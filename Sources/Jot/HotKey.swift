import Carbon.HIToolbox
import JotCore

/// One system-wide hotkey via Carbon `RegisterEventHotKey`: it fires whatever app is frontmost
/// and whatever is selected, which is what the toggle needs.
final class HotKey {
    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().onPress?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    /// false when macOS refuses the combination.
    @discardableResult
    func register(_ spec: HotKeySpec) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4A4F_5421), id: 1) // 'JOT!'
        return RegisterEventHotKey(spec.keyCode, spec.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
