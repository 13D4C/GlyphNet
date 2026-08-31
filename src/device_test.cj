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
    func refusesToGuessForUnsupportedCiscoFamilies(): Unit {
        @Expect(matchDeviceSignature(IOS_XR_SHOW_VERSION) == DeviceType.Generic, true)
        @Expect(matchDeviceSignature(NXOS_SHOW_VERSION) == DeviceType.Generic, true)
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
