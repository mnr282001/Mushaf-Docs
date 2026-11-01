# Mushaf Notes — Design Guide

How the app should look, feel and behave. Read this alongside `MUSHAF_PLAN.md` (architecture). When a design choice isn't covered here, choose whatever keeps the reader closest to the page.

---

## 1. The idea in one line

**A beautiful printed mushaf that opens up to make room for your thoughts, and closes back to a clean page.**

The Quran is the subject; the app is the margin. Every screen should feel like a well-bound mushaf on a quiet desk, not a productivity tool with a Quran inside it.

---

## 2. Principles

1. **The page comes first.** In plain mode, nothing but the mushaf page and the faintest frame. No toolbars, badges or chrome until you ask for them.
2. **Notes serve the text, never cover it.** Ink, text and stickies never sit on top of the Arabic. Bands open *between* lines, sidebars sit *beside* the page, and stickies are pushed off the text block or collapse to a dot. The one exception is highlights, which tint behind the words and never draw over them.
3. **Calm, with nothing hidden.** Few colours, soft motion and no gamification: no streaks, confetti or red badges. Every control can still be found with one tap on the page.
4. **Pencil-first, finger-friendly.** The Pencil writes and fingers navigate. You never have to pick a "mode" just to write.
5. **Reverence in the details.** The Arabic is never squeezed, stretched by hand, recoloured for decoration, cropped mid-word, or used as a background texture. Ayah markers and surah headers keep their traditional forms.
6. **Your notes are clearly yours.** You should always be able to tell at a glance what is Quran, what is your note, and which notebook a note belongs to.

---

## 3. Layout

### The page canvas
- The mushaf page sits on a **paper sheet** centred on a slightly darker **desk** background. The page keeps the printed proportions taken from the QPC font metrics, so don't stretch it to fill the screen.
- **Portrait:** one page, with a generous margin on the desk. **Landscape:** two facing pages (right page = odd/earlier, read right-to-left), *or* one page + sidebar when the sidebar layer is on.
- The text block keeps fixed inner margins, and line pitch is constant across all 604 pages, so the eye always lands in the same place.

### Notes mode (interlinear)
- Turning interlinear on **opens** the page: the 15 lines spread apart and each gets a writing band below it. The sheet grows taller and scrolls vertically, and horizontal paging still turns pages.
- Bands have a faint ruled baseline (like exercise-book lines) and a 1 pt tint of the active notebook's colour on the leading edge.
- **Band height** grows with your content. A small grabber at the band's bottom edge lets you drag it taller before writing. Double-tap the grabber to shrink it back to fit, and use the "+" in the band's corner to add one more ruled line.
- Empty bands collapse to a minimum height (about 0.6× line pitch) so an open page doesn't look like a blank form.
- Ayah-anchored notes show under the ayah's **last** line, with a hairline bracket in the band's leading margin spanning the ayah's lines.

### Sidebar
- A **margin column** about 280 pt wide on the page's outer edge: right of a right-hand page, left of a left-hand page. With a single page, it goes on the left.
- Each card aligns vertically with its anchor line and slides down to avoid overlapping others, with a thin leader line back to its line.

### Stickies
- Square-ish cards that float on the desk and margins. If one is dropped onto the text block it snaps to the nearest margin.
- Stickies collapse to a 12 pt coloured dot in the margin, and a tap expands them.

### Chrome
- **Top bar (hidden by default):** surah name · juz · page number, with notebook switcher and layer toggles. Tap the page (with a finger, not the Pencil) to show or hide it.
- **Bottom scrubber (with top bar):** a thin page scrubber with juz ticks; dragging previews the surah name and page.
- **Tool palette:** the system `PKToolPicker` when the Pencil is active, plus a compact pen/keyboard toggle beside the band being edited.

---

## 4. Typography

| Role | Face | Size (iPad, portrait) | Notes |
| --- | --- | --- | --- |
| Quran text | QPC v2 page font (fallback: KFGQPC Uthmanic HAFS) | set by page width, never by Dynamic Type | Never bold, italic, letter-spaced or re-coloured (except ayah markers, see colour) |
| Surah header | QPC surah-name glyph font in the traditional frame | fixed to page | Ornamental frame stays |
| Note text (English) | New York (serif) | 17 pt, line height 1.4 | Pairs with the bookish feel |
| Note text (Arabic/Urdu) | System Arabic (SF Arabic) or Noto Naskh Arabic | 19 pt | Auto RTL per paragraph |
| UI labels | SF Pro Text | 13–15 pt | Small caps for juz/hizb labels |
| Numerals in UI | SF Pro, tabular | — | Page numbers in Arabic-Indic on the page itself, Western in UI (user setting) |

UI text supports Dynamic Type, but the Quran text doesn't, because its size is set by the page layout. Accessibility zoom (section 9) covers readers who need it larger.

---

## 5. Colour

### Themes
Three page themes, chosen in settings, plus an "auto" option that follows the system.

| Token | Paper (light) | Sepia | Night |
| --- | --- | --- | --- |
| `desk` | `#ECE7DD` | `#E3D6BC` | `#0F1110` |
| `paper` | `#FBF8F1` | `#F4E9D2` | `#1A1C1B` |
| `quranInk` | `#1B1B18` | `#2A2116` | `#E6E1D6` |
| `ayahMarker` | `#1F6F5C` | `#6B4E1E` | `#7FBFA8` |
| `rule` (band lines, hairlines) | `#1B1B18` @ 8% | `#2A2116` @ 10% | `#E6E1D6` @ 10% |
| `uiInk` | `#3A3A36` | `#43382A` | `#C9C4B9` |
| `uiSecondary` | `#8A877F` | `#8F7F66` | `#7D7A73` |
| `accent` (selection, focus) | `#1F6F5C` | `#7A5A22` | `#7FBFA8` |

- Paper is never pure white and Night is never pure black, to reduce glare during long reading.
- `quranInk` stays neutral. Colour on the page belongs to notes and highlights, never to the revealed text.

### Notebook colours
Every notebook picks one of eight muted hues. Each hue has three uses: **tint** (band edge, dot), **wash** (highlight, read-only layer background) and **ink** (default pen colour in that notebook).

| Name | Tint | Wash (light) | Ink |
| --- | --- | --- | --- |
| Teal | `#2E7D6B` | `#2E7D6B` @ 14% | `#1F5C4F` |
| Indigo | `#4A5A9C` | `#4A5A9C` @ 14% | `#34407A` |
| Saffron | `#C8902E` | `#E3B04B` @ 22% | `#8A5F14` |
| Rose | `#B5566A` | `#B5566A` @ 14% | `#8A3B4C` |
| Olive | `#7A8A3A` | `#7A8A3A` @ 16% | `#56622A` |
| Slate | `#5E6B73` | `#5E6B73` @ 14% | `#3F4A50` |
| Plum | `#7D4F82` | `#7D4F82` @ 14% | `#5A375E` |
| Clay | `#A8673F` | `#A8673F` @ 14% | `#7A4A2C` |

- In Night theme, washes become 20–24% and inks lighten by about 30% (check contrast ≥ 4.5:1 on `paper`).
- Highlights use the wash *behind* glyphs only, with rounded 3 pt caps and no outline.

### Active vs read-only layers
- **Active notebook:** full-opacity ink and text, tint bar on the band edge, editable.
- **Read-only notebooks:** 55% opacity, a dotted tint bar, and a small notebook-name pill on the first visible note. Ink can't be selected, and tapping it opens "Switch to *Sunday class*".
- At most **3 notebooks** are visible at once. Beyond that the page gets noisy, so the toggle list warns you.

---

## 6. Interaction

| Gesture | Result |
| --- | --- |
| Swipe horizontally | Turn page (RTL: swipe right → next page) |
| Finger tap on page | Show/hide chrome |
| Pencil on a band / sidebar / sticky | Write immediately (no mode switch) |
| Pencil long-press on a word | Word menu: highlight · dictionary · new note on this ayah |
| Pencil double-tap (hardware) | Pen ↔ eraser (system default) |
| Squeeze (Pencil Pro) | Tool palette |
| Two-finger tap | Undo |
| Pinch on page | Zoom the whole page (notes zoom with it) |
| Drag band grabber | Resize band |
| Long-press a band | Band menu: switch to keyboard, change anchor to ayah, move to sidebar, delete |

- Writing never turns a page. Page swipes are only recognised from finger input, never the Pencil.
- Typing: tap the pen/keyboard toggle in a band (or hold the Pencil over it and use Scribble). The keyboard pushes the band up to stay visible above it.
- **Undo** covers the last 50 note edits across the current page.

---

## 7. Motion

- **Opening notes mode:** lines spread apart with a spring (`response 0.45, damping 0.85`), and bands fade in 80 ms after the lines settle. Closing reverses it. This is the signature motion of the app, so it should feel like a book's binding loosening.
- **Page turn:** a plain slide, no page-curl skeuomorphism.
- **Layer toggles:** a 150 ms cross-fade.
- **Reduce Motion:** spreading becomes an instant re-layout with a 120 ms fade.
- No looping animation, bounce or idle movement anywhere on the page.

---

## 8. Components

- **NotebookSwitcher** — a sheet listing notebooks with colour dot, title, page count and last opened. The active notebook has a check. There's a "New notebook" row at the top. Swipe actions: rename, colour, archive.
- **LayerToggles** — a popover of pills: Interlinear · Sidebar · Stickies · Highlights · Other notebooks ▸ (multi-select, max 3). Includes "Save as preset".
- **NoteBand** — ruled area, tint edge, grabber and "+" control, pen/keyboard toggle (visible only while focused).
- **SidebarCard** — 280 pt wide, `paper` background with a 0.5 pt `rule` border and 10 pt corner radius, leader line to its anchor line.
- **Sticky** — 200 × 200 pt default, notebook wash background, 8 pt radius and a faint shadow (y 2, blur 8, 12%). Collapses to a dot.
- **WordMenu** — a compact horizontal popover above the word showing the Arabic word, gloss and root (from `quran.db`), with actions below.
- **DictionaryPopover** — the word, transliteration, root, lemma and frequency, then "Other occurrences" and "My definition" (an editable band).
- **PageBadge** — a 4 pt notebook-tint dot in the outer margin at the line height of each note, shown in plain mode only. This is the quiet hint that notes exist.
- **Empty states** — one line of `uiSecondary` text, with no illustrations. Example: "No notes on this page in *Sunday class*."

Icons are SF Symbols, regular weight, at the size of the text they sit beside. Never use a Quran or mushaf glyph as a UI icon.

---

## 9. Accessibility

- VoiceOver reads each line as Arabic text with its ayah reference ("Al-Baqarah, ayah 255, line 3"), and notes are announced after their anchor line.
- All UI colours meet WCAG AA, and notebook identity is also shown by name pill and pattern (dotted vs solid edge), not by colour alone.
- **Large Quran zoom:** a setting that pins zoom at 1.25–2× with horizontal panning per line, for low-vision reading.
- Hit targets ≥ 44 pt, including band grabbers (the visual handle can be smaller than its hit area).
- Support Reduce Motion, Reduce Transparency, Increase Contrast (rules go to 20%, read-only layers to 75%).

---

## 10. Adab of the interface

- No ads, no social counters, and no notifications that interrupt reading.
- Never put Quran text in toasts, share-sheet previews, or anywhere it might be truncated mid-word.
- Exports (PDF) keep the full page with its frame, and notes go in the bands and margins as on screen.
- Don't offer a trash/delete gesture that's aimed at the Quran text itself. Delete actions always name the note ("Delete note").

---

## 11. Do / Don't

| Do | Don't |
| --- | --- |
| Open space between lines for notes | Put ink or text boxes over the Arabic |
| Use notebook tint sparingly (edge, dot, wash) | Colour whole bands or backgrounds in bright hues |
| Keep the page proportions of print | Stretch the page to fill a landscape screen |
| Hide chrome until asked | Keep permanent toolbars over the page |
| Let the Pencil write anywhere a note can live | Make users tap "Edit" before writing |
| Show other notebooks quietly | Mix read-only and editable notes at equal weight |

---

## 12. Acceptance checks (design QA)

- [ ] Plain mode on page 1, 2, 50, 300, 604: no UI visible except the page and desk.
- [ ] Notes mode open/close feels smooth at 120 Hz on an iPad Pro and has no layout jump in the Arabic.
- [ ] A long handwritten note grows its band with no clipping; the grabber adds room before writing.
- [ ] Two notebooks visible: the active one is clearly editable, the other clearly read-only, without relying on colour.
- [ ] Sticky dropped on the text block snaps to the margin.
- [ ] All three themes pass contrast checks for UI text and note ink.
- [ ] VoiceOver can navigate page → line → note.
