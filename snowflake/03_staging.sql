-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Supplier Quality Management
-- Country: THAILAND | Currency: THB
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- SUPPLIERS: 220 rows — Tier-1 and tier-2 automotive suppliers in Thailand
-- AUDIT_REPORTS: 450 rows — Supplier audit reports (PDF parsed via Textract/AI_PARSE_DOCUMENT)
-- NON_CONFORMANCES: 3,200 rows — Non-conformance records (NCRs) with severity and root cause
-- CORRECTIVE_ACTIONS: 2,800 rows — CAPA records linked to NCRs
-- QUALITY_STANDARDS: 150 rows — IATF 16949, Thai Industrial Standards, OEM-specific requirements
-- INCOMING_INSPECTION: 50,000 rows — Incoming material inspection results by lot
-- SUPPLIER_SCORECARDS: 2,640 rows — Monthly supplier performance scorecards (12 months × 220 suppliers)
-- THAI_AUTO_INDUSTRY: 10 rows — Thailand automotive industry context and export data
