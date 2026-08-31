package glyphnet.transport

import glyphnet.ffi.*
import glyphnet.errors.*

public class TcpListener <: Resource {
    private var rawFd: Int32
    private var closed: Bool = false

    public let host: String
    public let port: UInt16

    private init(rawFd: Int32, host: String, port: UInt16) {
        this.rawFd = rawFd
        this.host = host
        this.port = port
    }

    public prop fd: Int32 {
        get() {
            rawFd
        }
    }

    public static func bind(host: String, port: UInt16, backlog: Int32): TcpListener {
        let bindHost = if (host.isEmpty()) { "127.0.0.1" } else { host }
        let addrs = resolveAddresses(bindHost, port, true)
        if (addrs.isEmpty()) {
            throw ConnectionException("no bindable addresses resolved for ${bindHost}:${port}")
        }

        var lastError = "no bind attempt was made"
        var lastErrno: Int32 = 0
        var bound: Option<TcpListener> = None

        try {
            for (addr in addrs) {
                let sock = sysSocket(addr.family, SOCK_STREAM | SOCK_NONBLOCK, IPPROTO_TCP)
                if (sock < 0) {
                    lastErrno = errno()
                    lastError = "socket() failed: ${errnoMessage(lastErrno)}"
                    continue
                }
                setIntSockOpt(sock, SOL_SOCKET, SO_REUSEADDR, 1)

                if (sysBind(sock, addr.sockaddr, addr.sockaddrLen) != 0) {
                    lastErrno = errno()
                    lastError = "bind() failed: ${errnoMessage(lastErrno)}"
                    sysClose(sock)
                    continue
                }
                if (sysListen(sock, backlog) != 0) {
                    lastErrno = errno()
                    lastError = "listen() failed: ${errnoMessage(lastErrno)}"
                    sysClose(sock)
                    continue
                }
                let actual = sysBoundPort(sock)
                bound = TcpListener(sock, bindHost, if (actual > 0) { actual } else { port })
                break
            }
        } finally {
            for (addr in addrs) {
                addr.release()
            }
        }

        match (bound) {
            case Some(l) => return l
            case None =>
                throw ConnectionException("cannot listen on ${bindHost}:${port} - ${lastError}",
                                          lastErrno)
        }
    }

    public func acceptNonBlocking(): Option<Int32> {
        if (closed) {
            return None
        }
        let accepted = sysAcceptNonBlocking(rawFd)
        if (accepted >= 0) {
            setIntSockOpt(accepted, IPPROTO_TCP, TCP_NODELAY, 1)
            return accepted
        }
        let e = errno()
        if (e == EAGAIN || e == EINTR || e == ECONNABORTED) {
            return None
        }
        throw ConnectionException("accept() on ${host}:${port} failed: ${errnoMessage(e)}", e)
    }

    public func waitForConnection(timeoutMs: Int64): Bool {
        if (closed) {
            return false
        }
        let capped = if (timeoutMs > 2147483647) { 2147483647 } else { timeoutMs }
        return pollOne(rawFd, POLLIN, Int32(capped)) > 0
    }

    public func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        sysClose(rawFd)
        rawFd = -1
    }
}
