package glyphnet

import glyphnet.errors.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*
import std.convert.*

func liveSshOptions(): ConnectionOptions {
    return ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                             UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                             envOr("GLYPHNET_TEST_SSH_USER", "root"),
                             envOr("GLYPHNET_TEST_SSH_PASSWORD", ""))
}

func liveSshAvailable(): Bool {
    return envSet("GLYPHNET_TEST_SSH_HOST") && envSet("GLYPHNET_TEST_SSH_PASSWORD")
}

func writeTempFile(name: String, bytes: Array<UInt8>): String {
    let path = "/tmp/${name}"
    File.writeTo(path, bytes)
    return path
}

func removeQuietly(path: String): Unit {
    try {
        if (exists(Path(path))) {
            remove(Path(path))
        }
    } catch (_: Exception) {
    }
}

func patternBytes(size: Int64): Array<UInt8> {
    let out = Array<UInt8>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8((i * 31 + 7) % 251)
        i += 1
    }
    return out
}

func bytesEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) {
        return false
    }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) {
            return false
        }
        i += 1
    }
    return true
}

@Test
class ScpTransferValueTests {
    @TestCase
    func reportsThroughput(): Unit {
        let t = ScpTransfer("/tmp/a", "/tmp/b", 2048, 1000)
        @Expect(t.bytes, 2048)
        @Expect(t.bytesPerSecond > 2047.0, true)
        @Expect(t.bytesPerSecond < 2049.0, true)
        @Expect(t.toString().contains("2048 bytes"), true)
    }

    @TestCase
    func zeroElapsedDoesNotDivideByZero(): Unit {
        let t = ScpTransfer("/tmp/a", "/tmp/b", 100, 0)
        @Expect(t.bytesPerSecond, 0.0)
    }

    @TestCase
    func modesAreTheUsualOctalValues(): Unit {
        @Expect(SCP_MODE_FILE, 420)
        @Expect(SCP_MODE_EXECUTABLE, 493)
    }
}

@Test
class LiveScpTests {
    @TestCase
    func rejectsEmptyAndMissingPaths(): Unit {
        if (!liveSshAvailable()) {
            return
        }
        try (conn = SSHConnection.connect(liveSshOptions())) {
            try {
                conn.scpUpload("", "/tmp/x")
                @Fail("expected CommandException for an empty local path")
            } catch (e: CommandException) {
                @Expect(e.message.contains("local path"), true)
            }

            try {
                conn.scpUpload("/tmp/glyphnet-does-not-exist-4f2a", "/tmp/x")
                @Fail("expected CommandException for a missing local file")
            } catch (e: CommandException) {
                @Expect(e.message.contains("does not exist"), true)
            }

            try {
                conn.scpDownload("/tmp/x", "/tmp/y", 0)
                @Fail("expected CommandException for a non-positive timeout")
            } catch (e: CommandException) {
                @Expect(e.message.contains("timeout"), true)
            }

            try {
                conn.scpUpload("/tmp", "/tmp/x")
                @Fail("expected CommandException for a directory")
            } catch (e: CommandException) {
                @Expect(e.message.contains("directory"), true)
            }
        }
    }

    @TestCase
    func uploadThenDownloadRoundTripsTheBytes(): Unit {
        if (!liveSshAvailable()) {
            return
        }
        let payload = "GlyphNet SCP round trip\nline two\n".toArray()
        let source = writeTempFile("glyphnet_scp_src.txt", payload)
        let sink = "/tmp/glyphnet_scp_sink.txt"
        let remote = "/tmp/glyphnet_scp_remote.txt"
        removeQuietly(sink)

        try (conn = SSHConnection.connect(liveSshOptions())) {
            let up = conn.scpUpload(source, remote)
            @Expect(up.bytes, payload.size)

            let listing = conn.execChannel("wc -c < ${remote}")
            @Expect(listing.output.trimAscii(), payload.size.toString())

            let down = conn.scpDownload(remote, sink)
            @Expect(down.bytes, payload.size)
            @Expect(bytesEqual(File.readFrom(sink), payload), true)

            conn.execChannel("rm -f ${remote}")
        }
        removeQuietly(source)
        removeQuietly(sink)
    }

    @TestCase
    func movesAFileLargerThanOneChannelWindow(): Unit {
        if (!liveSshAvailable()) {
            return
        }
        let payload = patternBytes(3 * 1024 * 1024 + 17)
        let source = writeTempFile("glyphnet_scp_big.bin", payload)
        let sink = "/tmp/glyphnet_scp_big_back.bin"
        let remote = "/tmp/glyphnet_scp_big_remote.bin"
        removeQuietly(sink)

        try (conn = SSHConnection.connect(liveSshOptions())) {
            let up = conn.scpUpload(source, remote, 120000)
            @Expect(up.bytes, payload.size)

            let down = conn.scpDownload(remote, sink, 120000)
            @Expect(down.bytes, payload.size)
            @Expect(bytesEqual(File.readFrom(sink), payload), true)

            conn.execChannel("rm -f ${remote}")
        }
        removeQuietly(source)
        removeQuietly(sink)
    }

    @TestCase
    func downloadingAMissingRemoteFileThrows(): Unit {
        if (!liveSshAvailable()) {
            return
        }
        try (conn = SSHConnection.connect(liveSshOptions())) {
            try {
                conn.scpDownload("/tmp/glyphnet-absent-9c31.bin", "/tmp/glyphnet-absent-9c31.bin")
                @Fail("expected an SshException for a remote file that does not exist")
            } catch (e: SshException) {
                @Expect(e.message.contains("SCP download channel"), true)
            }
        }
        removeQuietly("/tmp/glyphnet-absent-9c31.bin")
    }

    @TestCase
    func uploadingAnEmptyFileWorks(): Unit {
        if (!liveSshAvailable()) {
            return
        }
        let source = writeTempFile("glyphnet_scp_empty.txt", Array<UInt8>())
        let sink = "/tmp/glyphnet_scp_empty_back.txt"
        let remote = "/tmp/glyphnet_scp_empty_remote.txt"
        removeQuietly(sink)

        try (conn = SSHConnection.connect(liveSshOptions())) {
            let up = conn.scpUpload(source, remote)
            @Expect(up.bytes, 0)
            let down = conn.scpDownload(remote, sink)
            @Expect(down.bytes, 0)
            @Expect(exists(Path(sink)), true)
            conn.execChannel("rm -f ${remote}")
        }
        removeQuietly(source)
        removeQuietly(sink)
    }

    @TestCase
    func theShellChannelStillWorksAfterATransfer(): Unit {
        if (!liveSshAvailable()) {
            return
        }
        let source = writeTempFile("glyphnet_scp_shell.txt", "marker\n".toArray())
        let remote = "/tmp/glyphnet_scp_shell_remote.txt"

        try (conn = SSHConnection.connect(liveSshOptions())) {
            conn.sendCommand("cd /var/log")
            conn.scpUpload(source, remote)
            @Expect(conn.sendCommand("pwd").contains("/var/log"), true)
            @Expect(conn.sendCommand("echo AFTER_SCP").contains("AFTER_SCP"), true)
            conn.execChannel("rm -f ${remote}")
        }
        removeQuietly(source)
    }
}
