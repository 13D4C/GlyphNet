package glyphnet.ffi

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

@C
public struct CPollFd {
    public var fd: Int32 = 0
    public var events: Int16 = 0
    public var revents: Int16 = 0
}

public const AF_UNSPEC: Int32 = 0
public const AF_INET: Int32 = 2
public const AF_INET6: Int32 = 10

public const SOCK_STREAM: Int32 = 1

public const SOCK_NONBLOCK: Int32 = 0x800

public const IPPROTO_TCP: Int32 = 6

public const SOL_SOCKET: Int32 = 1
public const SO_ERROR: Int32 = 4
public const SO_KEEPALIVE: Int32 = 9
public const TCP_NODELAY: Int32 = 1

public const POLLIN: Int16 = 0x001
public const POLLOUT: Int16 = 0x004
public const POLLERR: Int16 = 0x008
public const POLLHUP: Int16 = 0x010
public const POLLNVAL: Int16 = 0x020

public const EINTR: Int32 = 4
public const EAGAIN: Int32 = 11
public const EINPROGRESS: Int32 = 115
public const ECONNREFUSED: Int32 = 111

public const SHUT_RDWR: Int32 = 2

public const AI_NUMERICSERV: Int32 = 0x0400

foreign func socket(domain: Int32, ty: Int32, protocol: Int32): Int32
foreign func connect(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32
foreign func close(fd: Int32): Int32
foreign func shutdown(fd: Int32, how: Int32): Int32
foreign func poll(fds: CPointer<CPollFd>, nfds: UInt64, timeout: Int32): Int32
foreign func getsockopt(fd: Int32, level: Int32, optname: Int32, optval: CPointer<Int32>,
                        optlen: CPointer<UInt32>): Int32
foreign func setsockopt(fd: Int32, level: Int32, optname: Int32, optval: CPointer<Int32>,
                        optlen: UInt32): Int32
foreign func getaddrinfo(node: CString, service: CString, hints: CPointer<CAddrInfo>,
                         res: CPointer<CPointer<CAddrInfo>>): Int32
foreign func freeaddrinfo(res: CPointer<CAddrInfo>): Unit
foreign func gai_strerror(code: Int32): CString
foreign func strerror(errnum: Int32): CString

foreign func __errno_location(): CPointer<Int32>

public func errno(): Int32 {
    unsafe { return __errno_location().read() }
}

public func errnoMessage(e: Int32): String {
    unsafe { return strerror(e).toString() }
}

public func gaiMessage(code: Int32): String {
    unsafe { return gai_strerror(code).toString() }
}

public func sysSocket(domain: Int32, ty: Int32, protocol: Int32): Int32 {
    unsafe { return socket(domain, ty, protocol) }
}

public func sysConnect(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32 {
    unsafe { return connect(fd, addr, addrlen) }
}

public func sysClose(fd: Int32): Int32 {
    unsafe { return close(fd) }
}

public func sysShutdown(fd: Int32, how: Int32): Int32 {
    unsafe { return shutdown(fd, how) }
}

public func sysGetaddrinfo(node: CString, service: CString, hints: CPointer<CAddrInfo>,
                           res: CPointer<CPointer<CAddrInfo>>): Int32 {
    unsafe { return getaddrinfo(node, service, hints, res) }
}

public func sysFreeaddrinfo(res: CPointer<CAddrInfo>): Unit {
    unsafe { freeaddrinfo(res) }
}

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
