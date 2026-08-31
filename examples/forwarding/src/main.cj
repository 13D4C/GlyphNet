package glyphnet_forwarding

import glyphnet.*
import glyphnet.errors.*
import std.collection.*
import std.net.*
import std.convert.*
import std.time.*


func openConnection(host: String, port: UInt16, user: String, password: String): SSHConnection {
    let o = ConnectionOptions(host, port, user, password)
    o.commandTimeoutMs = 20000
    return SSHConnection.connect(o)
}

func runMulti(conn: SSHConnection): Unit {
    println("[multi] prompt=${conn.prompt}")
    let shellBefore = conn.sendCommand("echo SHELL_MARKER_1")
    println("[multi] shell#1 -> ${shellBefore.trimAscii()}")

    conn.sendCommand("MYVAR=shellstate")
    let stateEcho = conn.sendCommand("echo state=$MYVAR")
    println("[multi] shell state -> ${stateEcho.trimAscii()}")

    let a = conn.execChannel("echo EXEC_ONE; id -un")
    println("[multi] exec#1 status=${a.exitStatus} out=${a.output.trimAscii().replace("\n", " | ")}")

    let b = conn.execChannel("echo state_in_exec=$MYVAR")
    println("[multi] exec#2 status=${b.exitStatus} out=${b.output.trimAscii()}")

    let c = conn.execChannel("exit 7")
    println("[multi] exec#3 status=${c.exitStatus} succeeded=${c.succeeded}")

    let shellAfter = conn.sendCommand("echo state_still=$MYVAR")
    println("[multi] shell after exec -> ${shellAfter.trimAscii()}")
    println("[multi] prompt still=${conn.findPrompt()} alive=${conn.isAlive()}")
}

func runConcurrent(conn: SSHConnection): Unit {
    let futures = ArrayList<Future<String>>()
    for (i in 0..4) {
        futures.add(
            spawn {
                let sb = StringBuilder()
                for (j in 0..3) {
                    let r = conn.execChannel("echo T${i}_${j}")
                    sb.append(r.output.trimAscii())
                    sb.append(",")
                }
                return sb.toString()
            })
    }
    let shell = spawn {
        let sb = StringBuilder()
        for (k in 0..3) {
            sb.append(conn.sendCommand("echo SHELL_${k}").trimAscii())
            sb.append(",")
        }
        return sb.toString()
    }
    for (f in futures) {
        println("[concurrent] exec thread -> ${f.get()}")
    }
    println("[concurrent] shell thread -> ${shell.get()}")
    println("[concurrent] alive=${conn.isAlive()}")
}

func runLocalForward(conn: SSHConnection, remoteHost: String, remotePort: UInt16): Unit {
    let fwd = LocalForward.start(conn, 0, remoteHost, remotePort)
    println("[local] listening on ${fwd.localHost}:${fwd.localPort} -> ${remoteHost}:${remotePort} (as seen by the server)")

    let port = fwd.localPort
    let client = spawn {
        let s = TcpSocket("127.0.0.1", port)
        s.connect(timeout: Duration.second * 10)
        let buf = Array<Byte>(256, repeat: 0)
        let n = s.read(buf)
        let banner = String.fromUtf8(buf[0..n]).trimAscii()
        s.write("SSH-2.0-GlyphNetProbe\r\n".toArray())
        s.close()
        return banner
    }

    let deadline = MonoTime.now() + Duration.millisecond * 15000
    while (MonoTime.now() < deadline && client.tryGet().isNone()) {
        fwd.pumpOnce(20)
    }
    println("[local] banner through tunnel = '${client.get()}'")
    println("[local] accepted=${fwd.acceptedConnections} active=${fwd.activeStreams}")
    fwd.serve(500)
    fwd.close()
    println("[local] closed, connection still alive=${conn.isAlive()}")
    println("[local] shell after tunnel -> ${conn.sendCommand("echo LOCAL_FWD_SHELL_OK").trimAscii()}")
}

func runLocalForwardBackground(conn: SSHConnection, remoteHost: String, remotePort: UInt16): Unit {
    let fwd = LocalForward.start(conn, 0, remoteHost, remotePort)
    fwd.startBackgroundPump()
    println("[localbg] background pump serving ${fwd.localHost}:${fwd.localPort} -> ${remoteHost}:${remotePort}")

    let port = fwd.localPort
    var ok = 0
    for (i in 0..3) {
        let s = TcpSocket("127.0.0.1", port)
        s.connect(timeout: Duration.second * 10)
        let buf = Array<Byte>(256, repeat: 0)
        let n = s.read(buf)
        let got = String.fromUtf8(buf[0..n]).trimAscii()
        println("[localbg] client ${i} received '${got}'")
        if (!got.isEmpty()) {
            ok += 1
        }
        s.close()
    }
    println("[localbg] successful=${ok}/3 accepted=${fwd.acceptedConnections}")

    let exec = conn.execChannel("echo EXEC_WHILE_PUMPING")
    println("[localbg] exec during background pump -> ${exec.output.trimAscii()} status=${exec.exitStatus}")
    println("[localbg] shell during background pump -> ${conn.sendCommand("echo SHELL_WHILE_PUMPING").trimAscii()}")

    fwd.close()
    println("[localbg] closed=${fwd.isClosed()} conn alive=${conn.isAlive()}")
}

func runRemoteForward(conn: SSHConnection, remotePort: UInt16): Unit {
    let receiver = TcpServerSocket(bindAt: 0)
    receiver.bind()
    let localPort = (receiver.localAddress as IPSocketAddress).getOrThrow().port
    println("[remote] local receiver on 127.0.0.1:${localPort}")

    let received = spawn {
        let c = receiver.accept()
        let buf = Array<Byte>(512, repeat: 0)
        let n = c.read(buf)
        let text = String.fromUtf8(buf[0..n]).trimAscii()
        c.write("GLYPHNET_REMOTE_REPLY\n".toArray())
        c.close()
        return text
    }

    let fwd = RemoteForward.start(conn, "127.0.0.1", remotePort, "127.0.0.1", localPort)
    println("[remote] server listening on remote port ${fwd.remotePort} -> 127.0.0.1:${localPort}")
    println("READY ${fwd.remotePort}")

    let deadline = MonoTime.now() + Duration.millisecond * 25000
    while (MonoTime.now() < deadline && received.tryGet().isNone()) {
        fwd.pumpOnce(20)
    }
    fwd.serve(1000)
    println("[remote] data arrived from container = '${received.get()}'")
    println("[remote] accepted=${fwd.acceptedConnections}")
    fwd.close()
    receiver.close()
    println("[remote] closed, shell -> ${conn.sendCommand("echo REMOTE_FWD_SHELL_OK").trimAscii()}")
}

main(args: Array<String>): Int64 {
    if (args.size < 5) {
        println("usage: main <phase> <host> <port> <user> <password> [extra]")
        return 2
    }
    let phase = args[0]
    let host = args[1]
    let port = UInt16.parse(args[2])
    let user = args[3]
    let password = args[4]

    try (conn = openConnection(host, port, user, password)) {
        match (phase) {
            case "multi" => runMulti(conn)
            case "concurrent" => runConcurrent(conn)
            case "local" =>
                let target = if (args.size > 5) { args[5] } else { "127.0.0.1" }
                let tport = if (args.size > 6) { UInt16.parse(args[6]) } else { port }
                runLocalForward(conn, target, tport)
            case "localbg" =>
                let target = if (args.size > 5) { args[5] } else { "127.0.0.1" }
                let tport = if (args.size > 6) { UInt16.parse(args[6]) } else { port }
                runLocalForwardBackground(conn, target, tport)
            case "remote" =>
                let rport: UInt16 = if (args.size > 5) { UInt16.parse(args[5]) } else { 0 }
                runRemoteForward(conn, rport)
            case _ =>
                println("unknown phase '${phase}'")
                return 2
        }
    } catch (e: GlyphNetException) {
        println("FAILED: ${e.message}")
        return 1
    }
    println("[${phase}] OK")
    return 0
}
