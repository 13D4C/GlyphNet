package glyphnet.transport

import glyphnet.ffi.*
import glyphnet.errors.*
import std.collection.*

public class TcpTransport <: Resource {
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

    public static func connect(host: String, port: UInt16, timeoutMs: Int64): TcpTransport {
        if (host.isEmpty()) {
            throw ConnectionException("host must not be empty")
        }
        if (timeoutMs <= 0) {
            throw ConnectionException("connect timeout must be positive, got ${timeoutMs}ms")
        }

        let addrs = resolve(host, port)
        if (addrs.isEmpty()) {
            throw ConnectionException("no addresses resolved for ${host}:${port}")
        }

        var lastError = "no connection attempt was made"
        var lastErrno: Int32 = 0
        var connected: Option<TcpTransport> = None

        try {
            for (addr in addrs) {
                let fd = sysSocket(addr.family, SOCK_STREAM | SOCK_NONBLOCK, IPPROTO_TCP)
                if (fd < 0) {
                    lastErrno = errno()
                    lastError = "socket() failed: ${errnoMessage(lastErrno)}"
                    continue
                }

                match (tryConnect(fd, addr, timeoutMs)) {
                    case None =>

                        setIntSockOpt(fd, IPPROTO_TCP, TCP_NODELAY, 1)
                        setIntSockOpt(fd, SOL_SOCKET, SO_KEEPALIVE, 1)
                        connected = TcpTransport(fd, host, port)
                        break
                    case Some(err) =>
                        sysClose(fd)
                        lastErrno = err[1]
                        lastError = err[0]
                }
            }
        } finally {
            for (addr in addrs) {
                addr.release()
            }
        }

        match (connected) {
            case Some(t) => return t
            case None =>
                throw ConnectionException("cannot connect to ${host}:${port} - ${lastError}", lastErrno)
        }
    }

    private static func tryConnect(fd: Int32, addr: ResolvedAddr, timeoutMs: Int64): Option<(String, Int32)> {
        let rc = sysConnect(fd, addr.sockaddr, addr.sockaddrLen)
        if (rc == 0) {
            return Option<(String, Int32)>.None
        }

        let e = errno()
        if (e != EINPROGRESS) {
            return Some(("connect() failed: ${errnoMessage(e)}", e))
        }

        let capped = if (timeoutMs > 2147483647) { 2147483647 } else { timeoutMs }
        let revents = pollOne(fd, POLLOUT, Int32(capped))
        if (revents == 0) {
            return Some(("connect timed out after ${timeoutMs}ms", Int32(0)))
        }
        if (revents < 0) {
            let pe = -revents
            return Some(("poll() failed while connecting: ${errnoMessage(pe)}", pe))
        }

        let soErr = soError(fd)
        if (soErr != 0) {
            return Some(("connect() failed: ${errnoMessage(soErr)}", soErr))
        }
        return Option<(String, Int32)>.None
    }

    private static func resolve(host: String, port: UInt16): Array<ResolvedAddr> {
        let results = ArrayList<ResolvedAddr>()
        unsafe {
            let node = LibC.mallocCString(host)
            let service = LibC.mallocCString(port.toString())
            let hintsPtr = LibC.malloc<CAddrInfo>(count: 1)
            let resPtr = LibC.malloc<CPointer<CAddrInfo>>(count: 1)

            if (hintsPtr.isNull() || resPtr.isNull()) {
                LibC.free(node)
                LibC.free(service)
                throw ConnectionException("out of memory resolving ${host}")
            }

            var hints = CAddrInfo()
            hints.aiFamily = AF_UNSPEC
            hints.aiSocktype = SOCK_STREAM
            hints.aiProtocol = IPPROTO_TCP
            hints.aiFlags = AI_NUMERICSERV
            hintsPtr.write(0, hints)
            resPtr.write(0, CPointer<CAddrInfo>())

            let rc = sysGetaddrinfo(node, service, hintsPtr, resPtr)
            let head = resPtr.read(0)

            LibC.free(node)
            LibC.free(service)
            LibC.free(hintsPtr)
            LibC.free(resPtr)

            if (rc != 0) {
                throw ConnectionException("cannot resolve ${host}:${port} - ${gaiMessage(rc)}")
            }

            var cur = head
            while (!cur.isNull()) {
                let ai = cur.read(0)
                if (!ai.aiAddr.isNull() && ai.aiAddrlen > 0) {
                    let n = Int64(ai.aiAddrlen)
                    let copy = LibC.malloc<UInt8>(count: n)
                    if (!copy.isNull()) {
                        for (i in 0..n) {
                            copy.write(i, ai.aiAddr.read(i))
                        }
                        results.add(ResolvedAddr(ai.aiFamily, copy, ai.aiAddrlen))
                    }
                }
                cur = ai.aiNext
            }
            sysFreeaddrinfo(head)
        }
        return results.toArray()
    }

    public func waitReadable(timeoutMs: Int64): Bool {
        return waitFor(POLLIN, timeoutMs)
    }

    public func waitWritable(timeoutMs: Int64): Bool {
        return waitFor(POLLOUT, timeoutMs)
    }

    private func waitFor(events: Int16, timeoutMs: Int64): Bool {
        if (closed) {
            return false
        }
        let capped = if (timeoutMs > 2147483647) { 2147483647 } else { timeoutMs }
        let r = pollOne(rawFd, events, Int32(capped))
        return r > 0
    }

    public func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        sysShutdown(rawFd, SHUT_RDWR)
        sysClose(rawFd)
        rawFd = -1
    }
}

class ResolvedAddr {
    let family: Int32
    var sockaddr: CPointer<UInt8>
    let sockaddrLen: UInt32
    private var released: Bool = false

    init(family: Int32, sockaddr: CPointer<UInt8>, sockaddrLen: UInt32) {
        this.family = family
        this.sockaddr = sockaddr
        this.sockaddrLen = sockaddrLen
    }

    func release(): Unit {
        if (released) {
            return
        }
        released = true
        if (!sockaddr.isNull()) {
            unsafe { LibC.free(sockaddr) }
            sockaddr = CPointer<UInt8>()
        }
    }
}
