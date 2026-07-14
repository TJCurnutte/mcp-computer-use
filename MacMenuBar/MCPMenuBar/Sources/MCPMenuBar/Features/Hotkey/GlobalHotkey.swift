import Carbon
import AppKit
import Foundation

/// A global/local hotkey that triggers a closure.
///
/// It tries the best available mechanism in order:
/// 1. `Carbon` `RegisterEventHotKey` — a true global shortcut, no permission required.
/// 2. `NSEvent.addGlobalMonitorForEventsMatchingMask` — observes key events in other apps.
/// 3. `NSEvent.addLocalMonitorForEventsMatchingMask` — works only while the app is active.
final class GlobalHotkey {

    /// Which fallback to use when the Carbon registration does not work.
    enum FallbackMode {
        /// Try the `NSEvent` global monitor (requires Accessibility and Input Monitoring).
        case global
        /// Use only a local event monitor (active app only).
        case local
    }

    /// The registration outcome after `start()`.
    enum RegistrationMode {
        case none
        case carbon
        case globalMonitor
        case localMonitor
    }

    var action: (() -> Void)?

    private(set) var currentMode: RegistrationMode = .none

    var isRunning: Bool { currentMode != .none }
    var isGlobal: Bool { currentMode == .carbon || currentMode == .globalMonitor }

    private let keyCode: UInt32
    private let modifiers: NSEvent.ModifierFlags
    private let carbonModifiers: UInt32
    private let fallbackMode: FallbackMode
    private let instanceID: UInt32

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private static var nextID: UInt32 = 1
    private static let signature: OSType = makeOSType("MCPH")

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, fallbackMode: FallbackMode = .global, action: (() -> Void)? = nil) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask)
        self.carbonModifiers = GlobalHotkey.carbonModifiers(from: self.modifiers)
        self.fallbackMode = fallbackMode
        self.action = action
        self.instanceID = GlobalHotkey.nextID
        GlobalHotkey.nextID += 1
    }

    convenience init(key: UInt16, modifiers: NSEvent.ModifierFlags, fallbackMode: FallbackMode = .global, action: (() -> Void)? = nil) {
        self.init(keyCode: key, modifiers: modifiers, fallbackMode: fallbackMode, action: action)
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        if registerCarbon() {
            currentMode = .carbon
            return true
        }

        if fallbackMode == .global, registerGlobalMonitor() {
            // Global monitor does not observe this app's own events, so add a local one too.
            _ = registerLocalMonitor()
            currentMode = .globalMonitor
            return true
        }

        if registerLocalMonitor() {
            currentMode = .localMonitor
            return true
        }

        currentMode = .none
        return false
    }

    func stop() {
        unregisterCarbon()
        unregisterMonitors()
        currentMode = .none
    }

    // MARK: - Carbon

    private func registerCarbon() -> Bool {
        var handlerRef: EventHandlerRef?

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            mcpHotKeyEventHandler,
            1,
            &eventSpec,
            userData,
            &handlerRef
        )

        guard handlerStatus == noErr else {
            Logger.shared.log("Hotkey: failed to install Carbon event handler (status \(handlerStatus))")
            return false
        }

        eventHandlerRef = handlerRef

        let hotKeyID = EventHotKeyID(signature: GlobalHotkey.signature, id: instanceID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, ref != nil else {
            Logger.shared.log("Hotkey: failed to register Carbon hotkey (status \(status))")
            RemoveEventHandler(eventHandlerRef)
            eventHandlerRef = nil
            return false
        }

        hotKeyRef = ref
        return true
    }

    private func unregisterCarbon() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    // MARK: - NSEvent

    private func registerGlobalMonitor() -> Bool {
        let mask: NSEvent.EventTypeMask = .keyDown
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self = self, self.matches(event) else { return }
            self.fire()
        }
        return globalMonitor != nil
    }

    private func registerLocalMonitor() -> Bool {
        let mask: NSEvent.EventTypeMask = .keyDown
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self = self, self.matches(event) else { return event }
            self.fire()
            return nil
        }
        return localMonitor != nil
    }

    private func unregisterMonitors() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    // MARK: - Matching

    private func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == UInt16(keyCode) else { return false }
        return event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers
    }

    private func fire() {
        DispatchQueue.main.async { [weak self] in
            self?.action?()
        }
    }

    // MARK: - Helpers

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option)  { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift)   { result |= UInt32(shiftKey) }
        if flags.contains(.capsLock){ result |= UInt32(alphaLock) }
        return result
    }

    private static func makeOSType(_ string: String) -> OSType {
        var result: FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }

    // MARK: - Carbon callback

    fileprivate func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let error = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard error == noErr,
              hotKeyID.signature == GlobalHotkey.signature,
              hotKeyID.id == instanceID
        else {
            return OSStatus(eventNotHandledErr)
        }

        fire()
        return noErr
    }
}

private func mcpHotKeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else {
        return OSStatus(eventNotHandledErr)
    }
    let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
    return hotkey.handleCarbonEvent(event)
}
