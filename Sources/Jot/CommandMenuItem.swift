import AppKit

final class CommandMenuItem: NSMenuItem {
    private let command: Command
    private let perform: (Command) -> Void

    /// `perform` is the controller's, so a menu pick reloads an outside edit and re-checks
    /// `disabledReason()` like every other entry point.
    init(_ command: Command, perform: @escaping (Command) -> Void) {
        self.command = command
        self.perform = perform
        let key = command.keys.first
        super.init(title: command.title, action: #selector(fire), keyEquivalent: key?.menuEquivalent ?? "")
        target = self
        keyEquivalentModifierMask = key?.modifiers ?? []
        let reason = command.disabledReason()
        isEnabled = reason == nil
        toolTip = reason
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func fire() { perform(command) }
}
