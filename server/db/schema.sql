-- CMPE-137 Sec 1, Group 5
--
-- Run in MySQL Workbench against the `noireel` database.
-- Re-running this file DROPS every table and recreates it (dev only).
--
-- Notes
-- * user_accounts -> registered_users / admins is the ISA (subclass entity).
--   Each subtype row shares its user_id with its user_accounts row.
--   user_accounts.role says which subtype a row is; the app must create
--   exactly one matching subtype row (disjoint, total).
-- * Counts kept for fast reads (titles.avg_rating, titles.rating_count,
--   watchlists.view_count) are maintained by
--   the server inside the same transaction as the change (RU-06.03,
--   RU-13.04). ON DELETE CASCADE does not fix them.
-- * Mood vote counts and the majority rule are handled in one place:
--   after any change to user_mood_tags, CALL refresh_title_moods(title_id).
-- * Rules MySQL cannot enforce here, so the server must:
--   - watch_logs.watched_on is never in the future
--   - one is_default watchlist per user, which cannot be deleted (RU-08.06)
--   - reports target exactly one of review_id / watchlist_id (RU-06.07, RU-12.03)
--   - only RU actions for guests show a login prompt (GU-08.07)
-- * No image table: uploaded images are never stored (SYS-03.04).
-- * Guest themes live in device storage, not here (GU-06.03).
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS title_mood_tags, title_mood_votes;
DROP PROCEDURE IF EXISTS refresh_title_moods;

DROP TABLE IF EXISTS engagement_events, moderation_actions, reports,
  collection_items, collections, seed_moods, seed_titles, not_interested,
  watch_logs, watchlist_items, watchlists, reviews, ratings, private_tags,
  user_mood_tags, title_moods, genre_moods, mood_counters, moods,
  title_credits, people, title_genres, genres, titles,
  password_resets, sessions, admins, registered_users, user_accounts;

SET FOREIGN_KEY_CHECKS = 1;

-- Accounts (ERD: UserAccount ISA RegisteredUser | Admin)
CREATE TABLE user_accounts (
  user_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email              VARCHAR(254) NOT NULL,
  username           VARCHAR(20)  NOT NULL,
  password_hash      VARCHAR(255) NOT NULL,          -- bcrypt/argon2 string, salt included 
  role               ENUM('user','admin') NOT NULL DEFAULT 'user',
  status             ENUM('active','suspended','banned') NOT NULL DEFAULT 'active',
  status_reason      VARCHAR(255) NULL,              
  status_until       DATETIME     NULL,             
  failed_logins      TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- GU-08.03
  locked_until       DATETIME     NULL,              -- 15 min after 5 failures
  display_name       VARCHAR(50)  NULL,
  bio                VARCHAR(160) NULL,              -- RU-13.01
  avatar_url         VARCHAR(500) NULL,
  profile_visibility ENUM('public','private') NOT NULL DEFAULT 'public',
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_user_email (email),
  UNIQUE KEY uq_user_username (username),
  CONSTRAINT chk_username_format CHECK (username REGEXP '^[A-Za-z0-9_]{3,20}$')  -- GU-07.02
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE registered_users (
  user_id          BIGINT UNSIGNED NOT NULL,
  mood_mode        ENUM('match','regulate') NOT NULL DEFAULT 'match',  -- RU-07.01 last-used mode
  theme_mode       ENUM('light','dark','system') NOT NULL DEFAULT 'system',  -- GU-06
  theme_accent     VARCHAR(20) NULL,
  onboarding_done  BOOLEAN NOT NULL DEFAULT FALSE,   -- RU-04.02
  image_consent_at DATETIME NULL,                    -- RU-14.01 one-time consent
  PRIMARY KEY (user_id),
  CONSTRAINT fk_ru_account FOREIGN KEY (user_id)
    REFERENCES user_accounts (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE admins (
  user_id      BIGINT UNSIGNED NOT NULL,
  access_level ENUM('moderator','super_admin') NOT NULL DEFAULT 'moderator',
  granted_by   BIGINT UNSIGNED NULL,        
  granted_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (user_id),
  KEY idx_admin_granted_by (granted_by),
  CONSTRAINT fk_admin_account FOREIGN KEY (user_id)
    REFERENCES user_accounts (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_admin_granted_by FOREIGN KEY (granted_by)
    REFERENCES admins (user_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Weak entities owned by UserAccount
CREATE TABLE sessions (
  session_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  token_hash     CHAR(64) NOT NULL,                  -- SHA-256 of the token
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_active_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- expire after 30 days idle (RU-01.02)
  revoked_at     DATETIME NULL,                      -- logout / password change (RU-01.03, RU-13.02)
  PRIMARY KEY (session_id),
  UNIQUE KEY uq_session_token (token_hash),
  KEY idx_session_user (user_id),
  CONSTRAINT fk_session_user FOREIGN KEY (user_id)
    REFERENCES user_accounts (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE password_resets (
  reset_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,                      -- created_at + 1 hour (GU-08.05)
  used_at    DATETIME NULL,                          -- single use (GU-08.06)
  PRIMARY KEY (reset_id),
  UNIQUE KEY uq_reset_token (token_hash),
  KEY idx_reset_user (user_id),
  CONSTRAINT fk_reset_user FOREIGN KEY (user_id)
    REFERENCES user_accounts (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catalog (local copy of TMDB data; admins can add/edit, AD-06, SYS-04)
CREATE TABLE titles (
  title_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tmdb_id      INT UNSIGNED NULL,                    -- NULL for admin-created entries
  type         ENUM('movie','tv') NOT NULL,
  name         VARCHAR(255) NOT NULL,
  synopsis     TEXT NULL,
  release_year SMALLINT UNSIGNED NULL,
  runtime_min  SMALLINT UNSIGNED NULL,               -- movies
  num_seasons  SMALLINT UNSIGNED NULL,               -- TV
  num_episodes SMALLINT UNSIGNED NULL,               -- TV
  poster_url   VARCHAR(500) NULL,                    -- NULL -> placeholder (GU-02.03)
  popularity   DECIMAL(10,3) NOT NULL DEFAULT 0,     -- TMDB trend score; tie-breaker only, never the main sort
  tmdb_vote_avg   DECIMAL(3,1) NULL,                 -- TMDB 0-10 score, used as a quality floor in mood rows
  tmdb_vote_count INT UNSIGNED NOT NULL DEFAULT 0,
  mood_voter_count INT UNSIGNED NOT NULL DEFAULT 0,  -- distinct users who voted moods on this title
  avg_rating   DECIMAL(2,1) NULL,                    -- GU-04.01, maintained by server
  rating_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (title_id),
  UNIQUE KEY uq_title_tmdb (type, tmdb_id),          -- TMDB movie and TV ids overlap
  KEY idx_title_popularity (popularity),
  KEY idx_title_year (release_year),
  FULLTEXT KEY ft_title_name (name)                  -- GU-02.02 keyword search
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE genres (
  genre_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tmdb_genre_id INT UNSIGNED NULL,
  name          VARCHAR(50) NOT NULL,
  PRIMARY KEY (genre_id),
  UNIQUE KEY uq_genre_name (name),
  UNIQUE KEY uq_genre_tmdb (tmdb_genre_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE title_genres (
  title_id BIGINT UNSIGNED NOT NULL,
  genre_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (title_id, genre_id),
  KEY idx_tg_genre (genre_id),
  CONSTRAINT fk_tg_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE,
  CONSTRAINT fk_tg_genre FOREIGN KEY (genre_id) REFERENCES genres (genre_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE people (
  person_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tmdb_id   INT UNSIGNED NULL,
  name      VARCHAR(255) NOT NULL,
  PRIMARY KEY (person_id),
  UNIQUE KEY uq_person_tmdb (tmdb_id),
  FULLTEXT KEY ft_person_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE title_credits (
  title_id       BIGINT UNSIGNED NOT NULL,
  person_id      BIGINT UNSIGNED NOT NULL,
  role           ENUM('director','creator','cast') NOT NULL,
  character_name VARCHAR(255) NULL,
  billing_order  SMALLINT UNSIGNED NULL,             -- top 10 cast (GU-03.02)
  PRIMARY KEY (title_id, person_id, role),
  KEY idx_tc_person (person_id),
  CONSTRAINT fk_tc_title  FOREIGN KEY (title_id)  REFERENCES titles (title_id) ON DELETE CASCADE,
  CONSTRAINT fk_tc_person FOREIGN KEY (person_id) REFERENCES people (person_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mood
CREATE TABLE moods (
  mood_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(40) NOT NULL,
  description VARCHAR(255) NULL,
  color_hex   CHAR(7) NULL,                          -- '#RRGGBB' (RU-05.01)
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (mood_id),
  UNIQUE KEY uq_mood_name (name),
  CONSTRAINT chk_mood_color CHECK (color_hex IS NULL OR color_hex REGEXP '^#[0-9A-Fa-f]{6}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Regulate mode: mood -> counter-moods (RU-07.03, AD-05)
CREATE TABLE mood_counters (
  mood_id         INT UNSIGNED NOT NULL,
  counter_mood_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (mood_id, counter_mood_id),
  KEY idx_mc_counter (counter_mood_id),
  CONSTRAINT fk_mc_mood    FOREIGN KEY (mood_id)         REFERENCES moods (mood_id) ON DELETE CASCADE,
  CONSTRAINT fk_mc_counter FOREIGN KEY (counter_mood_id) REFERENCES moods (mood_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Genre -> mood translation (core concept)
CREATE TABLE genre_moods (
  genre_id INT UNSIGNED NOT NULL,
  mood_id  INT UNSIGNED NOT NULL,
  weight   DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  PRIMARY KEY (genre_id, mood_id),
  KEY idx_gm_mood (mood_id),
  CONSTRAINT fk_gm_genre FOREIGN KEY (genre_id) REFERENCES genres (genre_id) ON DELETE CASCADE,
  CONSTRAINT fk_gm_mood  FOREIGN KEY (mood_id)  REFERENCES moods (mood_id) ON DELETE CASCADE,
  CONSTRAINT chk_gm_weight CHECK (weight BETWEEN 0 AND 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mood tags per title, Fragrantica-style: every user can vote any moods
-- on a title, and the vote totals are shown to everyone.
--   genre_score     0-1 starting tag from the title's genres (genre_moods),
--                   refreshed by the importer and seed_moods.sql
--   community_count users who voted this mood (RU-11.03)
--   is_confirmed    the community has adopted this tag: at least 5 people
--                   voted on the title AND more than half of them picked
--                   this mood. Below that, a vote stays a personal tag that
--                   only its voter sees. Set by CALL refresh_title_moods().
--   is_curated      admin-set tag (AD-05.04)
--   mood_score      ranking signal for mood rows/search, and decides which
--                   tag is primary: confirmed (2+) > curated (1) > genre (0-1).
--                   Unconfirmed votes add nothing.
CREATE TABLE title_moods (
  title_id        BIGINT UNSIGNED NOT NULL,
  mood_id         INT UNSIGNED NOT NULL,
  genre_score     DECIMAL(4,3) NOT NULL DEFAULT 0,
  community_count INT UNSIGNED NOT NULL DEFAULT 0,
  is_confirmed    BOOLEAN NOT NULL DEFAULT FALSE,
  is_curated      BOOLEAN NOT NULL DEFAULT FALSE,
  mood_score      DECIMAL(7,3) AS (
                    IF(is_confirmed, 2 + LN(1 + community_count) / 10, 0)
                    + IF(is_curated, 1, 0)
                    + genre_score) STORED,
  PRIMARY KEY (title_id, mood_id),
  KEY idx_tm_mood_score (mood_id, mood_score),
  CONSTRAINT fk_tm_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE,
  CONSTRAINT fk_tm_mood  FOREIGN KEY (mood_id)  REFERENCES moods (mood_id) ON DELETE CASCADE,
  CONSTRAINT chk_tm_genre_score CHECK (genre_score BETWEEN 0 AND 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One user's mood tag on one title (RU-11.01)
CREATE TABLE user_mood_tags (
  user_id    BIGINT UNSIGNED NOT NULL,
  title_id   BIGINT UNSIGNED NOT NULL,
  mood_id    INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, title_id, mood_id),
  KEY idx_umt_title (title_id, mood_id),
  KEY idx_umt_mood (mood_id),
  CONSTRAINT fk_umt_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_umt_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE,
  CONSTRAINT fk_umt_mood  FOREIGN KEY (mood_id)  REFERENCES moods (mood_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Private free-text tags, never counted (RU-11.04)
CREATE TABLE private_tags (
  tag_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id  BIGINT UNSIGNED NOT NULL,
  title_id BIGINT UNSIGNED NOT NULL,
  text     VARCHAR(30) NOT NULL,
  PRIMARY KEY (tag_id),
  UNIQUE KEY uq_private_tag (user_id, title_id, text),
  KEY idx_pt_user_text (user_id, text),              -- filter by tag (RU-11.05)
  KEY idx_pt_title (title_id),
  CONSTRAINT fk_pt_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_pt_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Social features: ratings, reviews, watchlists, logs
CREATE TABLE ratings (
  rating_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  title_id   BIGINT UNSIGNED NOT NULL,
  stars      DECIMAL(2,1) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (rating_id),
  UNIQUE KEY uq_rating_user_title (user_id, title_id),
  KEY idx_rating_title (title_id, stars),               
  CONSTRAINT fk_rating_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_rating_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE,
  CONSTRAINT chk_rating_stars CHECK (stars BETWEEN 0.5 AND 5.0 AND MOD(stars * 10, 5) = 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reviews (
  review_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  title_id   BIGINT UNSIGNED NOT NULL,
  body       VARCHAR(5000) NOT NULL,                 -- RU-06.04
  is_spoiler BOOLEAN NOT NULL DEFAULT FALSE,
  is_edited  BOOLEAN NOT NULL DEFAULT FALSE,         -- RU-06.05
  status     ENUM('visible','hidden') NOT NULL DEFAULT 'visible',  -- AD-03.03
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (review_id),
  UNIQUE KEY uq_review_user_title (user_id, title_id),
  KEY idx_review_title_date (title_id, status, created_at),  -- GU-04.02 sort newest
  CONSTRAINT fk_review_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_review_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE watchlists (
  watchlist_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NOT NULL,
  name         VARCHAR(60) NOT NULL,
  description  VARCHAR(500) NULL,
  visibility   ENUM('public','private') NOT NULL DEFAULT 'private',
  is_default   BOOLEAN NOT NULL DEFAULT FALSE,       
  mod_hidden   BOOLEAN NOT NULL DEFAULT FALSE,
  view_count   INT UNSIGNED NOT NULL DEFAULT 0,      -- GU-05.03
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (watchlist_id),
  KEY idx_wl_user (user_id),
  KEY idx_wl_public (visibility, mod_hidden, created_at),  -- GU-05.01
  CONSTRAINT fk_wl_user FOREIGN KEY (user_id) REFERENCES registered_users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE watchlist_items (
  watchlist_id BIGINT UNSIGNED NOT NULL,
  title_id     BIGINT UNSIGNED NOT NULL,
  position     INT UNSIGNED NOT NULL,                -- RU-08.04 reorder
  added_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (watchlist_id, title_id),              -- "Already in this watchlist" (RU-08.02)
  KEY idx_wli_title (title_id),
  KEY idx_wli_order (watchlist_id, position),
  CONSTRAINT fk_wli_list  FOREIGN KEY (watchlist_id) REFERENCES watchlists (watchlist_id) ON DELETE CASCADE,
  CONSTRAINT fk_wli_title FOREIGN KEY (title_id)     REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE watch_logs (
  log_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  title_id      BIGINT UNSIGNED NOT NULL,
  watched_on    DATE NOT NULL,                       -- never in the future: enforced by server
  season_number SMALLINT UNSIGNED NULL,              -- TV only
  is_rewatch    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  KEY idx_log_user_date (user_id, watched_on),       -- RU-10.01 newest first
  KEY idx_log_title (title_id),
  CONSTRAINT fk_log_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_log_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Recommendation inputs (RU-04, SYS-01, SYS-02)
CREATE TABLE not_interested (
  user_id    BIGINT UNSIGNED NOT NULL,
  title_id   BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, title_id),
  KEY idx_ni_title (title_id),
  CONSTRAINT fk_ni_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_ni_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Onboarding: 3 favorite titles + 2 preferred moods (RU-04.02)
CREATE TABLE seed_titles (
  user_id  BIGINT UNSIGNED NOT NULL,
  title_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, title_id),
  KEY idx_st_title (title_id),
  CONSTRAINT fk_st_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_st_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE seed_moods (
  user_id BIGINT UNSIGNED NOT NULL,
  mood_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, mood_id),
  KEY idx_sm_mood (mood_id),
  CONSTRAINT fk_sm_user FOREIGN KEY (user_id) REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_sm_mood FOREIGN KEY (mood_id) REFERENCES moods (mood_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE engagement_events (
  event_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  title_id   BIGINT UNSIGNED NULL,
  mood_id    INT UNSIGNED NULL,
  event_type ENUM('view','rate','review','log','list_add','mood_tag','not_interested','mood_search') NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id),
  KEY idx_ev_user_time (user_id, created_at),        -- recency (SYS-02.02)
  KEY idx_ev_title (title_id),
  KEY idx_ev_mood (mood_id),
  CONSTRAINT fk_ev_user  FOREIGN KEY (user_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_ev_title FOREIGN KEY (title_id) REFERENCES titles (title_id) ON DELETE CASCADE,
  CONSTRAINT fk_ev_mood  FOREIGN KEY (mood_id)  REFERENCES moods (mood_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin: curation, reports, moderation log
CREATE TABLE collections (
  collection_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  created_by    BIGINT UNSIGNED NULL,
  title         VARCHAR(100) NOT NULL,
  description   VARCHAR(500) NULL,
  pin_order     TINYINT UNSIGNED NULL,               -- 1-5 = pinned on home, NULL = not pinned (AD-02.03)
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (collection_id),
  UNIQUE KEY uq_collection_pin (pin_order),          -- at most one collection per slot -> max 5 pinned
  KEY idx_col_creator (created_by),
  CONSTRAINT fk_col_admin FOREIGN KEY (created_by) REFERENCES admins (user_id) ON DELETE SET NULL,
  CONSTRAINT chk_col_pin CHECK (pin_order IS NULL OR pin_order BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE collection_items (
  collection_id BIGINT UNSIGNED NOT NULL,
  title_id      BIGINT UNSIGNED NOT NULL,
  position      INT UNSIGNED NOT NULL,
  PRIMARY KEY (collection_id, title_id),
  KEY idx_ci_title (title_id),
  CONSTRAINT fk_ci_col   FOREIGN KEY (collection_id) REFERENCES collections (collection_id) ON DELETE CASCADE,
  CONSTRAINT fk_ci_title FOREIGN KEY (title_id)      REFERENCES titles (title_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A report targets one review OR one public watchlist (server enforces exactly one).
CREATE TABLE reports (
  report_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  reporter_id  BIGINT UNSIGNED NOT NULL,
  review_id    BIGINT UNSIGNED NULL,
  watchlist_id BIGINT UNSIGNED NULL,
  reason       ENUM('spoiler','harassment','inappropriate','other') NOT NULL,
  status       ENUM('open','actioned','dismissed') NOT NULL DEFAULT 'open',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (report_id),
  UNIQUE KEY uq_report_review (reporter_id, review_id),        -- once per user per review (RU-06.07)
  UNIQUE KEY uq_report_watchlist (reporter_id, watchlist_id),
  KEY idx_report_status (status, created_at),
  KEY idx_report_review (review_id),
  KEY idx_report_watchlist (watchlist_id),
  CONSTRAINT fk_report_user FOREIGN KEY (reporter_id)  REFERENCES registered_users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_report_rev  FOREIGN KEY (review_id)    REFERENCES reviews (review_id) ON DELETE CASCADE,
  CONSTRAINT fk_report_wl   FOREIGN KEY (watchlist_id) REFERENCES watchlists (watchlist_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit log for every admin action (AD-01.03, AD-03.04, AD-04, AD-05.03, AD-06.03).
-- target_type + target_id point at different tables, so they are not foreign keys.
CREATE TABLE moderation_actions (
  action_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id    BIGINT UNSIGNED NULL,                  -- kept if the admin account is deleted
  action      VARCHAR(40) NOT NULL,                  -- e.g. 'suspend_user', 'hide_review', 'delete_mood'
  target_type ENUM('user','review','watchlist','watchlist_item','mood','title','collection') NOT NULL,
  target_id   BIGINT UNSIGNED NOT NULL,
  reason      VARCHAR(500) NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (action_id),
  KEY idx_ma_admin (admin_id, created_at),
  KEY idx_ma_target (target_type, target_id),
  CONSTRAINT fk_ma_admin FOREIGN KEY (admin_id) REFERENCES admins (user_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Mood voting logic
-- ---------------------------------------------------------------------

-- Call after ANY change to user_mood_tags for a title (vote, unvote, user
-- deleted): CALL refresh_title_moods(title_id);
-- Recounts the votes and re-applies the majority rule for every mood on it.
DELIMITER //
CREATE PROCEDURE refresh_title_moods(IN p_title_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_voters INT UNSIGNED;
  DECLARE v_min_voters INT UNSIGNED DEFAULT 5;   -- the "5 users" in the rule

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
  SET tm.community_count = COALESCE(v.votes, 0),
      tm.is_confirmed    = (v_voters >= v_min_voters AND COALESCE(v.votes, 0) * 2 > v_voters)
  WHERE tm.title_id = p_title_id;
END //
DELIMITER ;

-- Public mood tags for each title, ranked. tag_rank 1 = primary tag,
-- 2+ = secondary tags. Vote totals are included so the app can show
-- results by default. A user's own unconfirmed votes (personal tags) come
-- from user_mood_tags WHERE user_id = ?.
CREATE VIEW title_mood_tags AS
SELECT tm.title_id,
        tm.mood_id,
        m.name      AS mood_name,
        m.color_hex,
        tm.community_count AS votes,
        t.mood_voter_count AS voters,
        tm.is_confirmed,
        tm.mood_score,
        ROW_NUMBER() OVER (PARTITION BY tm.title_id
                            ORDER BY tm.mood_score DESC, tm.community_count DESC, m.mood_id) AS tag_rank
FROM title_moods tm
JOIN moods  m ON m.mood_id  = tm.mood_id AND m.is_active
JOIN titles t ON t.title_id = tm.title_id
WHERE tm.mood_score > 0;

-- Vote results panel (like Fragrantica's "notes according to your votes"):
-- every mood that has at least one vote, with its total, shown by default.
-- Unconfirmed moods appear here as counts, but NOT as tags in title_mood_tags.
CREATE VIEW title_mood_votes AS
SELECT tm.title_id,
        tm.mood_id,
        m.name      AS mood_name,
        m.color_hex,
        tm.community_count AS votes,
        t.mood_voter_count AS voters,
        tm.is_confirmed
FROM title_moods tm
JOIN moods  m ON m.mood_id  = tm.mood_id AND m.is_active
JOIN titles t ON t.title_id = tm.title_id
WHERE tm.community_count > 0;
