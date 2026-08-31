package glyphnet.transport

import glyphnet.ffi.*
import glyphnet.errors.*
import std.collection.*

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

func resolveAddresses(host: String, port: UInt16, forListening: Bool): Array<ResolvedAddr> {
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
        if (forListening) {
            hints.aiFlags |= AI_PASSIVE
        }
        hintsPtr.write(0, hints)
        resPtr.write(0, CPointer<CAddrInfo>())

        let nodeArg = if (host.isEmpty()) { CString(CPointer<UInt8>()) } else { node }
        let rc = sysGetaddrinfo(nodeArg, service, hintsPtr, resPtr)
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
