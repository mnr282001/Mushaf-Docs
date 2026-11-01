import PencilKit
import UIKit
import Vision

@MainActor
enum InkText {
    private static var pending: [UUID: Task<Void, Never>] = [:]

    static func schedule(_ note: Annotation) {
        let id = note.id
        pending[id]?.cancel()
        let data = note.drawing ?? Data()
        pending[id] = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let drawing = (try? PKDrawing(data: data)) ?? PKDrawing()
            let text = await recognize(drawing)
            guard !Task.isCancelled, note.modelContext != nil else { return }
            let next = text.isEmpty ? nil : text
            guard note.recognizedText != next else { return }
            note.recognizedText = next
        }
    }

    static func recognize(_ drawing: PKDrawing) async -> String {
        let bounds = drawing.bounds
        guard bounds.width > 4, bounds.height > 4 else { return "" }
        let image = drawing.image(from: bounds.insetBy(dx: -16, dy: -16), scale: 2)
        return await recognize(image)
    }

    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = [Locale.Language(identifier: "en-US"), Locale.Language(identifier: "ar-SA")]
        do {
            let observations = try await request.perform(on: cg)
            return observations.map(\.transcript).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }

    static func proofImage(_ text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 160))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 160))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64),
                .foregroundColor: UIColor.black,
            ]
            text.draw(at: CGPoint(x: 24, y: 40), withAttributes: attributes)
        }
    }
}
