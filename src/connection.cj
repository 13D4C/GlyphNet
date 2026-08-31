package glyphnet

import glyphnet.errors.*
import glyphnet.ssh2.*
import glyphnet.transport.*
import std.collection.*

public enum HostKeyPolicy {
    AcceptAny
    |

    Pinned(Array<UInt8>)
}

public enum AuthMethod {
    Password(String)
    |

    PublicKey(String, String, String)
}

public class ConnectionOptions {
    public var host: String = ""
    public var port: UInt16 = 22
    public var username: String = ""
    public var auth: AuthMethod = AuthMethod.Password("")

    public var connectTimeoutMs: Int64 = 15000

    public var authTimeoutMs: Int64 = 20000

    public var commandTimeoutMs: Int64 = 30000

    public var quietPeriodMs: Int64 = 300

    public var bannerSettleMs: Int64 = 800

    public var requestPty: Bool = true
    public var terminalType: String = "vt100"
    public var terminalWidth: Int32 = 511
    public var terminalHeight: Int32 = 4096

    public var pagingCommand: String = ""

    public var deviceType: DeviceType = DeviceType.Generic

    public var autoDetectDeviceType: Bool = false

    public var enablePassword: String = ""

    public var maxRetries: Int64 = 0

    public var retryBackoffMs: Int64 = 1000

    public var retryMaxBackoffMs: Int64 = 30000

    public var hostKeyPolicy: HostKeyPolicy = HostKeyPolicy.AcceptAny

    public var keepaliveSec: UInt32 = 0

    public init() {}

    public init(host: String, port: UInt16, username: String, password: String) {
        this.host = host
        this.port = port
        this.username = username
        this.auth = AuthMethod.Password(password)
    }
}

public class ExecResult {
    public let output: String
    public let exitStatus: Int32

    init(output: String, exitStatus: Int32) {
        this.output = output
        this.exitStatus = exitStatus
    }

    public prop succeeded: Bool {
        get() {
            exitStatus == 0
        }
    }

    public func toString(): String {
        return "ExecResult(exitStatus=${exitStatus}, ${output.size} bytes)"
    }
}

class ShellHandles {
    let session: Session
    let channel: Channel

    init(session: Session, channel: Channel) {
        this.session = session
        this.channel = channel
    }
}

class ChannelStream <: CliStream {
    private let channel: Channel

    init(channel: Channel) {
        this.channel = channel
    }

    public func writeAll(data: String, timeoutMs: Int64): Unit {
        channel.writeAll(data, timeoutMs)
    }

    public func readAvailable(): String {
        return channel.readAvailable()
    }

    public func readUntil(predicate: (String) -> Bool, timeoutMs: Int64, quietMs: Int64): String {
        return channel.readUntil(predicate, timeoutMs, quietMs)
    }

    public func isEof(): Bool {
        return channel.isEof()
    }

    public func closeStream(): Unit {
        channel.close()
    }
}

public class SSHConnection <: Resource & NetworkConnection {
    private var session: Session
    private var channel: Channel
    private let options: ConnectionOptions
    private var driver: CliDriver

    private init(handles: ShellHandles, options: ConnectionOptions) {
        this.session = handles.session
        this.channel = handles.channel
        this.options = options
        this.driver = SSHConnection.makeDriver(handles.channel, options)
    }

    private static func makeDriver(channel: Channel, options: ConnectionOptions): CliDriver {
        return CliDriver(ChannelStream(channel), options.host, options.deviceType,
                         options.pagingCommand, options.enablePassword,
                         options.autoDetectDeviceType, options.commandTimeoutMs,
                         options.quietPeriodMs, options.bannerSettleMs)
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

    public func serverBanner(): String {
        return session.banner()
    }

    public func hostKeyFingerprint(): Array<UInt8> {
        return session.hostKeyFingerprintSha256()
    }

    public static func connect(host: String, port: UInt16, username: String,
                               password: String): SSHConnection {
        return connect(ConnectionOptions(host, port, username, password))
    }

    public static func connect(options: ConnectionOptions): SSHConnection {
        validate(options)
        return retrying<SSHConnection>(options, {=> connectOnce(options)})
    }

    private static func connectOnce(options: ConnectionOptions): SSHConnection {
        let handles = openShell(options)
        let conn = SSHConnection(handles, options)
        try {
            conn.driver.establish()
        } catch (e: Exception) {
            conn.close()
            throw e
        }
        return conn
    }

    private static func openShell(options: ConnectionOptions): ShellHandles {
        let transport = TcpTransport.connect(options.host, options.port, options.connectTimeoutMs)

        let session = Session.handshake(transport, options.authTimeoutMs)

        try {
            checkHostKey(session, options)
            authenticate(session, options)

            if (options.keepaliveSec > 0) {
                session.setKeepalive(true, options.keepaliveSec)
            }

            let channel = session.openChannel()
            if (options.requestPty) {
                channel.requestPty(options.terminalType, options.terminalWidth,
                                   options.terminalHeight)
            }
            channel.mergeStderr()
            channel.startShell()
            return ShellHandles(session, channel)
        } catch (e: Exception) {
            session.close()
            throw e
        }
    }

    private static func retrying<T>(options: ConnectionOptions, body: () -> T): T {
        var attempt: Int64 = 0
        while (true) {
            try {
                return body()
            } catch (e: AuthenticationException) {
                throw e
            } catch (e: HostKeyException) {
                throw e
            } catch (e: GlyphNetException) {
                if (attempt >= options.maxRetries) {
                    throw e
                }
                let delay = retryDelayMs(attempt, options.retryBackoffMs, options.retryMaxBackoffMs)
                if (delay > 0) {
                    sleep(Duration.millisecond * delay)
                }
                attempt += 1
            }
        }
        throw ConnectionException("retry loop for ${options.host} exited unexpectedly")
    }

    public func reconnect(): Unit {
        close()
        let handles = SSHConnection.retrying<ShellHandles>(options,
                                                           {=> SSHConnection.openShell(options)})
        session = handles.session
        channel = handles.channel
        driver = SSHConnection.makeDriver(handles.channel, options)
        try {
            driver.establish()
        } catch (e: Exception) {
            close()
            throw e
        }
    }

    private static func validate(options: ConnectionOptions): Unit {
        if (options.host.isEmpty()) {
            throw ConnectionException("host must not be empty")
        }
        if (options.username.isEmpty()) {
            throw AuthenticationException("username must not be empty")
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
        if (options.maxRetries < 0) {
            throw ConnectionException("maxRetries must not be negative, got ${options.maxRetries}")
        }
    }

    private static func checkHostKey(session: Session, options: ConnectionOptions): Unit {
        match (options.hostKeyPolicy) {
            case AcceptAny => return
            case Pinned(expected) =>
                let actual = session.hostKeyFingerprintSha256()
                if (actual.size == 0) {
                    throw HostKeyException("server did not present a hashable host key")
                }
                if (expected.size != actual.size) {
                    throw HostKeyException(
                        "host key fingerprint length mismatch: expected ${expected.size} bytes, got ${actual.size}")
                }
                var i = 0
                while (i < actual.size) {
                    if (actual[i] != expected[i]) {
                        throw HostKeyException(
                            "host key fingerprint mismatch for ${options.host}: got ${hexOf(actual)}")
                    }
                    i += 1
                }
        }
    }

    private static func authenticate(session: Session, options: ConnectionOptions): Unit {
        match (options.auth) {
            case Password(pw) => session.authenticatePassword(options.username, pw)
            case PublicKey(priv, pub, passphrase) =>
                session.authenticatePublicKey(options.username, priv, pub, passphrase)
        }
        if (!session.isAuthenticated()) {
            throw AuthenticationException(
                "authentication reported success but the session is not authenticated")
        }
    }

    public func redispatch(deviceType: DeviceType): Unit {
        driver.redispatch(deviceType)
    }

    public func detectDeviceType(): DeviceType {
        return driver.detectDeviceType()
    }

    public func isEnableMode(): Bool {
        return driver.isEnableMode()
    }

    public func isConfigMode(): Bool {
        return driver.isConfigMode()
    }

    public func enable(): Unit {
        driver.enable()
    }

    public func enable(password: String): Unit {
        driver.enable(password)
    }

    public func configMode(): String {
        return driver.configMode()
    }

    public func exitConfigMode(): String {
        return driver.exitConfigMode()
    }

    public func sendConfig(commands: Array<String>): Array<String> {
        return driver.sendConfig(commands)
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

    public func sendCommandParsed(command: String, template: String): Array<TextFsmRow> {
        return TextFsmTemplate.compile(template).parse(sendCommand(command))
    }

    public func sendCommandParsed(command: String, template: String,
                                  timeoutMs: Int64): Array<TextFsmRow> {
        return TextFsmTemplate.compile(template).parse(sendCommand(command, timeoutMs))
    }

    public func sendCommandParsed(command: String, template: TextFsmTemplate): Array<TextFsmRow> {
        return template.parse(sendCommand(command))
    }

    public func execChannel(command: String): ExecResult {
        return execChannel(command, options.commandTimeoutMs)
    }

    public func execChannel(command: String, timeoutMs: Int64): ExecResult {
        driver.checkOpen()
        if (command.isEmpty()) {
            throw CommandException("exec command must not be empty")
        }
        if (timeoutMs <= 0) {
            throw CommandException("exec timeout must be positive, got ${timeoutMs}ms")
        }
        let ch = session.openChannel()
        try {
            ch.mergeStderr()
            ch.exec(command)
            let raw = ch.readToEof(timeoutMs)
            let status = ch.waitForExit(timeoutMs)
            return ExecResult(cleanOutput(raw), status)
        } finally {
            try {
                ch.close()
            } catch (_: Exception) {
            }
        }
    }

    public func execChannels(commands: Array<String>): Array<ExecResult> {
        driver.checkOpen()
        let results = ArrayList<ExecResult>()
        for (c in commands) {
            results.add(execChannel(c))
        }
        return results.toArray()
    }

    func rawSession(): Session {
        driver.checkOpen()
        return session
    }

    func transferTimeoutMs(): Int64 {
        return options.commandTimeoutMs
    }

    public func sendCommands(commands: Array<String>): Array<String> {
        return driver.sendCommands(commands)
    }

    public func writeRaw(text: String): Unit {
        driver.writeRaw(text)
    }

    public func readAvailable(): String {
        return driver.readAvailable()
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
        try {
            channel.close()
        } catch (_: Exception) {
        }
        session.close()
    }
}

public func hexOf(bytes: Array<UInt8>): String {
    let digits = "0123456789abcdef"
    let table = digits.toArray()
    let out = Array<UInt8>(bytes.size * 2, repeat: 0)
    var i = 0
    while (i < bytes.size) {
        let b = Int64(bytes[i])
        out[i * 2] = table[b / 16]
        out[i * 2 + 1] = table[b % 16]
        i += 1
    }
    return String.fromUtf8(out)
}
