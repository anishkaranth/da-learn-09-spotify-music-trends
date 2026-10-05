-- 02_cleaning.sql  Cleaning (Spark SQL dialect; runs unchanged on DuckDB after sql/00)
-- Steps: trim + 'NA' -> NULL, cast types, standardise genre text, parse mixed-precision release dates,
--        dedupe (track, playlist) rows, invalid-value handling, outlier flags, one-row-per-track table.

-- 1) Typed, standardised (track, playlist) rows; exact duplicate (track_id, playlist_id) pairs removed
CREATE OR REPLACE TABLE cln_playlist_tracks AS
SELECT trim(track_id) AS track_id,
       trim(playlist_id) AS playlist_id,
       CASE WHEN trim(playlist_name) IN ('', 'NA') THEN NULL ELSE trim(playlist_name) END AS playlist_name,
       lower(trim(playlist_genre)) AS genre,
       lower(trim(playlist_subgenre)) AS subgenre
FROM stg_spotify
WHERE track_id IS NOT NULL AND playlist_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY trim(track_id), trim(playlist_id)
                           ORDER BY lower(trim(playlist_genre)), lower(trim(playlist_subgenre))) = 1;

-- 2) Track attributes (identical on every playlist row of a track - asserted in sql/05), typed
CREATE OR REPLACE TABLE cln_track_attributes AS
SELECT track_id,
       CASE WHEN track_name IN ('', 'NA') THEN NULL ELSE track_name END AS track_name,
       CASE WHEN track_artist IN ('', 'NA') THEN NULL ELSE track_artist END AS track_artist,
       album_id,
       CASE WHEN album_name IN ('', 'NA') THEN NULL ELSE album_name END AS album_name,
       release_date_raw,
       CAST(substr(release_date_raw, 1, 4) AS INT) AS release_year,
       CAST(CASE length(release_date_raw) WHEN 10 THEN release_date_raw
                 WHEN 7 THEN concat(release_date_raw, '-01')
                 WHEN 4 THEN concat(release_date_raw, '-01-01') END AS DATE) AS release_date,
       CASE length(release_date_raw) WHEN 10 THEN 'day' WHEN 7 THEN 'month' WHEN 4 THEN 'year' ELSE 'unknown' END AS release_date_precision,
       popularity, danceability, energy, musical_key, loudness, mode_major, speechiness, acousticness,
       instrumentalness, liveness, valence,
       CASE WHEN tempo > 0 THEN tempo END AS tempo,
       CASE WHEN tempo > 0 THEN 0 ELSE 1 END AS dq_invalid_tempo,
       duration_ms
FROM (
  SELECT trim(track_id) AS track_id,
         MAX(trim(track_name)) AS track_name,
         MAX(trim(track_artist)) AS track_artist,
         MAX(trim(track_album_id)) AS album_id,
         MAX(trim(track_album_name)) AS album_name,
         MAX(trim(track_album_release_date)) AS release_date_raw,
         MAX(CAST(track_popularity AS INT)) AS popularity,
         MAX(CAST(danceability AS DOUBLE)) AS danceability,
         MAX(CAST(energy AS DOUBLE)) AS energy,
         MAX(CAST(musical_key AS INT)) AS musical_key,
         MAX(CAST(loudness AS DOUBLE)) AS loudness,
         MAX(CAST(mode AS INT)) AS mode_major,
         MAX(CAST(speechiness AS DOUBLE)) AS speechiness,
         MAX(CAST(acousticness AS DOUBLE)) AS acousticness,
         MAX(CAST(instrumentalness AS DOUBLE)) AS instrumentalness,
         MAX(CAST(liveness AS DOUBLE)) AS liveness,
         MAX(CAST(valence AS DOUBLE)) AS valence,
         MAX(CAST(tempo AS DOUBLE)) AS tempo,
         MAX(CAST(duration_ms AS BIGINT)) AS duration_ms
  FROM stg_spotify
  WHERE track_id IS NOT NULL
  GROUP BY trim(track_id)
) a;

-- 3) One row per track: primary genre (genre of most playlists, ties alphabetical), derived bands, outlier flags
CREATE OR REPLACE TABLE cln_tracks AS
WITH g AS (
  SELECT track_id, genre, subgenre, COUNT(*) AS n FROM cln_playlist_tracks GROUP BY track_id, genre, subgenre
), pg AS (
  SELECT track_id, genre AS primary_genre, subgenre AS primary_subgenre FROM g
  QUALIFY ROW_NUMBER() OVER (PARTITION BY track_id ORDER BY n DESC, genre, subgenre) = 1
), pc AS (
  SELECT track_id, COUNT(*) AS playlist_count, COUNT(DISTINCT genre) AS genre_count FROM cln_playlist_tracks GROUP BY track_id
), dur AS (
  SELECT percentile_approx(duration_ms, 0.25) AS q1, percentile_approx(duration_ms, 0.75) AS q3 FROM cln_track_attributes
), ver AS (
  SELECT lower(track_name) AS lname, lower(track_artist) AS lartist, COUNT(*) AS n_ids
  FROM cln_track_attributes WHERE track_name IS NOT NULL GROUP BY lower(track_name), lower(track_artist)
)
SELECT t.*,
       coalesce(t.track_artist, 'Unknown artist') AS artist_name,
       CAST(floor(t.release_year / 10) * 10 AS INT) AS release_decade,
       ROUND(t.duration_ms / 60000.0, 3) AS duration_min,
       CASE WHEN t.popularity >= 70 THEN 1 ELSE 0 END AS hit_flag,
       CASE WHEN t.popularity = 0 THEN '0 (zero)' WHEN t.popularity < 20 THEN '01-19' WHEN t.popularity < 40 THEN '20-39'
            WHEN t.popularity < 60 THEN '40-59' WHEN t.popularity < 80 THEN '60-79' ELSE '80-100' END AS popularity_band,
       CASE WHEN t.duration_ms < 150000 THEN 'a <2.5 min' WHEN t.duration_ms < 180000 THEN 'b 2.5-3 min'
            WHEN t.duration_ms < 210000 THEN 'c 3-3.5 min' WHEN t.duration_ms < 240000 THEN 'd 3.5-4 min'
            WHEN t.duration_ms < 300000 THEN 'e 4-5 min' ELSE 'f 5+ min' END AS duration_band,
       pg.primary_genre, pg.primary_subgenre, pc.playlist_count, pc.genre_count,
       CASE WHEN t.duration_ms < dur.q1 - 3 * (dur.q3 - dur.q1) OR t.duration_ms > dur.q3 + 3 * (dur.q3 - dur.q1) THEN 1 ELSE 0 END AS is_duration_outlier,
       CASE WHEN t.duration_ms < 60000 THEN 1 ELSE 0 END AS is_under_1min,
       CASE WHEN ver.n_ids > 1 THEN 1 ELSE 0 END AS is_multi_version_song,
       CASE WHEN t.track_name IS NULL THEN 1 ELSE 0 END AS dq_missing_metadata
FROM cln_track_attributes t
JOIN pg ON pg.track_id = t.track_id
JOIN pc ON pc.track_id = t.track_id
CROSS JOIN dur
LEFT JOIN ver ON ver.lname = lower(t.track_name) AND ver.lartist = lower(t.track_artist);
