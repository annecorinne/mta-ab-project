# Multi-Touch Attribution & Behavioral A/B Testing

> *"We found a variant that increased conversion rate by 14%. We chose not to ship it."*

---

## Overview

This project examines a question most A/B tests never ask: **what happens after the conversion?**

Using a simulated DTC e-commerce dataset, we run a four-arm experiment testing three behavioral economics nudges — loss aversion framing, decoy pricing, and scarcity/social proof stacking — against a control. On the surface, one variant wins clearly. Dig into 90-day customer lifetime value and the story inverts.

Alongside the experiment, we build a full multi-touch attribution model — from Last Touch baselines through a from-scratch Shapley value implementation — and show how the landing page experience a user saw contaminates the credit your attribution model assigns to acquisition channels. The two analyses are in genuine dialogue with each other.

---

## The Business Question

A DTC brand is running paid acquisition across five channels. The growth team wants to know:

1. Which behavioral nudge maximises revenue per visitor — not just conversion rate?
2. Do nudge effects differ by customer segment (new vs. returning, high vs. low AOV)?
3. How much does our landing page experience distort what our attribution model tells us about channel performance?

---

## Behavioral Economics Framework

Each experiment arm is grounded in a specific mechanism:

| Arm | Nudge | Mechanism |
|-----|-------|-----------|
| Control | Standard page | Baseline |
| B | Loss aversion framing | Prospect Theory — losses loom ~2× larger than equivalent gains (Kahneman & Tversky, 1979) |
| C | Decoy pricing | Asymmetric dominance effect — an inferior option makes the target feel obviously correct (Ariely et al., 2001) |
| D | Scarcity + social proof | Hyperbolic discounting + herding behaviour — urgency collapses future regret into present action (Cialdini, 2001) |

---

## Key Findings

> *This section will be populated on project completion.*

---

## Technical Approach

### Data Architecture

Three tables, designed to mirror a production warehouse schema:

- **`user_touchpoints`** — every ad interaction per user, with channel, campaign, device, and timestamp
- **`conversions`** — order-level data including AOV, product category, and 90-day repeat purchase signals
- **`experiment_assignments`** — arm assignment with timestamp, used to validate SUTVA and detect contamination

### SQL Layer (DuckDB)

| File | Purpose |
|------|---------|
| `00_validation.sql` | Row counts, null checks, distribution sanity |
| `01_staging.sql` | Deduplication, type casting, clean views |
| `02_journey_reconstruction.sql` | LAG/LEAD path reconstruction, time-between-touch |
| `03_experiment_validation.sql` | Balance checks, contamination detection, covariate balance |
| `04_analysis_datasets.sql` | Final flattened tables consumed by Python notebooks |

### Notebooks

| Notebook | Content |
|----------|---------|
| `01_eda.ipynb` | Journey patterns, Sankey diagram, channel distributions |
| `02_baseline_mta.ipynb` | Last Touch, First Touch, Linear, Time Decay, Position-Based |
| `03_shapley_mta.ipynb` | Shapley value model built from scratch |
| `04_mta_comparison.ipynb` | Cross-model comparison and business interpretation |
| `05_experiment_design.ipynb` | Pre-analysis plan, power analysis, MDE curves |
| `06_frequentist_analysis.ipynb` | z-tests, Bonferroni correction, CVR scorecard |
| `07_bayesian_analysis.ipynb` | Beta-Binomial posteriors, P(arm beats control) |
| `08_hte_analysis.ipynb` | T-Learner CATE estimates by segment |
| `09_ltv_analysis.ipynb` | 90-day revenue per visitor — the LTV reveal |
| `10_deployment_strategy.ipynb` | Segmentation-based rollout recommendation |

---

## Concepts Covered

- Multi-touch attribution (Last Touch → Shapley Value)
- Bayesian A/B testing with Beta-Binomial conjugate models
- Heterogeneous treatment effects with EconML T-Learner
- Prospect theory, asymmetric dominance, hyperbolic discounting
- Goodhart's Law applied to conversion rate optimisation
- SUTVA validation and experimental hygiene
- Attribution model contamination by on-site experience

---

## Stack

| Layer | Tools |
|-------|-------|
| Database | DuckDB (cloud-warehouse style SQL) |
| Analysis | Python — pandas, numpy, scipy |
| Modelling | scikit-learn, XGBoost, EconML, PyMC |
| Visualisation | matplotlib, seaborn, plotly |
| Notebooks | JupyterLab |

---

## Running the Project



```bash
# 1. Clone and set up environment
git clone https://github.com/YOUR_USERNAME/mta-ab-project.git
cd mta-ab-project
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# 2. Generate synthetic data
python data/raw/simulate_data.py

# 3. Run SQL layer (executed via DuckDB in notebooks)
# See sql/README.md for execution order

# 4. Open notebooks in order
jupyter lab
```

## Phase 1 — Status

Data architecture and simulation complete as of February 2026.

**Schema:** Three-table design defined in `sql/schema.sql` — `user_touchpoints`, 
`conversions`, and `experiment_assignments`, all joined on `user_id`.

**Simulation:** `data/raw/simulate_data.py` generates 50,000 users with realistic 
multi-touch journeys across five channels. Behavioral economics effects are baked 
into the data-generating process — the scarcity arm (Arm D) produces a 18.2% CVR 
lift over control, but repeat purchase rates are suppressed to 28% vs. 45% for 
control. The gap between CVR performance and LTV is the central finding the 
analysis will surface.

**Validation:** DuckDB loaded all three tables cleanly — zero nulls across critical 
fields, arms balanced at ~25% each, overall CVR of 11.2%.
---

## Repository Structure

```
mta-ab-project/
├── README.md
├── requirements.txt
├── .gitignore
├── data/
│   ├── raw/                  ← Simulation script + generated CSVs (gitignored)
│   └── processed/            ← SQL output tables committed here
├── sql/
│   ├── README.md
│   ├── 00_validation.sql
│   ├── 01_staging.sql
│   ├── 02_journey_reconstruction.sql
│   ├── 03_experiment_validation.sql
│   └── 04_analysis_datasets.sql
├── notebooks/
│   ├── 01_eda.ipynb
│   ├── 02_baseline_mta.ipynb
│   ├── 03_shapley_mta.ipynb
│   ├── 04_mta_comparison.ipynb
│   ├── 05_experiment_design.ipynb
│   ├── 06_frequentist_analysis.ipynb
│   ├── 07_bayesian_analysis.ipynb
│   ├── 08_hte_analysis.ipynb
│   ├── 09_ltv_analysis.ipynb
│   └── 10_deployment_strategy.ipynb
└── assets/                   ← Chart exports for README embeds
```

---

*Project completed as part of a performance marketing portfolio. See also: [Marketing Mix Modelling project](link).*
