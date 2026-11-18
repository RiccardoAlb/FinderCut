import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let engine = CutEngine()
    private var retryTimer: Timer?
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let hideItem = NSMenuItem(title: "Hide cut files", action: #selector(toggleHide), keyEquivalent: "")
    private let restoreItem = NSMenuItem(title: "Show hidden files again", action: #selector(restoreHidden), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)
        hideItem.target = self
        menu.addItem(hideItem)
        restoreItem.target = self
        menu.addItem(restoreItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FinderCut", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        menu.delegate = self

        #if LOCAL_DIAGNOSTICS
        installLocalDiagnostics(on: engine) // defined in the git-ignored LocalDiagnostics.swift
        #endif
        engine.onPendingChange = { [weak self] _ in self?.refresh() }
        startEngine()
    }

    private func startEngine() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts), engine.start() {
            retryTimer?.invalidate()
            refresh()
        } else {
            refresh()
            // Wait for the user to grant Accessibility permission.
            retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                guard let self, AXIsProcessTrusted(), self.engine.start() else { return }
                self.retryTimer?.invalidate()
                self.refresh()
            }
        }
    }

    private func refresh() {
        let symbol = engine.pendingCount > 0 ? "scissors.circle.fill" : "scissors"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "FinderCut")
        if !AXIsProcessTrusted() {
            statusLine.title = "⚠️ Grant Accessibility permission"
        } else if engine.pendingCount > 0 {
            statusLine.title = "✂️ \(engine.pendingCount) item(s) ready to move"
        } else {
            statusLine.title = "Ready — ⌘X in Finder, then ⌘V"
        }
        enabledItem.state = engine.isEnabled ? .on : .off
        hideItem.state = engine.hideCutItems ? .on : .off
        restoreItem.isHidden = engine.hiddenCount == 0
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleEnabled() {
        engine.isEnabled.toggle()
        refresh()
    }

    @objc private func toggleHide() {
        engine.hideCutItems.toggle()
        refresh()
    }

    @objc private func restoreHidden() {
        engine.restoreHidden()
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.restoreHidden()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("FinderCut: login item error: \(error)")
        }
        refresh()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { refresh() }
}
