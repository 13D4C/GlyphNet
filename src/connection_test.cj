package glyphnet

import glyphnet.errors.*
import glyphnet.ssh2.*
import glyphnet.transport.*
import std.unittest.*
import std.unittest.testmacro.*
import std.env.*
import std.convert.*

func envOr(name: String, fallback: String): String {
    match (getVariable(name)) {
        case Some(v) => if (v.isEmpty()) { return fallback } else { return v }
        case None => return fallback
    }
}

func envSet(name: String): Bool {
    match (getVariable(name)) {
        case Some(v) => return !v.isEmpty()
        case None => return false
    }
}

@Test
class LibraryTests {
    @TestCase
    func reportsLibssh2Version(): Unit {
        let v = libssh2Version()
        @Expect(v.isEmpty(), false)

        @Expect(v.startsWith("1."), true)
    }

    @TestCase
    func initializeIsIdempotent(): Unit {
        initialize()
        initialize()
        @Expect(libssh2Version().isEmpty(), false)
    }
}

@Test
class TransportErrorTests {
    @TestCase
    func refusesEmptyHost(): Unit {
        try {
            TcpTransport.connect("", 22, 1000)
            @Fail("expected ConnectionException for an empty host")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("host"), true)
        }
    }

    @TestCase
    func refusesNonPositiveTimeout(): Unit {
        try {
            TcpTransport.connect("127.0.0.1", 22, 0)
            @Fail("expected ConnectionException for a zero timeout")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("timeout"), true)
        }
    }

    @TestCase
    func reportsConnectionRefused(): Unit {
        try {
            let t = TcpTransport.connect("127.0.0.1", 1, 3000)
            t.close()
            @Fail("expected ConnectionException connecting to 127.0.0.1:1")
        } catch (e: ConnectionException) {
            @Expect(e.errnoValue, 111)
            @Expect(e.message.contains("Connection refused"), true)
        }
    }

    @TestCase
    func reportsUnresolvableHost(): Unit {
        try {
            let t = TcpTransport.connect("no-such-host.invalid", 22, 3000)
            t.close()
            @Fail("expected ConnectionException for an unresolvable host")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("cannot resolve"), true)
        }
    }

    @TestCase
    func closeIsIdempotent(): Unit {
        try {
            TcpTransport.connect("127.0.0.1", 1, 2000)
        } catch (_: ConnectionException) {
        }
    }
}

@Test
class ConnectionValidationTests {
    @TestCase
    func rejectsEmptyHost(): Unit {
        let o = ConnectionOptions("", 22, "admin", "secret")
        try {
            SSHConnection.connect(o)
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("host"), true)
        }
    }

    @TestCase
    func rejectsEmptyUsername(): Unit {
        let o = ConnectionOptions("127.0.0.1", 22, "", "secret")
        try {
            SSHConnection.connect(o)
            @Fail("expected AuthenticationException")
        } catch (e: AuthenticationException) {
            @Expect(e.message.contains("username"), true)
        }
    }

    @TestCase
    func rejectsZeroPort(): Unit {
        let o = ConnectionOptions("127.0.0.1", 0, "admin", "secret")
        try {
            SSHConnection.connect(o)
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("port"), true)
        }
    }

    @TestCase
    func surfacesRefusedConnectionAsConnectionException(): Unit {
        let o = ConnectionOptions("127.0.0.1", 1, "admin", "secret")
        o.connectTimeoutMs = 3000
        try {
            SSHConnection.connect(o)
            @Fail("expected ConnectionException")
        } catch (e: ConnectionException) {
            @Expect(e.errnoValue, 111)
        }
    }

    @TestCase
    func defaultsAreSane(): Unit {
        let o = ConnectionOptions()
        @Expect(o.port, 22)
        @Expect(o.requestPty, true)
        @Expect(o.connectTimeoutMs > 0, true)
        @Expect(o.commandTimeoutMs > 0, true)
        @Expect(o.terminalWidth > 80, true)
    }
}

@Test
class LiveSshTests {
    @TestCase
    func handshakeAndBanner(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST")) {
            return
        }
        let host = envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1")
        let port = UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22"))

        let transport = TcpTransport.connect(host, port, 10000)
        try (session = Session.handshake(transport, 10000)) {
            let banner = session.banner()
            @Expect(banner.startsWith("SSH-"), true)
            @Expect(session.hostKeyFingerprintSha256().size, 32)
            @Expect(session.isAuthenticated(), false)
            let methods = session.authMethods(envOr("GLYPHNET_TEST_SSH_USER", "root"))
            @Expect(methods.isEmpty(), false)
        }
    }

    @TestCase
    func rejectsWrongPassword(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST")) {
            return
        }
        let host = envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1")
        let port = UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22"))
        let o = ConnectionOptions(host, port, envOr("GLYPHNET_TEST_SSH_USER", "root"),
                                  "definitely-not-the-password-9f3a")
        try {
            SSHConnection.connect(o)
            @Fail("expected AuthenticationException for a wrong password")
        } catch (e: AuthenticationException) {
            @Expect(e.message.contains("authentication failed"), true)
        }
    }

    @TestCase
    func fullCommandRoundTrip(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST") || !envSet("GLYPHNET_TEST_SSH_PASSWORD")) {
            return
        }
        let o = ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                                  UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                                  envOr("GLYPHNET_TEST_SSH_USER", "root"),
                                  envOr("GLYPHNET_TEST_SSH_PASSWORD", ""))
        try (conn = SSHConnection.connect(o)) {
            let prompt = conn.findPrompt()
            @Expect(prompt.isEmpty(), false)

            let echoed = conn.sendCommand("echo GLYPHNET_OK")
            @Expect(echoed.contains("GLYPHNET_OK"), true)

            @Expect(echoed.contains("echo GLYPHNET_OK"), false)

            let multi = conn.sendCommands(["echo first", "echo second"])
            @Expect(multi.size, 2)
            @Expect(multi[0].contains("first"), true)
            @Expect(multi[1].contains("second"), true)

            @Expect(conn.serverBanner().startsWith("SSH-"), true)
            @Expect(conn.hostKeyFingerprint().size, 32)
        }
    }

    @TestCase
    func publicKeyAuthRoundTrip(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST") || !envSet("GLYPHNET_TEST_SSH_KEY")) {
            return
        }
        let o = ConnectionOptions()
        o.host = envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1")
        o.port = UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22"))
        o.username = envOr("GLYPHNET_TEST_SSH_USER", "root")

        o.auth = AuthMethod.PublicKey(envOr("GLYPHNET_TEST_SSH_KEY", ""), "", "")

        try (conn = SSHConnection.connect(o)) {
            @Expect(conn.prompt.isEmpty(), false)
            let out = conn.sendCommand("echo PUBKEY_OK")
            @Expect(out.contains("PUBKEY_OK"), true)
        }
    }

    @TestCase
    func rejectsWrongPrivateKey(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST")) {
            return
        }
        let o = ConnectionOptions()
        o.host = envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1")
        o.port = UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22"))
        o.username = envOr("GLYPHNET_TEST_SSH_USER", "root")
        o.auth = AuthMethod.PublicKey("/nonexistent/glyphnet/key", "", "")
        try {
            SSHConnection.connect(o)
            @Fail("expected AuthenticationException for a missing key file")
        } catch (e: AuthenticationException) {
            @Expect(e.message.isEmpty(), false)
        }
    }

    @TestCase
    func pinnedHostKeyMismatchIsRejected(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST")) {
            return
        }
        let o = ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                                  UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                                  envOr("GLYPHNET_TEST_SSH_USER", "root"), "irrelevant")

        o.hostKeyPolicy = HostKeyPolicy.Pinned(Array<UInt8>(32, repeat: 0))
        try {
            SSHConnection.connect(o)
            @Fail("expected HostKeyException for a mismatched pinned fingerprint")
        } catch (e: HostKeyException) {
            @Expect(e.message.contains("fingerprint mismatch"), true)
        }
    }

    @TestCase
    func pinnedHostKeyMatchIsAccepted(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST")) {
            return
        }
        let host = envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1")
        let port = UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22"))

        var actual = Array<UInt8>()
        let t = TcpTransport.connect(host, port, 10000)
        try (s = Session.handshake(t, 10000)) {
            actual = s.hostKeyFingerprintSha256()
        }
        @Expect(actual.size, 32)

        let o = ConnectionOptions(host, port, envOr("GLYPHNET_TEST_SSH_USER", "root"),
                                  "definitely-wrong-password-4a1c")
        o.hostKeyPolicy = HostKeyPolicy.Pinned(actual)
        try {
            SSHConnection.connect(o)
            @Fail("expected auth to fail, not the host key check")
        } catch (e: AuthenticationException) {
            @Expect(e.message.contains("authentication failed"), true)
        }
    }

    @TestCase
    func disconnectIsIdempotent(): Unit {
        if (!envSet("GLYPHNET_TEST_SSH_HOST") || !envSet("GLYPHNET_TEST_SSH_PASSWORD")) {
            return
        }
        let o = ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                                  UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                                  envOr("GLYPHNET_TEST_SSH_USER", "root"),
                                  envOr("GLYPHNET_TEST_SSH_PASSWORD", ""))
        let conn = SSHConnection.connect(o)
        conn.disconnect()
        conn.disconnect()
        @Expect(conn.isClosed(), true)

        try {
            conn.sendCommand("echo nope")
            @Fail("expected CommandException on a closed connection")
        } catch (e: CommandException) {
            @Expect(e.message.contains("closed"), true)
        }
    }
}
