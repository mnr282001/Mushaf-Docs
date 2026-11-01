#!/usr/bin/env python3
"""Invariants for Resources/mushaf.sqlite."""

import sqlite3
import unittest
from pathlib import Path

DB = Path(__file__).resolve().parents[1] / "Resources/mushaf.sqlite"


class MushafData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.con = sqlite3.connect(DB)

    def test_line_counts(self):
        rows = dict(self.con.execute("SELECT page, COUNT(*) FROM line GROUP BY page"))
        self.assertEqual(set(rows), set(range(1, 605)))
        for page, count in rows.items():
            self.assertEqual(count, 8 if page <= 2 else 15, page)
            nums = [r[0] for r in self.con.execute("SELECT line FROM line WHERE page=? ORDER BY line", (page,))]
            self.assertEqual(nums, list(range(1, count + 1)), page)

    def test_every_ayah_once_in_order(self):
        counts = dict(self.con.execute("SELECT id, ayah_count FROM src_surah"))
        self.assertEqual(sum(counts.values()), 6236)
        for surah, n in counts.items():
            poss = self.con.execute(
                "SELECT ayah, pos FROM word WHERE surah=? ORDER BY ayah, pos", (surah,)
            ).fetchall()
            by_ayah = {}
            for ayah, pos in poss:
                by_ayah.setdefault(ayah, []).append(pos)
            self.assertEqual(set(by_ayah), set(range(1, n + 1)), surah)
            for ayah, positions in by_ayah.items():
                self.assertEqual(positions, list(range(1, len(positions) + 1)), (surah, ayah))

    def test_page_bounds_match_ayah_table(self):
        bad = []
        for page, first, last in self.con.execute("SELECT page, first_ayah, last_ayah FROM page ORDER BY page"):
            db = [
                f"{s}:{a}"
                for s, a in self.con.execute(
                    "SELECT surah, ayah FROM src_ayah WHERE page=? ORDER BY surah, ayah", (page,)
                )
            ]
            if not db or db[0] != first or db[-1] != last:
                bad.append((page, first, last, db[0] if db else None, db[-1] if db else None))
        self.assertEqual(bad, [], bad[:8])

    def test_spans_match_words(self):
        for surah, ayah, page, first, last in self.con.execute("SELECT * FROM ayah_span"):
            lines = [
                r[0]
                for r in self.con.execute(
                    "SELECT DISTINCT line FROM word WHERE surah=? AND ayah=? AND page=? ORDER BY line",
                    (surah, ayah, page),
                )
            ]
            self.assertEqual(first, min(lines), (surah, ayah, page))
            self.assertEqual(last, max(lines), (surah, ayah, page))
        word_ayahs = self.con.execute("SELECT DISTINCT surah, ayah FROM word").fetchall()
        span_ayahs = self.con.execute("SELECT DISTINCT surah, ayah FROM ayah_span").fetchall()
        self.assertEqual(word_ayahs, span_ayahs)

    def test_headers_and_bismillah(self):
        headers = [r[0] for r in self.con.execute("SELECT surah FROM line WHERE kind='surah_header' ORDER BY surah")]
        self.assertEqual(headers, list(range(1, 115)))
        bism = [r[0] for r in self.con.execute("SELECT surah FROM line WHERE kind='bismillah' ORDER BY surah")]
        self.assertEqual(bism, [n for n in range(1, 115) if n not in (1, 9)])

    def test_code_v2_present(self):
        empty = self.con.execute("SELECT COUNT(*) FROM word WHERE code_v2 IS NULL OR code_v2 = ''").fetchone()[0]
        self.assertEqual(empty, 0)


if __name__ == "__main__":
    unittest.main()
