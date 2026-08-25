package glyphnet

import glyphnet.ssh2.*

public const GLYPHNET_VERSION = "0.1.0"

public func libssh2Version(): String {
    return Libssh2.version()
}

public func initialize(): Unit {
    Libssh2.ensureInit()
}
