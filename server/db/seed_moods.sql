-- NoiReel mood seed: the 6 moods, their opposites, and genre mappings.
--
-- Run AFTER schema.sql and AFTER the TMDB importer has run at least once
-- (the genre mappings need the genres to exist). Safe to re-run.
-- Community votes are never touched.
--
-- Genres are matched on TMDB genre ids, which never change, so renaming a
-- genre in the database won't break this file.
-- =====================================================================

-- Moods (3 opposing pairs)
INSERT INTO moods (name, description, color_hex) VALUES
  ('Hopeful',    'Optimistic, inspiring, things will work out', '#D9B13B'),
  ('Gloomy',     'Dark, heavy, unsettling',                     '#1D5632'),
  ('Happy',      'Light, fun, feel-good',                       '#EB6661'),
  ('Melancholy', 'Bittersweet, wistful, emotional',             '#325D7F'),
  ('Calm',       'Slow, quiet, easy to settle into',            '#EAE9E5'),
  ('Excited',    'Fast, thrilling, high energy',                '#BE280F')
ON DUPLICATE KEY UPDATE description = VALUES(description),
                        color_hex   = VALUES(color_hex),
                        is_active   = TRUE;

-- Regulate mode: each mood's opposite, both directions
INSERT IGNORE INTO mood_counters (mood_id, counter_mood_id)
SELECT a.mood_id, b.mood_id
FROM moods a JOIN moods b
WHERE (a.name, b.name) IN (
  ('Hopeful', 'Gloomy'),  ('Gloomy', 'Hopeful'),
  ('Happy', 'Melancholy'), ('Melancholy', 'Happy'),
  ('Calm', 'Excited'),     ('Excited', 'Calm'));

-- Genre -> mood starting tags
DELETE FROM genre_moods;

INSERT INTO genre_moods (genre_id, mood_id, weight)
SELECT g.genre_id, m.mood_id, map.weight
FROM (
  -- Hopeful
            SELECT 16 AS tmdb_genre_id, 'Hopeful' AS mood, 1.00 AS weight  -- Animation
  UNION ALL SELECT 35,    'Hopeful',    1.00  -- Comedy
  UNION ALL SELECT 10751, 'Hopeful',    1.00  -- Family
  UNION ALL SELECT 14,    'Hopeful',    1.00  -- Fantasy
  UNION ALL SELECT 10762, 'Hopeful',    1.00  -- Kids (TV)
  -- Gloomy
  UNION ALL SELECT 80,    'Gloomy',     1.00  -- Crime
  UNION ALL SELECT 18,    'Gloomy',     1.00  -- Drama
  UNION ALL SELECT 27,    'Gloomy',     1.00  -- Horror
  -- Happy
  UNION ALL SELECT 16,    'Happy',      1.00  -- Animation
  UNION ALL SELECT 10762, 'Happy',      1.00  -- Kids (TV)
  UNION ALL SELECT 35,    'Happy',      1.00  -- Comedy
  UNION ALL SELECT 10402, 'Happy',      1.00  -- Music
  -- Melancholy
  UNION ALL SELECT 10749, 'Melancholy', 1.00  -- Romance
  UNION ALL SELECT 10766, 'Melancholy', 1.00  -- Soap (TV)
  UNION ALL SELECT 10751, 'Melancholy', 1.00  -- Family
  -- Calm
  UNION ALL SELECT 99,    'Calm',       1.00  -- Documentary
  UNION ALL SELECT 10763, 'Calm',       1.00  -- News (TV)
  UNION ALL SELECT 10764, 'Calm',       1.00  -- Reality (TV)
  UNION ALL SELECT 36,    'Calm',       1.00  -- History
  UNION ALL SELECT 9648,  'Calm',       1.00  -- Mystery
  -- Excited
  UNION ALL SELECT 28,    'Excited',    1.00  -- Action
  UNION ALL SELECT 12,    'Excited',    1.00  -- Adventure
  UNION ALL SELECT 10759, 'Excited',    1.00  -- Action & Adventure (TV)
  UNION ALL SELECT 14,    'Excited',    1.00  -- Fantasy
  UNION ALL SELECT 878,   'Excited',    1.00  -- Science Fiction
  UNION ALL SELECT 10765, 'Excited',    1.00  -- Sci-Fi & Fantasy (TV)
  UNION ALL SELECT 37,    'Excited',    1.00  -- Western
  UNION ALL SELECT 53,    'Excited',    1.00  -- Thriller
  UNION ALL SELECT 10768, 'Excited',    1.00  -- War & Politics (TV)
  -- Not mapped yet (no starting tag; users can still vote):
  --   10770 TV Movie, 10767 Talk (TV), 10752 War
) AS map
JOIN genres g ON g.tmdb_genre_id = map.tmdb_genre_id
JOIN moods  m ON m.name          = map.mood;
 
-- Give every imported title its starting tags (same as the importer does)
UPDATE title_moods SET genre_score = 0;

INSERT INTO title_moods (title_id, mood_id, genre_score)
SELECT tg.title_id, gm.mood_id, MAX(gm.weight)
FROM title_genres tg JOIN genre_moods gm ON gm.genre_id = tg.genre_id
GROUP BY tg.title_id, gm.mood_id
ON DUPLICATE KEY UPDATE genre_score = VALUES(genre_score);

-- Quick check: how many titles start with each mood
SELECT m.name AS mood, COUNT(*) AS titles
FROM title_moods tm JOIN moods m USING (mood_id)
WHERE tm.genre_score > 0
GROUP BY m.name ORDER BY titles DESC;
