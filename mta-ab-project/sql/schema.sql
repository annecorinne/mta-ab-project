#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Feb 22 15:06:55 2026

@author: annecarroll
"""

-- =============================================================================
-- schema.sql
-- Defines the three core tables for the MTA & A/B Test project.
-- All tables are joined on user_id.
-- Executed via DuckDB in notebook 01_eda.ipynb
-- =============================================================================

-- Every ad interaction per user (one user → many touchpoints)
CREATE TABLE IF NOT EXISTS user_touchpoints (
    touchpoint_id   VARCHAR PRIMARY KEY,  -- Unique ID for each ad interaction
    user_id         VARCHAR NOT NULL,     -- Links to conversions + experiment_assignments
    session_id      VARCHAR,              -- Groups touchpoints within a browsing session
    timestamp       TIMESTAMP NOT NULL,   -- Used to order the journey chronologically
    channel         VARCHAR NOT NULL,     -- paid_social, paid_search, display, email, organic
    campaign_id     VARCHAR,              -- Links to campaign metadata
    device          VARCHAR               -- mobile, desktop, tablet
);

-- One row per completed purchase
CREATE TABLE IF NOT EXISTS conversions (
    conversion_id        VARCHAR PRIMARY KEY,  -- Unique order identifier
    user_id              VARCHAR NOT NULL,     -- Links back to their touchpoint journey
    timestamp            TIMESTAMP NOT NULL,   -- Must be after assignment_timestamp
    order_value          FLOAT,                -- First order AOV
    product_category     VARCHAR,              -- skincare, supplements, apparel
    repeat_purchase_90d  BOOLEAN,              -- Did they buy again within 90 days?
    ltv_90d              FLOAT                 -- Total revenue in 90 days post purchase
);

-- One row per user — arm assignment for the A/B test
CREATE TABLE IF NOT EXISTS experiment_assignments (
    assignment_id        VARCHAR PRIMARY KEY,  -- Unique assignment record
    user_id              VARCHAR NOT NULL,     -- Must appear exactly once (dupes = bug)
    arm                  VARCHAR NOT NULL,     -- control, loss_aversion, decoy, scarcity
    assignment_timestamp TIMESTAMP NOT NULL,   -- Must be before conversion timestamp
    is_new_visitor       BOOLEAN,              -- First ever site visit? Key HTE variable
    prior_orders         INTEGER,              -- Purchase history at time of assignment
    device               VARCHAR               -- mobile, desktop, tablet
);


-- =============================================================================
-- Relationships
-- user_touchpoints.user_id  → many rows per user
-- conversions.user_id       → one row per user
-- experiment_assignments.user_id → one row per user
--
-- Query execution order:
-- 00_validation.sql → 01_staging.sql → 02_journey_reconstruction.sql
-- → 03_experiment_validation.sql → 04_analysis_datasets.sql
-- =============================================================================
