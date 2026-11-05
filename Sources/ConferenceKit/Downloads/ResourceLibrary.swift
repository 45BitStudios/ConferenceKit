import Foundation
import Observation

/// Downloads resources into the conference directory and records progress.
/// Link resources are not downloaded; the UI opens them in the browser.
@MainActor
@Observable
public final class ResourceLibrary {
    public private(set) var records: [String: ResourceDownloadRecord] = [:]
    public let directory: URL

    @ObservationIgnored private var generation: [String: Int] = [:]
    @ObservationIgnored private var handles: [String: ResourceFetchHandle] = [:]

    public init(directory: URL, resources: [ConferenceResource] = []) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for resource in resources where resource.kind != .link {
            let filename = ResourceTransfer.storedFilename(for: resource)
            let url = directory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) {
                records[resource.id] = ResourceTransfer.reduce(
                    ResourceTransfer.initial(id: resource.id),
                    .succeed(filename: filename)
                )
            }
        }
    }

    public func record(for resource: ConferenceResource) -> ResourceDownloadRecord {
        records[resource.id] ?? ResourceTransfer.initial(id: resource.id)
    }

    public func fileURL(for resource: ConferenceResource) -> URL? {
        guard case .preview(let url) = ResourceTransfer.action(
            for: resource,
            record: record(for: resource),
            directory: directory
        ) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func download(_ resource: ConferenceResource) {
        guard resource.kind != .link else { return }
        let id = resource.id
        let token = (generation[id] ?? 0) + 1
        generation[id] = token
        handles[id]?.cancel()
        let filename = ResourceTransfer.storedFilename(for: resource)
        let destination = directory.appendingPathComponent(filename)
        records[id] = ResourceTransfer.reduce(record(for: resource), .start)
        let handle = ResourceFetchHandle()
        handles[id] = handle
        let stream = handle.start(remote: resource.remoteURL, destination: destination)
        Task {
            for await event in stream {
                guard generation[id] == token else { break }
                let current = records[id] ?? ResourceTransfer.initial(id: id)
                records[id] = ResourceTransfer.reduce(current, event)
            }
        }
    }
}

final class ResourceFetchHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDownloadTask?
    private var session: URLSession?

    func cancel() {
        lock.lock()
        task?.cancel()
        session?.invalidateAndCancel()
        lock.unlock()
    }

    func start(remote: URL, destination: URL) -> AsyncStream<ResourceDownloadEvent> {
        AsyncStream { continuation in
            let delegate = ResourceFetchDelegate(destination: destination, continuation: continuation)
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: remote)
            delegate.attach(session)
            lock.lock()
            self.session = session
            self.task = task
            lock.unlock()
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.cancel()
            }
            task.resume()
        }
    }
}

private final class ResourceFetchDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let continuation: AsyncStream<ResourceDownloadEvent>.Continuation
    private let lock = NSLock()
    private var session: URLSession?
    private var finished = false

    init(destination: URL, continuation: AsyncStream<ResourceDownloadEvent>.Continuation) {
        self.destination = destination
        self.continuation = continuation
    }

    func attach(_ session: URLSession) {
        lock.lock()
        self.session = session
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let raw = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        continuation.yield(.progress(raw))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.fail("The server returned \(http.statusCode)."))
            return
        }
        do {
            let folder = destination.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.succeed(filename: destination.lastPathComponent))
        } catch {
            finish(.fail(error.localizedDescription))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                finish(nil)
            } else {
                finish(.fail(error.localizedDescription))
            }
        } else {
            finish(nil)
        }
    }

    private func finish(_ event: ResourceDownloadEvent?) {
        lock.lock()
        let session = session
        if finished {
            lock.unlock()
            return
        }
        finished = true
        self.session = nil
        lock.unlock()
        if let event { continuation.yield(event) }
        continuation.finish()
        session?.finishTasksAndInvalidate()
    }
}
