# dbt Projects on Snowflake - Complete Guide

> **Scope**: This guide covers ONLY **dbt Projects on Snowflake** - the native Snowflake feature for running dbt Core directly within Snowflake. This is NOT dbt Cloud or externally-hosted dbt Core.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites & Setup](#prerequisites--setup)
4. [Lineage & Documentation Integration](#lineage--documentation-integration)
5. [OpenTelemetry & Observability](#opentelemetry--observability)
6. [Mono-repo vs Multi-repo Structures](#mono-repo-vs-multi-repo-structures)
7. [dbt Commands: generate & snapshot](#dbt-commands-generate--snapshot)
8. [External Scheduling (Tidal & Others)](#external-scheduling-tidal--others)
9. [Starter Templates](#starter-templates)
10. [Validation & Testing](#validation--testing)
11. [CI/CD Integration](#cicd-integration)
12. [Troubleshooting](#troubleshooting)

---

## Overview

**dbt Projects on Snowflake** is a native Snowflake feature (GA Nov 2025) that lets you:
- Create schema-level **DBT PROJECT objects** in Snowflake
- Execute dbt commands directly via **EXECUTE DBT PROJECT**
- Schedule runs using **Snowflake Tasks**
- Version control projects with automatic versioning
- Monitor execution via Snowsight

### Key Differentiators from External dbt

| Feature | dbt Projects on Snowflake | External dbt Core/Cloud |
|---------|---------------------------|-------------------------|
| Execution Environment | Inside Snowflake | External compute |
| Scheduling | Snowflake Tasks | Cron/Airflow/dbt Cloud |
| Authentication | Native Snowflake RBAC | Connection credentials |
| Lineage | Native Snowsight + External Lineage API | Requires third-party tools |
| Versioning | Automatic VERSION$N | Git-only |
| Monitoring | Snowsight Transformation UI | External tools |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Snowflake Account                           │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
│  │   Git Repo      │    │   Workspace     │    │ Internal Stage  │  │
│  │   Stage         │    │   (Snowsight)   │    │                 │  │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘  │
│           │                      │                      │           │
│           └──────────────────────┼──────────────────────┘           │
│                                  ▼                                  │
│                    ┌─────────────────────────┐                      │
│                    │   CREATE DBT PROJECT    │                      │
│                    │   (Schema-level object) │                      │
│                    └────────────┬────────────┘                      │
│                                 │                                   │
│           ┌─────────────────────┼─────────────────────┐             │
│           ▼                     ▼                     ▼             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │ EXECUTE DBT     │  │ Snowflake Task  │  │ snow dbt        │      │
│  │ PROJECT (SQL)   │  │ (Scheduled)     │  │ execute (CLI)   │      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘     │
│           │                    │                    │              │
│           └────────────────────┼────────────────────┘              │
│                                ▼                                   │
│                    ┌─────────────────────────┐                     │
│                    │   Target Tables/Views   │                     │
│                    │   Snapshots, Seeds      │                     │
│                    └─────────────────────────┘                     │
│                                │                                   │
│                                ▼                                   │
│                    ┌─────────────────────────┐                     │
│                    │   Snowsight Lineage     │                     │
│                    │   (Native + External)   │                     │
│                    └─────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites & Setup

### Required Privileges

```sql
-- Create role for dbt project management
CREATE ROLE dbt_project_admin;

-- Grant schema privileges
GRANT CREATE DBT PROJECT ON SCHEMA my_db.my_schema TO ROLE dbt_project_admin;
GRANT CREATE TASK ON SCHEMA my_db.my_schema TO ROLE dbt_project_admin;

-- Grant project-level privileges
GRANT OWNERSHIP ON DBT PROJECT my_dbt_project TO ROLE dbt_project_admin;
GRANT USAGE ON DBT PROJECT my_dbt_project TO ROLE dbt_executor;
GRANT MONITOR ON DBT PROJECT my_dbt_project TO ROLE dbt_viewer;

-- For external lineage (optional)
CREATE ROLE dbt_lineage_role;
GRANT INGEST LINEAGE ON ACCOUNT TO ROLE dbt_lineage_role;
```

### Enable Monitoring

```sql
-- Enable logging, tracing, and metrics on schema
ALTER SCHEMA my_db.my_dbt_schema SET LOG_LEVEL = 'INFO';
ALTER SCHEMA my_db.my_dbt_schema SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA my_db.my_dbt_schema SET METRIC_LEVEL = 'ALL';
```

### External Access Integration (for dbt packages)

```sql
-- Create network rule for dbt hub
CREATE OR REPLACE NETWORK RULE dbt_hub_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('hub.getdbt.com:443', 'github.com:443', 'raw.githubusercontent.com:443');

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION dbt_packages_integration
  ALLOWED_NETWORK_RULES = (dbt_hub_rule)
  ENABLED = TRUE;
```

---

## Lineage & Documentation Integration

### Native Snowsight Lineage

dbt Projects on Snowflake automatically populate Snowsight lineage:
- Navigate: **Catalog → Database Explorer → [Table] → Lineage**
- Shows upstream/downstream dependencies
- Model-level lineage captured during execution

### dbt docs generate Support

| Execution Method | Supported |
|------------------|-----------|
| Workspaces | ✔ |
| EXECUTE DBT PROJECT | ✔ |
| snow dbt execute | ❌ |

```sql
-- Generate documentation
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'docs generate';
```

**Note**: `dbt docs serve` is NOT supported. Use artifacts retrieval instead:

```sql
-- Get documentation artifacts
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');
-- Returns: snow://dbt/DB.SCHEMA.PROJECT/results/query_id_.../

-- Download manifest.json, catalog.json
LIST 'snow://dbt/DB.SCHEMA.PROJECT/results/query_id_.../';
```

### External Lineage API (OpenLineage)

For integrating external data sources into Snowsight lineage:

```yaml
# openlineage.yml
transport:
  type: http
  url: https://<account_identifier>.snowflakecomputing.com
  endpoint: /api/v2/lineage/external-lineage
  auth:
    type: api_key
    apiKey: <JWT_TOKEN>
  compression: gzip
```

---

## OpenTelemetry & Observability

### Built-in Monitoring

```sql
-- Query execution history
SELECT * FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE OBJECT_NAME = 'MY_DBT_PROJECT'
ORDER BY query_end_time DESC;

-- Get logs for specific execution
SET latest_query_id = (
  SELECT query_id FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
  WHERE OBJECT_NAME = 'MY_DBT_PROJECT'
  ORDER BY query_end_time DESC LIMIT 1
);
SELECT SYSTEM$GET_DBT_LOG($latest_query_id);
```

### Artifact Retrieval

| Function | Returns | Use Case |
|----------|---------|----------|
| `SYSTEM$GET_DBT_LOG(query_id)` | Text log output | Quick debugging |
| `SYSTEM$LOCATE_DBT_ARTIFACTS(query_id)` | Folder path to artifacts | Browse/copy specific files |
| `SYSTEM$LOCATE_DBT_ARCHIVE(query_id)` | ZIP file URL | Download all artifacts |

### Accessing Artifacts Programmatically

```sql
-- List all artifact files
LIST 'snow://dbt/DB.SCHEMA.PROJECT/results/query_id_xxx/';

-- Copy to your stage
CREATE STAGE IF NOT EXISTS my_artifacts_stage;
COPY FILES INTO @my_artifacts_stage
  FROM 'snow://dbt/DB.SCHEMA.PROJECT/results/query_id_xxx/'
  FILES = ('manifest.json', 'run_results.json');
```

---

## Mono-repo vs Multi-repo Structures

### Recommendation for dbt Projects on Snowflake

| Scenario | Recommended Structure |
|----------|----------------------|
| Single team, <500 models | Mono-repo |
| Multiple independent domains | Multi-repo with cross-project refs |
| Data mesh architecture | Multi-repo with local packages |

### Cross dbt Project Dependencies

**Important**: Snowflake only supports local references in the same folder.

```
core_project/
├─ dbt_project.yml
├─ packages.yml
├─ models/
├─ local_packages/
│  └─ metrics_project/
│     ├─ dbt_project.yml
│     └─ models/
```

```yaml
# core_project/packages.yml
packages:
  - local: local_packages/metrics_project
```

### Multi-Project Workspace Setup

```sql
-- Create from workspace with multiple projects
CREATE DBT PROJECT my_db.my_schema.project_a
  FROM 'snow://workspace/user$.public."My Workspace"/versions/live/project_a'
  DEFAULT_TARGET = 'prod';

CREATE DBT PROJECT my_db.my_schema.project_b
  FROM 'snow://workspace/user$.public."My Workspace"/versions/live/project_b'
  DEFAULT_TARGET = 'prod';
```

---

## dbt Commands: generate & snapshot

### Supported Commands Matrix

| Command | Workspaces | EXECUTE DBT PROJECT | snow dbt execute |
|---------|------------|---------------------|------------------|
| build | ✔ | ✔ | ✔ |
| compile | ✔ | ✔ | ✔ |
| deps | ✔ | ✔ | ✔ |
| docs generate | ✔ | ✔ | ❌ |
| list | ✔ | ✔ | ✔ |
| parse | ❌ | ✔ | ✔ |
| run | ✔ | ✔ | ✔ |
| retry | ✔ | ❌ | ❌ |
| run-operation | ✔ | ✔ | ✔ |
| seed | ✔ | ✔ | ✔ |
| show | ✔ | ✔ | ✔ |
| **snapshot** | **✔** | **✔** | **✔** |
| test | ✔ | ✔ | ✔ |

### Snapshot Implementation (SCD Type 2)

```sql
-- snapshots/orders_snapshot.sql
{% snapshot orders_snapshot %}
{{
  config(
    target_schema='snapshots',
    strategy='timestamp',
    unique_key='order_id',
    updated_at='updated_at',
    invalidate_hard_deletes=True
  )
}}
SELECT * FROM {{ source('raw', 'orders') }}
{% endsnapshot %}
```

**Execute snapshot:**
```sql
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'snapshot';

-- Or specific snapshot
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'snapshot --select orders_snapshot';
```

### Snapshot Strategies

| Strategy | When to Use | Configuration |
|----------|-------------|---------------|
| `timestamp` | Source has reliable `updated_at` | `updated_at='column_name'` |
| `check` | No timestamp available | `check_cols=['col1', 'col2']` or `check_cols='all'` |

---

## External Scheduling (Tidal & Others)

### Native Snowflake Tasks (Recommended)

```sql
-- Create run task
CREATE OR ALTER TASK my_db.my_schema.dbt_run_task
  WAREHOUSE = my_warehouse
  SCHEDULE = '6 hours'
AS
  EXECUTE DBT PROJECT my_db.my_schema.my_project
  ARGS = 'run --target prod';

-- Create test task (runs after run completes)
CREATE OR ALTER TASK my_db.my_schema.dbt_test_task
  WAREHOUSE = my_warehouse
  AFTER my_db.my_schema.dbt_run_task
AS
  EXECUTE DBT PROJECT my_db.my_schema.my_project
  ARGS = 'test --target prod';

-- Enable tasks
ALTER TASK my_db.my_schema.dbt_test_task RESUME;
ALTER TASK my_db.my_schema.dbt_run_task RESUME;
```

### External Scheduler Integration (Tidal, Control-M, etc.)

**Option 1: Snowflake SQL via JDBC/ODBC**
```sql
-- Execute from external scheduler
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'build --target prod';
```

**Option 2: Snowflake CLI**
```bash
snow dbt execute my_project --args "build --target prod"
```

**Option 3: REST API (Snowflake SQL API)**
```bash
curl -X POST "https://<account>.snowflakecomputing.com/api/v2/statements" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "statement": "EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = '\''build --target prod'\''",
    "warehouse": "my_warehouse",
    "database": "my_db",
    "schema": "my_schema"
  }'
```

### Tidal-Specific Best Practices

1. **Job Definition**: Create Tidal job using Snowflake JDBC adapter
2. **Dependencies**: Use Tidal job groups for dbt model dependencies
3. **Error Handling**: Configure retry actions (max 2 retries)
4. **Alerts**: Set up email/SNMP alerts on job failure
5. **Calendars**: Use business calendar for scheduled runs

```
Tidal Job Configuration:
├── Job: dbt_daily_build
│   ├── Type: SQL (Snowflake JDBC)
│   ├── Command: EXECUTE DBT PROJECT ...
│   ├── Schedule: Business Days, 6:00 AM
│   └── On Failure: Retry 2x, then Alert
└── Job: dbt_test_validation
    ├── Type: SQL (Snowflake JDBC)
    ├── Predecessor: dbt_daily_build
    └── Command: EXECUTE DBT PROJECT ... ARGS = 'test'
```

---

## Starter Templates

### Template 1: Basic dbt Project Structure

```
my_dbt_project/
├── dbt_project.yml
├── profiles.yml
├── packages.yml
├── models/
│   ├── staging/
│   │   └── stg_orders.sql
│   ├── intermediate/
│   │   └── int_orders_enriched.sql
│   └── marts/
│       └── fct_orders.sql
├── snapshots/
│   └── orders_snapshot.sql
├── seeds/
│   └── country_codes.csv
├── tests/
│   └── assert_positive_amounts.sql
└── macros/
    └── generate_schema_name.sql
```

### Template 2: profiles.yml for Snowflake

```yaml
my_dbt_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      database: DEV_DB
      schema: DBT_DEV
      role: DBT_DEV_ROLE
      warehouse: DEV_WH
    prod:
      type: snowflake
      database: PROD_DB
      schema: DBT_PROD
      role: DBT_PROD_ROLE
      warehouse: PROD_WH
```

### Template 3: dbt_project.yml

```yaml
name: 'my_dbt_project'
version: '1.0.0'
config-version: 2
profile: 'my_dbt_project'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  my_dbt_project:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      +schema: marts

snapshots:
  my_dbt_project:
    +target_schema: snapshots
```

### Template 4: Deployment SQL Script

```sql
-- ============================================
-- dbt Projects on Snowflake - Deployment Script
-- ============================================

-- Step 1: Setup environment
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS DBT_PROJECTS;
CREATE SCHEMA IF NOT EXISTS DBT_PROJECTS.PROD;

-- Step 2: Create external access integration
CREATE OR REPLACE NETWORK RULE dbt_hub_rule
  MODE = EGRESS TYPE = HOST_PORT
  VALUE_LIST = ('hub.getdbt.com:443', 'github.com:443');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION dbt_packages_integration
  ALLOWED_NETWORK_RULES = (dbt_hub_rule) ENABLED = TRUE;

-- Step 3: Create Git repository stage
CREATE OR REPLACE GIT REPOSITORY DBT_PROJECTS.PROD.my_dbt_repo
  API_INTEGRATION = github_api_integration
  ORIGIN = 'https://github.com/myorg/my-dbt-project.git';

ALTER GIT REPOSITORY DBT_PROJECTS.PROD.my_dbt_repo FETCH;

-- Step 4: Create dbt project object
CREATE OR REPLACE DBT PROJECT DBT_PROJECTS.PROD.my_dbt_project
  FROM '@DBT_PROJECTS.PROD.my_dbt_repo/branches/main'
  DEFAULT_TARGET = 'prod'
  DBT_VERSION = '1.9.4'
  EXTERNAL_ACCESS_INTEGRATIONS = (dbt_packages_integration)
  COMMENT = 'Production dbt project';

-- Step 5: Grant permissions
GRANT USAGE ON DBT PROJECT DBT_PROJECTS.PROD.my_dbt_project TO ROLE DBT_EXECUTOR;
GRANT MONITOR ON DBT PROJECT DBT_PROJECTS.PROD.my_dbt_project TO ROLE DBT_VIEWER;

-- Step 6: Create scheduled tasks
CREATE OR REPLACE TASK DBT_PROJECTS.PROD.dbt_daily_build
  WAREHOUSE = TRANSFORM_WH
  SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
AS
  EXECUTE DBT PROJECT DBT_PROJECTS.PROD.my_dbt_project
  ARGS = 'build --target prod';

CREATE OR REPLACE TASK DBT_PROJECTS.PROD.dbt_snapshot
  WAREHOUSE = TRANSFORM_WH
  AFTER DBT_PROJECTS.PROD.dbt_daily_build
AS
  EXECUTE DBT PROJECT DBT_PROJECTS.PROD.my_dbt_project
  ARGS = 'snapshot --target prod';

-- Enable tasks
ALTER TASK DBT_PROJECTS.PROD.dbt_snapshot RESUME;
ALTER TASK DBT_PROJECTS.PROD.dbt_daily_build RESUME;

-- Step 7: Enable monitoring
ALTER SCHEMA DBT_PROJECTS.PROD SET LOG_LEVEL = 'INFO';
ALTER SCHEMA DBT_PROJECTS.PROD SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA DBT_PROJECTS.PROD SET METRIC_LEVEL = 'ALL';
```

---

## Validation & Testing

### Pre-Deployment Validation

```sql
-- Validate project compiles
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'compile --target dev';

-- List all models
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'list';

-- Run specific model in dev
EXECUTE DBT PROJECT my_db.my_schema.my_project 
  ARGS = 'run --select my_model --target dev';
```

### Testing Commands

```sql
-- Run all tests
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'test --target prod';

-- Run tests for specific model
EXECUTE DBT PROJECT my_db.my_schema.my_project 
  ARGS = 'test --select my_model --target prod';

-- Build with tests (recommended)
EXECUTE DBT PROJECT my_db.my_schema.my_project ARGS = 'build --target prod';
```

### Monitoring Task Execution

```sql
-- View task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  TASK_NAME => 'dbt_daily_build',
  SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
ORDER BY scheduled_time DESC;

-- View dbt execution history
SELECT 
  query_id,
  object_name,
  query_start_time,
  query_end_time,
  execution_status
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE object_name = 'MY_DBT_PROJECT'
ORDER BY query_end_time DESC
LIMIT 10;
```

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/dbt-snowflake.yml
name: dbt Projects on Snowflake CI/CD

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

env:
  SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
  SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
  SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}

jobs:
  ci:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Snowflake CLI
        run: pip install snowflake-cli-labs
      
      - name: Deploy to Dev
        run: |
          snow dbt deploy my_project_dev \
            --source . \
            --database DEV_DB \
            --schema DBT_DEV \
            --default-target dev \
            --force
      
      - name: Run Tests
        run: |
          snow dbt execute my_project_dev \
            --args "build --target dev"

  cd:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Snowflake CLI
        run: pip install snowflake-cli-labs
      
      - name: Deploy to Prod
        run: |
          snow dbt deploy my_project_prod \
            --source . \
            --database PROD_DB \
            --schema DBT_PROD \
            --default-target prod \
            --force
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `dbt deps` fails | No external access integration | Add `EXTERNAL_ACCESS_INTEGRATIONS` |
| `Object does not exist` | Target schema missing | Create schema before deployment |
| Task not running | Task suspended | `ALTER TASK ... RESUME` |
| Permission denied | Missing USAGE privilege | Grant USAGE on dbt project |
| Compilation error | Invalid profiles.yml | Verify database/schema/role exist |

### Debug Commands

```sql
-- Check project exists
SHOW DBT PROJECTS IN SCHEMA my_db.my_schema;

-- Describe project
DESCRIBE DBT PROJECT my_db.my_schema.my_project;

-- Get last execution logs
SELECT SYSTEM$GET_DBT_LOG(
  (SELECT query_id FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
   WHERE OBJECT_NAME = 'MY_PROJECT' ORDER BY query_end_time DESC LIMIT 1)
);

-- Check task status
SHOW TASKS IN SCHEMA my_db.my_schema;
```

---

## Quick Reference

### SQL Commands

| Command | Purpose |
|---------|---------|
| `CREATE DBT PROJECT` | Create new dbt project object |
| `ALTER DBT PROJECT` | Add version, modify settings |
| `EXECUTE DBT PROJECT` | Run dbt commands |
| `DESCRIBE DBT PROJECT` | View project metadata |
| `SHOW DBT PROJECTS` | List all projects |
| `DROP DBT PROJECT` | Delete project object |

### Snowflake CLI Commands

| Command | Purpose |
|---------|---------|
| `snow dbt deploy` | Create/update dbt project |
| `snow dbt execute` | Run dbt commands |
| `snow dbt list` | List dbt projects |

### System Functions

| Function | Purpose |
|----------|---------|
| `SYSTEM$GET_DBT_LOG()` | Get execution logs |
| `SYSTEM$LOCATE_DBT_ARTIFACTS()` | Get artifacts folder path |
| `SYSTEM$LOCATE_DBT_ARCHIVE()` | Get ZIP archive URL |

---

**Document Version**: 1.0  
**Last Updated**: March 2026  
**Snowflake Feature**: dbt Projects on Snowflake (GA Nov 2025)
