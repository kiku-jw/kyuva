import Foundation
import Carbon

/// Manages global keyboard shortcuts
class HotkeyManager {
    
    enum Hotkey {
        case speedUp      // Shift + →
        case speedDown    // Shift + ←
        case togglePause  // Space
        case reset        // Cmd + R
        case toggleOverlay // Cmd + T
    }
    
    private var handlers: [Hotkey: () -> Void] = [:]
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    init() {
        setupEventTap()
    }
    
    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }
    
    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        handlers[hotkey] = handler
    }
    
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            print("⚠️ Failed to create event tap. Grant Accessibility permissions.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Shift + Right Arrow (speed up)
        if keyCode == 124 && flags.contains(.maskShift) {
            handlers[.speedUp]?()
            return nil // Consume event
        }
        
        // Shift + Left Arrow (speed down)
        if keyCode == 123 && flags.contains(.maskShift) {
            handlers[.speedDown]?()
            return nil
        }
        
        // Control + Space (toggle pause) - 49
        if keyCode == 49 && flags.contains(.maskControl) {
            handlers[.togglePause]?()
            return nil // Consume only when modifier is present
        }
        
        // Cmd + R (reset) - 15
        if keyCode == 15 && flags.contains(.maskCommand) {
            handlers[.reset]?()
            return nil
        }
        
        // Cmd + Option + T (toggle overlay) - 17
        if keyCode == 17 && flags.contains(.maskCommand) && flags.contains(.maskAlternate) {
            handlers[.toggleOverlay]?()
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
}
