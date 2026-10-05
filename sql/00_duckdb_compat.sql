-- 00_duckdb_compat.sql  (DuckDB ONLY)
-- Spark SQL function shims so that 02-05 can be written in Spark SQL dialect
-- and still execute unchanged on DuckDB. On Spark/Databricks these functions are built in.
CREATE OR REPLACE MACRO percentile_approx(x, p) AS quantile_cont(x, p);
