package glyphnet

import glyphnet.errors.*
import std.convert.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

let CISCO_IOS_12_SHOW_VERSION: String =
    "Cisco IOS Software, 7200 Software (C7200-ADVENTERPRISEK9-M), Version 12.4(24)T5, " +
    "RELEASE SOFTWARE (fc3)\n" + "Copyright (c) 1986-2011 by Cisco Systems, Inc.\n" +
    "ROM: ROMMON Emulation Microcode\n" + "Khaow-InwZa007x2-R1 uptime is 21 minutes\n" +
    "Cisco 7206VXR (NPE400) processor (revision A) with 491520K/32768K bytes of memory.\n" +
    "Configuration register is 0x2102"

let CISCO_IOS_15_SHOW_VERSION: String =
    "Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 15.0(2)SE11, " +
    "RELEASE SOFTWARE (fc3)\n" + "Switch uptime is 4 weeks, 2 days\n" +
    "cisco WS-C2960-24TT-L (PowerPC405) processor (revision C0) with 65536K bytes of memory."

let ARISTA_EOS_SHOW_VERSION: String =
    "Arista DCS-7050QX-32-F\n" + "Hardware version:    01.31\n" +
    "Serial number:       JPE13120819\n" + "System MAC address:  001c.7326.fd2b\n" + "\n" +
    "Software image version: 4.20.5F\n" + "Architecture:           i386\n" +
    "Internal build version: 4.20.5F-8127914.4205F\n" + "Uptime:                 21 weeks"

let JUNOS_SHOW_VERSION: String =
    "Hostname: lab-mx480\n" + "Model: mx480\n" + "Junos: 20.4R3-S2.6\n" +
    "JUNOS OS Kernel 64-bit  [20210726.2f2e04b_builder_stable_11]\n" +
    "JUNOS OS runtime [20210726.2f2e04b_builder_stable_11]"

let IOS_XR_SHOW_VERSION: String =
    "Cisco IOS XR Software, Version 6.5.3\n" + "Copyright (c) 2013-2019 by Cisco Systems, Inc.\n" +
    "Build Information:\n" + " Built By     : ahoang"

let NXOS_SHOW_VERSION: String =
    "Cisco Nexus Operating System (NX-OS) Software\n" + "  system:    version 7.3(0)D1(1)"

let CISCO_ASA_SHOW_VERSION: String =
    "Cisco Adaptive Security Appliance Software Version 9.12(4)9\n" +
    "Firepower Extensible Operating System Version 2.6(1.192)\n" +
    "Device Manager Version 7.13(1)\n" +
    "System image file is \"disk0:/asa9-12-4-9-smp-k8.bin\"\n" +
    "ciscoasa up 3 days 2 hours"

let HUAWEI_VRP5_DISPLAY_VERSION: String =
    "Huawei Versatile Routing Platform Software\n" +
    "VRP (R) software, Version 5.170 (AR2200 V200R007C00SPC900)\n" +
    "Copyright (C) 2011-2016 HUAWEI TECH CO., LTD\n" +
    "Huawei AR2220E Router uptime is 3 weeks, 2 days"

let HUAWEI_VRP8_DISPLAY_VERSION: String =
    "Huawei Versatile Routing Platform Software\n" +
    "VRP (R) software, Version 8.180 (CE6865EI V200R005C10SPC800)\n" +
    "Copyright (C) 2012-2018 Huawei Technologies Co., Ltd.\n" +
    "HUAWEI CE6865-48S8CQ-EI uptime is 12 days, 4 hours"

let HP_COMWARE_DISPLAY_VERSION: String =
    "HPE Comware Software, Version 7.1.070, Release 6127P02\n" +
    "Copyright (c) 2010-2018 New H3C Technologies Co., Ltd. All rights reserved.\n" +
    "HPE 5130 48G PoE+ 4SFP+ (370W) EI Switch uptime is 0 weeks, 3 days"

let FORTINET_GET_SYSTEM_STATUS: String =
    "Version: FortiGate-VM64 v6.4.5,build1828,210217 (GA)\n" +
    "Virus-DB: 1.00000(2018-04-09 18:07)\n" + "Serial-Number: FGVM02TM21000000\n" +
    "Hostname: FortiGate-VM64\n" + "Current HA mode: standalone"

let PANOS_SHOW_SYSTEM_INFO: String =
    "hostname: PA-VM\n" + "ip-address: 192.0.2.5\n" + "model: PA-VM\n" + "serial: unknown\n" +
    "sw-version: 10.1.6\n" + "app-version: 8595-7326\n" + "threat-version: 8595-7326"

let DELL_OS10_SHOW_VERSION: String =
    "Dell EMC Networking OS10 Enterprise\n" +
    "Copyright (c) 1999-2020 by Dell Inc. All Rights Reserved.\n" + "OS Version: 10.5.0.6\n" +
    "Build Version: 10.5.0.6.242\n" + "System Type: S4128F-ON"

let MIKROTIK_SYSTEM_RESOURCE: String =
    "uptime: 3d4h12m\n" + "version: 6.48.6 (long-term)\n" +
    "build-time: Dec/01/2021 09:53:29\n" + "platform: MikroTik\n" +
    "board-name: CRS309-1G-8S+"

let SHELL_ERROR_OUTPUT: String = "bash: show: command not found"

@Test
class DeviceProfileTests {
    @TestCase
    func deviceTypeNamesRoundTrip(): Unit {
        @Expect(DeviceType.CiscoIOS.toString(), "cisco_ios")
        @Expect(DeviceType.AristaEOS.toString(), "arista_eos")
        @Expect(DeviceType.JuniperJunOS.toString(), "juniper_junos")
        @Expect(DeviceType.Generic.toString(), "generic")

        @Expect(parseDeviceType("cisco_ios") == DeviceType.CiscoIOS, true)
        @Expect(parseDeviceType("Arista") == DeviceType.AristaEOS, true)
        @Expect(parseDeviceType("  JUNOS ") == DeviceType.JuniperJunOS, true)
        @Expect(parseDeviceType("hp-procurve") == DeviceType.Generic, true)
    }

    @TestCase
    func presetsCarryVendorPagingCommands(): Unit {
        @Expect(deviceProfile(DeviceType.CiscoIOS).pagingCommand, "terminal length 0")
        @Expect(deviceProfile(DeviceType.AristaEOS).pagingCommand, "terminal length 0")
        @Expect(deviceProfile(DeviceType.JuniperJunOS).pagingCommand, "set cli screen-length 0")
        @Expect(deviceProfile(DeviceType.Generic).pagingCommand, "")
    }

    @TestCase
    func presetsCarryConfigModeCommands(): Unit {
        let ios = deviceProfile(DeviceType.CiscoIOS)
        @Expect(ios.configCommand, "configure terminal")
        @Expect(ios.exitConfigCommand, "end")
        @Expect(ios.supportsConfigMode, true)

        let eos = deviceProfile(DeviceType.AristaEOS)
        @Expect(eos.configCommand, "configure terminal")
        @Expect(eos.exitConfigCommand, "end")

        let junos = deviceProfile(DeviceType.JuniperJunOS)
        @Expect(junos.configCommand, "configure")
        @Expect(junos.exitConfigCommand, "exit")

        let generic = deviceProfile(DeviceType.Generic)
        @Expect(generic.supportsConfigMode, false)
    }

    @TestCase
    func enableIsOnlyForTwoTierPlatforms(): Unit {
        @Expect(deviceProfile(DeviceType.CiscoIOS).supportsEnable, true)
        @Expect(deviceProfile(DeviceType.CiscoIOS).enableCommand, "enable")
        @Expect(deviceProfile(DeviceType.AristaEOS).supportsEnable, true)
        @Expect(deviceProfile(DeviceType.JuniperJunOS).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.Generic).supportsEnable, false)
    }

    @TestCase
    func profileReportsItsOwnType(): Unit {
        @Expect(deviceProfile(DeviceType.AristaEOS).deviceType == DeviceType.AristaEOS, true)
        @Expect(deviceProfile(DeviceType.JuniperJunOS).displayName, "Juniper JunOS")
        @Expect(deviceProfile(DeviceType.CiscoIOS).toString().contains("cisco_ios"), true)
    }
}

@Test
class DeviceDetectionTests {
    @TestCase
    func detectsRealCiscoIos12ShowVersion(): Unit {
        @Expect(matchDeviceSignature(CISCO_IOS_12_SHOW_VERSION) == DeviceType.CiscoIOS, true)
    }

    @TestCase
    func detectsCiscoIos15ShowVersion(): Unit {
        @Expect(matchDeviceSignature(CISCO_IOS_15_SHOW_VERSION) == DeviceType.CiscoIOS, true)
    }

    @TestCase
    func detectsAristaEos(): Unit {
        @Expect(matchDeviceSignature(ARISTA_EOS_SHOW_VERSION) == DeviceType.AristaEOS, true)
    }

    @TestCase
    func detectsJunos(): Unit {
        @Expect(matchDeviceSignature(JUNOS_SHOW_VERSION) == DeviceType.JuniperJunOS, true)
    }

    @TestCase
    func detectsJunosFromAnUppercaseBanner(): Unit {
        @Expect(matchDeviceSignature("JUNOS Base OS boot [15.1X49-D100]") ==
                DeviceType.JuniperJunOS, true)
    }

    @TestCase
    func keepsTheCiscoFamiliesApart(): Unit {
        @Expect(matchDeviceSignature(IOS_XR_SHOW_VERSION) == DeviceType.CiscoXR, true)
        @Expect(matchDeviceSignature(NXOS_SHOW_VERSION) == DeviceType.CiscoNXOS, true)
        @Expect(matchDeviceSignature(CISCO_ASA_SHOW_VERSION) == DeviceType.CiscoASA, true)
        @Expect(matchDeviceSignature(CISCO_IOS_12_SHOW_VERSION) == DeviceType.CiscoIOS, true)
    }

    @TestCase
    func treatsShellNoiseAsUnknown(): Unit {
        @Expect(matchDeviceSignature(SHELL_ERROR_OUTPUT) == DeviceType.Generic, true)
        @Expect(matchDeviceSignature("") == DeviceType.Generic, true)
        @Expect(matchDeviceSignature("% Invalid input detected at '^' marker.") ==
                DeviceType.Generic, true)
    }

    @TestCase
    func detectionSurvivesCrlfAndAnsi(): Unit {
        let raw = "\u{1b}[0mCisco IOS Software, 7200 Software\r\nVersion 12.4(24)T5\r\n"
        @Expect(matchDeviceSignature(raw) == DeviceType.CiscoIOS, true)
    }

    @TestCase
    func seesAPromptWrappedInTerminalEscapes(): Unit {
        let stem = promptStem("Router>")
        let raw = "enable\u{1b}[?2004l\r\nRouter# \u{1b}[?2004h"

        @Expect(endsWithPrompt(raw, stem), false)
        @Expect(endsWithCleanPrompt(raw, stem), true)
        @Expect(endsWithCleanPrompt("show version\r\nCisco IOS Software\r\n", stem), false)
    }

    @TestCase
    func recognisesPasswordPrompts(): Unit {
        @Expect(looksLikePasswordPrompt("enable\r\nPassword: "), true)
        @Expect(looksLikePasswordPrompt("Password:"), true)
        @Expect(looksLikePasswordPrompt("enable\r\nEnter password:"), true)
        @Expect(looksLikePasswordPrompt("enable\r\nRouter#"), false)
        @Expect(looksLikePasswordPrompt("password is wrong"), false)
        @Expect(looksLikePasswordPrompt(""), false)
    }

    @TestCase
    func enableModeIsJudgedFromThePrompt(): Unit {
        @Expect(inEnableMode("Router>", DeviceType.CiscoIOS), false)
        @Expect(inEnableMode("Router#", DeviceType.CiscoIOS), true)
        @Expect(inEnableMode("Router(config)#", DeviceType.CiscoIOS), true)
        @Expect(inEnableMode("switch>", DeviceType.AristaEOS), false)
        @Expect(inEnableMode("switch#", DeviceType.AristaEOS), true)

        @Expect(inEnableMode("me@junos#", DeviceType.JuniperJunOS), false)
        @Expect(inEnableMode("host:~$", DeviceType.Generic), false)
        @Expect(inEnableMode("", DeviceType.CiscoIOS), false)
    }

    @TestCase
    func configModeIsJudgedFromThePrompt(): Unit {
        @Expect(inConfigMode("Router#", DeviceType.CiscoIOS), false)
        @Expect(inConfigMode("Router(config)#", DeviceType.CiscoIOS), true)
        @Expect(inConfigMode("Router(config-if)#", DeviceType.CiscoIOS), true)
        @Expect(inConfigMode("switch(config)#", DeviceType.AristaEOS), true)

        @Expect(inConfigMode("me@junos>", DeviceType.JuniperJunOS), false)
        @Expect(inConfigMode("me@junos#", DeviceType.JuniperJunOS), true)

        @Expect(inConfigMode("host:~$", DeviceType.Generic), false)
    }
}

@Test
class VendorPresetTests {
    @TestCase
    func newDeviceTypesUseNetmikoNames(): Unit {
        @Expect(DeviceType.CiscoNXOS.toString(), "cisco_nxos")
        @Expect(DeviceType.CiscoASA.toString(), "cisco_asa")
        @Expect(DeviceType.CiscoXR.toString(), "cisco_xr")
        @Expect(DeviceType.HuaweiVRP.toString(), "huawei")
        @Expect(DeviceType.HuaweiVRPv8.toString(), "huawei_vrpv8")
        @Expect(DeviceType.HPComware.toString(), "hp_comware")
        @Expect(DeviceType.PaloAltoPanOS.toString(), "paloalto_panos")
        @Expect(DeviceType.FortinetFortiOS.toString(), "fortinet")
        @Expect(DeviceType.DellOS10.toString(), "dell_os10")
        @Expect(DeviceType.MikrotikRouterOS.toString(), "mikrotik_routeros")
    }

    @TestCase
    func netmikoNamesParseBackToTheirDeviceType(): Unit {
        @Expect(parseDeviceType("cisco_nxos") == DeviceType.CiscoNXOS, true)
        @Expect(parseDeviceType("cisco_asa") == DeviceType.CiscoASA, true)
        @Expect(parseDeviceType("cisco_xr") == DeviceType.CiscoXR, true)
        @Expect(parseDeviceType("huawei") == DeviceType.HuaweiVRP, true)
        @Expect(parseDeviceType("huawei_vrpv8") == DeviceType.HuaweiVRPv8, true)
        @Expect(parseDeviceType("hp_comware") == DeviceType.HPComware, true)
        @Expect(parseDeviceType("paloalto_panos") == DeviceType.PaloAltoPanOS, true)
        @Expect(parseDeviceType("fortinet") == DeviceType.FortinetFortiOS, true)
        @Expect(parseDeviceType("dell_os10") == DeviceType.DellOS10, true)
        @Expect(parseDeviceType("mikrotik_routeros") == DeviceType.MikrotikRouterOS, true)

        @Expect(parseDeviceType("  CISCO_NXOS ") == DeviceType.CiscoNXOS, true)
        @Expect(parseDeviceType("panos") == DeviceType.PaloAltoPanOS, true)
        @Expect(parseDeviceType("routeros") == DeviceType.MikrotikRouterOS, true)
    }

    @TestCase
    func unsupportedNetmikoNamesStayGeneric(): Unit {
        @Expect(parseDeviceType("hp_procurve") == DeviceType.Generic, true)
        @Expect(parseDeviceType("dell_force10") == DeviceType.Generic, true)
        @Expect(parseDeviceType("linux") == DeviceType.Generic, true)
    }

    @TestCase
    func pagingCommandsAreThePlatformsOwn(): Unit {
        @Expect(deviceProfile(DeviceType.CiscoNXOS).pagingCommand, "terminal length 0")
        @Expect(deviceProfile(DeviceType.CiscoASA).pagingCommand, "terminal pager 0")
        @Expect(deviceProfile(DeviceType.CiscoXR).pagingCommand, "terminal length 0")
        @Expect(deviceProfile(DeviceType.DellOS10).pagingCommand, "terminal length 0")
        @Expect(deviceProfile(DeviceType.HuaweiVRP).pagingCommand, "screen-length 0 temporary")
        @Expect(deviceProfile(DeviceType.HuaweiVRPv8).pagingCommand, "screen-length 0 temporary")
        @Expect(deviceProfile(DeviceType.HPComware).pagingCommand, "screen-length disable")
        @Expect(deviceProfile(DeviceType.PaloAltoPanOS).pagingCommand, "set cli pager off")
        @Expect(deviceProfile(DeviceType.FortinetFortiOS).pagingCommand, "")
        @Expect(deviceProfile(DeviceType.MikrotikRouterOS).pagingCommand, "")
    }

    @TestCase
    func onlyTwoTierPlatformsClaimAnEnableStep(): Unit {
        @Expect(deviceProfile(DeviceType.CiscoNXOS).supportsEnable, true)
        @Expect(deviceProfile(DeviceType.CiscoASA).supportsEnable, true)
        @Expect(deviceProfile(DeviceType.DellOS10).supportsEnable, true)
        @Expect(deviceProfile(DeviceType.CiscoNXOS).enableCommand, "enable")

        @Expect(deviceProfile(DeviceType.CiscoXR).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.HuaweiVRP).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.HuaweiVRPv8).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.HPComware).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.PaloAltoPanOS).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.FortinetFortiOS).supportsEnable, false)
        @Expect(deviceProfile(DeviceType.MikrotikRouterOS).supportsEnable, false)
    }

    @TestCase
    func configModeCommandsMatchTheVendorCli(): Unit {
        let nxos = deviceProfile(DeviceType.CiscoNXOS)
        @Expect(nxos.configCommand, "configure terminal")
        @Expect(nxos.exitConfigCommand, "end")

        let asa = deviceProfile(DeviceType.CiscoASA)
        @Expect(asa.configCommand, "configure terminal")
        @Expect(asa.exitConfigCommand, "end")

        let dell = deviceProfile(DeviceType.DellOS10)
        @Expect(dell.configCommand, "configure terminal")
        @Expect(dell.exitConfigCommand, "end")

        let huawei = deviceProfile(DeviceType.HuaweiVRP)
        @Expect(huawei.configCommand, "system-view")
        @Expect(huawei.exitConfigCommand, "return")

        let comware = deviceProfile(DeviceType.HPComware)
        @Expect(comware.configCommand, "system-view")
        @Expect(comware.exitConfigCommand, "return")

        let panos = deviceProfile(DeviceType.PaloAltoPanOS)
        @Expect(panos.configCommand, "configure")
        @Expect(panos.exitConfigCommand, "exit")
    }

    @TestCase
    func platformsWithoutAGlobalConfigModeSaySo(): Unit {
        @Expect(deviceProfile(DeviceType.FortinetFortiOS).supportsConfigMode, false)
        @Expect(deviceProfile(DeviceType.FortinetFortiOS).configCommand, "")
        @Expect(deviceProfile(DeviceType.MikrotikRouterOS).supportsConfigMode, false)
        @Expect(deviceProfile(DeviceType.MikrotikRouterOS).configCommand, "")
    }

    @TestCase
    func onlyCommitBasedPlatformsCarryACommitCommand(): Unit {
        @Expect(deviceProfile(DeviceType.CiscoXR).commitCommand, "commit")
        @Expect(deviceProfile(DeviceType.CiscoXR).requiresCommit, true)
        @Expect(deviceProfile(DeviceType.PaloAltoPanOS).commitCommand, "commit")
        @Expect(deviceProfile(DeviceType.PaloAltoPanOS).requiresCommit, true)
        @Expect(deviceProfile(DeviceType.HuaweiVRPv8).commitCommand, "commit")
        @Expect(deviceProfile(DeviceType.HuaweiVRPv8).requiresCommit, true)

        @Expect(deviceProfile(DeviceType.CiscoIOS).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.AristaEOS).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.JuniperJunOS).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.CiscoNXOS).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.CiscoASA).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.DellOS10).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.HuaweiVRP).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.HPComware).requiresCommit, false)
        @Expect(deviceProfile(DeviceType.Generic).requiresCommit, false)
    }

    @TestCase
    func everyProfileReportsItsOwnTypeAndName(): Unit {
        @Expect(deviceProfile(DeviceType.CiscoNXOS).displayName, "Cisco NX-OS")
        @Expect(deviceProfile(DeviceType.CiscoXR).displayName, "Cisco IOS-XR")
        @Expect(deviceProfile(DeviceType.HuaweiVRP).displayName, "Huawei VRP")
        @Expect(deviceProfile(DeviceType.HPComware).displayName, "HP Comware")
        @Expect(deviceProfile(DeviceType.PaloAltoPanOS).displayName, "Palo Alto PAN-OS")
        @Expect(deviceProfile(DeviceType.FortinetFortiOS).displayName, "Fortinet FortiOS")
        @Expect(deviceProfile(DeviceType.DellOS10).displayName, "Dell OS10")
        @Expect(deviceProfile(DeviceType.MikrotikRouterOS).displayName, "MikroTik RouterOS")

        for (t in [DeviceType.CiscoNXOS, DeviceType.CiscoASA, DeviceType.CiscoXR,
                   DeviceType.HuaweiVRP, DeviceType.HuaweiVRPv8, DeviceType.HPComware,
                   DeviceType.PaloAltoPanOS, DeviceType.FortinetFortiOS, DeviceType.DellOS10,
                   DeviceType.MikrotikRouterOS]) {
            @Expect(deviceProfile(t).deviceType == t, true)
        }
    }

    @TestCase
    func existingPresetsAreUnchanged(): Unit {
        let ios = deviceProfile(DeviceType.CiscoIOS)
        @Expect(ios.pagingCommand, "terminal length 0")
        @Expect(ios.supportsEnable, true)
        @Expect(ios.enableCommand, "enable")
        @Expect(ios.configCommand, "configure terminal")
        @Expect(ios.exitConfigCommand, "end")
        @Expect(ios.commitCommand, "")

        let junos = deviceProfile(DeviceType.JuniperJunOS)
        @Expect(junos.pagingCommand, "set cli screen-length 0")
        @Expect(junos.configCommand, "configure")
        @Expect(junos.exitConfigCommand, "exit")
        @Expect(junos.commitCommand, "")
    }
}

@Test
class VendorDetectionTests {
    @TestCase
    func detectsNxosAndIosXrInsteadOfRefusing(): Unit {
        @Expect(matchDeviceSignature(NXOS_SHOW_VERSION) == DeviceType.CiscoNXOS, true)
        @Expect(matchDeviceSignature(IOS_XR_SHOW_VERSION) == DeviceType.CiscoXR, true)
        @Expect(matchDeviceSignature("Cisco Nexus Operating System (NX-OS) Software") ==
                DeviceType.CiscoNXOS, true)
    }

    @TestCase
    func detectsAsa(): Unit {
        @Expect(matchDeviceSignature(CISCO_ASA_SHOW_VERSION) == DeviceType.CiscoASA, true)
    }

    @TestCase
    func detectsHuaweiAndTellsV5FromV8(): Unit {
        @Expect(matchDeviceSignature(HUAWEI_VRP5_DISPLAY_VERSION) == DeviceType.HuaweiVRP, true)
        @Expect(matchDeviceSignature(HUAWEI_VRP8_DISPLAY_VERSION) == DeviceType.HuaweiVRPv8, true)
    }

    @TestCase
    func detectsComwareBeforeHuawei(): Unit {
        @Expect(matchDeviceSignature(HP_COMWARE_DISPLAY_VERSION) == DeviceType.HPComware, true)
        @Expect(matchDeviceSignature("H3C Comware Platform Software, Software Version 5.20") ==
                DeviceType.HPComware, true)
    }

    @TestCase
    func detectsFortinetPanosDellAndMikrotik(): Unit {
        @Expect(matchDeviceSignature(FORTINET_GET_SYSTEM_STATUS) == DeviceType.FortinetFortiOS,
                true)
        @Expect(matchDeviceSignature(PANOS_SHOW_SYSTEM_INFO) == DeviceType.PaloAltoPanOS, true)
        @Expect(matchDeviceSignature(DELL_OS10_SHOW_VERSION) == DeviceType.DellOS10, true)
        @Expect(matchDeviceSignature(MIKROTIK_SYSTEM_RESOURCE) == DeviceType.MikrotikRouterOS,
                true)
    }

    @TestCase
    func detectionStillRefusesUnknownText(): Unit {
        @Expect(matchDeviceSignature(SHELL_ERROR_OUTPUT) == DeviceType.Generic, true)
        @Expect(matchDeviceSignature("% Invalid input detected at '^' marker.") ==
                DeviceType.Generic, true)
        @Expect(matchDeviceSignature("Error: Unrecognized command found at '^' position.") ==
                DeviceType.Generic, true)
        @Expect(matchDeviceSignature("uptime: 3d4h12m\nversion: 6.48.6") == DeviceType.Generic,
                true)
    }

    @TestCase
    func detectionCommandsCoverThePlatformsThatNeedThem(): Unit {
        @Expect(DEVICE_DETECT_COMMANDS[0], "show version")
        @Expect(DEVICE_DETECT_COMMANDS.size, 5)

        var seen = false
        for (c in DEVICE_DETECT_COMMANDS) {
            if (c == "display version") {
                seen = true
            }
        }
        @Expect(seen, true)
    }
}

@Test
class VendorPromptModeTests {
    @TestCase
    func enableModeIsJudgedPerPlatform(): Unit {
        @Expect(inEnableMode("switch>", DeviceType.CiscoNXOS), false)
        @Expect(inEnableMode("switch#", DeviceType.CiscoNXOS), true)
        @Expect(inEnableMode("ciscoasa>", DeviceType.CiscoASA), false)
        @Expect(inEnableMode("ciscoasa#", DeviceType.CiscoASA), true)
        @Expect(inEnableMode("OS10>", DeviceType.DellOS10), false)
        @Expect(inEnableMode("OS10#", DeviceType.DellOS10), true)

        @Expect(inEnableMode("RP/0/RP0/CPU0:R1#", DeviceType.CiscoXR), false)
        @Expect(inEnableMode("<Huawei>", DeviceType.HuaweiVRP), false)
        @Expect(inEnableMode("[Huawei]", DeviceType.HuaweiVRP), false)
        @Expect(inEnableMode("admin@PA-VM>", DeviceType.PaloAltoPanOS), false)
        @Expect(inEnableMode("FGT #", DeviceType.FortinetFortiOS), false)
        @Expect(inEnableMode("[admin@MikroTik] >", DeviceType.MikrotikRouterOS), false)
    }

    @TestCase
    func configModeIsJudgedPerPlatform(): Unit {
        @Expect(inConfigMode("switch#", DeviceType.CiscoNXOS), false)
        @Expect(inConfigMode("switch(config)#", DeviceType.CiscoNXOS), true)
        @Expect(inConfigMode("switch(config-if)#", DeviceType.CiscoNXOS), true)
        @Expect(inConfigMode("ciscoasa(config)#", DeviceType.CiscoASA), true)
        @Expect(inConfigMode("OS10(config)#", DeviceType.DellOS10), true)

        @Expect(inConfigMode("RP/0/RP0/CPU0:R1#", DeviceType.CiscoXR), false)
        @Expect(inConfigMode("RP/0/RP0/CPU0:R1(config)#", DeviceType.CiscoXR), true)
        @Expect(inConfigMode("RP/0/RP0/CPU0:R1(config-if)#", DeviceType.CiscoXR), true)

        @Expect(inConfigMode("<Huawei>", DeviceType.HuaweiVRP), false)
        @Expect(inConfigMode("[Huawei]", DeviceType.HuaweiVRP), true)
        @Expect(inConfigMode("[Huawei-GigabitEthernet0/0/1]", DeviceType.HuaweiVRP), true)
        @Expect(inConfigMode("[~HUAWEI]", DeviceType.HuaweiVRPv8), true)
        @Expect(inConfigMode("<HP>", DeviceType.HPComware), false)
        @Expect(inConfigMode("[HP]", DeviceType.HPComware), true)

        @Expect(inConfigMode("admin@PA-VM>", DeviceType.PaloAltoPanOS), false)
        @Expect(inConfigMode("admin@PA-VM#", DeviceType.PaloAltoPanOS), true)

        @Expect(inConfigMode("FGT # ", DeviceType.FortinetFortiOS), false)
        @Expect(inConfigMode("[admin@MikroTik] >", DeviceType.MikrotikRouterOS), false)
    }

    @TestCase
    func bracketPromptsAreRecognisedWithoutBreakingJunosEditBanners(): Unit {
        @Expect(looksLikeBracketPrompt("[Huawei]"), true)
        @Expect(looksLikeBracketPrompt("[Huawei-GigabitEthernet0/0/1]"), true)
        @Expect(looksLikeBracketPrompt("[HP]"), true)
        @Expect(looksLikeBracketPrompt("[edit]"), false)
        @Expect(looksLikeBracketPrompt("[edit interfaces ge-0/0/0]"), false)
        @Expect(looksLikeBracketPrompt("Router#"), false)
        @Expect(looksLikeBracketPrompt("[]"), false)

        @Expect(promptStem("[Huawei]"), "[Huawei")
        @Expect(promptStem("<Huawei>"), "<Huawei")
        @Expect(promptStem("[HP-GigabitEthernet1/0/1]"), "[HP-GigabitEthernet1/0/1")

        @Expect(endsWithPrompt("display version\r\n[Huawei]", "[Huawei"), true)
        @Expect(endsWithPrompt("system-view\r\n[Huawei-Vlanif10]", "[Huawei"), true)
        @Expect(endsWithPrompt("show configuration\r\n[edit]", ""), false)
        @Expect(endsWithPrompt("show configuration\r\n[edit]\r\nme@junos# ", ""), true)
    }

    @TestCase
    func aHuaweiCommandLosesItsTrailingSystemViewPrompt(): Unit {
        let raw = "display version\r\nHuawei Versatile Routing Platform Software\r\n[Huawei]"
        @Expect(extractCommandOutput(raw, "display version", "[Huawei").contains("[Huawei]"),
                false)
        @Expect(extractCommandOutput(raw, "display version", "[Huawei").contains("Versatile"),
                true)
    }
}

@Test
class RetryPolicyTests {
    @TestCase
    func backoffDoublesAndIsCapped(): Unit {
        @Expect(retryDelayMs(0, 500, 30000), 500)
        @Expect(retryDelayMs(1, 500, 30000), 1000)
        @Expect(retryDelayMs(2, 500, 30000), 2000)
        @Expect(retryDelayMs(3, 500, 30000), 4000)
        @Expect(retryDelayMs(20, 500, 30000), 30000)
        @Expect(retryDelayMs(2, 500, 900), 900)
    }

    @TestCase
    func backoffHandlesDegenerateSettings(): Unit {
        @Expect(retryDelayMs(0, 0, 30000), 0)
        @Expect(retryDelayMs(5, -1, 30000), 0)
        @Expect(retryDelayMs(0, 1000, 0), 1000)
        @Expect(retryDelayMs(60, 1000, 0), 300000)
    }

    @TestCase
    func retryOptionDefaultsPreserveOldBehaviour(): Unit {
        let o = ConnectionOptions()
        @Expect(o.maxRetries, 0)
        @Expect(o.retryBackoffMs > 0, true)
        @Expect(o.retryMaxBackoffMs > o.retryBackoffMs, true)
        @Expect(o.deviceType == DeviceType.Generic, true)
        @Expect(o.autoDetectDeviceType, false)
        @Expect(o.pagingCommand, "")
        @Expect(o.enablePassword, "")
    }

    @TestCase
    func rejectsNegativeMaxRetries(): Unit {
        let o = ConnectionOptions("127.0.0.1", 22, "admin", "secret")
        o.maxRetries = -1
        try {
            SSHConnection.connect(o)
            @Fail("expected ConnectionException for a negative maxRetries")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("maxRetries"), true)
        }
    }

    @TestCase
    func retriesARefusedConnectionThenGivesUp(): Unit {
        let o = ConnectionOptions("127.0.0.1", 1, "admin", "secret")
        o.connectTimeoutMs = 3000
        o.maxRetries = 2
        o.retryBackoffMs = 250
        o.retryMaxBackoffMs = 30000

        let start = MonoTime.now()
        try {
            SSHConnection.connect(o)
            @Fail("expected ConnectionException connecting to 127.0.0.1:1")
        } catch (e: ConnectionException) {
            @Expect(e.errnoValue, 111)
        }
        let elapsed = (MonoTime.now() - start).toMilliseconds()

        @Expect(elapsed >= 750, true)
    }

    @TestCase
    func zeroRetriesFailsImmediately(): Unit {
        let o = ConnectionOptions("127.0.0.1", 1, "admin", "secret")
        o.connectTimeoutMs = 3000
        o.retryBackoffMs = 5000

        let start = MonoTime.now()
        try {
            SSHConnection.connect(o)
            @Fail("expected ConnectionException connecting to 127.0.0.1:1")
        } catch (_: ConnectionException) {
        }
        @Expect((MonoTime.now() - start).toMilliseconds() < 2000, true)
    }
}

func deviceTestOptions(): ConnectionOptions {
    let o = ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                              UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                              envOr("GLYPHNET_TEST_SSH_USER", "root"),
                              envOr("GLYPHNET_TEST_SSH_PASSWORD", ""))
    o.commandTimeoutMs = 20000
    return o
}

@Test
class LiveDeviceDriverTests {
    @TestCase
    func presetFillsInThePagingCommand(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.deviceType = DeviceType.CiscoIOS
        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.deviceType == DeviceType.CiscoIOS, true)
            @Expect(conn.pagingCommand, "terminal length 0")
            @Expect(conn.devicePreset.displayName, "Cisco IOS")

            @Expect(conn.sendCommand("echo STILL_ALIVE").contains("STILL_ALIVE"), true)
        }
    }

    @TestCase
    func explicitPagingCommandBeatsThePreset(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.deviceType = DeviceType.JuniperJunOS
        o.pagingCommand = "echo CUSTOM_PAGING"
        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.pagingCommand, "echo CUSTOM_PAGING")
            @Expect(conn.deviceType == DeviceType.JuniperJunOS, true)
        }
    }

    @TestCase
    func detectReportsGenericForALinuxShell(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            @Expect(conn.detectDeviceType() == DeviceType.Generic, true)

            @Expect(conn.sendCommand("echo AFTER_DETECT").contains("AFTER_DETECT"), true)
        }
    }

    @TestCase
    func autoDetectLeavesAnUnknownDeviceGeneric(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.autoDetectDeviceType = true
        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.deviceType == DeviceType.Generic, true)
            @Expect(conn.pagingCommand, "")
        }
    }

    @TestCase
    func genericDevicesRefuseEnableAndConfigMode(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            try {
                conn.enable()
                @Fail("expected CommandException for enable() on a generic device")
            } catch (e: CommandException) {
                @Expect(e.message.contains("no enable mode"), true)
            }
            try {
                conn.configMode()
                @Fail("expected CommandException for configMode() on a generic device")
            } catch (e: CommandException) {
                @Expect(e.message.contains("no configuration mode"), true)
            }
        }
    }

    @TestCase
    func junosHasNoEnableMode(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.deviceType = DeviceType.JuniperJunOS
        try (conn = SSHConnection.connect(o)) {
            try {
                conn.enable()
                @Fail("expected CommandException for enable() on JunOS")
            } catch (e: CommandException) {
                @Expect(e.message.contains("no enable mode"), true)
            }
        }
    }

    @TestCase
    func enableAndConfigModeTrackThePromptStateMachine(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            conn.sendCommand("enable() { PS1='Router# '; }")
            conn.sendCommand("configure() { PS1='Router(config)# '; }")
            conn.sendCommand("end() { PS1='Router# '; }")
            conn.sendCommand("PS1='Router> '")
            @Expect(conn.findPrompt(), "Router>")

            conn.redispatch(DeviceType.CiscoIOS)
            @Expect(conn.deviceType == DeviceType.CiscoIOS, true)
            @Expect(conn.isEnableMode(), false)

            conn.enable()
            @Expect(conn.prompt, "Router#")
            @Expect(conn.isEnableMode(), true)
            @Expect(conn.isConfigMode(), false)

            conn.configMode()
            @Expect(conn.prompt, "Router(config)#")
            @Expect(conn.isConfigMode(), true)

            @Expect(conn.sendCommand("echo IN_CONFIG").contains("IN_CONFIG"), true)

            conn.exitConfigMode()
            @Expect(conn.prompt, "Router#")
            @Expect(conn.isConfigMode(), false)

            conn.configMode()
            @Expect(conn.isConfigMode(), true)
            @Expect(conn.configMode(), "")
            conn.exitConfigMode()
            @Expect(conn.isConfigMode(), false)
            @Expect(conn.exitConfigMode(), "")
        }
    }

    @TestCase
    func sendConfigBracketsCommandsWithConfigMode(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            conn.sendCommand("enable() { PS1='Router# '; }")
            conn.sendCommand("configure() { PS1='Router(config)# '; }")
            conn.sendCommand("end() { PS1='Router# '; }")
            conn.sendCommand("PS1='Router# '")
            conn.findPrompt()
            conn.redispatch(DeviceType.CiscoIOS)
            @Expect(conn.isEnableMode(), true)

            let outputs = conn.sendConfig(["echo LINE_ONE", "echo LINE_TWO"])
            @Expect(outputs.size, 2)
            @Expect(outputs[0].contains("LINE_ONE"), true)
            @Expect(outputs[1].contains("LINE_TWO"), true)
            @Expect(conn.isConfigMode(), false)
            @Expect(conn.prompt, "Router#")
        }
    }

    @TestCase
    func configModeNeedsEnableFirst(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            conn.sendCommand("PS1='Router> '")
            conn.findPrompt()
            conn.redispatch(DeviceType.CiscoIOS)
            try {
                conn.configMode()
                @Fail("expected CommandException asking for enable() first")
            } catch (e: CommandException) {
                @Expect(e.message.contains("privileged mode"), true)
            }
        }
    }

    @TestCase
    func enableReportsWhenThePromptNeverBecomesPrivileged(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            conn.sendCommand("enable() { echo NOT_TODAY; }")
            conn.sendCommand("PS1='Router> '")
            conn.findPrompt()
            conn.redispatch(DeviceType.CiscoIOS)
            try {
                conn.enable()
                @Fail("expected AuthenticationException when the prompt stays unprivileged")
            } catch (e: AuthenticationException) {
                @Expect(e.message.contains("privileged mode"), true)
            }
        }
    }
}

func installFakeIosXr(conn: SSHConnection): Unit {
    conn.sendCommand("configure() { PS1='RP/0/RP0/CPU0:R1(config)# '; }")
    conn.sendCommand("commit() { echo 'COMMITTED_OK'; }")
    conn.sendCommand("end() { PS1='RP/0/RP0/CPU0:R1# '; }")
    conn.sendCommand("PS1='RP/0/RP0/CPU0:R1# '")
    conn.findPrompt()
    conn.redispatch(DeviceType.CiscoXR)
}

func installFakeHuawei(conn: SSHConnection): Unit {
    conn.sendCommand("system-view() { PS1='[Huawei] '; }")
    conn.sendCommand("return() { PS1='<Huawei> '; }")
    conn.sendCommand("PS1='<Huawei> '")
    conn.findPrompt()
    conn.redispatch(DeviceType.HuaweiVRP)
}

@Test
class LiveCommitPlatformTests {
    @TestCase
    func exitConfigModeCommitsOnACommitBasedPlatform(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installFakeIosXr(conn)
            @Expect(conn.deviceType == DeviceType.CiscoXR, true)
            @Expect(conn.devicePreset.requiresCommit, true)
            @Expect(conn.isConfigMode(), false)

            conn.configMode()
            @Expect(conn.prompt, "RP/0/RP0/CPU0:R1(config)#")
            @Expect(conn.isConfigMode(), true)

            let out = conn.exitConfigMode()
            @Expect(out.contains("COMMITTED_OK"), true)
            @Expect(conn.isConfigMode(), false)
            @Expect(conn.prompt, "RP/0/RP0/CPU0:R1#")
        }
    }

    @TestCase
    func commitCanBeCalledOnItsOwnInsideConfigMode(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installFakeIosXr(conn)
            conn.configMode()
            @Expect(conn.commit().contains("COMMITTED_OK"), true)
            @Expect(conn.isConfigMode(), true)
            conn.exitConfigMode()
            @Expect(conn.isConfigMode(), false)
        }
    }

    @TestCase
    func commitRefusesOutsideConfigModeAndOffCommitPlatforms(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installFakeIosXr(conn)
            try {
                conn.commit()
                @Fail("expected CommandException for commit() outside configuration mode")
            } catch (e: CommandException) {
                @Expect(e.message.contains("configuration mode"), true)
            }

            conn.redispatch(DeviceType.CiscoIOS)
            try {
                conn.commit()
                @Fail("expected CommandException for commit() on Cisco IOS")
            } catch (e: CommandException) {
                @Expect(e.message.contains("no commit step"), true)
            }
        }
    }

    @TestCase
    func sendConfigCommitsBeforeLeavingConfigMode(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installFakeIosXr(conn)
            let outputs = conn.sendConfig(["echo XR_LINE_ONE", "echo XR_LINE_TWO"])
            @Expect(outputs.size, 2)
            @Expect(outputs[0].contains("XR_LINE_ONE"), true)
            @Expect(conn.isConfigMode(), false)
            @Expect(conn.prompt, "RP/0/RP0/CPU0:R1#")
        }
    }

    @TestCase
    func huaweiSystemViewIsTrackedAsConfigMode(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installFakeHuawei(conn)
            @Expect(conn.deviceType == DeviceType.HuaweiVRP, true)
            @Expect(conn.prompt, "<Huawei>")
            @Expect(conn.isConfigMode(), false)
            @Expect(conn.isEnableMode(), false)

            conn.configMode()
            @Expect(conn.prompt, "[Huawei]")
            @Expect(conn.isConfigMode(), true)
            @Expect(conn.sendCommand("echo IN_SYSTEM_VIEW").contains("IN_SYSTEM_VIEW"), true)

            conn.exitConfigMode()
            @Expect(conn.prompt, "<Huawei>")
            @Expect(conn.isConfigMode(), false)
        }
    }

    @TestCase
    func huaweiHasNoEnableStep(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.deviceType = DeviceType.HuaweiVRP
        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.pagingCommand, "screen-length 0 temporary")
            try {
                conn.enable()
                @Fail("expected CommandException for enable() on Huawei VRP")
            } catch (e: CommandException) {
                @Expect(e.message.contains("no enable mode"), true)
            }
        }
    }

    @TestCase
    func fortinetRefusesConfigModeRatherThanGuessing(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.deviceType = DeviceType.FortinetFortiOS
        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.pagingCommand, "")
            try {
                conn.configMode()
                @Fail("expected CommandException for configMode() on FortiOS")
            } catch (e: CommandException) {
                @Expect(e.message.contains("no configuration mode"), true)
            }
        }
    }
}

func installPasswordProtectedEnable(conn: SSHConnection, secret: String): Unit {
    conn.sendCommand("enable() { i=0; while [ $i -lt 3 ]; do printf 'Password: '; read -r pw; " +
                     "printf '\\n'; if [ \"$pw\" = '" + secret + "' ]; then PS1='Router# '; " +
                     "return 0; fi; i=$((i+1)); done; printf '%% Bad passwords\\n'; }")
    conn.sendCommand("PS1='Router> '")
    conn.findPrompt()
    conn.redispatch(DeviceType.CiscoIOS)
}

@Test
class LiveEnablePasswordTests {
    @TestCase
    func enableAnswersAPasswordChallenge(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installPasswordProtectedEnable(conn, "s3cret")
            @Expect(conn.isEnableMode(), false)

            conn.enable("s3cret")
            @Expect(conn.prompt, "Router#")
            @Expect(conn.isEnableMode(), true)
        }
    }

    @TestCase
    func enableUsesTheStoredEnablePassword(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.enablePassword = "s3cret"
        try (conn = SSHConnection.connect(o)) {
            installPasswordProtectedEnable(conn, "s3cret")
            conn.enable()
            @Expect(conn.isEnableMode(), true)
        }
    }

    @TestCase
    func enableRejectsABadPasswordAndRecoversThePrompt(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installPasswordProtectedEnable(conn, "s3cret")
            try {
                conn.enable("wrong-password")
                @Fail("expected AuthenticationException for a rejected enable password")
            } catch (e: AuthenticationException) {
                @Expect(e.message.contains("rejected"), true)
            }

            @Expect(conn.isEnableMode(), false)
            @Expect(conn.sendCommand("echo RECOVERED").contains("RECOVERED"), true)
        }
    }

    @TestCase
    func enableRefusesWhenNoPasswordIsAvailable(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = SSHConnection.connect(deviceTestOptions())) {
            installPasswordProtectedEnable(conn, "s3cret")
            try {
                conn.enable()
                @Fail("expected AuthenticationException when no enable password is set")
            } catch (e: AuthenticationException) {
                @Expect(e.message.contains("none was supplied"), true)
            }

            @Expect(conn.isEnableMode(), false)
            @Expect(conn.sendCommand("echo RECOVERED").contains("RECOVERED"), true)
        }
    }
}

@Test
class LiveReconnectTests {
    @TestCase
    func reconnectRestoresAUsableShell(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let conn = SSHConnection.connect(deviceTestOptions())
        try {
            @Expect(conn.sendCommand("echo BEFORE").contains("BEFORE"), true)
            conn.sendCommand("GLYPHNET_MARKER=alive")
            @Expect(conn.sendCommand("echo [$GLYPHNET_MARKER]").contains("alive"), true)

            conn.reconnect()

            @Expect(conn.isClosed(), false)
            @Expect(conn.isAlive(), true)
            @Expect(conn.prompt.isEmpty(), false)
            @Expect(conn.sendCommand("echo AFTER").contains("AFTER"), true)

            @Expect(conn.sendCommand("echo [$GLYPHNET_MARKER]").contains("alive"), false)
        } finally {
            conn.close()
        }
    }

    @TestCase
    func reconnectRevivesADisconnectedSession(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let conn = SSHConnection.connect(deviceTestOptions())
        try {
            conn.disconnect()
            @Expect(conn.isClosed(), true)

            conn.reconnect()
            @Expect(conn.isClosed(), false)
            @Expect(conn.sendCommand("echo REVIVED").contains("REVIVED"), true)
            @Expect(conn.serverBanner().startsWith("SSH-"), true)
        } finally {
            conn.close()
        }
    }

    @TestCase
    func reconnectReappliesTheDevicePreset(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        o.deviceType = DeviceType.CiscoIOS
        let conn = SSHConnection.connect(o)
        try {
            conn.redispatch(DeviceType.Generic)
            @Expect(conn.pagingCommand, "")

            conn.reconnect()
            @Expect(conn.deviceType == DeviceType.CiscoIOS, true)
            @Expect(conn.pagingCommand, "terminal length 0")
        } finally {
            conn.close()
        }
    }

    @TestCase
    func reconnectSurfacesFailureAndLeavesTheConnectionClosed(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        let o = deviceTestOptions()
        let conn = SSHConnection.connect(o)
        try {
            @Expect(conn.isClosed(), false)

            o.port = 1
            o.connectTimeoutMs = 2000
            o.maxRetries = 1
            o.retryBackoffMs = 100
            try {
                conn.reconnect()
                @Fail("expected ConnectionException reconnecting to a refused port")
            } catch (e: ConnectionException) {
                @Expect(e.errnoValue, 111)
            }
            @Expect(conn.isClosed(), true)

            try {
                conn.sendCommand("echo nope")
                @Fail("expected CommandException on a closed connection")
            } catch (e: CommandException) {
                @Expect(e.message.contains("closed"), true)
            }
        } finally {
            conn.close()
        }
    }

    @TestCase
    func authenticationFailuresAreNotRetried(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST")) {
            return
        }
        let o = ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                                  UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                                  envOr("GLYPHNET_TEST_SSH_USER", "root"),
                                  "definitely-not-the-password-7c2b")
        o.maxRetries = 3
        o.retryBackoffMs = 3000

        let start = MonoTime.now()
        try {
            SSHConnection.connect(o)
            @Fail("expected AuthenticationException for a wrong password")
        } catch (_: AuthenticationException) {
        }
        let elapsed = (MonoTime.now() - start).toMilliseconds()

        @Expect(elapsed < 6000, true)
    }
}

@Test
class LiveCiscoRouterTests {
    @TestCase
    func autodetectIdentifiesARealCiscoIosRouter(): Unit {
        if (!envSet("GLYPHNET_TEST_CISCO_HOST")) {
            return
        }
        let o = ConnectionOptions(envOr("GLYPHNET_TEST_CISCO_HOST", ""),
                                  UInt16.parse(envOr("GLYPHNET_TEST_CISCO_PORT", "22")),
                                  envOr("GLYPHNET_TEST_CISCO_USER", "admin"),
                                  envOr("GLYPHNET_TEST_CISCO_PASSWORD", ""))
        o.commandTimeoutMs = 30000
        o.autoDetectDeviceType = true

        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.deviceType == DeviceType.CiscoIOS, true)
            @Expect(conn.pagingCommand, "terminal length 0")
            @Expect(conn.devicePreset.configCommand, "configure terminal")
            @Expect(conn.prompt.endsWith("#"), true)
            @Expect(conn.isEnableMode(), true)
            @Expect(conn.isConfigMode(), false)

            @Expect(conn.sendCommand("show version").contains("Cisco IOS Software"), true)
        }
    }
}
