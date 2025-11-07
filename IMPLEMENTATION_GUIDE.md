<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Implementation Guide - GitHub Pages Reporting System

**Version:** 2.0
**Status:** Ready for Deployment
**Date:** 2025-01
**Estimated Implementation Time:** 2-4 hours

---

## 🎯 Executive Summary

This guide summarizes the complete redesign of the Linux Foundation Gerrit reporting system. The new architecture eliminates external repository dependencies, simplifies authentication, and adds PR preview capabilities while maintaining all existing functionality.

### What Changed

**Before:**

- Reports pushed to separate `modeseven-lfit/gerrit-reports` repository
- Required `GERRIT_REPORTS_PAT_TOKEN` for cross-repo access
- Single workflow for all report generation
- No preview system for code changes
- 30-day artifact retention

**After:**

- Reports published to GitHub Pages on same repository
- Uses built-in `GITHUB_TOKEN` (no external token needed)
- Separate workflows for production and PR previews
- Automatic preview generation for code changes
- 90-day artifact retention for meta-reporting

### Key Benefits

1. **Simplified Operations** - One less repository, one less token
2. **Automated Testing** - PR previews verify changes before merge
3. **Enhanced Data Retention** - 90-day artifacts for trend analysis
4. **Improved Security** - Fewer external authentication points
5. **Better Organization** - Clear separation of production and preview reports

---

## 📋 What We Built

### 1. New Workflows

**`reporting-production.yaml`**

- Scheduled: Monday 7:00 AM UTC
- Processes all 8 Linux Foundation Gerrit servers
- Publishes to `/production/` on GitHub Pages
- 90-day artifact retention
- ~60-90 minutes execution time

**`reporting-pr-preview.yaml`**

- Triggered by PRs modifying reporting code
- Processes first 2 projects (resource optimization)
- Publishes to `/pr-preview/<pr-number>/`
- 30-day artifact retention
- Comments on PR with preview links
- ~30-45 minutes execution time

### 2. Supporting Scripts

**`generate-index.sh`**

- Creates styled HTML index pages
- Lists all available reports
- Generates both root and section indexes
- Includes metadata (timestamps, project info)

**`download-artifacts.sh`**

- Downloads workflow run artifacts for meta-reporting
- Filters by date range
- Organizes data for analysis
- Generates summary index
- Enables historical trend tracking

### 3. Documentation

| Document | Purpose |
|----------|---------|
| `GITHUB_PAGES_SETUP.md` | Complete setup instructions |
| `MIGRATION_CHECKLIST.md` | Step-by-step migration guide |
| `QUICK_REFERENCE.md` | Common tasks quick reference |
| `REPORTING_SYSTEM_OVERVIEW.md` | System architecture and design |
| `.github/scripts/README.md` | Script documentation |

### 4. GitHub Pages Structure

```text
https://<owner>.github.io/<repo>/
├── index.html                    # Landing page
├── production/                   # Official weekly reports
│   ├── index.html               # Report listing
│   └── <project-slug>/
│       ├── report.html          # Interactive report
│       ├── report_raw.json      # Complete data
│       ├── report.md            # Markdown format
│       └── metadata.json        # Generation info
└── pr-preview/                  # PR validation reports
    └── <pr-number>/
        └── ...
```text

---

## 🚀 Implementation Steps

### Phase 1: Preparation (30 minutes)

1. **Review Documentation**
   - Read this guide in full
   - Review [GITHUB_PAGES_SETUP.md](docs/GITHUB_PAGES_SETUP.md)
   - Check [MIGRATION_CHECKLIST.md](docs/MIGRATION_CHECKLIST.md)

2. **Backup Current System**
   - Export existing reports (if any)
   - Document current configuration
   - Save current secrets/variables

3. **Verify Prerequisites**
   - Ensure you have admin access to repository
   - Verify `CLASSIC_READ_ONLY_PAT_TOKEN` exists
   - Check `PROJECTS_JSON` variable is valid
   - Confirm `LF_GERRIT_INFO_MASTER_SSH_KEY` if using SSH

### Phase 2: Setup (45 minutes)

1. **Enable GitHub Pages**

   ```bash
   # In repository Settings → Pages
   # Source: Deploy from a branch
   # Branch: gh-pages
   # Folder: / (root)
   ```

2. **Create gh-pages Branch**

   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   mkdir -p production pr-preview
   cat > index.html <<'EOF'
   <!DOCTYPE html>
   <html>
   <head><title>Reports Coming Soon</title></head>
   <body><h1>Reports will be available soon</h1></body>
   </html>
   EOF
   git add .
   git commit -m "chore: initialize gh-pages branch"
   git push origin gh-pages
   git checkout main
   ```

3. **Configure Permissions**

   ```bash
   # Settings → Actions → General
   # Workflow permissions:
   # ✅ Read and write permissions
   # ✅ Allow GitHub Actions to create and approve pull requests
   ```

4. **Verify Secrets and Variables**
   - Go to Settings → Secrets and variables → Actions
   - Verify `CLASSIC_READ_ONLY_PAT_TOKEN` exists
   - Verify `LF_GERRIT_INFO_MASTER_SSH_KEY` exists (optional)
   - Check Variables tab for `PROJECTS_JSON`
   - Check JSON syntax with: `echo '$PROJECTS_JSON' | jq .`

5. **Make Scripts Executable**

   ```bash
   chmod +x .github/scripts/generate-index.sh
   chmod +x .github/scripts/download-artifacts.sh
   git add .github/scripts/
   git commit -m "chore: make scripts executable"
   git push origin main
   ```

### Phase 3: Testing (60 minutes)

1. **Manual Test Run**
   - Go to Actions tab
   - Select "📊 Production Reports"
   - Click "Run workflow"
   - Select `main` branch
   - Click "Run workflow"
   - Watch execution progress (~60 minutes)

2. **Verify Workflow Execution**
   - Watch each job complete
   - Check for errors in logs
   - Verify all projects processed
   - Confirm artifacts uploaded

3. **Verify GitHub Pages**

   ```bash
   # Check gh-pages branch
   git fetch origin gh-pages
   git checkout gh-pages
   ls -la production/
   cat production/*/metadata.json | jq .
   git checkout main
   ```

4. **Access Reports**
   - Open browser to: `https://<owner>.github.io/<repo>/`
   - Verify landing page loads
   - Click "Production Reports"
   - Open at least one `report.html`
   - Check `report_raw.json` downloads
   - Verify all projects listed

5. **Test PR Preview**
   - Create test branch: `git checkout -b test-pr-preview`
   - Make minor change to Python file
   - Commit and push
   - Create PR
   - Wait for workflow to complete
   - Verify bot comment appears
   - Click preview link
   - Confirm reports display as expected
   - Close or merge PR

### Phase 4: Production Validation (1 week)

1. **Wait for Scheduled Run**
   - First scheduled run: Next Monday 7:00 AM UTC
   - Watch workflow execution
   - Verify automatic trigger works

2. **Check Output**
   - Check all projects processed
   - Compare with legacy reports (if available)
   - Verify data accuracy
   - Test report accessibility

3. **Stakeholder Review**
   - Share GitHub Pages URL with stakeholders
   - Collect feedback
   - Address any concerns
   - Document any issues

### Phase 5: Cleanup (30 minutes)

**After 2 weeks of successful operation:**

1. **Remove Legacy Token**
   - Go to Settings → Secrets and variables → Actions
   - Delete `GERRIT_REPORTS_PAT_TOKEN`
   - Revoke token on GitHub

2. **Archive Old Repository** (Optional)
   - Archive `modeseven-lfit/gerrit-reports` repository
   - Add README explaining migration
   - Update documentation links

3. **Remove Deprecated Files**

   ```bash
   git rm .github/workflows/reporting.yaml.deprecated
   git rm .github/scripts/publish-reports.sh.deprecated
   git commit -m "chore: remove deprecated files"
   git push origin main
   ```

4. **Update Documentation**
   - Update any external links
   - Notify stakeholders of new URLs
   - Update runbooks/procedures

---

## 🔍 Verification Checklist

Use this checklist to confirm successful deployment:

### Configuration

- [ ] GitHub Pages enabled and set to `gh-pages` branch
- [ ] `gh-pages` branch exists with initial structure
- [ ] Workflow permissions set to "Read and write"
- [ ] `CLASSIC_READ_ONLY_PAT_TOKEN` secret present
- [ ] `LF_GERRIT_INFO_MASTER_SSH_KEY` secret present (or HTTPS fallback)
- [ ] `PROJECTS_JSON` variable valid JSON
- [ ] Scripts are executable

### Workflows

- [ ] Production workflow exists and runs
- [ ] PR preview workflow exists and runs
- [ ] Old workflow renamed/disabled
- [ ] Manual trigger works
- [ ] Scheduled trigger configured (Monday 7am UTC)

### GitHub Pages

- [ ] Root index page loads
- [ ] Production reports directory exists
- [ ] PR preview directory exists
- [ ] Reports are accessible via HTTPS
- [ ] Index pages display as expected
- [ ] Report links work

### Artifacts

- [ ] Raw data artifacts upload (90-day retention)
- [ ] Report artifacts upload (90-day retention)
- [ ] Clone manifests upload
- [ ] Artifact downloads work

### PR Preview System

- [ ] Workflow triggers on code changes
- [ ] Limited to 2 projects
- [ ] Bot comments on PR
- [ ] Preview URL accessible
- [ ] Preview doesn't overwrite production

### Production Reports

- [ ] All 8 projects process without errors
- [ ] Reports publish to `/production/`
- [ ] Index page lists all projects
- [ ] Metadata files present
- [ ] Data appears accurate

---

## 📊 Success Metrics

Track these metrics to ensure successful deployment:

### Operational Metrics

- **Workflow Success Rate:** Target >95%
- **Report Generation Time:** Target <90 minutes
- **Artifact Storage Usage:** Check monthly
- **GitHub Pages Uptime:** Target 99.9%

### Quality Metrics

- **Data Completeness:** All projects reporting
- **Data Accuracy:** Compare with legacy system
- **Report Accessibility:** All stakeholders can access
- **Update Frequency:** Weekly on schedule

### User Satisfaction

- **Ease of Access:** Stakeholder feedback
- **Report Clarity:** Readability and usefulness
- **Performance:** Page load times
- **Reliability:** Consistent weekly updates

---

## 🐛 Troubleshooting

### Workflow Fails

**Symptom:** Workflow run fails with errors

**Steps:**

1. Check Actions tab for specific error
2. Review job logs for details
3. Verify secrets are present
4. Check `PROJECTS_JSON` syntax
5. Check Gerrit server accessibility
6. Review recent code changes

**Common Causes:**

- Missing or expired secrets
- Invalid JSON in `PROJECTS_JSON`
- Gerrit server downtime
- Network connectivity issues

### Reports Not Appearing

**Symptom:** Workflow completes but reports don't show on Pages

**Steps:**

1. Check gh-pages branch: `git checkout gh-pages && ls -la production/`
2. Verify GitHub Pages deployment status (Settings → Pages)
3. Check workflow logs for publish job errors
4. Verify branch permissions
5. Force Pages rebuild if needed

**Common Causes:**

- Pages not enabled
- Wrong branch selected
- Deployment failure
- Permission issues

### PR Preview Not Working

**Symptom:** PR doesn't trigger workflow or no bot comment

**Steps:**

1. Verify PR modifies correct file paths
2. Check workflow permissions
3. Review PR preview job logs
4. Verify bot has permission to comment
5. Check gh-pages write access

**Common Causes:**

- PR doesn't change trigger paths
- Insufficient permissions
- Workflow disabled
- Bot authentication issue

---

## 🔧 Configuration Reference

### Minimal Configuration

```bash
# Required Secrets
CLASSIC_READ_ONLY_PAT_TOKEN=ghp_...

# Required Variables
PROJECTS_JSON='[
  {
    "project": "Project Name",
    "gerrit": "gerrit.example.org"
  }
]'

# Repository Settings
# - GitHub Pages: gh-pages branch, / (root)
# - Actions: Read and write permissions
```text

### Full Configuration

```bash
# Required Secrets
CLASSIC_READ_ONLY_PAT_TOKEN=ghp_...

# Optional Secrets
LF_GERRIT_INFO_MASTER_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----"

# Required Variables
PROJECTS_JSON='[
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
]'
```text

---

## 📞 Support and Resources

### Documentation

- [Complete Setup Guide](docs/GITHUB_PAGES_SETUP.md)
- [Migration Checklist](docs/MIGRATION_CHECKLIST.md)
- [Quick Reference](docs/QUICK_REFERENCE.md)
- [System Overview](REPORTING_SYSTEM_OVERVIEW.md)

### Getting Help

1. Review documentation
2. Check workflow logs
3. Verify configuration
4. Open GitHub issue with details

### Contact

- **Technical Issues:** GitHub Issues
- **Questions:** Check documentation
- **Emergency:** Follow rollback procedure in migration checklist

---

## 🎓 Training Resources

### For Administrators

1. Read [GITHUB_PAGES_SETUP.md](docs/GITHUB_PAGES_SETUP.md)
2. Follow this implementation guide
3. Practice manual workflow triggers
4. Review artifact download process

### For Developers

1. Read [QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md)
2. Create test PR to see preview system
3. Review script documentation
4. Understand report data structure

### For Stakeholders

1. Bookmark production URL
2. Review sample reports
3. Understand update schedule
4. Know how to request changes

---

## ✅ Post-Implementation Tasks

### Immediate (Week 1)

- [ ] Watch first scheduled run
- [ ] Verify all projects reporting
- [ ] Collect initial stakeholder feedback
- [ ] Document any issues encountered

### Short-term (Month 1)

- [ ] Remove legacy token after 2 weeks
- [ ] Archive old repository (optional)
- [ ] Update external documentation
- [ ] Set up artifact archival process

### Ongoing

- [ ] Weekly workflow monitoring
- [ ] Monthly artifact downloads for meta-reporting
- [ ] Configuration reviews every 3 months
- [ ] Regular stakeholder feedback collection

---

## 📈 Future Roadmap

### Phase 2 Enhancements

- Automated cleanup of old PR previews
- Email notifications for report completion
- Enhanced meta-reporting dashboard
- Week-over-week comparison tools

### Phase 3 Features

- Advanced report filtering
- More export formats (PDF, CSV)
- Integration with issue tracking
- Automated anomaly detection

---

## 📝 Implementation Notes

**Document your implementation:**

```text
Implementation Date: _______________
Implemented By: _______________
Test Results: _______________
Issues Encountered: _______________
Stakeholder Approval: _______________
Production Date: _______________
```text

---

## 🎉 Conclusion

This redesigned reporting system provides a robust, maintainable, and scalable solution for Linux Foundation Gerrit project reporting. The elimination of external dependencies, addition of PR preview capabilities, and enhanced artifact retention position the system well for future meta-reporting and trend analysis needs.

**Key Takeaways:**

- ✅ Simpler architecture (1 repo vs 2)
- ✅ Better security (fewer tokens)
- ✅ Enhanced testing (PR previews)
- ✅ Improved data retention (90 days)
- ✅ Ready for meta-reporting

**Next Steps:**

1. Follow Phase 1-5 implementation steps
2. Complete verification checklist
3. Watch for one week
4. Collect stakeholder feedback
5. Remove legacy dependencies

---

**Implementation Status:** 🟢 Ready to Deploy
**Estimated Time:** 2-4 hours
**Risk Level:** Low (rollback plan available)
**Last Updated:** 2025-01-XX
