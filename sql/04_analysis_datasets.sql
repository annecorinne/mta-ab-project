-- 04_analysis_datasets.sql
-- Populated in Phase 2

-- =============================================================================
-- 04_analysis_datasets.sql
-- Builds the final flattened tables consumed by Python notebooks.
-- One row per user with full journey, conversion, and experiment context.
-- Also builds a channel funnel table for EDA and MTA analysis.
-- Run after: 03_experiment_validation.sql
-- =============================================================================

-- Master user-level analysis table — one row per user
CREATE OR REPLACE VIEW analysis_users AS
SELECT
    -- Identity
    ea.user_id,
    ea.arm,

    -- User characteristics
    ea.is_new_visitor,
    ea.prior_orders,
    ea.device,

    -- Journey shape
    COALESCE(cs.n_touchpoints, 0)    AS n_touchpoints,
    COALESCE(cs.n_channels, 0)       AS n_channels,
    COALESCE(cs.is_cross_channel, FALSE) AS is_cross_channel,
    fl.first_touch_channel,
    fl.last_touch_channel,
    fl.journey_days,

    -- Conversion outcome
    CASE WHEN c.user_id IS NOT NULL
         THEN TRUE ELSE FALSE END    AS converted,
    COALESCE(c.order_value, 0)       AS order_value,
    c.product_category,
    COALESCE(c.repeat_purchase_90d, FALSE) AS repeat_purchase_90d,
    COALESCE(c.ltv_90d, 0)           AS ltv_90d,

    -- Timing
    ea.assignment_timestamp,
    c.conversion_timestamp,

    -- Hours from assignment to conversion (NULL if no conversion)
    ROUND(
        EPOCH(c.conversion_timestamp - ea.assignment_timestamp)
        / 3600.0, 2
    ) AS hours_to_convert

FROM stg_experiment_assignments ea
LEFT JOIN user_channel_summary  cs ON ea.user_id = cs.user_id
LEFT JOIN user_journey_summary  fl ON ea.user_id = fl.user_id
LEFT JOIN stg_conversions       c  ON ea.user_id = c.user_id;

-- Touchpoints for converted users only — input for MTA models
CREATE OR REPLACE VIEW analysis_mta_touchpoints AS
SELECT
    tp.user_id,
    tp.touchpoint_id,
    tp.touch_timestamp,
    tp.channel,
    tp.device,
    tp.campaign_id,
    jo.touch_number,
    jo.total_touches,
    jo.hours_since_last_touch,

    -- Is this the first touch?
    CASE WHEN jo.touch_number = 1
         THEN TRUE ELSE FALSE END      AS is_first_touch,

    -- Is this the last touch before conversion?
    CASE WHEN jo.touch_number = jo.total_touches
         THEN TRUE ELSE FALSE END      AS is_last_touch,

    -- Conversion info
    c.conversion_timestamp,
    c.order_value,
    c.ltv_90d,

    -- Experiment arm
    ea.arm

FROM stg_user_touchpoints tp
JOIN stg_conversions           c  ON tp.user_id = c.user_id
JOIN journeys_ordered          jo ON tp.touchpoint_id = jo.touchpoint_id
JOIN stg_experiment_assignments ea ON tp.user_id = ea.user_id

-- Only include touchpoints that happened BEFORE conversion
WHERE tp.touch_timestamp < c.conversion_timestamp;


-- Channel funnel — impression to conversion rates by channel and arm
CREATE OR REPLACE VIEW analysis_channel_funnel AS
SELECT
    tp.channel,
    ea.arm,

    -- Total users who saw this channel
    COUNT(DISTINCT tp.user_id)                          AS users_reached,

    -- Users who converted after seeing this channel
    COUNT(DISTINCT c.user_id)                           AS converters,

    -- Conversion rate
    ROUND(COUNT(DISTINCT c.user_id) * 100.0
          / COUNT(DISTINCT tp.user_id), 2)              AS cvr_pct,

    -- Average order value for converters via this channel
    ROUND(AVG(c.order_value), 2)                        AS avg_order_value,

    -- Average LTV for converters via this channel
    ROUND(AVG(c.ltv_90d), 2)                            AS avg_ltv_90d

FROM stg_user_touchpoints tp
JOIN stg_experiment_assignments ea ON tp.user_id = ea.user_id
LEFT JOIN stg_conversions       c  ON tp.user_id = c.user_id
GROUP BY tp.channel, ea.arm
ORDER BY tp.channel, ea.arm;



-- LTV and CVR summary by arm — the core finding of the project
CREATE OR REPLACE VIEW analysis_ltv_by_arm AS
SELECT
    ea.arm,
    COUNT(DISTINCT ea.user_id)                          AS total_users,
    COUNT(DISTINCT c.user_id)                           AS converters,

    -- CVR
    ROUND(COUNT(DISTINCT c.user_id) * 100.0
          / COUNT(DISTINCT ea.user_id), 2)              AS cvr_pct,

    -- Order metrics
    ROUND(AVG(c.order_value), 2)                        AS avg_order_value,

    -- LTV metrics
    ROUND(AVG(c.ltv_90d), 2)                            AS avg_ltv_90d,
    ROUND(SUM(CASE WHEN c.repeat_purchase_90d
              THEN 1 ELSE 0 END) * 100.0
              / NULLIF(COUNT(DISTINCT c.user_id), 0), 2) AS repeat_purchase_pct,

    -- Revenue per visitor (the metric that matters most)
    ROUND(SUM(COALESCE(c.ltv_90d, 0))
          / COUNT(DISTINCT ea.user_id), 2)              AS revenue_per_visitor

FROM stg_experiment_assignments ea
LEFT JOIN stg_conversions c ON ea.user_id = c.user_id
GROUP BY ea.arm
ORDER BY revenue_per_visitor DESC;

-- =============================================================================
-- Output views:
--   analysis_users            — master user table, one row per user
--   analysis_mta_touchpoints  — touchpoints for converted users (MTA input)
--   analysis_channel_funnel   — CVR and LTV by channel and arm
--   analysis_ltv_by_arm       — the central finding: CVR vs LTV by arm
-- =============================================================================


