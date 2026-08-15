-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Supplier Quality Management
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.QUALITY_STANDARDS_SEARCH
  ON CONTENT
  ATTRIBUTES STANDARD_TYPE, SECTION, APPLICABILITY
  WAREHOUSE = SUPPLIER_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.QUALITY_STANDARDS
);
