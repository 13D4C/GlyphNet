package cisco_config

import glyphnet.*
import glyphnet.errors.*

func joinWithSpaces(parts: Array<String>): String {
    let sb = StringBuilder()
    var i = 0
    while (i < parts.size) {
        if (i > 0) {
            sb.append(" ")
        }
        sb.append(parts[i])
        i += 1
    }
    return sb.toString()
}

main(args: Array<String>): Int64 {
    if (args.size < 5) {
        println("usage: main <host> <user> <password> <interface> <description...>")
        return 2
    }

    let host = args[0]
    let user = args[1]
    let password = args[2]
    let iface = args[3]
    let description = joinWithSpaces(args[4..args.size])

    let opts = ConnectionOptions(host, 22, user, password)
    opts.pagingCommand = "terminal length 0"
    opts.commandTimeoutMs = 25000

    try {
        try (conn = SSHConnection.connect(opts)) {
            println("connected as ${user}@${host}, prompt [${conn.prompt}]")

            println("")
            println("=== show ip interface brief ===")
            println(conn.sendCommand("show ip interface brief"))

            let steps = [
                "configure terminal",
                "interface ${iface}",
                "description ${description}",
                "end"
            ]
            for (step in steps) {
                println("")
                println("=== ${step} ===")
                println(conn.sendCommand(step))
            }

            println("")
            println("=== show running-config interface ${iface} ===")
            println(conn.sendCommand("show running-config interface ${iface}"))
        }
        return 0
    } catch (e: GlyphNetException) {
        println("FAILED: ${e.message}")
        return 1
    }
}
