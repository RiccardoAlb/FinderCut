import AppKit
import ApplicationServices
import FinderCutCore

/// Intercepts ⌘X / ⌘V in Finder.
///
/// ⌘X  → performs a normal ⌘C (copy), remembers the pasteboard state and
///        (optionally) hides the cut items.
/// ⌘V  → if the pasteboard is still the one we remembered, sends ⌥⌘V
///        ("Move Item Here") instead, otherwise lets ⌘V through untouched.
final class CutEngine {
    var isEnabled = true
    var onPendingChange: ((Int) -> Void)?
    var pendingCount: Int { state.pendingItems }
    var hiddenCount: Int { hider.count }

    /// Hide cut files until they are pasted or the cut is cancelled.
    var hideCutItems: Bool = UserDefaults.standard.bool(forKey: "hideCutItems") {
        didSet {
            UserDefaults.standard.set(hideCutItems, forKey: "hideCutItems")
            if !hideCutItems { restoreHidden() }
        }
    }

    /// Optional hook for debugging; unused unless something installs it.
    var diagnostics: ((String) -> Void)?

    private var tap: CFMachPort?
    private var state = CutState()
    private let hider = HideManager(storeURL: HideManager.defaultStoreURL)
    private var swallowedKeyCodes = Set<Int64>()
    private var watchTimer: Timer?

    private let marker: Int64 = 0x46_43_55_54 // "FCUT"
    private enum Key { static let c: CGKeyCode = 8, v: CGKeyCode = 9 }

    init() {
        // A previous run may have crashed while files were hidden.
        hider.restoreAll()
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let engine = Unmanaged<CutEngine>.fromOpaque(refcon!).takeUnretainedValue()
            return engine.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            diagnostics?("event tap creation failed (trusted=\(AXIsProcessTrusted()))")
            return false
        }
        diagnostics?("event tap started (trusted=\(AXIsProcessTrusted()))")
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // If something else is copied while a cut is pending, the cut is cancelled.
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let pending = self.state.pendingChangeCount,
                  NSPasteboard.general.changeCount != pending else { return }
            self.cancelCut()
        }
        return true
    }

    /// Un-hide everything we hid (cancel, quit, manual restore, toggle off).
    func restoreHidden() {
        hider.restoreAll()
        onPendingChange?(state.pendingItems)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let pass = Unmanaged.passUnretained(event)
        guard isEnabled, event.getIntegerValueField(.eventSourceUserData) != marker else { return pass }

        let code = event.getIntegerValueField(.keyboardEventKeycode)

        // Swallow the matching key-up of a key-down we swallowed.
        if type == .keyUp {
            return swallowedKeyCodes.remove(code) != nil ? nil : pass
        }

        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let textFocused = isTextEditingFocused()
        let action = state.action(
            keyCode: code,
            flags: event.flags,
            frontmostBundleID: front,
            textEditingFocused: textFocused,
            pasteboardChangeCount: NSPasteboard.general.changeCount)
        if event.flags.contains(.maskCommand), code == KeyCode.x || code == KeyCode.v {
            diagnostics?("cmd key=\(code) flags=\(event.flags.rawValue) front=\(front ?? "nil") text=\(textFocused) -> \(action)")
        }

        switch action {
        case .passThrough:
            return pass
        case .cut:
            swallowedKeyCodes.insert(code)
            DispatchQueue.main.async { self.cut() }
            return nil
        case .move:
            swallowedKeyCodes.insert(code)
            DispatchQueue.main.async { self.moveHere() }
            return nil
        }
    }

    // MARK: - Actions

    private func cut() {
        // A new cut replaces the previous one: show the old items again.
        if hider.count > 0 { hider.restoreAll() }
        let before = NSPasteboard.general.changeCount
        post(key: Key.c, flags: .maskCommand)
        // Give Finder a moment to write to the pasteboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let pb = NSPasteboard.general
            let urls = pb.readObjects(forClasses: [NSURL.self],
                                      options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            if self.state.recordCut(changeCountBefore: before, changeCountAfter: pb.changeCount, fileCount: urls.count) {
                if self.hideCutItems { self.hider.hide(urls) }
                self.onPendingChange?(urls.count)
            }
        }
    }

    private func cancelCut() {
        state.clear()
        hider.restoreAll()
        onPendingChange?(0)
    }

    private func moveHere() {
        post(key: Key.v, flags: [.maskCommand, .maskAlternate])
        state.clear()
        onPendingChange?(0)
        guard hider.count > 0 else { return }
        // Wait for Finder to finish moving, then show the items at their new place.
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            attempts += 1
            let left = self.hider.restoreAfterMove(destinationFolder: { Self.frontFinderFolder() })
            if left == 0 || attempts >= 120 {
                timer.invalidate()
                self.onPendingChange?(0)
            }
        }
    }

    private func post(key: CGKeyCode, flags: CGEventFlags) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: marker)
            e.post(tap: .cgSessionEventTap)
        }
    }

    /// Folder shown in the front Finder window (Desktop if there is none).
    /// Only used as a fallback for cross-volume moves; asks for Automation permission.
    private static func frontFinderFolder() -> URL? {
        let script = NSAppleScript(source: """
            tell application "Finder" to POSIX path of (target of front Finder window as alias)
            """)
        var error: NSDictionary?
        if let path = script?.executeAndReturnError(&error).stringValue, error == nil {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    /// True when a text field is focused (e.g. renaming a file, search box),
    /// so the normal ⌘X / ⌘V text behaviour is preserved.
    private func isTextEditingFocused() -> Bool {
        let system = AXUIElementCreateSystemWide()
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
              let el = ref else { return false }
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el as! AXUIElement, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField"].contains(role)
    }
}
