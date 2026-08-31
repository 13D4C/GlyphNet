package glyphnet

import glyphnet.errors.*
import std.unittest.*
import std.unittest.testmacro.*
import std.convert.*

let CISCO_C7200_SHOW_VERSION: String = """
Cisco IOS Software, 7200 Software (C7200-ADVENTERPRISEK9-M), Version 12.4(24)T5, RELEASE SOFTWARE (fc3)
Technical Support: http:\u{2f}/www.cisco.com/techsupport
Copyright (c) 1986-2011 by Cisco Systems, Inc.
Compiled Fri 04-Mar-11 06:49 by prod_rel_team

ROM: ROMMON Emulation Microcode
BOOTLDR: 7200 Software (C7200-ADVENTERPRISEK9-M), Version 12.4(24)T5, RELEASE SOFTWARE (fc3)

Khaow-InwZa007x2-R1 uptime is 4 minutes
System returned to ROM by unknown reload cause - suspect boot_data[BOOT_COUNT] 0x0, BOOT_COUNT 0, BOOTDATA 19
System image file is "tftp:\u{2f}/255.255.255.255/unknown"

Cisco 7206VXR (NPE400) processor (revision A) with 491520K/32768K bytes of memory.
Processor board ID 4279256517
R7000 CPU at 150MHz, Implementation 39, Rev 2.1, 256KB L2 Cache
6 slot VXR midplane, Version 2.1

1 FastEthernet interface
509K bytes of NVRAM.

8192K bytes of Flash internal SIMM (Sector size 256K).
Configuration register is 0x2102
"""

let CISCO_C7200_SHOW_IP_INT_BRIEF: String = """
Interface                  IP-Address      OK? Method Status                Protocol
FastEthernet0/0            10.30.32.43     YES DHCP   up                    up
"""

@Test
class TextFsmEngineTests {
    @TestCase
    func substitutesValueRegexIntoRules(): Unit {
        let template = #"Value INTERFACE (\S+)
Value STATUS (\S+)

Start
  ^${INTERFACE}\s+is\s+${STATUS} -> Record
"#
        let rows = parseTextFsm(template, "Gi0/1 is up\nGi0/2 is down\n")
        @Expect(rows.size, 2)
        @Expect(rows[0].get("INTERFACE"), "Gi0/1")
        @Expect(rows[0].get("STATUS"), "up")
        @Expect(rows[1].get("INTERFACE"), "Gi0/2")
        @Expect(rows[1].get("STATUS"), "down")
    }

    @TestCase
    func dollarDollarIsAnEndOfLineAnchor(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$ -> Record
"#
        @Expect(parseTextFsm(template, "abc\n").size, 1)
        @Expect(parseTextFsm(template, "abc def\n").size, 0)
    }

    @TestCase
    func rulesAreAnchoredAtTheStartOfTheLine(): Unit {
        let template = #"Value A (\d+)

Start
  ^id ${A}$$ -> Record
"#
        @Expect(parseTextFsm(template, "id 42\n").size, 1)
        @Expect(parseTextFsm(template, "the id 42\n").size, 0)
    }

    @TestCase
    func requiredDropsRowsWithoutTheValue(): Unit {
        let template = #"Value Required NAME (\S+)
Value AGE (\d+)

Start
  ^name ${NAME}$$
  ^age ${AGE}$$
  ^--$$ -> Record
"#
        let rows = parseTextFsm(template, "name bob\nage 32\n--\nage 44\n--\nname amy\n--\n")
        @Expect(rows.size, 2)
        @Expect(rows[0].get("NAME"), "bob")
        @Expect(rows[0].get("AGE"), "32")
        @Expect(rows[1].get("NAME"), "amy")
        @Expect(rows[1].get("AGE"), "")
    }

    @TestCase
    func listAccumulatesRepeatedMatches(): Unit {
        let template = #"Value Required DEVICE (\S+)
Value List NEIGHBORS (\S+)

Start
  ^device ${DEVICE}$$ -> Record
  ^\s+${NEIGHBORS}$$
"#
        let rows = parseTextFsm(template, "  r1\n  r2\n  r3\ndevice sw1\n")
        @Expect(rows.size, 1)
        @Expect(rows[0].isListValue("NEIGHBORS"), true)
        @Expect(rows[0].isListValue("DEVICE"), false)
        let neighbors = rows[0].getList("NEIGHBORS")
        @Expect(neighbors.size, 3)
        @Expect(neighbors[0], "r1")
        @Expect(neighbors[1], "r2")
        @Expect(neighbors[2], "r3")
        @Expect(rows[0].get("DEVICE"), "sw1")
    }

    @TestCase
    func listIsClearedBetweenRecords(): Unit {
        let template = #"Value Required DEVICE (\S+)
Value List PORTS (\S+)

Start
  ^device ${DEVICE}$$ -> Record
  ^\s+${PORTS}$$
"#
        let rows = parseTextFsm(template, "  a\ndevice one\n  b\n  c\ndevice two\n")
        @Expect(rows.size, 2)
        @Expect(rows[0].getList("PORTS").size, 1)
        @Expect(rows[1].getList("PORTS").size, 2)
        @Expect(rows[1].getList("PORTS")[1], "c")
    }

    @TestCase
    func filldownCarriesValuesAcrossRecords(): Unit {
        let template = #"Value Filldown VLAN (\d+)
Value Required MAC (\S+)

Start
  ^VLAN ${VLAN}$$
  ^\s+${MAC}$$ -> Record
"#
        let rows = parseTextFsm(template,
                                "VLAN 10\n  aaaa.1111.0001\n  aaaa.1111.0002\nVLAN 20\n  bbbb.2222.0001\n")
        @Expect(rows.size, 3)
        @Expect(rows[0].get("VLAN"), "10")
        @Expect(rows[1].get("VLAN"), "10")
        @Expect(rows[1].get("MAC"), "aaaa.1111.0002")
        @Expect(rows[2].get("VLAN"), "20")
    }

    @TestCase
    func fillupBackfillsEarlierRows(): Unit {
        let template = #"Value Fillup OWNER (\S+)
Value B (\S+)

Start
  ^b ${B}$$ -> Record
  ^owner ${OWNER}$$
"#
        let rows = parseTextFsm(template, "b one\nb two\nowner alice\n")
        @Expect(rows.size, 3)
        @Expect(rows[0].get("OWNER"), "alice")
        @Expect(rows[1].get("OWNER"), "alice")
        @Expect(rows[2].get("OWNER"), "alice")
        @Expect(rows[2].get("B"), "")
    }

    @TestCase
    func continueTriesMoreRulesOnTheSameLine(): Unit {
        let template = #"Value NAME (\S+)
Value FLAG (\S+)

Start
  ^${NAME}\s -> Continue
  ^\S+\s+${FLAG}$$ -> Record
"#
        let rows = parseTextFsm(template, "alpha yes\nbeta no\n")
        @Expect(rows.size, 2)
        @Expect(rows[0].get("NAME"), "alpha")
        @Expect(rows[0].get("FLAG"), "yes")
        @Expect(rows[1].get("NAME"), "beta")
        @Expect(rows[1].get("FLAG"), "no")
    }

    @TestCase
    func stateTransitionSwitchesTheRuleSet(): Unit {
        let template = #"Value NAME (\S+)

Start
  ^Interfaces: -> Ifaces

Ifaces
  ^\s+${NAME}$$ -> Record
  ^End$$ -> Start
"#
        let rows = parseTextFsm(template, "  ignored\nInterfaces:\n  Gi0/1\n  Gi0/2\nEnd\n  ignored\n")
        @Expect(rows.size, 2)
        @Expect(rows[0].get("NAME"), "Gi0/1")
        @Expect(rows[1].get("NAME"), "Gi0/2")
    }

    @TestCase
    func recordAndStateChangeCombine(): Unit {
        let template = #"Value A (\S+)

Start
  ^a ${A}$$ -> Next.Record Second

Second
  ^b ${A}$$ -> Record Start
"#
        let rows = parseTextFsm(template, "a one\nb two\na three\n")
        @Expect(rows.size, 3)
        @Expect(rows[0].get("A"), "one")
        @Expect(rows[1].get("A"), "two")
        @Expect(rows[2].get("A"), "three")
    }

    @TestCase
    func endStateStopsParsing(): Unit {
        let template = #"Value A (\S+)

Start
  ^STOP$$ -> End
  ^${A}$$ -> Record
"#
        let rows = parseTextFsm(template, "one\nSTOP\ntwo\n")
        @Expect(rows.size, 1)
        @Expect(rows[0].get("A"), "one")
    }

    @TestCase
    func implicitFinalRecordAtEndOfInput(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$
"#
        let rows = parseTextFsm(template, "one\ntwo\n")
        @Expect(rows.size, 1)
        @Expect(rows[0].get("A"), "two")
    }

    @TestCase
    func emptyEofStateSuppressesTheFinalRecord(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$

EOF
"#
        @Expect(parseTextFsm(template, "one\ntwo\n").size, 0)
    }

    @TestCase
    func emptyRecordsAreNeverEmitted(): Unit {
        let template = #"Value A (\S+)

Start
  ^match ${A}$$ -> Record
  ^.*$$ -> Record
"#
        let rows = parseTextFsm(template, "nothing here\nstill nothing\n")
        @Expect(rows.size, 0)
    }

    @TestCase
    func clearallResetsFilldownMemory(): Unit {
        let template = #"Value Filldown A (\S+)
Value B (\S+)

Start
  ^a ${A}$$
  ^b ${B}$$ -> Record
  ^RESET$$ -> Clearall
"#
        let rows = parseTextFsm(template, "a 1\nb x\nb y\nRESET\nb z\n")
        @Expect(rows.size, 3)
        @Expect(rows[0].get("A"), "1")
        @Expect(rows[1].get("A"), "1")
        @Expect(rows[2].get("A"), "")
        @Expect(rows[2].get("B"), "z")
    }

    @TestCase
    func clearDropsTheRecordInProgress(): Unit {
        let template = #"Value A (\S+)
Value B (\S+)

Start
  ^a ${A}$$
  ^DROP$$ -> Clear
  ^b ${B}$$ -> Record
"#
        let rows = parseTextFsm(template, "a 1\nDROP\nb x\n")
        @Expect(rows.size, 1)
        @Expect(rows[0].get("A"), "")
        @Expect(rows[0].get("B"), "x")
    }

    @TestCase
    func errorActionRaises(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$ -> Record
  ^. -> Error "unexpected line"
"#
        try {
            parseTextFsm(template, "ok\n!!! bad line\n")
            @Fail("expected ParseException from the Error action")
        } catch (e: ParseException) {
            @Expect(e.message.contains("unexpected line"), true)
        }
    }

    @TestCase
    func commentsAndBlankLinesAreIgnored(): Unit {
        let template = #"# leading comment
Value A (\S+)
# between values
Value B (\S+)

# before the state
Start
  # a comment inside the state
  ^${A}\s+${B}$$ -> Record
"#
        let rows = parseTextFsm(template, "x y\n")
        @Expect(rows.size, 1)
        @Expect(rows[0].get("A"), "x")
        @Expect(rows[0].get("B"), "y")
    }

    @TestCase
    func rulesWithoutAnExplicitStateBecomeStart(): Unit {
        let template = #"Value A (\S+)

  ^${A}$$ -> Record
"#
        let rows = parseTextFsm(template, "one\n")
        @Expect(rows.size, 1)
        @Expect(rows[0].get("A"), "one")
    }

    @TestCase
    func exposesValueMetadata(): Unit {
        let template = #"Value Required,List HARDWARE (\S+)
Value Filldown HOSTNAME (\S+)

Start
  ^${HOSTNAME}\s+${HARDWARE}$$ -> Record
"#
        let compiled = TextFsmTemplate.compile(template)
        @Expect(compiled.valueNames.size, 2)
        @Expect(compiled.valueNames[0], "HARDWARE")
        @Expect(compiled.stateNames.size, 1)
        @Expect(compiled.stateNames[0], "Start")
        let hardware = compiled.valueDefinitions[0]
        @Expect(hardware.required, true)
        @Expect(hardware.isList, true)
        @Expect(hardware.template, "(?<HARDWARE>\\S+)")
        @Expect(compiled.valueDefinitions[1].filldown, true)
    }

    @TestCase
    func aCompiledTemplateIsReusable(): Unit {
        let compiled = TextFsmTemplate.compile(TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF)
        let first = compiled.parse(CISCO_C7200_SHOW_IP_INT_BRIEF)
        let second = compiled.parse(CISCO_C7200_SHOW_IP_INT_BRIEF)
        @Expect(first.size, 1)
        @Expect(second.size, 1)
        @Expect(second[0].get("INTERFACE"), "FastEthernet0/0")
    }

    @TestCase
    func emptyInputProducesNoRows(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$ -> Record
"#
        @Expect(parseTextFsm(template, "").size, 0)
    }
}

@Test
class TextFsmTemplateErrorTests {
    @TestCase
    func rejectsAnUnknownValueReference(): Unit {
        let template = #"Value A (\S+)

Start
  ^${MISSING}$$ -> Record
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for an unknown value reference")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("MISSING"), true)
        }
    }

    @TestCase
    func rejectsAnUnknownOption(): Unit {
        let template = #"Value Bogus A (\S+)

Start
  ^${A}$$ -> Record
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for an unknown option")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("Bogus"), true)
        }
    }

    @TestCase
    func rejectsAValueRegexWithoutParentheses(): Unit {
        let template = #"Value Required A \S+

Start
  ^${A}$$ -> Record
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for an unparenthesised value regex")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("()"), true)
        }
    }

    @TestCase
    func rejectsAMissingStartState(): Unit {
        let template = #"Value A (\S+)

Other
  ^${A}$$ -> Record
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for a missing Start state")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("Start"), true)
        }
    }

    @TestCase
    func rejectsContinueWithANewState(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$ -> Continue Other

Other
  ^x$$
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for Continue with a new state")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("Continue"), true)
        }
    }

    @TestCase
    func rejectsAJumpToAnUndefinedState(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$ -> Nowhere
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for an undefined target state")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("Nowhere"), true)
        }
    }

    @TestCase
    func rejectsANonEmptyEofState(): Unit {
        let template = #"Value A (\S+)

Start
  ^${A}$$

EOF
  ^.*$$ -> Record
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for a non-empty EOF state")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("EOF"), true)
        }
    }

    @TestCase
    func rejectsATemplateWithNoValues(): Unit {
        let template = #"Start
  ^abc$$ -> Record
"#
        try {
            parseTextFsm(template, "abc")
            @Fail("expected TemplateException for a template with no values")
        } catch (e: TemplateException) {
            @Expect(e.message.contains("Value"), true)
        }
    }

    @TestCase
    func rejectsAnInvalidRegex(): Unit {
        let template = #"Value A ((\S+)

Start
  ^${A}$$ -> Record
"#
        try {
            parseTextFsm(template, "x")
            @Fail("expected TemplateException for an invalid regex")
        } catch (e: TemplateException) {
            @Expect(e.message.isEmpty(), false)
        }
    }
}

@Test
class CiscoIosTemplateTests {
    @TestCase
    func parsesRealShowVersionFromAC7200(): Unit {
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_VERSION, CISCO_C7200_SHOW_VERSION)
        @Expect(rows.size, 1)
        let row = rows[0]
        @Expect(row.get("HOSTNAME"), "Khaow-InwZa007x2-R1")
        @Expect(row.get("VERSION"), "12.4(24)T5")
        @Expect(row.get("SOFTWARE_IMAGE"), "C7200-ADVENTERPRISEK9-M")
        @Expect(row.get("RELEASE"), "fc3")
        @Expect(row.get("ROMMON"), "ROMMON Emulation Microcode")
        @Expect(row.get("UPTIME"), "4 minutes")
        @Expect(row.get("RUNNING_IMAGE"), "tftp:\u{2f}/255.255.255.255/unknown")
        @Expect(row.get("SERIAL"), "4279256517")
        @Expect(row.get("CONFIG_REGISTER"), "0x2102")
        let hardware = row.getList("HARDWARE")
        @Expect(hardware.size, 1)
        @Expect(hardware[0], "7206VXR")
    }

    @TestCase
    func showVersionSurvivesCrlfAndATrailingPrompt(): Unit {
        let noisy = CISCO_C7200_SHOW_VERSION.replace("\n", "\r\n")
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_VERSION, noisy)
        @Expect(rows.size, 1)
        @Expect(rows[0].get("HOSTNAME"), "Khaow-InwZa007x2-R1")
        @Expect(rows[0].get("VERSION"), "12.4(24)T5")
    }

    @TestCase
    func parsesRealShowIpInterfaceBriefFromAC7200(): Unit {
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF,
                                CISCO_C7200_SHOW_IP_INT_BRIEF)
        @Expect(rows.size, 1)
        let row = rows[0]
        @Expect(row.get("INTERFACE"), "FastEthernet0/0")
        @Expect(row.get("IP_ADDRESS"), "10.30.32.43")
        @Expect(row.get("OK"), "YES")
        @Expect(row.get("METHOD"), "DHCP")
        @Expect(row.get("STATUS"), "up")
        @Expect(row.get("PROTO"), "up")
    }

    @TestCase
    func showIpInterfaceBriefEmitsOneRowPerInterfaceLine(): Unit {
        let extra = CISCO_C7200_SHOW_IP_INT_BRIEF +
            "FastEthernet0/1            unassigned      YES unset  administratively down down\n"
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF, extra)
        @Expect(rows.size, 2)
        @Expect(rows[1].get("INTERFACE"), "FastEthernet0/1")
        @Expect(rows[1].get("IP_ADDRESS"), "unassigned")
        @Expect(rows[1].get("STATUS"), "administratively down")
        @Expect(rows[1].get("PROTO"), "down")
    }

    @TestCase
    func showIpInterfaceBriefListVariantAccumulatesOneRow(): Unit {
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF_LIST,
                                CISCO_C7200_SHOW_IP_INT_BRIEF)
        @Expect(rows.size, 1)
        @Expect(rows[0].isListValue("INTERFACE"), true)
        @Expect(rows[0].getList("INTERFACE").size, 1)
        @Expect(rows[0].getList("INTERFACE")[0], "FastEthernet0/0")
        @Expect(rows[0].getList("IP_ADDRESS")[0], "10.30.32.43")
        @Expect(rows[0].getList("STATUS")[0], "up")
        @Expect(rows[0].getList("PROTO")[0], "up")
    }

    @TestCase
    func showVersionRequiresAHostnameAndVersion(): Unit {
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_VERSION,
                                "% Invalid input detected at '^' marker.\n")
        @Expect(rows.size, 0)
    }

    @TestCase
    func rowToStringShowsScalarsAndLists(): Unit {
        let rows = parseTextFsm(TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF,
                                CISCO_C7200_SHOW_IP_INT_BRIEF)
        let text = rows[0].toString()
        @Expect(text.contains("INTERFACE='FastEthernet0/0'"), true)
        @Expect(rows[0].names.size, 6)
    }
}

@Test
class LiveCiscoTextFsmTests {
    @TestCase
    func parsesLiveShowVersionAndInterfacesFromARealRouter(): Unit {
        if (!envSet("GLYPHNET_TEST_CISCO_HOST")) {
            return
        }
        let o = ConnectionOptions(envOr("GLYPHNET_TEST_CISCO_HOST", ""),
                                  UInt16.parse(envOr("GLYPHNET_TEST_CISCO_PORT", "22")),
                                  envOr("GLYPHNET_TEST_CISCO_USER", "admin"),
                                  envOr("GLYPHNET_TEST_CISCO_PASSWORD", ""))
        o.commandTimeoutMs = 30000
        o.deviceType = DeviceType.CiscoIOS

        try (conn = SSHConnection.connect(o)) {
            let version = conn.sendCommandParsed("show version",
                                                 TEMPLATE_CISCO_IOS_SHOW_VERSION)
            @Expect(version.size, 1)
            @Expect(version[0].get("HOSTNAME").isEmpty(), false)
            @Expect(version[0].get("VERSION").isEmpty(), false)
            @Expect(version[0].get("UPTIME").isEmpty(), false)
            @Expect(version[0].getList("HARDWARE").size >= 1, true)

            let interfaces = conn.sendCommandParsed("show ip interface brief",
                                                    TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF)
            @Expect(interfaces.size >= 1, true)
            @Expect(interfaces[0].get("INTERFACE").isEmpty(), false)
            @Expect(interfaces[0].get("PROTO").isEmpty(), false)
        }
    }
}
