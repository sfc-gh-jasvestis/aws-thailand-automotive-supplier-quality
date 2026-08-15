-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Supplier Quality Management
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.SUPPLIER_QUALITY_AGENT
  COMMENT = 'Supplier Quality Management AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'SUPPLIER_QUALITY.APP.SUPPLIER_QUALITY_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'SUPPLIER_QUALITY.SEARCH.QUALITY_STANDARDS_SEARCH', TOOL_DESCRIPTION => 'Search documents for Automotive Manufacturing information')
  )
  SYSTEM_PROMPT = 'You are the Supplier Quality Agent for 220 automotive suppliers across Thailand''s Eastern Seaboard industrial zone.';
