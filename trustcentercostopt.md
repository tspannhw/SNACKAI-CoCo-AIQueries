# Snowflake Trust Center Cost Optimization Guide

## Executive Summary

This document provides a complete guide to managing Snowflake Trust Center costs. Your customer already has their own SIEM and external scanners, and is familiar with password management. The goal is to **minimize Trust Center credit consumption** while maintaining essential security coverage.

### Current Account State (As of April 2026)

| Scanner Package | State | Scanners | Schedule | Cost Impact |
|----------------|-------|----------|----------|-------------|
| **Security Essentials** | ENABLED (cannot disable) | 6 scanners, all enabled | Monthly (7th) + Bi-monthly (9th, 24th) | **Free** (default monthly run) |
| **CIS Benchmarks** | DISABLED | 37 scanners, all disabled | Daily at 08:16 UTC | **Zero cost** (already disabled) |
| **Threat Intelligence** | DISABLED | 14 scanners, all disabled | Daily at 04:34 UTC + event-driven | **Zero cost** (already disabled) |

### Key Findings

1. **Security Essentials cannot be disabled** - Its ENABLED and SCHEDULE configurations are locked by Snowflake. Only NOTIFICATION settings can be changed.
2. **CIS Benchmarks is already disabled** - Was disabled on 2026-03-24. No cost is being incurred.
3. **Threat Intelligence is already disabled** - Has never been enabled. No cost is being incurred.
4. **MFA and Passwordless readiness are both at 100%** - Your account is fully compliant on strong authentication.
5. **Open findings exist from past CIS scans** - 174 Critical, 686 High, 1380 Medium, 2376 Low findings remain from when CIS was enabled.

---

## Section 1: Understanding Trust Center Costs

### How Trust Center Charges Work

Trust Center consumes **serverless compute credits** each time a scanner runs. Costs depend on:

- **Number of enabled scanners** - Each scanner that runs consumes credits
- **Run frequency** - More frequent schedules = more cost
- **Scan complexity** - Scanners that query large datasets (e.g., access history, login history) cost more per run
- **Account size** - More users, roles, and objects = longer scan times

### Cost Tiers by Package

| Package | Default Schedule | Cost Per Run | Notes |
|---------|-----------------|--------------|-------|
| Security Essentials | Monthly (free run) | **Free** for default schedule | Ad-hoc `execute_scanner` calls DO consume credits |
| CIS Benchmarks | Daily | **Credits per scan** | 37 scanners x daily = significant cost |
| Threat Intelligence | Daily + event-driven | **Credits per scan** | Event-driven scanners fire on every matching event |

### Cost Reduction Strategies

1. **Disable entire packages** you don't need (CIS Benchmarks, Threat Intelligence)
2. **Reduce scan frequency** for packages you keep (e.g., daily -> weekly)
3. **Disable individual scanners** within a package that duplicate your SIEM coverage
4. **Avoid ad-hoc executions** of Security Essentials (default monthly run is free)

---

## Section 2: What Can Be Stopped/Paused/Modified

### Package-Level Controls

| Package | Can Disable? | Can Change Schedule? | Can Change Notifications? |
|---------|-------------|---------------------|--------------------------|
| Security Essentials | **NO** | **NO** | YES |
| CIS Benchmarks | YES | YES | YES |
| Threat Intelligence | YES | YES | YES |

### Scanner-Level Controls

Every individual scanner within CIS Benchmarks and Threat Intelligence can be independently:
- **Enabled/Disabled** (parent package must be enabled first)
- **Scheduled** (custom cron per scanner)
- **Notified** (custom notification per scanner)

### Security Essentials Scanners (Cannot Disable)

| Scanner ID | Name | Schedule | What It Checks |
|-----------|------|----------|---------------|
| SECURITY_ESSENTIALS_CIS1_4 | MFA for human users | 7th of month | Password users have MFA |
| SECURITY_ESSENTIALS_CIS3_1 | Account network policy | 7th of month | Account-level network policy exists |
| SECURITY_ESSENTIALS_MFA_REQUIRED_FOR_USERS_CHECK | MFA Auth Policy | 7th of month | Auth policy requires MFA enrollment |
| SECURITY_ESSENTIALS_NA_CONSUMER_ES_CHECK | Native Apps Event Sharing | 7th of month | Event table configured for Native Apps |
| SECURITY_ESSENTIALS_STRONG_AUTH_LEGACY_SERVICE_USERS_READINESS | Legacy Service User Auth | 9th & 24th of month | Legacy service users migrating off passwords |
| SECURITY_ESSENTIALS_STRONG_AUTH_PERSON_USERS_READINESS | Person User Auth | 9th & 24th of month | Person users migrating off passwords |

**Important**: Security Essentials' default monthly run is covered by Snowflake at no charge. Do NOT call `execute_scanner('SECURITY_ESSENTIALS')` manually unless you want to pay for it.

### CIS Benchmarks Scanners (All Disableable)

37 scanners organized into 4 sections:

**Section 1: Identity & Access Management (17 scanners)**
- CIS 1.1 - SSO configuration
- CIS 1.2 - SCIM integration
- CIS 1.4 - MFA for human users
- CIS 1.5 - Minimum password length (14+ chars)
- CIS 1.6 - Key pair auth for legacy service users
- CIS 1.7 - Key pair rotation every 180 days
- CIS 1.8 - Disable users inactive 90+ days
- CIS 1.9 - Idle session timeout for admin roles
- CIS 1.10 - Limit ACCOUNTADMIN/SECURITYADMIN users
- CIS 1.11 - Email on ACCOUNTADMIN users
- CIS 1.12 - No ACCOUNTADMIN/SECURITYADMIN as default role
- CIS 1.13 - No ACCOUNTADMIN/SECURITYADMIN granted to custom roles
- CIS 1.14 - Tasks not owned by admin roles
- CIS 1.15 - Tasks not running with admin privileges
- CIS 1.16 - Stored procs not owned by admin roles
- CIS 1.17 - Stored procs not running with admin privileges

**Section 2: Monitoring & Alerting (8 scanners)**
- CIS 2.1 - Monitor admin role grants
- CIS 2.2 - Monitor MANAGE GRANTS privilege grants
- CIS 2.4 - Monitor password sign-in without MFA
- CIS 2.5 - Monitor security integration changes
- CIS 2.6 - Monitor network policy changes
- CIS 2.7 - Monitor SCIM token creation
- CIS 2.8 - Monitor share exposures
- CIS 2.9 - Monitor unsupported connector sessions

**Section 3: Network Security (2 scanners)**
- CIS 3.1 - Account-level network policy
- CIS 3.2 - User-level network policies for service accounts

**Section 4: Data Protection (11 scanners)**
- CIS 4.1 - Yearly rekeying
- CIS 4.2 - AES-256 for internal stages
- CIS 4.3 - DATA_RETENTION_TIME_IN_DAYS = 90
- CIS 4.4 - MIN_DATA_RETENTION_TIME_IN_DAYS >= 7
- CIS 4.5 - REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION
- CIS 4.6 - REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION
- CIS 4.7 - Storage integrations on external stages
- CIS 4.8 - PREVENT_UNLOAD_TO_INLINE_URL
- CIS 4.9 - Tri-Secret Secure
- CIS 4.10 - Data masking for sensitive data
- CIS 4.11 - Row-access policies for sensitive data

### Threat Intelligence Scanners (All Disableable)

**Scheduled Scanners (7 scanners, daily at 04:34 UTC):**

| Scanner ID | Name | What It Checks |
|-----------|------|---------------|
| THREAT_INTELLIGENCE_NON_MFA_PERSON_USERS | Human User MFA Readiness | Password users without MFA |
| THREAT_INTELLIGENCE_PASSWORD_SERVICE_USERS | Service User Passwordless | Service users using passwords |
| THREAT_INTELLIGENCE_USERS_WITH_ADMIN_PRIVILEGES | Admin Privilege Grants | New admin grants in last 24h |
| THREAT_INTELLIGENCE_USERS_WITH_HIGH_AUTHN_FAILURES | Auth Failure Detection | High auth failure volume |
| THREAT_INTELLIGENCE_USERS_WITH_HIGH_JOB_ERRORS | Job Error Detection | High job error volume |
| THREAT_INTELLIGENCE_ENTITIES_WITH_LONG_RUNNING_QUERIES | Long-Running Queries | Unusually long queries |
| THREAT_INTELLIGENCE_UNUSUAL_APP_USED_IN_SESSION | Unusual App Sessions | Sessions from unusual apps |

**Event-Driven Scanners (7 scanners, fire on events):**

| Scanner ID | Name | What It Checks |
|-----------|------|---------------|
| THREAT_INTELLIGENCE_AUTHENTICATION_POLICY_CHANGES | Auth Policy Changes | Any auth policy modification |
| THREAT_INTELLIGENCE_DORMANT_USER_LOGIN | Dormant User Login | Login from inactive users |
| THREAT_INTELLIGENCE_LOGIN_PROTECTION | Login Protection | Logins from unusual IPs |
| THREAT_INTELLIGENCE_NETWORK_POLICY_CONFIGURATIONS | Network Policy Changes | Network policy modifications |
| THREAT_INTELLIGENCE_SENSITIVE_PARAMETER_PROTECTION | Sensitive Parameter Changes | Critical parameter changes |
| THREAT_INTELLIGENCE_SENSITIVE_POLICY_CHANGES | Policy Changes | Password/session policy changes |

---

## Section 3: Recommended Configuration for Cost Minimization

### For Customers with Their Own SIEM

Since your customer already has a SIEM and external scanners:

**Keep as-is (no cost):**
- Security Essentials: Cannot disable, but the default monthly run is free
- CIS Benchmarks: Already disabled - leave disabled
- Threat Intelligence: Already disabled - leave disabled

**Do NOT do:**
- Do not manually execute `CALL snowflake.trust_center.execute_scanner(...)` for Security Essentials - this incurs costs
- Do not re-enable CIS Benchmarks or Threat Intelligence unless you need specific checks your SIEM doesn't cover

**Optional - If you need some CIS/TI coverage:**
If specific checks are needed that your SIEM cannot provide, enable only those individual scanners and set them to weekly or monthly instead of daily:

```sql
-- Example: Enable only the package first
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'CIS_BENCHMARKS', false);

-- Set package to weekly instead of daily
CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 * * 1 UTC', 'CIS_BENCHMARKS', false);

-- Enable only the specific scanner you need
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_4');

-- Disable the ones you don't need (they default to enabled when package is enabled)
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_1');
-- ... repeat for each unwanted scanner
```

---

## Section 4: SQL Scripts Reference

### List All Scanner Packages and Status

```sql
SELECT ID, NAME, STATE, SCHEDULE, NOTIFICATION, PROVIDER,
       LAST_ENABLED_TIMESTAMP, LAST_DISABLED_TIMESTAMP
FROM snowflake.trust_center.scanner_packages
ORDER BY NAME;
```

### List All Scanners with Status

```sql
SELECT s.ID, s.NAME, s.SHORT_DESCRIPTION, s.STATE, s.SCHEDULE,
       s.NOTIFICATION, s.LAST_SCAN_TIMESTAMP, sp.NAME AS PACKAGE_NAME
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp
    ON s.SCANNER_PACKAGE_ID = sp.ID
ORDER BY sp.NAME, s.NAME;
```

### View Full Configuration Resolution Chain

```sql
SELECT SCANNER_PACKAGE_ID, SCANNER_ID, TYPE, CONFIGURATION_NAME,
       RUNNING_CONFIGURATION_VALUE, SET_CONFIGURATION_VALUE
FROM snowflake.trust_center.configuration_view
ORDER BY SCANNER_PACKAGE_ID, SCANNER_ID, CONFIGURATION_NAME;
```

### Count Open Findings by Severity

```sql
SELECT SCANNER_PACKAGE_NAME, SEVERITY, COUNT(*) AS finding_count
FROM snowflake.trust_center.findings
WHERE (STATE IS NULL OR UPPER(STATE) = 'OPEN')
  AND TOTAL_AT_RISK_COUNT > 0
GROUP BY SCANNER_PACKAGE_NAME, SEVERITY
ORDER BY SCANNER_PACKAGE_NAME,
    CASE UPPER(SEVERITY)
        WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5
    END;
```

### Disable a Package

```sql
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', '<PACKAGE_ID>', false);
```

### Enable a Package

```sql
CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', '<PACKAGE_ID>', false);
```

### Disable a Specific Scanner

```sql
CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', '<PACKAGE_ID>', '<SCANNER_ID>');
```

### Change Package Schedule to Weekly

```sql
CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 * * 1 UTC', '<PACKAGE_ID>', false);
```

### Change Package Schedule to Monthly

```sql
CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 1 * * UTC', '<PACKAGE_ID>', false);
```

### View Notification History

```sql
SELECT * FROM snowflake.trust_center.notification_history ORDER BY SENT_ON DESC;
```

### View MFA and Passwordless Readiness

```sql
SELECT * FROM snowflake.trust_center.overview_metrics;
```

---

## Section 5: Validation & Testing

### Verify Package is Disabled

```sql
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages WHERE ID = '<PACKAGE_ID>';
-- STATE should be 'FALSE' or NULL
```

### Verify All Scanners in Package are Disabled

```sql
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanners
WHERE SCANNER_PACKAGE_ID = '<PACKAGE_ID>' AND UPPER(STATE) = 'TRUE';
-- Should return 0 rows if all are disabled
```

### Verify No New Findings Being Generated

```sql
SELECT SCANNER_PACKAGE_NAME, COUNT(*) AS recent_findings
FROM snowflake.trust_center.findings
WHERE CREATED_ON >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY SCANNER_PACKAGE_NAME
ORDER BY recent_findings DESC;
-- Disabled packages should show 0 or no rows
```

### Verify Running Configuration Matches Desired State

```sql
SELECT SCANNER_PACKAGE_ID, SCANNER_ID, CONFIGURATION_NAME,
       RUNNING_CONFIGURATION_VALUE
FROM snowflake.trust_center.configuration_view
WHERE CONFIGURATION_NAME = 'ENABLED'
  AND UPPER(RUNNING_CONFIGURATION_VALUE) = 'TRUE'
ORDER BY SCANNER_PACKAGE_ID, SCANNER_ID;
-- Only Security Essentials scanners should appear
```

### Check for Cost-Generating Activity

```sql
-- Check if any non-free scanners ran recently
SELECT SCANNER_PACKAGE_NAME, SCANNER_NAME, START_TIMESTAMP, END_TIMESTAMP
FROM snowflake.trust_center.findings
WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
  AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY START_TIMESTAMP DESC
LIMIT 20;
```

---

## Section 6: SIEM Integration Overlap Analysis

Since your customer has their own SIEM, here's what Trust Center checks map to common SIEM capabilities:

| Trust Center Check | Typical SIEM Equivalent | Recommendation |
|-------------------|------------------------|----------------|
| Auth failures detection | Failed login alerting | **SIEM handles this** |
| Dormant user login | Inactive account access alerts | **SIEM handles this** |
| Admin privilege grants | Privilege escalation detection | **SIEM handles this** |
| Network policy changes | Configuration change monitoring | **SIEM handles this** |
| Auth policy changes | Policy modification alerts | **SIEM handles this** |
| Unusual app sessions | Anomalous session detection | **SIEM handles this** |
| MFA compliance | Identity governance | **Keep Security Essentials (free)** |
| CIS benchmark compliance | Compliance scanning | **Run CIS monthly if needed for audit** |
| Long-running queries | Performance monitoring | **SIEM/monitoring handles this** |
| Password policy changes | Configuration monitoring | **SIEM handles this** |

---

## Appendix A: Complete Scanner ID Reference

### CIS Benchmarks Package (ID: CIS_BENCHMARKS)

| Scanner ID | CIS Control |
|-----------|-------------|
| CIS_BENCHMARKS_CIS1_1 | 1.1 SSO Configuration |
| CIS_BENCHMARKS_CIS1_2 | 1.2 SCIM Integration |
| CIS_BENCHMARKS_CIS1_4 | 1.4 MFA for Human Users |
| CIS_BENCHMARKS_CIS1_5 | 1.5 Password Length |
| CIS_BENCHMARKS_CIS1_6 | 1.6 Key Pair Auth |
| CIS_BENCHMARKS_CIS1_7 | 1.7 Key Pair Rotation |
| CIS_BENCHMARKS_CIS1_8 | 1.8 Inactive User Disablement |
| CIS_BENCHMARKS_CIS1_9 | 1.9 Idle Session Timeout |
| CIS_BENCHMARKS_CIS1_10 | 1.10 Admin User Limits |
| CIS_BENCHMARKS_CIS1_11 | 1.11 Admin Email Required |
| CIS_BENCHMARKS_CIS1_12 | 1.12 No Admin Default Role |
| CIS_BENCHMARKS_CIS1_13 | 1.13 No Admin on Custom Roles |
| CIS_BENCHMARKS_CIS1_14 | 1.14 Tasks Not Admin-Owned |
| CIS_BENCHMARKS_CIS1_15 | 1.15 Tasks Not Admin-Run |
| CIS_BENCHMARKS_CIS1_16 | 1.16 Procs Not Admin-Owned |
| CIS_BENCHMARKS_CIS1_17 | 1.17 Procs Not Admin-Run |
| CIS_BENCHMARKS_CIS2_1 | 2.1 Admin Grant Monitoring |
| CIS_BENCHMARKS_CIS2_2 | 2.2 MANAGE GRANTS Monitoring |
| CIS_BENCHMARKS_CIS2_4 | 2.4 Password No-MFA Monitoring |
| CIS_BENCHMARKS_CIS2_5 | 2.5 Security Integration Monitoring |
| CIS_BENCHMARKS_CIS2_6 | 2.6 Network Policy Monitoring |
| CIS_BENCHMARKS_CIS2_7 | 2.7 SCIM Token Monitoring |
| CIS_BENCHMARKS_CIS2_8 | 2.8 Share Exposure Monitoring |
| CIS_BENCHMARKS_CIS2_9 | 2.9 Unsupported Connector Monitoring |
| CIS_BENCHMARKS_CIS3_1 | 3.1 Account Network Policy |
| CIS_BENCHMARKS_CIS3_2 | 3.2 Service Account Network Policies |
| CIS_BENCHMARKS_CIS4_1 | 4.1 Yearly Rekeying |
| CIS_BENCHMARKS_CIS4_2 | 4.2 AES-256 Internal Stages |
| CIS_BENCHMARKS_CIS4_3 | 4.3 Data Retention 90 Days |
| CIS_BENCHMARKS_CIS4_4 | 4.4 Min Data Retention 7 Days |
| CIS_BENCHMARKS_CIS4_5 | 4.5 Storage Integration for Stage Creation |
| CIS_BENCHMARKS_CIS4_6 | 4.6 Storage Integration for Stage Operation |
| CIS_BENCHMARKS_CIS4_7 | 4.7 External Stage Storage Integrations |
| CIS_BENCHMARKS_CIS4_8 | 4.8 Prevent Inline URL Unload |
| CIS_BENCHMARKS_CIS4_9 | 4.9 Tri-Secret Secure |
| CIS_BENCHMARKS_CIS4_10 | 4.10 Data Masking |
| CIS_BENCHMARKS_CIS4_11 | 4.11 Row-Access Policies |

### Threat Intelligence Package (ID: THREAT_INTELLIGENCE)

| Scanner ID | Type | Name |
|-----------|------|------|
| THREAT_INTELLIGENCE_NON_MFA_PERSON_USERS | Scheduled | Human User MFA Readiness |
| THREAT_INTELLIGENCE_PASSWORD_SERVICE_USERS | Scheduled | Service User Passwordless |
| THREAT_INTELLIGENCE_USERS_WITH_ADMIN_PRIVILEGES | Scheduled | Admin Privilege Grants |
| THREAT_INTELLIGENCE_USERS_WITH_HIGH_AUTHN_FAILURES | Scheduled | Auth Failure Detection |
| THREAT_INTELLIGENCE_USERS_WITH_HIGH_JOB_ERRORS | Scheduled | Job Error Detection |
| THREAT_INTELLIGENCE_ENTITIES_WITH_LONG_RUNNING_QUERIES | Scheduled | Long-Running Queries |
| THREAT_INTELLIGENCE_UNUSUAL_APP_USED_IN_SESSION | Scheduled | Unusual App Sessions |
| THREAT_INTELLIGENCE_AUTHENTICATION_POLICY_CHANGES | Event-Driven | Auth Policy Changes |
| THREAT_INTELLIGENCE_DORMANT_USER_LOGIN | Event-Driven | Dormant User Login |
| THREAT_INTELLIGENCE_LOGIN_PROTECTION | Event-Driven | Login Protection |
| THREAT_INTELLIGENCE_NETWORK_POLICY_CONFIGURATIONS | Event-Driven | Network Policy Changes |
| THREAT_INTELLIGENCE_SENSITIVE_PARAMETER_PROTECTION | Event-Driven | Sensitive Param Changes |
| THREAT_INTELLIGENCE_SENSITIVE_POLICY_CHANGES | Event-Driven | Policy Changes |

### Security Essentials Package (ID: SECURITY_ESSENTIALS) — Cannot Disable

| Scanner ID | Name |
|-----------|------|
| SECURITY_ESSENTIALS_CIS1_4 | MFA for Human Users |
| SECURITY_ESSENTIALS_CIS3_1 | Account Network Policy |
| SECURITY_ESSENTIALS_MFA_REQUIRED_FOR_USERS_CHECK | MFA Auth Policy |
| SECURITY_ESSENTIALS_NA_CONSUMER_ES_CHECK | Native Apps Event Sharing |
| SECURITY_ESSENTIALS_STRONG_AUTH_LEGACY_SERVICE_USERS_READINESS | Legacy Service User Auth |
| SECURITY_ESSENTIALS_STRONG_AUTH_PERSON_USERS_READINESS | Person User Auth |
