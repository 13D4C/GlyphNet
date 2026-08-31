package glyphnet.ffi

@When[os == "Linux"]
@C
public struct CAddrInfo {
    public var aiFlags: Int32 = 0
    public var aiFamily: Int32 = 0
    public var aiSocktype: Int32 = 0
    public var aiProtocol: Int32 = 0
    public var aiAddrlen: UInt32 = 0
    public var padding: UInt32 = 0
    public var aiAddr: CPointer<UInt8> = CPointer<UInt8>()
    public var aiCanonname: CPointer<UInt8> = CPointer<UInt8>()
    public var aiNext: CPointer<CAddrInfo> = CPointer<CAddrInfo>()
}

@When[os == "Linux"]
@C
public struct CPollFd {
    public var fd: Int32 = 0
    public var events: Int16 = 0
    public var revents: Int16 = 0
}

@When[os == "Linux"]
public const AF_UNSPEC: Int32 = 0

@When[os == "Linux"]
public const AF_INET: Int32 = 2

@When[os == "Linux"]
public const AF_INET6: Int32 = 10

@When[os == "Linux"]
public const SOCK_STREAM: Int32 = 1

@When[os == "Linux"]
public const SOCK_NONBLOCK: Int32 = 0x800

@When[os == "Linux"]
public const IPPROTO_TCP: Int32 = 6

@When[os == "Linux"]
public const SOL_SOCKET: Int32 = 1

@When[os == "Linux"]
public const SO_REUSEADDR: Int32 = 2

@When[os == "Linux"]
public const SO_ERROR: Int32 = 4

@When[os == "Linux"]
public const SO_KEEPALIVE: Int32 = 9

@When[os == "Linux"]
public const TCP_NODELAY: Int32 = 1

@When[os == "Linux"]
public const POLLIN: Int16 = 0x001

@When[os == "Linux"]
public const POLLOUT: Int16 = 0x004

@When[os == "Linux"]
public const POLLERR: Int16 = 0x008

@When[os == "Linux"]
public const POLLHUP: Int16 = 0x010

@When[os == "Linux"]
public const POLLNVAL: Int16 = 0x020

@When[os == "Linux"]
public const EINTR: Int32 = 4

@When[os == "Linux"]
public const EAGAIN: Int32 = 11

@When[os == "Linux"]
public const EWOULDBLOCK: Int32 = 11

@When[os == "Linux"]
public const EPIPE: Int32 = 32

@When[os == "Linux"]
public const EINPROGRESS: Int32 = 115

@When[os == "Linux"]
public const ECONNREFUSED: Int32 = 111

@When[os == "Linux"]
public const ECONNRESET: Int32 = 104

@When[os == "Linux"]
public const ECONNABORTED: Int32 = 103

@When[os == "Linux"]
public const SHUT_RDWR: Int32 = 2

@When[os == "Linux"]
public const SHUT_WR: Int32 = 1

@When[os == "Linux"]
public const AI_PASSIVE: Int32 = 0x0001

@When[os == "Linux"]
public const AI_NUMERICSERV: Int32 = 0x0400

@When[os == "Linux"]
public const SOCKADDR_STORAGE_SIZE: Int64 = 128

@When[os == "Linux"]
foreign func socket(domain: Int32, ty: Int32, protocol: Int32): Int32

@When[os == "Linux"]
foreign func connect(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32

@When[os == "Linux"]
foreign func bind(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32

@When[os == "Linux"]
foreign func listen(fd: Int32, backlog: Int32): Int32

@When[os == "Linux"]
foreign func accept4(fd: Int32, addr: CPointer<UInt8>, addrlen: CPointer<UInt32>,
                     flags: Int32): Int32

@When[os == "Linux"]
foreign func getsockname(fd: Int32, addr: CPointer<UInt8>, addrlen: CPointer<UInt32>): Int32

@When[os == "Linux"]
foreign func read(fd: Int32, buf: CPointer<UInt8>, count: UIntNative): IntNative

@When[os == "Linux"]
foreign func write(fd: Int32, buf: CPointer<UInt8>, count: UIntNative): IntNative

@When[os == "Linux"]
foreign func close(fd: Int32): Int32

@When[os == "Linux"]
foreign func shutdown(fd: Int32, how: Int32): Int32

@When[os == "Linux"]
foreign func poll(fds: CPointer<CPollFd>, nfds: UInt64, timeout: Int32): Int32

@When[os == "Linux"]
foreign func getsockopt(fd: Int32, level: Int32, optname: Int32, optval: CPointer<Int32>,
                        optlen: CPointer<UInt32>): Int32

@When[os == "Linux"]
foreign func setsockopt(fd: Int32, level: Int32, optname: Int32, optval: CPointer<Int32>,
                        optlen: UInt32): Int32

@When[os == "Linux"]
foreign func getaddrinfo(node: CString, service: CString, hints: CPointer<CAddrInfo>,
                         res: CPointer<CPointer<CAddrInfo>>): Int32

@When[os == "Linux"]
foreign func freeaddrinfo(res: CPointer<CAddrInfo>): Unit

@When[os == "Linux"]
foreign func gai_strerror(code: Int32): CString

@When[os == "Linux"]
foreign func strerror(errnum: Int32): CString

@When[os == "Linux"]
foreign func __errno_location(): CPointer<Int32>

@When[os == "Linux"]
public func errno(): Int32 {
    unsafe { return __errno_location().read() }
}

@When[os == "Linux"]
public func errnoMessage(e: Int32): String {
    unsafe { return strerror(e).toString() }
}

@When[os == "Linux"]
public func gaiMessage(code: Int32): String {
    unsafe { return gai_strerror(code).toString() }
}

@When[os == "Linux"]
public func sysNetInit(): Unit {
}

@When[os == "Linux"]
public func sysSocket(domain: Int32, ty: Int32, protocol: Int32): Int32 {
    unsafe { return socket(domain, ty, protocol) }
}

@When[os == "Linux"]
public func sysSocketStreamNonBlocking(domain: Int32): Int32 {
    unsafe { return socket(domain, SOCK_STREAM | SOCK_NONBLOCK, IPPROTO_TCP) }
}

@When[os == "Linux"]
public func sysConnect(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32 {
    unsafe { return connect(fd, addr, addrlen) }
}

@When[os == "Linux"]
public func sysBind(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32 {
    unsafe { return bind(fd, addr, addrlen) }
}

@When[os == "Linux"]
public func sysListen(fd: Int32, backlog: Int32): Int32 {
    unsafe { return listen(fd, backlog) }
}

@When[os == "Linux"]
public func sysAcceptNonBlocking(fd: Int32): Int32 {
    unsafe {
        let addr = LibC.malloc<UInt8>(count: SOCKADDR_STORAGE_SIZE)
        let len = LibC.malloc<UInt32>(count: 1)
        if (addr.isNull() || len.isNull()) {
            return -1
        }
        len.write(0, UInt32(SOCKADDR_STORAGE_SIZE))
        let accepted = accept4(fd, addr, len, SOCK_NONBLOCK)
        LibC.free(addr)
        LibC.free(len)
        return accepted
    }
}

@When[os == "Linux"]
public func sysBoundPort(fd: Int32): UInt16 {
    unsafe {
        let addr = LibC.malloc<UInt8>(count: SOCKADDR_STORAGE_SIZE)
        let len = LibC.malloc<UInt32>(count: 1)
        if (addr.isNull() || len.isNull()) {
            return 0
        }
        len.write(0, UInt32(SOCKADDR_STORAGE_SIZE))
        let rc = getsockname(fd, addr, len)
        var port: UInt16 = 0
        if (rc == 0 && len.read(0) >= 4) {
            port = (UInt16(addr.read(2)) << 8) | UInt16(addr.read(3))
        }
        LibC.free(addr)
        LibC.free(len)
        return port
    }
}

@When[os == "Linux"]
public func sysRead(fd: Int32, buf: Array<UInt8>): Int64 {
    unsafe {
        let h = acquireArrayRawData(buf)
        let n = read(fd, h.pointer, UIntNative(buf.size))
        releaseArrayRawData(h)
        return Int64(n)
    }
}

@When[os == "Linux"]
public func sysWrite(fd: Int32, data: Array<UInt8>): Int64 {
    if (data.size == 0) {
        return 0
    }
    unsafe {
        let h = acquireArrayRawData(data)
        let n = write(fd, h.pointer, UIntNative(data.size))
        releaseArrayRawData(h)
        return Int64(n)
    }
}

@When[os == "Linux"]
public func sysClose(fd: Int32): Int32 {
    unsafe { return close(fd) }
}

@When[os == "Linux"]
public func sysShutdown(fd: Int32, how: Int32): Int32 {
    unsafe { return shutdown(fd, how) }
}

@When[os == "Linux"]
public func sysGetaddrinfo(node: CString, service: CString, hints: CPointer<CAddrInfo>,
                           res: CPointer<CPointer<CAddrInfo>>): Int32 {
    unsafe { return getaddrinfo(node, service, hints, res) }
}

@When[os == "Linux"]
public func sysFreeaddrinfo(res: CPointer<CAddrInfo>): Unit {
    unsafe { freeaddrinfo(res) }
}

@When[os == "Linux"]
public func pollOne(fd: Int32, events: Int16, timeoutMs: Int32): Int32 {
    var pfd = CPollFd()
    pfd.fd = fd
    pfd.events = events
    pfd.revents = 0
    unsafe {
        let p = LibC.malloc<CPollFd>(count: 1)
        if (p.isNull()) {
            return -1
        }
        p.write(0, pfd)
        let rc = poll(p, 1, timeoutMs)
        let revents = p.read(0).revents
        LibC.free(p)
        if (rc < 0) {
            let e = errno()
            return -e
        }
        if (rc == 0) {
            return 0
        }
        return Int32(revents)
    }
}

@When[os == "Linux"]
public func pollMany(fds: Array<Int32>, events: Array<Int16>, timeoutMs: Int32): Array<Int16> {
    let count = fds.size
    let out = Array<Int16>(count, repeat: 0)
    if (count == 0) {
        return out
    }
    unsafe {
        let p = LibC.malloc<CPollFd>(count: count)
        if (p.isNull()) {
            return out
        }
        for (i in 0..count) {
            var pfd = CPollFd()
            pfd.fd = fds[i]
            pfd.events = events[i]
            pfd.revents = 0
            p.write(i, pfd)
        }
        let rc = poll(p, UInt64(count), timeoutMs)
        if (rc > 0) {
            for (i in 0..count) {
                out[i] = p.read(i).revents
            }
        }
        LibC.free(p)
        return out
    }
}

@When[os == "Linux"]
public func soError(fd: Int32): Int32 {
    unsafe {
        let val = LibC.malloc<Int32>(count: 1)
        let len = LibC.malloc<UInt32>(count: 1)
        if (val.isNull() || len.isNull()) {
            return -1
        }
        val.write(0, 0)
        len.write(0, 4)
        let rc = getsockopt(fd, SOL_SOCKET, SO_ERROR, val, len)
        let out = if (rc == 0) { val.read(0) } else { errno() }
        LibC.free(val)
        LibC.free(len)
        return out
    }
}

@When[os == "Linux"]
public func setIntSockOpt(fd: Int32, level: Int32, optname: Int32, value: Int32): Int32 {
    unsafe {
        let val = LibC.malloc<Int32>(count: 1)
        if (val.isNull()) {
            return -1
        }
        val.write(0, value)
        let rc = setsockopt(fd, level, optname, val, 4)
        LibC.free(val)
        return rc
    }
}
