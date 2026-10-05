-- 03_model.sql  Star schema (Spark SQL dialect)
--   fact_track          : one row per track (popularity + audio features), FK -> dim_artist, dim_album, dim_genre, dim_release_year
--   fact_playlist_track : one row per (track, playlist) membership, FK -> fact_track, dim_playlist, dim_subgenre
-- Surrogate keys use DENSE_RANK over the natural key (deterministic on both engines).

CREATE OR REPLACE TABLE dim_genre AS
SELECT DENSE_RANK() OVER (ORDER BY genre) AS genre_key, genre
FROM (SELECT DISTINCT genre FROM cln_playlist_tracks) g;

CREATE OR REPLACE TABLE dim_subgenre AS
SELECT DENSE_RANK() OVER (ORDER BY s.genre, s.subgenre) AS subgenre_key, s.subgenre, s.genre, g.genre_key
FROM (SELECT DISTINCT genre, subgenre FROM cln_playlist_tracks) s
JOIN dim_genre g ON g.genre = s.genre;

CREATE OR REPLACE TABLE dim_artist AS
SELECT DENSE_RANK() OVER (ORDER BY artist_name) AS artist_key, artist_name
FROM (SELECT DISTINCT artist_name FROM cln_tracks) a;

CREATE OR REPLACE TABLE dim_album AS
SELECT album_id, MAX(album_name) AS album_name, MAX(release_date) AS release_date, MAX(release_year) AS release_year,
       MAX(release_date_precision) AS release_date_precision
FROM cln_tracks GROUP BY album_id;

CREATE OR REPLACE TABLE dim_release_year AS
SELECT release_year, CAST(floor(release_year / 10) * 10 AS INT) AS release_decade,
       CASE WHEN release_year < 1980 THEN 'pre-1980' WHEN release_year < 2000 THEN '1980-1999'
            WHEN release_year < 2010 THEN '2000-2009' WHEN release_year < 2015 THEN '2010-2014' ELSE '2015-2020' END AS era
FROM (SELECT DISTINCT release_year FROM cln_tracks) y;

CREATE OR REPLACE TABLE dim_playlist AS
SELECT playlist_id, MAX(playlist_name) AS playlist_name, COUNT(*) AS tracks
FROM cln_playlist_tracks GROUP BY playlist_id;

CREATE OR REPLACE TABLE fact_track AS
SELECT t.track_id, t.track_name, a.artist_key, t.album_id, g.genre_key AS primary_genre_key, t.release_year,
       t.popularity, t.hit_flag, t.popularity_band, t.danceability, t.energy, t.musical_key, t.loudness, t.mode_major,
       t.speechiness, t.acousticness, t.instrumentalness, t.liveness, t.valence, t.tempo, t.duration_min, t.duration_band,
       t.playlist_count, t.genre_count, t.is_duration_outlier, t.is_multi_version_song
FROM cln_tracks t
JOIN dim_artist a ON a.artist_name = t.artist_name
JOIN dim_genre g ON g.genre = t.primary_genre;

CREATE OR REPLACE TABLE fact_playlist_track AS
SELECT p.track_id, p.playlist_id, s.subgenre_key, s.genre_key
FROM cln_playlist_tracks p
JOIN dim_subgenre s ON s.genre = p.genre AND s.subgenre = p.subgenre;
