-- 01_staging.sql
-- Populated in Phase 2

-- =============================================================================
-- 01_staging.sql
-- Cleans and deduplicates the three raw tables loaded from CSV.
-- Creates one clean view per table that all downstream queries build on.
-- Run after: 00_validation.sql
-- Run before: 02_journey_reconstruction.sql
-- =============================================================================

-- Removes duplicate touchpoints caused by ad pixels firing twice.
-- Normalises channel and device to lowercase for consistent joins downstream.

-- Deduplicate touchpoints and cast types cleanly
CREATE OR REPLACE VIEW stg_user_touchpoints AS
SELECT DISTINCT
    touchpoint_id,
    user_id,
    session_id,
    CAST(timestamp AS TIMESTAMP)  AS touch_timestamp,
    LOWER(TRIM(channel))          AS channel,       -- normalize casing
    campaign_id,
    LOWER(TRIM(device))           AS device
FROM user_touchpoints
WHERE touchpoint_id IS NOT NULL
  AND user_id       IS NOT NULL
  AND timestamp     IS NOT NULL;
  
  
-- Filters out zero-value orders and cases where LTV is less than AOV
-- (data integrity check — LTV must always be >= first order value).
  
-- Clean conversions — remove nulls and impossible order values
CREATE OR REPLACE VIEW stg_conversions AS
SELECT
    conversion_id,
    user_id,
    CAST(timestamp AS TIMESTAMP)  AS conversion_timestamp,
    ROUND(order_value, 2)         AS order_value,
    LOWER(TRIM(product_category)) AS product_category,
    repeat_purchase_90d,
    ROUND(ltv_90d, 2)             AS ltv_90d
FROM conversions
WHERE conversion_id  IS NOT NULL
  AND user_id        IS NOT NULL
  AND order_value    > 0          -- filter out zero or negative orders
  AND ltv_90d        >= order_value; -- LTV must be at least the first order
  
-- Enforces one row per user using ROW_NUMBER().
-- If a user appears twice, we keep their earliest assignment record.
-- COALESCE sets null prior_orders to 0 (new visitors have no history).
  
  -- Clean experiment assignments — enforce one row per user
CREATE OR REPLACE VIEW stg_experiment_assignments AS
WITH deduplicated AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY user_id
               ORDER BY assignment_timestamp ASC
           ) AS rn           -- if a user appears twice, keep the earliest record
    FROM experiment_assignments
    WHERE user_id              IS NOT NULL
      AND arm                  IS NOT NULL
      AND assignment_timestamp IS NOT NULL
)
SELECT
    assignment_id,
    user_id,
    LOWER(TRIM(arm))                        AS arm,
    CAST(assignment_timestamp AS TIMESTAMP) AS assignment_timestamp,
    is_new_visitor,
    COALESCE(prior_orders, 0)               AS prior_orders,  -- treat nulls as 0
    LOWER(TRIM(device))                     AS device
FROM deduplicated
WHERE rn = 1;


-- =============================================================================
-- Output views (used by all downstream SQL files):
--   stg_user_touchpoints    — deduplicated, normalised touchpoints
--   stg_conversions         — clean orders with valid AOV and LTV
--   stg_experiment_assignments — one row per user, earliest assignment kept
-- =============================================================================