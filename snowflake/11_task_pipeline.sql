-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Supplier Quality Management
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_PARSE_NEW_AUDITS
  WAREHOUSE = SUPPLIER_WH
  SCHEDULE = 'USING CRON 0 6 * * * UTC'
  COMMENT = 'Parse newly uploaded audit PDFs with AI_PARSE_DOCUMENT'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_REFRESH_RISK_SCORES
  WAREHOUSE = SUPPLIER_WH
  AFTER APP.TASK_PARSE_NEW_AUDITS
  COMMENT = 'Recalculate supplier risk scores'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_EXPORT_ICEBERG
  WAREHOUSE = SUPPLIER_WH
  AFTER APP.TASK_REFRESH_RISK_SCORES
  COMMENT = 'Export to Iceberg for QuickSight'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_EXPORT_ICEBERG RESUME;
ALTER TASK APP.TASK_REFRESH_RISK_SCORES RESUME;
ALTER TASK APP.TASK_PARSE_NEW_AUDITS RESUME;
