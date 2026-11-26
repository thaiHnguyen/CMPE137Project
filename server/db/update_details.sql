-- Adds Favorites (next to the built-in Watchlist) to an existing NoiReel
-- database WITHOUT wiping any data. Fresh installs don't need this:
-- schema.sql already has it. Reviews, ratings and watch logs already had
-- their tables, so nothing else changes.
--
-- * watchlists.kind: 'list' (made by the user), 'watchlist' or 'favorites'
-- * watchlists.special_kind + uq_wl_special: one Watchlist and one
--   Favorites per user
--
-- Run once in MySQL Workbench against the `noireel` database.
-- Safe to run again: each step is skipped if it's already done.

SET NAMES utf8mb4;
SET SQL_SAFE_UPDATES = 0;

-- 1. kind column; existing default Watchlists become kind 'watchlist'
SET @has_kind = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
        AND table_name = 'watchlists'
        AND column_name = 'kind'
);
SET @sql = IF(@has_kind = 0,
    'ALTER TABLE watchlists ADD COLUMN kind ENUM(''list'',''watchlist'',''favorites'') NOT NULL DEFAULT ''list'' AFTER is_default',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE watchlists SET kind = 'watchlist' WHERE is_default AND kind = 'list';

-- If an account somehow has two default Watchlists, keep the oldest one
-- as the Watchlist; the others become ordinary lists
UPDATE watchlists w
JOIN (
    SELECT user_id, MIN(watchlist_id) AS keep_id
    FROM watchlists WHERE kind = 'watchlist' GROUP BY user_id
) k ON k.user_id = w.user_id
SET w.kind = 'list', w.is_default = FALSE
WHERE w.kind = 'watchlist' AND w.watchlist_id <> k.keep_id;

-- 2. special_kind and its unique key
SET @has_special = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
        AND table_name = 'watchlists'
        AND column_name = 'special_kind'
);
SET @sql = IF(@has_special = 0,
    'ALTER TABLE watchlists ADD COLUMN special_kind VARCHAR(10) AS (IF(kind = ''list'', NULL, kind)) STORED AFTER kind, ADD UNIQUE KEY uq_wl_special (user_id, special_kind)',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET SQL_SAFE_UPDATES = 1;
