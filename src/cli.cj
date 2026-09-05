package glyphnet

import glyphnet.errors.*
import std.collection.*

public interface CliStream {
    func writeAll(data: String, timeoutMs: Int64): Unit

    func readAvailable(): String

    func readUntil(predicate: (String) -> Bool, timeoutMs: Int64, quietMs: Int64): String

    func isEof(): Bool

    func closeStream(): Unit
}

public interface NetworkConnection <: Resource {
    prop prompt: String

    prop deviceType: DeviceType

    prop devicePreset: DeviceProfile

    prop pagingCommand: String

    func findPrompt(): String

    func sendCommand(command: String): String

    func sendCommand(command: String, timeoutMs: Int64): String

    func sendCommandTiming(command: String, timeoutMs: Int64, quietMs: Int64): String

    func sendCommands(commands: Array<String>): Array<String>

    func readAvailable(): String

    func writeRaw(text: String): Unit

    func detectDeviceType(): DeviceType

    func redispatch(deviceType: DeviceType): Unit

    func enable(): Unit

    func enable(password: String): Unit

    func isEnableMode(): Bool

    func configMode(): String

    func exitConfigMode(): String

    func commit(): String

    func isConfigMode(): Bool

    func sendConfig(commands: Array<String>): Array<String>

    func isAlive(): Bool

    func disconnect(): Unit
}

class CliDriver {
    private let stream: CliStream
    private let label: String

    let commandTimeoutMs: Int64
    let quietPeriodMs: Int64
    let bannerSettleMs: Int64
    private let pagingOverride: String
    private let enablePassword: String
    private let autoDetect: Bool

    private var activeDeviceType: DeviceType
    private var basePrompt: String = ""
    private var promptStemValue: String = ""
    private var closed: Bool = false

    init(stream: CliStream, label: String, deviceType: DeviceType, pagingOverride: String,
         enablePassword: String, autoDetect: Bool, commandTimeoutMs: Int64, quietPeriodMs: Int64,
         bannerSettleMs: Int64) {
        this.stream = stream
        this.label = label
        this.activeDeviceType = deviceType
        this.pagingOverride = pagingOverride
        this.enablePassword = enablePassword
        this.autoDetect = autoDetect
        this.commandTimeoutMs = commandTimeoutMs
        this.quietPeriodMs = quietPeriodMs
        this.bannerSettleMs = bannerSettleMs
    }

    prop prompt: String {
        get() {
            basePrompt
        }
    }

    prop stem: String {
        get() {
            promptStemValue
        }
    }

    prop deviceType: DeviceType {
        get() {
            activeDeviceType
        }
    }

    prop devicePreset: DeviceProfile {
        get() {
            deviceProfile(activeDeviceType)
        }
    }

    prop pagingCommand: String {
        get() {
            resolvedPagingCommand()
        }
    }

    func settleBanner(): Unit {
        try {
            stream.readUntil({_ => false}, bannerSettleMs, quietPeriodMs)
        } catch (_: SshTimeoutException) {
        }
    }

    func establish(): Unit {
        settleBanner()
        findPrompt()
        applyPagingCommand()
        if (autoDetect) {
            let detected = detectDeviceType()
            if (detected != DeviceType.Generic) {
                redispatch(detected)
            }
        }
    }

    func resolvedPagingCommand(): String {
        if (!pagingOverride.isEmpty()) {
            return pagingOverride
        }
        return deviceProfile(activeDeviceType).pagingCommand
    }

    func applyPagingCommand(): Unit {
        let cmd = resolvedPagingCommand()
        if (!cmd.isEmpty()) {
            sendCommand(cmd)
        }
    }

    func redispatch(deviceType: DeviceType): Unit {
        checkOpen()
        if (deviceType == activeDeviceType) {
            return
        }
        let previous = resolvedPagingCommand()
        activeDeviceType = deviceType
        let next = resolvedPagingCommand()
        if (!next.isEmpty() && next != previous) {
            sendCommand(next)
        }
    }

    func detectDeviceType(): DeviceType {
        checkOpen()
        for (cmd in DEVICE_DETECT_COMMANDS) {
            var text = ""
            try {
                text = sendCommand(cmd)
            } catch (_: GlyphNetException) {
                resyncPrompt()
                continue
            }
            let detected = matchDeviceSignature(text)
            if (detected != DeviceType.Generic) {
                return detected
            }
        }
        return DeviceType.Generic
    }

    func resyncPrompt(): Unit {
        try {
            stream.readAvailable()
            findPrompt()
        } catch (_: GlyphNetException) {
        }
    }

    func isEnableMode(): Bool {
        return inEnableMode(basePrompt, activeDeviceType)
    }

    func isConfigMode(): Bool {
        return inConfigMode(basePrompt, activeDeviceType)
    }

    func enable(): Unit {
        enable(enablePassword)
    }

    func enable(password: String): Unit {
        checkOpen()
        let profile = deviceProfile(activeDeviceType)
        if (!profile.supportsEnable) {
            throw CommandException(
                "device type '${activeDeviceType}' has no enable mode; " +
                "set ConnectionOptions.deviceType to a platform that does, or use sendCommand()")
        }
        if (isEnableMode()) {
            return
        }

        let savedStem = promptStemValue
        stream.readAvailable()
        stream.writeAll(profile.enableCommand + "\n", commandTimeoutMs)
        var raw = readUntilPasswordOrPrompt(savedStem)

        if (looksLikePasswordPrompt(raw)) {
            if (password.isEmpty()) {
                abandonPasswordPrompt(savedStem)
                throw AuthenticationException(
                    "${label} asked for an enable password but none was supplied")
            }
            stream.writeAll(password + "\n", commandTimeoutMs)
            raw = readUntilPasswordOrPrompt(savedStem)
            if (looksLikePasswordPrompt(raw)) {
                abandonPasswordPrompt(savedStem)
                throw AuthenticationException("enable password was rejected by ${label}")
            }
        }

        findPrompt()
        if (!isEnableMode()) {
            throw AuthenticationException(
                "'${profile.enableCommand}' did not reach privileged mode on ${label}; " +
                "the prompt is still '${basePrompt}'")
        }
    }

    private func readUntilPasswordOrPrompt(savedStem: String): String {
        return stream.readUntil(
            {text => looksLikePasswordPrompt(text) || endsWithCleanPrompt(text, savedStem)},
            commandTimeoutMs, 0)
    }

    private func abandonPasswordPrompt(savedStem: String): Unit {
        var i = 0
        while (i < 3) {
            try {
                stream.writeAll("\n", commandTimeoutMs)
                if (!looksLikePasswordPrompt(readUntilPasswordOrPrompt(savedStem))) {
                    break
                }
            } catch (_: GlyphNetException) {
                break
            }
            i += 1
        }
        resyncPrompt()
    }

    func configMode(): String {
        checkOpen()
        let profile = deviceProfile(activeDeviceType)
        if (!profile.supportsConfigMode) {
            throw CommandException(
                "device type '${activeDeviceType}' has no configuration mode; " +
                "set ConnectionOptions.deviceType or drive the CLI with sendCommand()")
        }
        if (isConfigMode()) {
            return ""
        }
        if (profile.supportsEnable && !isEnableMode()) {
            throw CommandException(
                "'${profile.configCommand}' needs privileged mode on ${label}; " +
                "call enable() first (the prompt is '${basePrompt}')")
        }
        let out = sendCommand(profile.configCommand)
        findPrompt()
        if (!isConfigMode()) {
            throw CommandException(
                "'${profile.configCommand}' did not enter configuration mode on ${label}; " +
                "the prompt is '${basePrompt}'")
        }
        return out
    }

    func exitConfigMode(): String {
        checkOpen()
        let profile = deviceProfile(activeDeviceType)
        if (!profile.supportsConfigMode) {
            throw CommandException(
                "device type '${activeDeviceType}' has no configuration mode; " +
                "set ConnectionOptions.deviceType or drive the CLI with sendCommand()")
        }
        if (!isConfigMode()) {
            return ""
        }
        var out = ""
        if (profile.requiresCommit) {
            let committed = sendCommand(profile.commitCommand)
            if (!committed.isEmpty()) {
                out = committed + "\n"
            }
        }
        out += sendCommand(profile.exitConfigCommand)
        findPrompt()
        if (isConfigMode()) {
            throw CommandException(
                "'${profile.exitConfigCommand}' did not leave configuration mode on " +
                "${label}; the prompt is '${basePrompt}'")
        }
        return out
    }

    func commit(): String {
        checkOpen()
        let profile = deviceProfile(activeDeviceType)
        if (!profile.requiresCommit) {
            throw CommandException(
                "device type '${activeDeviceType}' has no commit step; its configuration " +
                "commands take effect as they are entered")
        }
        if (!isConfigMode()) {
            throw CommandException(
                "'${profile.commitCommand}' needs configuration mode on ${label}; " +
                "call configMode() first (the prompt is '${basePrompt}')")
        }
        return sendCommand(profile.commitCommand)
    }

    func sendConfig(commands: Array<String>): Array<String> {
        checkOpen()
        configMode()
        let results = ArrayList<String>()
        try {
            for (c in commands) {
                results.add(sendCommand(c))
            }
        } finally {
            exitConfigMode()
        }
        return results.toArray()
    }

    func findPrompt(): String {
        checkOpen()

        stream.readAvailable()
        stream.writeAll("\n", commandTimeoutMs)

        let raw = stream.readUntil({text => endsWithPrompt(text, "")}, commandTimeoutMs,
                                   quietPeriodMs)
        let line = lastNonEmptyLine(cleanOutput(raw))
        if (line.isEmpty()) {
            throw SshTimeoutException("could not determine the device prompt (no output received)")
        }
        basePrompt = line
        promptStemValue = promptStem(line)
        return basePrompt
    }

    func adoptPrompt(line: String): Unit {
        basePrompt = line
        promptStemValue = promptStem(line)
    }

    func sendCommand(command: String): String {
        return sendCommand(command, commandTimeoutMs)
    }

    func sendCommand(command: String, timeoutMs: Int64): String {
        checkOpen()
        if (timeoutMs <= 0) {
            throw CommandException("command timeout must be positive, got ${timeoutMs}ms")
        }
        stream.writeAll(command + "\n", timeoutMs)

        let savedStem = promptStemValue
        let raw = stream.readUntil({text => endsWithPrompt(text, savedStem)}, timeoutMs,
                                   quietPeriodMs)
        return extractCommandOutput(raw, command, savedStem)
    }

    func sendCommandTiming(command: String, timeoutMs: Int64, quietMs: Int64): String {
        checkOpen()
        stream.writeAll(command + "\n", timeoutMs)
        let raw = stream.readUntil({_ => false}, timeoutMs, quietMs)
        return extractCommandOutput(raw, command, promptStemValue)
    }

    func sendCommands(commands: Array<String>): Array<String> {
        checkOpen()
        let results = ArrayList<String>()
        for (c in commands) {
            results.add(sendCommand(c))
        }
        return results.toArray()
    }

    func writeRaw(text: String): Unit {
        checkOpen()
        stream.writeAll(text, commandTimeoutMs)
    }

    func readAvailable(): String {
        checkOpen()
        return cleanOutput(stream.readAvailable())
    }

    func writeLine(text: String): Unit {
        stream.writeAll(text + "\n", commandTimeoutMs)
    }

    func readUntilRaw(predicate: (String) -> Bool, timeoutMs: Int64, quietMs: Int64): String {
        return stream.readUntil(predicate, timeoutMs, quietMs)
    }

    func isAlive(): Bool {
        if (closed) {
            return false
        }
        return !stream.isEof()
    }

    func checkOpen(): Unit {
        if (closed) {
            throw CommandException("connection to ${label} is already closed")
        }
    }

    func isClosed(): Bool {
        return closed
    }

    func markClosed(): Unit {
        closed = true
    }
}
