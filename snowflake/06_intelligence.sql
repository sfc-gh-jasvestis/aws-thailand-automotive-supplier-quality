-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live inspection alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_INSPECTIONS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic incoming-inspection SOPs (clearly synthetic, not audit or PPAP guidance) ----------
CREATE OR REPLACE TABLE SEARCH.QUALITY_SOP_DOCS AS
WITH signals AS (
  SELECT DISTINCT r.RISK_SIGNAL, s.CATEGORY
  FROM RAW.SUPPLIER_DAILY r JOIN RAW.SUPPLIERS s ON s.ID = r.ENTITY_ID
  WHERE r.CONFIRMED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, RISK_SIGNAL)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  RISK_SIGNAL,
  CATEGORY || ' - ' || RISK_SIGNAL || ' containment' AS TITLE,
  'Synthetic demo SOP for fictional automotive parts suppliers in Thailand; not supplier audit, PPAP or certification guidance. Part category: ' || CATEGORY || '. Exception signal: ' || RISK_SIGNAL || '. '
  || 'Step 1: place the affected lots on quality hold at incoming inspection, and notify the supplier quality engineer and the line buyer within 1 business day. '
  || 'Step 2: ' || CASE
       WHEN RISK_SIGNAL = 'Label or packaging error' THEN 'check every carton label against the part number, revision and lot number on the delivery note, and relabel or return cartons that do not match.'
       WHEN RISK_SIGNAL = 'Material certificate missing' THEN 'request the mill or material certificate for every heat or lot number in the delivery, and keep the lots on hold until each certificate matches the lot label.'
       WHEN RISK_SIGNAL = 'Surface defect found' THEN 'inspect a sample of panels under the light booth against the boundary sample, and sort the lot if dents, scratches or splits exceed the agreed limit.'
       WHEN RISK_SIGNAL = 'Burr height over limit' THEN 'measure burr height on a sample from each coil or die set, and ask the supplier for the die maintenance record for the affected run.'
       WHEN RISK_SIGNAL = 'Terminal crimp failure' THEN 'pull-test and section a sample of crimped terminals, and compare crimp height with the specification before releasing any harness sets.'
       WHEN RISK_SIGNAL = 'Dimensional deviation' THEN 'measure the key characteristics on a sample with the checking fixture or CMM, and compare the results with the drawing tolerance before releasing the lot.'
       WHEN RISK_SIGNAL = 'Colour mismatch' THEN 'compare the parts with the approved colour master under standard light, and hold the lot if the difference exceeds the agreed limit.'
       WHEN RISK_SIGNAL = 'Short shot detected' THEN 'sort the lot for incomplete fills, and ask the supplier for the moulding parameters and cavity numbers for the affected shift.'
       WHEN RISK_SIGNAL = 'Unannounced process change' THEN 'request the change notification and first-article data from the supplier, and keep the lot out of production until engineering signs off.'
       ELSE 'review the lot against the purchase order and the control plan, and escalate if unexplained.'
     END
  || ' Step 3: if the dimensional deviation exceeds 75% of the tolerance band or more than 3% of inspected parts are rejected, open an 8D supplier corrective action request. '
  || 'Step 4: record the outcome and the evidence; release the lot only with sign-off from the supplier quality lead.' AS CONTENT
FROM signals;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.QUALITY_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, RISK_SIGNAL
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, RISK_SIGNAL, CONTENT FROM SEARCH.QUALITY_SOP_DOCS);

-- ---------- Dimensional deviation anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.DIM_DEVIATION_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, DIM_DEVIATION_PCT::FLOAT AS DIM_DEVIATION
FROM RAW.SUPPLIER_DAILY;
CREATE OR REPLACE VIEW ML.DIM_DEVIATION_TRAIN AS
SELECT * FROM ML.DIM_DEVIATION_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.DIM_DEVIATION_SERIES);
CREATE OR REPLACE VIEW ML.DIM_DEVIATION_DETECT AS
SELECT * FROM ML.DIM_DEVIATION_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.DIM_DEVIATION_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.DIM_DEVIATION_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.DIM_DEVIATION_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'DIM_DEVIATION',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.DIM_DEVIATION_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS DIM_DEVIATION, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.DIM_DEVIATION_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.DIM_DEVIATION_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'DIM_DEVIATION'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.SUPPLIER_QUALITY_ANALYTICS
  TABLES (
    suppliers AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'suppliers', 'component suppliers')
      COMMENT = 'One row per supplier (city x part category), 90-day totals',
    risk AS ML.NCR_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day probability of a confirmed non-conformance per supplier',
    signals AS CURATED.SIGNAL_SUMMARY PRIMARY KEY (RISK_SIGNAL)
      COMMENT = 'Quality exception flags, confirmed non-conformances and quarantined lots by exception signal, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_supplier AS risk (ENTITY_ID) REFERENCES suppliers)
  FACTS (
    suppliers.lots_f AS LOT_COUNT,
    suppliers.accepted_f AS ACCEPTED_KPARTS,
    suppliers.inspected_f AS INSPECTED_KPARTS,
    suppliers.flags_f AS FLAG_COUNT,
    suppliers.confirmed_f AS CONFIRMED_COUNT,
    suppliers.quarantined_f AS QUARANTINED_COUNT,
    suppliers.review_due_f AS REVIEW_DUE,
    suppliers.review_done_f AS REVIEW_DONE,
    risk.ncr_prob_f AS NCR_PROB_7D,
    signals.sig_flags_f AS FLAG_COUNT,
    signals.sig_confirmed_f AS CONFIRMED_COUNT,
    signals.sig_quarantined_f AS QUARANTINED_COUNT,
    daily.day_lots_f AS LOT_COUNT,
    daily.day_accepted_f AS ACCEPTED_KPARTS,
    daily.day_inspected_f AS INSPECTED_KPARTS,
    daily.day_flags_f AS FLAG_COUNT
  )
  DIMENSIONS (
    suppliers.supplier_id AS ENTITY_ID WITH SYNONYMS = ('entity', 'supplier', 'supplier id'),
    suppliers.supplier_name AS ENTITY_NAME,
    suppliers.city AS REGION WITH SYNONYMS = ('city', 'region', 'supplier location') COMMENT = 'Thai city of the supplier plant',
    suppliers.part_category AS CATEGORY WITH SYNONYMS = ('part category', 'supplier type', 'category'),
    suppliers.risk_tier AS RISK_TIER COMMENT = 'Supply risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    signals.risk_signal AS RISK_SIGNAL WITH SYNONYMS = ('signal', 'exception signal', 'quality exception'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    suppliers.supplier_count AS COUNT(suppliers.supplier_id) WITH SYNONYMS = ('number of entities', 'number of suppliers'),
    suppliers.accept_quantity_pct AS 100 * SUM(suppliers.accepted_f) / NULLIF(SUM(suppliers.inspected_f), 0)
      COMMENT = 'Parts accepted at first-pass incoming inspection / parts inspected',
    suppliers.total_lots AS SUM(suppliers.lots_f) WITH SYNONYMS = ('inspection lots', 'lots received'),
    suppliers.total_accepted_kparts AS SUM(suppliers.accepted_f) WITH SYNONYMS = ('accepted parts', 'thousand parts accepted'),
    suppliers.total_inspected_kparts AS SUM(suppliers.inspected_f) WITH SYNONYMS = ('parts inspected', 'thousand parts inspected'),
    suppliers.total_flags AS SUM(suppliers.flags_f) WITH SYNONYMS = ('quality exception flags', 'flags'),
    suppliers.total_confirmed AS SUM(suppliers.confirmed_f) WITH SYNONYMS = ('confirmed non-conformances', 'confirmed NCRs'),
    suppliers.total_quarantined AS SUM(suppliers.quarantined_f) WITH SYNONYMS = ('quarantined lots', 'lots quarantined'),
    suppliers.flag_precision_pct AS 100 * SUM(suppliers.confirmed_f) / NULLIF(SUM(suppliers.flags_f), 0)
      COMMENT = 'Confirmed non-conformances / quality exception flags',
    suppliers.review_rate_pct AS 100 * SUM(suppliers.review_done_f) / NULLIF(SUM(suppliers.review_due_f), 0)
      COMMENT = 'Supplier quality reviews completed / reviews due',
    risk.avg_ncr_prob AS AVG(risk.ncr_prob_f),
    signals.signal_flags AS SUM(signals.sig_flags_f),
    signals.signal_confirmed AS SUM(signals.sig_confirmed_f),
    signals.signal_quarantined AS SUM(signals.sig_quarantined_f),
    signals.signal_precision_pct AS 100 * SUM(signals.sig_confirmed_f) / NULLIF(SUM(signals.sig_flags_f), 0),
    daily.daily_lots AS SUM(daily.day_lots_f),
    daily.daily_inspected_kparts AS SUM(daily.day_inspected_f),
    daily.daily_accept_pct AS 100 * SUM(daily.day_accepted_f) / NULLIF(SUM(daily.day_inspected_f), 0),
    daily.daily_flags AS SUM(daily.day_flags_f)
  )
  COMMENT = 'Synthetic Thailand automotive supplier quality analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.SUPPLIER_QUALITY_AGENT
  COMMENT = 'Supplier quality assistant over synthetic Thailand automotive parts suppliers'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic and that quality exception checks are demo signals, not supplier audit, PPAP or certification verdicts. Give supplier IDs and numbers with units."
  orchestration: "Use quality_analyst for inspection lots, parts inspected and parts accepted, first-pass acceptance, quality exception flags, confirmed non-conformances, quarantined lots, supplier quality reviews, cities, part categories, exception signals and non-conformance risk. Use sop_search for containment procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: quality_analyst
      description: "Inspection lots, parts inspected, first-pass acceptance, quality exception flags, confirmed non-conformances, quarantined lots, flag precision, quality review completion, exception signals and non-conformance risk scores by supplier"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic incoming-inspection containment SOPs by part category and exception signal"
tool_resources:
  quality_analyst:
    semantic_view: __DEMO_DB__.APP.SUPPLIER_QUALITY_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.QUALITY_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live inspection alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), SUPPLIER_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, LOT_KPARTS FLOAT, DIM_DEVIATION_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION TH_AUTOMOTIVE_SUPPLIER_QUALITY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_FLAGS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (SUPPLIER_ID, EVENT_TS, LOT_KPARTS, DIM_DEVIATION_PCT, SOP_HINT)
    SELECT c.SUPPLIER_ID, c.EVENT_TS, c.LOT_KPARTS, c.DIM_DEVIATION_PCT,
           'Check ' || m.CATEGORY || ' containment SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_INSPECTIONS c
    JOIN RAW.SUPPLIERS m ON m.ID = c.SUPPLIER_ID
    LEFT JOIN ML.NCR_RISK_SCORES r ON r.ENTITY_ID = c.SUPPLIER_ID
    WHERE c.STATUS = 'FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SUPPLIER_ID = c.SUPPLIER_ID AND l.EVENT_TS = c.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('TH_AUTOMOTIVE_SUPPLIER_QUALITY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Incoming inspection exception alert',
      'New flagged live inspection lots logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_INSPECTION_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_INSPECTIONS c
    WHERE c.STATUS = 'FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SUPPLIER_ID = c.SUPPLIER_ID AND l.EVENT_TS = c.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_FLAGS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.SIGNAL_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.NCR_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.QUALITY_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.NCR_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'PROGRAM_YEARS', PROGRAM_YEARS,
             'DIM_DEVIATION_PCT', DIM_DEVIATION_PCT, 'REJECT_PCT', REJECT_PCT,
             'DIM_DEVIATION_7D', DIM_DEVIATION_7D, 'CONFIRMED_30D', CONFIRMED_30D,
           'DAYS_SINCE_REVIEW', DAYS_SINCE_REVIEW, 'REVIEW_RATE_30D', REVIEW_RATE_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:NCR::FLOAT, 4) AS NCR_PROB_7D,
         CASE WHEN PRED:probability:NCR::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:NCR::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
