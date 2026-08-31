package glyphnet

import glyphnet.errors.*
import glyphnet.ffi.*
import glyphnet.ssh2.*
import glyphnet.transport.*
import std.collection.*
import std.time.*

const FORWARD_BUFFER_SIZE = 32768

const FORWARD_POLL_SLICE_MS: Int64 = 50

const FORWARD_ACCEPT_QUEUE: Int32 = 16

func copyRange(src: Array<UInt8>, from: Int64, to: Int64): Array<UInt8> {
    let out = Array<UInt8>(to - from, repeat: 0)
    var i = 0
    while (i < out.size) {
        out[i] = src[from + i]
        i += 1
    }
    return out
}

class ForwardedStream {
    private let socket: TcpTransport
    private let channel: Channel
    private let scratch = Array<UInt8>(FORWARD_BUFFER_SIZE, repeat: 0)

    private var pendingToRemote = Array<UInt8>()
    private var pendingToLocal = Array<UInt8>()
    private var localEof: Bool = false
    private var remoteEof: Bool = false
    private var broken: Bool = false
    private var closed: Bool = false

    var bytesToRemote: Int64 = 0
    var bytesToLocal: Int64 = 0

    init(socket: TcpTransport, channel: Channel) {
        this.socket = socket
        this.channel = channel
    }

    prop socketFd: Int32 {
        get() {
            socket.fd
        }
    }

    func pollEvents(): Int16 {
        var events: Int16 = 0
        if (!localEof && pendingToRemote.size == 0) {
            events |= POLLIN
        }
        if (pendingToLocal.size > 0) {
            events |= POLLOUT
        }
        return events
    }

    func pump(): Bool {
        if (closed || broken) {
            return false
        }
        var progressed = false
        if (pumpLocalToRemote()) {
            progressed = true
        }
        if (pumpRemoteToLocal()) {
            progressed = true
        }
        return progressed
    }

    private func pumpLocalToRemote(): Bool {
        var progressed = false

        if (pendingToRemote.size > 0) {
            let n = channel.writeSome(pendingToRemote)
            if (n > 0) {
                bytesToRemote += n
                pendingToRemote = copyRange(pendingToRemote, n, pendingToRemote.size)
                progressed = true
            } else if (Int32(n) != LIBSSH2_ERROR_EAGAIN && n != 0) {
                broken = true
                return true
            }
        }

        if (pendingToRemote.size == 0 && !localEof) {
            let n = socket.readSome(scratch)
            if (n > 0) {
                pendingToRemote = copyRange(scratch, 0, n)
                progressed = true
            } else if (n == 0) {
                localEof = true
                progressed = true
                try {
                    channel.sendEof()
                } catch (_: Exception) {
                    broken = true
                }
            } else {
                let e = errno()
                if (e != EAGAIN && e != EINTR) {
                    localEof = true
                    broken = true
                    progressed = true
                }
            }
        }
        return progressed
    }

    private func pumpRemoteToLocal(): Bool {
        var progressed = false

        if (pendingToLocal.size > 0) {
            let n = socket.writeSome(pendingToLocal)
            if (n > 0) {
                bytesToLocal += n
                pendingToLocal = copyRange(pendingToLocal, n, pendingToLocal.size)
                progressed = true
            } else {
                let e = errno()
                if (e != EAGAIN && e != EINTR) {
                    broken = true
                    return true
                }
            }
        }

        if (pendingToLocal.size == 0 && !remoteEof) {
            let n = channel.readSome(scratch)
            if (n > 0) {
                pendingToLocal = copyRange(scratch, 0, n)
                progressed = true
            } else if (n == 0) {
                if (channel.isEof()) {
                    remoteEof = true
                    progressed = true
                    socket.shutdownWrite()
                }
            } else if (Int32(n) != LIBSSH2_ERROR_EAGAIN) {
                remoteEof = true
                broken = true
                progressed = true
            }
        }
        return progressed
    }

    func isFinished(): Bool {
        if (closed || broken) {
            return true
        }
        let localDone = localEof && pendingToRemote.size == 0
        let remoteDone = remoteEof && pendingToLocal.size == 0
        return localDone && remoteDone
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        try {
            channel.close()
        } catch (_: Exception) {
        }
        socket.close()
    }
}

public class LocalForward <: Resource {
    private let session: Session
    private let listener: TcpListener
    private let streams = ArrayList<ForwardedStream>()
    private var closed: Bool = false
    private var pumpTask: Option<Future<Unit>> = None
    private var accepted: Int64 = 0
    private var rejected: Int64 = 0
    private var lastFailure: String = ""

    public let remoteHost: String
    public let remotePort: UInt16

    private init(session: Session, listener: TcpListener, remoteHost: String, remotePort: UInt16) {
        this.session = session
        this.listener = listener
        this.remoteHost = remoteHost
        this.remotePort = remotePort
    }

    public prop localHost: String {
        get() {
            listener.host
        }
    }

    public prop localPort: UInt16 {
        get() {
            listener.port
        }
    }

    public prop acceptedConnections: Int64 {
        get() {
            accepted
        }
    }

    public prop activeStreams: Int64 {
        get() {
            streams.size
        }
    }

    public prop rejectedConnections: Int64 {
        get() {
            rejected
        }
    }

    public prop lastError: String {
        get() {
            lastFailure
        }
    }

    public static func start(connection: SSHConnection, localPort: UInt16, remoteHost: String,
                             remotePort: UInt16): LocalForward {
        return start(connection, "127.0.0.1", localPort, remoteHost, remotePort)
    }

    public static func start(connection: SSHConnection, localHost: String, localPort: UInt16,
                             remoteHost: String, remotePort: UInt16): LocalForward {
        if (remoteHost.isEmpty()) {
            throw ConnectionException("remoteHost must not be empty for a local forward")
        }
        if (remotePort == 0) {
            throw ConnectionException("remotePort must not be 0 for a local forward")
        }
        let session = connection.rawSession()
        let listener = TcpListener.bind(localHost, localPort, FORWARD_ACCEPT_QUEUE)
        return LocalForward(session, listener, remoteHost, remotePort)
    }

    public func pumpOnce(waitMs: Int64): Bool {
        checkOpen()
        var progressed = acceptPending()
        if (pumpStreams()) {
            progressed = true
        }
        if (!progressed && waitMs > 0) {
            waitForActivity(waitMs)
        }
        return progressed
    }

    public func serve(durationMs: Int64): Unit {
        let deadline = MonoTime.now() + Duration.millisecond * durationMs
        while (!closed && MonoTime.now() < deadline) {
            pumpOnce(FORWARD_POLL_SLICE_MS)
        }
    }

    public func startBackgroundPump(): Unit {
        checkOpen()
        if (pumpTask.isSome()) {
            return
        }
        pumpTask = spawn {
            backgroundLoop()
        }
    }

    private func backgroundLoop(): Unit {
        while (!closed) {
            try {
                pumpOnce(FORWARD_POLL_SLICE_MS)
            } catch (_: Exception) {
                break
            }
        }
    }

    private func acceptPending(): Bool {
        var progressed = false
        while (true) {
            match (listener.acceptNonBlocking()) {
                case None => break
                case Some(fd) =>
                    progressed = true
                    accepted += 1
                    let socket = TcpTransport.adopt(fd, listener.host, listener.port)
                    try {
                        let channel = session.openDirectTcpIpChannel(remoteHost, remotePort,
                                                                     listener.host, listener.port)
                        streams.add(ForwardedStream(socket, channel))
                    } catch (e: Exception) {
                        rejected += 1
                        lastFailure = e.message
                        socket.close()
                    }
            }
        }
        return progressed
    }

    private func pumpStreams(): Bool {
        var progressed = false
        let done = ArrayList<ForwardedStream>()
        for (s in streams) {
            if (s.pump()) {
                progressed = true
            }
            if (s.isFinished()) {
                done.add(s)
            }
        }
        for (s in done) {
            s.close()
            streams.removeIf({x => refEq(x, s)})
        }
        return progressed
    }

    private func waitForActivity(waitMs: Int64): Unit {
        let fds = ArrayList<Int32>()
        let events = ArrayList<Int16>()
        fds.add(listener.fd)
        events.add(POLLIN)
        fds.add(session.socket.fd)
        events.add(sessionPollEvents(session))
        for (s in streams) {
            let e = s.pollEvents()
            if (e != 0) {
                fds.add(s.socketFd)
                events.add(e)
            }
        }
        let capped = if (waitMs > 2147483647) { 2147483647 } else { waitMs }
        pollMany(fds.toArray(), events.toArray(), Int32(capped))
    }

    private func checkOpen(): Unit {
        if (closed) {
            throw CommandException("local forward on port ${listener.port} is already closed")
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        match (pumpTask) {
            case Some(f) =>
                try {
                    f.get()
                } catch (_: Exception) {
                }
            case None => ()
        }
        pumpTask = None
        listener.close()
        let snapshot = streams.toArray()
        streams.clear()
        for (s in snapshot) {
            s.close()
        }
    }
}

public class RemoteForward <: Resource {
    private let session: Session
    private let listener: RemoteListener
    private let streams = ArrayList<ForwardedStream>()
    private var closed: Bool = false
    private var pumpTask: Option<Future<Unit>> = None
    private var accepted: Int64 = 0
    private var rejected: Int64 = 0
    private var lastFailure: String = ""

    public let localHost: String
    public let localPort: UInt16
    public let localConnectTimeoutMs: Int64

    private init(session: Session, listener: RemoteListener, localHost: String, localPort: UInt16,
                 localConnectTimeoutMs: Int64) {
        this.session = session
        this.listener = listener
        this.localHost = localHost
        this.localPort = localPort
        this.localConnectTimeoutMs = localConnectTimeoutMs
    }

    public prop remotePort: UInt16 {
        get() {
            listener.boundPort
        }
    }

    public prop acceptedConnections: Int64 {
        get() {
            accepted
        }
    }

    public prop activeStreams: Int64 {
        get() {
            streams.size
        }
    }

    public prop rejectedConnections: Int64 {
        get() {
            rejected
        }
    }

    public prop lastError: String {
        get() {
            lastFailure
        }
    }

    public static func start(connection: SSHConnection, remotePort: UInt16, localHost: String,
                             localPort: UInt16): RemoteForward {
        return start(connection, "", remotePort, localHost, localPort)
    }

    public static func start(connection: SSHConnection, remoteBindHost: String, remotePort: UInt16,
                             localHost: String, localPort: UInt16): RemoteForward {
        if (localHost.isEmpty()) {
            throw ConnectionException("localHost must not be empty for a remote forward")
        }
        if (localPort == 0) {
            throw ConnectionException("localPort must not be 0 for a remote forward")
        }
        let session = connection.rawSession()
        let listener = session.listenForwarded(remoteBindHost, remotePort, FORWARD_ACCEPT_QUEUE)
        return RemoteForward(session, listener, localHost, localPort, 10000)
    }

    public func pumpOnce(waitMs: Int64): Bool {
        checkOpen()
        var progressed = acceptPending()
        if (pumpStreams()) {
            progressed = true
        }
        if (!progressed && waitMs > 0) {
            waitForActivity(waitMs)
        }
        return progressed
    }

    public func serve(durationMs: Int64): Unit {
        let deadline = MonoTime.now() + Duration.millisecond * durationMs
        while (!closed && MonoTime.now() < deadline) {
            pumpOnce(FORWARD_POLL_SLICE_MS)
        }
    }

    public func startBackgroundPump(): Unit {
        checkOpen()
        if (pumpTask.isSome()) {
            return
        }
        pumpTask = spawn {
            backgroundLoop()
        }
    }

    private func backgroundLoop(): Unit {
        while (!closed) {
            try {
                pumpOnce(FORWARD_POLL_SLICE_MS)
            } catch (_: Exception) {
                break
            }
        }
    }

    private func acceptPending(): Bool {
        var progressed = false
        while (true) {
            match (listener.acceptNonBlocking()) {
                case None => break
                case Some(channel) =>
                    progressed = true
                    accepted += 1
                    try {
                        let socket = TcpTransport.connect(localHost, localPort,
                                                          localConnectTimeoutMs)
                        streams.add(ForwardedStream(socket, channel))
                    } catch (e: Exception) {
                        rejected += 1
                        lastFailure = e.message
                        try {
                            channel.close()
                        } catch (_: Exception) {
                        }
                    }
            }
        }
        return progressed
    }

    private func pumpStreams(): Bool {
        var progressed = false
        let done = ArrayList<ForwardedStream>()
        for (s in streams) {
            if (s.pump()) {
                progressed = true
            }
            if (s.isFinished()) {
                done.add(s)
            }
        }
        for (s in done) {
            s.close()
            streams.removeIf({x => refEq(x, s)})
        }
        return progressed
    }

    private func waitForActivity(waitMs: Int64): Unit {
        let fds = ArrayList<Int32>()
        let events = ArrayList<Int16>()
        fds.add(session.socket.fd)
        events.add(sessionPollEvents(session))
        for (s in streams) {
            let e = s.pollEvents()
            if (e != 0) {
                fds.add(s.socketFd)
                events.add(e)
            }
        }
        let capped = if (waitMs > 2147483647) { 2147483647 } else { waitMs }
        pollMany(fds.toArray(), events.toArray(), Int32(capped))
    }

    private func checkOpen(): Unit {
        if (closed) {
            throw CommandException("remote forward on port ${listener.boundPort} is already closed")
        }
    }

    public func isClosed(): Bool {
        return closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        match (pumpTask) {
            case Some(f) =>
                try {
                    f.get()
                } catch (_: Exception) {
                }
            case None => ()
        }
        pumpTask = None
        let snapshot = streams.toArray()
        streams.clear()
        for (s in snapshot) {
            s.close()
        }
        listener.close()
    }
}
