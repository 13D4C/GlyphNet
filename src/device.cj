package glyphnet

public enum DeviceType <: ToString & Equatable<DeviceType> {
    CiscoIOS
    |

    CiscoNXOS
    |

    CiscoASA
    |

    CiscoXR
    |

    AristaEOS
    |

    JuniperJunOS
    |

    HuaweiVRP
    |

    HuaweiVRPv8
    |

    HPComware
    |

    PaloAltoPanOS
    |

    FortinetFortiOS
    |

    DellOS10
    |

    MikrotikRouterOS
    |

    Generic

    public func toString(): String {
        return match (this) {
            case CiscoIOS => "cisco_ios"
            case CiscoNXOS => "cisco_nxos"
            case CiscoASA => "cisco_asa"
            case CiscoXR => "cisco_xr"
            case AristaEOS => "arista_eos"
            case JuniperJunOS => "juniper_junos"
            case HuaweiVRP => "huawei"
            case HuaweiVRPv8 => "huawei_vrpv8"
            case HPComware => "hp_comware"
            case PaloAltoPanOS => "paloalto_panos"
            case FortinetFortiOS => "fortinet"
            case DellOS10 => "dell_os10"
            case MikrotikRouterOS => "mikrotik_routeros"
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
    if (key == "cisco_nxos" || key == "cisco-nxos" || key == "nxos" || key == "nx-os" ||
        key == "nexus") {
        return DeviceType.CiscoNXOS
    }
    if (key == "cisco_asa" || key == "cisco-asa" || key == "asa") {
        return DeviceType.CiscoASA
    }
    if (key == "cisco_xr" || key == "cisco-xr" || key == "cisco_iosxr" || key == "iosxr" ||
        key == "ios_xr" || key == "ios-xr") {
        return DeviceType.CiscoXR
    }
    if (key == "arista_eos" || key == "arista-eos" || key == "arista" || key == "eos") {
        return DeviceType.AristaEOS
    }
    if (key == "juniper_junos" || key == "juniper-junos" || key == "juniper" || key == "junos") {
        return DeviceType.JuniperJunOS
    }
    if (key == "huawei" || key == "huawei_vrp" || key == "huawei-vrp" || key == "vrp") {
        return DeviceType.HuaweiVRP
    }
    if (key == "huawei_vrpv8" || key == "huawei-vrpv8" || key == "vrpv8") {
        return DeviceType.HuaweiVRPv8
    }
    if (key == "hp_comware" || key == "hp-comware" || key == "hpe_comware" || key == "comware") {
        return DeviceType.HPComware
    }
    if (key == "paloalto_panos" || key == "paloalto-panos" || key == "panos" ||
        key == "pan-os" || key == "paloalto") {
        return DeviceType.PaloAltoPanOS
    }
    if (key == "fortinet" || key == "fortios" || key == "fortigate") {
        return DeviceType.FortinetFortiOS
    }
    if (key == "dell_os10" || key == "dell-os10" || key == "dellos10" || key == "os10") {
        return DeviceType.DellOS10
    }
    if (key == "mikrotik_routeros" || key == "mikrotik-routeros" || key == "mikrotik" ||
        key == "routeros") {
        return DeviceType.MikrotikRouterOS
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
    public let commitCommand: String

    init(deviceType: DeviceType, displayName: String, pagingCommand: String, supportsEnable: Bool,
         enableCommand: String, configCommand: String, exitConfigCommand: String,
         commitCommand: String) {
        this.deviceType = deviceType
        this.displayName = displayName
        this.pagingCommand = pagingCommand
        this.supportsEnable = supportsEnable
        this.enableCommand = enableCommand
        this.configCommand = configCommand
        this.exitConfigCommand = exitConfigCommand
        this.commitCommand = commitCommand
    }

    public prop supportsConfigMode: Bool {
        get() {
            !configCommand.isEmpty()
        }
    }

    public prop requiresCommit: Bool {
        get() {
            !commitCommand.isEmpty()
        }
    }

    public func toString(): String {
        return "DeviceProfile(${deviceType}, paging='${pagingCommand}', config='${configCommand}')"
    }
}

public func deviceProfile(deviceType: DeviceType): DeviceProfile {
    return match (deviceType) {
        case CiscoIOS => DeviceProfile(DeviceType.CiscoIOS, "Cisco IOS", "terminal length 0", true,
                                       "enable", "configure terminal", "end", "")
        case CiscoNXOS => DeviceProfile(DeviceType.CiscoNXOS, "Cisco NX-OS", "terminal length 0",
                                        true, "enable", "configure terminal", "end", "")
        case CiscoASA => DeviceProfile(DeviceType.CiscoASA, "Cisco ASA", "terminal pager 0", true,
                                       "enable", "configure terminal", "end", "")
        case CiscoXR => DeviceProfile(DeviceType.CiscoXR, "Cisco IOS-XR", "terminal length 0",
                                      false, "", "configure terminal", "end", "commit")
        case AristaEOS => DeviceProfile(DeviceType.AristaEOS, "Arista EOS", "terminal length 0",
                                        true, "enable", "configure terminal", "end", "")
        case JuniperJunOS => DeviceProfile(DeviceType.JuniperJunOS, "Juniper JunOS",
                                           "set cli screen-length 0", false, "", "configure",
                                           "exit", "")
        case HuaweiVRP => DeviceProfile(DeviceType.HuaweiVRP, "Huawei VRP",
                                        "screen-length 0 temporary", false, "", "system-view",
                                        "return", "")
        case HuaweiVRPv8 => DeviceProfile(DeviceType.HuaweiVRPv8, "Huawei VRPv8",
                                          "screen-length 0 temporary", false, "", "system-view",
                                          "return", "commit")
        case HPComware => DeviceProfile(DeviceType.HPComware, "HP Comware", "screen-length disable",
                                        false, "", "system-view", "return", "")
        case PaloAltoPanOS => DeviceProfile(DeviceType.PaloAltoPanOS, "Palo Alto PAN-OS",
                                            "set cli pager off", false, "", "configure", "exit",
                                            "commit")
        case FortinetFortiOS => DeviceProfile(DeviceType.FortinetFortiOS, "Fortinet FortiOS", "",
                                              false, "", "", "", "")
        case DellOS10 => DeviceProfile(DeviceType.DellOS10, "Dell OS10", "terminal length 0", true,
                                       "enable", "configure terminal", "end", "")
        case MikrotikRouterOS => DeviceProfile(DeviceType.MikrotikRouterOS, "MikroTik RouterOS", "",
                                               false, "", "", "", "")
        case Generic => DeviceProfile(DeviceType.Generic, "Generic", "", false, "", "", "", "")
    }
}

public let DEVICE_DETECT_COMMANDS: Array<String> = [
    "show version",
    "display version",
    "get system status",
    "show system info",
    "/system resource print"
]

public func matchDeviceSignature(text: String): DeviceType {
    let lower = cleanOutput(text).toAsciiLower()
    if (lower.isEmpty()) {
        return DeviceType.Generic
    }

    if (lower.contains("nexus operating system") || lower.contains("nx-os")) {
        return DeviceType.CiscoNXOS
    }

    if (lower.contains("cisco ios xr") || lower.contains("ios-xr") ||
        lower.contains("ios xr software")) {
        return DeviceType.CiscoXR
    }

    if (lower.contains("adaptive security appliance") || lower.contains("cisco asa")) {
        return DeviceType.CiscoASA
    }

    if (lower.contains("junos") || lower.contains("juniper networks")) {
        return DeviceType.JuniperJunOS
    }

    if (lower.contains("arista")) {
        return DeviceType.AristaEOS
    }

    if (lower.contains("comware")) {
        return DeviceType.HPComware
    }

    if (lower.contains("huawei versatile routing platform") ||
        lower.contains("huawei technologies") || lower.contains("vrp (r) software")) {
        if (lower.contains("vrp (r) software, version 8")) {
            return DeviceType.HuaweiVRPv8
        }
        return DeviceType.HuaweiVRP
    }

    if (lower.contains("fortigate") || lower.contains("fortios") || lower.contains("fortiwifi") ||
        lower.contains("fortinet")) {
        return DeviceType.FortinetFortiOS
    }

    if (lower.contains("pan-os") || lower.contains("palo alto") ||
        lower.contains("wildfire-version") ||
        (lower.contains("sw-version:") && lower.contains("app-version:"))) {
        return DeviceType.PaloAltoPanOS
    }

    if (lower.contains("dell emc networking os10") || lower.contains("dell smartfabric os10") ||
        lower.contains("os10 enterprise")) {
        return DeviceType.DellOS10
    }

    if (lower.contains("mikrotik") || lower.contains("routeros")) {
        return DeviceType.MikrotikRouterOS
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
        case CiscoNXOS => p.endsWith("#")
        case CiscoASA => p.endsWith("#")
        case AristaEOS => p.endsWith("#")
        case DellOS10 => p.endsWith("#")
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
        case CiscoNXOS => p.contains("(config")
        case CiscoASA => p.contains("(config")
        case CiscoXR => p.contains("(config")
        case AristaEOS => p.contains("(config")
        case DellOS10 => p.contains("(config")
        case JuniperJunOS => p.endsWith("#")
        case PaloAltoPanOS => p.endsWith("#")
        case HuaweiVRP => p.startsWith("[")
        case HuaweiVRPv8 => p.startsWith("[")
        case HPComware => p.startsWith("[")
        case FortinetFortiOS => false
        case MikrotikRouterOS => false
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
