package glyphnet.ssh2

import glyphnet.ffi.*
import glyphnet.errors.*
import std.time.*

const READ_BUFFER_SIZE = 32768

const POLL_SLICE_MS: Int64 = 50

public func sessionPollEvents(session: Session): Int16 {
    let dir = session.blockDirections()
    var events: Int16 = 0
    if ((dir & LIBSSH2_SESSION_BLOCK_INBOUND) != 0) {
        events |= POLLIN
    }
    if ((dir & LIBSSH2_SESSION_BLOCK_OUTBOUND) != 0) {
        events |= POLLOUT
    }
    if (events == 0) {
        events = POLLIN
    }
    return events
}

public class Channel <: Resource {
    private var handle: CPointer<Unit>
    private let session: Session
    private var closed: Bool = false
    private var ptyRequested: Bool = false
    private var started: Bool = false

    init(handle: CPointer<Unit>, session: Session) {
        this.handle = handle
        this.session = session
    }

    public func requestPty(term: String, width: Int32, height: Int32): Unit {
        session.withLock {
            checkOpen()
            if (started) {
                throw SshException("PTY must be requested before the shell or command is started")
            }
            session.setBlocking(true)
            let rc = ssh2ChannelRequestPty(handle, term, width, height)
            if (rc != 0) {
                let err = session.lastError()
                throw SshException("PTY request ('${term}') was denied", rc, err[1])
            }
            ptyRequested = true
        }
    }

    public func startShell(): Unit {
        session.withLock {
            checkOpen()
            session.setBlocking(true)
            let rc = ssh2ChannelProcessStartup(handle, "shell", "")
            if (rc != 0) {
                let err = session.lastError()
                throw SshException("failed to start remote shell", rc, err[1])
            }
            started = true
        }
    }

    public func exec(command: String): Unit {
        session.withLock {
            checkOpen()
            session.setBlocking(true)
            let rc = ssh2ChannelProcessStartup(handle, "exec", command)
            if (rc != 0) {
                let err = session.lastError()
                throw SshException("failed to exec '${command}'", rc, err[1])
            }
            started = true
        }
    }

    public func mergeStderr(): Unit {
        session.withLock {
            checkOpen()
            ssh2ChannelHandleExtendedData(handle, LIBSSH2_CHANNEL_EXTENDED_DATA_MERGE)
        }
    }

    public func writeAll(data: String, timeoutMs: Int64): Unit {
        writeAll(data.toArray(), timeoutMs)
    }

    public func writeAll(bytes: Array<UInt8>, timeoutMs: Int64): Unit {
        checkOpen()
        if (bytes.size == 0) {
            return
        }
        let deadline = MonoTime.now() + Duration.millisecond * timeoutMs
        var offset = 0
        while (offset < bytes.size) {
            let chunk = if (offset == 0) {
                bytes
            } else {
                bytes[offset..bytes.size]
            }
            let n = session.withLock {
                checkOpen()
                session.setBlocking(false)
                return ssh2ChannelWrite(handle, 0, chunk)
            }
            if (n > 0) {
                offset += Int64(n)
                continue
            }
            if (Int32(n) == LIBSSH2_ERROR_EAGAIN) {
                if (MonoTime.now() >= deadline) {
                    throw SshTimeoutException(
                        "timed out after ${timeoutMs}ms writing ${bytes.size} bytes to the channel")
                }
                waitForSocket(POLL_SLICE_MS)
                continue
            }
            let err = session.lastError()
            throw SshException("channel write failed", Int32(n), err[1])
        }
    }

    public func writeSome(data: Array<UInt8>): Int64 {
        return session.withLock {
            checkOpen()
            session.setBlocking(false)
            return ssh2ChannelWrite(handle, 0, data)
        }
    }

    public func readSome(buf: Array<UInt8>): Int64 {
        return session.withLock {
            checkOpen()
            session.setBlocking(false)
            return ssh2ChannelRead(handle, 0, buf)
        }
    }

    public func readAvailable(): String {
        return session.withLock {
            checkOpen()
            session.setBlocking(false)
            let sb = StringBuilder()
            let buf = Array<UInt8>(READ_BUFFER_SIZE, repeat: 0)
            while (true) {
                let n = ssh2ChannelRead(handle, 0, buf)
                if (n > 0) {
                    sb.append(String.fromUtf8(buf[0..Int64(n)]))
                    continue
                }
                if (n == 0 || Int32(n) == LIBSSH2_ERROR_EAGAIN) {
                    break
                }
                if (Int32(n) == LIBSSH2_ERROR_CHANNEL_CLOSED ||
                    Int32(n) == LIBSSH2_ERROR_SOCKET_DISCONNECT) {
                    break
                }
                let err = session.lastError()
                throw SshException("channel read failed", Int32(n), err[1])
            }
            return sb.toString()
        }
    }

    public func readUntil(predicate: (String) -> Bool, timeoutMs: Int64, quietMs: Int64): String {
        checkOpen()

        let sb = StringBuilder()
        let buf = Array<UInt8>(READ_BUFFER_SIZE, repeat: 0)
        let start = MonoTime.now()
        let deadline = start + Duration.millisecond * timeoutMs
        var lastData = MonoTime.now()
        var sawAnyData = false

        while (true) {
            let drained = session.withLock {
                checkOpen()
                session.setBlocking(false)
                var got = false
                var eof = false
                while (true) {
                    let n = ssh2ChannelRead(handle, 0, buf)
                    if (n > 0) {
                        sb.append(String.fromUtf8(buf[0..Int64(n)]))
                        got = true
                        continue
                    }
                    if (Int32(n) == LIBSSH2_ERROR_EAGAIN) {
                        break
                    }
                    if (n == 0) {
                        if (ssh2ChannelEof(handle) == 1) {
                            eof = true
                        }
                        break
                    }
                    if (Int32(n) == LIBSSH2_ERROR_CHANNEL_CLOSED ||
                        Int32(n) == LIBSSH2_ERROR_SOCKET_DISCONNECT) {
                        eof = true
                        break
                    }
                    let err = ssh2SessionLastError(session.raw)
                    throw SshException("channel read failed", Int32(n), err[1])
                }
                if (!eof && ssh2ChannelEof(handle) == 1) {
                    eof = true
                }
                return (got, eof)
            }
            let progressed = drained[0]
            let atEof = drained[1]

            if (progressed) {
                lastData = MonoTime.now()
                sawAnyData = true
            }

            let text = sb.toString()
            if (predicate(text)) {
                return text
            }
            if (atEof) {
                return text
            }
            if (MonoTime.now() >= deadline) {
                throw SshTimeoutException(
                    "timed out after ${timeoutMs}ms waiting for expected output; " +
                    "read ${text.size} bytes so far")
            }

            if (quietMs > 0 && sawAnyData) {
                let idle = (MonoTime.now() - lastData).toMilliseconds()
                if (idle >= quietMs) {
                    return text
                }
            }
            waitForSocket(POLL_SLICE_MS)
        }
        return sb.toString()
    }

    public func readToEof(timeoutMs: Int64): String {
        return readUntil({_ => false}, timeoutMs, 0)
    }

    public func readChunk(buf: Array<UInt8>, timeoutMs: Int64): Int64 {
        checkOpen()
        if (buf.size == 0) {
            return 0
        }
        let deadline = MonoTime.now() + Duration.millisecond * timeoutMs
        while (true) {
            let result = session.withLock {
                checkOpen()
                session.setBlocking(false)
                let got = ssh2ChannelRead(handle, 0, buf)
                return (got, ssh2ChannelEof(handle) == 1)
            }
            let n = result[0]
            if (n > 0) {
                return n
            }
            if (result[1]) {
                return 0
            }
            if (n == 0 || Int32(n) == LIBSSH2_ERROR_EAGAIN) {
                if (MonoTime.now() >= deadline) {
                    throw SshTimeoutException(
                        "timed out after ${timeoutMs}ms waiting for channel data")
                }
                waitForSocket(POLL_SLICE_MS)
                continue
            }
            if (Int32(n) == LIBSSH2_ERROR_CHANNEL_CLOSED ||
                Int32(n) == LIBSSH2_ERROR_SOCKET_DISCONNECT) {
                return 0
            }
            let err = session.lastError()
            throw SshException("channel read failed", Int32(n), err[1])
        }
        return 0
    }

    public func isEof(): Bool {
        return session.withLock {
            if (closed) {
                return true
            }
            return ssh2ChannelEof(handle) == 1
        }
    }

    public func exitStatus(): Int32 {
        return session.withLock {
            checkOpen()
            return ssh2ChannelExitStatus(handle)
        }
    }

    public func waitForExit(timeoutMs: Int64): Int32 {
        return session.withLock {
            checkOpen()
            let previousTimeout = ssh2SessionGetTimeout(session.raw)
            ssh2SessionSetBlocking(session.raw, true)
            ssh2SessionSetTimeout(session.raw, timeoutMs)
            ssh2ChannelClose(handle)
            ssh2ChannelWaitClosed(handle)
            let status = ssh2ChannelExitStatus(handle)
            ssh2SessionSetTimeout(session.raw, previousTimeout)
            return status
        }
    }

    public func sendEof(): Unit {
        session.withLock {
            checkOpen()
            session.setBlocking(true)
            ssh2ChannelSendEof(handle)
        }
    }

    private func waitForSocket(sliceMs: Int64): Unit {
        pollOne(session.socket.fd, sessionPollEvents(session), Int32(sliceMs))
    }

    private func checkOpen(): Unit {
        if (closed) {
            throw SshException("SSH channel is already closed")
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        session.withLock {
            if (closed) {
                return
            }
            closed = true
            if (!handle.isNull()) {
                if (!session.isClosed()) {
                    ssh2SessionSetBlocking(session.raw, true)
                    ssh2SessionSetTimeout(session.raw, 2000)
                }
                ssh2ChannelClose(handle)
                ssh2ChannelFree(handle)
                handle = CPointer<Unit>()
            }
            if (!session.isClosed()) {
                session.forgetChannel(this)
            }
        }
    }
}
