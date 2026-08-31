package glyphnet.ssh2

import glyphnet.ffi.*
import glyphnet.errors.*

public class RemoteListener <: Resource {
    private var handle: CPointer<Unit>
    private let session: Session
    private var closed: Bool = false

    public let boundPort: UInt16

    init(handle: CPointer<Unit>, boundPort: UInt16, session: Session) {
        this.handle = handle
        this.boundPort = boundPort
        this.session = session
    }

    public func acceptNonBlocking(): Option<Channel> {
        return session.withLock {
            if (closed) {
                return Option<Channel>.None
            }
            ssh2SessionSetBlocking(session.raw, false)
            let ch = ssh2ChannelForwardAccept(handle)
            if (!ch.isNull()) {
                return Option<Channel>.Some(session.adoptChannel(ch))
            }
            let err = ssh2SessionLastError(session.raw)
            if (err[0] == LIBSSH2_ERROR_EAGAIN || err[0] == LIBSSH2_ERROR_NONE) {
                return Option<Channel>.None
            }
            throw SshException("accepting a forwarded connection on remote port ${boundPort} failed",
                               err[0], err[1])
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
                    ssh2ChannelForwardCancel(handle)
                }
                handle = CPointer<Unit>()
            }
            if (!session.isClosed()) {
                session.forgetListener(this)
            }
        }
    }
}
