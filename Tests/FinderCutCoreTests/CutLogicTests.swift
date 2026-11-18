import XCTest
import CoreGraphics
@testable import FinderCutCore

final class CutLogicTests: XCTestCase {
    private let finder = CutState.finderID

    private func act(_ s: CutState, key: Int64, flags: CGEventFlags = .maskCommand,
                     app: String? = "com.apple.finder", text: Bool = false, pb: Int = 1) -> CutAction {
        s.action(keyCode: key, flags: flags, frontmostBundleID: app,
                 textEditingFocused: text, pasteboardChangeCount: pb)
    }

    func testCommandXInFinderCuts() {
        XCTAssertEqual(act(CutState(), key: KeyCode.x), .cut)
    }

    func testCommandXOutsideFinderPassesThrough() {
        XCTAssertEqual(act(CutState(), key: KeyCode.x, app: "com.apple.TextEdit"), .passThrough)
        XCTAssertEqual(act(CutState(), key: KeyCode.x, app: nil), .passThrough)
    }

    func testTextEditingPassesThrough() {
        XCTAssertEqual(act(CutState(), key: KeyCode.x, text: true), .passThrough)
        var s = CutState(); s.recordCut(changeCountBefore: 1, changeCountAfter: 2, fileCount: 1)
        XCTAssertEqual(act(s, key: KeyCode.v, text: true, pb: 2), .passThrough)
    }

    func testExtraModifiersPassThrough() {
        for flags: CGEventFlags in [[.maskCommand, .maskShift], [.maskCommand, .maskAlternate],
                                    [.maskCommand, .maskControl], [], .maskShift] {
            XCTAssertEqual(act(CutState(), key: KeyCode.x, flags: flags), .passThrough)
        }
    }

    func testOtherKeysPassThrough() {
        XCTAssertEqual(act(CutState(), key: 8), .passThrough) // ⌘C
    }

    func testPasteWithoutCutPassesThrough() {
        XCTAssertEqual(act(CutState(), key: KeyCode.v), .passThrough)
    }

    func testPasteAfterCutMoves() {
        var s = CutState()
        XCTAssertTrue(s.recordCut(changeCountBefore: 5, changeCountAfter: 6, fileCount: 3))
        XCTAssertEqual(s.pendingItems, 3)
        XCTAssertEqual(act(s, key: KeyCode.v, pb: 6), .move)
    }

    func testPasteAfterUnrelatedCopyPassesThrough() {
        var s = CutState()
        s.recordCut(changeCountBefore: 5, changeCountAfter: 6, fileCount: 1)
        XCTAssertEqual(act(s, key: KeyCode.v, pb: 7), .passThrough)
    }

    func testCutWithNoSelectionIsNotRecorded() {
        var s = CutState()
        XCTAssertFalse(s.recordCut(changeCountBefore: 5, changeCountAfter: 5, fileCount: 0))
        XCTAssertFalse(s.recordCut(changeCountBefore: 5, changeCountAfter: 6, fileCount: 0))
        XCTAssertNil(s.pendingChangeCount)
    }

    func testClearAfterMove() {
        var s = CutState()
        s.recordCut(changeCountBefore: 1, changeCountAfter: 2, fileCount: 2)
        s.clear()
        XCTAssertEqual(s.pendingItems, 0)
        XCTAssertEqual(act(s, key: KeyCode.v, pb: 2), .passThrough)
    }
}

final class HideManagerTests: XCTestCase {
    private var dir: URL!
    private var store: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("fc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = dir.appendingPathComponent("store/hidden.json")
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func makeFile(_ name: String) throws -> URL {
        let u = dir.appendingPathComponent(name)
        try "x".write(to: u, atomically: true, encoding: .utf8)
        return u
    }
    private func isHidden(_ u: URL) -> Bool {
        // URL caches resource values, so always read through a fresh URL.
        (try? URL(fileURLWithPath: u.path).resourceValues(forKeys: [.isHiddenKey]).isHidden) ?? false
    }

    func testHideAndRestore() throws {
        let f = try makeFile("a.txt")
        let m = HideManager(storeURL: store)
        XCTAssertEqual(m.hide([f]), 1)
        XCTAssertTrue(isHidden(f))
        XCTAssertEqual(m.restoreAll(), 0)
        XCTAssertFalse(isHidden(f))
        XCTAssertEqual(m.count, 0)
    }

    func testAlreadyHiddenItemsAreNotTouched() throws {
        let f = try makeFile("b.txt")
        var u = f; var v = URLResourceValues(); v.isHidden = true; try u.setResourceValues(v)
        let m = HideManager(storeURL: store)
        XCTAssertEqual(m.hide([f]), 0)
        m.restoreAll()
        XCTAssertTrue(isHidden(f)) // user's own hidden file stays hidden
    }

    func testRestoreAfterCrashViaPersistedStore() throws {
        let f = try makeFile("c.txt")
        XCTAssertEqual(HideManager(storeURL: store).hide([f]), 1)
        XCTAssertTrue(isHidden(f))
        // "relaunch"
        let m2 = HideManager(storeURL: store)
        XCTAssertEqual(m2.count, 1)
        XCTAssertEqual(m2.restoreAll(), 0)
        XCTAssertFalse(isHidden(f))
    }

    func testRestoreAfterMoveFollowsFile() throws {
        let f = try makeFile("d.txt")
        let dest = dir.appendingPathComponent("dest"); try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let m = HideManager(storeURL: store)
        m.hide([f])
        // Still at old path: stays hidden.
        XCTAssertEqual(m.restoreAfterMove(destinationFolder: { nil }), 1)
        XCTAssertTrue(isHidden(f))
        let moved = dest.appendingPathComponent("d.txt")
        try FileManager.default.moveItem(at: f, to: moved)
        XCTAssertEqual(m.restoreAfterMove(destinationFolder: { nil }), 0)
        XCTAssertFalse(isHidden(moved))
    }

    func testDestinationFolderFallback() throws {
        let f = try makeFile("e.txt")
        let dest = dir.appendingPathComponent("dest2"); try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let m = HideManager(storeURL: store)
        m.hide([f])
        // Simulate cross-volume: old file gone, a new copy (with flag) appears in destination.
        let copy = dest.appendingPathComponent("e.txt")
        try FileManager.default.copyItem(at: f, to: copy)
        try FileManager.default.removeItem(at: f)
        XCTAssertEqual(m.restoreAfterMove(destinationFolder: { dest }), 0)
        XCTAssertFalse(isHidden(copy))
    }
}
