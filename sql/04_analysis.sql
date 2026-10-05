-- 04_analysis.sql  Business KPIs (Spark SQL dialect). Grain = track unless stated.
-- popularity: Spotify 0-100 score at extraction (Jan 2020); hit = popularity >= 70.

CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT (SELECT COUNT(*) FROM fact_track) AS tracks_total,
       (SELECT COUNT(*) FROM fact_playlist_track) AS playlist_memberships,
       (SELECT COUNT(*) FROM dim_artist) AS artists_total,
       (SELECT COUNT(*) FROM dim_album) AS albums_total,
       (SELECT COUNT(*) FROM dim_playlist) AS playlists_total,
       (SELECT COUNT(*) FROM dim_genre) AS genres_total,
       ROUND(AVG(popularity), 2) AS avg_popularity,
       ROUND(100.0 * SUM(hit_flag) / COUNT(*), 2) AS hit_pct,
       ROUND(100.0 * SUM(CASE WHEN popularity = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS zero_popularity_pct,
       MIN(release_year) AS first_release_year,
       MAX(release_year) AS last_release_year,
       ROUND(100.0 * SUM(CASE WHEN release_year >= 2010 THEN 1 ELSE 0 END) / COUNT(*), 2) AS released_2010_plus_pct,
       ROUND(AVG(duration_min), 3) AS avg_duration_min,
       ROUND(100.0 * SUM(CASE WHEN genre_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS multi_genre_track_pct
FROM fact_track;

CREATE OR REPLACE TABLE a_genre_summary AS
SELECT g.genre AS primary_genre, COUNT(*) AS tracks,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_track), 2) AS share_pct,
       ROUND(AVG(f.popularity), 2) AS avg_popularity,
       ROUND(100.0 * SUM(f.hit_flag) / COUNT(*), 2) AS hit_pct,
       ROUND(AVG(f.danceability), 3) AS avg_danceability, ROUND(AVG(f.energy), 3) AS avg_energy,
       ROUND(AVG(f.valence), 3) AS avg_valence, ROUND(AVG(f.acousticness), 3) AS avg_acousticness,
       ROUND(AVG(f.speechiness), 3) AS avg_speechiness, ROUND(AVG(f.tempo), 1) AS avg_tempo,
       ROUND(AVG(f.duration_min), 2) AS avg_duration_min, ROUND(AVG(f.release_year), 1) AS avg_release_year
FROM fact_track f JOIN dim_genre g ON g.genre_key = f.primary_genre_key
GROUP BY g.genre;

-- playlist-membership grain: a track in 2 sub-genre playlists counts in both
CREATE OR REPLACE TABLE a_subgenre_popularity AS
SELECT s.genre, s.subgenre, COUNT(*) AS playlist_tracks,
       ROUND(AVG(f.popularity), 2) AS avg_popularity, ROUND(100.0 * SUM(f.hit_flag) / COUNT(*), 2) AS hit_pct
FROM fact_playlist_track p
JOIN fact_track f ON f.track_id = p.track_id
JOIN dim_subgenre s ON s.subgenre_key = p.subgenre_key
GROUP BY s.genre, s.subgenre;

-- Pearson correlation of each audio feature with popularity (all tracks and popularity > 0) + hit vs non-hit means
CREATE OR REPLACE TABLE a_feature_popularity_corr AS
WITH long AS (
  SELECT 'danceability' AS feature, danceability AS v, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'energy', energy, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'loudness', loudness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'speechiness', speechiness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'acousticness', acousticness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'instrumentalness', instrumentalness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'liveness', liveness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'valence', valence, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'tempo', tempo, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'duration_min', duration_min, popularity, hit_flag FROM fact_track
)
SELECT feature,
       ROUND(corr(v, popularity), 4) AS corr_all,
       ROUND(corr(CASE WHEN popularity > 0 THEN v END, CASE WHEN popularity > 0 THEN popularity END), 4) AS corr_nonzero,
       ROUND(AVG(CASE WHEN hit_flag = 1 THEN v END), 4) AS mean_hits,
       ROUND(AVG(CASE WHEN hit_flag = 0 THEN v END), 4) AS mean_non_hits
FROM long GROUP BY feature;

-- Popularity by fixed 0.2-wide bins of the 0-1 audio features
CREATE OR REPLACE TABLE a_popularity_by_feature_bin AS
WITH long AS (
  SELECT 'danceability' AS feature, danceability AS v, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'energy', energy, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'acousticness', acousticness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'instrumentalness', instrumentalness, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'valence', valence, popularity, hit_flag FROM fact_track
  UNION ALL SELECT 'speechiness', speechiness, popularity, hit_flag FROM fact_track
), b AS (
  SELECT feature, LEAST(CAST(floor(v * 5) AS INT), 4) AS bin_idx, popularity, hit_flag FROM long WHERE v IS NOT NULL
)
SELECT feature, bin_idx,
       concat(CAST(bin_idx * 2 AS STRING), '-', CAST(bin_idx * 2 + 2 AS STRING)) AS bin_tenths,
       COUNT(*) AS tracks, ROUND(AVG(popularity), 2) AS avg_popularity, ROUND(100.0 * SUM(hit_flag) / COUNT(*), 2) AS hit_pct
FROM b GROUP BY feature, bin_idx;

CREATE OR REPLACE TABLE a_popularity_band_profile AS
SELECT popularity_band, COUNT(*) AS tracks, ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_track), 2) AS share_pct,
       ROUND(AVG(danceability), 3) AS avg_danceability, ROUND(AVG(energy), 3) AS avg_energy,
       ROUND(AVG(acousticness), 3) AS avg_acousticness, ROUND(AVG(instrumentalness), 3) AS avg_instrumentalness,
       ROUND(AVG(loudness), 2) AS avg_loudness, ROUND(AVG(duration_min), 2) AS avg_duration_min,
       ROUND(AVG(release_year), 1) AS avg_release_year
FROM fact_track GROUP BY popularity_band;

CREATE OR REPLACE TABLE a_popularity_by_duration AS
SELECT duration_band, COUNT(*) AS tracks, ROUND(AVG(popularity), 2) AS avg_popularity,
       ROUND(100.0 * SUM(hit_flag) / COUNT(*), 2) AS hit_pct
FROM fact_track GROUP BY duration_band;

CREATE OR REPLACE TABLE a_trend_by_year AS
SELECT release_year, COUNT(*) AS tracks, ROUND(AVG(popularity), 2) AS avg_popularity,
       ROUND(100.0 * SUM(hit_flag) / COUNT(*), 2) AS hit_pct,
       ROUND(AVG(danceability), 3) AS avg_danceability, ROUND(AVG(energy), 3) AS avg_energy,
       ROUND(AVG(acousticness), 3) AS avg_acousticness, ROUND(AVG(valence), 3) AS avg_valence,
       ROUND(AVG(loudness), 2) AS avg_loudness, ROUND(AVG(duration_min), 2) AS avg_duration_min
FROM fact_track GROUP BY release_year;

CREATE OR REPLACE TABLE a_trend_by_decade AS
SELECT y.release_decade, COUNT(*) AS tracks, ROUND(AVG(f.popularity), 2) AS avg_popularity,
       ROUND(100.0 * SUM(f.hit_flag) / COUNT(*), 2) AS hit_pct,
       ROUND(AVG(f.danceability), 3) AS avg_danceability, ROUND(AVG(f.energy), 3) AS avg_energy,
       ROUND(AVG(f.acousticness), 3) AS avg_acousticness, ROUND(AVG(f.valence), 3) AS avg_valence,
       ROUND(AVG(f.loudness), 2) AS avg_loudness, ROUND(AVG(f.duration_min), 2) AS avg_duration_min
FROM fact_track f JOIN dim_release_year y ON y.release_year = f.release_year
GROUP BY y.release_decade;

CREATE OR REPLACE TABLE a_genre_by_decade AS
SELECT y.release_decade, g.genre AS primary_genre, COUNT(*) AS tracks,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY y.release_decade), 2) AS share_of_decade_pct,
       ROUND(AVG(f.popularity), 2) AS avg_popularity
FROM fact_track f
JOIN dim_release_year y ON y.release_year = f.release_year
JOIN dim_genre g ON g.genre_key = f.primary_genre_key
GROUP BY y.release_decade, g.genre;

-- Artist leaderboard: artists with >= 10 tracks; ranked by catalogue size and by average popularity
CREATE OR REPLACE TABLE a_artist_leaderboard AS
WITH a AS (
  SELECT d.artist_name, COUNT(*) AS tracks, ROUND(AVG(f.popularity), 2) AS avg_popularity,
         SUM(f.hit_flag) AS hit_tracks, MAX(f.popularity) AS max_popularity
  FROM fact_track f JOIN dim_artist d ON d.artist_key = f.artist_key
  WHERE d.artist_name <> 'Unknown artist'
  GROUP BY d.artist_name HAVING COUNT(*) >= 10
), mg AS (
  SELECT artist_name, genre AS main_genre FROM (
    SELECT d.artist_name, g.genre, COUNT(*) AS n FROM fact_track f
    JOIN dim_artist d ON d.artist_key = f.artist_key JOIN dim_genre g ON g.genre_key = f.primary_genre_key
    GROUP BY d.artist_name, g.genre) x
  QUALIFY ROW_NUMBER() OVER (PARTITION BY artist_name ORDER BY n DESC, genre) = 1
)
SELECT a.*, mg.main_genre,
       ROW_NUMBER() OVER (ORDER BY a.tracks DESC, a.artist_name) AS rank_by_tracks,
       ROW_NUMBER() OVER (ORDER BY a.avg_popularity DESC, a.artist_name) AS rank_by_popularity
FROM a JOIN mg ON mg.artist_name = a.artist_name;

CREATE OR REPLACE TABLE a_artist_concentration AS
WITH a AS (SELECT artist_key, COUNT(*) AS tracks, SUM(hit_flag) AS hits FROM fact_track GROUP BY artist_key),
r AS (SELECT a.*, ROW_NUMBER() OVER (ORDER BY hits DESC, tracks DESC, artist_key) AS rn FROM a)
SELECT CASE WHEN rn <= 10 THEN 'top 10' WHEN rn <= 100 THEN '11-100' ELSE '101+' END AS artist_rank_by_hits,
       COUNT(*) AS artists, SUM(tracks) AS tracks, SUM(hits) AS hit_tracks,
       ROUND(100.0 * SUM(hits) / (SELECT SUM(hit_flag) FROM fact_track), 2) AS share_of_hits_pct
FROM r GROUP BY CASE WHEN rn <= 10 THEN 'top 10' WHEN rn <= 100 THEN '11-100' ELSE '101+' END;
