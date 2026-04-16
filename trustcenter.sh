#!/usr/bin/env bash
###############################################################################
# trust_center_manager.sh
# Snowflake Trust Center Management Script
#
# Usage: ./trust_center_manager.sh <command> [options]
#
# Commands:
#   list-packages        List all scanner packages and their status
#   list-scanners        List all scanners with status and schedule
#   list-enabled         List only enabled scanners
#   list-disabled        List only disabled scanners
#   list-config          Show full configuration resolution chain
#   list-findings        Show open findings summary
#   list-notifications   Show notification history
#   status               Full Trust Center status report
#   stop-package <ID>    Disable a scanner package
#   stop-scanner <PKG> <SCANNER>  Disable a specific scanner
#   start-package <ID>   Enable a scanner package
#   start-scanner <PKG> <SCANNER> Enable a specific scanner
#   schedule-package <ID> <CRON>  Change package schedule
#   validate             Run full validation checks
#   validate-disabled    Verify cost-generating scanners are off
#   cost-check           Check for recent cost-generating activity
#   report               Generate HTML report to stdout
#   help                 Show this help message
#
# Requirements:
#   - SnowSQL installed and configured (or snow CLI)
#   - Connection named in SNOW_CONNECTION or default connection
#   - Role with trust_center_admin or trust_center_viewer access
#
# Environment Variables:
#   SNOW_CONNECTION   - SnowSQL connection name (default: uses default)
#   SNOW_ROLE         - Role to use (default: ACCOUNTADMIN)
#   SNOW_OUTPUT       - Output format: table, csv, json (default: table)
#   SNOW_CLI          - CLI tool: snowsql or snow (default: snowsql)
###############################################################################

set -euo pipefail

# Configuration
SNOW_CONNECTION="${SNOW_CONNECTION:-}"
SNOW_ROLE="${SNOW_ROLE:-ACCOUNTADMIN}"
SNOW_OUTPUT="${SNOW_OUTPUT:-table}"
SNOW_CLI="${SNOW_CLI:-snowsql}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

###############################################################################
# Helper Functions
###############################################################################

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_header(){ echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

run_sql() {
    local sql="$1"
    local format="${2:-$SNOW_OUTPUT}"

    if [[ "$SNOW_CLI" == "snow" ]]; then
        local conn_flag=""
        if [[ -n "$SNOW_CONNECTION" ]]; then
            conn_flag="--connection $SNOW_CONNECTION"
        fi
        snow sql -q "$sql" $conn_flag --role "$SNOW_ROLE" 2>/dev/null
    else
        local conn_flag=""
        if [[ -n "$SNOW_CONNECTION" ]]; then
            conn_flag="-c $SNOW_CONNECTION"
        fi
        local output_flag="-o output_format=$format -o header=true -o timing=false -o friendly=false"
        snowsql $conn_flag -r "$SNOW_ROLE" $output_flag -q "$sql" 2>/dev/null
    fi
}

run_sql_quiet() {
    local sql="$1"
    run_sql "$sql" "csv" 2>/dev/null || true
}

###############################################################################
# List Commands
###############################################################################

cmd_list_packages() {
    log_header "Scanner Packages"
    run_sql "
SELECT ID, NAME, STATE, SCHEDULE, PROVIDER,
       LAST_ENABLED_TIMESTAMP, LAST_DISABLED_TIMESTAMP
FROM snowflake.trust_center.scanner_packages
ORDER BY NAME;
"
}

cmd_list_scanners() {
    log_header "All Scanners"
    run_sql "
SELECT s.ID, s.NAME AS SCANNER_NAME, s.SHORT_DESCRIPTION,
       s.STATE, s.SCHEDULE, s.LAST_SCAN_TIMESTAMP,
       sp.NAME AS PACKAGE_NAME
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp
    ON s.SCANNER_PACKAGE_ID = sp.ID
ORDER BY sp.NAME, s.NAME;
"
}

cmd_list_enabled() {
    log_header "Enabled Scanners"
    run_sql "
SELECT s.ID, s.NAME AS SCANNER_NAME, s.SHORT_DESCRIPTION,
       s.SCHEDULE, s.LAST_SCAN_TIMESTAMP,
       sp.NAME AS PACKAGE_NAME
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp
    ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE UPPER(s.STATE) = 'TRUE'
ORDER BY sp.NAME, s.NAME;
"
}

cmd_list_disabled() {
    log_header "Disabled Scanners"
    run_sql "
SELECT s.ID, s.NAME AS SCANNER_NAME, s.SHORT_DESCRIPTION,
       sp.NAME AS PACKAGE_NAME, sp.STATE AS PACKAGE_STATE
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp
    ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE (s.STATE IS NULL OR UPPER(s.STATE) != 'TRUE')
ORDER BY sp.NAME, s.NAME;
"
}

cmd_list_config() {
    log_header "Configuration Resolution Chain"
    run_sql "
SELECT SCANNER_PACKAGE_ID, SCANNER_ID, TYPE,
       CONFIGURATION_NAME, RUNNING_CONFIGURATION_VALUE
FROM snowflake.trust_center.configuration_view
WHERE CONFIGURATION_NAME = 'ENABLED'
ORDER BY SCANNER_PACKAGE_ID, SCANNER_ID;
"
}

cmd_list_findings() {
    log_header "Open Findings Summary"
    run_sql "
SELECT SCANNER_PACKAGE_NAME, SEVERITY, COUNT(*) AS FINDING_COUNT
FROM snowflake.trust_center.findings
WHERE (STATE IS NULL OR UPPER(STATE) = 'OPEN')
  AND TOTAL_AT_RISK_COUNT > 0
GROUP BY SCANNER_PACKAGE_NAME, SEVERITY
ORDER BY SCANNER_PACKAGE_NAME,
    CASE UPPER(SEVERITY)
        WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5
    END;
"
}

cmd_list_notifications() {
    log_header "Recent Notification History"
    run_sql "
SELECT SCANNER_PACKAGE_ID, SCANNER_ID, SENT_ON,
       NOTIFICATION_INTEGRATION_NAME, STATUS, ERROR_MESSAGE
FROM snowflake.trust_center.notification_history
ORDER BY SENT_ON DESC
LIMIT 20;
"
}

###############################################################################
# Status Command
###############################################################################

cmd_status() {
    log_header "Trust Center Full Status Report"
    echo ""

    log_info "Scanner Package Summary:"
    run_sql "
SELECT ID, NAME, STATE, PROVIDER, SCHEDULE
FROM snowflake.trust_center.scanner_packages
ORDER BY NAME;
"
    echo ""

    log_info "Enabled Scanner Count by Package:"
    run_sql "
SELECT sp.NAME AS PACKAGE, sp.STATE AS PKG_STATE,
       COUNT(CASE WHEN UPPER(s.STATE) = 'TRUE' THEN 1 END) AS ENABLED,
       COUNT(CASE WHEN UPPER(s.STATE) != 'TRUE' OR s.STATE IS NULL THEN 1 END) AS DISABLED,
       COUNT(*) AS TOTAL
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp
    ON s.SCANNER_PACKAGE_ID = sp.ID
GROUP BY sp.NAME, sp.STATE
ORDER BY sp.NAME;
"
    echo ""

    log_info "Open Findings by Severity:"
    run_sql "
SELECT SCANNER_PACKAGE_NAME, SEVERITY, COUNT(*) AS COUNT
FROM snowflake.trust_center.findings
WHERE (STATE IS NULL OR UPPER(STATE) = 'OPEN')
  AND TOTAL_AT_RISK_COUNT > 0
GROUP BY SCANNER_PACKAGE_NAME, SEVERITY
ORDER BY SCANNER_PACKAGE_NAME,
    CASE UPPER(SEVERITY)
        WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5
    END;
"
    echo ""

    log_info "MFA & Passwordless Readiness:"
    run_sql "SELECT METRIC_NAME, VALUE FROM snowflake.trust_center.overview_metrics;"
    echo ""

    log_info "Recently Active Scanners (last 7 days):"
    run_sql "
SELECT DISTINCT SCANNER_PACKAGE_NAME, SCANNER_NAME,
       MAX(START_TIMESTAMP) AS LAST_RUN
FROM snowflake.trust_center.findings
WHERE START_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY SCANNER_PACKAGE_NAME, SCANNER_NAME
ORDER BY LAST_RUN DESC;
"
}

###############################################################################
# Start/Stop Commands
###############################################################################

cmd_stop_package() {
    local pkg_id="${1:?Usage: $0 stop-package <PACKAGE_ID>}"

    if [[ "$pkg_id" == "SECURITY_ESSENTIALS" ]]; then
        log_error "Security Essentials CANNOT be disabled. This is enforced by Snowflake."
        log_warn "Only NOTIFICATION settings can be changed for Security Essentials."
        exit 1
    fi

    log_info "Disabling package: $pkg_id"
    run_sql "CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', '$pkg_id', false);"
    log_ok "Package $pkg_id disabled."

    log_info "Verifying..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages WHERE ID = '$pkg_id';"
}

cmd_stop_scanner() {
    local pkg_id="${1:?Usage: $0 stop-scanner <PACKAGE_ID> <SCANNER_ID>}"
    local scanner_id="${2:?Usage: $0 stop-scanner <PACKAGE_ID> <SCANNER_ID>}"

    if [[ "$pkg_id" == "SECURITY_ESSENTIALS" ]]; then
        log_error "Security Essentials scanners CANNOT be disabled."
        exit 1
    fi

    log_info "Disabling scanner: $scanner_id in package $pkg_id"
    run_sql "CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', '$pkg_id', '$scanner_id');"
    log_ok "Scanner $scanner_id disabled."

    log_info "Verifying..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanners WHERE ID = '$scanner_id';"
}

cmd_start_package() {
    local pkg_id="${1:?Usage: $0 start-package <PACKAGE_ID>}"

    log_warn "Enabling package $pkg_id will start consuming credits when scanners run."
    read -r -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Cancelled."
        exit 0
    fi

    log_info "Enabling package: $pkg_id"
    run_sql "CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', '$pkg_id', false);"
    log_ok "Package $pkg_id enabled."

    log_info "Verifying..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages WHERE ID = '$pkg_id';"
}

cmd_start_scanner() {
    local pkg_id="${1:?Usage: $0 start-scanner <PACKAGE_ID> <SCANNER_ID>}"
    local scanner_id="${2:?Usage: $0 start-scanner <PACKAGE_ID> <SCANNER_ID>}"

    # Check if parent package is enabled
    local pkg_state
    pkg_state=$(run_sql_quiet "SELECT STATE FROM snowflake.trust_center.scanner_packages WHERE ID = '$pkg_id';" | tail -1 | tr -d '[:space:]')

    if [[ "$pkg_state" != "TRUE" && "$pkg_state" != "true" ]]; then
        log_error "Parent package $pkg_id is not enabled (STATE=$pkg_state)."
        log_warn "Enable the package first: $0 start-package $pkg_id"
        exit 1
    fi

    log_info "Enabling scanner: $scanner_id in package $pkg_id"
    run_sql "CALL snowflake.trust_center.set_configuration('ENABLED', 'TRUE', '$pkg_id', '$scanner_id');"
    log_ok "Scanner $scanner_id enabled."

    log_info "Verifying..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanners WHERE ID = '$scanner_id';"
}

###############################################################################
# Schedule Command
###############################################################################

cmd_schedule_package() {
    local pkg_id="${1:?Usage: $0 schedule-package <PACKAGE_ID> <CRON_EXPR>}"
    local cron_expr="${2:?Usage: $0 schedule-package <PACKAGE_ID> <CRON_EXPR>}"

    if [[ "$pkg_id" == "SECURITY_ESSENTIALS" ]]; then
        log_error "Security Essentials schedule CANNOT be changed."
        exit 1
    fi

    log_info "Setting schedule for $pkg_id to: USING CRON $cron_expr"
    run_sql "CALL snowflake.trust_center.set_configuration('SCHEDULE', 'USING CRON $cron_expr', '$pkg_id', false);"
    log_ok "Schedule updated."

    log_info "Verifying..."
    run_sql "SELECT ID, NAME, SCHEDULE FROM snowflake.trust_center.scanner_packages WHERE ID = '$pkg_id';"
}

###############################################################################
# Validate Commands
###############################################################################

cmd_validate() {
    log_header "Trust Center Validation Report"
    local issues=0

    # Check 1: Package states
    log_info "Check 1: Package enablement states"
    local enabled_paid
    enabled_paid=$(run_sql_quiet "
SELECT COUNT(*) FROM snowflake.trust_center.scanner_packages
WHERE UPPER(STATE) = 'TRUE' AND ID != 'SECURITY_ESSENTIALS';
" | tail -1 | tr -d '[:space:]')

    if [[ "$enabled_paid" -gt 0 ]]; then
        log_warn "  $enabled_paid paid package(s) are enabled and consuming credits."
        run_sql "
SELECT ID, NAME, SCHEDULE FROM snowflake.trust_center.scanner_packages
WHERE UPPER(STATE) = 'TRUE' AND ID != 'SECURITY_ESSENTIALS';
"
        issues=$((issues + 1))
    else
        log_ok "  No paid packages are enabled. Cost impact: ZERO."
    fi
    echo ""

    # Check 2: Enabled scanners in disabled packages (should not happen)
    log_info "Check 2: Orphaned enabled scanners in disabled packages"
    local orphaned
    orphaned=$(run_sql_quiet "
SELECT COUNT(*) FROM snowflake.trust_center.scanners s
JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE UPPER(s.STATE) = 'TRUE' AND (sp.STATE IS NULL OR UPPER(sp.STATE) != 'TRUE')
  AND sp.ID != 'SECURITY_ESSENTIALS';
" | tail -1 | tr -d '[:space:]')

    if [[ "$orphaned" -gt 0 ]]; then
        log_warn "  $orphaned scanner(s) enabled in disabled packages (no cost, but inconsistent)."
        issues=$((issues + 1))
    else
        log_ok "  No orphaned scanners found."
    fi
    echo ""

    # Check 3: Security Essentials still running
    log_info "Check 3: Security Essentials health"
    local se_enabled
    se_enabled=$(run_sql_quiet "
SELECT COUNT(*) FROM snowflake.trust_center.scanners
WHERE SCANNER_PACKAGE_ID = 'SECURITY_ESSENTIALS' AND UPPER(STATE) = 'TRUE';
" | tail -1 | tr -d '[:space:]')
    log_ok "  Security Essentials: $se_enabled/6 scanners enabled (free, cannot disable)."
    echo ""

    # Check 4: Recent cost-generating scans
    log_info "Check 4: Recent cost-generating scanner activity (last 30 days)"
    local recent_paid
    recent_paid=$(run_sql_quiet "
SELECT COUNT(DISTINCT SCANNER_NAME)
FROM snowflake.trust_center.findings
WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
  AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP());
" | tail -1 | tr -d '[:space:]')

    if [[ "$recent_paid" -gt 0 ]]; then
        log_warn "  $recent_paid paid scanner(s) ran in the last 30 days."
        run_sql "
SELECT DISTINCT SCANNER_PACKAGE_NAME, SCANNER_NAME, MAX(START_TIMESTAMP) AS LAST_RUN
FROM snowflake.trust_center.findings
WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
  AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY SCANNER_PACKAGE_NAME, SCANNER_NAME
ORDER BY LAST_RUN DESC;
"
        issues=$((issues + 1))
    else
        log_ok "  No paid scanners have run in the last 30 days."
    fi
    echo ""

    # Check 5: Configuration consistency
    log_info "Check 5: Configuration consistency (running vs set)"
    local mismatches
    mismatches=$(run_sql_quiet "
SELECT COUNT(*) FROM snowflake.trust_center.configuration_view
WHERE RUNNING_CONFIGURATION_VALUE != SET_CONFIGURATION_VALUE
  AND CONFIGURATION_NAME = 'ENABLED';
" | tail -1 | tr -d '[:space:]')

    if [[ "$mismatches" -gt 0 ]]; then
        log_warn "  $mismatches configuration mismatch(es) between running and set values."
        issues=$((issues + 1))
    else
        log_ok "  All configurations are consistent."
    fi
    echo ""

    # Check 6: MFA readiness
    log_info "Check 6: MFA & Passwordless readiness"
    run_sql "SELECT METRIC_NAME, VALUE FROM snowflake.trust_center.overview_metrics;"
    echo ""

    # Summary
    log_header "Validation Summary"
    if [[ "$issues" -eq 0 ]]; then
        log_ok "All checks passed. Trust Center is optimized for minimum cost."
    else
        log_warn "$issues issue(s) found. Review warnings above."
    fi
}

cmd_validate_disabled() {
    log_header "Verify Cost-Generating Scanners Are Off"

    log_info "Checking CIS Benchmarks package..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages WHERE ID = 'CIS_BENCHMARKS';"

    log_info "Checking Threat Intelligence package..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages WHERE ID = 'THREAT_INTELLIGENCE';"

    log_info "Checking for any enabled paid scanners..."
    run_sql "
SELECT s.ID, s.NAME, s.STATE, sp.NAME AS PACKAGE
FROM snowflake.trust_center.scanners s
JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
WHERE UPPER(s.STATE) = 'TRUE' AND sp.ID != 'SECURITY_ESSENTIALS'
ORDER BY sp.NAME, s.NAME;
"

    log_info "Only these scanners should be enabled (Security Essentials - free):"
    run_sql "
SELECT s.ID, s.NAME, s.STATE, s.SCHEDULE
FROM snowflake.trust_center.scanners s
WHERE s.SCANNER_PACKAGE_ID = 'SECURITY_ESSENTIALS' AND UPPER(s.STATE) = 'TRUE'
ORDER BY s.NAME;
"
}

cmd_cost_check() {
    log_header "Cost-Generating Activity Check"

    log_info "Paid scanner runs in last 30 days:"
    run_sql "
SELECT SCANNER_PACKAGE_NAME, SCANNER_NAME,
       COUNT(*) AS RUN_COUNT,
       MIN(START_TIMESTAMP) AS FIRST_RUN,
       MAX(START_TIMESTAMP) AS LAST_RUN
FROM snowflake.trust_center.findings
WHERE SCANNER_PACKAGE_NAME != 'Security Essentials'
  AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY SCANNER_PACKAGE_NAME, SCANNER_NAME
ORDER BY RUN_COUNT DESC;
"

    echo ""
    log_info "Security Essentials runs (free on default schedule):"
    run_sql "
SELECT SCANNER_NAME,
       COUNT(*) AS RUN_COUNT,
       MAX(START_TIMESTAMP) AS LAST_RUN
FROM snowflake.trust_center.findings
WHERE SCANNER_PACKAGE_NAME = 'Security Essentials'
  AND START_TIMESTAMP >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY SCANNER_NAME
ORDER BY LAST_RUN DESC;
"
}

###############################################################################
# Cost Estimation Command
###############################################################################

cmd_cost_estimate() {
    log_header "Trust Center Cost Estimation"

    log_info "Historical scan run data (all time):"
    run_sql "
SELECT SCANNER_PACKAGE_NAME,
       COUNT(DISTINCT SCANNER_NAME) AS DISTINCT_SCANNERS,
       COUNT(DISTINCT EVENT_ID) AS TOTAL_SCAN_RUNS,
       MIN(START_TIMESTAMP) AS FIRST_RUN,
       MAX(START_TIMESTAMP) AS LAST_RUN,
       DATEDIFF('day', MIN(START_TIMESTAMP), MAX(START_TIMESTAMP)) AS DAYS_ACTIVE,
       ROUND(COUNT(DISTINCT EVENT_ID) / NULLIF(DATEDIFF('day', MIN(START_TIMESTAMP), MAX(START_TIMESTAMP)), 0), 1) AS RUNS_PER_DAY
FROM snowflake.trust_center.findings
GROUP BY SCANNER_PACKAGE_NAME
ORDER BY TOTAL_SCAN_RUNS DESC;
"
    echo ""

    log_info "Per-scanner average duration (top 20 most expensive):"
    run_sql "
SELECT SCANNER_PACKAGE_NAME, SCANNER_NAME,
       COUNT(DISTINCT EVENT_ID) AS RUN_COUNT,
       ROUND(AVG(DATEDIFF('second', START_TIMESTAMP, END_TIMESTAMP)), 1) AS AVG_DURATION_SEC,
       MAX(START_TIMESTAMP) AS LAST_RUN
FROM snowflake.trust_center.findings
WHERE START_TIMESTAMP IS NOT NULL AND END_TIMESTAMP IS NOT NULL
GROUP BY SCANNER_PACKAGE_NAME, SCANNER_NAME
ORDER BY AVG_DURATION_SEC DESC
LIMIT 20;
"
    echo ""

    log_info "Cost projection (if all packages enabled at default daily schedule):"
    echo ""
    echo -e "  ${BOLD}Package                   Scanners  Schedule   Est. Daily Credits${NC}"
    echo "  -----------------------------------------------------------------------"
    echo -e "  Security Essentials     6         Monthly    ${GREEN}FREE${NC}"
    echo -e "  CIS Benchmarks          37        Daily      ${RED}~0.5-2.0${NC}"
    echo -e "  Threat Intelligence     13        Daily+Evt  ${RED}~0.1-1.0+${NC}"
    echo "  -----------------------------------------------------------------------"
    echo -e "  ${BOLD}TOTAL (all enabled)       56        Mixed      ~0.7-3.5 credits/day${NC}"
    echo ""
    echo -e "  ${BOLD}Projected Annual Cost:${NC}"
    echo "    All enabled (daily):    ~255-1,278 credits/yr  (~\$765-\$3,834 at \$3/credit)"
    echo "    CIS weekly + TI daily:  ~96-480 credits/yr     (~\$288-\$1,440)"
    echo "    CIS monthly + TI weekly: ~36-144 credits/yr    (~\$108-\$432)"
    echo "    All disabled:            0 credits/yr          (\$0)"
    echo ""

    log_info "Current state cost impact:"
    local enabled_paid
    enabled_paid=$(run_sql_quiet "
SELECT COUNT(*) FROM snowflake.trust_center.scanner_packages
WHERE UPPER(COALESCE(STATE, 'FALSE')) = 'TRUE' AND ID != 'SECURITY_ESSENTIALS';
" | tail -1 | tr -d '[:space:]')

    if [[ "$enabled_paid" -gt 0 ]]; then
        log_warn "  $enabled_paid paid package(s) are ENABLED and actively consuming credits."
        run_sql "
SELECT ID, NAME, STATE, SCHEDULE FROM snowflake.trust_center.scanner_packages
WHERE UPPER(COALESCE(STATE, 'FALSE')) = 'TRUE' AND ID != 'SECURITY_ESSENTIALS';
"
    else
        log_ok "  No paid packages enabled. Current cost: \$0"
    fi
}

###############################################################################
# Disable All Command
###############################################################################

cmd_disable_all() {
    log_header "Disable All Paid Trust Center Packages"

    log_warn "This will disable CIS Benchmarks and Threat Intelligence."
    log_warn "Security Essentials cannot be disabled (free, locked by Snowflake)."
    echo ""

    log_info "Current package states:"
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages ORDER BY NAME;"
    echo ""

    read -r -p "Are you sure you want to disable all paid packages? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Cancelled."
        exit 0
    fi

    echo ""
    log_info "Disabling CIS Benchmarks..."
    run_sql "CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'CIS_BENCHMARKS', false);" || log_warn "CIS Benchmarks may already be disabled."

    log_info "Disabling Threat Intelligence..."
    run_sql "CALL snowflake.trust_center.set_configuration('ENABLED', 'FALSE', 'THREAT_INTELLIGENCE', false);" || log_warn "Threat Intelligence may already be disabled."

    echo ""
    log_ok "All paid packages disabled."
    echo ""

    log_info "Verifying..."
    run_sql "SELECT ID, NAME, STATE FROM snowflake.trust_center.scanner_packages ORDER BY NAME;"
    echo ""

    log_info "Enabled scanner count (should show only Security Essentials):"
    run_sql "
SELECT sp.NAME AS PACKAGE,
       COUNT(CASE WHEN UPPER(s.STATE) = 'TRUE' THEN 1 END) AS ENABLED,
       COUNT(*) AS TOTAL
FROM snowflake.trust_center.scanners s
LEFT JOIN snowflake.trust_center.scanner_packages sp ON s.SCANNER_PACKAGE_ID = sp.ID
GROUP BY sp.NAME ORDER BY sp.NAME;
"
}

###############################################################################
# Report Command (generates HTML to stdout)
###############################################################################

cmd_report() {
    # This delegates to the SQL-based HTML report
    if [[ -f "$SCRIPT_DIR/../sql/trust_center_html_report.sql" ]]; then
        log_info "Generating HTML report via SQL..."
        run_sql "$(cat "$SCRIPT_DIR/../sql/trust_center_html_report.sql")" "csv" 2>/dev/null | tail -n +2
    else
        log_error "HTML report SQL not found at $SCRIPT_DIR/../sql/trust_center_html_report.sql"
        exit 1
    fi
}

###############################################################################
# Help
###############################################################################

cmd_help() {
    echo ""
    echo -e "${BOLD}Trust Center Manager${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo -e "${BOLD}List Commands:${NC}"
    echo "  list-packages                     List all scanner packages"
    echo "  list-scanners                     List all scanners with details"
    echo "  list-enabled                      List only enabled scanners"
    echo "  list-disabled                     List only disabled scanners"
    echo "  list-config                       Show configuration chain"
    echo "  list-findings                     Show open findings summary"
    echo "  list-notifications                Show notification history"
    echo "  status                            Full status report"
    echo ""
    echo -e "${BOLD}Control Commands:${NC}"
    echo "  stop-package <PACKAGE_ID>         Disable a package"
    echo "  stop-scanner <PKG_ID> <SCAN_ID>   Disable a scanner"
    echo "  start-package <PACKAGE_ID>        Enable a package (prompts)"
    echo "  start-scanner <PKG_ID> <SCAN_ID>  Enable a scanner"
    echo "  schedule-package <PKG_ID> <CRON>  Change package schedule"
    echo ""
    echo -e "${BOLD}Validation Commands:${NC}"
    echo "  validate                          Full validation report"
    echo "  validate-disabled                 Verify paid scanners are off"
    echo "  cost-check                        Check recent cost activity"
    echo "  cost-estimate                     Estimate costs for all scenarios"
    echo "  disable-all                       Disable all paid packages (prompts)"
    echo "  report                            Generate HTML report"
    echo ""
    echo -e "${BOLD}Package IDs:${NC}"
    echo "  SECURITY_ESSENTIALS               Cannot disable (free)"
    echo "  CIS_BENCHMARKS                    Can disable"
    echo "  THREAT_INTELLIGENCE               Can disable"
    echo ""
    echo -e "${BOLD}Environment Variables:${NC}"
    echo "  SNOW_CONNECTION    SnowSQL connection name"
    echo "  SNOW_ROLE          Role (default: ACCOUNTADMIN)"
    echo "  SNOW_OUTPUT        Output format: table/csv/json"
    echo "  SNOW_CLI           CLI tool: snowsql or snow"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 status"
    echo "  $0 stop-package CIS_BENCHMARKS"
    echo "  $0 stop-scanner THREAT_INTELLIGENCE THREAT_INTELLIGENCE_DORMANT_USER_LOGIN"
    echo "  $0 schedule-package CIS_BENCHMARKS '0 6 * * 1 UTC'"
    echo "  $0 validate"
    echo "  $0 report > trust_center_report.html"
    echo ""
}

###############################################################################
# Main Dispatch
###############################################################################

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        list-packages)      cmd_list_packages ;;
        list-scanners)      cmd_list_scanners ;;
        list-enabled)       cmd_list_enabled ;;
        list-disabled)      cmd_list_disabled ;;
        list-config)        cmd_list_config ;;
        list-findings)      cmd_list_findings ;;
        list-notifications) cmd_list_notifications ;;
        status)             cmd_status ;;
        stop-package)       cmd_stop_package "$@" ;;
        stop-scanner)       cmd_stop_scanner "$@" ;;
        start-package)      cmd_start_package "$@" ;;
        start-scanner)      cmd_start_scanner "$@" ;;
        schedule-package)   cmd_schedule_package "$@" ;;
        validate)           cmd_validate ;;
        validate-disabled)  cmd_validate_disabled ;;
        cost-check)         cmd_cost_check ;;
        cost-estimate)      cmd_cost_estimate ;;
        disable-all)        cmd_disable_all ;;
        report)             cmd_report ;;
        help|--help|-h)     cmd_help ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
