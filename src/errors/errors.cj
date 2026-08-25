package glyphnet.errors

public open class GlyphNetException <: Exception {
    public init(message: String) {
        super(message)
    }
}

public class ConnectionException <: GlyphNetException {
    public let errnoValue: Int32

    public init(message: String) {
        this(message, 0)
    }

    public init(message: String, errnoValue: Int32) {
        super(message)
        this.errnoValue = errnoValue
    }
}

public open class SshException <: GlyphNetException {
    public let code: Int32
    public let detail: String

    public init(message: String) {
        this(message, 0, "")
    }

    public init(message: String, code: Int32, detail: String) {
        super(formatMessage(message, code, detail))
        this.code = code
        this.detail = detail
    }
}

public class AuthenticationException <: SshException {
    public init(message: String) {
        this(message, 0, "")
    }

    public init(message: String, code: Int32, detail: String) {
        super(message, code, detail)
    }
}

public class HostKeyException <: SshException {
    public init(message: String) {
        super(message, 0, "")
    }
}

public class SshTimeoutException <: GlyphNetException {
    public init(message: String) {
        super(message)
    }
}

public class CommandException <: GlyphNetException {
    public init(message: String) {
        super(message)
    }
}

func formatMessage(message: String, code: Int32, detail: String): String {
    if (code == 0 && detail.isEmpty()) {
        return message
    }
    let sb = StringBuilder()
    sb.append(message)
    sb.append(" (libssh2 ")
    sb.append(code.toString())
    let name = errorCodeName(code)
    if (!name.isEmpty()) {
        sb.append(" ")
        sb.append(name)
    }
    if (!detail.isEmpty()) {
        sb.append(": ")
        sb.append(detail)
    }
    sb.append(")")
    return sb.toString()
}

public func errorCodeName(code: Int32): String {
    return match (code) {
        case 0 => "LIBSSH2_ERROR_NONE"
        case -2 => "LIBSSH2_ERROR_BANNER_RECV"
        case -3 => "LIBSSH2_ERROR_BANNER_SEND"
        case -5 => "LIBSSH2_ERROR_KEX_FAILURE"
        case -6 => "LIBSSH2_ERROR_ALLOC"
        case -7 => "LIBSSH2_ERROR_SOCKET_SEND"
        case -8 => "LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE"
        case -9 => "LIBSSH2_ERROR_TIMEOUT"
        case -13 => "LIBSSH2_ERROR_SOCKET_DISCONNECT"
        case -14 => "LIBSSH2_ERROR_PROTO"
        case -16 => "LIBSSH2_ERROR_FILE"
        case -17 => "LIBSSH2_ERROR_METHOD_NONE"
        case -18 => "LIBSSH2_ERROR_AUTHENTICATION_FAILED"
        case -20 => "LIBSSH2_ERROR_CHANNEL_FAILURE"
        case -21 => "LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED"
        case -25 => "LIBSSH2_ERROR_CHANNEL_CLOSED"
        case -37 => "LIBSSH2_ERROR_EAGAIN"
        case -43 => "LIBSSH2_ERROR_SOCKET_RECV"
        case -45 => "LIBSSH2_ERROR_BAD_SOCKET"
        case -48 => "LIBSSH2_ERROR_KEYFILE_AUTH_FAILED"
        case _ => ""
    }
}
