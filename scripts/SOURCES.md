# Sources

Built 2026-11-01.

Layout authority is the live Quran.com API, not `raw/qurancom/*.json`.
That snapshot's `line_number` values scramble 18 pages (120, 121, 145, 531, 533, 564, 567, 569, 575, 583, 588, 592, 593, 595, 597, 598, 599, 600).
The API returns the corrected Madani line breaks plus `code_v2`.
`chapters.json` is still read for surah names and `bismillah_pre`.

## Quran.com API v4

Source: https://api.quran.com/api/v4/verses/by_page/{page}
Fields: page_number, line_number, code_v2, text_uthmani, char_type_name, position, id, juz, hizb.
The Quran text itself is not copyrighted. The API is run by Quran.Foundation.
Attribution: Quran.com (https://quran.com).

## Local quran.db

Source file: /Users/nayabrehmat/dev/arabic-proj/data/quran.db
Copied tables: surah, ayah (including the Clear Quran English translation), word (gloss, transliteration, root, lemma), lemma, section, tafsir.
Clear Quran translation: © Dr. Mustafa Khattab. Included for this personal reader.
Tafsir rows are the translations already imported into quran.db.
Glosses and morphology were already imported there from the Quranic Arabic Corpus.

## QPC v2 page fonts

Source: https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v2/ttf/p{n}.ttf (604 files, unmodified)
Family: QCF2001
Copyright: Test Font, KFGQPC
License: 
License URL: 

## KFGQPC Uthmanic Script HAFS

Source: https://github.com/quran/quran.com-frontend-next (public/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.ttf), unmodified
Family: KFGQPC HAFS Uthmanic Script
Copyright: The digitally signed machine readable Typeface(Font) licensed to you is copyrighted, (2010), King Fahd Glorious Quran Printing Complex.
ISBN: 978-603-8010-15-0, Accession No. 1430/7278
All rights reserved. This Font is the property of King Fahd Glorious Quran Printing Complex, and may not be reproduced, modified without the express written approval of King Fahd Glorious Quran Printing Complex.
License: ELECTRONIC END-USER LICENSE AGREEMENT

By installing this Font You accept all the terms and conditions of this Agreement.

Copyright (c) 2010 by King Fahd Glorious Quran Printing Complex (KFGQPC), AlMadinah AlMunawarrah, Kingdom of Saudi Arabia. All Rights Reserved. KFGQPC retains full title and ownership of this Typeface both as artwork and font software. This Agreement does not grant you any intellectual property rights in the Font.

Permission is hereby granted, Free of Cost, to any person obtaining a copy of this Font accompanying this license, the rights to Use, Copy, Distribute, subject to the following conditions:

1.    The Font Software cannot be Sold, Modified, Altered, Translated, Reverse Engineered, Decompiled, Disassembled, Reproduced or Attempted to discover the Source Code of this Font in no means.

2.    The Font Software is provided "AS IS", and KFGQPC makes no warranties as to its use or performance, fitness for a particular purpose. KFGQPC does not and cannot warrant the performance or results you may obtain by using the Font. In no event shall KFGQPC be liable for any Claims, Damages or other Liability, including any Damages, arising from, out of the use or inability to use the Font or from other dealings in the Font.
License URL: 

## Surah name font v2

Source: https://static-cdn.tarteel.ai/qul/fonts/surah-names/v2/surah-name-v2.ttf
Family: surah-name-v2
Copyright: 
License: 
License URL: 

## Bismillah font

Source: https://static-cdn.tarteel.ai/qul/fonts/bismillah/bismillah.ttf
Family: icomoon
Copyright: 
License: 
License URL: 

Fonts are bundled unmodified. The KFGQPC agreement grants free use, copy, and distribution, and also says the font may not be reproduced. They are included under the granted use and copy rights, without modification, for this personal reader.
