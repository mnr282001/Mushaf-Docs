# Mushaf Notes — Architecture Plan

iPad app (SwiftUI, iPadOS 26+) showing the 15-line Madani mushaf (604 pages, ~20 per juz) with layered notes — handwritten and typed — organized into notebooks. The page itself never changes; notes are layers on top.

**Companion doc:** `DESIGN.md` defines the look, feel, colour tokens, typography, gestures and motion. This plan covers architecture; when they touch the same thing (e.g. band height, layers), DESIGN.md wins on presentation, this plan on data.

**Scope decisions (locked):**
- Madani 15-line layout only. No IndoPak or other layouts.
- Personal use first. Notebook sharing (classmates) is a future goal — design for it, don't build it.
- Interlinear bands grow with content, plus a manual height control.
- A note anchored to an ayah that spans lines displays under the ayah's **last** line.

---

## 1. Core principles

- **The mushaf is the default.** Open the app → a clean page. Notes are layers you turn on.
- **Where a note lives ≠ how it's shown.** A note is anchored to a page, line, ayah or word range. Interlinear, sidebar and sticky are views of it.
- **Notebooks group notes.** A notebook (e.g. "Sunday class") is a collection of notes spread across any pages.
- **One writable notebook at a time.** Others can be shown read-only on the same page.
- **Note types are open-ended.** New kinds plug in via a registry without changing the core model.

---

## 2. Existing data (`~/dev/arabic-proj/data`)

Already on disk — use it instead of fetching from scratch:

| File | What it has | Use in app |
| --- | --- | --- |
| `raw/qurancom/NNN_k.json` (114 surahs, 50 verses/file) | Quran.com v4 verses with per-word `page_number` + `line_number` (Madani 15-line), `char_type_name` (`word` / `end` = ayah marker), `text_uthmani`, juz, hizb, rub, ruku, manzil, sajdah | **Page layout source.** Build the page → line → word table from this. |
| `raw/qurancom/chapters.json` | Surah names, `bismillah_pre`, `pages` range, revelation place | Surah headers, navigation |
| `quran.db` (SQLite, 39 MB) | `surah`, `ayah` (text, juz, page, ruku, translation), `word` (gloss, translit, lemma, root), `lemma`, `segment` (morphology), `section` (ruku/theme titles), `tafsir` (Ibn Kathir HTML) | Word-by-word gloss, dictionary note type, tafsir, search |
| `raw/quran-morphology.txt` | Quranic Arabic Corpus segments (root/lemma/POS) | Already imported into `quran.db.segment` |
| `raw/clear-quran.json` | Clear Quran English translation | Already in `quran.db.ayah.translation` |
| `section_titles.tsv`, `raw/ayah-themes.db` | Ruku/theme titles per ayah range | Section labels, notebook navigation |
| `raw/tafsir-169`, `raw/tafsir-91` | Raw tafsir JSON | Already in `quran.db.tafsir` |

Verified: page 1 = Al-Fatihah on lines 2–8 (line 1 = surah header); page 2 = Al-Baqarah 2:1 starting line 3 (lines 1–2 = header + bismillah). This is the 15-line Madani layout.

**Gaps:**
- **No QPC glyph codes (`code_v2`) and no page fonts.** Needed for pixel-exact printed-mushaf rendering. Fetch `code_v2` per word (Quran.com API `word_fields=code_v2` or the QUL dataset) and the 604 QPC v2 page fonts.
- **Surah header and bismillah lines aren't in the word data.** Derive them: line numbers with no words on a page, before a surah's first ayah, are header (and bismillah when `bismillah_pre`).
- License/attribution of each source must be recorded in `scripts/SOURCES.md`.

**Fallback renderer:** if QPC glyphs are delayed, render `text_uthmani` with the KFGQPC Uthmanic HAFS font, justified per line. Same line breaks, slightly different glyph shapes. Keep the renderer behind a protocol so it can be swapped.

---

## 3. Bundled data (build step)

A script in `scripts/` reads the raw data and produces one read-only `mushaf.sqlite` bundled with the app:

```sql
page(page INTEGER PRIMARY KEY, juz INTEGER, hizb INTEGER, first_ayah TEXT, last_ayah TEXT)
line(page INTEGER, line INTEGER, kind TEXT,          -- 'surah_header' | 'bismillah' | 'ayah'
     surah INTEGER, centered INTEGER,                -- centered: short last lines (e.g. p.1, p.2)
     PRIMARY KEY(page, line))
word(id INTEGER PRIMARY KEY, page INTEGER, line INTEGER, idx INTEGER,  -- idx = order within line
     surah INTEGER, ayah INTEGER, pos INTEGER,       -- pos = word position within ayah
     kind TEXT,                                      -- 'word' | 'end'
     text_uthmani TEXT, code_v2 TEXT)
ayah_span(surah INTEGER, ayah INTEGER, page INTEGER, first_line INTEGER, last_line INTEGER,
          PRIMARY KEY(surah, ayah))                  -- drives "show under last line"
```

Plus attach (or copy) the needed tables from `quran.db`: `surah`, `word` gloss/translit/root, `lemma`, `ayah.translation`, `section`, `tafsir`.

---

## 4. Mushaf rendering

- **Page** = up to 15 `LineView`s. Line kinds: surah header, bismillah, ayah text.
- **Ayah lines** fully justified to page width; `centered` lines (pages 1–2, some surah endings) centered.
- **Fonts:** QPC v2 — one font per page, registered lazily with `CTFontManagerRegisterGraphicsFont` for the visible ± 1 pages, unregistered when far away.
- **Hit-testing:** keep each word's frame → tap / Pencil long-press resolves to a `(page, line, word)` and its `(surah, ayah, pos)`.
- **Reader:** right-to-left paging. Plain mode = paged like print. Note modes reflow vertically (bands inserted between lines), so the page scrolls.
- **Navigation:** surah, juz, hizb, page number; remember last page.

---

## 5. Data model (SwiftData + CloudKit)

```swift
@Model final class Notebook {
    var id: UUID = UUID()
    var title: String = ""             // "Sunday class"
    var colorHex: String = "#2E7D6B"   // layer tint when shown read-only
    var createdAt: Date = Date()
    var lastOpenedPage: Int = 1
    var viewPreset: Data?              // enabled layers (Codable)
    @Relationship(deleteRule: .cascade, inverse: \Annotation.notebook)
    var annotations: [Annotation]? = []
}

@Model final class Annotation {
    var id: UUID = UUID()
    var notebook: Notebook?
    var kind: String = ""              // "interlinear", "sidebar", "sticky", "highlight", "dictionary"
    var schemaVersion: Int = 1
    // Anchor
    var page: Int = 1                  // 1...604 — fast per-page fetch
    var line: Int?                     // 1...15
    var ayahStart: String?             // "2:255"
    var ayahEnd: String?
    var wordStart: Int?                // position within ayah
    var wordEnd: Int?
    // Payload
    var drawing: Data?                 // PKDrawing.dataRepresentation()
    var text: Data?                    // AttributedString, encoded
    var extra: Data?                   // kind-specific Codable JSON
    var recognizedText: String?        // Vision OCR of drawing, for search
    var layout: Data?                  // band height, sticky x/y, sidebar order
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
```

- Store both page/line **and** ayah/word anchors. Page/line → fast render; ayah/word → meaning, search, export.
- CloudKit rules: everything optional/defaulted, no unique constraints, optional relationships.
- `extra` absorbs new kinds' data → no migration per new kind.
- Annotation's display line for an ayah anchor = `ayah_span.last_line` of `ayahEnd` (if the ayah ends on the next page, it shows on that page).

---

## 6. Notebooks and layers

- Session state: `activeNotebookID: UUID?`, `visibleNotebookIDs: Set<UUID>`. Active is always visible.
- Opening a notebook → set active, jump to `lastOpenedPage`. Notebook index lists every page it touches.
- Read-only layers render dimmed and tinted with their notebook colour + small label. Tapping offers "Switch to this notebook", never edits.
- New notes always go to the active notebook; none active → a default "Personal" notebook.
- Plain mode shows a subtle margin marker on pages that have notes.
- **Future sharing:** keep notebook as the unit of sharing (`CKShare` per notebook later). Don't let annotations reference anything outside their notebook.

---

## 7. Annotation kinds (registry)

```swift
enum AnchorLevel { case page, line, ayah, word }
enum Placement { case belowLine, margin, overlay, floating, popover }

protocol AnnotationKind {
    static var id: String { get }
    static var displayName: String { get }
    static var allowedAnchors: Set<AnchorLevel> { get }
    static var placement: Placement { get }
    associatedtype Payload: Codable
    @MainActor @ViewBuilder static func render(_ a: Annotation, readOnly: Bool) -> AnyView
    @MainActor @ViewBuilder static func editor(_ a: Annotation) -> AnyView
}

enum AnnotationRegistry {
    static var kinds: [String: any AnnotationKind.Type] = [:]
    static func register(_ k: any AnnotationKind.Type) { kinds[k.id] = k }
}
```

| Kind | Anchor | Placement | Payload |
| --- | --- | --- | --- |
| Interlinear | line (or ayah → last line) | below line | drawing + text, band height |
| Sidebar | ayah or line | margin column | drawing + text |
| Sticky | page (x, y) | floating | drawing + text, colour, collapsed |
| Highlight | word range | overlay | colour |
| Dictionary | word | popover | gloss/root/lemma from `quran.db` + your definition |

Unknown kinds render as a generic "unsupported note" chip, never dropped.

---

## 8. View modes

Toggleable layers stacked on the page; several at once; combination saved per notebook as a view preset.

- **Plain** — mushaf only.
- **Interlinear** — a writing band under each of the 15 lines.
  - **Grows with content:** band height = max(min height, content height) — drawing bounds + padding, or text height.
  - **Manual control:** a "+" / drag handle on each band to make it taller (extra writing room before you write); global default height slider; double-tap handle to reset to fit.
  - Height persisted per band in `layout`.
- **Sidebar** — margin column aligned to the note's line (best in landscape).
- **Sticky** — floating, draggable, collapsible notes.
- **Highlights** — overlays on the text.

Implementation: page = `ZStack` of text layer + one layer per enabled `Placement`; each layer asks the registry which kinds use it.

---

## 9. Input and search

- **Pencil:** `PKCanvasView` per visible note slot, `drawingPolicy = .pencilOnly` so fingers scroll. One shared `PKToolPicker`.
- **Keyboard:** rich text (`TextEditor` + `AttributedString`, or `UITextView` wrapper). Mixed Arabic/English, RTL-aware.
- **Toggle** pen ↔ keyboard per slot; Scribble works in text fields for free.
- **Performance:** live canvases only for visible slots; others render a cached image of the drawing.
- **Handwriting OCR:** on drawing change (debounced), render → Vision `RecognizeTextRequest` in background → `recognizedText`.
- **Search:** notes (`text`, `recognizedText`) + Quran (Arabic text, translation, gloss, root via `quran.db`); filter by notebook, surah, juz; results jump to page.

---

## 10. Storage, sync, export

- SwiftData local + CloudKit private database. Bundled Quran data is read-only, never synced.
- Last-writer-wins per annotation (`updatedAt`).
- Export a notebook as PDF (pages + its notes) or JSON backup.

---

## 11. Build order

1. **Data pipeline:** script builds `mushaf.sqlite` from `raw/qurancom` + `quran.db`; fetch `code_v2` + QPC v2 fonts; record sources/licenses.
2. **Render** one page exactly; then all 604 with RTL paging, surah/juz navigation, word hit-testing, last page remembered. Includes the design foundation: theme tokens, page-on-desk canvas, hidden chrome (DESIGN.md §3–5).
3. **SwiftData models**, default notebook, interlinear mode with PencilKit and growing bands + manual height.
4. Typed text in note slots; pen/keyboard toggle.
5. Multiple notebooks, active vs read-only layers, notebook page index.
6. Annotation registry; sidebar, sticky, highlight kinds.
7. CloudKit sync, Vision OCR, search.
8. Dictionary kind (from `quran.db` lemma/root), view presets, PDF export.
9. *(Later)* notebook sharing via `CKShare`.

---

## 12. Open questions

- [ ] Should the default interlinear band show for every line, or only lines you've written on (plus a tap to open others)?
- [ ] Tafsir and word-by-word gloss: show as read-only reference layers, or only inside the dictionary popover?
