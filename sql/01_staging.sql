-- 01_staging.sql
-- Land the raw CSV as an all-STRING staging table (no type inference). {{RAW_DIR}} is substituted by run_pipeline.py.
-- DuckDB : read_csv(path, header = true, all_varchar = true)
-- Spark  : read_files('<path>/spotify_songs.csv', format => 'csv', header => true, inferColumnTypes => false)
-- spotify_songs.csv : one row per (track, playlist) - 32,833 rows x 23 columns; 'NA' = missing (written by R)
-- Column `key` is renamed to musical_key here so that 02-05 never use a keyword-like identifier.
CREATE OR REPLACE TABLE stg_spotify AS
SELECT * EXCLUDE ("key"), "key" AS musical_key
FROM read_csv('{{RAW_DIR}}/spotify_songs.csv', header = true, all_varchar = true);
