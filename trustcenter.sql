-------------------------------------------------------------------------------
-- TRUST CENTER: DISABLE ALL PAID SCANNERS WITH ROLLBACK
-- Run this script to disable all cost-generating Trust Center activity.
-- Includes pre-change snapshot, disable commands, validation, and rollback.
--
-- IMPORTANT: Run sections in order. Review output at each step.
-- Requires: ACCOUNTADMIN or trust_center_admin role
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- SECTION 1: PRE-CHANGE STATE SNAPSHOT
-- Run this BEFORE making any changes to preserve rollback data
-------------------------------------------------------------------------------

-- 1a. Show current package states
SELECT '=== PRE-CHANGE: Package States ===' AS SECTION;
SELECT ID, NAME, STATE, SCHEDULE, PROVIDER
FROM snowflake.trust_center.scanner_packages ORDER BY NAME;

-- 1b. Show current enabled scanners
SELECT '=== PRE-CHANGE: Enabled Scanners ===' AS SECTION;
SELECT s.ID, s.NAME, s.STATE, s.SCHEDULE, sp.NAME AS PACKAGE
FROM snowflake.trust_center.scanners s
JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE UPPER(s.STATE) = 'TRUE'
ORDER BY sp.NAME, s.NAME;

-- 1c. Show current enabled counts
SELECT '=== PRE-CHANGE: Scanner Counts ===' AS SECTION;
SELECT sp.NAME AS PACKAGE, sp.STATE AS PKG_STATE,
       COUNT(CASE WHEN UPPER(s.STATE) = 'TRUE' THEN 1 END) AS ENABLED,
       COUNT(*) AS TOTAL
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
GROUP BY sp.NAME, sp.STATE ORDER BY sp.NAME;

-------------------------------------------------------------------------------
-- SECTION 2: DISABLE ALL PAID PACKAGES
-- This is the primary cost-saving action.
-- Security Essentials cannot be disabled (will error if attempted).
-------------------------------------------------------------------------------

-- 2a. Disable CIS Benchmarks (37 scanners, daily schedule)
-- Uncomment to execute:
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', false);

-- 2b. Disable Threat Intelligence (13 scanners, daily + event-driven)
-- Uncomment to execute:
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', false);

-------------------------------------------------------------------------------
-- SECTION 3: DISABLE INDIVIDUAL SCANNERS (OPTIONAL - GRANULAR CONTROL)
-- Use this section if you want to keep a package enabled but disable
-- specific expensive scanners within it.
-------------------------------------------------------------------------------

-- 3a. Disable expensive CIS Section 2 (Monitoring) scanners
-- These are the highest-cost scanners (17-51 sec each, access history queries)
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_1');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_2');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_4');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_5');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_6');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_7');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_8');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS2_9');

-- 3b. Disable expensive CIS Section 1 (Admin privilege) scanners
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_14');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_15');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_16');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', 'CIS_BENCHMARKS_CIS1_17');

-- 3c. Disable all Threat Intelligence scheduled scanners individually
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_NON_MFA_PERSON_USERS');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_PASSWORD_SERVICE_USERS');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_USERS_WITH_ADMIN_PRIVILEGES');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_USERS_WITH_HIGH_AUTHN_FAILURES');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_USERS_WITH_HIGH_JOB_ERRORS');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_ENTITIES_WITH_LONG_RUNNING_QUERIES');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_UNUSUAL_APP_USED_IN_SESSION');

-- 3d. Disable all Threat Intelligence event-driven scanners individually
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_AUTHENTICATION_POLICY_CHANGES');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_DORMANT_USER_LOGIN');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_LOGIN_PROTECTION');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_NETWORK_POLICY_CONFIGURATIONS');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_SENSITIVE_PARAMETER_PROTECTION');
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', 'THREAT_INTELLIGENCE_SENSITIVE_POLICY_CHANGES');

-------------------------------------------------------------------------------
-- SECTION 4: REDUCE FREQUENCY (ALTERNATIVE TO FULL DISABLE)
-- If the customer wants to keep scanners but reduce cost by running less often
-------------------------------------------------------------------------------

-- 4a. Change CIS Benchmarks from daily to weekly (Monday 6am UTC)
-- CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 * * 1 UTC', 'CIS_BENCHMARKS', false);

-- 4b. Change CIS Benchmarks from daily to monthly (1st of month, 6am UTC)
-- CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 1 * * UTC', 'CIS_BENCHMARKS', false);

-- 4c. Change Threat Intelligence from daily to weekly
-- CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 * * 1 UTC', 'THREAT_INTELLIGENCE', false);

-- 4d. Change Threat Intelligence from daily to monthly
-- CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 0 6 1 * * UTC', 'THREAT_INTELLIGENCE', false);

-------------------------------------------------------------------------------
-- SECTION 5: POST-CHANGE VALIDATION
-- Run these after making changes to verify the desired state
-------------------------------------------------------------------------------

-- 5a. Verify package states
SELECT '=== POST-CHANGE: Package States ===' AS SECTION;
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages ORDER BY NAME;

-- 5b. Verify no paid scanners are active
SELECT '=== POST-CHANGE: Active Paid Scanners (should be 0 rows) ===' AS SECTION;
SELECT s.ID, s.NAME, s.STATE, sp.NAME AS PACKAGE
FROM snowflake.trust_center.scanners s
JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE UPPER(s.STATE) = 'TRUE' AND sp.ID != 'SECURITY_ESSENTIALS';

-- 5c. Verify Security Essentials is still intact
SELECT '=== POST-CHANGE: Security Essentials (should be 6 rows, all TRUE) ===' AS SECTION;
SELECT ID, NAME, STATE FROM snowflake.trust_center.scanners
WHERE SCANNER_PACKAGE_ID = 'SECURITY_ESSENTIALS';

-- 5d. Verify config consistency
SELECT '=== POST-CHANGE: Config Mismatches (should be 0 rows) ===' AS SECTION;
SELECT SCANNER_PACKAGE_ID, SCANNER_ID, RUNNING_CONFIGURATION_VALUE, SET_CONFIGURATION_VALUE
FROM snowflake.trust_center.configuration_view
WHERE RUNNING_CONFIGURATION_VALUE != SET_CONFIGURATION_VALUE AND CONFIGURATION_NAME = 'ENABLED';

-- 5e. Final scanner counts
SELECT '=== POST-CHANGE: Scanner Counts ===' AS SECTION;
SELECT sp.NAME AS PACKAGE,
       COUNT(CASE WHEN UPPER(s.STATE) = 'TRUE' THEN 1 END) AS ENABLED,
       COUNT(CASE WHEN UPPER(s.STATE) != 'TRUE' OR s.STATE IS NULL THEN 1 END) AS DISABLED,
       COUNT(*) AS TOTAL
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
GROUP BY sp.NAME ORDER BY sp.NAME;

-------------------------------------------------------------------------------
-- SECTION 6: ROLLBACK (IF NEEDED)
-- Re-enable packages/scanners to restore previous state
-------------------------------------------------------------------------------

-- 6a. Re-enable CIS Benchmarks
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'CIS_BENCHMARKS', false);

-- 6b. Re-enable Threat Intelligence
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', 'THREAT_INTELLIGENCE', false);

-- 6c. Re-enable specific scanners
-- CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', '<PACKAGE_ID>', '<SCANNER_ID>');

-- 6d. Restore original schedule (daily at 08:16 UTC for CIS)
-- CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 16 8 * * * UTC', 'CIS_BENCHMARKS', false);

-- 6e. Restore original schedule (daily at 04:34 UTC for TI)
-- CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON 34 4 * * * UTC', 'THREAT_INTELLIGENCE', false);

-- 6f. Verify rollback
-- SELECT ID, NAME, STATE, SCHEDULE FROM snowflake.trust_center.scanner_packages ORDER BY NAME;
