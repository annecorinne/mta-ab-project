-- 02_journey_reconstruction.sql
-- Populated in Phase 2

-- =============================================================================
-- 02_journey_reconstruction.sql
-- Reconstructs full user journeys from touchpoint data.
-- Uses window functions to order touches, calculate time between touches,
-- identify first and last touch per user, and flag cross-channel behaviour.
-- Run after: 01_staging.sql
-- Run before: 03_experiment_validation.sql
-- =============================================================================



-- Adds sequence numbers and time-between-touches to every touchpoint.
-- LAG/LEAD window functions let us see what channel came before and after
-- each touch — essential for understanding how users move across channels.

-- Add journey order and time-between-touches for each user
CREATE OR REPLACE VIEW journeys_ordered AS
SELECT
    tp.touchpoint_id,
    tp.user_id,
    tp.touch_timestamp,
    tp.channel,
    tp.device,
    tp.campaign_id,

    -- What position in the journey is this touch? (1 = first ad seen)
    ROW_NUMBER() OVER (
        PARTITION BY tp.user_id
        ORDER BY tp.touch_timestamp ASC
    ) AS touch_number,

    -- How many total touches did this user have?
    COUNT(*) OVER (
        PARTITION BY tp.user_id
    ) AS total_touches,

    -- What channel came before this one?
    LAG(tp.channel) OVER (
        PARTITION BY tp.user_id
        ORDER BY tp.touch_timestamp ASC
    ) AS previous_channel,

    -- What channel came after this one?
    LEAD(tp.channel) OVER (
        PARTITION BY tp.user_id
        ORDER BY tp.touch_timestamp ASC
    ) AS next_channel,

    -- How many hours since the last touchpoint?
    ROUND(
        EPOCH(tp.touch_timestamp - LAG(tp.touch_timestamp) OVER (
            PARTITION BY tp.user_id
            ORDER BY tp.touch_timestamp ASC
        )) / 3600.0, 2
    ) AS hours_since_last_touch

FROM stg_user_touchpoints tp;



-- Identifies the first channel that introduced a user to the brand
-- and the last channel they saw before converting.
-- These are the two touches that simple attribution models focus on.

-- Identify first touch and last touch channel per user
CREATE OR REPLACE VIEW user_first_last_touch AS
SELECT
    user_id,

    -- First touch = the very first channel a user saw
    FIRST_VALUE(channel) OVER (
        PARTITION BY user_id
        ORDER BY touch_timestamp ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_touch_channel,

    -- Last touch = the final channel before conversion
    LAST_VALUE(channel) OVER (
        PARTITION BY user_id
        ORDER BY touch_timestamp ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_touch_channel,

    MIN(touch_timestamp) OVER (PARTITION BY user_id) AS first_touch_time,
    MAX(touch_timestamp) OVER (PARTITION BY user_id) AS last_touch_time,
    COUNT(*) OVER (PARTITION BY user_id)             AS total_touches

FROM stg_user_touchpoints
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY user_id ORDER BY touch_timestamp ASC
) = 1;


-- Counts distinct channels per user and flags cross-channel behaviour.
-- Users who saw multiple channels are the most important for attribution
-- because credit needs to be split across more than one touchpoint.

-- Flag users who saw more than one channel (cross-channel behaviour)
CREATE OR REPLACE VIEW user_channel_summary AS
SELECT
    user_id,
    COUNT(DISTINCT channel)                    AS n_channels,
    COUNT(*)                                   AS n_touchpoints,
    -- List all channels the user saw as an array
    ARRAY_AGG(DISTINCT channel ORDER BY channel) AS channels_seen,
    CASE
        WHEN COUNT(DISTINCT channel) > 1 THEN TRUE
        ELSE FALSE
    END                                        AS is_cross_channel
FROM stg_user_touchpoints
GROUP BY user_id;


-- Master journey summary — one row per user with full journey context
CREATE OR REPLACE VIEW user_journey_summary AS
SELECT
    ea.user_id,
    ea.arm,
    ea.is_new_visitor,
    ea.prior_orders,
    ea.device,

    -- Journey shape
    cs.n_touchpoints,
    cs.n_channels,
    cs.is_cross_channel,
    cs.channels_seen,

    -- First and last touch
    fl.first_touch_channel,
    fl.last_touch_channel,
    fl.first_touch_time,
    fl.last_touch_time,

    -- Time span of the journey in days
    ROUND(
        EPOCH(fl.last_touch_time - fl.first_touch_time) / 86400.0, 2
    ) AS journey_days,

    -- Conversion info
    CASE WHEN c.user_id IS NOT NULL THEN TRUE ELSE FALSE END AS converted,
    c.order_value,
    c.product_category,
    c.repeat_purchase_90d,
    c.ltv_90d,
    c.conversion_timestamp

FROM stg_experiment_assignments ea
LEFT JOIN user_channel_summary  cs ON ea.user_id = cs.user_id
LEFT JOIN user_first_last_touch fl ON ea.user_id = fl.user_id
LEFT JOIN stg_conversions       c  ON ea.user_id = c.user_id;


-- =============================================================================
-- Output views:
--   journeys_ordered       — every touchpoint with sequence number and LAG/LEAD
--   user_first_last_touch  — first and last channel per user
--   user_channel_summary   — channel counts and cross-channel flag per user
--   user_journey_summary   — master table, one row per user (consumed by Python)
-- =============================================================================
