package glyphnet.ssh2

import glyphnet.ffi.*
import glyphnet.errors.*
import glyphnet.transport.*
import std.collection.*

public class Session <: Resource {
    private var handle: CPointer<Unit>
    private let transport: TcpTransport
    private var closed: Bool = false
    private let channels = ArrayList<Channel>()

    private init(handle: CPointer<Unit>, transport: TcpTransport) {
        this.handle = handle
        this.transport = transport
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
        checkOpen()
        return ssh2SessionBanner(handle)
    }

    public func hostKey(): Array<UInt8> {
        checkOpen()
        return ssh2SessionHostkey(handle)[0]
    }

    public func hostKeyType(): Int32 {
        checkOpen()
        return ssh2SessionHostkey(handle)[1]
    }

    public func hostKeyFingerprintSha256(): Array<UInt8> {
        checkOpen()
        return ssh2HostkeyHash(handle, LIBSSH2_HOSTKEY_HASH_SHA256)
    }

    public func authMethods(username: String): String {
        checkOpen()
        return ssh2UserauthList(handle, username)
    }

    public func isAuthenticated(): Bool {
        if (closed) {
            return false
        }
        return ssh2UserauthAuthenticated(handle)
    }

    public func authenticatePassword(username: String, password: String): Unit {
        checkOpen()
        let rc = ssh2UserauthPassword(handle, username, password)
        if (rc != 0) {
            let err = ssh2SessionLastError(handle)
            throw AuthenticationException("password authentication failed for user '${username}'",
                                          rc, err[1])
        }
    }

    public func authenticatePublicKey(username: String, privateKeyPath: String,
                                      publicKeyPath: String, passphrase: String): Unit {
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

    public func openChannel(): Channel {
        checkOpen()
        let ch = ssh2ChannelOpenSession(handle)
        if (ch.isNull()) {
            let err = ssh2SessionLastError(handle)
            throw SshException("failed to open SSH channel", err[0], err[1])
        }
        let channel = Channel(ch, this)
        channels.add(channel)
        return channel
    }

    public func setBlocking(blocking: Bool): Unit {
        checkOpen()
        ssh2SessionSetBlocking(handle, blocking)
    }

    public func setTimeout(timeoutMs: Int64): Unit {
        checkOpen()
        ssh2SessionSetTimeout(handle, timeoutMs)
    }

    public func setKeepalive(wantReply: Bool, intervalSec: UInt32): Unit {
        checkOpen()
        ssh2KeepaliveConfig(handle, wantReply, intervalSec)
    }

    func blockDirections(): Int32 {
        return ssh2SessionBlockDirections(handle)
    }

    public func lastError(): (Int32, String) {
        if (closed) {
            return (LIBSSH2_ERROR_NONE, "session is closed")
        }
        return ssh2SessionLastError(handle)
    }

    func forgetChannel(channel: Channel): Unit {
        channels.removeIf({c => refEq(c, channel)})
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
        if (closed) {
            return
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
