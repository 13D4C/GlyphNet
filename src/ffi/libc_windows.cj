package glyphnet.ffi

@When[os == "Windows"]
import std.sync.*

@When[os == "Windows"]
@C
public struct CAddrInfo {
    public var aiFlags: Int32 = 0
    public var aiFamily: Int32 = 0
    public var aiSocktype: Int32 = 0
    public var aiProtocol: Int32 = 0
    public var aiAddrlen: UInt32 = 0
    public var aiAddrlenHigh: UInt32 = 0
    public var aiCanonname: CPointer<UInt8> = CPointer<UInt8>()
    public var aiAddr: CPointer<UInt8> = CPointer<UInt8>()
    public var aiNext: CPointer<CAddrInfo> = CPointer<CAddrInfo>()
}

@When[os == "Windows"]
@C
public struct CPollFd {
    public var fd: UIntNative = 0
    public var events: Int16 = 0
    public var revents: Int16 = 0
    public var pad: Int32 = 0
}

@When[os == "Windows"]
@C
struct CWsaData {
    var wVersion: UInt16 = 0
    var wHighVersion: UInt16 = 0
    var iMaxSockets: UInt16 = 0
    var iMaxUdpDg: UInt16 = 0
    var lpVendorInfo: CPointer<UInt8> = CPointer<UInt8>()
    var szDescription: CPointer<UInt8> = CPointer<UInt8>()
    var szSystemStatus: CPointer<UInt8> = CPointer<UInt8>()
}

@When[os == "Windows"]
public const AF_UNSPEC: Int32 = 0

@When[os == "Windows"]
public const AF_INET: Int32 = 2

@When[os == "Windows"]
public const AF_INET6: Int32 = 23

@When[os == "Windows"]
public const SOCK_STREAM: Int32 = 1

@When[os == "Windows"]
public const SOCK_NONBLOCK: Int32 = 0x800

@When[os == "Windows"]
public const IPPROTO_TCP: Int32 = 6

@When[os == "Windows"]
public const SOL_SOCKET: Int32 = 0xFFFF

@When[os == "Windows"]
public const SO_REUSEADDR: Int32 = 0x0004

@When[os == "Windows"]
public const SO_ERROR: Int32 = 0x1007

@When[os == "Windows"]
public const SO_KEEPALIVE: Int32 = 0x0008

@When[os == "Windows"]
public const TCP_NODELAY: Int32 = 0x0001

@When[os == "Windows"]
public const POLLIN: Int16 = 0x0300

@When[os == "Windows"]
public const POLLOUT: Int16 = 0x0010

@When[os == "Windows"]
public const POLLERR: Int16 = 0x0001

@When[os == "Windows"]
public const POLLHUP: Int16 = 0x0002

@When[os == "Windows"]
public const POLLNVAL: Int16 = 0x0004

@When[os == "Windows"]
public const EINTR: Int32 = 10004

@When[os == "Windows"]
public const EAGAIN: Int32 = 10035

@When[os == "Windows"]
public const EWOULDBLOCK: Int32 = 10035

@When[os == "Windows"]
public const EPIPE: Int32 = 10058

@When[os == "Windows"]
public const EINPROGRESS: Int32 = 10035

@When[os == "Windows"]
public const ECONNREFUSED: Int32 = 10061

@When[os == "Windows"]
public const ECONNRESET: Int32 = 10054

@When[os == "Windows"]
public const ECONNABORTED: Int32 = 10053

@When[os == "Windows"]
public const SHUT_RDWR: Int32 = 2

@When[os == "Windows"]
public const SHUT_WR: Int32 = 1

@When[os == "Windows"]
public const AI_PASSIVE: Int32 = 0x0001

@When[os == "Windows"]
public const AI_NUMERICSERV: Int32 = 0x0008

@When[os == "Windows"]
public const SOCKADDR_STORAGE_SIZE: Int64 = 128

@When[os == "Windows"]
const FIONBIO: Int32 = -2147195266

@When[os == "Windows"]
const INVALID_SOCKET: UIntNative = 0xFFFFFFFFFFFFFFFF

@When[os == "Windows"]
const FORMAT_MESSAGE_FROM_SYSTEM: UInt32 = 0x1000

@When[os == "Windows"]
const FORMAT_MESSAGE_IGNORE_INSERTS: UInt32 = 0x0200

@When[os == "Windows"]
foreign func WSAStartup(version: UInt16, data: CPointer<CWsaData>): Int32

@When[os == "Windows"]
foreign func WSACleanup(): Int32

@When[os == "Windows"]
foreign func WSAGetLastError(): Int32

@When[os == "Windows"]
foreign func WSAPoll(fds: CPointer<CPollFd>, nfds: UInt32, timeout: Int32): Int32

@When[os == "Windows"]
foreign func socket(domain: Int32, ty: Int32, protocol: Int32): UIntNative

@When[os == "Windows"]
foreign func connect(s: UIntNative, addr: CPointer<UInt8>, addrlen: Int32): Int32

@When[os == "Windows"]
foreign func bind(s: UIntNative, addr: CPointer<UInt8>, addrlen: Int32): Int32

@When[os == "Windows"]
foreign func listen(s: UIntNative, backlog: Int32): Int32

@When[os == "Windows"]
foreign func accept(s: UIntNative, addr: CPointer<UInt8>, addrlen: CPointer<Int32>): UIntNative

@When[os == "Windows"]
foreign func getsockname(s: UIntNative, addr: CPointer<UInt8>, addrlen: CPointer<Int32>): Int32

@When[os == "Windows"]
foreign func recv(s: UIntNative, buf: CPointer<UInt8>, len: Int32, flags: Int32): Int32

@When[os == "Windows"]
foreign func send(s: UIntNative, buf: CPointer<UInt8>, len: Int32, flags: Int32): Int32

@When[os == "Windows"]
foreign func closesocket(s: UIntNative): Int32

@When[os == "Windows"]
foreign func shutdown(s: UIntNative, how: Int32): Int32

@When[os == "Windows"]
foreign func ioctlsocket(s: UIntNative, cmd: Int32, argp: CPointer<UInt32>): Int32

@When[os == "Windows"]
foreign func getsockopt(s: UIntNative, level: Int32, optname: Int32, optval: CPointer<Int32>,
                        optlen: CPointer<Int32>): Int32

@When[os == "Windows"]
foreign func setsockopt(s: UIntNative, level: Int32, optname: Int32, optval: CPointer<Int32>,
                        optlen: Int32): Int32

@When[os == "Windows"]
foreign func getaddrinfo(node: CString, service: CString, hints: CPointer<CAddrInfo>,
                         res: CPointer<CPointer<CAddrInfo>>): Int32

@When[os == "Windows"]
foreign func freeaddrinfo(res: CPointer<CAddrInfo>): Unit

@When[os == "Windows"]
foreign func FormatMessageA(flags: UInt32, source: CPointer<UInt8>, messageId: UInt32,
                            languageId: UInt32, buffer: CPointer<UInt8>, size: UInt32,
                            args: CPointer<UInt8>): UInt32

@When[os == "Windows"]
class WinsockRuntime {
    static let lock = Mutex()
    static var started = false

    static func ensure(): Unit {
        synchronized(lock) {
            if (started) {
                return
            }
            unsafe {
                let d = LibC.malloc<CWsaData>(count: 1)
                if (d.isNull()) {
                    return
                }
                d.write(0, CWsaData())
                WSAStartup(0x0202, d)
                LibC.free(d)
            }
            started = true
        }
    }
}

@When[os == "Windows"]
public func sysNetInit(): Unit {
    WinsockRuntime.ensure()
}

@When[os == "Windows"]
func toSocket(fd: Int32): UIntNative {
    if (fd < 0) {
        return INVALID_SOCKET
    }
    return UIntNative(UInt32(fd))
}

@When[os == "Windows"]
func fromSocket(s: UIntNative): Int32 {
    if (s == INVALID_SOCKET) {
        return -1
    }
    return Int32(UInt32(s & 0xFFFFFFFF))
}

@When[os == "Windows"]
func setNonBlocking(s: UIntNative): Bool {
    unsafe {
        let flag = LibC.malloc<UInt32>(count: 1)
        if (flag.isNull()) {
            return false
        }
        flag.write(0, 1)
        let rc = ioctlsocket(s, FIONBIO, flag)
        LibC.free(flag)
        return rc == 0
    }
}

@When[os == "Windows"]
public func errno(): Int32 {
    unsafe { return WSAGetLastError() }
}

@When[os == "Windows"]
public func errnoMessage(e: Int32): String {
    unsafe {
        let size: Int64 = 512
        let buf = LibC.malloc<UInt8>(count: size)
        if (buf.isNull()) {
            return "error ${e}"
        }
        let n = FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                               CPointer<UInt8>(), UInt32(e), 0, buf, UInt32(size),
                               CPointer<UInt8>())
        var out = "error ${e}"
        if (n > 0) {
            var end = Int64(n)
            while (end > 0) {
                let c = buf.read(end - 1)
                if (c == 13 || c == 10 || c == 32 || c == 46) {
                    end -= 1
                } else {
                    break
                }
            }
            let bytes = Array<UInt8>(end, repeat: 0)
            for (i in 0..end) {
                bytes[i] = buf.read(i)
            }
            out = String.fromUtf8(bytes)
        }
        LibC.free(buf)
        return out
    }
}

@When[os == "Windows"]
public func gaiMessage(code: Int32): String {
    return errnoMessage(code)
}

@When[os == "Windows"]
public func sysSocket(domain: Int32, ty: Int32, protocol: Int32): Int32 {
    WinsockRuntime.ensure()
    let nonBlocking = (ty & SOCK_NONBLOCK) != 0
    let baseType = ty & (!SOCK_NONBLOCK)
    unsafe {
        let s = socket(domain, baseType, protocol)
        if (s == INVALID_SOCKET) {
            return -1
        }
        if (nonBlocking && !setNonBlocking(s)) {
            closesocket(s)
            return -1
        }
        return fromSocket(s)
    }
}

@When[os == "Windows"]
public func sysSocketStreamNonBlocking(domain: Int32): Int32 {
    return sysSocket(domain, SOCK_STREAM | SOCK_NONBLOCK, IPPROTO_TCP)
}

@When[os == "Windows"]
public func sysConnect(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32 {
    unsafe { return connect(toSocket(fd), addr, Int32(addrlen)) }
}

@When[os == "Windows"]
public func sysBind(fd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32 {
    unsafe { return bind(toSocket(fd), addr, Int32(addrlen)) }
}

@When[os == "Windows"]
public func sysListen(fd: Int32, backlog: Int32): Int32 {
    unsafe { return listen(toSocket(fd), backlog) }
}

@When[os == "Windows"]
public func sysAcceptNonBlocking(fd: Int32): Int32 {
    unsafe {
        let addr = LibC.malloc<UInt8>(count: SOCKADDR_STORAGE_SIZE)
        let len = LibC.malloc<Int32>(count: 1)
        if (addr.isNull() || len.isNull()) {
            return -1
        }
        len.write(0, Int32(SOCKADDR_STORAGE_SIZE))
        let accepted = accept(toSocket(fd), addr, len)
        LibC.free(addr)
        LibC.free(len)
        if (accepted == INVALID_SOCKET) {
            return -1
        }
        if (!setNonBlocking(accepted)) {
            closesocket(accepted)
            return -1
        }
        return fromSocket(accepted)
    }
}

@When[os == "Windows"]
public func sysBoundPort(fd: Int32): UInt16 {
    unsafe {
        let addr = LibC.malloc<UInt8>(count: SOCKADDR_STORAGE_SIZE)
        let len = LibC.malloc<Int32>(count: 1)
        if (addr.isNull() || len.isNull()) {
            return 0
        }
        len.write(0, Int32(SOCKADDR_STORAGE_SIZE))
        let rc = getsockname(toSocket(fd), addr, len)
        var port: UInt16 = 0
        if (rc == 0 && len.read(0) >= 4) {
            port = (UInt16(addr.read(2)) << 8) | UInt16(addr.read(3))
        }
        LibC.free(addr)
        LibC.free(len)
        return port
    }
}

@When[os == "Windows"]
public func sysRead(fd: Int32, buf: Array<UInt8>): Int64 {
    unsafe {
        let h = acquireArrayRawData(buf)
        let n = recv(toSocket(fd), h.pointer, Int32(buf.size), 0)
        releaseArrayRawData(h)
        return Int64(n)
    }
}

@When[os == "Windows"]
public func sysWrite(fd: Int32, data: Array<UInt8>): Int64 {
    if (data.size == 0) {
        return 0
    }
    unsafe {
        let h = acquireArrayRawData(data)
        let n = send(toSocket(fd), h.pointer, Int32(data.size), 0)
        releaseArrayRawData(h)
        return Int64(n)
    }
}

@When[os == "Windows"]
public func sysClose(fd: Int32): Int32 {
    unsafe { return closesocket(toSocket(fd)) }
}

@When[os == "Windows"]
public func sysShutdown(fd: Int32, how: Int32): Int32 {
    unsafe { return shutdown(toSocket(fd), how) }
}

@When[os == "Windows"]
public func sysGetaddrinfo(node: CString, service: CString, hints: CPointer<CAddrInfo>,
                           res: CPointer<CPointer<CAddrInfo>>): Int32 {
    WinsockRuntime.ensure()
    unsafe { return getaddrinfo(node, service, hints, res) }
}

@When[os == "Windows"]
public func sysFreeaddrinfo(res: CPointer<CAddrInfo>): Unit {
    unsafe { freeaddrinfo(res) }
}

@When[os == "Windows"]
public func pollOne(fd: Int32, events: Int16, timeoutMs: Int32): Int32 {
    WinsockRuntime.ensure()
    var pfd = CPollFd()
    pfd.fd = toSocket(fd)
    pfd.events = events
    pfd.revents = 0
    unsafe {
        let p = LibC.malloc<CPollFd>(count: 1)
        if (p.isNull()) {
            return -1
        }
        p.write(0, pfd)
        let rc = WSAPoll(p, 1, timeoutMs)
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

@When[os == "Windows"]
public func pollMany(fds: Array<Int32>, events: Array<Int16>, timeoutMs: Int32): Array<Int16> {
    let count = fds.size
    let out = Array<Int16>(count, repeat: 0)
    if (count == 0) {
        return out
    }
    WinsockRuntime.ensure()
    unsafe {
        let p = LibC.malloc<CPollFd>(count: count)
        if (p.isNull()) {
            return out
        }
        for (i in 0..count) {
            var pfd = CPollFd()
            pfd.fd = toSocket(fds[i])
            pfd.events = events[i]
            pfd.revents = 0
            p.write(i, pfd)
        }
        let rc = WSAPoll(p, UInt32(count), timeoutMs)
        if (rc > 0) {
            for (i in 0..count) {
                out[i] = p.read(i).revents
            }
        }
        LibC.free(p)
        return out
    }
}

@When[os == "Windows"]
public func soError(fd: Int32): Int32 {
    unsafe {
        let val = LibC.malloc<Int32>(count: 1)
        let len = LibC.malloc<Int32>(count: 1)
        if (val.isNull() || len.isNull()) {
            return -1
        }
        val.write(0, 0)
        len.write(0, 4)
        let rc = getsockopt(toSocket(fd), SOL_SOCKET, SO_ERROR, val, len)
        let out = if (rc == 0) { val.read(0) } else { errno() }
        LibC.free(val)
        LibC.free(len)
        return out
    }
}

@When[os == "Windows"]
public func setIntSockOpt(fd: Int32, level: Int32, optname: Int32, value: Int32): Int32 {
    unsafe {
        let val = LibC.malloc<Int32>(count: 1)
        if (val.isNull()) {
            return -1
        }
        val.write(0, value)
        let rc = setsockopt(toSocket(fd), level, optname, val, 4)
        LibC.free(val)
        return rc
    }
}
