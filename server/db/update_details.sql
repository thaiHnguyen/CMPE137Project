-- Adds the new details-page fields to an existing NoiReel database WITHOUT
-- wiping any data. Fresh installs don't need this: schema.sql already has
-- them.
--
-- * titles.original_name: the title in its own language,
--   only stored when it differs from the English name
-- * titles.backdrop_url: the wide still behind the details page header
--
-- Run once in MySQL Workbench against the `noireel` database, then run the
-- importer again (dart run bin/import_tmdb.dart) to fill them in for the
-- titles you already have. Safe to run again.

SET NAMES utf8mb4;

SET @has_original = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
        AND table_name = 'titles'
        AND column_name = 'original_name'
);
SET @sql = IF(@has_original = 0,
    'ALTER TABLE titles ADD COLUMN original_name VARCHAR(255) NULL AFTER name',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_backdrop = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
        AND table_name = 'titles'
        AND column_name = 'backdrop_url'
);
SET @sql = IF(@has_backdrop = 0,
    'ALTER TABLE titles ADD COLUMN backdrop_url VARCHAR(500) NULL AFTER poster_url',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
