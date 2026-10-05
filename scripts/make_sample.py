#!/usr/bin/env python3
"""Build the reproducible raw subset in data/raw/ from data/raw_full/.

Rule (deterministic, no randomness): keep every playlist row whose track_id ends in 'Q' and starts with '2' or '3'
(135 of 32,833 rows, 118 tracks, all 6 genres; includes an 'NA' metadata row, a duplicate (track, playlist) row and
year-only release dates so every cleaning rule is exercised). Values are copied verbatim as strings.
"""
import pathlib, duckdb

ROOT = pathlib.Path(__file__).resolve().parents[1]
FULL, OUT = ROOT / "data/raw_full", ROOT / "data/raw"
OUT.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
con.execute(f"""
COPY (
  SELECT * FROM read_csv('{(FULL / "spotify_songs.csv").as_posix()}', header = true, all_varchar = true)
  WHERE substr(track_id, 22, 1) = 'Q' AND substr(track_id, 1, 1) IN ('2', '3')
  ORDER BY track_id, playlist_id
) TO '{(OUT / "spotify_songs.csv").as_posix()}' (HEADER, DELIMITER ',')
""")
n = con.execute(f"SELECT COUNT(*) FROM read_csv('{(OUT / 'spotify_songs.csv').as_posix()}', all_varchar = true)").fetchone()[0]
print("spotify_songs.csv sample rows:", n)
