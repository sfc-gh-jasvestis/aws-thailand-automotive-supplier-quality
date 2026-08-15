-- ============================================================================
-- Supplier Quality Management
-- AI-powered supplier quality management for 200+ tier-1 automotive suppliers — Textract parses audit reports, Cortex Search indexes quality standards, and AI_PARSE_DOCUMENT extracts non-conformance data across Thailand's automotive supply chain.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS SUPPLIER_QUALITY;
CREATE WAREHOUSE IF NOT EXISTS SUPPLIER_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE SUPPLIER_QUALITY;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE SUPPLIER_WH;
