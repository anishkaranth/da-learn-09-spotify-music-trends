-- 05_quality_checks.sql  Data-quality evidence (Spark SQL dialect)

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'playlist_rows' AS entity, (SELECT COUNT(*) FROM stg_spotify) AS raw_rows,
       (SELECT COUNT(DISTINCT concat(track_id, '|', playlist_id)) FROM stg_spotify) AS distinct_keys,
       (SELECT COUNT(*) FROM cln_playlist_tracks) AS clean_rows, 'track_id x playlist_id' AS grain
UNION ALL SELECT 'tracks', NULL, (SELECT COUNT(DISTINCT track_id) FROM stg_spotify), (SELECT COUNT(*) FROM cln_tracks), 'track_id'
UNION ALL SELECT 'fact_track', NULL, NULL, (SELECT COUNT(*) FROM fact_track), 'track'
UNION ALL SELECT 'fact_playlist_track', NULL, NULL, (SELECT COUNT(*) FROM fact_playlist_track), 'track x playlist'
UNION ALL SELECT 'dim_artist', NULL, NULL, (SELECT COUNT(*) FROM dim_artist), 'artist name'
UNION ALL SELECT 'dim_album', NULL, NULL, (SELECT COUNT(*) FROM dim_album), 'album_id'
UNION ALL SELECT 'dim_genre', NULL, NULL, (SELECT COUNT(*) FROM dim_genre), 'genre'
UNION ALL SELECT 'dim_subgenre', NULL, NULL, (SELECT COUNT(*) FROM dim_subgenre), 'genre x subgenre'
UNION ALL SELECT 'dim_playlist', NULL, NULL, (SELECT COUNT(*) FROM dim_playlist), 'playlist_id'
UNION ALL SELECT 'dim_release_year', NULL, NULL, (SELECT COUNT(*) FROM dim_release_year), 'release year';

CREATE OR REPLACE TABLE dq_null_rates AS
SELECT 'tracks' AS entity, 'track_name / artist / album_name' AS column_name,
  (SELECT ROUND(100.0 * SUM(CASE WHEN track_name = 'NA' OR track_name IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_spotify) AS raw_missing_pct,
  (SELECT ROUND(100.0 * SUM(dq_missing_metadata) / COUNT(*), 3) FROM cln_tracks) AS clean_null_pct,
  'R-style NA -> NULL; artist shown as Unknown artist' AS treatment
UNION ALL SELECT 'tracks', 'tempo',
  (SELECT ROUND(100.0 * SUM(CASE WHEN CAST(tempo AS DOUBLE) = 0 THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_spotify),
  (SELECT ROUND(100.0 * SUM(CASE WHEN tempo IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_tracks),
  'tempo = 0 is invalid -> NULL'
UNION ALL SELECT 'tracks', 'release_date (day precision)',
  (SELECT ROUND(100.0 * SUM(CASE WHEN length(track_album_release_date) <> 10 THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_spotify),
  (SELECT ROUND(100.0 * SUM(CASE WHEN release_date_precision <> 'day' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_tracks),
  'yyyy / yyyy-mm padded to the 1st; precision kept in release_date_precision';

CREATE OR REPLACE TABLE dq_issues AS
SELECT 'playlist_rows: duplicate (track_id, playlist_id) rows dropped' AS check_name,
       (SELECT COUNT(*) FROM stg_spotify) - (SELECT COUNT(*) FROM cln_playlist_tracks) AS affected_rows
UNION ALL SELECT 'tracks: appear on more than one playlist row', (SELECT COUNT(*) FROM cln_tracks WHERE playlist_count > 1)
UNION ALL SELECT 'tracks: appear under more than one genre (primary genre assigned)', (SELECT COUNT(*) FROM cln_tracks WHERE genre_count > 1)
UNION ALL SELECT 'tracks: missing name / artist / album (NA)', (SELECT SUM(dq_missing_metadata) FROM cln_tracks)
UNION ALL SELECT 'tracks: tempo = 0 (set NULL)', (SELECT SUM(dq_invalid_tempo) FROM cln_tracks)
UNION ALL SELECT 'tracks: release date year-only', (SELECT COUNT(*) FROM cln_tracks WHERE release_date_precision = 'year')
UNION ALL SELECT 'tracks: release date year-month only', (SELECT COUNT(*) FROM cln_tracks WHERE release_date_precision = 'month')
UNION ALL SELECT 'tracks: popularity = 0', (SELECT COUNT(*) FROM cln_tracks WHERE popularity = 0)
UNION ALL SELECT 'tracks: duration outlier (outside Q1/Q3 -/+ 3*IQR, kept)', (SELECT SUM(is_duration_outlier) FROM cln_tracks)
UNION ALL SELECT 'tracks: shorter than 1 minute (kept)', (SELECT SUM(is_under_1min) FROM cln_tracks)
UNION ALL SELECT 'tracks: same name + artist under several track_ids (kept)', (SELECT SUM(is_multi_version_song) FROM cln_tracks);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'fact_track.track_id unique' AS check_name, (SELECT COUNT(*) - COUNT(DISTINCT track_id) FROM fact_track) AS failed_rows
  UNION ALL SELECT 'fact_track rows = distinct raw track_id',
         (SELECT ABS((SELECT COUNT(*) FROM fact_track) - (SELECT COUNT(DISTINCT track_id) FROM stg_spotify)))
  UNION ALL SELECT 'track attributes identical on every playlist row',
         (SELECT COUNT(*) FROM (SELECT track_id FROM stg_spotify GROUP BY track_id
            HAVING COUNT(DISTINCT track_popularity) > 1 OR COUNT(DISTINCT danceability) > 1 OR COUNT(DISTINCT track_album_id) > 1) x)
  UNION ALL SELECT 'fact_playlist_track (track_id, playlist_id) unique',
         (SELECT COUNT(*) - COUNT(DISTINCT concat(track_id, '|', playlist_id)) FROM fact_playlist_track)
  UNION ALL SELECT 'fact_playlist_track.track_id -> fact_track',
         (SELECT COUNT(*) FROM fact_playlist_track WHERE track_id NOT IN (SELECT track_id FROM fact_track))
  UNION ALL SELECT 'fact_playlist_track.playlist_id -> dim_playlist',
         (SELECT COUNT(*) FROM fact_playlist_track WHERE playlist_id NOT IN (SELECT playlist_id FROM dim_playlist))
  UNION ALL SELECT 'fact_track.artist_key -> dim_artist',
         (SELECT COUNT(*) FROM fact_track WHERE artist_key NOT IN (SELECT artist_key FROM dim_artist))
  UNION ALL SELECT 'fact_track.album_id -> dim_album',
         (SELECT COUNT(*) FROM fact_track WHERE album_id NOT IN (SELECT album_id FROM dim_album))
  UNION ALL SELECT 'fact_track.release_year -> dim_release_year',
         (SELECT COUNT(*) FROM fact_track WHERE release_year NOT IN (SELECT release_year FROM dim_release_year))
  UNION ALL SELECT 'popularity between 0 and 100', (SELECT COUNT(*) FROM fact_track WHERE popularity NOT BETWEEN 0 AND 100)
  UNION ALL SELECT '0-1 audio features in range',
         (SELECT COUNT(*) FROM fact_track WHERE danceability NOT BETWEEN 0 AND 1 OR energy NOT BETWEEN 0 AND 1
            OR valence NOT BETWEEN 0 AND 1 OR acousticness NOT BETWEEN 0 AND 1 OR speechiness NOT BETWEEN 0 AND 1)
  UNION ALL SELECT 'every release date parsed', (SELECT COUNT(*) FROM cln_tracks WHERE release_date IS NULL)
  UNION ALL SELECT 'release_year between 1950 and 2020', (SELECT COUNT(*) FROM fact_track WHERE release_year NOT BETWEEN 1950 AND 2020)
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;
