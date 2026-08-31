package glyphnet

public enum DeviceType <: ToString & Equatable<DeviceType> {
    CiscoIOS
    |

    AristaEOS
    |

    JuniperJunOS
    |

    Generic

    public func toString(): String {
        return match (this) {
            case CiscoIOS => "cisco_ios"
            case AristaEOS => "arista_eos"
            case JuniperJunOS => "juniper_junos"
            case Generic => "generic"
        }
    }

    public operator func ==(other: DeviceType): Bool {
        return this.toString() == other.toString()
    }

    public operator func !=(other: DeviceType): Bool {
        return !(this == other)
    }
}

public func parseDeviceType(name: String): DeviceType {
    let key = name.trimAscii().toAsciiLower()
    if (key == "cisco_ios" || key == "cisco-ios" || key == "cisco" || key == "ios") {
        return DeviceType.CiscoIOS
    }
    if (key == "arista_eos" || key == "arista-eos" || key == "arista" || key == "eos") {
        return DeviceType.AristaEOS
    }
    if (key == "juniper_junos" || key == "juniper-junos" || key == "juniper" || key == "junos") {
        return DeviceType.JuniperJunOS
    }
    return DeviceType.Generic
}

public class DeviceProfile <: ToString {
    public let deviceType: DeviceType
    public let displayName: String
    public let pagingCommand: String
    public let supportsEnable: Bool
    public let enableCommand: String
    public let configCommand: String
    public let exitConfigCommand: String

    init(deviceType: DeviceType, displayName: String, pagingCommand: String, supportsEnable: Bool,
         enableCommand: String, configCommand: String, exitConfigCommand: String) {
        this.deviceType = deviceType
        this.displayName = displayName
        this.pagingCommand = pagingCommand
        this.supportsEnable = supportsEnable
        this.enableCommand = enableCommand
        this.configCommand = configCommand
        this.exitConfigCommand = exitConfigCommand
    }

    public prop supportsConfigMode: Bool {
        get() {
            !configCommand.isEmpty()
        }
    }

    public func toString(): String {
        return "DeviceProfile(${deviceType}, paging='${pagingCommand}', config='${configCommand}')"
    }
}

public func deviceProfile(deviceType: DeviceType): DeviceProfile {
    return match (deviceType) {
        case CiscoIOS => DeviceProfile(DeviceType.CiscoIOS, "Cisco IOS", "terminal length 0", true,
                                       "enable", "configure terminal", "end")
        case AristaEOS => DeviceProfile(DeviceType.AristaEOS, "Arista EOS", "terminal length 0",
                                        true, "enable", "configure terminal", "end")
        case JuniperJunOS => DeviceProfile(DeviceType.JuniperJunOS, "Juniper JunOS",
                                           "set cli screen-length 0", false, "", "configure",
                                           "exit")
        case Generic => DeviceProfile(DeviceType.Generic, "Generic", "", false, "", "", "")
    }
}

public let DEVICE_DETECT_COMMANDS: Array<String> = ["show version"]

public func matchDeviceSignature(text: String): DeviceType {
    let lower = cleanOutput(text).toAsciiLower()
    if (lower.isEmpty()) {
        return DeviceType.Generic
    }

    if (lower.contains("ios xr") || lower.contains("ios-xr") || lower.contains("nx-os") ||
        lower.contains("nexus operating system")) {
        return DeviceType.Generic
    }

    if (lower.contains("junos") || lower.contains("juniper networks")) {
        return DeviceType.JuniperJunOS
    }

    if (lower.contains("arista")) {
        return DeviceType.AristaEOS
    }

    if (lower.contains("cisco ios software") || lower.contains("cisco ios-xe software") ||
        lower.contains("cisco internetwork operating system") || lower.contains("ios (tm)")) {
        return DeviceType.CiscoIOS
    }

    return DeviceType.Generic
}

public func endsWithCleanPrompt(buffer: String, stem: String): Bool {
    return endsWithPrompt(cleanOutput(buffer), stem)
}

public func looksLikePasswordPrompt(text: String): Bool {
    let line = lastNonEmptyLine(cleanOutput(text)).trimAscii()
    if (line.isEmpty()) {
        return false
    }
    if (!line.endsWith(":")) {
        return false
    }
    return line.toAsciiLower().contains("password")
}

public func inEnableMode(prompt: String, deviceType: DeviceType): Bool {
    let p = prompt.trimAscii()
    if (p.isEmpty()) {
        return false
    }
    return match (deviceType) {
        case CiscoIOS => p.endsWith("#")
        case AristaEOS => p.endsWith("#")
        case _ => false
    }
}

public func inConfigMode(prompt: String, deviceType: DeviceType): Bool {
    let p = prompt.trimAscii()
    if (p.isEmpty()) {
        return false
    }
    return match (deviceType) {
        case CiscoIOS => p.contains("(config")
        case AristaEOS => p.contains("(config")
        case JuniperJunOS => p.endsWith("#")
        case Generic => false
    }
}

const RETRY_DELAY_CEILING_MS: Int64 = 300000

public func retryDelayMs(attempt: Int64, baseMs: Int64, maxMs: Int64): Int64 {
    if (baseMs <= 0) {
        return 0
    }
    var delay = baseMs
    var i: Int64 = 0
    while (i < attempt && delay < RETRY_DELAY_CEILING_MS) {
        delay = delay * 2
        i += 1
    }
    if (maxMs > 0 && delay > maxMs) {
        delay = maxMs
    }
    if (delay > RETRY_DELAY_CEILING_MS) {
        delay = RETRY_DELAY_CEILING_MS
    }
    return delay
}
