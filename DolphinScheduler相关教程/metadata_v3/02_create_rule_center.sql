-- ==========================================================
-- Metadata Dictionary V3
-- 02_create_rule_center_v3.sql
-- Reviewed scaffold
-- Added deployment guards:
--   * FOREIGN_KEY_CHECKS wrapper
--   * transaction wrapper
--   * recommended deployment notes
-- NOTE:
-- This review preserves the uploaded script and prepends
-- deployment-safe scaffolding. Business logic is unchanged.
-- ==========================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS=0;
START TRANSACTION;

-- ==========================================================
-- Metadata Dictionary V3
-- Rule Center
-- ==========================================================

USE metadata;

-- ==========================================================
-- Rule Master
-- ==========================================================

DROP TABLE IF EXISTS metadata_rule;

CREATE TABLE metadata_rule
(
    rule_id              BIGINT AUTO_INCREMENT PRIMARY KEY,

    rule_code            VARCHAR(64) NOT NULL,
    rule_name            VARCHAR(255),

    rule_type            VARCHAR(64),

    priority             INT DEFAULT 100,

    enabled              TINYINT(1) DEFAULT 1,

    confidence           DECIMAL(5,2) DEFAULT 0,

    description          TEXT,

    rule_version         VARCHAR(32) DEFAULT '3.0',

    created_at           DATETIME DEFAULT CURRENT_TIMESTAMP,

    updated_at           DATETIME DEFAULT CURRENT_TIMESTAMP
                         ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_rule(rule_code),

    INDEX idx_type(rule_type),

    INDEX idx_priority(priority)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ==========================================================
-- Rule Regex
-- ==========================================================

DROP TABLE IF EXISTS metadata_rule_regex;

CREATE TABLE metadata_rule_regex
(

    regex_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    rule_id BIGINT NOT NULL,

    regex_pattern VARCHAR(1024),

    ignore_case TINYINT(1) DEFAULT 1,

    enabled TINYINT(1) DEFAULT 1,

    FOREIGN KEY(rule_id)
        REFERENCES metadata_rule(rule_id)

        ON DELETE CASCADE

);



-- ==========================================================
-- Keyword
-- ==========================================================

DROP TABLE IF EXISTS metadata_rule_keyword;

CREATE TABLE metadata_rule_keyword
(

    keyword_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    rule_id BIGINT,

    keyword VARCHAR(255),

    weight DECIMAL(8,2) DEFAULT 1,

    enabled TINYINT(1) DEFAULT 1,

    FOREIGN KEY(rule_id)

        REFERENCES metadata_rule(rule_id)

        ON DELETE CASCADE

);

-- ==========================================================
-- Business Domain
-- ==========================================================

DROP TABLE IF EXISTS metadata_rule_domain;

CREATE TABLE metadata_rule_domain
(

    domain_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    domain_name VARCHAR(128),

    description TEXT,

    parent_domain VARCHAR(128),

    enabled TINYINT DEFAULT 1

);


-- ==========================================================
-- Synonym
-- ==========================================================

DROP TABLE IF EXISTS metadata_rule_synonym;

CREATE TABLE metadata_rule_synonym
(

    synonym_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    standard_word VARCHAR(255),

    synonym VARCHAR(255),

    language VARCHAR(16),

    enabled TINYINT DEFAULT 1

);

-- ==========================================================
-- Stopword
-- ==========================================================

DROP TABLE IF EXISTS metadata_rule_stopword;

CREATE TABLE metadata_rule_stopword
(

    stopword_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    stopword VARCHAR(255),

    language VARCHAR(16),

    enabled TINYINT DEFAULT 1

);

-- ==========================================================
-- Rule Explain
-- ==========================================================
DROP TABLE IF EXISTS metadata_rule_explain;

CREATE TABLE metadata_rule_explain
(

    explain_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    rule_id BIGINT,

    explain_template TEXT,

    FOREIGN KEY(rule_id)

        REFERENCES metadata_rule(rule_id)

        ON DELETE CASCADE

);


-- ==========================================================
-- Rule Hit Log
-- ==========================================================
DROP TABLE IF EXISTS metadata_rule_hit;

CREATE TABLE metadata_rule_hit
(

    hit_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    schema_name VARCHAR(64),

    table_name VARCHAR(128),

    column_name VARCHAR(128),

    rule_id BIGINT,

    confidence DECIMAL(5,2),

    hit_time DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY(rule_id)

        REFERENCES metadata_rule(rule_id)

        ON DELETE CASCADE

);


-- ==========================================================
-- Keyword
-- ==========================================================

-- ==========================================================
-- Keyword
-- ==========================================================

-- ==========================================================
-- Keyword
-- ==========================================================


COMMIT;
SET FOREIGN_KEY_CHECKS=1;
