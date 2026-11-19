-- Switches an existing NoiReel database to the new mood vote rules,
-- WITHOUT wiping any data. Fresh installs don't need this: schema.sql
-- already has the new rules.
--
-- New rules (Nov 2026):
-- * The mood with the most votes is a title's primary tag, then the 2nd
--   most, and so on. Every vote counts right away: no 5-voter minimum and
--   no majority rule, so is_confirmed is gone.
-- * Before anyone votes, tags come from the title's genres. Ties in votes
--   go to the better genre fit.
-- * Mood rows rank titles by genre fit + votes + curation (mood_score).
-- * Each user can vote up to 3 moods per title (enforced by the server).
--
-- Run once in MySQL Workbench against the `noireel` database.
-- Safe to run again: it only changes the table if is_confirmed still exists.

SET NAMES utf8mb4;

-- 1. title_moods: drop is_confirmed and recompute mood_score without it.
--    MySQL can't change a generated column's formula in place, so the
--    column and its index are dropped and added back.
SET @has_old_rules = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'title_moods'
    AND COLUMN_NAME = 'is_confirmed');

SET @sql = IF(@has_old_rules > 0,
  'ALTER TABLE title_moods
     DROP INDEX idx_tm_mood_score,
     DROP COLUMN mood_score,
     DROP COLUMN is_confirmed,
     ADD COLUMN mood_score DECIMAL(7,3) AS (
       genre_score + LN(1 + community_count) + IF(is_curated, 1, 0)) STORED,
     ADD KEY idx_tm_mood_score (mood_id, mood_score)',
  'SELECT ''title_moods is already up to date'' AS note');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. The vote procedure and views, same as in schema.sql.
DROP VIEW IF EXISTS title_mood_tags, title_mood_votes;
DROP PROCEDURE IF EXISTS refresh_title_moods;

-- Call after ANY change to user_mood_tags for a title (vote, unvote, user
-- deleted): CALL refresh_title_moods(title_id);
-- Recounts the votes for every mood on it, and the number of voters.
DELIMITER //
CREATE PROCEDURE refresh_title_moods(IN p_title_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_voters INT UNSIGNED;

  SELECT COUNT(DISTINCT user_id) INTO v_voters
  FROM user_mood_tags WHERE title_id = p_title_id;

  UPDATE titles SET mood_voter_count = v_voters WHERE title_id = p_title_id;

  -- Make sure every voted mood has a row (e.g. titles with no genre mood).
  INSERT IGNORE INTO title_moods (title_id, mood_id)
  SELECT DISTINCT title_id, mood_id FROM user_mood_tags WHERE title_id = p_title_id;

  UPDATE title_moods tm
  LEFT JOIN (
    SELECT mood_id, COUNT(*) AS votes
    FROM user_mood_tags WHERE title_id = p_title_id GROUP BY mood_id
  ) v ON v.mood_id = tm.mood_id
  SET tm.community_count = COALESCE(v.votes, 0)
  WHERE tm.title_id = p_title_id;
END //
DELIMITER ;

-- Mood tags for each title, ranked. tag_rank 1 = primary tag, 2+ =
-- secondary tags. Most votes first; moods nobody voted for yet come after,
-- in order of admin curation, then genre fit. Ties in votes go to the
-- better genre fit. A user's own votes come from
-- user_mood_tags WHERE user_id = ?.
CREATE VIEW title_mood_tags AS
SELECT tm.title_id,
        tm.mood_id,
        m.name      AS mood_name,
        m.color_hex,
        tm.community_count AS votes,
        t.mood_voter_count AS voters,
        tm.mood_score,
        ROW_NUMBER() OVER (PARTITION BY tm.title_id
                            ORDER BY tm.community_count DESC, tm.is_curated DESC,
                                     tm.genre_score DESC, m.mood_id) AS tag_rank
FROM title_moods tm
JOIN moods  m ON m.mood_id  = tm.mood_id AND m.is_active
JOIN titles t ON t.title_id = tm.title_id
WHERE tm.mood_score > 0;

-- Vote results panel (like Fragrantica's "notes according to your votes"):
-- every mood that has at least one vote, with its total, shown by default.
-- Sort by votes DESC, is_curated DESC, genre_score DESC, mood_id to match
-- the tag order in title_mood_tags.
CREATE VIEW title_mood_votes AS
SELECT tm.title_id,
        tm.mood_id,
        m.name      AS mood_name,
        m.color_hex,
        tm.community_count AS votes,
        t.mood_voter_count AS voters,
        tm.is_curated,
        tm.genre_score
FROM title_moods tm
JOIN moods  m ON m.mood_id  = tm.mood_id AND m.is_active
JOIN titles t ON t.title_id = tm.title_id
WHERE tm.community_count > 0;

-- 3. Check: the top tags of the most-voted titles, highest votes first.
SELECT t.name, mt.tag_rank, mt.mood_name, mt.votes
FROM title_mood_tags mt JOIN titles t ON t.title_id = mt.title_id
WHERE t.mood_voter_count > 0 AND mt.tag_rank <= 3
ORDER BY t.mood_voter_count DESC, t.title_id, mt.tag_rank
LIMIT 15;
