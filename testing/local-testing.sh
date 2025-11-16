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

# Configuration
ONAP_SERVER="gerrit.onap.org"
ODL_SERVER="git.opendaylight.org"
CLONE_BASE_DIR="/tmp"
REPORT_BASE_DIR="/tmp/reports"

# Directories
ONAP_CLONE_DIR="${CLONE_BASE_DIR}/${ONAP_SERVER}"
ODL_CLONE_DIR="${CLONE_BASE_DIR}/${ODL_SERVER}"
ONAP_REPORT_DIR="${REPORT_BASE_DIR}/onap"
ODL_REPORT_DIR="${REPORT_BASE_DIR}/opendaylight"

# Script directory (assuming script is in reporting-tool/testing/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if uvx is available
    if ! command -v uvx &> /dev/null; then
        log_error "uvx is not installed. Please install uv first:"
        log_error "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. Please install git."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Clean up existing report directories only
cleanup_directories() {
    log_info "Cleaning up existing report directories..."
    
    if [ -d "${ONAP_REPORT_DIR}" ]; then
        log_warning "Removing existing ${ONAP_REPORT_DIR}"
        rm -rf "${ONAP_REPORT_DIR}"
    fi
    
    if [ -d "${ODL_REPORT_DIR}" ]; then
        log_warning "Removing existing ${ODL_REPORT_DIR}"
        rm -rf "${ODL_REPORT_DIR}"
    fi
    
    log_success "Cleanup complete"
}

# Check if repositories already exist
check_existing_repos() {
    log_info "Checking for existing cloned repositories..."
    
    ONAP_EXISTS=false
    ODL_EXISTS=false
    
    if [ -d "${ONAP_CLONE_DIR}" ]; then
        log_info "Found existing ONAP repositories at ${ONAP_CLONE_DIR}"
        ONAP_EXISTS=true
    fi
    
    if [ -d "${ODL_CLONE_DIR}" ]; then
        log_info "Found existing OpenDaylight repositories at ${ODL_CLONE_DIR}"
        ODL_EXISTS=true
    fi
    
    if [ "$ONAP_EXISTS" = true ] && [ "$ODL_EXISTS" = true ]; then
        log_success "Both repository sets already exist, skipping clone step"
    elif [ "$ONAP_EXISTS" = true ]; then
        log_info "ONAP repositories exist, will only clone OpenDaylight"
    elif [ "$ODL_EXISTS" = true ]; then
        log_info "OpenDaylight repositories exist, will only clone ONAP"
    else
        log_info "No existing repositories found, will clone both"
    fi
    
    echo ""
}

# Create output directories
create_directories() {
    log_info "Creating output directories..."
    
    mkdir -p "${CLONE_BASE_DIR}"
    mkdir -p "${ONAP_REPORT_DIR}"
    mkdir -p "${ODL_REPORT_DIR}"
    
    log_success "Directories created"
}

# Clone ONAP repositories
clone_onap() {
    if [ -d "${ONAP_CLONE_DIR}" ]; then
        log_info "ONAP repositories already exist at ${ONAP_CLONE_DIR}, skipping clone"
        return 0
    fi
    
    log_info "Cloning ONAP repositories from ${ONAP_SERVER}..."
    
    uvx gerrit-clone clone \
        --host "${ONAP_SERVER}" \
        --path-prefix "${ONAP_CLONE_DIR}" \
        --skip-archived \
        --threads 4 \
        --clone-timeout 600 \
        --retry-attempts 3 \
        --move-conflicting
    
    if [ $? -eq 0 ]; then
        log_success "ONAP repositories cloned successfully to ${ONAP_CLONE_DIR}"
    else
        log_error "Failed to clone ONAP repositories"
        return 1
    fi
}

# Clone OpenDaylight repositories
clone_opendaylight() {
    if [ -d "${ODL_CLONE_DIR}" ]; then
        log_info "OpenDaylight repositories already exist at ${ODL_CLONE_DIR}, skipping clone"
        return 0
    fi
    
    log_info "Cloning OpenDaylight repositories from ${ODL_SERVER}..."
    
    uvx gerrit-clone clone \
        --host "${ODL_SERVER}" \
        --path-prefix "${ODL_CLONE_DIR}" \
        --skip-archived \
        --threads 4 \
        --clone-timeout 600 \
        --retry-attempts 3 \
        --move-conflicting
    
    if [ $? -eq 0 ]; then
        log_success "OpenDaylight repositories cloned successfully to ${ODL_CLONE_DIR}"
    else
        log_error "Failed to clone OpenDaylight repositories"
        return 1
    fi
}

# Generate ONAP report
generate_onap_report() {
    log_info "Generating ONAP report..."
    
    if [ ! -d "${ONAP_CLONE_DIR}" ]; then
        log_error "ONAP clone directory not found: ${ONAP_CLONE_DIR}"
        return 1
    fi
    
    cd "${REPO_ROOT}"
    
    # Use uv run to execute the reporting tool
    uv run reporting-tool generate \
        --project "ONAP" \
        --repos-path "${ONAP_CLONE_DIR}" \
        --output-dir "${ONAP_REPORT_DIR}" \
        --cache \
        --workers 4
    
    if [ $? -eq 0 ]; then
        log_success "ONAP report generated successfully in ${ONAP_REPORT_DIR}"
    else
        log_error "Failed to generate ONAP report"
        return 1
    fi
}

# Generate OpenDaylight report
generate_opendaylight_report() {
    log_info "Generating OpenDaylight report..."
    
    if [ ! -d "${ODL_CLONE_DIR}" ]; then
        log_error "OpenDaylight clone directory not found: ${ODL_CLONE_DIR}"
        return 1
    fi
    
    cd "${REPO_ROOT}"
    
    # Use uv run to execute the reporting tool
    uv run reporting-tool generate \
        --project "OpenDaylight" \
        --repos-path "${ODL_CLONE_DIR}" \
        --output-dir "${ODL_REPORT_DIR}" \
        --cache \
        --workers 4
    
    if [ $? -eq 0 ]; then
        log_success "OpenDaylight report generated successfully in ${ODL_REPORT_DIR}"
    else
        log_error "Failed to generate OpenDaylight report"
        return 1
    fi
}

# Display summary
show_summary() {
    echo ""
    log_info "=========================================="
    log_info "Testing Complete - Summary"
    log_info "=========================================="
    echo ""
    
    log_info "Clone Directories:"
    echo "  - ONAP:          ${ONAP_CLONE_DIR}"
    echo "  - OpenDaylight:  ${ODL_CLONE_DIR}"
    echo ""
    
    log_info "Report Directories:"
    echo "  - ONAP:          ${ONAP_REPORT_DIR}"
    echo "  - OpenDaylight:  ${ODL_REPORT_DIR}"
    echo ""
    
    log_info "Report Contents:"
    if [ -d "${ONAP_REPORT_DIR}" ]; then
        echo "  ONAP reports:"
        ls -lh "${ONAP_REPORT_DIR}" | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
    fi
    
    if [ -d "${ODL_REPORT_DIR}" ]; then
        echo "  OpenDaylight reports:"
        ls -lh "${ODL_REPORT_DIR}" | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
    fi
    
    echo ""
    log_success "You can now review the reports manually!"
    echo ""
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Local Testing Script for Reporting Tool"
    log_info "=========================================="
    echo ""
    
    # Step 1: Check prerequisites
    check_prerequisites
    echo ""
    
    # Step 2: Check for existing repositories
    check_existing_repos
    
    # Step 3: Clean up existing report directories
    cleanup_directories
    echo ""
    
    # Step 4: Create directories
    create_directories
    echo ""
    
    # Step 5: Clone repositories (if needed)
    log_info "Step 1/2: Cloning Gerrit Repositories"
    log_info "------------------------------------------"
    clone_onap
    echo ""
    clone_opendaylight
    echo ""
    
    # Step 6: Generate reports
    log_info "Step 2/2: Generating Reports"
    log_info "------------------------------------------"
    generate_onap_report
    echo ""
    generate_opendaylight_report
    echo ""
    
    # Step 7: Show summary
    show_summary
}

# Run main function
main "$@"