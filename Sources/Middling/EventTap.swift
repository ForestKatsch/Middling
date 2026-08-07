import Cocoa

/// Intercepts left mouse events while Fn is held and rewrites them into
/// middle-button (button 2) events.
final class EventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// True from a converted mouse-down until the matching mouse-up, so the
    /// whole drag stays middle-button even if Fn is released mid-drag.
    private var remappingDrag = false

    var isEnabled = true

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let tap = Unmanaged<EventTap>.fromOpaque(refcon!).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
        remappingDrag = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables taps that stall; re-arm and pass through.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .leftMouseDown:
            if isEnabled && event.flags.contains(.maskSecondaryFn) {
                remappingDrag = true
                return convert(event, to: .otherMouseDown)
            }

        case .leftMouseDragged:
            if remappingDrag {
                return convert(event, to: .otherMouseDragged)
            }

        case .leftMouseUp:
            if remappingDrag {
                remappingDrag = false
                return convert(event, to: .otherMouseUp)
            }

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func convert(_ event: CGEvent, to type: CGEventType) -> Unmanaged<CGEvent> {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        // Strip Fn so apps see a plain MMB drag; Shift/Ctrl/etc. pass through.
        event.flags.remove(.maskSecondaryFn)
        return Unmanaged.passUnretained(event)
    }
}
