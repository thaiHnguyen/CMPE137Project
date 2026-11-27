-- Adds review likes, comments and comment likes to an existing NoiReel
-- database WITHOUT wiping any data. Fresh installs don't need this:
-- schema.sql already has them.
--
-- Run once in MySQL Workbench against the `noireel` database.
-- Safe to run again: tables that already exist are left alone.

SET NAMES utf8mb4;

-- Likes on a review (one per user). Counted for "Popular reviews"
CREATE TABLE IF NOT EXISTS review_likes (
    review_id  BIGINT UNSIGNED NOT NULL,
    user_id    BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (review_id, user_id),
    KEY idx_rl_user (user_id),
    CONSTRAINT fk_rl_review FOREIGN KEY (review_id) REFERENCES reviews (review_id) ON DELETE CASCADE,
    CONSTRAINT fk_rl_user   FOREIGN KEY (user_id)   REFERENCES registered_users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Comments under a review, oldest first
CREATE TABLE IF NOT EXISTS review_comments (
    comment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    review_id  BIGINT UNSIGNED NOT NULL,
    user_id    BIGINT UNSIGNED NOT NULL,
    body       VARCHAR(2000) NOT NULL,
    status     ENUM('visible','hidden') NOT NULL DEFAULT 'visible',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (comment_id),
    KEY idx_rc_review (review_id, status, created_at),
    KEY idx_rc_user (user_id),
    CONSTRAINT fk_rc_review FOREIGN KEY (review_id) REFERENCES reviews (review_id) ON DELETE CASCADE,
    CONSTRAINT fk_rc_user   FOREIGN KEY (user_id)   REFERENCES registered_users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Likes on a comment (one per user)
CREATE TABLE IF NOT EXISTS comment_likes (
    comment_id BIGINT UNSIGNED NOT NULL,
    user_id    BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (comment_id, user_id),
    KEY idx_cl_user (user_id),
    CONSTRAINT fk_cl_comment FOREIGN KEY (comment_id) REFERENCES review_comments (comment_id) ON DELETE CASCADE,
    CONSTRAINT fk_cl_user    FOREIGN KEY (user_id)    REFERENCES registered_users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

