-- 03_experiment_validation.sql
-- Populated in Phase 2

-- =============================================================================
-- 03_experiment_validation.sql
-- Validates the A/B test before any analysis is run.
-- Checks: arm balance, contamination, covariate balance, assignment timing.
-- This is the SUTVA validation section — shows experimental hygiene.
-- Run after: 02_journey_reconstruction.sql
-- Run before: 04_analysis_datasets.sql
-- =============================================================================

-- Checks that each arm received roughly 25% of users.
-- A lopsided split would introduce selection bias into the results.
-- Expect ~12,500 users per arm.

-- Are arms evenly distributed?
CREATE OR REPLACE VIEW validation_arm_balance AS
SELECT
    arm,
    COUNT(*)                                            AS n_users,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM stg_experiment_assignments
GROUP BY arm
ORDER BY arm;


-- Checks for users assigned to more than one arm — this would violate
-- the Stable Unit Treatment Value Assumption (SUTVA).
-- This view should return zero rows. Any rows here = experiment is compromised.


-- Does any user appear in more than one arm? (should be zero)
CREATE OR REPLACE VIEW validation_contamination AS
SELECT
    user_id,
    COUNT(DISTINCT arm) AS n_arms
FROM stg_experiment_assignments
GROUP BY user_id
HAVING COUNT(DISTINCT arm) > 1;


-- Checks that arms are comparable on pre-experiment characteristics.
-- If one arm has significantly more new visitors or mobile users,
-- those differences could explain outcomes rather than the nudge itself.

-- Are arms balanced on pre-experiment characteristics?
CREATE OR REPLACE VIEW validation_covariate_balance AS
SELECT
    arm,
    ROUND(AVG(prior_orders), 2)                    AS avg_prior_orders,
    ROUND(SUM(is_new_visitor) * 100.0 / COUNT(*), 1) AS pct_new_visitors,
    ROUND(SUM(CASE WHEN device = 'mobile'
              THEN 1 ELSE 0 END) * 100.0
              / COUNT(*), 1)                       AS pct_mobile
FROM stg_experiment_assignments
GROUP BY arm
ORDER BY arm;

-- Flags users who converted before they were assigned to an arm.
-- This is a common data logging bug in real experiments.
-- This view should return zero rows. Any rows here = pipeline bug.

-- Were any users assigned AFTER they converted? (should be zero)
CREATE OR REPLACE VIEW validation_timing AS
SELECT
    ea.user_id,
    ea.arm,
    ea.assignment_timestamp,
    c.conversion_timestamp,
    ROUND(EPOCH(c.conversion_timestamp - ea.assignment_timestamp)
          / 3600.0, 2) AS hours_assign_to_convert
FROM stg_experiment_assignments ea
JOIN stg_conversions c ON ea.user_id = c.user_id

-- =============================================================================
-- Output views:
--   validation_arm_balance       — arm size and % split
--   validation_contamination     — users in multiple arms (expect 0 rows)
--   validation_covariate_balance — pre-experiment comparability across arms
--   validation_timing            — assignments after conversion (expect 0 rows)
-- =============================================================================


