-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Supplier Quality Management
-- ============================================================================
USE DATABASE SUPPLIER_QUALITY;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_thailand_automotive_supplier_quality_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: SUPPLIER_RISK_ALERT
CREATE OR REPLACE ALERT APP.SUPPLIER_RISK_ALERT
  WAREHOUSE = SUPPLIER_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Supplier risk score exceeds critical threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.SUPPLIER_RISK_SCORES
  WHERE 1=1 -- Condition: RISK_SCORE > 80 for any supplier
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_automotive_supplier_quality_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Supplier Quality Management: Supplier risk score exceeds critical threshold',
    'Supplier risk score exceeds critical threshold'
  );

ALTER ALERT APP.SUPPLIER_RISK_ALERT RESUME;

-- Alert: AUDIT_OVERDUE_ALERT
CREATE OR REPLACE ALERT APP.AUDIT_OVERDUE_ALERT
  WAREHOUSE = SUPPLIER_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Supplier audit overdue by 30+ days'
IF (EXISTS (
  SELECT 1 FROM CURATED.SUPPLIER_RISK_SCORES
  WHERE 1=1 -- Condition: DAYS_OVERDUE > 30 for any scheduled audit
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_automotive_supplier_quality_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] Supplier Quality Management: Supplier audit overdue by 30+ days',
    'Supplier audit overdue by 30+ days'
  );

ALTER ALERT APP.AUDIT_OVERDUE_ALERT RESUME;

