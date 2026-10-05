"""Project-specific settings used by run_pipeline.py (raw files, star / clean tables, JSON.shot content)."""
NAME = "da-learn-09-spotify-music-trends"
DATASET = ("30000 Spotify Songs (TidyTuesday 2020-01-21, collected with the spotifyr package from the Spotify Web API; "
           "Kaggle: joebeachcapital/30000-spotify-songs)")
RAW_FILES = ["spotify_songs.csv"]
STAR = ["fact_track", "fact_playlist_track", "dim_artist", "dim_album", "dim_genre", "dim_subgenre", "dim_playlist",
        "dim_release_year"]
CLEAN = ["cln_tracks", "cln_playlist_tracks"]
METRIC_TABLES = ["a_genre_summary", "a_subgenre_popularity", "a_feature_popularity_corr", "a_popularity_by_feature_bin",
                 "a_popularity_band_profile", "a_popularity_by_duration", "a_trend_by_year", "a_trend_by_decade",
                 "a_genre_by_decade", "a_artist_leaderboard", "a_artist_concentration"]


def build_shot(q, kpi):
    """Headline snapshot written to results/JSON.shot."""
    return {
        "config": {"sql_dialect": "Spark SQL style (+ DuckDB shims in sql/00), run on DuckDB",
                   "grain": "fact_track = one row per track_id; fact_playlist_track = track x playlist",
                   "hit_definition": "popularity >= 70 (Spotify 0-100 score at extraction, Jan 2020)",
                   "primary_genre_rule": "genre of most playlist rows, ties alphabetical",
                   "outlier_rule": "duration outside Q1/Q3 -/+ 3*IQR (flagged, kept)",
                   "sample_rule": "substr(track_id,22,1) = 'Q' AND substr(track_id,1,1) IN ('2','3') (data/raw, 135 rows)"},
        "headline": kpi,
        "genres": q("SELECT primary_genre, tracks, avg_popularity, hit_pct FROM a_genre_summary ORDER BY avg_popularity DESC"),
        "top_subgenres_by_popularity": q("SELECT genre, subgenre, avg_popularity, hit_pct FROM a_subgenre_popularity ORDER BY avg_popularity DESC LIMIT 5"),
        "feature_corr_with_popularity": {r["feature"]: r["corr_all"] for r in q("SELECT feature, corr_all FROM a_feature_popularity_corr ORDER BY corr_all")},
        "by_decade": q("SELECT release_decade, tracks, avg_popularity, avg_acousticness, avg_duration_min FROM a_trend_by_decade ORDER BY release_decade"),
        "top_artists_by_tracks": q("SELECT artist_name, tracks, avg_popularity, main_genre FROM a_artist_leaderboard WHERE rank_by_tracks <= 5 ORDER BY rank_by_tracks"),
        "top_artists_by_popularity_min10": q("SELECT artist_name, tracks, avg_popularity FROM a_artist_leaderboard WHERE rank_by_popularity <= 5 ORDER BY rank_by_popularity"),
    }

