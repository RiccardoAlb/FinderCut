import Foundation

/// Hides "cut" items by setting the filesystem hidden flag and restores them later.
/// The list of items we hid is persisted on disk, so a crash never leaves files
/// invisible forever: everything can be restored on next launch.
/// Items are tracked with bookmarks, which keep following a file after it is moved.
public final class HideManager {
    struct Entry: Codable {
        var path: String
        var bookmark: Data
    }

    private let storeURL: URL
    private var entries: [Entry] = []

    public var count: Int { entries.count }

    public init(storeURL: URL) {
        self.storeURL = storeURL
        if let data = try? Data(contentsOf: storeURL),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    public static var defaultStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FinderCut", isDirectory: true).appendingPathComponent("hidden.json")
    }

    /// Hides the given items. Items that are already hidden are left alone,
    /// so we never un-hide something the user hid on purpose.
    @discardableResult
    public func hide(_ urls: [URL]) -> Int {
        var n = 0
        for url in urls {
            guard (try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden) == false,
                  !entries.contains(where: { $0.path == url.path }),
                  let bookmark = try? url.bookmarkData() else { continue }
            if setHidden(true, url) {
                entries.append(Entry(path: url.path, bookmark: bookmark))
                n += 1
            }
        }
        save()
        return n
    }

    /// Cancel / quit / launch: make everything visible again wherever it is now.
    /// Returns how many items could not be found.
    @discardableResult
    public func restoreAll() -> Int {
        entries.removeAll { entry in
            if let url = resolve(entry) ?? existing(entry.path) {
                setHidden(false, url)
                return true
            }
            return false
        }
        save()
        return entries.count
    }

    /// After a move: un-hide items that now live somewhere else. Items still at
    /// their old path are left hidden (a slow cross-volume move may be in progress).
    /// `destinationFolder` is only asked when an item vanished from its old path
    /// and its bookmark can't follow it (cross-volume moves).
    @discardableResult
    public func restoreAfterMove(destinationFolder: () -> URL?) -> Int {
        var destination: URL??
        entries.removeAll { entry in
            if let url = resolve(entry), same(url.path, entry.path) == false {
                setHidden(false, url)
                return true
            }
            guard !FileManager.default.fileExists(atPath: entry.path) else { return false }
            if destination == nil { destination = .some(destinationFolder()) }
            if let folder = destination ?? nil {
                let candidate = folder.appendingPathComponent((entry.path as NSString).lastPathComponent)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    setHidden(false, candidate)
                    return true
                }
            }
            return false
        }
        save()
        return entries.count
    }

    // MARK: - Helpers

    private func resolve(_ entry: Entry) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: entry.bookmark,
                        options: [.withoutUI, .withoutMounting],
                        relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private func existing(_ path: String) -> URL? {
        FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }

    private func same(_ a: String, _ b: String) -> Bool {
        URL(fileURLWithPath: a).resolvingSymlinksInPath().path == URL(fileURLWithPath: b).resolvingSymlinksInPath().path
    }

    @discardableResult
    private func setHidden(_ hidden: Bool, _ url: URL) -> Bool {
        var u = url
        var values = URLResourceValues()
        values.isHidden = hidden
        do { try u.setResourceValues(values); return true } catch { return false }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("FinderCut: cannot save hidden list: \(error)")
        }
    }
}
