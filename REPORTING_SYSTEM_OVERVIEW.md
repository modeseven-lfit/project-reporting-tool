<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Reporting System Overview

**Version:** 2.0
**Status:** Ready for Production
**Date:** 2025-01

---

## 🎯 Executive Summary

We redesigned the reporting system to publish reports directly to GitHub Pages on this repository, eliminating the dependency on a separate `gerrit-reports` repository and associated authentication token. This new architecture provides:

- ✅ **Simplified Authentication** - Uses built-in `GITHUB_TOKEN`, no external token needed
- **PR Preview System** - Verify reporting code changes before merge
- ✅ **Enhanced Artifact Retention** - 90-day retention for meta-reporting
- ✅ **Separation of Concerns** - Production and preview workflows are independent
- ✅ **Better Scalability** - Parallel processing with resource limits

---

## 🏗️ System Architecture

### High-Level Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflows                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Production (Monday 7am UTC)          PR Preview (On PR)         │
│  ┌──────────────────────┐            ┌──────────────────────┐   │
│  │ 1. Verify Config     │            │ 1. Verify Config     │   │
│  │ 2. Clone Gerrit (x8) │            │ 2. Clone Gerrit (x2) │   │
│  │ 3. Clone info-master │            │ 3. Clone info-master │   │
│  │ 4. Generate Reports  │            │ 4. Generate Reports  │   │
│  │ 5. Upload Artifacts  │            │ 5. Upload Artifacts  │   │
│  │ 6. Publish to Pages  │            │ 6. Publish Preview   │   │
│  └──────────────────────┘            └──────────────────────┘   │
│           │                                      │                │
│           v                                      v                │
└───────────┼──────────────────────────────────────┼───────────────┘
            │                                      │
            v                                      v
┌─────────────────────────────────────────────────────────────────┐
│                      gh-pages Branch                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  /production/                    /pr-preview/                    │
│  ├── index.html                  ├── <pr-number>/                │
│  ├── project-1/                  │   ├── index.html             │
│  │   ├── report.html             │   ├── project-1/             │
│  │   ├── report_raw.json         │   │   └── report.html        │
│  │   └── metadata.json           │   └── project-2/             │
│  └── project-2/                  │       └── report.html        │
│      └── ...                     └── ...                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
            │
            v
┌─────────────────────────────────────────────────────────────────┐
│                       GitHub Pages Site                          │
│    https://<owner>.github.io/<repo>/                            │
└─────────────────────────────────────────────────────────────────┘
```text

---

## 📂 Repository Structure

### Workflow Files

```text
.github/
├── workflows/
│   ├── reporting-production.yaml       # Production reports (scheduled)
│   ├── reporting-pr-preview.yaml       # PR preview reports
│   ├── reporting.yaml.deprecated       # Legacy workflow (inactive)
│   └── ...                             # Other workflows
└── scripts/
    ├── generate-index.sh               # HTML index generation
    ├── download-artifacts.sh           # Artifact download utility
    ├── publish-reports.sh.deprecated   # Legacy publish script
    └── README.md                       # Scripts documentation
```text

### Documentation

```text
docs/
├── GITHUB_PAGES_SETUP.md              # Complete setup guide
├── MIGRATION_CHECKLIST.md             # Migration from legacy system
├── QUICK_REFERENCE.md                 # Common tasks quick ref
└── ...                                # Other documentation
```text

### GitHub Pages (gh-pages branch)

```text
/                                       # Root landing page
├── index.html                         # Main entry point
├── production/                        # Production reports
│   ├── index.html                    # Production listing
│   └── <project-slug>/
│       ├── report.html               # Interactive HTML report
│       ├── report_raw.json           # Complete data (for meta-reporting)
│       ├── report.md                 # Markdown format
│       └── metadata.json             # Generation metadata
└── pr-preview/                       # PR previews
    └── <pr-number>/                  # Per-PR isolation
        ├── index.html                # Preview listing
        └── <project-slug>/
            └── ...
```text

---

## 🔄 Workflows

### 1. Production Reports Workflow

**File:** `.github/workflows/reporting-production.yaml`

**Purpose:** Generate official weekly reports for all Linux Foundation Gerrit projects

**Schedule:**

- Automated: Monday at 7:00 AM UTC
- Manual: Via workflow_dispatch

**Process:**

1. **Verify Job**
   - Validates `PROJECTS_JSON` configuration
   - Checks required secrets are present
   - Parses project list into matrix for parallel execution

2. **Analyze Jobs** (Parallel, one per project)
   - Clones all Gerrit repositories (non-archived only)
   - Clones info-master repository for committer data
   - Queries Jenkins API for job status
   - Queries GitHub API for workflow status
   - Generates comprehensive reports (HTML, JSON, Markdown)
   - Uploads artifacts with 90-day retention

3. **Publish Job**
   - Downloads all generated reports
   - Organizes into `/production/<slug>/` structure
   - Generates index pages with project listings
   - Commits to `gh-pages` branch
   - Triggers GitHub Pages deployment

4. **Summary Job**
   - Generates workflow summary
   - Reports success/failure status
   - Provides links to published reports

**Artifacts:**

- Raw data JSON (90 days) - For meta-reporting and trend analysis
- Complete reports (90 days) - Full report package
- Clone manifests (90 days) - Repository tracking data
- Clone logs (90 days) - Debugging information

**Output:**

```text
https://<owner>.github.io/<repo>/production/<project-slug>/report.html
```text

---

### 2. PR Preview Workflow

**File:** `.github/workflows/reporting-pr-preview.yaml`

**Purpose:** Verify reporting code changes before merge

**Triggers:**

- Pull requests modifying:
  - `src/**/*.py` (reporting code)
  - `tests/**/*.py` (tests)
  - `.github/workflows/reporting-*.yaml` (workflows)
  - `.github/scripts/*.sh` (scripts)
  - `pyproject.toml`, `uv.lock` (dependencies)

**Resource Optimization:**

- Processes **first 2 projects only** to conserve CI resources
- Uses shorter timeouts (60 min vs 90 min)
- Lower artifact retention (30 days vs 90 days)

**Process:**

1. **Verify Job**
   - Same as production, but limits to 2 projects

2. **Analyze Jobs** (Parallel, first 2 projects only)
   - Same process as production
   - Adds PR context to metadata

3. **Publish Preview Job**
   - Downloads generated reports
   - Organizes into `/pr-preview/<pr-number>/<slug>/`
   - Generates preview index page
   - Commits to `gh-pages` branch
   - Comments on PR with preview link

4. **Summary Job**
   - Posts workflow summary
   - Updates PR comment with status

**Key Features:**

- ✅ **Non-Destructive** - Never overwrites production reports
- ✅ **Isolated** - Each PR gets separate directory
- ✅ **Automatic** - Triggers on code changes
- ✅ **Informative** - Bot comments with preview links

**Output:**

```text
https://<owner>.github.io/<repo>/pr-preview/<pr-number>/<project-slug>/report.html
```text

---

## 🔑 Required Configuration

### Secrets

| Secret | Required | Purpose | Permissions |
|--------|----------|---------|-------------|
| `CLASSIC_READ_ONLY_PAT_TOKEN` | ✅ Yes | GitHub API queries | `repo` (read), `workflow` (read) |
| `LF_GERRIT_INFO_MASTER_SSH_KEY` | ⚠️ Optional | SSH clone of info-master | Read access to info-master repo |

**Note:** `GERRIT_REPORTS_PAT_TOKEN` is **NO LONGER NEEDED** and you should remove it after migration.

### Variables

| Variable | Format | Required Fields |
|----------|--------|----------------|
| `PROJECTS_JSON` | JSON array | `project`, `gerrit` (required); `jenkins`, `github` (optional) |

**Example:**

```json
[
  {
    "project": "ONAP",
    "gerrit": "gerrit.onap.org",
    "jenkins": "jenkins.onap.org",
    "github": "onap"
  },
  {
    "project": "O-RAN-SC",
    "gerrit": "gerrit.o-ran-sc.org",
    "jenkins": "jenkins.o-ran-sc.org",
    "github": "o-ran-sc"
  }
]
```text

### Repository Settings

**GitHub Pages:**

- Source: `gh-pages` branch
- Folder: `/ (root)`
- Build and deployment: GitHub Actions

**Actions Permissions:**

- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

---

## 📊 Report Structure

Each project generates these output formats:

### report.html

- Interactive HTML report with sortable tables
- Styled with embedded CSS
- JavaScript for table sorting and filtering
- Responsive design for mobile/desktop

### report_raw.json

- Complete dataset in JSON format
- Canonical data source
- Used for meta-reporting and trend analysis
- Contains all collected metrics

### report.md

- Human-readable Markdown format
- Suitable for viewing in GitHub or text editors
- Tables and structured formatting

### metadata.json

- Generation metadata
- Workflow run information
- Timestamps and versioning
- Environment context (production vs preview)

### config_resolved.json

- Applied configuration
- Shows effective settings used
- Useful for debugging

---

## 🎯 Use Cases

### 1. Weekly Production Reports

**Scenario:** Automated weekly reporting for stakeholders

**Workflow:** Production Reports (Monday 7am UTC)

**Output:** All 8 LF Gerrit projects processed, reports at `/production/`

**Stakeholders access:**

```text
https://<owner>.github.io/<repo>/production/
```text

---

### 2. Code Change Validation

**Scenario:** Developer modifies reporting logic and wants to verify changes

**Workflow:** PR Preview (automatic)

**Output:** First 2 projects processed as preview

**Developer reviews:**

- PR comment contains preview link
- Can verify changes without affecting production
- Safe to iterate on fixes

---

### 3. Meta-Reporting / Trend Analysis

**Scenario:** Track Jenkins → GitHub Actions migration progress over time

**Process:**

1. Download historical artifacts using `download-artifacts.sh`
2. Extract `report_raw.json` files
3. Analyze trends:
   - Number of Jenkins jobs over time
   - GitHub Actions adoption rate
   - Repository activity metrics
   - Migration progress indicators

**Example:**

```bash
export GITHUB_TOKEN=ghp_...
.github/scripts/download-artifacts.sh \
  reporting-production.yaml \
  ./meta-reporting-data \
  90
```text

---

### 4. On-Demand Reporting

**Scenario:** Need immediate report outside weekly schedule

**Workflow:** Manual trigger via workflow_dispatch

**Process:**

1. Go to Actions → Production Reports
2. Click "Run workflow"
3. Select branch
4. Wait for completion (~60 minutes)
5. View reports at production URL

---

## 🔧 Maintenance

### Regular Tasks

**Weekly:**

- ✅ Watch scheduled workflow runs
- ✅ Review workflow success/failure rates
- ✅ Check artifact storage usage

**Monthly:**

- ✅ Download artifacts for archival
- ✅ Review gh-pages branch size
- ✅ Clean up old PR preview directories
- ✅ Rotate authentication tokens

**Every 3 Months:**

- ✅ Review and update PROJECTS_JSON
- ✅ Audit permissions and access
- ✅ Update dependencies
- ✅ Review meta-reporting trends

### Monitoring

**Key Metrics:**

1. **Workflow Success Rate**
   - Target: >95% success rate
   - Watch: Actions tab

2. **Report Generation Time**
   - Target: <60 minutes per project
   - Optimize if exceeding limits

3. **Artifact Storage**
   - Check: Settings → Actions → Storage
   - Clean up if approaching quota

4. **GitHub Pages Uptime**
   - Check: Settings → Pages
   - Check deployment status

---

## 🚀 Benefits Over Legacy System

### Simplified Architecture

| Aspect | Legacy | New |
|--------|--------|-----|
| **Branches** | 2 (main + reports) | 1 (main) |
| **Tokens** | 2 required | 1 required |
| **Branches** | main (both repos) | main + gh-pages |
| **Authentication** | External PAT | Built-in GITHUB_TOKEN |

### Enhanced Features

- ✅ **PR Previews** - Verify changes before merge (new)
- ✅ **Longer Retention** - 90 days vs 30 days
- ✅ **Better Organization** - Separate production/preview paths
- ✅ **Meta-Reporting Support** - Download utility for historical analysis
- ✅ **Automatic Index Pages** - Styled landing pages

### Operational Benefits

- ✅ **Reduced Complexity** - No cross-repo operations
- ✅ **Better Security** - Fewer external tokens
- ✅ **Easier Maintenance** - Single repository to manage
- ✅ **Faster Development** - Test changes in PR previews
- ✅ **Better Tracking** - Comprehensive metadata

---

## 📈 Future Enhancements

### Short-Term (Next 3 months)

- [ ] Automated cleanup of old PR previews (>30 days)
- [ ] Email notifications for report completion
- [ ] Dashboard for meta-reporting trends
- [ ] Report comparison tool (week-over-week)

### Medium-Term (3-6 months)

- [ ] Advanced filtering in HTML reports
- [ ] Export to more formats (PDF, CSV)
- [ ] Integration with issue tracking
- [ ] Automated anomaly detection

### Long-Term (6+ months)

- [ ] Machine learning for migration predictions
- [ ] Custom report templates per project
- [ ] Real-time report updates
- [ ] API for programmatic access

---

## 📚 Documentation Index

| Document | Purpose | Audience |
|----------|---------|----------|
| [GITHUB_PAGES_SETUP.md](docs/GITHUB_PAGES_SETUP.md) | Complete setup guide | Admins |
| [MIGRATION_CHECKLIST.md](docs/MIGRATION_CHECKLIST.md) | Migration steps | Admins |
| [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md) | Common tasks | All users |
| [.github/scripts/README.md](.github/scripts/README.md) | Script documentation | Developers |
| [SETUP.md](SETUP.md) | General setup | All users |
| [README.md](README.md) | Project overview | All users |

---

## 🆘 Support

### Getting Help

1. **Check Documentation** - Start with [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)
2. **Review Workflow Logs** - Actions tab → Select run → View logs
3. **Verify Configuration** - Check secrets and variables
4. **Check GitHub Pages** - Settings → Pages → Deployment status
5. **Open Issue** - GitHub Issues tab with details

### Common Issues

See [GITHUB_PAGES_SETUP.md § Troubleshooting](docs/GITHUB_PAGES_SETUP.md#-troubleshooting)

---

## 🎓 Training Materials

### For Administrators

1. Read [GITHUB_PAGES_SETUP.md](docs/GITHUB_PAGES_SETUP.md)
2. Follow [MIGRATION_CHECKLIST.md](docs/MIGRATION_CHECKLIST.md)
3. Practice manual workflow triggers
4. Learn artifact download process

### For Developers

1. Read [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)
2. Create test PR to see preview system
3. Review script documentation
4. Understand report structure

### For Stakeholders

1. Bookmark production reports URL
2. Review sample report.html
3. Understand update schedule (Monday 7am UTC)
4. Know where to request changes (GitHub Issues)

---

## ✅ Migration Status

**Current Phase:** ✅ **Ready for Production**

**Completed:**

- ✅ New workflows created and tested
- ✅ GitHub Pages deployment configured
- ✅ Scripts developed and documented
- ✅ Comprehensive documentation written
- ✅ Migration checklist prepared

**Pending:**

- ⏳ Initial production deployment
- ⏳ Stakeholder validation
- ⏳ Legacy token removal
- ⏳ Old repository archival

---

## 📝 Changelog

### Version 2.0 (2025-01)

**Breaking Changes:**

- Moved from external gerrit-reports repository to GitHub Pages
- Remove `GERRIT_REPORTS_PAT_TOKEN` dependency
- Changed report URLs to GitHub Pages URLs

**New Features:**

- PR preview system for code validation
- Enhanced artifact retention (90 days)
- Automatic index page generation
- Artifact download utility for meta-reporting
- Separate production/preview workflows

**Improvements:**

- Simplified authentication
- Better error handling
- Comprehensive documentation
- Enhanced metadata tracking

### Version 1.0 (Legacy)

- Single workflow pushing to external repository
- 30-day artifact retention
- Manual report navigation
- Basic metadata

---

**Last Updated:** 2025-01-XX
**System Status:** ✅ Production Ready
**Next Review:** 2025-04-XX
