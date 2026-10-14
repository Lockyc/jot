import AppKit

final class CommandMenuItem: NSMenuItem {
    private let command: Command

    init(_ command: Command) {
        self.command = command
        let key = command.keys.first
        super.init(title: command.title, action: #selector(fire), keyEquivalent: key?.menuEquivalent ?? "")
        target = self
        keyEquivalentModifierMask = key?.modifiers ?? []
        let reason = command.disabledReason()
        isEnabled = reason == nil
        toolTip = reason
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func fire() { command.run() }
}
