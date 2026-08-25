package glyphnet_smoke

import glyphnet.*
import glyphnet.errors.*
import glyphnet.ssh2.*
import glyphnet.transport.*
import std.convert.*

func handshakeOnly(host: String, port: UInt16): Int64 {
    println("--- handshake only (no authentication) ---")
    let transport = TcpTransport.connect(host, port, 10000)
    println("TCP connected to ${host}:${port}, raw fd = ${transport.fd}")
    try (session = Session.handshake(transport, 10000)) {
        println("server banner      : ${session.banner()}")
        println("host key type      : ${session.hostKeyType()}")
        println("host key sha256    : ${hexOf(session.hostKeyFingerprintSha256())}")
        println("authenticated?     : ${session.isAuthenticated()}")
    }
    println("handshake OK, session closed cleanly")
    return 0
}

func fullSession(host: String, port: UInt16, user: String, password: String,
                 commands: Array<String>): Int64 {
    println("--- full session as ${user}@${host}:${port} ---")
    let opts = ConnectionOptions(host, port, user, password)
    opts.commandTimeoutMs = 20000

    try (conn = SSHConnection.connect(opts)) {
        println("server banner      : ${conn.serverBanner()}")
        println("host key sha256    : ${hexOf(conn.hostKeyFingerprint())}")
        println("detected prompt    : [${conn.prompt}]")
        println("findPrompt() again : [${conn.findPrompt()}]")
        println("alive?             : ${conn.isAlive()}")

        for (cmd in commands) {
            println("")
            println("$ ${cmd}")
            let output = conn.sendCommand(cmd)
            println(output)
        }
        println("")
        println("disconnecting")
    }
    println("session closed cleanly")
    return 0
}

main(args: Array<String>): Int64 {
    println("glyphnet ${GLYPHNET_VERSION} / libssh2 ${libssh2Version()}")

    if (args.size == 0) {
        println("no target given; versions only")
        return 0
    }
    if (args.size < 2) {
        println("usage: main <host> <port> [user password [command...]]")
        return 2
    }

    let host = args[0]
    let port = UInt16.parse(args[1])

    try {
        if (args.size < 4) {
            return handshakeOnly(host, port)
        }
        var commands = ["echo GLYPHNET_OK", "uname -sr", "whoami"]
        if (args.size > 4) {
            commands = args[4..args.size]
        }
        return fullSession(host, port, args[2], args[3], commands)
    } catch (e: GlyphNetException) {
        println("FAILED: ${e.message}")
        return 1
    }
}
