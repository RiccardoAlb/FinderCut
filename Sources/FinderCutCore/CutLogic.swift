import CoreGraphics

public enum KeyCode {
    public static let x: Int64 = 7
    public static let v: Int64 = 9
}

public enum CutAction: Equatable {
    case passThrough
    case cut      // swallow ⌘X, perform ⌘C, remember it
    case move     // swallow ⌘V, perform ⌥⌘V
}

/// Pure decision logic, independent from the event tap so it can be unit tested.
public struct CutState {
    public static let finderID = "com.apple.finder"

    public private(set) var pendingChangeCount: Int?
    public private(set) var pendingItems = 0

    public init() {}

    public func action(keyCode: Int64,
                       flags: CGEventFlags,
                       frontmostBundleID: String?,
                       textEditingFocused: Bool,
                       pasteboardChangeCount: Int) -> CutAction {
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        guard flags.intersection(relevant) == .maskCommand,
              frontmostBundleID == Self.finderID,
              !textEditingFocused else { return .passThrough }

        switch keyCode {
        case KeyCode.x:
            return .cut
        case KeyCode.v:
            return pendingChangeCount == pasteboardChangeCount && pendingChangeCount != nil ? .move : .passThrough
        default:
            return .passThrough
        }
    }

    /// Call after the synthetic ⌘C. Only records a cut if the pasteboard
    /// actually changed and contains at least one file.
    @discardableResult
    public mutating func recordCut(changeCountBefore: Int, changeCountAfter: Int, fileCount: Int) -> Bool {
        guard changeCountAfter != changeCountBefore, fileCount > 0 else { return false }
        pendingChangeCount = changeCountAfter
        pendingItems = fileCount
        return true
    }

    public mutating func clear() {
        pendingChangeCount = nil
        pendingItems = 0
    }
}
