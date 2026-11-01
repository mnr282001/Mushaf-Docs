#!/usr/bin/env python3
"""Build Resources/mushaf.sqlite and download mushaf fonts.

Layout, code_v2, and Uthmani word text come from the live Quran.com API v4.
The on-disk raw/qurancom snapshot has scrambled line numbers on 18 pages, so it
is used only for chapters.json (names, bismillah_pre). Glosses, translation,
lemma, section, and tafsir are copied from quran.db.
"""

from __future__ import annotations

import json
import sqlite3
import struct
import time
import urllib.error
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = Path.home() / "dev/arabic-proj/data"
CHAPTERS = DATA / "raw/qurancom/chapters.json"
QURAN_DB = DATA / "quran.db"
CACHE = ROOT / "scripts/cache"
API_DIR = CACHE / "api"
FONT_DIR = ROOT / "Resources/Fonts"
DB_PATH = ROOT / "Resources/mushaf.sqlite"

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
API = "https://api.quran.com/api/v4/verses/by_page/{page}?words=true&word_fields=code_v2,text_uthmani&per_page=50"

FONTS = {
    "surah-name-v2.ttf": "https://static-cdn.tarteel.ai/qul/fonts/surah-names/v2/surah-name-v2.ttf",
    "bismillah.ttf": "https://static-cdn.tarteel.ai/qul/fonts/bismillah/bismillah.ttf",
    "UthmanicHafs1Ver18.ttf": "https://raw.githubusercontent.com/quran/quran.com-frontend-next/master/public/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.ttf",
}


def fetch(url: str, dest: Path, attempts: int = 5) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    for n in range(attempts):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as res:
                tmp.write_bytes(res.read())
            tmp.replace(dest)
            return
        except (urllib.error.URLError, TimeoutError, OSError):
            if n == attempts - 1:
                raise
            time.sleep(1.5 * (n + 1))


def download_pages() -> None:
    API_DIR.mkdir(parents=True, exist_ok=True)
    missing = [p for p in range(1, 605) if not (API_DIR / f"{p}.json").exists()]

    def one(page: int) -> int:
        dest = API_DIR / f"{page}.json"
        fetch(API.format(page=page), dest)
        payload = json.loads(dest.read_text())
        if payload.get("pagination", {}).get("next_page"):
            raise SystemExit(f"page {page} paginated; raise per_page")
        if not payload.get("verses"):
            dest.unlink(missing_ok=True)
            raise SystemExit(f"page {page} has no verses")
        return page

    with ThreadPoolExecutor(max_workers=8) as pool:
        futs = [pool.submit(one, p) for p in missing]
        done = 0
        for fut in as_completed(futs):
            fut.result()
            done += 1
            if done % 100 == 0:
                print(f"api {done}/{len(missing)}")
    print(f"api pages ready, fetched {len(missing)}")


def download_fonts() -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    jobs = dict(FONTS)
    for page in range(1, 605):
        jobs[f"p{page}.ttf"] = f"https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v2/ttf/p{page}.ttf"
    missing = [name for name in jobs if not (FONT_DIR / name).exists()]

    def one(name: str) -> None:
        dest = FONT_DIR / name
        fetch(jobs[name], dest)
        magic = dest.read_bytes()[:4]
        if magic not in (b"\x00\x01\x00\x00", b"OTTO", b"true"):
            dest.unlink(missing_ok=True)
            raise SystemExit(f"{name} is not a font")

    with ThreadPoolExecutor(max_workers=12) as pool:
        futs = [pool.submit(one, name) for name in missing]
        done = 0
        for fut in as_completed(futs):
            fut.result()
            done += 1
            if done % 100 == 0:
                print(f"fonts {done}/{len(missing)}")
    print(f"fonts ready, fetched {len(missing)}")


class Font:
    def __init__(self, path: Path):
        data = path.read_bytes()
        num_tables = struct.unpack(">H", data[4:6])[0]
        tables = {}
        off = 12
        for _ in range(num_tables):
            tag, _cs, toff, length = struct.unpack(">4sIII", data[off : off + 16])
            tables[tag] = data[toff : toff + length]
            off += 16
        self.units = struct.unpack(">H", tables[b"head"][18:20])[0]
        hhea = tables[b"hhea"]
        self.ascender, self.descender, self.line_gap = struct.unpack(">hhh", hhea[4:10])
        num_h = struct.unpack(">H", hhea[34:36])[0]
        hmtx = tables[b"hmtx"]
        self.advances = []
        for i in range(num_h):
            self.advances.append(struct.unpack(">H", hmtx[i * 4 : i * 4 + 2])[0])
        self.cmap = self._cmap(tables[b"cmap"])
        self.names = self._names(tables.get(b"name", b""))

    def advance(self, text: str) -> int | None:
        total = 0
        for ch in text:
            if ch == " ":
                continue
            gid = self.cmap.get(ord(ch))
            if gid is None:
                return None
            total += self.advances[min(gid, len(self.advances) - 1)]
        return total

    @staticmethod
    def _cmap(blob: bytes) -> dict[int, int]:
        _ver, count = struct.unpack(">HH", blob[:4])
        chosen = None
        for i in range(count):
            plat, enc, offset = struct.unpack(">HHI", blob[4 + 8 * i : 12 + 8 * i])
            fmt = struct.unpack(">H", blob[offset : offset + 2])[0]
            rank = 0
            if fmt == 12:
                rank = 3
            elif fmt == 4 and (plat, enc) in ((3, 1), (0, 3), (0, 4)):
                rank = 2
            elif fmt == 4:
                rank = 1
            if rank and (chosen is None or rank > chosen[0]):
                chosen = (rank, offset, fmt)
        if chosen is None:
            return {}
        _rank, offset, fmt = chosen
        if fmt == 12:
            return Font._cmap12(blob[offset:])
        return Font._cmap4(blob[offset:])

    @staticmethod
    def _cmap12(sub: bytes) -> dict[int, int]:
        ngroups = struct.unpack(">I", sub[12:16])[0]
        out = {}
        pos = 16
        for _ in range(ngroups):
            start, end, glyph = struct.unpack(">III", sub[pos : pos + 12])
            for cp in range(start, end + 1):
                out[cp] = glyph + (cp - start)
            pos += 12
        return out

    @staticmethod
    def _cmap4(sub: bytes) -> dict[int, int]:
        seg_count = struct.unpack(">H", sub[6:8])[0] // 2
        ends = list(struct.unpack(f">{seg_count}H", sub[14 : 14 + 2 * seg_count]))
        base = 14 + 2 * seg_count + 2
        starts = list(struct.unpack(f">{seg_count}H", sub[base : base + 2 * seg_count]))
        base += 2 * seg_count
        deltas = list(struct.unpack(f">{seg_count}h", sub[base : base + 2 * seg_count]))
        base += 2 * seg_count
        offsets = list(struct.unpack(f">{seg_count}H", sub[base : base + 2 * seg_count]))
        out = {}
        for i, (start, end) in enumerate(zip(starts, ends)):
            if start == 0xFFFF:
                continue
            for cp in range(start, end + 1):
                if offsets[i] == 0:
                    gid = (cp + deltas[i]) & 0xFFFF
                else:
                    # rangeOffset is relative to its own entry
                    pos = base + 2 * i + offsets[i] + 2 * (cp - start)
                    gid = struct.unpack(">H", sub[pos : pos + 2])[0]
                    if gid:
                        gid = (gid + deltas[i]) & 0xFFFF
                if gid:
                    out[cp] = gid
        return out

    @staticmethod
    def _names(blob: bytes) -> dict[int, str]:
        if len(blob) < 6:
            return {}
        _fmt, count, string_off = struct.unpack(">HHH", blob[:6])
        found = {}
        for i in range(count):
            rec = blob[6 + 12 * i : 18 + 12 * i]
            plat, _enc, _lang, name_id, length, offset = struct.unpack(">HHHHHH", rec)
            raw = blob[string_off + offset : string_off + offset + length]
            if plat == 3:
                text = raw.decode("utf-16-be", "replace")
            elif plat == 1:
                text = raw.decode("mac_roman", "replace")
            else:
                text = raw.decode("utf-8", "replace")
            found.setdefault(name_id, text.strip())
        return found


def load_words() -> list[dict]:
    words = []
    for page in range(1, 605):
        payload = json.loads((API_DIR / f"{page}.json").read_text())
        for verse in payload["verses"]:
            surah_s, ayah_s = verse["verse_key"].split(":")
            surah, ayah = int(surah_s), int(ayah_s)
            for word in verse["words"]:
                words.append(
                    {
                        "id": word["id"],
                        "page": word["page_number"],
                        "line": word["line_number"],
                        "surah": surah,
                        "ayah": ayah,
                        "pos": word["position"],
                        "kind": word["char_type_name"],
                        "text": word.get("text_uthmani") or "",
                        "code": word.get("code_v2") or "",
                        "juz": verse["juz_number"],
                        "hizb": verse["hizb_number"],
                    }
                )
    ids = [w["id"] for w in words]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate word ids from the API")
    missing = sum(1 for w in words if not w["code"])
    if missing:
        raise SystemExit(f"{missing} words lack code_v2")
    return words


def slots_for(page: int) -> range:
    return range(1, 9 if page <= 2 else 16)


def derive(words: list[dict], bismillah_pre: dict[int, bool]):
    occupied = defaultdict(list)
    spans = defaultdict(lambda: defaultdict(list))
    for word in words:
        occupied[(word["page"], word["line"])].append(word)
        spans[(word["surah"], word["ayah"])][word["page"]].append(word["line"])

    kind_of = {}
    for page in range(1, 605):
        for line in slots_for(page):
            if (page, line) in occupied:
                kind_of[(page, line)] = ("ayah", occupied[(page, line)][0]["surah"])
            else:
                kind_of[(page, line)] = ("empty", None)

    # Header and bismillah sit in the empty slots immediately before ayah 1.
    # A header can fall on the previous page when the surah starts at the top.
    order = [(page, line) for page in range(1, 605) for line in slots_for(page)]
    index = {slot: i for i, slot in enumerate(order)}
    starts = {}
    for word in words:
        if word["ayah"] == 1 and word["pos"] == 1:
            starts[word["surah"]] = (word["page"], word["line"])
    for surah, slot in starts.items():
        cursor = index[slot] - 1
        want = ["bismillah", "surah_header"] if bismillah_pre.get(surah, False) else ["surah_header"]
        for kind in want:
            if cursor < 0 or kind_of[order[cursor]][0] != "empty":
                raise SystemExit(f"no empty line for {kind} of surah {surah}")
            kind_of[order[cursor]] = (kind, surah)
            cursor -= 1

    lines = []
    for page, line in order:
        kind, surah = kind_of[(page, line)]
        centered = 1 if kind in ("surah_header", "bismillah") else 0
        lines.append((page, line, kind, surah, centered))
    ayah_span = []
    for (surah, ayah), pages in spans.items():
        for page, line_nums in pages.items():
            ayah_span.append((surah, ayah, page, min(line_nums), max(line_nums)))
    return lines, ayah_span


def mark_centered(lines: list[tuple], words: list[dict]) -> list[tuple]:
    by_line = defaultdict(list)
    for word in words:
        by_line[(word["page"], word["line"])].append(word)
    fonts = {}
    measured = {}
    failed = 0
    total = 0
    for (page, line), line_words in by_line.items():
        font = fonts.get(page)
        if font is None:
            font = Font(FONT_DIR / f"p{page}.ttf")
            fonts[page] = font
        width = 0
        for word in sorted(line_words, key=lambda w: (w["ayah"], w["pos"])):
            total += 1
            adv = font.advance(word["code"])
            if adv is None:
                failed += 1
                continue
            width += adv
        measured[(page, line)] = width
    if failed:
        raise SystemExit(f"{failed}/{total} glyphs missing from the page font")
    page_max = {}
    for (page, _line), width in measured.items():
        page_max[page] = max(page_max.get(page, 0), width)
    out = []
    centered_ayah = 0
    for page, line, kind, surah, centered in lines:
        if kind == "ayah":
            width = measured.get((page, line), 0)
            centered = 1 if page <= 2 or width < page_max[page] * 0.92 else 0
            centered_ayah += centered
        out.append((page, line, kind, surah, centered))
    print(f"centered ayah lines: {centered_ayah}")
    body_widths = sorted(
        width
        for (page, line), width in measured.items()
        if page > 2 and width >= page_max[page] * 0.92
    )
    body = body_widths[len(body_widths) // 2]
    opening = max(width for (page, _line), width in measured.items() if page <= 2)
    return out, fonts, body, opening


def page_rows(words: list[dict]) -> list[tuple]:
    by_page = defaultdict(list)
    for word in words:
        by_page[word["page"]].append(word)
    rows = []
    for page in range(1, 605):
        ordered = sorted(by_page[page], key=lambda w: (w["line"], w["ayah"], w["pos"]))
        first = ordered[0]
        last = ordered[-1]
        rows.append((page, first["juz"], first["hizb"], f"{first['surah']}:{first['ayah']}", f"{last['surah']}:{last['ayah']}"))
    return rows


def word_rows(words: list[dict]) -> list[tuple]:
    grouped = defaultdict(list)
    for word in words:
        grouped[(word["page"], word["line"])].append(word)
    rows = []
    for key in sorted(grouped):
        ordered = sorted(grouped[key], key=lambda w: (w["surah"], w["ayah"], w["pos"]))
        for idx, word in enumerate(ordered):
            rows.append(
                (
                    word["id"],
                    word["page"],
                    word["line"],
                    idx,
                    word["surah"],
                    word["ayah"],
                    word["pos"],
                    word["kind"],
                    word["text"],
                    word["code"],
                )
            )
    return rows


def font_license_notes(fonts: dict[int, Font]) -> str:
    sample = fonts[1]
    uth = Font(FONT_DIR / "UthmanicHafs1Ver18.ttf")
    surah = Font(FONT_DIR / "surah-name-v2.ttf")
    bism = Font(FONT_DIR / "bismillah.ttf")

    def block(title: str, font: Font, source: str) -> str:
        names = font.names
        return "\n".join(
            [
                f"## {title}",
                "",
                f"Source: {source}",
                f"Family: {names.get(1, '')}",
                f"Copyright: {names.get(0, '')}",
                f"License: {names.get(13, '')}",
                f"License URL: {names.get(14, '')}",
                "",
            ]
        )

    return "\n".join(
        [
            "# Sources",
            "",
            "Built " + datetime.now(timezone.utc).strftime("%Y-%m-%d") + ".",
            "",
            "Layout authority is the live Quran.com API, not `raw/qurancom/*.json`.",
            "That snapshot's `line_number` values scramble 18 pages (120, 121, 145, 531, 533, 564, 567, 569, 575, 583, 588, 592, 593, 595, 597, 598, 599, 600).",
            "The API returns the corrected Madani line breaks plus `code_v2`.",
            "`chapters.json` is still read for surah names and `bismillah_pre`.",
            "",
            "## Quran.com API v4",
            "",
            "Source: https://api.quran.com/api/v4/verses/by_page/{page}",
            "Fields: page_number, line_number, code_v2, text_uthmani, char_type_name, position, id, juz, hizb.",
            "The Quran text itself is not copyrighted. The API is run by Quran.Foundation.",
            "Attribution: Quran.com (https://quran.com).",
            "",
            "## Local quran.db",
            "",
            f"Source file: {QURAN_DB}",
            "Copied tables: surah, ayah (including the Clear Quran English translation), word (gloss, transliteration, root, lemma), lemma, section, tafsir.",
            "Clear Quran translation: © Dr. Mustafa Khattab. Included for this personal reader.",
            "Tafsir rows are the translations already imported into quran.db.",
            "Glosses and morphology were already imported there from the Quranic Arabic Corpus.",
            "",
            block(
                "QPC v2 page fonts",
                sample,
                "https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v2/ttf/p{n}.ttf (604 files, unmodified)",
            ),
            block(
                "KFGQPC Uthmanic Script HAFS",
                uth,
                "https://github.com/quran/quran.com-frontend-next (public/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.ttf), unmodified",
            ),
            block(
                "Surah name font v2",
                surah,
                "https://static-cdn.tarteel.ai/qul/fonts/surah-names/v2/surah-name-v2.ttf",
            ),
            block(
                "Bismillah font",
                bism,
                "https://static-cdn.tarteel.ai/qul/fonts/bismillah/bismillah.ttf",
            ),
            "Fonts are bundled unmodified. The KFGQPC agreement grants free use, copy, and distribution, and also says the font may not be reproduced. They are included under the granted use and copy rights, without modification, for this personal reader.",
            "",
        ]
    )


def write_db(pages, lines, words, spans, body_units: int, opening_units: int) -> None:
    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    con.executescript(
        """
        CREATE TABLE page(page INTEGER PRIMARY KEY, juz INTEGER, hizb INTEGER, first_ayah TEXT, last_ayah TEXT);
        CREATE TABLE line(page INTEGER, line INTEGER, kind TEXT, surah INTEGER, centered INTEGER, PRIMARY KEY(page, line));
        CREATE TABLE word(id INTEGER PRIMARY KEY, page INTEGER, line INTEGER, idx INTEGER,
                          surah INTEGER, ayah INTEGER, pos INTEGER, kind TEXT, text_uthmani TEXT, code_v2 TEXT);
        CREATE TABLE ayah_span(surah INTEGER, ayah INTEGER, page INTEGER, first_line INTEGER, last_line INTEGER,
                               PRIMARY KEY(surah, ayah, page));
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
        CREATE INDEX word_line ON word(page, line, idx);
        CREATE INDEX word_ayah ON word(surah, ayah, pos);
        """
    )
    con.executemany("INSERT INTO page VALUES (?,?,?,?,?)", pages)
    con.executemany("INSERT INTO line VALUES (?,?,?,?,?)", lines)
    con.executemany("INSERT INTO word VALUES (?,?,?,?,?,?,?,?,?,?)", words)
    con.executemany("INSERT INTO ayah_span VALUES (?,?,?,?,?)", spans)
    con.execute("ATTACH DATABASE ? AS src", (str(QURAN_DB),))
    for name in ("surah", "ayah", "word", "lemma", "section", "tafsir"):
        con.execute(f"CREATE TABLE src_{name} AS SELECT * FROM src.{name}")
    con.executemany(
        "INSERT INTO meta VALUES (?,?)",
        [
            ("layout", "quran.com api v4"),
            ("units_per_em", "2500"),
            ("body_line_units", str(body_units)),
            ("opening_line_units", str(opening_units)),
            ("bismillah_cp", "FDFD"),
        ],
    )
    con.commit()
    con.close()


def main() -> None:
    chapters = json.loads(CHAPTERS.read_text())["chapters"]
    bismillah_pre = {c["id"]: bool(c["bismillah_pre"]) for c in chapters}
    download_pages()
    download_fonts()
    words = load_words()
    lines, spans = derive(words, bismillah_pre)
    lines, fonts, body_units, opening_units = mark_centered(lines, words)
    pages = page_rows(words)
    wrows = word_rows(words)
    (ROOT / "scripts/SOURCES.md").write_text(font_license_notes(fonts))
    write_db(pages, lines, wrows, spans, body_units, opening_units)
    kinds = defaultdict(int)
    for _p, _l, kind, _s, _c in lines:
        kinds[kind] += 1
    print(f"words {len(wrows)} lines {len(lines)} spans {len(spans)} kinds {dict(kinds)}")
    print(f"wrote {DB_PATH}")


if __name__ == "__main__":
    main()
