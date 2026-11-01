Read MUSHAF_PLAN.md in the repo root. It's the architecture for an iPad app: a 15-line Madani mushaf reader with layered notes (handwritten + typed) organized into notebooks. Treat it as the source of truth. If you think something in it is wrong, flag it before building around it.

Goal for this session: Build Order steps 1–2 — a faithful mushaf on screen. No notes features yet.

Existing data lives at ~/dev/arabic-proj/data (see section 2 of the plan). Inspect it before deciding anything:
- raw/qurancom/*.json — per-word page_number + line_number for the 15-line Madani layout, char_type_name ('word' / 'end'), text_uthmani. This is the layout source.
- raw/qurancom/chapters.json — surah metadata incl. bismillah_pre.
- quran.db — surah, ayah (juz, page, translation), word (gloss, translit, root, lemma), section, tafsir.
Do not modify anything in that folder. Read from it only.

Setup:
- New Xcode project: SwiftUI, iPadOS 26+, Swift 6 strict concurrency.
- Folders: App/, Mushaf/ (data + rendering), Annotations/ (empty for now), Resources/, scripts/.

Tasks:
1. Data pipeline: a script in scripts/ (Python is fine) that reads raw/qurancom + quran.db and writes Resources/mushaf.sqlite with the page / line / word / ayah_span tables from section 3 of the plan.
   - Derive surah_header and bismillah lines (line numbers with no words before a surah's first ayah).
   - Mark centered lines (pages 1–2 and other short lines).
   - Fetch code_v2 for every word (Quran.com API v4 word_fields=code_v2, or the QUL dataset) and the 604 QPC v2 page fonts. Cache raw downloads under scripts/cache/, gitignored.
   - Write scripts/SOURCES.md with every source and its license. If a license is unclear, stop and tell me.
2. Rendering: MushafPageView with up to 15 LineViews (surah header, bismillah, ayah text). Ayah lines fully justified, centered lines centered. Register QPC fonts lazily (visible page ± 1) with CTFontManager. Keep each word's frame for hit-testing. Put the renderer behind a protocol, with a fallback that uses text_uthmani + the KFGQPC Uthmanic HAFS font in case the glyph fonts aren't ready.
3. Reader: right-to-left paging over all 604 pages, surah/juz/page navigation, last page remembered. Build only the visible and adjacent pages.
4. Tests:
   - Every page has 15 lines, except pages 1–2 (8 lines).
   - Every ayah 1:1–114:6 appears exactly once, and words are in order.
   - Every page's first/last ayah matches quran.db ayah.page.
   - ayah_span.last_line is correct for ayahs that span lines and pages.
5. Visual check: screenshot pages 1, 2, 50, 300, 604 on an iPad simulator and compare them to a printed Madani mushaf.

Constraints:
- Keep the page/line/ayah/word identifiers matching the Annotation anchor fields in the plan.
- Before writing code, give me a short plan and any open questions. Then work through it, committing after each task.
