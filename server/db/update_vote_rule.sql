-- Adds the profile features to an existing NoiReel database WITHOUT
-- wiping any data. Fresh installs don't need this: schema.sql already
-- has them.
--
-- * user_accounts.pronoun: shown on the profile
-- * goat_picks: a user's Greatest Of All Time, up to 5 titles
--
-- Run once in MySQL Workbench against the `noireel` database.
-- Safe to run again: each step is skipped if it's already done.

SET NAMES utf8mb4;

-- 1. pronoun column (MySQL has no ADD COLUMN IF NOT EXISTS, so check first)
SET @has_pronoun = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'user_accounts'
    AND column_name = 'pronoun'
);
SET @sql = IF(@has_pronoun = 0,
  'ALTER TABLE user_accounts ADD COLUMN pronoun VARCHAR(20) NULL AFTER bio',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. goat_picks table
CREATE TABLE IF NOT EXISTS goat_picks (
  user_id   BIGINT UNSIGNED  NOT NULL,
  slot      TINYINT UNSIGNED NOT NULL,              -- 1-5, left to right
  title_id  BIGINT UNSIGNED  NOT NULL,
  PRIMARY KEY (user_id, slot),
  UNIQUE KEY uq_goat_title (user_id, title_id),     -- a title fills one slot at most
  KEY idx_goat_title (title_id),
  CONSTRAINT chk_goat_slot  CHECK (slot BETWEEN 1 AND 5),
  CONSTRAINT fk_goat_user  FOREIGN KEY (user_id)  REFERENCES user_accounts (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_goat_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
