package glyphnet.ssh2

import glyphnet.ffi.*
import glyphnet.errors.*
import std.sync.*

public class Libssh2 {
    private static let lock = Mutex()
    private static var initialised = false

    public static func ensureInit(): Unit {
        synchronized(lock) {
            if (initialised) {
                return
            }
            let rc = ssh2Init()
            if (rc != 0) {
                throw SshException("libssh2_init() failed", rc, "")
            }
            initialised = true
        }
    }

    public static func shutdown(): Unit {
        synchronized(lock) {
            if (!initialised) {
                return
            }
            ssh2Exit()
            initialised = false
        }
    }

    public static func version(): String {
        return ssh2Version()
    }
}
