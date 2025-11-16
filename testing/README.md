<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Local Testing Guide

This directory contains scripts for local testing of the reporting tool with real Gerrit server data.

## Overview

The `local-testing.sh` script automates the following workflow:

1. **Check for existing repositories** - Reuses already cloned repositories if present
2. **Clone repositories** (if needed) from Gerrit servers using `gerrit-clone` CLI tool
3. **Generate reports** using the `reporting-tool` on the cloned repositories
4. **Output results** to `/tmp/reports` for manual review

## Prerequisites

### Required Software

- **uv** - Package manager and tool runner
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- **git** - Git version control system
  ```bash
  # Usually pre-installed on most systems
  git --version
  ```

### Disk Space

Ensure you have sufficient disk space in `/tmp`:

- **ONAP**: ~50-100 GB (varies based on number of active repositories)
- **OpenDaylight**: ~10-20 GB (varies based on number of active repositories)

Check available space:
```bash
df -h /tmp
```

## Quick Start

Run the testing script:

```bash
cd reporting-tool/testing
./local-testing.sh
```

The script will:

1. ✅ Check prerequisites (uv, git)
2. 🔍 Check for existing cloned repositories
3. 🗑️ Clean up existing report directories only
4. 📁 Create output directories
5. 📥 Clone ONAP repositories to `/tmp/gerrit.onap.org` (if not already present)
6. 📥 Clone OpenDaylight repositories to `/tmp/git.opendaylight.org` (if not already present)
7. 📊 Generate ONAP report to `/tmp/reports/onap`
8. 📊 Generate OpenDaylight report to `/tmp/reports/opendaylight`
9. 📋 Display summary of results

**Note:** The script preserves existing cloned repositories to save time on subsequent runs. It only re-clones if the directories don't exist. Report directories are always cleaned and regenerated.

## Output Structure

After successful execution, you'll have:

```
/tmp/
├── gerrit.onap.org/              # Cloned ONAP repositories
│   ├── aai/
│   ├── ccsdk/
│   ├── dcaegen2/
│   └── ...
│
├── git.opendaylight.org/         # Cloned OpenDaylight repositories
│   ├── aaa/
│   ├── controller/
│   ├── netconf/
│   └── ...
│
└── reports/
    ├── onap/                     # ONAP reports
    │   ├── report_raw.json       # Complete dataset (canonical)
    │   ├── report.md             # Markdown report (readable)
    │   ├── report.html           # Interactive HTML (sortable tables)
    │   ├── config_resolved.json  # Applied configuration
    │   └── ONAP_report_bundle.zip # Complete bundle
    │
    └── opendaylight/             # OpenDaylight reports
        ├── report_raw.json
        ├── report.md
        ├── report.html
        ├── config_resolved.json
        └── OpenDaylight_report_bundle.zip
```

## Configuration

### Customizing Clone Parameters

Edit the script variables at the top of `local-testing.sh`:

```bash
# Servers
ONAP_SERVER="gerrit.onap.org"
ODL_SERVER="git.opendaylight.org"

# Base directories
CLONE_BASE_DIR="/tmp"
REPORT_BASE_DIR="/tmp/reports"
```

### gerrit-clone Options

The script uses these `gerrit-clone` options:

- `--https` - Clone via HTTPS (no SSH keys required)
- `--skip-archived` - Skip archived/inactive repositories
- `--threads 4` - Use 4 concurrent threads
- `--clone-timeout 600` - 10-minute timeout per repository
- `--retry-attempts 3` - Retry failed clones up to 3 times
- `--move-conflicting` - Move conflicting files to allow nested repos
- `--verbose` - Show detailed progress

To modify these, edit the `clone_onap()` and `clone_opendaylight()` functions in the script.

### reporting-tool Options

The script uses these `reporting-tool` options:

- `--cache` - Enable caching for better performance
- `--workers 4` - Use 4 concurrent workers

To modify these, edit the `generate_onap_report()` and `generate_opendaylight_report()` functions.

## Reviewing Reports

### Markdown Reports

Quick, human-readable overview:

```bash
# ONAP report
less /tmp/reports/onap/report.md

# OpenDaylight report
less /tmp/reports/opendaylight/report.md
```

### HTML Reports

Interactive reports with sortable tables:

```bash
# ONAP report
open /tmp/reports/onap/report.html

# OpenDaylight report (macOS)
open /tmp/reports/opendaylight/report.html

# Linux
xdg-open /tmp/reports/opendaylight/report.html
```

### JSON Data

Complete structured data for programmatic analysis:

```bash
# ONAP data
jq '.' /tmp/reports/onap/report_raw.json | less

# OpenDaylight data
jq '.' /tmp/reports/opendaylight/report_raw.json | less
```

## Troubleshooting

### Clone Failures

If cloning fails:

1. **Check network connectivity**:
   ```bash
   ping gerrit.onap.org
   ping git.opendaylight.org
   ```

2. **Verify server accessibility**:
   ```bash
   curl -I https://gerrit.onap.org
   curl -I https://git.opendaylight.org
   ```

3. **Check disk space**:
   ```bash
   df -h /tmp
   ```

4. **Review clone logs** - The script outputs detailed progress

### Report Generation Failures

If report generation fails:

1. **Verify repositories were cloned**:
   ```bash
   ls -la /tmp/gerrit.onap.org/
   ls -la /tmp/git.opendaylight.org/
   ```

2. **Check for valid git repositories**:
   ```bash
   find /tmp/gerrit.onap.org -name ".git" -type d | head -5
   ```

3. **Run with verbose output** - Already enabled in the script

4. **Check the reporting-tool dependencies**:
   ```bash
   cd reporting-tool
   uv sync
   ```

### Out of Disk Space

If you run out of disk space:

1. **Clean up previous test runs**:
   ```bash
   rm -rf /tmp/gerrit.onap.org
   rm -rf /tmp/git.opendaylight.org
   rm -rf /tmp/reports
   ```

2. **Use a different directory** with more space:
   ```bash
   # Edit local-testing.sh
   CLONE_BASE_DIR="/path/to/larger/disk"
   REPORT_BASE_DIR="/path/to/larger/disk/reports"
   ```

3. **Clone with shallow depth** (edit the script):
   ```bash
   uvx gerrit-clone \
       --depth 1 \
       # ... other options
   ```

## Manual Testing

### Test Individual Steps

You can run individual steps manually:

#### 1. Clone ONAP only

```bash
uvx gerrit-clone clone \
    --host gerrit.onap.org \
    --path-prefix /tmp \
    --https \
    --skip-archived \
    --threads 4 \
    --verbose
```

#### 2. Clone OpenDaylight only

```bash
uvx gerrit-clone clone \
    --host git.opendaylight.org \
    --path-prefix /tmp \
    --https \
    --skip-archived \
    --threads 4 \
    --verbose
```

#### 3. Generate ONAP report only

```bash
cd reporting-tool
uv run reporting-tool generate \
    --project "ONAP" \
    --repos-path /tmp/gerrit.onap.org \
    --output-dir /tmp/reports/onap \
    --cache \
    --workers 4
```

#### 4. Generate OpenDaylight report only

```bash
cd reporting-tool
uv run reporting-tool generate \
    --project "OpenDaylight" \
    --repos-path /tmp/git.opendaylight.org \
    --output-dir /tmp/reports/opendaylight \
    --cache \
    --workers 4
```

## Cleanup

### Remove Test Data

To clean up all test data:

```bash
rm -rf /tmp/gerrit.onap.org
rm -rf /tmp/git.opendaylight.org
rm -rf /tmp/reports
```

Or use the cleanup script:

```bash
cd reporting-tool/testing
./cleanup.sh
```

### Automatic Cleanup

The script automatically cleans up **report directories only** at the start of each run. Cloned repositories are preserved and reused to save time. To force a fresh clone, manually delete the repository directories first:

```bash
rm -rf /tmp/gerrit.onap.org
rm -rf /tmp/git.opendaylight.org
```

## Advanced Usage

### Test with Specific Projects Only

Modify the clone commands to target specific projects:

```bash
uvx gerrit-clone clone \
    --host gerrit.onap.org \
    --path-prefix /tmp \
    --https \
    --include-project "aai/*" \
    --include-project "sdc" \
    --verbose
```

### Use SSH Instead of HTTPS

If you have SSH keys configured:

```bash
# Remove --https and add SSH options
uvx gerrit-clone clone \
    --host gerrit.onap.org \
    --path-prefix /tmp \
    --ssh-user your-username \
    --ssh-private-key ~/.ssh/id_rsa \
    --threads 4 \
    --verbose
```

### Different Report Formats

Generate only specific report formats:

```bash
uv run reporting-tool generate \
    --project "ONAP" \
    --repos-path /tmp/gerrit.onap.org \
    --output-dir /tmp/reports/onap \
    --formats json markdown  # Only JSON and Markdown
```

## Performance Tips

1. **Increase threads** for faster cloning (if network allows):
   ```bash
   --threads 8
   ```

2. **Use shallow clones** for faster initial clone:
   ```bash
   --depth 1
   ```

3. **Enable caching** for repeated report generation:
   ```bash
   --cache
   ```

4. **Increase workers** for faster report generation:
   ```bash
   --workers 8
   ```

5. **Reuse cloned repositories** - The script automatically preserves cloned repos between runs, saving significant time on subsequent executions.

## See Also

- [gerrit-clone documentation](https://github.com/lfreleng-actions/gerrit-clone-action)
- [reporting-tool documentation](../README.md)
- [Configuration guide](../docs/CONFIGURATION.md)
- [Performance guide](../docs/PERFORMANCE.md)