import AppKit
import JotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: JotController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        controller = JotController(store: NoteStore(folder: documents.appendingPathComponent("jot")))
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.flush()
    }
}
