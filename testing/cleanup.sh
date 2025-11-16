#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Cleanup function
cleanup_all() {
    log_info "=========================================="
    log_info "Cleanup Script for Test Repositories"
    log_info "=========================================="
    echo ""
    
    # List of directories to clean
    DIRS_TO_CLEAN=(
        "/tmp/gerrit.onap.org"
        "/tmp/git.opendaylight.org"
        "/tmp/reports"
    )
    
    # Also clean up any git repositories directly in /tmp (from the failed run)
    log_info "Checking for git repositories in /tmp..."
    
    # Count repositories to clean
    count=0
    for dir in "${DIRS_TO_CLEAN[@]}"; do
        if [ -d "$dir" ]; then
            ((count++))
        fi
    done
    
    # Find any .git directories directly in /tmp (excluding system directories)
    while IFS= read -r git_dir; do
        repo_dir=$(dirname "$git_dir")
        # Only include if it's directly in /tmp, not in subdirectories
        if [ "$(dirname "$repo_dir")" = "/tmp" ]; then
            # Exclude our expected directories
            if [[ ! "$repo_dir" =~ ^/tmp/(gerrit\.onap\.org|git\.opendaylight\.org|reports) ]]; then
                DIRS_TO_CLEAN+=("$repo_dir")
                ((count++))
            fi
        fi
    done < <(find /tmp -maxdepth 2 -name ".git" -type d 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        log_success "No test repositories found to clean up"
        exit 0
    fi
    
    log_warning "Found $count directories to clean up:"
    for dir in "${DIRS_TO_CLEAN[@]}"; do
        if [ -d "$dir" ]; then
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  - $dir ($size)"
        fi
    done
    echo ""
    
    # Ask for confirmation
    read -p "Are you sure you want to delete these directories? (y/N) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Starting cleanup..."
    
    # Remove directories
    removed=0
    for dir in "${DIRS_TO_CLEAN[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Removing $dir..."
            if rm -rf "$dir"; then
                ((removed++))
            else
                log_error "Failed to remove $dir"
            fi
        fi
    done
    
    echo ""
    log_success "Cleanup complete! Removed $removed directories"
}

# Run cleanup
cleanup_all