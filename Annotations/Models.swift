import Foundation
import SwiftData
import PencilKit

struct BandLayout: Codable {
    var manual: Double?
}

@Model
final class Notebook {
    var id: UUID = UUID()
    var title: String = "Personal"
    var colorHex: String = "#2E7D6B"
    var createdAt: Date = Date()
    var lastOpenedPage: Int = 1
    var viewPreset: Data? = nil
    @Relationship(deleteRule: .cascade, inverse: \Annotation.notebook)
    var annotations: [Annotation]? = []

    init() {}
}

@Model
final class Annotation {
    var id: UUID = UUID()
    var notebook: Notebook?
    var kind: String = "interlinear"
    var schemaVersion: Int = 1
    var page: Int = 1
    var line: Int? = nil
    var ayahStart: String? = nil
    var ayahEnd: String? = nil
    var wordStart: Int? = nil
    var wordEnd: Int? = nil
    var drawing: Data? = nil
    var text: Data? = nil
    var extra: Data? = nil
    var recognizedText: String? = nil
    var layout: Data? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}
}

enum Notes {
    static let rulePitch: CGFloat = 28

    static func layout(of data: Data?) -> BandLayout {
        guard let data, let decoded = try? JSONDecoder().decode(BandLayout.self, from: data) else { return BandLayout(manual: nil) }
        return decoded
    }

    static func encoded(_ layout: BandLayout) -> Data? {
        try? JSONEncoder().encode(layout)
    }

    static func bandHeight(pitch: CGFloat, drawing: Data?, manual: Double?) -> CGFloat {
        let minimum = pitch * 0.6
        let content = inkHeight(drawing)
        return max(minimum, content, CGFloat(manual ?? 0))
    }

    static func inkHeight(_ data: Data?) -> CGFloat {
        guard let data, let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty else { return 0 }
        return drawing.bounds.height + 16
    }

    static func hasInk(_ data: Data?) -> Bool {
        guard let data, let drawing = try? PKDrawing(data: data) else { return false }
        return !drawing.strokes.isEmpty
    }

    static func sampleDrawing() -> Data {
        let start = PKStrokePoint(location: CGPoint(x: 28, y: 18), timeOffset: 0, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: 1)
        let end = PKStrokePoint(location: CGPoint(x: 220, y: 78), timeOffset: 0.3, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: 1)
        let path = PKStrokePath(controlPoints: [start, end], creationDate: Date())
        let ink = PKInk(.pen, color: UIColor(red: 0.12, green: 0.36, blue: 0.31, alpha: 1))
        var drawing = PKDrawing()
        drawing.strokes = [PKStroke(ink: ink, path: path)]
        return drawing.dataRepresentation()
    }
}
