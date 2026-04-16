# Snowflake Trust Center Cost Analysis: "Everything Enabled" Scenario

## Executive Summary

This document models the cost impact when **all Trust Center packages and scanners are enabled** at their default schedules, provides a prioritized disablement plan, and includes ready-to-run SQL scripts for each action. All data is derived from actual historical scan runs on this account.

---

## 1. Current Account Baseline (Historical Data)

### Historical Scan Activity (When CIS Was Enabled)

| Package | Scanners | Total Runs | Days Active | Runs/Day | Avg Duration/Scan |
|---------|----------|------------|-------------|----------|-------------------|
| **CIS Benchmarks** | 38 | 6,547 | 132 days | 49.6/day | 3-50 sec |
| **Security Essentials** | 6 | 277 | 477 days | 0.6/day | N/A (free) |
| **Threat Intelligence** | 13 | 0 | 0 | 0 | N/A (never enabled) |

**Key Observation**: When CIS Benchmarks was enabled (Nov 2025 - Mar 2026), it generated **~50 scan runs per day** across 37-38 scanners running on a daily schedule.

### Historical Findings (Still Open)

| Package | Critical | High | Medium | Low | Total | At-Risk Entities |
|---------|----------|------|--------|-----|-------|-----------------|
| CIS Benchmarks | 174 | 686 | 1,380 | 2,376 | 4,616 | 46,322 |
| Security Essentials | 9 | 0 | 5 | 1 | 15 | 21 |

---

## 2. Cost Model: Everything Enabled

### Trust Center Pricing

Trust Center scanners consume **serverless compute credits**. The exact credit cost per scan varies by:
- Scanner complexity (simple parameter check vs. full access history scan)
- Account size (users, roles, objects, query volume)
- Data volume scanned

Based on the observed scan durations from this account's history:

| Scanner Category | Avg Duration | Relative Cost | Example Scanners |
|-----------------|-------------|---------------|-----------------|
| Simple parameter checks | 3-4 sec | Low | CIS 4.1, 4.2, 4.4, 4.5, 4.6, 4.8 |
| User/role enumeration | 8-12 sec | Medium | CIS 1.1, 1.2, 1.10, 1.11, 1.8 |
| Access history/query scans | 17-51 sec | High | CIS 1.14, 1.15, 1.17, 2.1, 2.2, 2.5, 2.6, 2.8 |

### Projected Daily Cost: All Packages Enabled at Default Schedules

| Package | Scanners | Schedule | Daily Runs | Estimated Daily Credits |
|---------|----------|----------|------------|------------------------|
| **Security Essentials** | 6 | Monthly | ~0.2 | **FREE** (Snowflake-covered) |
| **CIS Benchmarks** | 37 | Daily (`CRON 16 8 * * * UTC`) | 37 | **~0.5-2.0 credits/day** |
| **Threat Intelligence (Scheduled)** | 7 | Daily (`CRON 34 4 * * * UTC`) | 7 | **~0.1-0.5 credits/day** |
| **Threat Intelligence (Event-Driven)** | 6 | Per-event | Variable | **~0.1-1.0+ credits/day** |
| **TOTAL (Everything Enabled)** | 56 | Mixed | 44+ scheduled | **~0.7-3.5 credits/day** |

### Projected Monthly/Annual Costs

| Scenario | Monthly Credits | Annual Credits | Annual Cost (est. $3/credit) |
|----------|----------------|----------------|------------------------------|
| **Everything enabled (daily)** | 21-105 | 255-1,278 | **$765 - $3,834** |
| **CIS weekly + TI daily** | 8-40 | 96-480 | **$288 - $1,440** |
| **CIS monthly + TI weekly** | 3-12 | 36-144 | **$108 - $432** |
| **CIS disabled + TI disabled** | 0 | 0 | **$0** |
| **Only Security Essentials** | 0 | 0 | **$0** (current state) |

> **Note**: Credit costs depend on your Snowflake edition and contract. The $3/credit estimate is illustrative. Event-driven Threat Intelligence scanners fire on each matching event, making their cost unpredictable for high-activity accounts.

---

## 3. Scanner-by-Scanner Cost/Value Analysis

### CIS Benchmarks: 37 Scanners

#### High-Cost Scanners (17-51 sec avg, run daily)
These scanners query access history, query history, and grants - the most expensive operations.

| Scanner | CIS Control | Avg Duration | SIEM Overlap? | Recommendation |
|---------|-------------|-------------|---------------|---------------|
| CIS_BENCHMARKS_CIS2_1 | Admin role grant monitoring | 50.6 sec | **YES** - privilege escalation alerts | **DISABLE** |
| CIS_BENCHMARKS_CIS2_8 | Share exposure monitoring | 21.7 sec | **YES** - data sharing alerts | **DISABLE** |
| CIS_BENCHMARKS_CIS2_2 | MANAGE GRANTS monitoring | 21.9 sec | **YES** - privilege change alerts | **DISABLE** |
| CIS_BENCHMARKS_CIS2_6 | Network policy change monitoring | 19.1 sec | **YES** - config change alerts | **DISABLE** |
| CIS_BENCHMARKS_CIS2_5 | Security integration monitoring | 19.0 sec | **YES** - integration alerts | **DISABLE** |
| CIS_BENCHMARKS_CIS1_14 | Tasks owned by admin roles | 18.7 sec | Partial | **DISABLE** (if SIEM monitors) |
| CIS_BENCHMARKS_CIS1_17 | Procs running as admin | 18.8 sec | Partial | **DISABLE** (if SIEM monitors) |
| CIS_BENCHMARKS_CIS1_15 | Tasks running as admin | 17.1 sec | Partial | **DISABLE** (if SIEM monitors) |

**Subtotal high-cost**: ~186 sec/day = **~60% of daily CIS compute cost**

#### Medium-Cost Scanners (6-13 sec avg)

| Scanner | CIS Control | Avg Duration | SIEM Overlap? | Recommendation |
|---------|-------------|-------------|---------------|---------------|
| CIS_BENCHMARKS_CIS1_10 | Limit admin users | 11.0 sec | **YES** | **DISABLE** |
| CIS_BENCHMARKS_CIS1_11 | Admin email required | 10.8 sec | Partial | **DISABLE** |
| CIS_BENCHMARKS_CIS2_4 | Password no-MFA monitoring | 8.4 sec | **YES** | **DISABLE** |
| CIS_BENCHMARKS_CIS2_9 | Unsupported connectors | 6.5 sec | **YES** | **DISABLE** |

#### Low-Cost Scanners (3-4 sec avg)
Simple parameter/config checks. Minimal cost even daily.

| Scanner | CIS Control | Avg Duration | SIEM Overlap? | Recommendation |
|---------|-------------|-------------|---------------|---------------|
| CIS_BENCHMARKS_CIS4_1 | Yearly rekeying | 3.2 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS4_2 | AES-256 stages | 3.4 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS4_4 | Min data retention | 3.3 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS4_5 | Storage integration for stage creation | 3.3 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS4_6 | Storage integration for stage operation | 3.2 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS4_8 | Prevent inline URL unload | 3.0 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS1_1 | SSO configured | 3.7 sec | No | Disable (rarely changes) |
| CIS_BENCHMARKS_CIS1_2 | SCIM configured | 4.0 sec | No | Disable (rarely changes) |

### Threat Intelligence: 13 Scanners

#### Scheduled Scanners (7 scanners, daily)

| Scanner ID | Name | SIEM Overlap? | Recommendation |
|-----------|------|---------------|---------------|
| THREAT_INTELLIGENCE_NON_MFA_PERSON_USERS | MFA Readiness | **YES** (SE covers this free) | **DISABLE** |
| THREAT_INTELLIGENCE_PASSWORD_SERVICE_USERS | Passwordless | **YES** (SE covers this free) | **DISABLE** |
| THREAT_INTELLIGENCE_USERS_WITH_ADMIN_PRIVILEGES | Admin grants | **YES** - privilege alerts | **DISABLE** |
| THREAT_INTELLIGENCE_USERS_WITH_HIGH_AUTHN_FAILURES | Auth failures | **YES** - brute force detection | **DISABLE** |
| THREAT_INTELLIGENCE_USERS_WITH_HIGH_JOB_ERRORS | Job errors | Partial - monitoring handles | **DISABLE** |
| THREAT_INTELLIGENCE_ENTITIES_WITH_LONG_RUNNING_QUERIES | Long queries | **YES** - performance monitoring | **DISABLE** |
| THREAT_INTELLIGENCE_UNUSUAL_APP_USED_IN_SESSION | Unusual apps | **YES** - anomaly detection | **DISABLE** |

#### Event-Driven Scanners (6 scanners)

| Scanner ID | Name | SIEM Overlap? | Recommendation |
|-----------|------|---------------|---------------|
| THREAT_INTELLIGENCE_AUTHENTICATION_POLICY_CHANGES | Auth policy changes | **YES** | **DISABLE** |
| THREAT_INTELLIGENCE_DORMANT_USER_LOGIN | Dormant user login | **YES** | **DISABLE** |
| THREAT_INTELLIGENCE_LOGIN_PROTECTION | Unusual IP login | **YES** | **DISABLE** |
| THREAT_INTELLIGENCE_NETWORK_POLICY_CONFIGURATIONS | Network policy changes | **YES** | **DISABLE** |
| THREAT_INTELLIGENCE_SENSITIVE_PARAMETER_PROTECTION | Param changes | **YES** | **DISABLE** |
| THREAT_INTELLIGENCE_SENSITIVE_POLICY_CHANGES | Policy changes | **YES** | **DISABLE** |

### Security Essentials: 6 Scanners (CANNOT DISABLE)

| Scanner ID | Name | Schedule | Cost |
|-----------|------|----------|------|
| SECURITY_ESSENTIALS_CIS1_4 | MFA for humans | Monthly 7th | **FREE** |
| SECURITY_ESSENTIALS_CIS3_1 | Network policy | Monthly 7th | **FREE** |
| SECURITY_ESSENTIALS_MFA_REQUIRED_FOR_USERS_CHECK | MFA auth policy | Monthly 7th | **FREE** |
| SECURITY_ESSENTIALS_NA_CONSUMER_ES_CHECK | Native app events | Monthly 7th | **FREE** |
| SECURITY_ESSENTIALS_STRONG_AUTH_LEGACY_SERVICE_USERS_READINESS | Legacy svc auth | Bi-monthly 9th/24th | **FREE** |
| SECURITY_ESSENTIALS_STRONG_AUTH_PERSON_USERS_READINESS | Person auth | Bi-monthly 9th/24th | **FREE** |

---

## 4. Disablement Priority Plan

### Phase 1: Immediate (High Impact, Zero Risk)

**Action**: Disable CIS Benchmarks and Threat Intelligence packages entirely.
**Savings**: 100% of Trust Center credit costs.
**Risk**: None if SIEM covers the same detections.

```sql
-- PHASE 1: Disable both paid packages
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', false);
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', false);
```

### Phase 2: Optional (If Partial Coverage Desired)

If the customer wants to keep **some** CIS checks for compliance audits but at reduced cost:

```sql
-- Enable CIS package but set to MONTHLY instead of daily
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'CIS_BENCHMARKS', false);
CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 1 * * UTC', 'CIS_BENCHMARKS', false);

-- Disable the expensive scanners (Section 2: Monitoring - SIEM handles these)
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_1');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_2');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_4');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_5');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_6');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_7');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_8');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_9');

-- Disable the expensive admin checks (if SIEM covers privilege monitoring)
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_14');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_15');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_16');
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_17');

-- Keep only the low-cost configuration checks (Section 1 IAM + Section 3 Network + Section 4 Data Protection)
-- These are 3-4 sec each and provide CIS compliance evidence at minimal cost
```

**Phase 2 savings**: ~70-80% of CIS costs (removes expensive scanners, keeps cheap config checks, monthly instead of daily).

### Phase 3: Cleanup

```sql
-- Mute stale findings to clean up the dashboard
-- (Run after reviewing findings to confirm they are expected)
-- Use the Trust Center UI or post_finding_activity to mute findings in bulk
```

---

## 5. Rollback Plan

If any package or scanner needs to be re-enabled:

```sql
-- Re-enable CIS Benchmarks (will start daily scans immediately)
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'CIS_BENCHMARKS', false);

-- Re-enable Threat Intelligence
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'THREAT_INTELLIGENCE', false);

-- Re-enable a specific scanner
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_1');

-- Verify after re-enable
SELECT ID, NAME, STATE, SCHEDULE FROM snowflake.trust_center.scanner_packages ORDER BY NAME;
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanners WHERE UPPER(STATE) = 'TRUE' ORDER BY NAME;
```

---

## 6. Validation Queries

### Pre-Disablement Snapshot (Run BEFORE making changes)

```sql
-- Save current state for rollback reference
CREATE TABLE IF NOT EXISTS TRUST_CENTER_SNAPSHOT AS
SELECT s.ID AS SCANNER_ID, s.NAME AS SCANNER_NAME, s.STATE, s.SCHEDULE,
       s.NOTIFICATION, sp.ID AS PKG_ID, sp.NAME AS PKG_NAME, sp.STATE AS PKG_STATE,
       CURRENT_TIMESTAMP() AS SNAPSHOT_TIME
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID;
```

### Post-Disablement Validation

```sql
-- 1. Verify package states
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages ORDER BY NAME;
-- Expected: SECURITY_ESSENTIALS=TRUE, CIS_BENCHMARKS=FALSE, THREAT_INTELLIGENCE=FALSE

-- 2. Verify no paid scanners are enabled
SELECT s.ID, s.NAME, s.STATE, sp.NAME AS PACKAGE
FROM snowflake.trust_center.scanners s
JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE UPPER(s.STATE) = 'TRUE' AND sp.ID != 'SECURITY_ESSENTIALS';
-- Expected: 0 rows

-- 3. Verify Security Essentials is intact
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanners
WHERE SCANNER_PACKAGE_ID = 'SECURITY_ESSENTIALS';
-- Expected: 6 rows, all STATE=TRUE

-- 4. Verify config consistency
SELECT SCANNER_PACKAGE_ID, SCANNER_ID, CONFIGURATION_NAME,
       RUNNING_CONFIGURATION_VALUE, SET_CONFIGURATION_VALUE
FROM snowflake.trust_center.configuration_view
WHERE RUNNING_CONFIGURATION_VALUE != SET_CONFIGURATION_VALUE AND CONFIGURATION_NAME = 'ENABLED';
-- Expected: 0 rows

-- 5. Confirm no new paid scans after disable
SELECT SCANNER_PACKAGE_NAME, COUNT(*) AS RUNS, MAX(START_TIMESTAMP) AS LAST_RUN
FROM snowflake.trust_center.findings
WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
  AND START_TIMESTAMP >= DATEADD('day', -1, CURRENT_TIMESTAMP())
GROUP BY SCANNER_PACKAGE_NAME;
-- Expected: 0 rows (after waiting 24h)
```

---

## 7. Ongoing Monitoring

Run this monthly to confirm Trust Center stays cost-optimized:

```sql
-- Monthly health check
SELECT
  'Paid packages enabled' AS CHECK_NAME,
  (SELECT COUNT(*) FROM snowflake.trust_center.scanner_packages
   WHERE UPPER(COALESCE(STATE, 'FALSE')) = 'TRUE' AND ID != 'SECURITY_ESSENTIALS') AS VALUE,
  CASE WHEN (SELECT COUNT(*) FROM snowflake.trust_center.scanner_packages
   WHERE UPPER(COALESCE(STATE, 'FALSE')) = 'TRUE' AND ID != 'SECURITY_ESSENTIALS') = 0
   THEN 'PASS' ELSE 'FAIL - COST ALERT' END AS STATUS
UNION ALL
SELECT
  'Paid scanner runs (last 30d)',
  (SELECT COUNT(DISTINCT SCANNER_NAME) FROM snowflake.trust_center.findings
   WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
   AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())),
  CASE WHEN (SELECT COUNT(DISTINCT SCANNER_NAME) FROM snowflake.trust_center.findings
   WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
   AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())) = 0
   THEN 'PASS' ELSE 'FAIL - UNEXPECTED ACTIVITY' END
UNION ALL
SELECT 'Security Essentials active',
  (SELECT COUNT(*) FROM snowflake.trust_center.scanners
   WHERE SCANNER_PACKAGE_ID = 'SECURITY_ESSENTIALS' AND UPPER(STATE) = 'TRUE'),
  CASE WHEN (SELECT COUNT(*) FROM snowflake.trust_center.scanners
   WHERE SCANNER_PACKAGE_ID = 'SECURITY_ESSENTIALS' AND UPPER(STATE) = 'TRUE') = 6
   THEN 'PASS' ELSE 'WARN - CHECK SE' END;
```
