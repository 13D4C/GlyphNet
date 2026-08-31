package glyphnet.ffi

public const LIBSSH2_ERROR_NONE: Int32 = 0
public const LIBSSH2_ERROR_SOCKET_NONE: Int32 = -1
public const LIBSSH2_ERROR_BANNER_RECV: Int32 = -2
public const LIBSSH2_ERROR_BANNER_SEND: Int32 = -3
public const LIBSSH2_ERROR_INVALID_MAC: Int32 = -4
public const LIBSSH2_ERROR_KEX_FAILURE: Int32 = -5
public const LIBSSH2_ERROR_ALLOC: Int32 = -6
public const LIBSSH2_ERROR_SOCKET_SEND: Int32 = -7
public const LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE: Int32 = -8
public const LIBSSH2_ERROR_TIMEOUT: Int32 = -9
public const LIBSSH2_ERROR_HOSTKEY_INIT: Int32 = -10
public const LIBSSH2_ERROR_HOSTKEY_SIGN: Int32 = -11
public const LIBSSH2_ERROR_DECRYPT: Int32 = -12
public const LIBSSH2_ERROR_SOCKET_DISCONNECT: Int32 = -13
public const LIBSSH2_ERROR_PROTO: Int32 = -14
public const LIBSSH2_ERROR_PASSWORD_EXPIRED: Int32 = -15
public const LIBSSH2_ERROR_FILE: Int32 = -16
public const LIBSSH2_ERROR_METHOD_NONE: Int32 = -17
public const LIBSSH2_ERROR_AUTHENTICATION_FAILED: Int32 = -18
public const LIBSSH2_ERROR_CHANNEL_OUTOFORDER: Int32 = -19
public const LIBSSH2_ERROR_CHANNEL_FAILURE: Int32 = -20
public const LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED: Int32 = -21
public const LIBSSH2_ERROR_CHANNEL_UNKNOWN: Int32 = -22
public const LIBSSH2_ERROR_CHANNEL_WINDOW_EXCEEDED: Int32 = -23
public const LIBSSH2_ERROR_CHANNEL_PACKET_EXCEEDED: Int32 = -24
public const LIBSSH2_ERROR_CHANNEL_CLOSED: Int32 = -25
public const LIBSSH2_ERROR_CHANNEL_EOF_SENT: Int32 = -26
public const LIBSSH2_ERROR_SCP_PROTOCOL: Int32 = -27
public const LIBSSH2_ERROR_ZLIB: Int32 = -28
public const LIBSSH2_ERROR_SOCKET_TIMEOUT: Int32 = -29
public const LIBSSH2_ERROR_SFTP_PROTOCOL: Int32 = -31
public const LIBSSH2_ERROR_REQUEST_DENIED: Int32 = -32
public const LIBSSH2_ERROR_METHOD_NOT_SUPPORTED: Int32 = -33
public const LIBSSH2_ERROR_INVAL: Int32 = -34
public const LIBSSH2_ERROR_INVALID_POLL_TYPE: Int32 = -35
public const LIBSSH2_ERROR_PUBLICKEY_PROTOCOL: Int32 = -36
public const LIBSSH2_ERROR_EAGAIN: Int32 = -37
public const LIBSSH2_ERROR_BUFFER_TOO_SMALL: Int32 = -38
public const LIBSSH2_ERROR_BAD_USE: Int32 = -39
public const LIBSSH2_ERROR_COMPRESS: Int32 = -40
public const LIBSSH2_ERROR_OUT_OF_BOUNDARY: Int32 = -41
public const LIBSSH2_ERROR_AGENT_PROTOCOL: Int32 = -42
public const LIBSSH2_ERROR_SOCKET_RECV: Int32 = -43
public const LIBSSH2_ERROR_ENCRYPT: Int32 = -44
public const LIBSSH2_ERROR_BAD_SOCKET: Int32 = -45
public const LIBSSH2_ERROR_KNOWN_HOSTS: Int32 = -46
public const LIBSSH2_ERROR_CHANNEL_WINDOW_FULL: Int32 = -47
public const LIBSSH2_ERROR_KEYFILE_AUTH_FAILED: Int32 = -48

public const LIBSSH2_CHANNEL_WINDOW_DEFAULT: UInt32 = 2097152
public const LIBSSH2_CHANNEL_PACKET_DEFAULT: UInt32 = 32768

public const LIBSSH2_SESSION_BLOCK_INBOUND: Int32 = 1
public const LIBSSH2_SESSION_BLOCK_OUTBOUND: Int32 = 2

public const LIBSSH2_HOSTKEY_HASH_MD5: Int32 = 1
public const LIBSSH2_HOSTKEY_HASH_SHA1: Int32 = 2
public const LIBSSH2_HOSTKEY_HASH_SHA256: Int32 = 3

public const LIBSSH2_HOSTKEY_TYPE_UNKNOWN: Int32 = 0
public const LIBSSH2_HOSTKEY_TYPE_RSA: Int32 = 1
public const LIBSSH2_HOSTKEY_TYPE_DSS: Int32 = 2
public const LIBSSH2_HOSTKEY_TYPE_ECDSA_256: Int32 = 3
public const LIBSSH2_HOSTKEY_TYPE_ECDSA_384: Int32 = 4
public const LIBSSH2_HOSTKEY_TYPE_ECDSA_521: Int32 = 5
public const LIBSSH2_HOSTKEY_TYPE_ED25519: Int32 = 6

public const SSH_DISCONNECT_BY_APPLICATION: Int32 = 11

public const LIBSSH2_CHANNEL_EXTENDED_DATA_NORMAL: Int32 = 0
public const LIBSSH2_CHANNEL_EXTENDED_DATA_IGNORE: Int32 = 1
public const LIBSSH2_CHANNEL_EXTENDED_DATA_MERGE: Int32 = 2

public const LIBSSH2_INIT_NO_CRYPTO: Int32 = 1

foreign func libssh2_init(flags: Int32): Int32
foreign func libssh2_exit(): Unit
foreign func libssh2_version(requiredVersion: Int32): CString
foreign func libssh2_free(session: CPointer<Unit>, ptr: CPointer<Unit>): Unit

foreign func libssh2_session_init_ex(myAlloc: CPointer<Unit>, myFree: CPointer<Unit>,
                                     myRealloc: CPointer<Unit>, abstract: CPointer<Unit>): CPointer<Unit>
foreign func libssh2_session_handshake(session: CPointer<Unit>, sock: Int32): Int32
foreign func libssh2_session_free(session: CPointer<Unit>): Int32
foreign func libssh2_session_disconnect_ex(session: CPointer<Unit>, reason: Int32,
                                           description: CString, lang: CString): Int32
foreign func libssh2_session_set_blocking(session: CPointer<Unit>, blocking: Int32): Unit
foreign func libssh2_session_get_blocking(session: CPointer<Unit>): Int32
foreign func libssh2_session_set_timeout(session: CPointer<Unit>, timeout: Int64): Unit
foreign func libssh2_session_get_timeout(session: CPointer<Unit>): Int64
foreign func libssh2_session_banner_get(session: CPointer<Unit>): CPointer<UInt8>
foreign func libssh2_session_banner_set(session: CPointer<Unit>, banner: CString): Int32
foreign func libssh2_session_block_directions(session: CPointer<Unit>): Int32

foreign func libssh2_session_last_errno(session: CPointer<Unit>): Int32
foreign func libssh2_session_last_error(session: CPointer<Unit>, errmsg: CPointer<CPointer<UInt8>>,
                                        errmsgLen: CPointer<Int32>, wantBuf: Int32): Int32

foreign func libssh2_session_hostkey(session: CPointer<Unit>, len: CPointer<UIntNative>,
                                     ty: CPointer<Int32>): CPointer<UInt8>
foreign func libssh2_hostkey_hash(session: CPointer<Unit>, hashType: Int32): CPointer<UInt8>

foreign func libssh2_userauth_list(session: CPointer<Unit>, username: CString,
                                   usernameLen: UInt32): CPointer<UInt8>
foreign func libssh2_userauth_authenticated(session: CPointer<Unit>): Int32
foreign func libssh2_userauth_password_ex(session: CPointer<Unit>, username: CString,
                                          usernameLen: UInt32, password: CString,
                                          passwordLen: UInt32,
                                          passwdChangeCb: CPointer<Unit>): Int32
foreign func libssh2_userauth_publickey_fromfile_ex(session: CPointer<Unit>, username: CString,
                                                    usernameLen: UInt32, publickey: CString,
                                                    privatekey: CString, passphrase: CString): Int32

foreign func libssh2_channel_open_ex(session: CPointer<Unit>, channelType: CString,
                                     channelTypeLen: UInt32, windowSize: UInt32,
                                     packetSize: UInt32, message: CString,
                                     messageLen: UInt32): CPointer<Unit>
foreign func libssh2_channel_process_startup(channel: CPointer<Unit>, request: CString,
                                             requestLen: UInt32, message: CString,
                                             messageLen: UInt32): Int32
foreign func libssh2_channel_request_pty_ex(channel: CPointer<Unit>, term: CString, termLen: UInt32,
                                            modes: CString, modesLen: UInt32, width: Int32,
                                            height: Int32, widthPx: Int32, heightPx: Int32): Int32
foreign func libssh2_channel_read_ex(channel: CPointer<Unit>, streamId: Int32,
                                     buf: CPointer<UInt8>, buflen: UIntNative): IntNative
foreign func libssh2_channel_write_ex(channel: CPointer<Unit>, streamId: Int32,
                                      buf: CPointer<UInt8>, buflen: UIntNative): IntNative
foreign func libssh2_channel_eof(channel: CPointer<Unit>): Int32
foreign func libssh2_channel_send_eof(channel: CPointer<Unit>): Int32
foreign func libssh2_channel_close(channel: CPointer<Unit>): Int32
foreign func libssh2_channel_wait_closed(channel: CPointer<Unit>): Int32
foreign func libssh2_channel_free(channel: CPointer<Unit>): Int32
foreign func libssh2_channel_get_exit_status(channel: CPointer<Unit>): Int32
foreign func libssh2_channel_set_blocking(channel: CPointer<Unit>, blocking: Int32): Unit
foreign func libssh2_channel_handle_extended_data2(channel: CPointer<Unit>, mode: Int32): Int32
foreign func libssh2_channel_direct_tcpip_ex(session: CPointer<Unit>, host: CString, port: Int32,
                                             shost: CString, sport: Int32): CPointer<Unit>
foreign func libssh2_channel_forward_listen_ex(session: CPointer<Unit>, host: CString, port: Int32,
                                               boundPort: CPointer<Int32>,
                                               queueMaxsize: Int32): CPointer<Unit>
foreign func libssh2_channel_forward_accept(listener: CPointer<Unit>): CPointer<Unit>
foreign func libssh2_channel_forward_cancel(listener: CPointer<Unit>): Int32
foreign func libssh2_keepalive_config(session: CPointer<Unit>, wantReply: Int32,
                                      interval: UInt32): Unit
foreign func libssh2_scp_send64(session: CPointer<Unit>, path: CString, mode: Int32, size: Int64,
                                mtime: Int64, atime: Int64): CPointer<Unit>
foreign func libssh2_scp_recv2(session: CPointer<Unit>, path: CString,
                               sb: CPointer<UInt8>): CPointer<Unit>

public func ssh2Init(): Int32 {
    unsafe { return libssh2_init(0) }
}

public func ssh2Exit(): Unit {
    unsafe { libssh2_exit() }
}

public func ssh2Version(): String {
    unsafe { return libssh2_version(0).toString() }
}

public func ssh2SessionInit(): CPointer<Unit> {
    unsafe {
        return libssh2_session_init_ex(CPointer<Unit>(), CPointer<Unit>(), CPointer<Unit>(),
                                       CPointer<Unit>())
    }
}

public func ssh2SessionHandshake(session: CPointer<Unit>, fd: Int32): Int32 {
    unsafe { return libssh2_session_handshake(session, fd) }
}

public func ssh2SessionFree(session: CPointer<Unit>): Int32 {
    unsafe { return libssh2_session_free(session) }
}

public func ssh2SessionDisconnect(session: CPointer<Unit>, description: String): Int32 {
    unsafe {
        let d = LibC.mallocCString(description)
        let l = LibC.mallocCString("")
        let rc = libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, d, l)
        LibC.free(d)
        LibC.free(l)
        return rc
    }
}

public func ssh2SessionSetBlocking(session: CPointer<Unit>, blocking: Bool): Unit {
    unsafe { libssh2_session_set_blocking(session, if (blocking) { 1 } else { 0 }) }
}

public func ssh2SessionSetTimeout(session: CPointer<Unit>, timeoutMs: Int64): Unit {
    unsafe { libssh2_session_set_timeout(session, timeoutMs) }
}

public func ssh2SessionGetTimeout(session: CPointer<Unit>): Int64 {
    unsafe { return libssh2_session_get_timeout(session) }
}

public func ssh2SessionBlockDirections(session: CPointer<Unit>): Int32 {
    unsafe { return libssh2_session_block_directions(session) }
}

public func ssh2SessionLastErrno(session: CPointer<Unit>): Int32 {
    unsafe { return libssh2_session_last_errno(session) }
}

public func ssh2SessionLastError(session: CPointer<Unit>): (Int32, String) {
    if (session.isNull()) {
        return (LIBSSH2_ERROR_NONE, "")
    }
    unsafe {
        let msgPtr = LibC.malloc<CPointer<UInt8>>(count: 1)
        let lenPtr = LibC.malloc<Int32>(count: 1)
        if (msgPtr.isNull() || lenPtr.isNull()) {
            return (LIBSSH2_ERROR_ALLOC, "out of memory reading libssh2 error")
        }
        msgPtr.write(0, CPointer<UInt8>())
        lenPtr.write(0, 0)
        let code = libssh2_session_last_error(session, msgPtr, lenPtr, 0)
        let raw = msgPtr.read(0)
        let len = Int64(lenPtr.read(0))
        var msg = ""
        if (!raw.isNull() && len > 0) {
            msg = readCBytes(raw, len)
        }
        LibC.free(msgPtr)
        LibC.free(lenPtr)
        return (code, msg)
    }
}

public func ssh2SessionBanner(session: CPointer<Unit>): String {
    unsafe {
        let p = libssh2_session_banner_get(session)
        if (p.isNull()) {
            return ""
        }
        return readCStringZ(p)
    }
}

public func ssh2SessionHostkey(session: CPointer<Unit>): (Array<UInt8>, Int32) {
    unsafe {
        let lenPtr = LibC.malloc<UIntNative>(count: 1)
        let tyPtr = LibC.malloc<Int32>(count: 1)
        if (lenPtr.isNull() || tyPtr.isNull()) {
            return (Array<UInt8>(), LIBSSH2_HOSTKEY_TYPE_UNKNOWN)
        }
        lenPtr.write(0, 0)
        tyPtr.write(0, LIBSSH2_HOSTKEY_TYPE_UNKNOWN)
        let p = libssh2_session_hostkey(session, lenPtr, tyPtr)
        let len = Int64(lenPtr.read(0))
        let ty = tyPtr.read(0)
        LibC.free(lenPtr)
        LibC.free(tyPtr)
        if (p.isNull() || len <= 0) {
            return (Array<UInt8>(), ty)
        }
        let out = Array<UInt8>(len, repeat: 0)
        for (i in 0..len) {
            out[i] = p.read(i)
        }
        return (out, ty)
    }
}

public func ssh2HostkeyHash(session: CPointer<Unit>, hashType: Int32): Array<UInt8> {
    let len = match (hashType) {
        case 1 => 16
        case 2 => 20
        case 3 => 32
        case _ => 0
    }
    if (len == 0) {
        return Array<UInt8>()
    }
    unsafe {
        let p = libssh2_hostkey_hash(session, hashType)
        if (p.isNull()) {
            return Array<UInt8>()
        }
        let out = Array<UInt8>(len, repeat: 0)
        for (i in 0..len) {
            out[i] = p.read(i)
        }
        return out
    }
}

public func ssh2UserauthList(session: CPointer<Unit>, username: String): String {
    unsafe {
        let u = LibC.mallocCString(username)
        let p = libssh2_userauth_list(session, u, UInt32(username.size))
        LibC.free(u)
        if (p.isNull()) {
            return ""
        }
        return readCStringZ(p)
    }
}

public func ssh2UserauthAuthenticated(session: CPointer<Unit>): Bool {
    unsafe { return libssh2_userauth_authenticated(session) == 1 }
}

public func ssh2UserauthPassword(session: CPointer<Unit>, username: String, password: String): Int32 {
    unsafe {
        let u = LibC.mallocCString(username)
        let p = LibC.mallocCString(password)
        let rc = libssh2_userauth_password_ex(session, u, UInt32(username.size), p,
                                              UInt32(password.size), CPointer<Unit>())
        LibC.free(u)
        LibC.free(p)
        return rc
    }
}

public func ssh2UserauthPublicKeyFromFile(session: CPointer<Unit>, username: String,
                                          publicKeyPath: String, privateKeyPath: String,
                                          passphrase: String): Int32 {
    unsafe {
        let u = LibC.mallocCString(username)
        let pub = LibC.mallocCString(publicKeyPath)
        let priv = LibC.mallocCString(privateKeyPath)
        let pass = LibC.mallocCString(passphrase)

        let pubArg = if (publicKeyPath.isEmpty()) { CString(CPointer<UInt8>()) } else { pub }
        let passArg = if (passphrase.isEmpty()) { CString(CPointer<UInt8>()) } else { pass }
        let rc = libssh2_userauth_publickey_fromfile_ex(session, u, UInt32(username.size), pubArg,
                                                        priv, passArg)
        LibC.free(u)
        LibC.free(pub)
        LibC.free(priv)
        LibC.free(pass)
        return rc
    }
}

public func ssh2ChannelOpenSession(session: CPointer<Unit>): CPointer<Unit> {
    unsafe {
        let ty = LibC.mallocCString("session")
        let msg = CString(CPointer<UInt8>())
        let ch = libssh2_channel_open_ex(session, ty, 7, LIBSSH2_CHANNEL_WINDOW_DEFAULT,
                                         LIBSSH2_CHANNEL_PACKET_DEFAULT, msg, 0)
        LibC.free(ty)
        return ch
    }
}

public func ssh2ChannelProcessStartup(channel: CPointer<Unit>, request: String,
                                      message: String): Int32 {
    unsafe {
        let r = LibC.mallocCString(request)
        let m = LibC.mallocCString(message)
        let mArg = if (message.isEmpty()) { CString(CPointer<UInt8>()) } else { m }
        let rc = libssh2_channel_process_startup(channel, r, UInt32(request.size), mArg,
                                                 UInt32(message.size))
        LibC.free(r)
        LibC.free(m)
        return rc
    }
}

public func ssh2ChannelRequestPty(channel: CPointer<Unit>, term: String, width: Int32,
                                  height: Int32): Int32 {
    unsafe {
        let t = LibC.mallocCString(term)
        let modes = CString(CPointer<UInt8>())
        let rc = libssh2_channel_request_pty_ex(channel, t, UInt32(term.size), modes, 0, width,
                                                height, 0, 0)
        LibC.free(t)
        return rc
    }
}

public func ssh2ChannelRead(channel: CPointer<Unit>, streamId: Int32, buf: Array<UInt8>): Int64 {
    unsafe {
        let h = acquireArrayRawData(buf)
        let n = libssh2_channel_read_ex(channel, streamId, h.pointer, UIntNative(buf.size))
        releaseArrayRawData(h)
        return Int64(n)
    }
}

public func ssh2ChannelWrite(channel: CPointer<Unit>, streamId: Int32, data: Array<UInt8>): Int64 {
    unsafe {
        let h = acquireArrayRawData(data)
        let n = libssh2_channel_write_ex(channel, streamId, h.pointer, UIntNative(data.size))
        releaseArrayRawData(h)
        return Int64(n)
    }
}

public func ssh2ChannelEof(channel: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_eof(channel) }
}

public func ssh2ChannelSendEof(channel: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_send_eof(channel) }
}

public func ssh2ChannelClose(channel: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_close(channel) }
}

public func ssh2ChannelWaitClosed(channel: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_wait_closed(channel) }
}

public func ssh2ChannelFree(channel: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_free(channel) }
}

public func ssh2ChannelExitStatus(channel: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_get_exit_status(channel) }
}

public func ssh2ChannelHandleExtendedData(channel: CPointer<Unit>, mode: Int32): Int32 {
    unsafe { return libssh2_channel_handle_extended_data2(channel, mode) }
}

public func ssh2ChannelDirectTcpip(session: CPointer<Unit>, host: String, port: UInt16,
                                   originHost: String, originPort: UInt16): CPointer<Unit> {
    unsafe {
        let h = LibC.mallocCString(host)
        let sh = LibC.mallocCString(originHost)
        let ch = libssh2_channel_direct_tcpip_ex(session, h, Int32(port), sh, Int32(originPort))
        LibC.free(h)
        LibC.free(sh)
        return ch
    }
}

public func ssh2ChannelForwardListen(session: CPointer<Unit>, bindHost: String, port: UInt16,
                                     queueMaxsize: Int32): (CPointer<Unit>, UInt16) {
    unsafe {
        let h = LibC.mallocCString(bindHost)
        let hostArg = if (bindHost.isEmpty()) { CString(CPointer<UInt8>()) } else { h }
        let boundPtr = LibC.malloc<Int32>(count: 1)
        if (boundPtr.isNull()) {
            LibC.free(h)
            return (CPointer<Unit>(), 0)
        }
        boundPtr.write(0, 0)
        let listener = libssh2_channel_forward_listen_ex(session, hostArg, Int32(port), boundPtr,
                                                         queueMaxsize)
        let bound = boundPtr.read(0)
        LibC.free(boundPtr)
        LibC.free(h)
        if (listener.isNull()) {
            return (listener, 0)
        }
        if (bound > 0 && bound < 65536) {
            return (listener, UInt16(bound))
        }
        return (listener, port)
    }
}

public func ssh2ChannelForwardAccept(listener: CPointer<Unit>): CPointer<Unit> {
    unsafe { return libssh2_channel_forward_accept(listener) }
}

public func ssh2ChannelForwardCancel(listener: CPointer<Unit>): Int32 {
    unsafe { return libssh2_channel_forward_cancel(listener) }
}

public func ssh2KeepaliveConfig(session: CPointer<Unit>, wantReply: Bool, intervalSec: UInt32): Unit {
    unsafe { libssh2_keepalive_config(session, if (wantReply) { 1 } else { 0 }, intervalSec) }
}

public const LIBSSH2_STRUCT_STAT_SIZE: Int64 = 256

public const STRUCT_STAT_SIZE_OFFSET: Int64 = 48

public func ssh2ScpSend(session: CPointer<Unit>, path: String, mode: Int32, size: Int64,
                        mtime: Int64, atime: Int64): CPointer<Unit> {
    unsafe {
        let p = LibC.mallocCString(path)
        let ch = libssh2_scp_send64(session, p, mode, size, mtime, atime)
        LibC.free(p)
        return ch
    }
}

public func ssh2ScpRecv(session: CPointer<Unit>, path: String): (CPointer<Unit>, Int64) {
    unsafe {
        let p = LibC.mallocCString(path)
        let sb = LibC.malloc<UInt8>(count: LIBSSH2_STRUCT_STAT_SIZE)
        if (sb.isNull()) {
            LibC.free(p)
            return (CPointer<Unit>(), 0)
        }
        for (i in 0..LIBSSH2_STRUCT_STAT_SIZE) {
            sb.write(i, 0)
        }
        let ch = libssh2_scp_recv2(session, p, sb)
        var size: Int64 = 0
        if (!ch.isNull()) {
            size = readLe64(sb, STRUCT_STAT_SIZE_OFFSET)
        }
        LibC.free(sb)
        LibC.free(p)
        return (ch, size)
    }
}

func readLe64(p: CPointer<UInt8>, offset: Int64): Int64 {
    unsafe {
        var v: UInt64 = 0
        var i = 7
        while (i >= 0) {
            v = (v << 8) | UInt64(p.read(offset + i))
            i -= 1
        }
        return Int64(v)
    }
}

func readCBytes(p: CPointer<UInt8>, len: Int64): String {
    unsafe {
        let bytes = Array<UInt8>(len, repeat: 0)
        for (i in 0..len) {
            bytes[i] = p.read(i)
        }
        return String.fromUtf8(bytes)
    }
}

func readCStringZ(p: CPointer<UInt8>): String {
    unsafe {
        var len = 0
        while (len < 65536) {
            if (p.read(len) == 0) {
                break
            }
            len += 1
        }
        return readCBytes(p, len)
    }
}
