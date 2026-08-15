# Demo Script: Supplier Quality Management
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake ingests and parses supplier audit documents, indexes Thai automotive quality standards for instant retrieval, classifies supplier risk, and alerts procurement — replacing manual compliance tracking with AI-native workflows"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Prasert Thanapatpisal** | Head of Supplier Quality | React App (SPCS) | Supplier risk scores, non-conformance trends, audit compliance rates, cost of poor quality |
| **Nattaya Siriphanich** | Quality Assurance Engineer | Amazon QuickSight | Audit findings, corrective action tracking, IATF 16949 compliance, document traceability |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 8 tables | SUPPLIERS (220), AUDIT_REPORTS (450), NON_CONFORMANCES (3200), CORRECTIVE_ACTIONS (2800), QUALITY_STANDARDS (150), INCOMING_INSPECTION (50000), SUPPLIER_SCORECARDS (2640), THAI_AUTO_INDUSTRY (10) |
| **CURATED** | 4 Dynamic Tables | SUPPLIER_RISK_SCORES, NCR_TRENDS, AUDIT_COMPLIANCE, COPQ_SUMMARY |
| **ML** | ML.FORECAST + ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | AI_PARSE_DOCUMENT, AI_CLASSIFY, SUMMARIZE | Classification + extraction |
| **Search** | Cortex Search | 150 documents indexed |
| **Agent** | SUPPLIER_QUALITY_AGENT | Semantic View + Search tools |


---

## The Story

Thailand produces 1.88 million vehicles annually with 220+ tier-1 suppliers across the Eastern Seaboard. Manual audit tracking and paper-based compliance create blind spots — 14 suppliers are silently degrading in quality, generating ฿1.2B in annual Cost of Poor Quality that traditional scorecards detect months too late.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "One point two billion baht in Cost of Poor Quality across 220 suppliers this year."

**Action**: Point at the ฿1.2B COPQ KPI card

### [0:45–1:30] SUPPLIER RISK ANALYSIS

**Show**: Supplier Risk Analysis tab

> "Supplier S-0047 (Siam Parts Manufacturing) — risk score 92, twelve NCRs in 90 days."

**Action**: Click S-0047 in the risk-ranked supplier list

### [1:30–2:15] STANDARDS & COMPLIANCE

**Show**: Standards & Compliance tab

> "Cortex Search indexes 150 quality standards — IATF 16949, TISI, and OEM-specific requirements."

**Action**: Demo a Cortex Search query

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Prasert asks: 'Which suppliers have the highest COPQ this quarter?'"

**Action**: Type: 'Top 5 suppliers by COPQ this quarter'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Seven Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **AI_PARSE_DOCUMENT on supplier audit PDFs** — Only demo extracting structured quality data from Thai-language audit documents
2. **Cortex Search on IATF 16949 + Thai standards** — Natural language search across automotive quality standards for instant compliance lookup
3. **Supplier risk scoring via Dynamic Tables** — Real-time risk scores combining NCRs, inspections, and audit findings
4. **Thai automotive supply chain context** — 220 realistic Thai supplier names with Eastern Seaboard industrial zone locations
5. **Document-to-insight pipeline** — End-to-end: PDF upload → parse → classify → search → alert in one platform
6. **COPQ calculation with AI root-cause** — Automated Cost of Poor Quality attribution with AI-generated corrective actions


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM SUPPLIER_QUALITY.RAW.AUDIT_REPORTS` → 450
- [ ] `SELECT COUNT(*) FROM SUPPLIER_QUALITY.RAW.NON_CONFORMANCES` → 3200
- [ ] `SELECT COUNT(*) FROM SUPPLIER_QUALITY.CURATED.SUPPLIER_RISK_SCORES WHERE RISK_SCORE > 80` → 14

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM SUPPLIER_QUALITY.ML.NCR_FORECAST_RESULTS` → >0
- [ ] `SELECT SUM(CASE WHEN IS_ANOMALY THEN 1 ELSE 0 END) FROM SUPPLIER_QUALITY.ML.SUPPLIER_ANOMALY_RESULTS WHERE SERIES = 'S-0047'` → >=6

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM SUPPLIER_QUALITY.AI.PARSED_AUDIT_FINDINGS` → >400

