#!/usr/bin/env python3
"""Download the full 30000 Spotify Songs dataset into data/raw_full/ and verify SHA-256.

Source  : TidyTuesday 2020-01-21 (rfordatascience/tidytuesday), collected with the spotifyr R package from the Spotify Web API
Kaggle  : https://www.kaggle.com/datasets/joebeachcapital/30000-spotify-songs (same file, 32,833 rows)
Licence : TidyTuesday repository CC0 1.0; Kaggle mirror lists Open Database License (ODbL). Underlying data (c) Spotify,
          provided through the Spotify Web API - use for learning / non-commercial analysis.
"""
import hashlib, pathlib, urllib.request

URL = "https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2020/2020-01-21/spotify_songs.csv"
FILE, SHA256 = "spotify_songs.csv", "9902920cfe4940f0914ebb6716801a42f7f19ac88fbd6693eaae7e2822b16845"
out = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw_full"
out.mkdir(parents=True, exist_ok=True)
if not (out / FILE).exists():
    print("downloading", URL)
    with urllib.request.urlopen(URL, timeout=300) as r:
        (out / FILE).write_bytes(r.read())
got = hashlib.sha256((out / FILE).read_bytes()).hexdigest()
print(f"{FILE} {(out / FILE).stat().st_size:,d} bytes  {'OK' if got == SHA256 else 'CHECKSUM MISMATCH ' + got}")
raise SystemExit(0 if got == SHA256 else 1)
