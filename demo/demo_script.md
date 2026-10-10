# Automotive Supplier Quality

**Thailand - Automotive parts supply base**
Use case: First-pass acceptance and non-conformance risk for parts suppliers feeding a fictional vehicle assembly plant

> 40 fictional automotive parts suppliers from Rayong to Nakhon Ratchasima, tracked from supplier delivery to incoming inspection: dynamic tables for first-pass acceptance, a holdout-evaluated non-conformance classifier, an inspection lot forecast and grounded AI answers. Exception checks are demo signals, not supplier audit, PPAP or certification verdicts.

## Why Snowflake

- **Dynamic tables** reconcile inspection lots, first-pass acceptance, exception flags, confirmed non-conformances and quality review completion from RAW supplier data, with checks in `run_core.py`
- **Non-conformance classification** gives a holdout-evaluated next-7-day probability per supplier
- **Lot forecast** projects 14 days of network-wide inspection lots with prediction intervals, for incoming inspection staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live inspections**: a native inspection simulator (Snowflake only) or Amazon Data Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.SUPPLIERS` (40 rows) |
| Fact table | `RAW.SUPPLIER_DAILY` (3,600 supplier-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `SIGNAL_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.NCR_RISK_SCORES`, `ML.NCR_RISK_HOLDOUT_METRICS`, `ML.LOT_FORECAST`, `ML.DIM_DEVIATION_ANOMALIES` |

Cities: Rayong, Chon Buri, Chachoengsao, Ayutthaya, Samut Prakan, Pathum Thani, Prachin Buri, Nakhon Ratchasima.
Part categories: Fastener supplier, Stamping supplier, Wire harness supplier, Plastic moulding supplier, Brake component supplier.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| First-Pass Acceptance (parts) | 98.6% |
| Inspection Lots Received | 22,623 |
| Parts Inspected (millions) | 300 |
| Quality Exception Flags | 527 |
| Confirmed Non-Conformances | 128 |
| Flag Precision | 24.3% |
| Lots Quarantined at Receiving | 46 |
| Quality Review Completion | 76.0% |
| Suppliers Monitored | 40 |
| PPAP Approval Coverage | 75.0% |
| PPAP Submissions Pending | 378 |
| Active Part Numbers | 5,607 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily inspection lots against exception flags, flags and confirmed non-conformances by exception signal, supplier table
2. Predictive: holdout metrics, risk bands, 14-day inspection lot forecast, dimensional deviation anomalies
3. Reviews & PPAP: quality review completion, PPAP approval coverage and pending submissions, review completion against confirmed non-conformances, then generate the action memo
4. Live Inspections: run `CALL APP.SIMULATE_INSPECTIONS(20)` (Snowflake only) or `python aws/publish_inspections.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_INSPECTION_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About one exception flag in four is confirmed as a non-conformance (24.3%). The rest are cleared on re-inspection, and that is where the supplier quality team loses its week.
- "Unannounced process change" produces the most confirmed non-conformances (26 of 57 flags), while "Dimensional deviation" raises the most flags (123). Inspection lab system outage flags hit every supplier in a city at once and are never confirmed.
- SUP-0030 (Prachin Buri plastic moulding supplier) has the most confirmed non-conformances (20), and wire harness suppliers have the lowest first-pass acceptance (96.9%).
- The risk model is evaluated on a time-based holdout: precision 0.43 and recall 0.19 at 0.5, against a 0.20 base rate. Use it to order supplier calls, not as a verdict. Forecast and anomaly figures can shift slightly with the build day.
- Inspection lab outage days are excluded from model training, because the supplier did not cause them.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
