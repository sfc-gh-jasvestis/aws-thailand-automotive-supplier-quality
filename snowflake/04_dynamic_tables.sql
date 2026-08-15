-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Supplier Quality Management
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA CURATED;

-- SUPPLIER_RISK_SCORES: Real-time supplier risk scoring based on NCRs, audits, and inspections
-- Source: SUPPLIERS, NON_CONFORMANCES, INCOMING_INSPECTION
CREATE OR REPLACE DYNAMIC TABLE CURATED.SUPPLIER_RISK_SCORES
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SUPPLIER_WH
AS
SELECT * FROM RAW.SUPPLIERS;
-- TODO: Replace with actual join/aggregation logic per demo

-- NCR_TRENDS: Non-conformance trend analysis by supplier and category
-- Source: NON_CONFORMANCES
CREATE OR REPLACE DYNAMIC TABLE CURATED.NCR_TRENDS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SUPPLIER_WH
AS
SELECT * FROM RAW.NON_CONFORMANCES;
-- TODO: Replace with actual join/aggregation logic per demo

-- AUDIT_COMPLIANCE: Audit schedule compliance and overdue tracking
-- Source: SUPPLIERS, AUDIT_REPORTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.AUDIT_COMPLIANCE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SUPPLIER_WH
AS
SELECT * FROM RAW.SUPPLIERS;
-- TODO: Replace with actual join/aggregation logic per demo

-- COPQ_SUMMARY: Cost of Poor Quality aggregation by supplier and defect type
-- Source: NON_CONFORMANCES, INCOMING_INSPECTION
CREATE OR REPLACE DYNAMIC TABLE CURATED.COPQ_SUMMARY
  TARGET_LAG = '5 minutes'
  WAREHOUSE = SUPPLIER_WH
AS
SELECT * FROM RAW.NON_CONFORMANCES;
-- TODO: Replace with actual join/aggregation logic per demo

