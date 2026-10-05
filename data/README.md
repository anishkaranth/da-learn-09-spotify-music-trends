# Data layout

| Path | What | In git |
|---|---|---|
| `raw/spotify_songs.csv` | 135 raw playlist rows, original 23 columns, verbatim text. Rule in `scripts/make_sample.py`: keep every row whose `track_id` ends in `Q` and starts with `2` or `3` (118 tracks, all 6 genres; includes an `NA` metadata row, a duplicate `(track, playlist)` row and year-only release dates so every cleaning rule is exercised). | yes |
| `raw_full/spotify_songs.csv` | the full TidyTuesday / Kaggle file (32,833 rows, 7,971,379 B), from `python scripts/download_full_data.py` | no (download) |
| `clean/` | cleaned CSVs (`tracks.csv`, `playlist_tracks.csv`) and `star/` from `python run_pipeline.py --source full` (~18 MB total) | no — regenerate; Power BI uses the committed copies in `../powerbi/data/` |
