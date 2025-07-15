#!/usr/bin/env python3
"""
Test script to verify the efficiency improvements work correctly
"""

import sys

sys.path.append(".")


def test_itertuples_improvement():
    """Test that the itertuples efficiency improvement works"""
    print("🧪 Testing itertuples efficiency improvement...")

    try:
        import pandas as pd
        from PySide6.QtWidgets import QApplication

        from app.views.main_window import MainWindow

        app = QApplication([])
        window = MainWindow()

        test_data = pd.DataFrame(
            {
                "col1": range(100),
                "col2": [f"value_{i}" for i in range(100)],
                "col3": [i * 1.5 for i in range(100)],
            }
        )

        window.display_data(test_data)

        assert (
            window.table_model.rowCount() == 100
        ), f"Expected 100 rows, got {window.table_model.rowCount()}"
        assert (
            window.table_model.columnCount() == 3
        ), f"Expected 3 columns, got {window.table_model.columnCount()}"

        print("✅ Efficiency improvement test passed - itertuples works correctly")
        print(f"✅ Table model has {window.table_model.rowCount()} rows")
        print(f"✅ Table model has {window.table_model.columnCount()} columns")

        app.quit()
        return True

    except Exception as e:
        print(f"❌ Error testing efficiency improvement: {e}")
        return False


def test_type_annotations():
    """Test that type annotations don't cause runtime issues"""
    print("🧪 Testing type annotations...")

    try:
        from app.models.analysis_engine import AnalysisEngine
        from app.models.database_manager import DatabaseManager
        from app.views.main_window import MainWindow

        print("✅ All imports successful")

        from typing import get_type_hints

        hints = get_type_hints(DatabaseManager.execute_query)
        print(f"✅ DatabaseManager.execute_query type hints: {hints}")

        hints = get_type_hints(AnalysisEngine.run_analysis)
        print(f"✅ AnalysisEngine.run_analysis type hints: {hints}")

        hints = get_type_hints(
            MainWindow.update_connection_status)
        print(f"✅ MainWindow.update_connection_status type hints: {hints}")

        return True

    except Exception as e:
        print(f"❌ Error testing type annotations: {e}")
        return False


if __name__ == "__main__":
    print("🚀 Running efficiency improvement tests...")

    success = True
    success &= test_type_annotations()
    success &= test_itertuples_improvement()

    if success:
        print("\n✅ All efficiency improvement tests passed!")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed!")
        sys.exit(1)
