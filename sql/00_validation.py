#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Feb 23 15:36:04 2026

@author: annecarroll
"""

import duckdb
import pandas as pd
import os


# ── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR = os.path.expanduser(
    "~/Dropbox/github"
    "/02_mta/mta-ab-project"
)

RAW_DIR = os.path.join(BASE_DIR, "data", "raw")

# File paths for each CSV
touchpoints_path  = os.path.join(RAW_DIR, "user_touchpoints.csv")
conversions_path  = os.path.join(RAW_DIR, "conversions.csv")
assignments_path  = os.path.join(RAW_DIR, "experiment_assignments.csv")


# ── Connect & Load ────────────────────────────────────────────────────────────
con = duckdb.connect()  # in-memory database

con.execute(f"""
    CREATE TABLE user_touchpoints AS
    SELECT * FROM read_csv_auto('{touchpoints_path}')
""")

con.execute(f"""
    CREATE TABLE conversions AS
    SELECT * FROM read_csv_auto('{conversions_path}')
""")

con.execute(f"""
    CREATE TABLE experiment_assignments AS
    SELECT * FROM read_csv_auto('{assignments_path}')
""")

print("✓ Tables loaded into DuckDB")


# ── Row Counts ────────────────────────────────────────────────────────────────
print("\n── Row Counts ───────────────────────────────")
for table in ['user_touchpoints', 'conversions', 'experiment_assignments']:
    n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    print(f"  {table}: {n:,} rows")
    

# ── Null Checks ───────────────────────────────────────────────────────────────
print("\n── Null Checks ──────────────────────────────")

null_checks = {
    'user_touchpoints':       ['touchpoint_id', 'user_id', 'timestamp', 'channel'],
    'conversions':            ['conversion_id', 'user_id', 'timestamp', 'order_value'],
    'experiment_assignments': ['user_id', 'arm', 'assignment_timestamp'],
}

for table, cols in null_checks.items():
    for col in cols:
        nulls = con.execute(f"""
            SELECT COUNT(*) FROM {table} WHERE {col} IS NULL
        """).fetchone()[0]
        status = "✓" if nulls == 0 else "✗ PROBLEM"
        print(f"  {status}  {table}.{col}: {nulls} nulls")
        
        
        
        
        
# ── Distribution Checks ───────────────────────────────────────────────────────
print("\n── Arm Distribution ─────────────────────────")
arm_dist = con.execute("""
    SELECT arm, COUNT(*) as n,
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as pct
    FROM experiment_assignments
    GROUP BY arm
    ORDER BY arm
""").df()
print(arm_dist.to_string(index=False))

print("\n── Channel Distribution ─────────────────────")
channel_dist = con.execute("""
    SELECT channel, COUNT(*) as n,
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as pct
    FROM user_touchpoints
    GROUP BY channel
    ORDER BY n DESC
""").df()
print(channel_dist.to_string(index=False))

print("\n── CVR by Arm ───────────────────────────────")
cvr_by_arm = con.execute("""
    SELECT
        ea.arm,
        COUNT(DISTINCT ea.user_id)  AS users,
        COUNT(DISTINCT c.user_id)   AS converters,
        ROUND(COUNT(DISTINCT c.user_id) * 100.0 /
              COUNT(DISTINCT ea.user_id), 1) AS cvr_pct
    FROM experiment_assignments ea
    LEFT JOIN conversions c ON ea.user_id = c.user_id
    GROUP BY ea.arm
    ORDER BY cvr_pct DESC
""").df()
print(cvr_by_arm.to_string(index=False))

print("\n✓ Validation complete — data looks good!")






