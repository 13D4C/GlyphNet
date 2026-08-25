package glyphnet.ssh2

import glyphnet.ffi.*
import glyphnet.errors.*
import std.time.*

const READ_BUFFER_SIZE = 32768

const POLL_SLICE_MS: Int64 = 50

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

    public func startShell(): Unit {
        checkOpen()
        session.setBlocking(true)
        let rc = ssh2ChannelProcessStartup(handle, "shell", "")
        if (rc != 0) {
            let err = session.lastError()
            throw SshException("failed to start remote shell", rc, err[1])
        }
        started = true
    }

    public func exec(command: String): Unit {
        checkOpen()
        session.setBlocking(true)
        let rc = ssh2ChannelProcessStartup(handle, "exec", command)
        if (rc != 0) {
            let err = session.lastError()
            throw SshException("failed to exec '${command}'", rc, err[1])
        }
        started = true
    }

    public func mergeStderr(): Unit {
        checkOpen()
        ssh2ChannelHandleExtendedData(handle, LIBSSH2_CHANNEL_EXTENDED_DATA_MERGE)
    }

    public func writeAll(data: String, timeoutMs: Int64): Unit {
        checkOpen()
        let bytes = data.toArray()
        if (bytes.size == 0) {
            return
        }
        session.setBlocking(false)
        let deadline = MonoTime.now() + Duration.millisecond * timeoutMs
        var offset = 0
        while (offset < bytes.size) {
            let chunk = if (offset == 0) {
                bytes
            } else {
                bytes[offset..bytes.size]
            }
            let n = ssh2ChannelWrite(handle, 0, chunk)
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

    public func readAvailable(): String {
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
            if (Int32(n) == LIBSSH2_ERROR_CHANNEL_CLOSED || Int32(n) == LIBSSH2_ERROR_SOCKET_DISCONNECT) {
                break
            }
            let err = session.lastError()
            throw SshException("channel read failed", Int32(n), err[1])
        }
        return sb.toString()
    }

    public func readUntil(predicate: (String) -> Bool, timeoutMs: Int64, quietMs: Int64): String {
        checkOpen()
        session.setBlocking(false)

        let sb = StringBuilder()
        let buf = Array<UInt8>(READ_BUFFER_SIZE, repeat: 0)
        let start = MonoTime.now()
        let deadline = start + Duration.millisecond * timeoutMs
        var lastData = MonoTime.now()
        var sawAnyData = false

        while (true) {
            var progressed = false
            var atEof = false

            while (true) {
                let n = ssh2ChannelRead(handle, 0, buf)
                if (n > 0) {
                    sb.append(String.fromUtf8(buf[0..Int64(n)]))
                    progressed = true
                    sawAnyData = true
                    continue
                }
                if (Int32(n) == LIBSSH2_ERROR_EAGAIN) {
                    break
                }
                if (n == 0) {
                    if (ssh2ChannelEof(handle) == 1) {
                        atEof = true
                    }
                    break
                }
                if (Int32(n) == LIBSSH2_ERROR_CHANNEL_CLOSED ||
                    Int32(n) == LIBSSH2_ERROR_SOCKET_DISCONNECT) {
                    atEof = true
                    break
                }
                let err = session.lastError()
                throw SshException("channel read failed", Int32(n), err[1])
            }

            if (progressed) {
                lastData = MonoTime.now()
            }

            let text = sb.toString()
            if (predicate(text)) {
                return text
            }
            if (atEof || ssh2ChannelEof(handle) == 1) {
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

    public func isEof(): Bool {
        if (closed) {
            return true
        }
        return ssh2ChannelEof(handle) == 1
    }

    public func exitStatus(): Int32 {
        checkOpen()
        return ssh2ChannelExitStatus(handle)
    }

    public func sendEof(): Unit {
        checkOpen()
        session.setBlocking(true)
        ssh2ChannelSendEof(handle)
    }

    private func waitForSocket(sliceMs: Int64): Unit {
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
        pollOne(session.socket.fd, events, Int32(sliceMs))
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
