-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Supplier Quality Management
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.SUPPLIER_QUALITY_ANALYTICS
  COMMENT = 'Supplier quality, risk scoring, and compliance analytics'
AS
  TABLES (
    CURATED.SUPPLIER_RISK_SCORES AS supplier_risk_scores,CURATED.NCR_TRENDS AS ncr_trends,CURATED.AUDIT_COMPLIANCE AS audit_compliance,CURATED.COPQ_SUMMARY AS copq_summary
  );
