-- Synthetic incoming-inspection observations for fictional tier-1 and tier-2
-- automotive parts suppliers in Thailand. 40 suppliers = 8 cities x 5 part
-- categories. Nothing is seeded as a prediction. Randomness is HASH-seeded, so
-- every rebuild is reproducible: per-supplier non-conformance propensity, drift
-- between periodic supplier quality reviews, skipped reviews, category-weighted
-- exception signals, false-positive exception flags, and two area-wide
-- inspection lab system outages. Exception checks are demo signals, not
-- supplier audit, PPAP or certification verdicts.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.SUPPLIERS AS
WITH suppliers AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SUPPLIER_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT SUPPLIER_INDEX,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'thasq-program')), 1000000) / 1e6 AS U_PROGRAM,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'thasq-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'thasq-review')), 1000000) / 1e6 AS U_REVIEW,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'thasq-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'thasq-tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(SUPPLIER_INDEX, 'thasq-size')), 1000000) / 1e6 AS U_SIZE
  FROM suppliers
), suppliers_named AS (
  SELECT *,
         -- Every city x part category combination appears exactly once.
         CASE MOD(SUPPLIER_INDEX, 8) WHEN 0 THEN 'Rayong' WHEN 1 THEN 'Chon Buri'
              WHEN 2 THEN 'Chachoengsao' WHEN 3 THEN 'Ayutthaya' WHEN 4 THEN 'Samut Prakan'
              WHEN 5 THEN 'Pathum Thani' WHEN 6 THEN 'Prachin Buri'
              ELSE 'Nakhon Ratchasima' END AS REGION,
         CASE FLOOR(SUPPLIER_INDEX / 8) WHEN 0 THEN 'Fastener supplier'
              WHEN 1 THEN 'Stamping supplier' WHEN 2 THEN 'Wire harness supplier'
              WHEN 3 THEN 'Plastic moulding supplier' ELSE 'Brake component supplier' END AS CATEGORY
  FROM draws
)
SELECT 'SUP-' || LPAD(SUPPLIER_INDEX::VARCHAR, 4, '0') AS ID,
       REGION || ' ' || CATEGORY AS NAME,
       REGION, CATEGORY, SUPPLIER_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.5 + U_PROGRAM * 9.5, 1) AS PROGRAM_YEARS,
       ROUND(0.6 + U_SIZE * 0.8, 3) AS SIZE_FACTOR,
       -- Base daily probability of a confirmed non-conformance, higher for
       -- process-sensitive categories; ~15% of suppliers are weak links (x3).
       (0.004 + U_RATE * 0.019)
         * CASE CATEGORY WHEN 'Fastener supplier' THEN 0.5 WHEN 'Stamping supplier' THEN 0.9
                         WHEN 'Wire harness supplier' THEN 1.4 WHEN 'Plastic moulding supplier' THEN 1.2
                         ELSE 1.1 END
         * IFF(U_RATE > 0.85, 3, 1) AS BASE_NCR_RATE,
       7 * (1 + FLOOR(U_REVIEW * 3)) AS REVIEW_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS REVIEW_RETURN_PROB,
       -- Share of inspected parts typically rejected at incoming inspection (%).
       CASE CATEGORY WHEN 'Fastener supplier' THEN 0.4 WHEN 'Stamping supplier' THEN 1.1
                     WHEN 'Wire harness supplier' THEN 2.2 WHEN 'Plastic moulding supplier' THEN 1.7
                     ELSE 0.9 END AS BASE_REJECT_PCT,
       'Active' AS STATUS
FROM suppliers_named;

CREATE TABLE RAW.SUPPLIER_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), outage_events AS (
  -- Two area-wide inspection lab system outages; every supplier in the city gets a flag.
  SELECT * FROM VALUES (34, 'Chon Buri'), (71, 'Ayutthaya') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.SUPPLIER_INDEX, s.CATEGORY, s.REGION, s.PROGRAM_YEARS,
         s.SIZE_FACTOR, s.BASE_REJECT_PCT,
         s.BASE_NCR_RATE, s.REVIEW_INTERVAL_DAYS, s.REVIEW_RETURN_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.SUPPLIER_INDEX * 5, s.REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_REVIEW,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-ncr')), 1000000) / 1e6 AS U_NCR,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-fp')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-signal')), 1000000) / 1e6 AS U_SIG,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-lot')), 1000000) / 1e6 AS U_LOT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thasq-hold')), 1000000) / 1e6 AS U_HOLD,
         o.REGION IS NOT NULL AS OUTAGE_EVENT
  FROM RAW.SUPPLIERS s CROSS JOIN days d
  LEFT JOIN outage_events o ON o.DAY_INDEX = d.DAY_INDEX AND o.REGION = s.REGION
), reviews AS (
  SELECT *,
         IFF(DAYS_SINCE_REVIEW = 0, 1, 0) AS REVIEW_DUE,
         IFF(DAYS_SINCE_REVIEW = 0 AND U_DONE < REVIEW_RETURN_PROB, 1, 0) AS REVIEW_DONE,
         -- Process drift rises between supplier quality reviews; weak follow-up carries it over.
         DAYS_SINCE_REVIEW / REVIEW_INTERVAL_DAYS + (1 - REVIEW_RETURN_PROB) AS DRIFT
  FROM base
), activity AS (
  SELECT *,
         CASE WHEN U_NCR < LEAST(0.5, BASE_NCR_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAM_YEARS))) / 4 THEN 2
              WHEN U_NCR < LEAST(0.5, BASE_NCR_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PROGRAM_YEARS))) THEN 1
              ELSE 0 END AS NCR_COUNT
  FROM reviews
), checks AS (
  SELECT *,
         -- Incoming inspection confirms about 80% of non-conformances; the rest stays undetected.
         IFF(OUTAGE_EVENT, 0, IFF(U_DETECT < 0.80, NCR_COUNT, 0)) AS CONFIRMED_COUNT,
         -- False-positive flags (cleared on re-inspection): higher where the part is harder to gauge.
         IFF(OUTAGE_EVENT, 1, IFF(U_FP < CASE CATEGORY WHEN 'Wire harness supplier' THEN 0.14
                                              WHEN 'Plastic moulding supplier' THEN 0.13
                                              WHEN 'Brake component supplier' THEN 0.11
                                              WHEN 'Stamping supplier' THEN 0.10 ELSE 0.05 END, 1, 0)) AS FALSE_POSITIVE_COUNT
  FROM activity
), measured AS (
  SELECT *,
         CONFIRMED_COUNT + FALSE_POSITIVE_COUNT AS FLAG_COUNT,
         ROUND(CASE CATEGORY WHEN 'Fastener supplier' THEN 7 WHEN 'Stamping supplier' THEN 5
                             WHEN 'Wire harness supplier' THEN 6 WHEN 'Plastic moulding supplier' THEN 8 ELSE 4 END
               * SIZE_FACTOR * (0.7 + 0.6 * U_LOT)) AS LOT_COUNT,
         -- Thousand parts (bolts, panels, harness sets, mouldings, brake parts) per inspection lot.
         CASE CATEGORY WHEN 'Fastener supplier' THEN 48 WHEN 'Stamping supplier' THEN 3.5
                       WHEN 'Wire harness supplier' THEN 1.2 WHEN 'Plastic moulding supplier' THEN 6
                       ELSE 2.4 END
           * (0.9 + 0.2 * U_NOISE) AS AVG_LOT_KPARTS,
         LEAST(40, BASE_REJECT_PCT + 0.7 * DRIFT + 2.6 * NCR_COUNT + 0.5 * U_NOISE) AS REJECT_SHARE
  FROM checks
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       LOT_COUNT,
       ROUND(LOT_COUNT * AVG_LOT_KPARTS * (1 - REJECT_SHARE / 100), 3) AS ACCEPTED_KPARTS,
       ROUND(LOT_COUNT * AVG_LOT_KPARTS, 3) AS INSPECTED_KPARTS,
       FLAG_COUNT, CONFIRMED_COUNT,
       IFF(CONFIRMED_COUNT > 0 AND U_HOLD < 0.5, 1, 0) AS LOTS_QUARANTINED,
       CASE WHEN FLAG_COUNT = 0 THEN 'None'
            WHEN OUTAGE_EVENT THEN 'Inspection lab system outage'
            WHEN CATEGORY = 'Fastener supplier' THEN IFF(U_SIG < 0.6, 'Label or packaging error', 'Material certificate missing')
            WHEN CATEGORY = 'Stamping supplier' THEN IFF(U_SIG < 0.55, 'Surface defect found', 'Burr height over limit')
            WHEN CATEGORY = 'Wire harness supplier' THEN IFF(U_SIG < 0.45, 'Terminal crimp failure', IFF(U_SIG < 0.8, 'Dimensional deviation', 'Label or packaging error'))
            WHEN CATEGORY = 'Plastic moulding supplier' THEN IFF(U_SIG < 0.55, 'Colour mismatch', 'Short shot detected')
            ELSE IFF(U_SIG < 0.5, 'Unannounced process change', 'Dimensional deviation') END AS RISK_SIGNAL,
       REVIEW_DUE, REVIEW_DONE,
       -- Measured deviation from nominal on the key characteristic, as % of the tolerance band.
       ROUND(18 + 14 * DRIFT + 21 * NCR_COUNT + 9 * U_NOISE, 2) AS DIM_DEVIATION_PCT,
       ROUND(REJECT_SHARE, 2) AS REJECT_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- PPAP snapshot per supplier: active part numbers, parts with an approved
-- production part approval (PPAP) on file, and PPAP submissions in progress.
CREATE TABLE RAW.PPAP_STATUS AS
WITH sized AS (
  SELECT ID, CATEGORY,
         ROUND(CASE CATEGORY WHEN 'Fastener supplier' THEN 140 WHEN 'Stamping supplier' THEN 90
                             WHEN 'Wire harness supplier' THEN 220 WHEN 'Plastic moulding supplier' THEN 160 ELSE 70 END
               * (0.6 + MOD(ABS(HASH(ID, 'thasq-parts')), 1000000) / 1e6 * 0.8)) AS PARTS,
         CASE CATEGORY WHEN 'Fastener supplier' THEN 0.82 WHEN 'Stamping supplier' THEN 0.74
                       WHEN 'Wire harness supplier' THEN 0.58 WHEN 'Plastic moulding supplier' THEN 0.69 ELSE 0.63 END
           + MOD(ABS(HASH(ID, 'thasq-approved')), 1000000) / 1e6 * 0.15 AS APPROVED_SHARE
  FROM RAW.SUPPLIERS
)
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Fastener supplier' THEN 'Fastener PPAP'
                     WHEN 'Stamping supplier' THEN 'Stamped part PPAP'
                     WHEN 'Wire harness supplier' THEN 'Harness assembly PPAP'
                     WHEN 'Plastic moulding supplier' THEN 'Moulded part PPAP'
                     ELSE 'Brake part PPAP' END AS EVIDENCE_TYPE,
       PARTS AS REQUIRED_QTY,
       LEAST(PARTS, ROUND(PARTS * APPROVED_SHARE)) AS ON_FILE_QTY,
       ROUND((PARTS - LEAST(PARTS, ROUND(PARTS * APPROVED_SHARE))) * MOD(ABS(HASH(ID, 'thasq-pending')), 1000000) / 1e6 * 0.6) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM sized;
