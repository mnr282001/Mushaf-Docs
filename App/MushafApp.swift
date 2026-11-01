import SwiftData
import SwiftUI

@main
struct MushafApp: App {
    var body: some Scene {
        WindowGroup {
            ReaderView()
        }
        .modelContainer(for: [Notebook.self, Annotation.self])
    }
}
