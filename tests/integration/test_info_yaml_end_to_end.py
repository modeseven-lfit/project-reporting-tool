# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

"""
End-to-end integration tests for INFO.yaml feature.

Tests complete workflows from collection through enrichment to rendering,
validating the entire INFO.yaml pipeline.

Phase 5: Comprehensive Testing
"""

import shutil
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

import pytest
from src.collectors.info_yaml import InfoYamlCollector
from src.domain.author_metrics import AuthorMetrics
from src.domain.info_yaml import ProjectInfo
from src.domain.repository_metrics import RepositoryMetrics
from src.enrichment.info_yaml import InfoYamlEnricher
from src.rendering.info_yaml_renderer import InfoYamlRenderer


@pytest.fixture
def temp_info_master():
    """Create temporary info-master directory structure."""
    temp_dir = tempfile.mkdtemp()
    info_master = Path(temp_dir) / "info-master"
    info_master.mkdir()

    # Create gerrit server directories
    gerrit1 = info_master / "gerrit.example.org"
    gerrit1.mkdir()

    gerrit2 = info_master / "gerrit.other.org"
    gerrit2.mkdir()

    yield info_master

    # Cleanup
    shutil.rmtree(temp_dir)


@pytest.fixture
def sample_info_yaml_content():
    """Sample INFO.yaml content."""
    return """---
project: 'test-project'
project_creation_date: '2020-01-15'
lifecycle_state: 'Active'
project_lead:
    name: 'Alice Lead'
    email: 'alice@example.com'
    company: 'Acme Corp'
    id: 'alice123'
    timezone: 'America/Los_Angeles'
committers:
    - name: 'Alice Lead'
      email: 'alice@example.com'
      company: 'Acme Corp'
      id: 'alice123'
      timezone: 'America/Los_Angeles'
    - name: 'Bob Developer'
      email: 'bob@example.com'
      company: 'Beta Inc'
      id: 'bob456'
      timezone: 'America/New_York'
    - name: 'Charlie Contributor'
      email: 'charlie@example.com'
      company: 'Gamma LLC'
      id: 'charlie789'
      timezone: 'Europe/London'
issue_tracking:
    type: 'jira'
    url: 'https://jira.example.com/projects/TEST'
repositories:
    - 'test-repo-1'
    - 'test-repo-2'
"""


@pytest.fixture
def create_test_projects(temp_info_master, sample_info_yaml_content):
    """Create test INFO.yaml files."""
    # Project 1: Active project
    project1_dir = temp_info_master / "gerrit.example.org" / "active-project"
    project1_dir.mkdir(parents=True)
    (project1_dir / "INFO.yaml").write_text(sample_info_yaml_content)

    # Project 2: Incubation project
    project2_yaml = sample_info_yaml_content.replace(
        "project: 'test-project'", "project: 'incubation-project'"
    ).replace("lifecycle_state: 'Active'", "lifecycle_state: 'Incubation'")
    project2_dir = temp_info_master / "gerrit.example.org" / "incubation-project"
    project2_dir.mkdir(parents=True)
    (project2_dir / "INFO.yaml").write_text(project2_yaml)

    # Project 3: Archived project (different server)
    project3_yaml = sample_info_yaml_content.replace(
        "project: 'test-project'", "project: 'archived-project'"
    ).replace("lifecycle_state: 'Active'", "lifecycle_state: 'Archived'")
    project3_dir = temp_info_master / "gerrit.other.org" / "archived-project"
    project3_dir.mkdir(parents=True)
    (project3_dir / "INFO.yaml").write_text(project3_yaml)

    return temp_info_master


@pytest.fixture
def sample_git_metrics():
    """Create sample Git metrics for enrichment."""
    # Create author metrics with varying activity levels
    now = datetime.now()

    # Alice: Recent activity (current)
    alice = AuthorMetrics(
        author_name="Alice Lead",
        author_email="alice@example.com",
        commit_count=150,
        lines_added=5000,
        lines_deleted=2000,
        first_commit_date=now - timedelta(days=730),
        last_commit_date=now - timedelta(days=30),
    )

    # Bob: Moderate activity (active)
    bob = AuthorMetrics(
        author_name="Bob Developer",
        author_email="bob@example.com",
        commit_count=75,
        lines_added=2500,
        lines_deleted=1000,
        first_commit_date=now - timedelta(days=800),
        last_commit_date=now - timedelta(days=500),
    )

    # Charlie: Old activity (inactive)
    charlie = AuthorMetrics(
        author_name="Charlie Contributor",
        author_email="charlie@example.com",
        commit_count=25,
        lines_added=500,
        lines_deleted=200,
        first_commit_date=now - timedelta(days=1500),
        last_commit_date=now - timedelta(days=1200),
    )

    # Create repository metrics
    repo_metrics = [
        RepositoryMetrics(
            repo_name="test-repo-1",
            gerrit_project="gerrit.example.org/active-project",
            authors=[alice, bob, charlie],
            total_commits=250,
            total_contributors=3,
            first_commit_date=now - timedelta(days=1500),
            last_commit_date=now - timedelta(days=30),
        )
    ]

    return repo_metrics


@pytest.fixture
def base_config():
    """Base configuration for tests."""
    return {
        "info_yaml": {
            "enabled": True,
            "cache_enabled": False,  # Disable for testing
            "enrich_with_git_data": True,
            "validate_urls": False,  # Skip URL validation in tests
            "activity_windows": {
                "current": 365,
                "active": 1095,
            },
        }
    }


class TestEndToEndBasicWorkflow:
    """Test basic end-to-end workflow."""

    def test_complete_workflow_without_enrichment(self, create_test_projects, base_config):
        """Test complete workflow without enrichment."""
        # Disable enrichment
        config = base_config.copy()
        config["info_yaml"]["enrich_with_git_data"] = False

        # Step 1: Collection
        collector = InfoYamlCollector(config)
        projects = collector.collect_projects(create_test_projects)

        assert len(projects) == 3
        assert all(isinstance(p, ProjectInfo) for p in projects)

        # Step 2: Rendering (without enrichment)
        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects)

        assert markdown
        assert "## 📋 Committer INFO.yaml Report" in markdown
        assert "### Lifecycle State Summary" in markdown
        assert "test-project" in markdown or "active-project" in markdown

    def test_complete_workflow_with_enrichment(
        self, create_test_projects, base_config, sample_git_metrics
    ):
        """Test complete workflow with Git data enrichment."""
        # Step 1: Collection
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        assert len(projects) == 3

        # Step 2: Enrichment
        enricher = InfoYamlEnricher(sample_git_metrics, base_config)
        enriched_projects = enricher.enrich_projects(projects)

        assert len(enriched_projects) == 3

        # Verify enrichment occurred
        active_project = next(
            (p for p in enriched_projects if "active" in p.project_name.lower()), None
        )
        assert active_project is not None
        assert active_project.has_git_data

        # Check committer activity colors
        committers_with_colors = [
            c for c in active_project.committers if c.activity_color != "gray"
        ]
        assert len(committers_with_colors) > 0

        # Step 3: Rendering
        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(enriched_projects)

        assert markdown
        assert "color: green" in markdown or "color: orange" in markdown

    def test_workflow_with_server_grouping(self, create_test_projects, base_config):
        """Test workflow with Gerrit server grouping."""
        # Collection
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        # Rendering with grouping
        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects, group_by_server=True)

        assert markdown
        assert "### gerrit.example.org" in markdown
        assert "### gerrit.other.org" in markdown


class TestEndToEndDataFlow:
    """Test data flow and transformations."""

    def test_data_integrity_through_pipeline(
        self, create_test_projects, base_config, sample_git_metrics
    ):
        """Verify data integrity through entire pipeline."""
        # Collection
        collector = InfoYamlCollector(base_config)
        collected = collector.collect_projects(create_test_projects)

        # Store original data
        original_names = {p.project_name for p in collected}
        original_states = {p.lifecycle_state for p in collected}

        # Enrichment
        enricher = InfoYamlEnricher(sample_git_metrics, base_config)
        enriched = enricher.enrich_projects(collected)

        # Verify no data loss
        enriched_names = {p.project_name for p in enriched}
        enriched_states = {p.lifecycle_state for p in enriched}

        assert original_names == enriched_names
        assert original_states == enriched_states

        # Verify enrichment added data
        for project in enriched:
            if any(c.email in ["alice@example.com", "bob@example.com"] for c in project.committers):
                assert project.has_git_data

    def test_committer_activity_calculation(
        self, create_test_projects, base_config, sample_git_metrics
    ):
        """Test activity status calculation through pipeline."""
        # Full pipeline
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        enricher = InfoYamlEnricher(sample_git_metrics, base_config)
        enriched = enricher.enrich_projects(projects)

        # Find project with enriched data
        active_project = next((p for p in enriched if p.has_git_data), None)

        assert active_project is not None

        # Check activity colors
        committers = active_project.committers

        # Should have at least one of each color (based on sample data)
        colors = {c.activity_color for c in committers}
        assert "green" in colors or "orange" in colors  # Alice or Bob
        assert "red" in colors or "gray" in colors  # Charlie or unknown


class TestEndToEndErrorHandling:
    """Test error handling through the pipeline."""

    def test_invalid_yaml_handling(self, temp_info_master, base_config):
        """Test handling of invalid YAML files."""
        # Create invalid YAML
        project_dir = temp_info_master / "gerrit.example.org" / "bad-project"
        project_dir.mkdir(parents=True)
        (project_dir / "INFO.yaml").write_text("invalid: yaml: content:")

        # Enable error continuation
        config = base_config.copy()
        config["info_yaml"]["continue_on_error"] = True
        config["info_yaml"]["skip_invalid_projects"] = True

        collector = InfoYamlCollector(config)
        projects = collector.collect_projects(temp_info_master)

        # Should not crash, may return empty list
        assert isinstance(projects, list)

    def test_missing_required_fields(self, temp_info_master, base_config):
        """Test handling of INFO.yaml with missing fields."""
        # Create minimal YAML (missing some fields)
        minimal_yaml = """---
project: 'minimal-project'
"""
        project_dir = temp_info_master / "gerrit.example.org" / "minimal-project"
        project_dir.mkdir(parents=True)
        (project_dir / "INFO.yaml").write_text(minimal_yaml)

        config = base_config.copy()
        config["info_yaml"]["skip_invalid_projects"] = True

        collector = InfoYamlCollector(config)
        projects = collector.collect_projects(temp_info_master)

        # Should handle gracefully
        assert isinstance(projects, list)

    def test_enrichment_with_no_git_data(self, create_test_projects, base_config):
        """Test enrichment when no Git data is available."""
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        # Enrich with empty Git metrics
        enricher = InfoYamlEnricher([], base_config)
        enriched = enricher.enrich_projects(projects)

        # Should complete without errors
        assert len(enriched) == len(projects)

        # All committers should be gray (no Git data)
        for project in enriched:
            for committer in project.committers:
                assert committer.activity_color == "gray"


class TestEndToEndPerformance:
    """Test performance characteristics."""

    def test_small_dataset_performance(self, create_test_projects, base_config, sample_git_metrics):
        """Test performance with small dataset (3 projects)."""
        import time

        collector = InfoYamlCollector(base_config)

        start = time.time()
        projects = collector.collect_projects(create_test_projects)
        collection_time = time.time() - start

        enricher = InfoYamlEnricher(sample_git_metrics, base_config)
        start = time.time()
        enriched = enricher.enrich_projects(projects)
        enrichment_time = time.time() - start

        renderer = InfoYamlRenderer()
        start = time.time()
        markdown = renderer.render_full_report_markdown(enriched)
        rendering_time = time.time() - start

        # Verify reasonable performance
        assert collection_time < 5.0  # Should be very fast
        assert enrichment_time < 5.0
        assert rendering_time < 5.0

        # Verify output
        assert len(projects) == 3
        assert len(enriched) == 3
        assert len(markdown) > 0

    def test_repeated_processing(self, create_test_projects, base_config, sample_git_metrics):
        """Test repeated processing of same data."""
        collector = InfoYamlCollector(base_config)
        enricher = InfoYamlEnricher(sample_git_metrics, base_config)
        renderer = InfoYamlRenderer()

        results = []
        for _ in range(3):
            projects = collector.collect_projects(create_test_projects)
            enriched = enricher.enrich_projects(projects)
            markdown = renderer.render_full_report_markdown(enriched)
            results.append((projects, enriched, markdown))

        # Verify consistent results
        assert all(len(r[0]) == 3 for r in results)
        assert all(len(r[1]) == 3 for r in results)
        assert all(len(r[2]) > 0 for r in results)


class TestEndToEndOutputFormats:
    """Test different output formats."""

    def test_markdown_output(self, create_test_projects, base_config):
        """Test Markdown output generation."""
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects)

        # Verify Markdown structure
        assert "##" in markdown  # Headers
        assert "|" in markdown  # Tables
        assert "**" in markdown  # Bold text

    def test_json_context_output(self, create_test_projects, base_config):
        """Test JSON context building."""
        import json

        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        renderer = InfoYamlRenderer()
        context = renderer.build_template_context(projects)

        # Verify JSON serializable
        json_str = json.dumps(context)
        assert json_str

        # Verify structure
        assert "projects" in context
        assert "total_projects" in context
        assert "lifecycle_summaries" in context

    def test_separate_sections(self, create_test_projects, base_config):
        """Test rendering sections separately."""
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        renderer = InfoYamlRenderer()

        # Render sections separately
        committer_report = renderer.render_committer_report_markdown(projects)
        lifecycle_summary = renderer.render_lifecycle_summary_markdown(projects)

        # Verify both sections
        assert "Committer INFO.yaml Report" in committer_report
        assert "Lifecycle State Summary" in lifecycle_summary

        # Verify they're different
        assert committer_report != lifecycle_summary


class TestEndToEndEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_empty_info_master(self, temp_info_master, base_config):
        """Test with empty info-master directory."""
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(temp_info_master)

        assert projects == []

        # Rendering should handle empty list
        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects)
        assert markdown == ""

    def test_single_project(self, temp_info_master, sample_info_yaml_content, base_config):
        """Test with single project."""
        project_dir = temp_info_master / "gerrit.example.org" / "single-project"
        project_dir.mkdir(parents=True)
        (project_dir / "INFO.yaml").write_text(sample_info_yaml_content)

        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(temp_info_master)

        assert len(projects) == 1

        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects)

        assert "**Total Projects:** 1" in markdown

    def test_projects_with_no_committers(self, temp_info_master, base_config):
        """Test projects with no committers."""
        yaml_content = """---
project: 'no-committers-project'
project_creation_date: '2020-01-15'
lifecycle_state: 'Active'
project_lead:
    name: 'Lead Only'
    email: 'lead@example.com'
committers: []
"""
        project_dir = temp_info_master / "gerrit.example.org" / "no-committers"
        project_dir.mkdir(parents=True)
        (project_dir / "INFO.yaml").write_text(yaml_content)

        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(temp_info_master)

        assert len(projects) == 1
        assert len(projects[0].committers) == 0

        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects)

        # Should render without errors
        assert markdown
        assert "None" in markdown  # No committers


class TestEndToEndRealWorldScenarios:
    """Test real-world usage scenarios."""

    def test_filtered_by_lifecycle_state(self, create_test_projects, base_config):
        """Test filtering by lifecycle state."""
        collector = InfoYamlCollector(base_config)
        all_projects = collector.collect_projects(create_test_projects)

        # Filter to only active projects
        active_projects = [p for p in all_projects if p.lifecycle_state == "Active"]

        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(active_projects)

        assert markdown
        assert "Archived" not in markdown  # Should not include archived

    def test_multi_server_grouping(self, create_test_projects, base_config):
        """Test grouping across multiple Gerrit servers."""
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        # Group by server
        servers = {}
        for project in projects:
            if project.gerrit_server not in servers:
                servers[project.gerrit_server] = []
            servers[project.gerrit_server].append(project)

        assert len(servers) == 2  # Two different servers
        assert "gerrit.example.org" in servers
        assert "gerrit.other.org" in servers

        # Render with grouping
        renderer = InfoYamlRenderer()
        markdown = renderer.render_full_report_markdown(projects, group_by_server=True)

        # Verify both servers in output
        assert "gerrit.example.org" in markdown
        assert "gerrit.other.org" in markdown

    def test_activity_status_distribution(
        self, create_test_projects, base_config, sample_git_metrics
    ):
        """Test distribution of activity statuses."""
        collector = InfoYamlCollector(base_config)
        projects = collector.collect_projects(create_test_projects)

        enricher = InfoYamlEnricher(sample_git_metrics, base_config)
        enriched = enricher.enrich_projects(projects)

        # Count activity statuses
        status_counts = {
            "current": 0,
            "active": 0,
            "inactive": 0,
            "unknown": 0,
        }

        for project in enriched:
            for committer in project.committers:
                status_counts[committer.activity_status] += 1

        # Should have a distribution
        total_committers = sum(status_counts.values())
        assert total_committers > 0

        # At least some should have activity data
        active_count = status_counts["current"] + status_counts["active"]
        assert active_count > 0 or status_counts["unknown"] > 0
