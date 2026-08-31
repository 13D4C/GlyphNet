package glyphnet

import glyphnet.errors.*
import glyphnet.ffi.*
import glyphnet.ssh2.*
import glyphnet.transport.*
import std.collection.*
import std.convert.*
import std.net.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

func liveSshConfigured(): Bool {
    return envSet("GLYPHNET_TEST_SSH_HOST") && envSet("GLYPHNET_TEST_SSH_PASSWORD")
}

func liveConnection(): SSHConnection {
    let o = ConnectionOptions(envOr("GLYPHNET_TEST_SSH_HOST", "127.0.0.1"),
                              UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22")),
                              envOr("GLYPHNET_TEST_SSH_USER", "root"),
                              envOr("GLYPHNET_TEST_SSH_PASSWORD", ""))
    o.commandTimeoutMs = 20000
    return SSHConnection.connect(o)
}

func liveSshPort(): UInt16 {
    return UInt16.parse(envOr("GLYPHNET_TEST_SSH_PORT", "22"))
}

func readWithDeadline(socket: TcpSocket, limit: Int64): String {
    let buf = Array<Byte>(limit, repeat: 0)
    let n = socket.read(buf)
    if (n <= 0) {
        return ""
    }
    return String.fromUtf8(buf[0..n])
}

@Test
class TcpListenerTests {
    @TestCase
    func bindsAnEphemeralPort(): Unit {
        let l = TcpListener.bind("127.0.0.1", 0, 8)
        try {
            @Expect(l.port > 0, true)
            @Expect(l.host, "127.0.0.1")
            @Expect(l.fd >= 0, true)
            @Expect(l.isClosed(), false)
        } finally {
            l.close()
        }
    }

    @TestCase
    func acceptReturnsNoneWhenIdle(): Unit {
        let l = TcpListener.bind("127.0.0.1", 0, 8)
        try {
            @Expect(l.acceptNonBlocking().isNone(), true)
            @Expect(l.waitForConnection(50), false)
        } finally {
            l.close()
        }
    }

    @TestCase
    func acceptsARealConnection(): Unit {
        let l = TcpListener.bind("127.0.0.1", 0, 8)
        try {
            let port = l.port
            let client = spawn {
                let s = TcpSocket("127.0.0.1", port)
                s.connect(timeout: Duration.second * 5)
                s.write("GLYPHNET_LISTENER_PROBE".toArray())
                sleep(Duration.millisecond * 200)
                s.close()
                return true
            }
            @Expect(l.waitForConnection(3000), true)
            let accepted = l.acceptNonBlocking()
            @Expect(accepted.isSome(), true)

            let fd = accepted.getOrThrow()
            let transport = TcpTransport.adopt(fd, "127.0.0.1", port)
            let buf = Array<UInt8>(64, repeat: 0)
            var got = ""
            let deadline = MonoTime.now() + Duration.second * 3
            while (MonoTime.now() < deadline && got.isEmpty()) {
                let n = transport.readSome(buf)
                if (n > 0) {
                    got = String.fromUtf8(buf[0..n])
                } else {
                    sleep(Duration.millisecond * 20)
                }
            }
            transport.close()
            client.get()
            @Expect(got, "GLYPHNET_LISTENER_PROBE")
        } finally {
            l.close()
        }
    }

    @TestCase
    func closeIsIdempotent(): Unit {
        let l = TcpListener.bind("127.0.0.1", 0, 8)
        l.close()
        l.close()
        @Expect(l.isClosed(), true)
        @Expect(l.acceptNonBlocking().isNone(), true)
    }

    @TestCase
    func refusesAPrivilegedPort(): Unit {
        try {
            let l = TcpListener.bind("127.0.0.1", 1, 8)
            l.close()
        } catch (e: ConnectionException) {
            @Expect(e.message.contains("cannot listen on"), true)
        }
    }
}

@Test
class ForwardValidationTests {
    @TestCase
    func localForwardRejectsEmptyRemoteHost(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            try {
                LocalForward.start(conn, 0, "", 22)
                @Fail("expected ConnectionException for an empty remote host")
            } catch (e: ConnectionException) {
                @Expect(e.message.contains("remoteHost"), true)
            }
        }
    }

    @TestCase
    func remoteForwardRejectsZeroLocalPort(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            try {
                RemoteForward.start(conn, 0, "127.0.0.1", 0)
                @Fail("expected ConnectionException for a zero local port")
            } catch (e: ConnectionException) {
                @Expect(e.message.contains("localPort"), true)
            }
        }
    }

    @TestCase
    func execChannelRejectsBadArguments(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            try {
                conn.execChannel("")
                @Fail("expected CommandException for an empty command")
            } catch (e: CommandException) {
                @Expect(e.message.contains("must not be empty"), true)
            }
            try {
                conn.execChannel("echo hi", 0)
                @Fail("expected CommandException for a zero timeout")
            } catch (e: CommandException) {
                @Expect(e.message.contains("positive"), true)
            }
        }
    }
}

@Test
class MultiChannelTests {
    @TestCase
    func execChannelLeavesTheShellUndisturbed(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let prompt = conn.findPrompt()
            @Expect(prompt.isEmpty(), false)

            conn.sendCommand("GLYPHNET_SHELL_STATE=kept")
            @Expect(conn.sendCommand("echo v=$GLYPHNET_SHELL_STATE").contains("v=kept"), true)

            let first = conn.execChannel("echo EXEC_CHANNEL_ONE")
            @Expect(first.output.contains("EXEC_CHANNEL_ONE"), true)
            @Expect(first.exitStatus, 0)
            @Expect(first.succeeded, true)

            let isolated = conn.execChannel("echo v=$GLYPHNET_SHELL_STATE")
            @Expect(isolated.output.contains("v=kept"), false)

            let second = conn.execChannel("echo EXEC_CHANNEL_TWO")
            @Expect(second.output.contains("EXEC_CHANNEL_TWO"), true)

            @Expect(conn.sendCommand("echo v=$GLYPHNET_SHELL_STATE").contains("v=kept"), true)
            @Expect(conn.findPrompt(), prompt)
            @Expect(conn.isAlive(), true)
        }
    }

    @TestCase
    func execChannelReportsExitStatus(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let failed = conn.execChannel("exit 7")
            @Expect(failed.exitStatus, 7)
            @Expect(failed.succeeded, false)

            let ok = conn.execChannel("true")
            @Expect(ok.exitStatus, 0)
        }
    }

    @TestCase
    func execChannelsRunABatch(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let results = conn.execChannels(["echo alpha", "echo beta"])
            @Expect(results.size, 2)
            @Expect(results[0].output.contains("alpha"), true)
            @Expect(results[1].output.contains("beta"), true)
        }
    }

    @TestCase
    func channelsAreSafeAcrossThreads(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            conn.findPrompt()
            let workers = ArrayList<Future<Bool>>()
            for (i in 0..4) {
                workers.add(
                    spawn {
                        var allGood = true
                        for (j in 0..3) {
                            let marker = "THREAD_${i}_ROUND_${j}"
                            let r = conn.execChannel("echo ${marker}")
                            if (!r.output.contains(marker) || r.exitStatus != 0) {
                                allGood = false
                            }
                        }
                        return allGood
                    })
            }
            let shellWorker = spawn {
                var allGood = true
                for (k in 0..3) {
                    if (!conn.sendCommand("echo SHELL_ROUND_${k}").contains("SHELL_ROUND_${k}")) {
                        allGood = false
                    }
                }
                return allGood
            }
            for (w in workers) {
                @Expect(w.get(), true)
            }
            @Expect(shellWorker.get(), true)
            @Expect(conn.isAlive(), true)
        }
    }
}

@Test
class PortForwardingTests {
    @TestCase
    func localForwardCarriesRealTraffic(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let fwd = LocalForward.start(conn, 0, "127.0.0.1", liveSshPort())
            try {
                @Expect(fwd.localPort > 0, true)
                @Expect(fwd.remotePort, liveSshPort())
                fwd.startBackgroundPump()

                let s = TcpSocket("127.0.0.1", fwd.localPort)
                s.connect(timeout: Duration.second * 10)
                let banner = readWithDeadline(s, 128)
                s.close()

                @Expect(banner.startsWith("SSH-"), true)
                @Expect(fwd.acceptedConnections, 1)
            } finally {
                fwd.close()
            }
            @Expect(conn.isAlive(), true)
            @Expect(conn.sendCommand("echo AFTER_LOCAL_FORWARD").contains("AFTER_LOCAL_FORWARD"),
                    true)
        }
    }

    @TestCase
    func localForwardServesSeveralConnections(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let fwd = LocalForward.start(conn, 0, "127.0.0.1", liveSshPort())
            try {
                fwd.startBackgroundPump()
                var banners = 0
                for (_ in 0..3) {
                    let s = TcpSocket("127.0.0.1", fwd.localPort)
                    s.connect(timeout: Duration.second * 10)
                    if (readWithDeadline(s, 128).startsWith("SSH-")) {
                        banners += 1
                    }
                    s.close()
                }
                @Expect(banners, 3)
                @Expect(fwd.acceptedConnections, 3)
            } finally {
                fwd.close()
            }
        }
    }

    @TestCase
    func remoteForwardCarriesTrafficBackToALocalServer(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let receiver = TcpServerSocket(bindAt: 0)
            receiver.bind()
            let localPort = (receiver.localAddress as IPSocketAddress).getOrThrow().port

            let served = spawn {
                let c = receiver.accept()
                let buf = Array<Byte>(256, repeat: 0)
                let n = c.read(buf)
                let text = if (n > 0) {
                    String.fromUtf8(buf[0..n])
                } else {
                    ""
                }
                c.write("PONG_FROM_LOCAL_SERVER".toArray())
                c.close()
                return text
            }

            let remote = RemoteForward.start(conn, "127.0.0.1", 0, "127.0.0.1", localPort)
            try {
                @Expect(remote.remotePort > 0, true)
                @Expect(remote.localPort, localPort)
                remote.startBackgroundPump()

                let local = LocalForward.start(conn, 0, "127.0.0.1", remote.remotePort)
                try {
                    local.startBackgroundPump()
                    let s = TcpSocket("127.0.0.1", local.localPort)
                    s.connect(timeout: Duration.second * 10)
                    s.write("PING_THROUGH_BOTH_TUNNELS".toArray())
                    let reply = readWithDeadline(s, 256)
                    s.close()

                    @Expect(reply.contains("PONG_FROM_LOCAL_SERVER"), true)
                    @Expect(served.get().contains("PING_THROUGH_BOTH_TUNNELS"), true)
                    @Expect(remote.acceptedConnections >= 1, true)
                } finally {
                    local.close()
                }
            } finally {
                remote.close()
                receiver.close()
            }
            @Expect(conn.isAlive(), true)
        }
    }

    @TestCase
    func forwardsRejectUseAfterClose(): Unit {
        if (!liveSshConfigured()) {
            return
        }
        try (conn = liveConnection()) {
            let fwd = LocalForward.start(conn, 0, "127.0.0.1", liveSshPort())
            fwd.close()
            fwd.close()
            @Expect(fwd.isClosed(), true)
            try {
                fwd.pumpOnce(10)
                @Fail("expected CommandException pumping a closed forward")
            } catch (e: CommandException) {
                @Expect(e.message.contains("already closed"), true)
            }
        }
    }
}
