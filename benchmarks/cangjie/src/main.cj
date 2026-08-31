package glyphnet_bench

import glyphnet.*
import glyphnet.errors.*
import std.fs.*
import std.time.*

let HOST = "127.0.0.1"
let PORT: UInt16 = 2222
let USER = "netadmin"
let PASSWORD = "glyphnet123"

let CONNECT_ITERS = 10
let EXEC_ITERS = 50
let SENDCMD_ITERS = 50
let SCP_SIZE: Int64 = 20 * 1024 * 1024
let SCP_ITERS = 3

func patternBytes(size: Int64): Array<UInt8> {
    let out = Array<UInt8>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8((i * 31 + 7) % 251)
        i += 1
    }
    return out
}

func sortedCopy(values: Array<Int64>): Array<Int64> {
    let out = Array<Int64>(values.size, repeat: 0)
    var i = 0
    while (i < values.size) {
        out[i] = values[i]
        i += 1
    }
    i = 0
    while (i < out.size) {
        var j = i + 1
        while (j < out.size) {
            if (out[j] < out[i]) {
                let tmp = out[i]
                out[i] = out[j]
                out[j] = tmp
            }
            j += 1
        }
        i += 1
    }
    return out
}

func report(name: String, samplesMs: Array<Int64>): Unit {
    let sorted = sortedCopy(samplesMs)
    let n = sorted.size
    var sum: Int64 = 0
    var i = 0
    while (i < n) {
        sum += sorted[i]
        i += 1
    }
    let mean = Float64(sum) / Float64(n)
    let p50 = sorted[n / 2]
    var p95Index = Int64(Float64(n) * 0.95)
    if (p95Index >= n) {
        p95Index = n - 1
    }
    let p95 = sorted[p95Index]
    println("${name}: n=${n} mean=${mean}ms p50=${p50}ms p95=${p95}ms min=${sorted[0]}ms max=${sorted[n - 1]}ms")
}

func elapsedMs(start: MonoTime): Int64 {
    return (MonoTime.now() - start).toMilliseconds()
}

func benchConnect(): Array<Int64> {
    let samples = Array<Int64>(CONNECT_ITERS, repeat: 0)
    var i = 0
    while (i < CONNECT_ITERS) {
        let start = MonoTime.now()
        let conn = SSHConnection.connect(HOST, PORT, USER, PASSWORD)
        samples[i] = elapsedMs(start)
        conn.close()
        i += 1
    }
    return samples
}

func benchExecChannel(conn: SSHConnection): Array<Int64> {
    let samples = Array<Int64>(EXEC_ITERS, repeat: 0)
    var i = 0
    while (i < EXEC_ITERS) {
        let start = MonoTime.now()
        conn.execChannel("echo GLYPHNET_BENCH")
        samples[i] = elapsedMs(start)
        i += 1
    }
    return samples
}

func benchSendCommand(conn: SSHConnection): Array<Int64> {
    let samples = Array<Int64>(SENDCMD_ITERS, repeat: 0)
    var i = 0
    while (i < SENDCMD_ITERS) {
        let start = MonoTime.now()
        conn.sendCommand("echo GLYPHNET_BENCH")
        samples[i] = elapsedMs(start)
        i += 1
    }
    return samples
}

func benchScp(conn: SSHConnection): (Array<Int64>, Array<Int64>, Float64, Float64) {
    let localUp = "/tmp/glyphnet_cj_bench_upload.bin"
    let localDown = "/tmp/glyphnet_cj_bench_download.bin"
    let remotePath = "/tmp/glyphnet_bench_glyphnet.bin"

    File.writeTo(localUp, patternBytes(SCP_SIZE))

    let upSamples = Array<Int64>(SCP_ITERS, repeat: 0)
    let downSamples = Array<Int64>(SCP_ITERS, repeat: 0)
    var upBpsSum: Float64 = 0.0
    var downBpsSum: Float64 = 0.0

    var i = 0
    while (i < SCP_ITERS) {
        let t0 = MonoTime.now()
        let up = conn.scpUpload(localUp, remotePath)
        upSamples[i] = elapsedMs(t0)
        upBpsSum += Float64(up.bytesPerSecond)

        let t1 = MonoTime.now()
        let down = conn.scpDownload(remotePath, localDown)
        downSamples[i] = elapsedMs(t1)
        downBpsSum += Float64(down.bytesPerSecond)
        i += 1
    }

    conn.execChannel("rm -f ${remotePath}")
    removeQuietly(localUp)
    removeQuietly(localDown)

    return (upSamples, downSamples, upBpsSum / Float64(SCP_ITERS), downBpsSum / Float64(SCP_ITERS))
}

func removeQuietly(path: String): Unit {
    try {
        if (exists(Path(path))) {
            remove(Path(path))
        }
    } catch (_: Exception) {
    }
}

main(): Int64 {
    try {
        println("connect: glyphnet")
        report("glyphnet connect", benchConnect())

        let conn = SSHConnection.connect(HOST, PORT, USER, PASSWORD)

        println("execChannel: glyphnet")
        report("glyphnet execChannel", benchExecChannel(conn))

        println("sendCommand: glyphnet")
        report("glyphnet sendCommand", benchSendCommand(conn))

        println("scp: glyphnet")
        let (upSamples, downSamples, upBps, downBps) = benchScp(conn)
        report("glyphnet scp upload", upSamples)
        report("glyphnet scp download", downSamples)
        println("glyphnet scp upload bytesPerSecond avg: ${upBps}")
        println("glyphnet scp download bytesPerSecond avg: ${downBps}")

        conn.close()
        return 0
    } catch (e: GlyphNetException) {
        println("FAILED: ${e.message}")
        return 1
    }
}
