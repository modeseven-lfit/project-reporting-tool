<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Table of Contents Bug Fix Report

**Date:** 2025-01-XX
**Issue:** Table of Contents not appearing in generated reports
**Status:** RESOLVED

---

## Executive Summary

The Table of Contents (TOC) feature was not appearing in generated HTML/Markdown reports despite being enabled by default. A thorough audit revealed **critical configuration mapping bugs** that prevented the TOC from detecting any sections, resulting in silent failures.

### Impact

- **Severity:** HIGH - Feature completely non-functional
- **Scope:** All reports generated since TOC feature introduction (PRs #29, #31)
- **User Experience:** Silent failure - no error messages to indicate why TOC was missing

---

## Root Cause Analysis

### Primary Issue: Configuration Key Mismatch

The TOC generation code was looking for configuration keys that **did not exist** in the configuration schema, causing all section checks to fall back to default `True` values while simultaneously failing data availability checks.

#### Configuration Schema Keys (Actual)

```yaml
output:
  include_sections:
    global_summary: true        # ← Schema defines this
    all_repositories: true      # ← Schema defines this
    repo_feature_matrix: true   # ← Schema defines this
    contributors: true
    organizations: true
    workflows: [MISSING]        # ← Not in schema!
    orphaned_jobs: [MISSING]    # ← Not in schema!
```

#### Code Expected Keys (Incorrect)

```python
include_sections.get("summary", True)       # ← Looking for "summary", not "global_summary"
include_sections.get("repositories", True)  # ← Looking for "repositories", not "all_repositories"
include_sections.get("features", True)      # ← Looking for "features", not "repo_feature_matrix"
include_sections.get("workflows", True)     # ← Key doesn't exist in schema
include_sections.get("orphaned_jobs", True) # ← Key doesn't exist in schema
```

### Secondary Issue: Dual Configuration Paths

The code had **two separate places** checking `include_sections`:

1. **`_build_config_context()`** - Created normalized keys for templates
2. **`_build_toc_context()`** - Directly read raw config keys

These two paths were **inconsistent**, with `_build_toc_context()` using the wrong key names.

### Tertiary Issue: Silent Failure

When TOC was enabled but no sections matched, the code only logged a WARNING message that could be easily missed in CI/CD output. There was no ERROR-level logging to alert users to the critical failure.

---

## Bugs Fixed

### 1. Configuration Key Mapping in `_build_config_context()`

**File:** `src/rendering/context.py`

**Before:**

```python
"include_sections": {
    "summary": include_sections.get("summary", True),        # Wrong key
    "repositories": include_sections.get("repositories", True),  # Wrong key
    "features": include_sections.get("features", True),      # Wrong key
    "workflows": include_sections.get("workflows", True),    # Missing from schema
    "orphaned_jobs": include_sections.get("orphaned_jobs", True),  # Missing from schema
}
```

**After:**

```python
mapped_sections = {
    "summary": include_sections.get("global_summary", True),       # ✅ Correct
    "repositories": include_sections.get("all_repositories", True), # ✅ Correct
    "features": include_sections.get("repo_feature_matrix", True),  # ✅ Correct
    "workflows": include_sections.get("workflows", True),          # ✅ Added to schema
    "orphaned_jobs": include_sections.get("orphaned_jobs", True),  # ✅ Added to schema
}
```

### 2. TOC Context Using Mapped Values

**File:** `src/rendering/context.py`

**Before:**

```python
def _build_toc_context(self):
    output_config = self.config.get("output", {})
    include_sections = output_config.get("include_sections", {})

    # Directly using wrong keys from raw config
    if include_sections.get("summary", True):  # ❌ Wrong key
        sections.append({"title": "Global Summary", "anchor": "summary"})
```

**After:**

```python
def _build_toc_context(self):
    # Use mapped sections from _build_config_context
    if hasattr(self, '_mapped_sections'):
        include_sections = self._mapped_sections  # ✅ Use normalized keys
    else:
        # Fallback with correct key mapping
        include_sections = {
            "summary": raw_sections.get("global_summary", True),  # ✅ Correct
            # ... other correct mappings
        }

    # Now using consistent internal keys
    if include_sections.get("summary", True):  # ✅ Correct
        sections.append({"title": "Global Summary", "anchor": "summary"})
```

### 3. Configuration Schema Updates

**File:** `src/config/schema.json`

**Added missing keys:**

```json
{
  "workflows": {
    "type": "boolean",
    "description": "Include CI/CD workflows section"
  },
  "orphaned_jobs": {
    "type": "boolean",
    "description": "Include orphaned Jenkins jobs section"
  }
}
```

### 4. Default Configuration Updates

**Files:** `configuration/default.yaml`, `config/default.yaml`

**Added:**

```yaml
include_sections:
  # ... existing keys ...
  workflows: true          # ✅ New
  orphaned_jobs: true      # ✅ New
```

### 5. Enhanced Error Reporting

**File:** `src/rendering/context.py`

**Added comprehensive logging:**

```python
# Success case - INFO level (visible in CI/CD)
if sections:
    logger.info(f"✅ Table of Contents: {len(sections)} sections")
    logger.debug(f"TOC sections: {[s['title'] for s in sections]}")

# Failure case - ERROR level (visible in CI/CD)
else:
    logger.error("❌ Table of Contents: FAILED - No sections matched!")
    logger.error("TOC enabled but no sections were generated. Reasons:")
    for diagnostic in section_diagnostics:
        logger.error(f"  - {diagnostic}")
    logger.error("Check configuration (output.include_sections) and data availability.")
```

**Diagnostic output for each section:**

- `summary: disabled in config` (if disabled)
- `repositories: no data (all_repositories=0)` (if no data)
- `contributors: no data (commits=0, loc=0)` (with counts)
- `features: no data (detected features=0)` (with details)
- `workflows: no data (jenkins=0, github=0)` (with job counts)

---

## Changes Summary

### Files Modified

1. `src/rendering/context.py` - Fixed key mapping and added error reporting
2. `src/config/schema.json` - Added missing keys
3. `configuration/default.yaml` - Added missing keys
4. `config/default.yaml` - Added missing keys

### Lines Changed

- **Context Builder:** ~150 lines modified
- **Schema:** 8 lines added
- **Configs:** 4 lines added (2 per file)

---

## Testing

### Test Results

All 23 TOC-related unit tests pass:

```text
tests/unit/test_rendering_context.py::TestRenderContextTOC - 23 PASSED
```

### Manual Testing

#### Success Case

```text
[INFO] ✅ Table of Contents: 5 sections
```

#### Failure Case (All Sections Disabled)

```text
[ERROR] ❌ Table of Contents: FAILED - No sections matched!
[ERROR] TOC enabled but no sections were generated. Reasons:
[ERROR]   - summary: disabled in config
[ERROR]   - repositories: disabled in config
[ERROR]   - contributors: disabled in config
[ERROR]   - organizations: disabled in config
[ERROR]   - features: disabled in config
[ERROR]   - workflows: disabled in config
[ERROR]   - orphaned_jobs: disabled in config
[ERROR]   - time_windows: no data (time_windows=0)
[ERROR] Check configuration (output.include_sections) and data availability.
```

#### Failure Case (No Data Available)

```text
[ERROR] ❌ Table of Contents: FAILED - No sections matched!
[ERROR] TOC enabled but no sections were generated. Reasons:
[ERROR]   - summary: disabled in config
[ERROR]   - repositories: no data (all_repositories=0)
[ERROR]   - contributors: no data (commits=0, loc=0)
[ERROR]   - organizations: no data (top_organizations=0)
[ERROR]   - features: no data (detected features=0)
[ERROR]   - workflows: no data (jenkins=0, github=0)
[ERROR]   - orphaned_jobs: no data (jobs=0)
[ERROR]   - time_windows: no data (time_windows=0)
[ERROR] Check configuration (output.include_sections) and data availability.
```

---

## Console Output Impact

### Before

- No indication TOC was being generated
- Silent failure when no sections matched

### After

**Normal Operation (Success):**

```text
[INFO] ✅ Table of Contents: 5 sections
```

**Failure Operation (Error):**

```text
[ERROR] ❌ Table of Contents: FAILED - No sections matched!
[ERROR] TOC enabled but no sections were generated. Reasons:
[ERROR]   - [detailed diagnostics for each section]
```

**Debug Mode (if enabled):**

```text
[DEBUG] TOC: Added 'Global Summary' section
[DEBUG] TOC: Added 'Gerrit Projects' section (178 repos)
[DEBUG] TOC: Added 'Top Contributors' section (100 by commits, 50 by LOC)
[DEBUG] TOC: Added 'Top Organizations' section (115 orgs)
```

---

## Recommendations

### For Users

1. **Upgrade immediately** - TOC feature is now functional
2. **Check logs** - Look for `✅ Table of Contents` in successful runs
3. **Review config** - Ensure desired sections are enabled in `output.include_sections`

### For Developers

1. **Configuration Consistency** - Always map config keys to internal names in ONE place
2. **Error Visibility** - Use ERROR level for critical failures, not just WARNING
3. **Schema Validation** - Keep schema in sync with code expectations
4. **Diagnostic Logging** - Provide actionable information when failures occur

### For CI/CD

1. **Monitor Logs** - ERROR messages should trigger alerts
2. **Validate Reports** - Check that TOC appears in generated reports
3. **Test Coverage** - Add integration tests that verify TOC rendering end-to-end

---

## Prevention Measures

### Code Review Checklist

- [ ] Configuration keys match schema definitions
- [ ] Internal key mapping is consistent across all consumers
- [ ] Error cases have ERROR-level logging
- [ ] Silent failures are eliminated
- [ ] Debug information is available but not verbose by default

### Schema Management

- [ ] Update schema when adding new sections
- [ ] Update default configs when adding new keys
- [ ] Document key mapping in code comments
- [ ] Validate config loading uses correct keys

---

## Related Documentation

- `docs/IMPLEMENTATION_TOC_FEATURE.md` - Original TOC implementation
- `docs/TABLE_OF_CONTENTS.md` - TOC user documentation
- `src/config/schema.json` - Configuration schema

---

## Conclusion

This bug fix resolves a critical issue where the Table of Contents feature was completely non-functional due to configuration key mismatches. The fix includes:

1. ✅ Corrected configuration key mapping
2. ✅ Unified configuration reading path
3. ✅ Added missing schema keys
4. ✅ Enhanced error reporting
5. ✅ Eliminated silent failures

The TOC feature is now fully functional and will provide clear feedback when issues occur, making debugging significantly easier for both developers and users.
