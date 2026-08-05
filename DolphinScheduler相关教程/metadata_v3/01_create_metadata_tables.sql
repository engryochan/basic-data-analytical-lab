-- ==========================================================
-- Metadata Dictionary V3
-- 01_create_metadata_tables.sql
--
-- Enterprise Metadata Catalog
-- Author : OpenAI
-- Version: 3.0
-- ==========================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS metadata
DEFAULT CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE metadata;

-- ==========================================================
-- Core Metadata Dictionary
-- ==========================================================

DROP TABLE IF EXISTS metadata_dictionary;

CREATE TABLE metadata_dictionary
(

    metadata_id BIGINT AUTO_INCREMENT PRIMARY KEY,

    ----------------------------------------------------------
    -- Database
    ----------------------------------------------------------

    catalog_name           varchar(64)  DEFAULT NULL,
    schema_name            varchar(64)  NOT NULL,
    table_name             varchar(128) NOT NULL,
    column_name            varchar(128) NOT NULL,

    ----------------------------------------------------------
    -- Table Information
    ----------------------------------------------------------

    table_type             varchar(32),
    table_rows             bigint,
    engine                 varchar(32),

    table_comment          varchar(2048),

    ----------------------------------------------------------
    -- Column Information
    ----------------------------------------------------------

    ordinal_position       int,

    data_type              varchar(64),
    column_type            varchar(255),

    char_length            int,
    numeric_precision      int,
    numeric_scale          int,

    is_nullable            varchar(5),

    column_default         text,

    extra                  varchar(255),

    column_comment         varchar(2048),

    ----------------------------------------------------------
    -- Index
    ----------------------------------------------------------

    column_key             varchar(8),

    is_primary_key         tinyint(1) DEFAULT 0,

    is_unique_key          tinyint(1) DEFAULT 0,

    is_index               tinyint(1) DEFAULT 0,

    is_auto_increment      tinyint(1) DEFAULT 0,

    ----------------------------------------------------------
    -- Table Semantic
    ----------------------------------------------------------

    table_role             varchar(64),

    business_domain        varchar(64),

    subject_area           varchar(64),

    ----------------------------------------------------------
    -- Column Semantic
    ----------------------------------------------------------

    semantic_role          varchar(128),

    semantic_tags          text,

    semantic_level         varchar(32),

    ----------------------------------------------------------
    -- Candidate
    ----------------------------------------------------------

    key_candidate          varchar(64),

    time_candidate         varchar(64),

    measure_candidate      varchar(64),

    dimension_candidate    varchar(64),

    formula_candidate      varchar(64),

    join_candidate         varchar(64),

    ----------------------------------------------------------
    -- Join
    ----------------------------------------------------------

    join_table             varchar(128),

    join_column            varchar(128),

    join_confidence        decimal(5,2),

    ----------------------------------------------------------
    -- Measure
    ----------------------------------------------------------

    measure_unit           varchar(32),

    measure_type           varchar(64),

    aggregation_type       varchar(64),

    ----------------------------------------------------------
    -- Lifecycle
    ----------------------------------------------------------

    lifecycle              varchar(64),

    created_column         tinyint(1),

    updated_column         tinyint(1),

    deleted_column         tinyint(1),

    effective_date_column  tinyint(1),

    expired_date_column    tinyint(1),

    ----------------------------------------------------------
    -- Governance
    ----------------------------------------------------------

    data_classification    varchar(64),

    pii_flag               tinyint(1),

    owner_department       varchar(128),

    steward                varchar(128),

    ----------------------------------------------------------
    -- AI Explainability
    ----------------------------------------------------------

    evidence_level         varchar(32),

    confidence_score       decimal(5,2),

    matched_rule           varchar(128),

    rule_version           varchar(32),

    explain_text           text,

    ----------------------------------------------------------
    -- Data Profile
    ----------------------------------------------------------

    row_count              bigint,

    null_count             bigint,

    null_rate              decimal(12,6),

    distinct_count         bigint,

    duplicate_count        bigint,

    duplicate_rate         decimal(12,6),

    min_value              varchar(255),

    max_value              varchar(255),

    avg_value              decimal(30,10),

    sample_value           varchar(255),

    enum_values            text,

    ----------------------------------------------------------
    -- Lineage
    ----------------------------------------------------------

    source_system          varchar(128),

    source_table           varchar(128),

    source_column          varchar(128),

    target_system          varchar(128),

    target_table           varchar(128),

    target_column          varchar(128),

    etl_job                varchar(255),

    schedule_name          varchar(255),

    ----------------------------------------------------------
    -- AI
    ----------------------------------------------------------

    embedding_status       tinyint(1) DEFAULT 0,

    ai_description         text,

    ai_summary             text,

    ----------------------------------------------------------
    -- Audit
    ----------------------------------------------------------

    is_active              tinyint(1) DEFAULT 1,

    created_at             datetime DEFAULT CURRENT_TIMESTAMP,

    updated_at             datetime DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_metadata
    (
        schema_name,
        table_name,
        column_name
    ),

    INDEX idx_table
    (
        schema_name,
        table_name
    ),

    INDEX idx_role
    (
        semantic_role
    ),

    INDEX idx_domain
    (
        business_domain
    ),

    INDEX idx_table_role
    (
        table_role
    )

)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Enterprise Metadata Dictionary V3';
