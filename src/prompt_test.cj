package glyphnet

import std.unittest.*
import std.unittest.testmacro.*

@Test
class PromptTests {
    @TestCase
    func stripsCsiColourCodes(): Unit {
        let raw = "\u{1b}[01;32mnetadmin@host\u{1b}[00m:\u{1b}[01;34m~\u{1b}[00m$ "
        @Expect(stripAnsiEscapes(raw), "netadmin@host:~$ ")
    }

    @TestCase
    func stripsOscTitleSequence(): Unit {
        let raw = "\u{1b}]0;netadmin@host: ~\u{07}Router#"
        @Expect(stripAnsiEscapes(raw), "Router#")
    }

    @TestCase
    func stripsCursorMovesAndKeepsText(): Unit {
        let raw = "line one\u{1b}[K\nline two\u{1b}[2J"
        @Expect(stripAnsiEscapes(raw), "line one\nline two")
    }

    @TestCase
    func leavesPlainTextAlone(): Unit {
        let raw = "Cisco IOS Software, Version 15.2"
        @Expect(stripAnsiEscapes(raw), raw)
    }

    @TestCase
    func normalizesCrlfAndBareCr(): Unit {
        @Expect(normalizeLineEndings("a\r\nb\rc\nd"), "a\nb\nc\nd")
    }

    @TestCase
    func lastNonEmptyLineSkipsTrailingBlanks(): Unit {
        @Expect(lastNonEmptyLine("output\nRouter#\n\n   \n"), "Router#")
    }

    @TestCase
    func lastNonEmptyLineOfEmptyIsEmpty(): Unit {
        @Expect(lastNonEmptyLine("\n\n   \n"), "")
    }

    @TestCase
    func promptStemDropsTerminator(): Unit {
        @Expect(promptStem("Router#"), "Router")
        @Expect(promptStem("Router>"), "Router")
        @Expect(promptStem("Router(config)#"), "Router(config)")
        @Expect(promptStem("netadmin@host:~$ "), "netadmin@host:~")
    }

    @TestCase
    func promptBaseDropsModeSuffix(): Unit {
        @Expect(promptBase("Router(config)"), "Router")
        @Expect(promptBase("Router(config-if)"), "Router")
        @Expect(promptBase("Router"), "Router")
    }

    @TestCase
    func recognisesPromptAcrossModeChanges(): Unit {
        let stem = promptStem("Router>")
        @Expect(looksLikePrompt("Router>", stem), true)
        @Expect(looksLikePrompt("Router#", stem), true)
        @Expect(looksLikePrompt("Router(config)#", stem), true)
        @Expect(looksLikePrompt("Router(config-if)#", stem), true)
    }

    @TestCase
    func rejectsNonPromptLines(): Unit {
        let stem = promptStem("Router#")
        @Expect(looksLikePrompt("Building configuration...", stem), false)
        @Expect(looksLikePrompt("", stem), false)
        @Expect(looksLikePrompt("   ", stem), false)

        @Expect(looksLikePrompt("Switch#", stem), false)
    }

    @TestCase
    func endsWithPromptOnlyAtTheEnd(): Unit {
        let stem = promptStem("Router#")
        @Expect(endsWithPrompt("show version\nIOS 15.2\nRouter#", stem), true)
        @Expect(endsWithPrompt("show version\nIOS 15.2\nRouter#\r\n", stem), true)

        @Expect(endsWithPrompt("Router#\nstill sending output", stem), false)
        @Expect(endsWithPrompt("", stem), false)
    }

    @TestCase
    func extractsOutputBetweenEchoAndPrompt(): Unit {
        let raw = "show version\r\nCisco IOS Software\r\nVersion 15.2\r\nRouter#"
        let stem = promptStem("Router#")
        @Expect(extractCommandOutput(raw, "show version", stem),
                "Cisco IOS Software\nVersion 15.2")
    }

    @TestCase
    func extractsOutputWhenEchoTrailsThePrompt(): Unit {
        let raw = "Router#show version\r\nVersion 15.2\r\nRouter#"
        let stem = promptStem("Router#")
        @Expect(extractCommandOutput(raw, "show version", stem), "Version 15.2")
    }

    @TestCase
    func dropsPtyBlankLineAfterEcho(): Unit {
        let raw = "echo hi\r\n\r\nhi\r\nhost:~$ "
        let stem = promptStem("host:~$")
        @Expect(extractCommandOutput(raw, "echo hi", stem), "hi")
    }

    @TestCase
    func preservesBlankLinesInsideOutput(): Unit {
        let raw = "show run\r\n\r\nline one\r\n\r\nline two\r\nRouter#"
        let stem = promptStem("Router#")
        @Expect(extractCommandOutput(raw, "show run", stem), "line one\n\nline two")
    }

    @TestCase
    func extractsEmptyOutputForSilentCommand(): Unit {
        let raw = "terminal length 0\r\nRouter#"
        let stem = promptStem("Router#")
        @Expect(extractCommandOutput(raw, "terminal length 0", stem), "")
    }

    @TestCase
    func extractStripsAnsiFromOutput(): Unit {
        let raw = "ls\r\n\u{1b}[01;34mdocs\u{1b}[0m\r\nnetadmin@host:~$ "
        let stem = promptStem("netadmin@host:~$")
        @Expect(extractCommandOutput(raw, "ls", stem), "docs")
    }

    @TestCase
    func hexEncodesFingerprintBytes(): Unit {
        @Expect(hexOf([UInt8(0), UInt8(15), UInt8(16), UInt8(255)]), "000f10ff")
        @Expect(hexOf(Array<UInt8>()), "")
    }
}
