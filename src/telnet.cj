package glyphnet

import glyphnet.errors.*
import glyphnet.ffi.*
import glyphnet.transport.*
import std.collection.*
import std.time.*

public const IAC: UInt8 = 255
public const DONT: UInt8 = 254
public const DO: UInt8 = 253
public const WONT: UInt8 = 252
public const WILL: UInt8 = 251
public const SB: UInt8 = 250
public const SE: UInt8 = 240

public const TELOPT_BINARY: UInt8 = 0
public const TELOPT_ECHO: UInt8 = 1
public const TELOPT_SGA: UInt8 = 3
public const TELOPT_TTYPE: UInt8 = 24
public const TELOPT_NAWS: UInt8 = 31

public const TELQUAL_IS: UInt8 = 0
public const TELQUAL_SEND: UInt8 = 1

const OPT_UNKNOWN: UInt8 = 0
const OPT_ENABLED: UInt8 = 1
const OPT_DISABLED: UInt8 = 2

const PARSE_DATA: UInt8 = 0
const PARSE_IAC: UInt8 = 1
const PARSE_VERB: UInt8 = 2
const PARSE_SUBNEG: UInt8 = 3
const PARSE_SUBNEG_IAC: UInt8 = 4

const TELNET_READ_BUFFER_SIZE: Int64 = 32768
const TELNET_POLL_SLICE_MS: Int64 = 50

public func telnetOptionName(option: UInt8): String {
    return match (option) {
        case 0 => "BINARY"
        case 1 => "ECHO"
        case 3 => "SUPPRESS-GO-AHEAD"
        case 5 => "STATUS"
        case 24 => "TERMINAL-TYPE"
        case 31 => "NAWS"
        case 32 => "TERMINAL-SPEED"
        case 33 => "TOGGLE-FLOW-CONTROL"
        case 34 => "LINEMODE"
        case 39 => "NEW-ENVIRON"
        case _ => "OPTION-${option}"
    }
}

public func encodeTelnetData(bytes: Array<UInt8>): Array<UInt8> {
    let out = ArrayList<UInt8>()
    var previous: UInt8 = 0
    for (b in bytes) {
        if (b == IAC) {
            out.add(IAC)
            out.add(IAC)
        } else if (b == UInt8(10) && previous != UInt8(13)) {
            out.add(UInt8(13))
            out.add(UInt8(10))
        } else {
            out.add(b)
        }
        previous = b
    }
    return out.toArray()
}

public func utf8SafeSplit(bytes: Array<UInt8>): (String, Array<UInt8>) {
    let out = ArrayList<UInt8>()
    var i = 0
    while (i < bytes.size) {
        let b = bytes[i]
        if (b < UInt8(128)) {
            out.add(b)
            i += 1
            continue
        }
        var need = 0
        if (b >= UInt8(0xC2) && b <= UInt8(0xDF)) {
            need = 1
        } else if (b >= UInt8(0xE0) && b <= UInt8(0xEF)) {
            need = 2
        } else if (b >= UInt8(0xF0) && b <= UInt8(0xF4)) {
            need = 3
        } else {
            i += 1
            continue
        }
        if (i + need >= bytes.size) {
            let leftover = Array<UInt8>(bytes.size - i, repeat: 0)
            var k = 0
            while (i + k < bytes.size) {
                leftover[k] = bytes[i + k]
                k += 1
            }
            return (String.fromUtf8(out.toArray()), leftover)
        }
        var valid = true
        var j = 1
        while (j <= need) {
            let c = bytes[i + j]
            if (c < UInt8(0x80) || c > UInt8(0xBF)) {
                valid = false
                break
            }
            j += 1
        }
        if (!valid) {
            i += 1
            continue
        }
        var k = 0
        while (k <= need) {
            out.add(bytes[i + k])
            k += 1
        }
        i += need + 1
    }
    return (String.fromUtf8(out.toArray()), Array<UInt8>())
}

public class TelnetNegotiator {
    private let remoteState = Array<UInt8>(256, repeat: OPT_UNKNOWN)
    private let localState = Array<UInt8>(256, repeat: OPT_UNKNOWN)
    private var state: UInt8 = PARSE_DATA
    private var verb: UInt8 = 0
    private var lastDataByte: UInt8 = 0
    private let subneg = ArrayList<UInt8>()

    public let terminalType: String
    public let width: Int32
    public let height: Int32
    public let offerWindowSize: Bool

    public init(terminalType: String, width: Int32, height: Int32, offerWindowSize: Bool) {
        this.terminalType = terminalType
        this.width = width
        this.height = height
        this.offerWindowSize = offerWindowSize
    }

    public func remoteEchoEnabled(): Bool {
        return remoteState[Int64(TELOPT_ECHO)] == OPT_ENABLED
    }

    public func remoteSuppressGoAhead(): Bool {
        return remoteState[Int64(TELOPT_SGA)] == OPT_ENABLED
    }

    public func localOptionEnabled(option: UInt8): Bool {
        return localState[Int64(option)] == OPT_ENABLED
    }

    func wantRemote(option: UInt8): Bool {
        return option == TELOPT_ECHO || option == TELOPT_SGA
    }

    func wantLocal(option: UInt8): Bool {
        if (option == TELOPT_SGA || option == TELOPT_TTYPE) {
            return true
        }
        return option == TELOPT_NAWS && offerWindowSize
    }

    public func feed(chunk: Array<UInt8>, length: Int64): (Array<UInt8>, Array<UInt8>) {
        let data = ArrayList<UInt8>()
        let reply = ArrayList<UInt8>()
        var i = 0
        while (i < length) {
            let b = chunk[i]
            i += 1
            if (state == PARSE_DATA) {
                if (b == IAC) {
                    state = PARSE_IAC
                } else {
                    emitData(data, b)
                }
            } else if (state == PARSE_IAC) {
                if (b == IAC) {
                    emitData(data, IAC)
                    state = PARSE_DATA
                } else if (b == WILL || b == WONT || b == DO || b == DONT) {
                    verb = b
                    state = PARSE_VERB
                } else if (b == SB) {
                    subneg.clear()
                    state = PARSE_SUBNEG
                } else {
                    state = PARSE_DATA
                }
            } else if (state == PARSE_VERB) {
                respond(verb, b, reply)
                state = PARSE_DATA
            } else if (state == PARSE_SUBNEG) {
                if (b == IAC) {
                    state = PARSE_SUBNEG_IAC
                } else {
                    subneg.add(b)
                }
            } else if (state == PARSE_SUBNEG_IAC) {
                if (b == IAC) {
                    subneg.add(IAC)
                    state = PARSE_SUBNEG
                } else if (b == SE) {
                    respondSubneg(reply)
                    state = PARSE_DATA
                } else {
                    state = PARSE_SUBNEG
                }
            } else {
                state = PARSE_DATA
            }
        }
        return (data.toArray(), reply.toArray())
    }

    private func emitData(data: ArrayList<UInt8>, b: UInt8): Unit {
        if (b == UInt8(0) && lastDataByte == UInt8(13)) {
            lastDataByte = 0
            return
        }
        data.add(b)
        lastDataByte = b
    }

    private func respond(command: UInt8, option: UInt8, reply: ArrayList<UInt8>): Unit {
        let slot = Int64(option)
        if (command == WILL) {
            let desired = if (wantRemote(option)) {
                OPT_ENABLED
            } else {
                OPT_DISABLED
            }
            if (remoteState[slot] != desired) {
                remoteState[slot] = desired
                emit(reply, if (desired == OPT_ENABLED) { DO } else { DONT }, option)
            }
            return
        }
        if (command == WONT) {
            if (remoteState[slot] != OPT_DISABLED) {
                remoteState[slot] = OPT_DISABLED
                emit(reply, DONT, option)
            }
            return
        }
        if (command == DO) {
            let desired = if (wantLocal(option)) {
                OPT_ENABLED
            } else {
                OPT_DISABLED
            }
            if (localState[slot] != desired) {
                localState[slot] = desired
                emit(reply, if (desired == OPT_ENABLED) { WILL } else { WONT }, option)
                if (desired == OPT_ENABLED && option == TELOPT_NAWS) {
                    emitWindowSize(reply)
                }
            }
            return
        }
        if (command == DONT) {
            if (localState[slot] != OPT_DISABLED) {
                localState[slot] = OPT_DISABLED
                emit(reply, WONT, option)
            }
        }
    }

    private func respondSubneg(reply: ArrayList<UInt8>): Unit {
        if (subneg.size < 2) {
            return
        }
        if (subneg[0] == TELOPT_TTYPE && subneg[1] == TELQUAL_SEND) {
            reply.add(IAC)
            reply.add(SB)
            reply.add(TELOPT_TTYPE)
            reply.add(TELQUAL_IS)
            for (b in terminalType.toArray()) {
                if (b == IAC) {
                    reply.add(IAC)
                }
                reply.add(b)
            }
            reply.add(IAC)
            reply.add(SE)
        }
    }

    private func emitWindowSize(reply: ArrayList<UInt8>): Unit {
        reply.add(IAC)
        reply.add(SB)
        reply.add(TELOPT_NAWS)
        appendEscaped(reply, UInt8((width >> 8) & 0xFF))
        appendEscaped(reply, UInt8(width & 0xFF))
        appendEscaped(reply, UInt8((height >> 8) & 0xFF))
        appendEscaped(reply, UInt8(height & 0xFF))
        reply.add(IAC)
        reply.add(SE)
    }

    private func appendEscaped(reply: ArrayList<UInt8>, b: UInt8): Unit {
        reply.add(b)
        if (b == IAC) {
            reply.add(IAC)
        }
    }

    private func emit(reply: ArrayList<UInt8>, command: UInt8, option: UInt8): Unit {
        reply.add(IAC)
        reply.add(command)
        reply.add(option)
    }
}

class TelnetStream <: CliStream {
    private let transport: TcpTransport
    private let negotiator: TelnetNegotiator
    private var leftover = Array<UInt8>()
    private var eof: Bool = false

    init(transport: TcpTransport, negotiator: TelnetNegotiator) {
        this.transport = transport
        this.negotiator = negotiator
    }

    prop options: TelnetNegotiator {
        get() {
            negotiator
        }
    }

    public func writeAll(data: String, timeoutMs: Int64): Unit {
        writeBytes(encodeTelnetData(data.toArray()), timeoutMs)
    }

    private func writeBytes(bytes: Array<UInt8>, timeoutMs: Int64): Unit {
        if (bytes.size == 0) {
            return
        }
        let deadline = MonoTime.now() + Duration.millisecond * timeoutMs
        var offset = 0
        while (offset < bytes.size) {
            let n = transport.writeSome(bytes[offset..bytes.size])
            if (n > 0) {
                offset += n
                continue
            }
            let e = errno()
            if (n < 0 && (e == EAGAIN || e == EWOULDBLOCK || e == EINTR)) {
                if (MonoTime.now() >= deadline) {
                    throw SshTimeoutException(
                        "timed out after ${timeoutMs}ms writing ${bytes.size} bytes to ${label()}")
                }
                transport.waitWritable(TELNET_POLL_SLICE_MS)
                continue
            }
            throw ConnectionException("telnet write to ${label()} failed: ${errnoMessage(e)}", e)
        }
    }

    private func label(): String {
        return "${transport.host}:${transport.port}"
    }

    private func drain(): String {
        if (eof) {
            return ""
        }
        let sb = StringBuilder()
        let buf = Array<UInt8>(TELNET_READ_BUFFER_SIZE, repeat: 0)
        while (true) {
            let n = transport.readSome(buf)
            if (n > 0) {
                let parsed = negotiator.feed(buf, n)
                if (parsed[1].size > 0) {
                    writeBytes(parsed[1], 5000)
                }
                if (parsed[0].size > 0) {
                    sb.append(decode(parsed[0]))
                }
                continue
            }
            if (n == 0) {
                eof = true
                break
            }
            let e = errno()
            if (e == EAGAIN || e == EWOULDBLOCK) {
                break
            }
            if (e == EINTR) {
                continue
            }
            if (e == ECONNRESET) {
                eof = true
                break
            }
            throw ConnectionException("telnet read from ${label()} failed: ${errnoMessage(e)}", e)
        }
        return sb.toString()
    }

    private func decode(bytes: Array<UInt8>): String {
        var input = bytes
        if (leftover.size > 0) {
            let merged = Array<UInt8>(leftover.size + bytes.size, repeat: 0)
            var i = 0
            while (i < leftover.size) {
                merged[i] = leftover[i]
                i += 1
            }
            var j = 0
            while (j < bytes.size) {
                merged[leftover.size + j] = bytes[j]
                j += 1
            }
            input = merged
        }
        let split = utf8SafeSplit(input)
        leftover = split[1]
        return split[0]
    }

    public func readAvailable(): String {
        return drain()
    }

    public func readUntil(predicate: (String) -> Bool, timeoutMs: Int64, quietMs: Int64): String {
        let sb = StringBuilder()
        let deadline = MonoTime.now() + Duration.millisecond * timeoutMs
        var lastData = MonoTime.now()
        var sawAnyData = false

        while (true) {
            let chunk = drain()
            if (!chunk.isEmpty()) {
                sb.append(chunk)
                lastData = MonoTime.now()
                sawAnyData = true
            }

            let text = sb.toString()
            if (predicate(text)) {
                return text
            }
            if (eof) {
                return text
            }
            if (MonoTime.now() >= deadline) {
                throw SshTimeoutException(
                    "timed out after ${timeoutMs}ms waiting for expected output from ${label()}; " +
                    "read ${text.size} bytes so far")
            }
            if (quietMs > 0 && sawAnyData) {
                let idle = (MonoTime.now() - lastData).toMilliseconds()
                if (idle >= quietMs) {
                    return text
                }
            }
            transport.waitReadable(TELNET_POLL_SLICE_MS)
        }
        return sb.toString()
    }

    public func isEof(): Bool {
        return eof || transport.isClosed()
    }

    public func closeStream(): Unit {
        transport.close()
    }
}

public class TelnetOptions {
    public var host: String = ""
    public var port: UInt16 = 23
    public var username: String = ""
    public var password: String = ""

    public var connectTimeoutMs: Int64 = 15000

    public var loginTimeoutMs: Int64 = 20000

    public var commandTimeoutMs: Int64 = 30000

    public var quietPeriodMs: Int64 = 300

    public var bannerSettleMs: Int64 = 800

    public var terminalType: String = "vt100"
    public var terminalWidth: Int32 = 511
    public var terminalHeight: Int32 = 4096

    public var negotiateWindowSize: Bool = true

    public var pagingCommand: String = ""

    public var deviceType: DeviceType = DeviceType.Generic

    public var autoDetectDeviceType: Bool = false

    public var enablePassword: String = ""

    public var maxRetries: Int64 = 0

    public var retryBackoffMs: Int64 = 1000

    public var retryMaxBackoffMs: Int64 = 30000

    public init() {}

    public init(host: String, port: UInt16, username: String, password: String) {
        this.host = host
        this.port = port
        this.username = username
        this.password = password
    }
}

public func looksLikeUsernamePrompt(text: String): Bool {
    let line = lastNonEmptyLine(cleanOutput(text)).trimAscii()
    if (line.isEmpty()) {
        return false
    }
    if (!line.endsWith(":")) {
        return false
    }
    let lower = line.toAsciiLower()
    if (lower.contains("password")) {
        return false
    }
    return lower.contains("username") || lower.contains("user name") || lower.contains("login")
}

public func looksLikeLoginFailure(text: String): Bool {
    let lower = cleanOutput(text).toAsciiLower()
    if (lower.isEmpty()) {
        return false
    }
    return lower.contains("login incorrect") || lower.contains("login invalid") ||
        lower.contains("authentication failed") || lower.contains("bad passwords") ||
        lower.contains("access denied") || lower.contains("permission denied")
}

class TelnetHandles {
    let transport: TcpTransport
    let stream: TelnetStream

    init(transport: TcpTransport, stream: TelnetStream) {
        this.transport = transport
        this.stream = stream
    }
}

public class TelnetConnection <: Resource & NetworkConnection {
    private var transport: TcpTransport
    private var stream: TelnetStream
    private let options: TelnetOptions
    private var driver: CliDriver

    private init(handles: TelnetHandles, options: TelnetOptions) {
        this.transport = handles.transport
        this.stream = handles.stream
        this.options = options
        this.driver = TelnetConnection.makeDriver(handles.stream, options)
    }

    private static func makeDriver(stream: TelnetStream, options: TelnetOptions): CliDriver {
        return CliDriver(stream, "${options.host}:${options.port}", options.deviceType,
                         options.pagingCommand, options.enablePassword,
                         options.autoDetectDeviceType, options.commandTimeoutMs,
                         options.quietPeriodMs, options.bannerSettleMs)
    }

    public static func connect(host: String, port: UInt16, username: String,
                               password: String): TelnetConnection {
        return connect(TelnetOptions(host, port, username, password))
    }

    public static func connect(options: TelnetOptions): TelnetConnection {
        validate(options)
        return retryingAttempt<TelnetConnection>(options.maxRetries, options.retryBackoffMs,
                                                 options.retryMaxBackoffMs,
                                                 {=> connectOnce(options)})
    }

    private static func validate(options: TelnetOptions): Unit {
        if (options.host.isEmpty()) {
            throw ConnectionException("host must not be empty")
        }
        if (options.port == 0) {
            throw ConnectionException("port must not be 0")
        }
        if (options.connectTimeoutMs <= 0) {
            throw ConnectionException("connectTimeoutMs must be positive")
        }
        if (options.commandTimeoutMs <= 0) {
            throw ConnectionException("commandTimeoutMs must be positive")
        }
        if (options.loginTimeoutMs <= 0) {
            throw ConnectionException("loginTimeoutMs must be positive")
        }
        if (options.maxRetries < 0) {
            throw ConnectionException("maxRetries must not be negative, got ${options.maxRetries}")
        }
    }

    private static func openSocket(options: TelnetOptions): TelnetHandles {
        let transport = TcpTransport.connect(options.host, options.port, options.connectTimeoutMs)
        let negotiator = TelnetNegotiator(options.terminalType, options.terminalWidth,
                                          options.terminalHeight, options.negotiateWindowSize)
        return TelnetHandles(transport, TelnetStream(transport, negotiator))
    }

    private static func connectOnce(options: TelnetOptions): TelnetConnection {
        let handles = openSocket(options)
        let conn = TelnetConnection(handles, options)
        try {
            conn.login()
            conn.driver.establish()
        } catch (e: Exception) {
            conn.close()
            throw e
        }
        return conn
    }

    public func reconnect(): Unit {
        close()
        let handles = TelnetConnection.retryingAttempt<TelnetHandles>(
            options.maxRetries, options.retryBackoffMs, options.retryMaxBackoffMs,
            {=> TelnetConnection.openSocket(options)})
        transport = handles.transport
        stream = handles.stream
        driver = TelnetConnection.makeDriver(handles.stream, options)
        try {
            login()
            driver.establish()
        } catch (e: Exception) {
            close()
            throw e
        }
    }

    private static func retryingAttempt<T>(maxRetries: Int64, backoffMs: Int64, maxBackoffMs: Int64,
                                           body: () -> T): T {
        var attempt: Int64 = 0
        while (true) {
            try {
                return body()
            } catch (e: AuthenticationException) {
                throw e
            } catch (e: GlyphNetException) {
                if (attempt >= maxRetries) {
                    throw e
                }
                let delay = retryDelayMs(attempt, backoffMs, maxBackoffMs)
                if (delay > 0) {
                    sleep(Duration.millisecond * delay)
                }
                attempt += 1
            }
        }
        throw ConnectionException("telnet retry loop exited unexpectedly")
    }

    private func endpoint(): String {
        return "${options.host}:${options.port}"
    }

    private func login(): Unit {
        let deadline = MonoTime.now() + Duration.millisecond * options.loginTimeoutMs
        var sentUsername = false
        var sentPassword = false

        while (true) {
            let remaining = (deadline - MonoTime.now()).toMilliseconds()
            if (remaining <= 0) {
                throw SshTimeoutException(
                    "timed out after ${options.loginTimeoutMs}ms waiting for a telnet login " +
                    "prompt from ${endpoint()}")
            }
            let raw = driver.readUntilRaw({
                text => looksLikeUsernamePrompt(text) || looksLikePasswordPrompt(text) ||
                    endsWithCleanPrompt(text, "")
            }, remaining, 0)

            if (looksLikeLoginFailure(raw)) {
                throw AuthenticationException(
                    "${endpoint()} rejected the telnet credentials for user " +
                    "'${options.username}'")
            }

            if (looksLikeUsernamePrompt(raw)) {
                if (sentUsername) {
                    throw AuthenticationException(
                        "${endpoint()} asked for the username again; the telnet credentials " +
                        "for '${options.username}' were rejected")
                }
                if (options.username.isEmpty()) {
                    throw AuthenticationException(
                        "${endpoint()} asked for a username but none was supplied")
                }
                driver.writeLine(options.username)
                sentUsername = true
                continue
            }

            if (looksLikePasswordPrompt(raw)) {
                if (sentPassword) {
                    throw AuthenticationException(
                        "the telnet password was rejected by ${endpoint()}")
                }
                if (options.password.isEmpty()) {
                    throw AuthenticationException(
                        "${endpoint()} asked for a password but none was supplied")
                }
                driver.writeLine(options.password)
                sentPassword = true
                continue
            }

            return
        }
    }

    public prop prompt: String {
        get() {
            driver.prompt
        }
    }

    public prop deviceType: DeviceType {
        get() {
            driver.deviceType
        }
    }

    public prop devicePreset: DeviceProfile {
        get() {
            driver.devicePreset
        }
    }

    public prop pagingCommand: String {
        get() {
            driver.pagingCommand
        }
    }

    public prop remoteEcho: Bool {
        get() {
            stream.options.remoteEchoEnabled()
        }
    }

    public prop characterAtATime: Bool {
        get() {
            stream.options.remoteSuppressGoAhead()
        }
    }

    public func findPrompt(): String {
        return driver.findPrompt()
    }

    public func sendCommand(command: String): String {
        return driver.sendCommand(command)
    }

    public func sendCommand(command: String, timeoutMs: Int64): String {
        return driver.sendCommand(command, timeoutMs)
    }

    public func sendCommandTiming(command: String, timeoutMs: Int64, quietMs: Int64): String {
        return driver.sendCommandTiming(command, timeoutMs, quietMs)
    }

    public func sendCommands(commands: Array<String>): Array<String> {
        return driver.sendCommands(commands)
    }

    public func readAvailable(): String {
        return driver.readAvailable()
    }

    public func writeRaw(text: String): Unit {
        driver.writeRaw(text)
    }

    public func detectDeviceType(): DeviceType {
        return driver.detectDeviceType()
    }

    public func redispatch(deviceType: DeviceType): Unit {
        driver.redispatch(deviceType)
    }

    public func enable(): Unit {
        driver.enable()
    }

    public func enable(password: String): Unit {
        driver.enable(password)
    }

    public func isEnableMode(): Bool {
        return driver.isEnableMode()
    }

    public func configMode(): String {
        return driver.configMode()
    }

    public func exitConfigMode(): String {
        return driver.exitConfigMode()
    }

    public func commit(): String {
        return driver.commit()
    }

    public func isConfigMode(): Bool {
        return driver.isConfigMode()
    }

    public func sendConfig(commands: Array<String>): Array<String> {
        return driver.sendConfig(commands)
    }

    public func isAlive(): Bool {
        return driver.isAlive()
    }

    public func isClosed(): Bool {
        return driver.isClosed()
    }

    public func disconnect(): Unit {
        close()
    }

    public func close(): Unit {
        if (driver.isClosed()) {
            return
        }
        driver.markClosed()
        transport.close()
    }
}
