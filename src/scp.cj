package glyphnet

import glyphnet.errors.*
import glyphnet.ssh2.*
import std.fs.*
import std.time.*

public const SCP_CHUNK_SIZE: Int64 = 32768

public const SCP_MODE_FILE: Int32 = 0o644

public const SCP_MODE_EXECUTABLE: Int32 = 0o755

let SCP_END_OF_FILE: Array<UInt8> = [0]

public class ScpTransfer <: ToString {
    public let localPath: String
    public let remotePath: String
    public let bytes: Int64
    public let elapsedMs: Int64

    init(localPath: String, remotePath: String, bytes: Int64, elapsedMs: Int64) {
        this.localPath = localPath
        this.remotePath = remotePath
        this.bytes = bytes
        this.elapsedMs = elapsedMs
    }

    public prop bytesPerSecond: Float64 {
        get() {
            if (elapsedMs <= 0) {
                return 0.0
            }
            return Float64(bytes) * 1000.0 / Float64(elapsedMs)
        }
    }

    public func toString(): String {
        return "ScpTransfer(${bytes} bytes in ${elapsedMs}ms, local='${localPath}', " +
               "remote='${remotePath}')"
    }
}

extend SSHConnection {
    public func scpUpload(localPath: String, remotePath: String): ScpTransfer {
        return scpUpload(localPath, remotePath, transferTimeoutMs())
    }

    public func scpUpload(localPath: String, remotePath: String, timeoutMs: Int64): ScpTransfer {
        validateScpArguments(localPath, remotePath, timeoutMs)

        let path = Path(localPath)
        if (!exists(path)) {
            throw CommandException("local file '${localPath}' does not exist")
        }
        let info = FileInfo(path)
        if (info.isDirectory()) {
            throw CommandException(
                "'${localPath}' is a directory; SCP moves one regular file per call")
        }
        let size = info.size
        let mode = if (info.canExecute()) {
            SCP_MODE_EXECUTABLE
        } else {
            SCP_MODE_FILE
        }

        let session = rawSession()
        let started = MonoTime.now()
        let channel = session.openScpSend(remotePath, mode, size, 0, 0)
        var sent: Int64 = 0
        try {
            let file = File(localPath, OpenMode.Read)
            try {
                let buf = Array<UInt8>(SCP_CHUNK_SIZE, repeat: 0)
                while (sent < size) {
                    let n = file.read(buf)
                    if (n <= 0) {
                        break
                    }
                    let want = if (sent + n > size) {
                        size - sent
                    } else {
                        n
                    }
                    channel.writeAll(buf[0..want], timeoutMs)
                    sent += want
                }
            } finally {
                file.close()
            }
            if (sent != size) {
                throw CommandException(
                    "'${localPath}' shrank while uploading: announced ${size} bytes to SCP but " +
                    "only ${sent} could be read")
            }
            channel.writeAll(SCP_END_OF_FILE, timeoutMs)
            channel.sendEof()
            let status = channel.waitForExit(timeoutMs)
            if (status != 0) {
                throw CommandException(
                    "SCP upload of '${localPath}' to '${remotePath}' failed; the remote scp " +
                    "process exited with status ${status}")
            }
        } finally {
            closeQuietly(channel)
        }
        return ScpTransfer(localPath, remotePath, sent,
                           (MonoTime.now() - started).toMilliseconds())
    }

    public func scpDownload(remotePath: String, localPath: String): ScpTransfer {
        return scpDownload(remotePath, localPath, transferTimeoutMs())
    }

    public func scpDownload(remotePath: String, localPath: String, timeoutMs: Int64): ScpTransfer {
        validateScpArguments(localPath, remotePath, timeoutMs)

        let session = rawSession()
        let started = MonoTime.now()
        let opened = session.openScpRecv(remotePath)
        let channel = opened[0]
        let size = opened[1]
        if (size < 0) {
            closeQuietly(channel)
            throw CommandException(
                "server reported a negative size (${size}) for '${remotePath}'")
        }

        var received: Int64 = 0
        try {
            let file = File(localPath, OpenMode.Write)
            try {
                let buf = Array<UInt8>(SCP_CHUNK_SIZE, repeat: 0)
                while (received < size) {
                    let remaining = size - received
                    let slot = if (remaining < SCP_CHUNK_SIZE) {
                        buf[0..remaining]
                    } else {
                        buf
                    }
                    let n = channel.readChunk(slot, timeoutMs)
                    if (n <= 0) {
                        throw CommandException(
                            "SCP download of '${remotePath}' ended early: expected ${size} " +
                            "bytes, got ${received}")
                    }
                    file.write(slot[0..n])
                    received += n
                }
                file.flush()
            } finally {
                file.close()
            }
            channel.sendEof()
        } finally {
            closeQuietly(channel)
        }
        return ScpTransfer(localPath, remotePath, received,
                           (MonoTime.now() - started).toMilliseconds())
    }
}

func validateScpArguments(localPath: String, remotePath: String, timeoutMs: Int64): Unit {
    if (localPath.isEmpty()) {
        throw CommandException("local path must not be empty")
    }
    if (remotePath.isEmpty()) {
        throw CommandException("remote path must not be empty")
    }
    if (timeoutMs <= 0) {
        throw CommandException("SCP timeout must be positive, got ${timeoutMs}ms")
    }
}

func closeQuietly(channel: Channel): Unit {
    try {
        channel.close()
    } catch (_: Exception) {
    }
}
