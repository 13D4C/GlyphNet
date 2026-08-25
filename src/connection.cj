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

public class SSHConnection <: Resource {
    private let session: Session
    private let channel: Channel
    private let options: ConnectionOptions
    private var basePrompt: String = ""
    private var promptStemValue: String = ""
    private var closed: Bool = false

    private init(session: Session, channel: Channel, options: ConnectionOptions) {
        this.session = session
        this.channel = channel
        this.options = options
    }

    public prop prompt: String {
        get() {
            basePrompt
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

            let conn = SSHConnection(session, channel, options)
            conn.establish()
            return conn
        } catch (e: Exception) {
            session.close()
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

    private func establish(): Unit {
        channel.readUntil({_ => false}, options.bannerSettleMs, options.quietPeriodMs)
        findPrompt()
        if (!options.pagingCommand.isEmpty()) {
            sendCommand(options.pagingCommand)
        }
    }

    public func findPrompt(): String {
        checkOpen()

        channel.readAvailable()
        channel.writeAll("\n", options.commandTimeoutMs)

        let raw = channel.readUntil({text => endsWithPrompt(text, "")}, options.commandTimeoutMs,
                                    options.quietPeriodMs)
        let line = lastNonEmptyLine(cleanOutput(raw))
        if (line.isEmpty()) {
            throw SshTimeoutException("could not determine the device prompt (no output received)")
        }
        basePrompt = line
        promptStemValue = promptStem(line)
        return basePrompt
    }

    public func sendCommand(command: String): String {
        return sendCommand(command, options.commandTimeoutMs)
    }

    public func sendCommand(command: String, timeoutMs: Int64): String {
        checkOpen()
        if (timeoutMs <= 0) {
            throw CommandException("command timeout must be positive, got ${timeoutMs}ms")
        }
        channel.writeAll(command + "\n", timeoutMs)

        let stem = promptStemValue
        let raw = channel.readUntil({text => endsWithPrompt(text, stem)}, timeoutMs,
                                    options.quietPeriodMs)
        return extractCommandOutput(raw, command, stem)
    }

    public func sendCommandTiming(command: String, timeoutMs: Int64, quietMs: Int64): String {
        checkOpen()
        channel.writeAll(command + "\n", timeoutMs)
        let raw = channel.readUntil({_ => false}, timeoutMs, quietMs)
        return extractCommandOutput(raw, command, promptStemValue)
    }

    public func sendCommands(commands: Array<String>): Array<String> {
        checkOpen()
        let results = ArrayList<String>()
        for (c in commands) {
            results.add(sendCommand(c))
        }
        return results.toArray()
    }

    public func writeRaw(text: String): Unit {
        checkOpen()
        channel.writeAll(text, options.commandTimeoutMs)
    }

    public func readAvailable(): String {
        checkOpen()
        return cleanOutput(channel.readAvailable())
    }

    public func isAlive(): Bool {
        if (closed) {
            return false
        }
        return !channel.isEof()
    }

    private func checkOpen(): Unit {
        if (closed) {
            throw CommandException("connection to ${options.host} is already closed")
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public func disconnect(): Unit {
        close()
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
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
