//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Copyright © 2020 Oliver Peate. All rights reserved.
//

import Cocoa
import IOBluetooth
import LaunchAtLogin

let statusChecksInterval: TimeInterval = 3

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var statusChecksTimer: Timer?
    private var preferedState = true

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initStatusItem()
        setLaunchAtLoginState()
        setupNotificationHandlers()
        setBluetooth(powerOn: preferedState)
        checkIfIsInClamshellMode()
    }

    // MARK: Click handlers

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        setLaunchAtLoginState()
    }

    @IBAction func hideIconClicked(_ sender: NSMenuItem) {
        UserDefaults.standard.set(true, forKey: "hideIcon")
        statusItem.statusBar?.removeStatusItem(statusItem)
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: Notification handlers

    func setupNotificationHandlers() {
        [
            NSWorkspace.willSleepNotification: #selector(onPowerDown(note:)),
            NSWorkspace.willPowerOffNotification: #selector(onPowerDown(note:)),
            NSWorkspace.didWakeNotification: #selector(onPowerUp(note:))
        ].forEach { notification, sel in
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: sel, name: notification, object: nil)
        }
    }

    @objc func onPowerDown(note: NSNotification) {
        setBluetooth(powerOn: false)
    }

    @objc func onPowerUp(note: NSNotification) {
        setBluetooth(powerOn: true)
    }

    private func checkIfIsInClamshellMode() {
        statusChecksTimer = Timer.scheduledTimer(
            withTimeInterval: statusChecksInterval,
            repeats: true,
            block: { [weak self] _ in
                guard let self = self else { return }

                let isNotInClamshellMode = !self.isInClamshellMode()
                if self.preferedState != isNotInClamshellMode {
                    self.setBluetooth(powerOn: isNotInClamshellMode)
                }
            })
    }

    private func setBluetooth(powerOn: Bool) {
        preferedState = powerOn
        IOBluetoothPreferenceSetControllerPowerState(powerOn ? 1 : 0)
    }

    // MARK: UI state

    private func initStatusItem() {
        if UserDefaults.standard.bool(forKey: "hideIcon") {
            return
        }

        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Bluesnooze"
        }
        statusItem.menu = statusMenu
    }

    private func setLaunchAtLoginState() {
        let state = LaunchAtLogin.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
        launchAtLoginMenuItem.state = state
    }

    func isInClamshellMode() -> Bool {
        let pipe = Pipe()
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState  | head -1"]
        process.standardOutput = pipe
        let fileHandle = pipe.fileHandleForReading
        process.launch()

        return String(data: fileHandle.readDataToEndOfFile(), encoding: .utf8)?.contains("Yes") == true
    }
}
