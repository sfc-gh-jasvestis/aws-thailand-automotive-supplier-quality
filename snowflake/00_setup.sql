-- Generated from generator/demo_specs/aws-thailand-automotive-supplier-quality.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-thailand-automotive-supplier-quality
-- This is the schema that is actually deployed for THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY.

-- THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY  (Supplier Quality Management)
-- generated from generator/demo_specs/aws-thailand-automotive-supplier-quality.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY;
CREATE SCHEMA IF NOT EXISTS THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY.RAW;
CREATE SCHEMA IF NOT EXISTS THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY.CURATED;
CREATE SCHEMA IF NOT EXISTS THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY.APP;
USE DATABASE THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY;

-- 5 real regions; entity names carry their region so the two always agree
