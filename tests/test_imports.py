"""
Tests for the BI Reporting Module
"""

import sys
from pathlib import Path

import pytest

# Add the app directory to the Python path
sys.path.insert(0, str(Path(__file__).parent.parent / "app"))


def test_imports():
    """Test that all main modules can be imported"""
    try:
        from app.config.logging import setup_logging
        from app.controllers.main_controller import MainController
        from app.models.analysis_engine import AnalysisEngine
        from app.models.database_manager import DatabaseManager
        from app.views.main_window import MainWindow

        assert True
    except ImportError as e:
        pytest.fail(f"Import failed: {e}")


def test_main_import():
    """Test that main module can be imported"""
    import main

    assert hasattr(main, "main")
    assert callable(main.main)
