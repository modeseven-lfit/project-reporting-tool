<!--
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Migration Checklist: GitHub Pages Reporting System

This checklist guides you through migrating from the legacy reporting system to the new GitHub Pages-based system.

---

## 📋 Pre-Migration Checklist

### ✅ Review and Planning

- [ ] Review the [GitHub Pages Setup Guide](GITHUB_PAGES_SETUP.md)
- [ ] Understand the new workflow architecture
- [ ] Identify all stakeholders and notify them of changes
- [ ] Schedule migration during low-traffic period
- [ ] Document current system configuration
- [ ] Review PROJECTS_JSON for accuracy

### ✅ Backup Current System

- [ ] Export existing reports from `gerrit-reports` repository
- [ ] Download all workflow run artifacts (last 90 days)
- [ ] Document current secret configurations
- [ ] Save current workflow files for reference
- [ ] Archive any custom scripts or configurations

---

## 🚀 Migration Steps

### Step 1: Repository Preparation

- [ ] **1.1** Create `gh-pages` branch

  ```bash
  git checkout --orphan gh-pages
  git rm -rf .
  mkdir -p production pr-preview
  # Create placeholder index.html
  git add .
  git commit -m "chore: initialize gh-pages branch"
  git push origin gh-pages
  git checkout main
  ```

- [ ] **1.2** Enable GitHub Pages
  - [ ] Go to Settings → Pages
  - [ ] Set source to `gh-pages` branch
  - [ ] Set folder to `/ (root)`
  - [ ] Save settings

- [ ] **1.3** Configure repository permissions
  - [ ] Settings → Actions → General
  - [ ] Enable "Read and write permissions"
  - [ ] Enable "Allow GitHub Actions to create and approve pull requests"
  - [ ] Save settings

### Step 2: Secrets and Variables Management

- [ ] **2.1** Verify existing secrets
  - [ ] `CLASSIC_READ_ONLY_PAT_TOKEN` is present
  - [ ] `LF_GERRIT_INFO_MASTER_SSH_KEY` is present (optional)
  - [ ] Token has not expired
  - [ ] Token has correct permissions

- [ ] **2.2** Verify PROJECTS_JSON variable
  - [ ] Variable is properly formatted JSON
  - [ ] All projects have required fields (project, gerrit)
  - [ ] Optional fields (jenkins, github) are present if needed
  - [ ] JSON syntax is valid

- [ ] **2.3** Remove deprecated secret (AFTER migration is complete)
  - [ ] `GERRIT_REPORTS_PAT_TOKEN` (keep until verified working)

### Step 3: Workflow Files

- [ ] **3.1** Verify new workflow files exist
  - [ ] `.github/workflows/reporting-production.yaml`
  - [ ] `.github/workflows/reporting-pr-preview.yaml`
  - [ ] `.github/scripts/generate-index.sh`
  - [ ] `.github/scripts/download-artifacts.sh`

- [ ] **3.2** Verify old workflow is disabled
  - [ ] `.github/workflows/reporting.yaml.deprecated` (should be renamed)
  - [ ] `.github/scripts/publish-reports.sh.deprecated` (should be renamed)

- [ ] **3.3** Make scripts executable

  ```bash
  chmod +x .github/scripts/generate-index.sh
  chmod +x .github/scripts/download-artifacts.sh
  ```

- [ ] **3.4** Commit and push changes

  ```bash
  git add .github/
  git commit -m "feat: migrate to GitHub Pages reporting system"
  git push origin main
  ```

### Step 4: Initial Test Run

- [ ] **4.1** Manually trigger production workflow
  - [ ] Go to Actions tab
  - [ ] Select "📊 Production Reports"
  - [ ] Click "Run workflow"
  - [ ] Select `main` branch
  - [ ] Run workflow

- [ ] **4.2** Monitor workflow execution
  - [ ] Verify job starts successfully
  - [ ] Check "verify" job completes
  - [ ] Monitor "analyze" jobs for each project
  - [ ] Verify "publish" job completes
  - [ ] Review "summary" job output

- [ ] **4.3** Verify workflow artifacts
  - [ ] Raw data artifacts uploaded
  - [ ] Report artifacts uploaded
  - [ ] Clone manifests uploaded
  - [ ] All expected artifacts present

### Step 5: Verify GitHub Pages Deployment

- [ ] **5.1** Check gh-pages branch

  ```bash
  git fetch origin gh-pages
  git checkout gh-pages
  ls -la production/
  git log --oneline -5
  git checkout main
  ```

- [ ] **5.2** Verify Pages deployment
  - [ ] Go to Settings → Pages
  - [ ] Check deployment status (should be green)
  - [ ] Note the published URL

- [ ] **5.3** Access and verify reports
  - [ ] Open `https://<owner>.github.io/<repo>/`
  - [ ] Verify landing page loads
  - [ ] Click "Production Reports"
  - [ ] Verify project list appears
  - [ ] Open at least one report.html
  - [ ] Verify report content is correct
  - [ ] Check report_raw.json is accessible
  - [ ] Verify metadata.json exists

### Step 6: Test PR Preview System

- [ ] **6.1** Create test PR
  - [ ] Create feature branch
  - [ ] Make minor change to Python code
  - [ ] Push and create PR

- [ ] **6.2** Monitor PR preview workflow
  - [ ] Workflow triggers automatically
  - [ ] Limited to 2 projects
  - [ ] All jobs complete successfully

- [ ] **6.3** Verify PR preview
  - [ ] Bot comments on PR with preview link
  - [ ] Preview URL is accessible
  - [ ] Preview reports load correctly
  - [ ] Preview does NOT overwrite production

- [ ] **6.4** Clean up test PR
  - [ ] Close or merge test PR
  - [ ] Verify gh-pages has pr-preview directory

### Step 7: Production Validation

- [ ] **7.1** Wait for scheduled run (Monday 7am UTC)
  - [ ] Scheduled workflow triggers correctly
  - [ ] All projects process successfully
  - [ ] Reports publish to GitHub Pages
  - [ ] No errors or warnings

- [ ] **7.2** Compare with legacy system
  - [ ] Verify all projects are included
  - [ ] Compare report content accuracy
  - [ ] Check data completeness
  - [ ] Validate metrics are consistent

- [ ] **7.3** Stakeholder validation
  - [ ] Share GitHub Pages URL with stakeholders
  - [ ] Collect feedback on report format
  - [ ] Verify report accessibility
  - [ ] Confirm data accuracy

---

## 🧹 Post-Migration Cleanup

### Step 8: Remove Legacy System Dependencies

- [ ] **8.1** Remove deprecated secret
  - [ ] Verify new system working for 2+ weeks
  - [ ] Delete `GERRIT_REPORTS_PAT_TOKEN` secret
  - [ ] Revoke token on GitHub

- [ ] **8.2** Archive old repository (optional)
  - [ ] Archive `gerrit-reports` repository
  - [ ] Add README explaining migration
  - [ ] Update any documentation pointing to old repo

- [ ] **8.3** Clean up deprecated files
  - [ ] Delete `.github/workflows/reporting.yaml.deprecated`
  - [ ] Delete `.github/scripts/publish-reports.sh.deprecated`
  - [ ] Commit cleanup changes

### Step 9: Documentation Updates

- [ ] **9.1** Update main README
  - [ ] Add link to GitHub Pages reports
  - [ ] Update workflow documentation
  - [ ] Add PR preview instructions

- [ ] **9.2** Update SETUP.md
  - [ ] Remove references to GERRIT_REPORTS_PAT_TOKEN
  - [ ] Add GitHub Pages setup steps
  - [ ] Update architecture diagrams

- [ ] **9.3** Create runbook
  - [ ] Document common operations
  - [ ] Add troubleshooting procedures
  - [ ] Include rollback plan

### Step 10: Monitoring and Optimization

- [ ] **10.1** Set up monitoring
  - [ ] Enable workflow failure notifications
  - [ ] Monitor GitHub Pages uptime
  - [ ] Track artifact storage usage
  - [ ] Monitor workflow execution times

- [ ] **10.2** Optimize performance
  - [ ] Review parallel execution settings
  - [ ] Adjust timeout values if needed
  - [ ] Optimize artifact compression
  - [ ] Fine-tune retention periods

- [ ] **10.3** Create meta-reporting baseline
  - [ ] Download first 30 days of artifacts
  - [ ] Set up tracking spreadsheet/dashboard
  - [ ] Document baseline metrics
  - [ ] Schedule regular data collection

---

## 🔄 Rollback Plan

If critical issues arise, use this rollback procedure:

### Immediate Rollback

- [ ] **R1** Disable new workflows
  - [ ] Rename production workflow to `.disabled`
  - [ ] Rename PR preview workflow to `.disabled`
  - [ ] Push changes

- [ ] **R2** Re-enable legacy workflow
  - [ ] Rename `reporting.yaml.deprecated` back to `reporting.yaml`
  - [ ] Rename `publish-reports.sh.deprecated` back to `publish-reports.sh`
  - [ ] Push changes

- [ ] **R3** Restore GERRIT_REPORTS_PAT_TOKEN
  - [ ] Re-add secret to repository
  - [ ] Verify token is valid

- [ ] **R4** Manually trigger legacy workflow
  - [ ] Run workflow to verify functionality
  - [ ] Monitor for successful completion

### Root Cause Analysis

- [ ] Document what went wrong
- [ ] Identify fix or workaround
- [ ] Test fix in isolated environment
- [ ] Plan re-migration attempt

---

## ✅ Success Criteria

The migration is considered successful when:

- [x] GitHub Pages site is live and accessible
- [x] Production reports generate on schedule (Monday 7am UTC)
- [x] All configured projects produce reports
- [x] PR preview system works correctly
- [x] Artifacts are uploaded with correct retention
- [x] No dependency on external repositories
- [x] Stakeholders can access and use reports
- [x] System runs for 2+ consecutive weeks without issues

---

## 📊 Validation Timeline

| Day | Activity | Validation |
|-----|----------|------------|
| Day 0 | Initial setup | Manual test run successful |
| Day 1 | Monitor first automated run | Reports published correctly |
| Day 7 | First scheduled run | All projects complete |
| Day 14 | Second scheduled run | Consistent results |
| Day 21 | Third scheduled run | Stakeholder approval |
| Day 30 | Migration complete | Remove legacy dependencies |

---

## 🆘 Troubleshooting Quick Reference

### Workflow Fails

1. Check Actions tab for error logs
2. Verify all secrets are present
3. Check PROJECTS_JSON syntax
4. Review individual job logs

### Reports Not Appearing

1. Check gh-pages branch exists
2. Verify GitHub Pages is enabled
3. Check workflow completed successfully
4. Review publish job logs

### PR Preview Not Working

1. Verify PR modifies correct paths
2. Check workflow permissions
3. Review PR preview job logs
4. Verify gh-pages write access

### Artifacts Missing

1. Check workflow upload steps
2. Verify retention settings
3. Check storage quota limits
4. Review artifact upload logs

---

## 📞 Support Contacts

- **Technical Issues:** [GitHub Issues](https://github.com/modeseven-lfit/reporting-tool/issues)
- **Questions:** Check [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)
- **Emergency Rollback:** Follow rollback plan above

---

## 📝 Notes

Use this section to track your migration progress:

```text
Migration Start Date: _______________
Completed By: _______________
Issues Encountered: _______________
Lessons Learned: _______________
Final Status: _______________
```text

---

**Next Steps After Completion:**

1. ✅ Monitor for 30 days
2. ✅ Collect stakeholder feedback
3. ✅ Set up meta-reporting automation
4. ✅ Document any customizations
5. ✅ Train team on new system

---

**Migration Version:** 1.0
**Last Updated:** 2025-01-XX
**Status:** Ready for use
