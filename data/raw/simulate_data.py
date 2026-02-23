#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Feb 23 08:51:55 2026

@author: annecarroll
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import os

# ── Settings ──────────────────────────────────────────────────────────────────
np.random.seed(42)        # Makes results reproducible — same data every run
random.seed(42)

N_USERS        = 50_000
START_DATE     = datetime(2024, 1, 1)
END_DATE       = datetime(2024, 6, 30)

CHANNELS       = ['paid_social', 'paid_search', 'display', 'email', 'organic']
DEVICES        = ['mobile', 'desktop', 'tablet']
DEVICE_WEIGHTS = [0.55, 0.38, 0.07]

PRODUCT_CATS   = ['skincare', 'supplements', 'apparel']

# Each arm's conversion rate lift over the 4% baseline
ARMS = {
    'control':       0.00,
    'loss_aversion': 0.06,
    'decoy':         0.09,
    'scarcity':      0.14,   # best CVR, worst LTV — the whole point of the project
}

# Save outputs to the same folder this script lives in
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Users & Experiment Assignments ────────────────────────────────────────────
def random_date(start, end):
    """Pick a random datetime between start and end."""
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))

user_ids     = [f'u_{i:06d}' for i in range(N_USERS)]
devices      = np.random.choice(DEVICES, size=N_USERS, p=DEVICE_WEIGHTS)
arms         = np.random.choice(list(ARMS.keys()), size=N_USERS)
is_new       = np.random.choice([True, False], size=N_USERS, p=[0.6, 0.4])
prior_orders = np.where(is_new, 0, np.random.randint(1, 8, size=N_USERS))
assign_times = [random_date(START_DATE, END_DATE) for _ in range(N_USERS)]

experiment_assignments = pd.DataFrame({
    'assignment_id':        [f'a_{i:06d}' for i in range(N_USERS)],
    'user_id':              user_ids,
    'arm':                  arms,
    'assignment_timestamp': assign_times,
    'is_new_visitor':       is_new,
    'prior_orders':         prior_orders,
    'device':               devices,
})

print(f"✓ experiment_assignments: {len(experiment_assignments):,} rows")
print(experiment_assignments['arm'].value_counts())

# ── Touchpoints & Conversions ─────────────────────────────────────────────────
BASE_CVR = 0.04

touchpoint_rows = []
conversion_rows = []

print("\nSimulating user journeys...")

for i, row in experiment_assignments.iterrows():
    uid       = row['user_id']
    arm       = row['arm']
    assign_ts = row['assignment_timestamp']
    device    = row['device']

    # Each user sees between 1 and 7 ads before hitting the landing page
    n_touches = np.random.randint(1, 8)

    for t in range(n_touches):
        touch_time = assign_ts - timedelta(
            hours=random.randint(1, 14 * 24)
        )
        touchpoint_rows.append({
            'touchpoint_id': f'tp_{i:06d}_{t}',
            'user_id':       uid,
            'session_id':    f's_{i:06d}_{t}',
            'timestamp':     touch_time,
            'channel':       random.choice(CHANNELS),
            'campaign_id':   f'camp_{random.randint(1, 20):03d}',
            'device':        device,
        })

    # Did this user convert?
    cvr       = BASE_CVR + ARMS[arm]
    converted = np.random.random() < cvr

    if converted:
        conv_time = assign_ts + timedelta(hours=random.randint(1, 72))

        aov = np.random.lognormal(mean=4.2, sigma=0.5)
        if arm == 'decoy':
            aov *= 1.15   # decoy attracts slightly higher first-order AOV

        # Repeat purchase probability — scarcity arm churns fastest
        repeat_probs = {
            'control':       0.45,
            'loss_aversion': 0.44,
            'decoy':         0.38,
            'scarcity':      0.28,
        }
        repeat = np.random.random() < repeat_probs[arm]
        ltv    = aov + (np.random.lognormal(3.8, 0.4) if repeat else 0)

        conversion_rows.append({
            'conversion_id':       f'c_{i:06d}',
            'user_id':             uid,
            'timestamp':           conv_time,
            'order_value':         round(aov, 2),
            'product_category':    random.choice(PRODUCT_CATS),
            'repeat_purchase_90d': repeat,
            'ltv_90d':             round(ltv, 2),
        })

user_touchpoints = pd.DataFrame(touchpoint_rows)
conversions      = pd.DataFrame(conversion_rows)

print(f"✓ user_touchpoints: {len(user_touchpoints):,} rows")
print(f"✓ conversions:      {len(conversions):,} rows")
print(f"  Overall CVR:      {len(conversions) / N_USERS:.1%}")

# ── Save ──────────────────────────────────────────────────────────────────────
user_touchpoints.to_csv(
    os.path.join(OUTPUT_DIR, 'user_touchpoints.csv'), index=False)

conversions.to_csv(
    os.path.join(OUTPUT_DIR, 'conversions.csv'), index=False)

experiment_assignments.to_csv(
    os.path.join(OUTPUT_DIR, 'experiment_assignments.csv'), index=False)

print("\n✓ All three CSVs saved to data/raw/")
print("  → user_touchpoints.csv")
print("  → conversions.csv")
print("  → experiment_assignments.csv")