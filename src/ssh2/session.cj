package glyphnet.ssh2

import glyphnet.ffi.*
import glyphnet.errors.*
import glyphnet.transport.*
import std.collection.*
import std.sync.*

public class Session <: Resource {
    private var handle: CPointer<Unit>
    private let transport: TcpTransport
    private var closed: Bool = false
    private let channels = ArrayList<Channel>()
    private let listeners = ArrayList<RemoteListener>()
    private let apiLock = Mutex()

    private init(handle: CPointer<Unit>, transport: TcpTransport) {
        this.handle = handle
        this.transport = transport
    }

    func withLock<T>(body: () -> T): T {
        synchronized(apiLock) {
            return body()
        }
    }

    prop raw: CPointer<Unit> {
        get() {
            handle
        }
    }

    public prop socket: TcpTransport {
        get() {
            transport
        }
    }

    public static func handshake(transport: TcpTransport, timeoutMs: Int64): Session {
        Libssh2.ensureInit()

        let h = ssh2SessionInit()
        if (h.isNull()) {
            transport.close()
            throw SshException("libssh2_session_init_ex() returned NULL (out of memory?)")
        }

        ssh2SessionSetBlocking(h, true)
        ssh2SessionSetTimeout(h, timeoutMs)

        let rc = ssh2SessionHandshake(h, transport.fd)
        if (rc != 0) {
            let err = ssh2SessionLastError(h)
            ssh2SessionFree(h)
            transport.close()
            if (rc == LIBSSH2_ERROR_TIMEOUT) {
                throw SshTimeoutException(
                    "SSH handshake with ${transport.host}:${transport.port} timed out after ${timeoutMs}ms")
            }
            throw SshException("SSH handshake with ${transport.host}:${transport.port} failed",
                               rc, err[1])
        }
        return Session(h, transport)
    }

    public func banner(): String {
        return withLock {
            checkOpen()
            return ssh2SessionBanner(handle)
        }
    }

    public func hostKey(): Array<UInt8> {
        return withLock {
            checkOpen()
            return ssh2SessionHostkey(handle)[0]
        }
    }

    public func hostKeyType(): Int32 {
        return withLock {
            checkOpen()
            return ssh2SessionHostkey(handle)[1]
        }
    }

    public func hostKeyFingerprintSha256(): Array<UInt8> {
        return withLock {
            checkOpen()
            return ssh2HostkeyHash(handle, LIBSSH2_HOSTKEY_HASH_SHA256)
        }
    }

    public func authMethods(username: String): String {
        return withLock {
            checkOpen()
            return ssh2UserauthList(handle, username)
        }
    }

    public func isAuthenticated(): Bool {
        return withLock {
            if (closed) {
                return false
            }
            return ssh2UserauthAuthenticated(handle)
        }
    }

    public func authenticatePassword(username: String, password: String): Unit {
        withLock {
            checkOpen()
            let rc = ssh2UserauthPassword(handle, username, password)
            if (rc != 0) {
                let err = ssh2SessionLastError(handle)
                throw AuthenticationException(
                    "password authentication failed for user '${username}'", rc, err[1])
            }
        }
    }

    public func authenticatePublicKey(username: String, privateKeyPath: String,
                                      publicKeyPath: String, passphrase: String): Unit {
        withLock {
            checkOpen()
            if (privateKeyPath.isEmpty()) {
                throw AuthenticationException("private key path must not be empty")
            }
            let rc = ssh2UserauthPublicKeyFromFile(handle, username, publicKeyPath, privateKeyPath,
                                                   passphrase)
            if (rc != 0) {
                let err = ssh2SessionLastError(handle)
                throw AuthenticationException(
                    "public key authentication failed for user '${username}' using '${privateKeyPath}'",
                    rc, err[1])
            }
        }
    }

    public func openChannel(): Channel {
        return withLock {
            checkOpen()
            ssh2SessionSetBlocking(handle, true)
            let ch = ssh2ChannelOpenSession(handle)
            if (ch.isNull()) {
                let err = ssh2SessionLastError(handle)
                throw SshException("failed to open SSH channel", err[0], err[1])
            }
            let channel = Channel(ch, this)
            channels.add(channel)
            return channel
        }
    }

    public func openDirectTcpIpChannel(remoteHost: String, remotePort: UInt16, originHost: String,
                                       originPort: UInt16): Channel {
        return withLock {
            checkOpen()
            ssh2SessionSetBlocking(handle, true)
            let ch = ssh2ChannelDirectTcpip(handle, remoteHost, remotePort, originHost, originPort)
            if (ch.isNull()) {
                let err = ssh2SessionLastError(handle)
                throw SshException(
                    "server refused a direct-tcpip channel to ${remoteHost}:${remotePort}",
                    err[0], err[1])
            }
            let channel = Channel(ch, this)
            channels.add(channel)
            return channel
        }
    }

    public func openScpSend(remotePath: String, mode: Int32, size: Int64, mtime: Int64,
                            atime: Int64): Channel {
        return withLock {
            checkOpen()
            ssh2SessionSetBlocking(handle, true)
            let ch = ssh2ScpSend(handle, remotePath, mode, size, mtime, atime)
            if (ch.isNull()) {
                let err = ssh2SessionLastError(handle)
                throw SshException("server refused an SCP upload channel for '${remotePath}'",
                                   err[0], err[1])
            }
            let channel = Channel(ch, this)
            channels.add(channel)
            return channel
        }
    }

    public func openScpRecv(remotePath: String): (Channel, Int64) {
        return withLock {
            checkOpen()
            ssh2SessionSetBlocking(handle, true)
            let result = ssh2ScpRecv(handle, remotePath)
            if (result[0].isNull()) {
                let err = ssh2SessionLastError(handle)
                throw SshException("server refused an SCP download channel for '${remotePath}'",
                                   err[0], err[1])
            }
            let channel = Channel(result[0], this)
            channels.add(channel)
            return (channel, result[1])
        }
    }

    public func listenForwarded(bindHost: String, remotePort: UInt16,
                                queueSize: Int32): RemoteListener {
        return withLock {
            checkOpen()
            ssh2SessionSetBlocking(handle, true)
            let result = ssh2ChannelForwardListen(handle, bindHost, remotePort, queueSize)
            if (result[0].isNull()) {
                let err = ssh2SessionLastError(handle)
                throw SshException(
                    "server refused to listen on ${bindHost}:${remotePort} for remote forwarding",
                    err[0], err[1])
            }
            let listener = RemoteListener(result[0], result[1], this)
            listeners.add(listener)
            return listener
        }
    }

    func adoptChannel(raw: CPointer<Unit>): Channel {
        return withLock {
            let channel = Channel(raw, this)
            channels.add(channel)
            return channel
        }
    }

    public func setBlocking(blocking: Bool): Unit {
        withLock {
            checkOpen()
            ssh2SessionSetBlocking(handle, blocking)
        }
    }

    public func setTimeout(timeoutMs: Int64): Unit {
        withLock {
            checkOpen()
            ssh2SessionSetTimeout(handle, timeoutMs)
        }
    }

    public func setKeepalive(wantReply: Bool, intervalSec: UInt32): Unit {
        withLock {
            checkOpen()
            ssh2KeepaliveConfig(handle, wantReply, intervalSec)
        }
    }

    func blockDirections(): Int32 {
        return withLock {
            if (closed) {
                return LIBSSH2_SESSION_BLOCK_INBOUND
            }
            return ssh2SessionBlockDirections(handle)
        }
    }

    public func lastError(): (Int32, String) {
        return withLock {
            if (closed) {
                return (LIBSSH2_ERROR_NONE, "session is closed")
            }
            return ssh2SessionLastError(handle)
        }
    }

    func forgetChannel(channel: Channel): Unit {
        withLock {
            channels.removeIf({c => refEq(c, channel)})
        }
    }

    func forgetListener(listener: RemoteListener): Unit {
        withLock {
            listeners.removeIf({l => refEq(l, listener)})
        }
    }

    private func checkOpen(): Unit {
        if (closed) {
            throw SshException("SSH session is already closed")
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        withLock {
            closeLocked()
        }
    }

    private func closeLocked(): Unit {
        if (closed) {
            return
        }

        let listenerSnapshot = listeners.toArray()
        listeners.clear()
        for (l in listenerSnapshot) {
            try {
                l.close()
            } catch (_: Exception) {
            }
        }

        closed = true

        let snapshot = channels.toArray()
        channels.clear()
        for (ch in snapshot) {
            try {
                ch.close()
            } catch (_: Exception) {
            }
        }

        if (!handle.isNull()) {
            ssh2SessionSetBlocking(handle, true)
            ssh2SessionSetTimeout(handle, 2000)
            ssh2SessionDisconnect(handle, "GlyphNet client disconnecting")
            ssh2SessionFree(handle)
            handle = CPointer<Unit>()
        }
        transport.close()
    }
}
