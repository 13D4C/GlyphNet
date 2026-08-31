package glyphnet

import glyphnet.errors.*
import std.unittest.*
import std.unittest.testmacro.*
import std.convert.*

func hexBytes(bytes: Array<UInt8>): String {
    return hexOf(bytes)
}

func feedAll(n: TelnetNegotiator, bytes: Array<UInt8>): (String, String) {
    let r = n.feed(bytes, bytes.size)
    return (String.fromUtf8(r[0]), hexOf(r[1]))
}

func defaultNegotiator(): TelnetNegotiator {
    return TelnetNegotiator("vt100", 511, 4096, true)
}

@Test
class TelnetEncodingTests {
    @TestCase
    func doublesIacInOutboundData(): Unit {
        let out = encodeTelnetData([UInt8(65), IAC, UInt8(66)])
        @Expect(hexOf(out), "41ffff42")
    }

    @TestCase
    func turnsBareLfIntoCrLf(): Unit {
        @Expect(hexOf(encodeTelnetData("a\n".toArray())), "610d0a")
    }

    @TestCase
    func leavesAnExistingCrLfAlone(): Unit {
        @Expect(hexOf(encodeTelnetData("a\r\n".toArray())), "610d0a")
    }

    @TestCase
    func leavesPlainAsciiAlone(): Unit {
        @Expect(String.fromUtf8(encodeTelnetData("show version".toArray())), "show version")
    }
}

@Test
class Utf8SafeSplitTests {
    @TestCase
    func passesAsciiThrough(): Unit {
        let r = utf8SafeSplit("Router# ".toArray())
        @Expect(r[0], "Router# ")
        @Expect(r[1].size, 0)
    }

    @TestCase
    func holdsBackAnIncompleteSequence(): Unit {
        let r = utf8SafeSplit([UInt8(65), UInt8(0xE4), UInt8(0xB8)])
        @Expect(r[0], "A")
        @Expect(r[1].size, 2)
    }

    @TestCase
    func rejoinsASplitSequence(): Unit {
        let first = utf8SafeSplit([UInt8(0xE4), UInt8(0xB8)])
        let merged = Array<UInt8>(3, repeat: 0)
        merged[0] = first[1][0]
        merged[1] = first[1][1]
        merged[2] = UInt8(0xAD)
        let second = utf8SafeSplit(merged)
        @Expect(second[0], "中")
        @Expect(second[1].size, 0)
    }

    @TestCase
    func dropsInvalidBytesInsteadOfThrowing(): Unit {
        let r = utf8SafeSplit([UInt8(65), UInt8(0xFE), UInt8(66)])
        @Expect(r[0], "AB")
    }
}

@Test
class TelnetNegotiationTests {
    @TestCase
    func stripsCommandsFromTheDataStream(): Unit {
        let n = defaultNegotiator()
        let r = feedAll(n, [UInt8(65), IAC, WILL, TELOPT_SGA, UInt8(66)])
        @Expect(r[0], "AB")
    }

    @TestCase
    func acceptsRemoteEchoAndSuppressGoAhead(): Unit {
        let n = defaultNegotiator()
        let r = feedAll(n, [IAC, WILL, TELOPT_ECHO, IAC, WILL, TELOPT_SGA])
        @Expect(r[1], "fffd01fffd03")
        @Expect(n.remoteEchoEnabled(), true)
        @Expect(n.remoteSuppressGoAhead(), true)
    }

    @TestCase
    func refusesToEchoBackToTheDevice(): Unit {
        let n = defaultNegotiator()
        let r = feedAll(n, [IAC, DO, TELOPT_ECHO])
        @Expect(r[1], "fffc01")
        @Expect(n.localOptionEnabled(TELOPT_ECHO), false)
    }

    @TestCase
    func refusesExoticOptions(): Unit {
        let n = defaultNegotiator()
        let r = feedAll(n, [IAC, WILL, UInt8(34), IAC, DO, TELOPT_BINARY])
        @Expect(r[1], "fffe22fffc00")
    }

    @TestCase
    func answersTheBusyboxOpeningSequence(): Unit {
        let n = defaultNegotiator()
        let r = feedAll(n, [IAC, DO, TELOPT_ECHO, IAC, DO, TELOPT_NAWS, IAC, WILL, TELOPT_ECHO,
                            IAC, WILL, TELOPT_SGA])
        @Expect(r[1], "fffc01fffb1ffffa1f01ffff1000fff0fffd01fffd03")
        @Expect(n.remoteEchoEnabled(), true)
        @Expect(n.remoteSuppressGoAhead(), true)
        @Expect(n.localOptionEnabled(TELOPT_ECHO), false)
        @Expect(n.localOptionEnabled(TELOPT_NAWS), true)
    }

    @TestCase
    func refusesWindowSizeWhenTurnedOff(): Unit {
        let n = TelnetNegotiator("vt100", 511, 4096, false)
        let r = feedAll(n, [IAC, DO, TELOPT_NAWS])
        @Expect(r[1], "fffc1f")
    }

    @TestCase
    func answersATerminalTypeSubnegotiation(): Unit {
        let n = defaultNegotiator()
        let first = feedAll(n, [IAC, DO, TELOPT_TTYPE])
        @Expect(first[1], "fffb18")
        let second = feedAll(n, [IAC, SB, TELOPT_TTYPE, TELQUAL_SEND, IAC, SE])
        @Expect(second[1], "fffa18007674313030fff0")
        @Expect(second[0], "")
    }

    @TestCase
    func doesNotLoopOnARepeatedOffer(): Unit {
        let n = defaultNegotiator()
        @Expect(feedAll(n, [IAC, WILL, TELOPT_SGA])[1], "fffd03")
        @Expect(feedAll(n, [IAC, WILL, TELOPT_SGA])[1], "")
        @Expect(feedAll(n, [IAC, WONT, TELOPT_SGA])[1], "fffe03")
        @Expect(feedAll(n, [IAC, WONT, TELOPT_SGA])[1], "")
    }

    @TestCase
    func handlesCommandsSplitAcrossReads(): Unit {
        let n = defaultNegotiator()
        @Expect(feedAll(n, [UInt8(88), IAC])[1], "")
        @Expect(feedAll(n, [WILL])[1], "")
        let third = feedAll(n, [TELOPT_ECHO, UInt8(89)])
        @Expect(third[1], "fffd01")
        @Expect(third[0], "Y")
    }

    @TestCase
    func unescapesADoubledIacIntoData(): Unit {
        let n = defaultNegotiator()
        let r = n.feed([UInt8(65), IAC, IAC, UInt8(66)], 4)
        @Expect(hexOf(r[0]), "41ff42")
    }

    @TestCase
    func dropsTheNulThatFollowsABareCr(): Unit {
        let n = defaultNegotiator()
        let r = n.feed([UInt8(65), UInt8(13), UInt8(0), UInt8(66)], 4)
        @Expect(hexOf(r[0]), "410d42")
    }

    @TestCase
    func dropsACrNulSplitAcrossReads(): Unit {
        let n = defaultNegotiator()
        @Expect(hexOf(n.feed([UInt8(65), UInt8(13)], 2)[0]), "410d")
        @Expect(hexOf(n.feed([UInt8(0), UInt8(66)], 2)[0]), "42")
    }

    @TestCase
    func keepsANulThatDoesNotFollowACr(): Unit {
        let n = defaultNegotiator()
        let r = n.feed([UInt8(65), UInt8(0), UInt8(66)], 3)
        @Expect(hexOf(r[0]), "410042")
    }

    @TestCase
    func keepsCrLfIntact(): Unit {
        let n = defaultNegotiator()
        let r = n.feed([UInt8(13), UInt8(10), UInt8(65)], 3)
        @Expect(hexOf(r[0]), "0d0a41")
    }

    @TestCase
    func ignoresStandaloneCommands(): Unit {
        let n = defaultNegotiator()
        let r = feedAll(n, [UInt8(65), IAC, UInt8(241), UInt8(66)])
        @Expect(r[0], "AB")
        @Expect(r[1], "")
    }

    @TestCase
    func namesTheCommonOptions(): Unit {
        @Expect(telnetOptionName(TELOPT_ECHO), "ECHO")
        @Expect(telnetOptionName(TELOPT_SGA), "SUPPRESS-GO-AHEAD")
        @Expect(telnetOptionName(TELOPT_NAWS), "NAWS")
        @Expect(telnetOptionName(UInt8(200)), "OPTION-200")
    }
}

@Test
class TelnetPromptTests {
    @TestCase
    func recognisesUsernamePrompts(): Unit {
        @Expect(looksLikeUsernamePrompt("\r\nUser Access Verification\r\n\r\nUsername: "), true)
        @Expect(looksLikeUsernamePrompt("router login: "), true)
        @Expect(looksLikeUsernamePrompt("Password: "), false)
        @Expect(looksLikeUsernamePrompt("Router> "), false)
        @Expect(looksLikeUsernamePrompt(""), false)
    }

    @TestCase
    func recognisesLoginFailures(): Unit {
        @Expect(looksLikeLoginFailure("% Login invalid\r\n\r\nUsername: "), true)
        @Expect(looksLikeLoginFailure("Login incorrect\r\nlogin: "), true)
        @Expect(looksLikeLoginFailure("% Bad passwords\r\n"), true)
        @Expect(looksLikeLoginFailure("Router> "), false)
    }
}

@Test
class TelnetValidationTests {
    @TestCase
    func defaultsAreSane(): Unit {
        let o = TelnetOptions()
        @Expect(o.port, 23)
        @Expect(o.negotiateWindowSize, true)
        @Expect(o.terminalType, "vt100")
        @Expect(o.commandTimeoutMs > 0, true)
        @Expect(o.loginTimeoutMs > 0, true)
    }

    @TestCase
    func rejectsEmptyHost(): Unit {
        try {
            TelnetConnection.connect(TelnetOptions("", 23, "a", "b"))
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("host"), true)
        }
    }

    @TestCase
    func rejectsZeroPort(): Unit {
        try {
            TelnetConnection.connect(TelnetOptions("127.0.0.1", 0, "a", "b"))
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("port"), true)
        }
    }

    @TestCase
    func rejectsNegativeRetries(): Unit {
        let o = TelnetOptions("127.0.0.1", 23, "a", "b")
        o.maxRetries = -1
        try {
            TelnetConnection.connect(o)
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("maxRetries"), true)
        }
    }

    @TestCase
    func surfacesRefusedConnections(): Unit {
        let o = TelnetOptions("127.0.0.1", 1, "a", "b")
        o.connectTimeoutMs = 3000
        try {
            TelnetConnection.connect(o)
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.errnoValue, 111)
        }
    }
}

func telnetLoginAvailable(): Bool {
    return envSet("GLYPHNET_TEST_TELNET_HOST") && envSet("GLYPHNET_TEST_TELNET_PORT")
}

func telnetLoginOptions(): TelnetOptions {
    let o = TelnetOptions(envOr("GLYPHNET_TEST_TELNET_HOST", "127.0.0.1"),
                          UInt16.parse(envOr("GLYPHNET_TEST_TELNET_PORT", "23")),
                          envOr("GLYPHNET_TEST_TELNET_USER", ""),
                          envOr("GLYPHNET_TEST_TELNET_PASSWORD", ""))
    o.deviceType = DeviceType.CiscoIOS
    return o
}

@Test
class LiveTelnetTests {
    @TestCase
    func logsInAndFindsThePrompt(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        try (conn = TelnetConnection.connect(telnetLoginOptions())) {
            @Expect(conn.prompt.isEmpty(), false)
            @Expect(conn.prompt.endsWith(">"), true)
            @Expect(conn.isAlive(), true)

            for (b in conn.prompt.toArray()) {
                @Expect(b >= UInt8(32), true)
            }
        }
    }

    @TestCase
    func negotiatesCharacterAtATimeWithRemoteEcho(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        try (conn = TelnetConnection.connect(telnetLoginOptions())) {
            @Expect(conn.remoteEcho, true)
            @Expect(conn.characterAtATime, true)
        }
    }

    @TestCase
    func runsCommandsAndStripsTheEcho(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        try (conn = TelnetConnection.connect(telnetLoginOptions())) {
            let out = conn.sendCommand("show version")
            @Expect(out.contains("Cisco IOS Software"), true)
            @Expect(out.startsWith("show version"), false)
            @Expect(out.contains(conn.prompt), false)

            let multi = conn.sendCommands(["show version", "show version"])
            @Expect(multi.size, 2)
            @Expect(multi[1].contains("Cisco IOS Software"), true)
        }
    }

    @TestCase
    func autodetectsTheDeviceType(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        let o = telnetLoginOptions()
        o.deviceType = DeviceType.Generic
        o.autoDetectDeviceType = true
        try (conn = TelnetConnection.connect(o)) {
            @Expect(conn.deviceType, DeviceType.CiscoIOS)
            @Expect(conn.pagingCommand, "terminal length 0")
        }
    }

    @TestCase
    func drivesEnableAndConfigMode(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        try (conn = TelnetConnection.connect(telnetLoginOptions())) {
            @Expect(conn.isEnableMode(), false)
            conn.enable()
            @Expect(conn.isEnableMode(), true)
            @Expect(conn.prompt.endsWith("#"), true)

            conn.configMode()
            @Expect(conn.isConfigMode(), true)
            @Expect(conn.prompt.contains("(config"), true)

            conn.exitConfigMode()
            @Expect(conn.isConfigMode(), false)
            @Expect(conn.isEnableMode(), true)
        }
    }

    @TestCase
    func rejectsAWrongPassword(): Unit {
        if (!telnetLoginAvailable() || !envSet("GLYPHNET_TEST_TELNET_PASSWORD")) {
            return
        }
        let o = telnetLoginOptions()
        o.password = "definitely-not-the-password-7b2e"
        o.loginTimeoutMs = 8000
        try {
            TelnetConnection.connect(o)
            @Fail("expected AuthenticationException for a wrong telnet password")
        } catch (e: AuthenticationException) {
            @Expect(e.message.isEmpty(), false)
        }
    }

    @TestCase
    func disconnectIsIdempotent(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        let conn = TelnetConnection.connect(telnetLoginOptions())
        conn.disconnect()
        conn.disconnect()
        @Expect(conn.isClosed(), true)
        @Expect(conn.isAlive(), false)
        try {
            conn.sendCommand("show version")
            @Fail("expected CommandException on a closed telnet connection")
        } catch (e: CommandException) {
            @Expect(e.message.contains("closed"), true)
        }
    }

    @TestCase
    func reconnectRebuildsTheSession(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        let conn = TelnetConnection.connect(telnetLoginOptions())
        try {
            let first = conn.prompt
            conn.reconnect()
            @Expect(conn.isClosed(), false)
            @Expect(conn.prompt, first)
            @Expect(conn.sendCommand("show version").contains("Cisco IOS Software"), true)
        } finally {
            conn.close()
        }
    }

    @TestCase
    func aTelnetConnectionIsUsableThroughTheSharedInterface(): Unit {
        if (!telnetLoginAvailable()) {
            return
        }
        try (conn = TelnetConnection.connect(telnetLoginOptions())) {
            let generic: NetworkConnection = conn
            @Expect(generic.findPrompt().isEmpty(), false)
            @Expect(generic.sendCommand("show version").contains("Cisco"), true)
            @Expect(generic.deviceType, DeviceType.CiscoIOS)
        }
    }
}

@Test
class LiveCiscoTelnetTests {
    @TestCase
    func negotiatesWithARealCiscoIosRouterOverTelnet(): Unit {
        if (!envSet("GLYPHNET_TEST_CISCO_TELNET_HOST")) {
            return
        }
        let o = TelnetOptions(envOr("GLYPHNET_TEST_CISCO_TELNET_HOST", ""),
                              UInt16.parse(envOr("GLYPHNET_TEST_CISCO_TELNET_PORT", "23")),
                              envOr("GLYPHNET_TEST_CISCO_TELNET_USER", "admin"),
                              envOr("GLYPHNET_TEST_CISCO_TELNET_PASSWORD", ""))
        o.commandTimeoutMs = 30000
        o.autoDetectDeviceType = true

        try (conn = TelnetConnection.connect(o)) {
            @Expect(conn.remoteEcho, true)
            @Expect(conn.characterAtATime, true)
            @Expect(conn.deviceType == DeviceType.CiscoIOS, true)
            @Expect(conn.pagingCommand, "terminal length 0")
            @Expect(conn.prompt.isEmpty(), false)
            @Expect(conn.sendCommand("show version").contains("Cisco IOS Software"), true)
        }
    }
}

@Test
class LiveOpenTelnetTests {
    @TestCase
    func connectsToATargetWithNoLoginPrompt(): Unit {
        if (!envSet("GLYPHNET_TEST_TELNET_OPEN_PORT")) {
            return
        }
        let o = TelnetOptions(envOr("GLYPHNET_TEST_TELNET_HOST", "127.0.0.1"),
                              UInt16.parse(envOr("GLYPHNET_TEST_TELNET_OPEN_PORT", "23")), "", "")
        try (conn = TelnetConnection.connect(o)) {
            @Expect(conn.prompt.isEmpty(), false)
            @Expect(conn.sendCommand("echo TELNET_OK").contains("TELNET_OK"), true)
            @Expect(conn.sendCommand("echo TELNET_OK").contains("echo TELNET_OK"), false)
        }
    }

    @TestCase
    func carriesEightBitDataThroughNegotiation(): Unit {
        if (!envSet("GLYPHNET_TEST_TELNET_OPEN_PORT")) {
            return
        }
        let o = TelnetOptions(envOr("GLYPHNET_TEST_TELNET_HOST", "127.0.0.1"),
                              UInt16.parse(envOr("GLYPHNET_TEST_TELNET_OPEN_PORT", "23")), "", "")
        try (conn = TelnetConnection.connect(o)) {
            let out = conn.sendCommand("printf 'a\\xff\\xffb\\n'")
            @Expect(out.contains("a"), true)
            @Expect(out.contains("b"), true)
        }
    }
}
