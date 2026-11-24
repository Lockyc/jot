import AppKit
import JotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: JotController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        controller = JotController(store: NoteStore(folder: documents.appendingPathComponent("jot")))
        // `--background`: the launch takes no focus and puts no window up (`just run`, `just install`).
        controller.start(showing: !CommandLine.arguments.contains("--background"))
    }

    /// Quits only once the notes are on disk: a failed save keeps jot running with the panel up
    /// and the banner saying why, since the edits exist nowhere else.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if controller.saveForQuit() { return .terminateNow }
        controller.show()
        return .terminateCancel
    }
}
