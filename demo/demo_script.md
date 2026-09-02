# Supplier Quality Management

**Thailand - Automotive Manufacturing**
Use case: Supplier Quality & Compliance

> AI-powered supplier quality management for 200+ tier-1 automotive suppliers — Textract parses audit reports, Cortex Search indexes quality standards, and AI_PARSE_DOCUMENT extracts non-conformance data across Thailand's automotive supply chain.

## Why Snowflake

Snowflake ingests and parses supplier audit documents, indexes Thai automotive quality standards for instant retrieval, classifies supplier risk, and alerts procurement — replacing manual compliance tracking with AI-native workflows

- **AI_PARSE_DOCUMENT on supplier audit PDFs** - Only demo extracting structured quality data from Thai-language audit documents
- **Cortex Search on IATF 16949 + Thai standards** - Natural language search across automotive quality standards for instant compliance lookup
- **Supplier risk scoring via Dynamic Tables** - Real-time risk scores combining NCRs, inspections, and audit findings
- **Thai automotive supply chain context** - 220 realistic Thai supplier names with Eastern Seaboard industrial zone locations
- **Document-to-insight pipeline** - End-to-end: PDF upload → parse → classify → search → alert in one platform
- **COPQ calculation with AI root-cause** - Automated Cost of Poor Quality attribution with AI-generated corrective actions

## What is deployed

| | |
|---|---|
| Database | `THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY` |
| Service | `THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY_APP` |
| Compute pool | `SEA_DEMOS_THAILAND_POOL` |
| Dimension table | `RAW.THAI_AUTO_INDUSTRY` (20 rows) |
| Fact table | `RAW.INCOMING_INSPECTION` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | THB (฿) |

Regions in play: Bangkok, Chonburi, Rayong, Chiang Mai, Songkhla
Segments: Tier 1 Stamping, Tier 1 Electronics, Tier 2 Casting, Tier 2 Rubber

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh THAILAND_AUTOMOTIVE_SUPPLIER_QUALITY
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Supplier PPM (Avg) | `34` | average per event |
| Critical NCRs Open | `7` | total across Thai Auto Industry |
| On-Time Delivery | `94.7%` | average per event |
| Active Suppliers | `248` | total across Thai Auto Industry |
| At-Risk Suppliers | `12` | average per event |
| Dual-Source Coverage | `78%` | average per event |
| Avg Lead Time | `14 days` | average per event |


## Demo flow

1. Executive Cockpit
2. Supplier Risk Analysis
3. Standards & Compliance
4. Ask AI
5. Architecture & Data

## Talking points

- **฿1.2B** - annual Cost of Poor Quality across 220 suppliers (US$34M)
- **14 suppliers** - flagged HIGH RISK (score > 80)
- **23 audits** - overdue by more than 30 days
- **450 PDFs** - parsed by AI_PARSE_DOCUMENT into structured findings
- **3,200 NCRs** - tracked with AI-classified severity
- **150 standards** - indexed in Cortex Search for instant compliance lookup

## Business impact

- Thailand produced 1.88 million vehicles in 2023, ranking 12th globally with ฿2.5T in exports (FTI Thailand)
- AI-powered supplier quality management reduces COPQ by 20-35% in automotive manufacturing (McKinsey Automotive)
- Document AI processing reduces audit review time by 70%, catching 40% more non-conformances (Deloitte Digital)
- Toyota Thailand operates 500+ supplier quality audits annually across its Thai supply base (Toyota Thailand)

---
Generated from `generator/demo_specs/aws-thailand-automotive-supplier-quality.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-thailand-automotive-supplier-quality` instead.
