Read MUSHAF_PLAN.md and DESIGN.md in the repo root before anything else.
- MUSHAF_PLAN.md is the architecture: a 15-line Madani mushaf reader for iPad with layered notes (handwritten + typed) organized into notebooks.
- DESIGN.md is the look and feel: principles, layout, typography, colour tokens, gestures, motion, components, accessibility.
Treat both as the source of truth. The plan wins on data and architecture, and the design guide wins on anything the user sees. If something in either seems wrong or contradictory, flag it before building around it.

Goal for this session: Build Order steps 1–2. That means a faithful, beautiful mushaf on screen, built on the design foundation. No notes features yet.

Existing data lives at ~/dev/arabic-proj/data (plan §2). Inspect it before deciding anything, and read from it only; don't modify it.
- raw/qurancom/*.json: per-word page_number + line_number for the 15-line Madani layout, char_type_name ('word' / 'end'), text_uthmani. This is the layout source.
- raw/qurancom/chapters.json: surah metadata incl. bismillah_pre.
- quran.db: surah, ayah (juz, page, translation), word (gloss, translit, root, lemma), section, tafsir.

Setup:
- New Xcode project: SwiftUI, iPadOS 26+, Swift 6 strict concurrency.
- Folders: App/, Design/ (tokens + shared components), Mushaf/ (data + rendering), Annotations/ (empty for now), Resources/, scripts/.

Tasks:
1. Data pipeline: a script in scripts/ (Python is fine) that reads raw/qurancom + quran.db and writes Resources/mushaf.sqlite with the page / line / word / ayah_span tables from plan §3.
   - Derive surah_header and bismillah lines (empty line numbers before a surah's first ayah).
   - Mark centered lines (pages 1–2 and other short lines).
   - Fetch code_v2 for every word (Quran.com API v4 word_fields=code_v2, or the QUL dataset), plus the 604 QPC v2 page fonts and the surah-name font. Cache downloads in scripts/cache/ (gitignored).
   - Write scripts/SOURCES.md listing every source and its license. If a license is unclear, stop and tell me.
2. Design foundation (DESIGN.md §4–5):
   - Design/Theme.swift: all colour tokens for Paper, Sepia and Night, plus the 8 notebook hues (tint / wash / ink), exposed through an environment value. Include an "auto" theme that follows the system.
   - Typography roles from §4 as named styles. The Quran text is never sized by Dynamic Type.
   - A small preview screen showing every token in all three themes, with a contrast check (WCAG AA) for UI text.
3. Rendering (DESIGN.md §3 "page canvas", §5):
   - MushafPageView: a paper sheet on the desk background, print proportions taken from the font metrics, fixed inner margins and constant line pitch across all pages.
   - Up to 15 LineViews: a surah header in its traditional frame, a bismillah, and ayah text. Ayah lines are fully justified and centered lines are centered. Ayah markers use the ayahMarker token, and all other text uses quranInk.
   - Register QPC fonts lazily (visible page ± 1) with CTFontManager.
   - Keep each word's frame for hit-testing.
   - Put the renderer behind a protocol, with a fallback that uses text_uthmani + KFGQPC Uthmanic HAFS.
4. Reader (DESIGN.md §3 "chrome", §6, §7):
   - Right-to-left paging over all 604 pages with a plain slide (no page curl). Accept finger swipes only, never the Pencil.
   - Portrait shows one page. Landscape shows two facing pages, with the odd page on the right.
   - Chrome is hidden by default, and a finger tap toggles the top bar (surah · juz · page) and the bottom scrubber with juz ticks.
   - Surah/juz/page navigation, with the last page remembered.
   - Build only the visible and adjacent pages.
   - Respect Reduce Motion.
5. Tests:
   - Every page has 15 lines, except pages 1–2, which have 8.
   - Every ayah from 1:1 to 114:6 appears exactly once, with its words in order.
   - Every page's first/last ayah matches quran.db ayah.page.
   - ayah_span.last_line is correct for ayahs that span lines and pages.
6. Visual + design QA: screenshot pages 1, 2, 50, 300 and 604 in all three themes, in both portrait and landscape, on an iPad simulator. Compare the text against a printed Madani mushaf, and run the relevant items in DESIGN.md §12. Show me the screenshots.

Constraints:
- Keep the page/line/ayah/word identifiers matching the Annotation anchor fields in the plan.
- Follow the Do/Don't table in DESIGN.md §11 and the adab rules in §10.
- Before writing any code, give me a short plan and any open questions. Then work through it, committing after each task.
