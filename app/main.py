#!/usr/bin/env python3
"""
Module de Reporting BI - Suite Logicielle
Point d'entrée principal de l'application

Auteur: Assistant IA
Date: 2025-01-13
"""

import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt

# Configuration du chemin d'import
sys.path.insert(0, '.')

from config.logging import setup_logging
from models.database_manager import DatabaseManager
from models.analysis_engine import AnalysisEngine
from views.main_window import MainWindow
from controllers.main_controller import MainController
from controllers.main_controller import MainController

def main():
    """Point d'entrée principal de l'application"""
    
    # Configuration logging
    logger = setup_logging()
    logger.info("🚀 Démarrage Module Reporting BI")
    
    # Création application Qt
    app = QApplication(sys.argv)
    app.setApplicationName("Reporting BI Module")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("Suite Logicielle")
    
    try:
        # Initialisation couche modèle
        logger.info("📊 Initialisation base de données...")
        db_manager = DatabaseManager()
        analysis_engine = AnalysisEngine(db_manager)
        
        # Initialisation interface
        logger.info("🎨 Création interface utilisateur...")
        main_window = MainWindow()
        
        # Initialisation contrôleur
        logger.info("🎮 Configuration contrôleur...")
        controller = MainController(analysis_engine, main_window)
        
        # Affichage interface
        main_window.show()
        logger.info("✅ Application prête")
        
        # Boucle événements Qt
        return app.exec()
        
    except Exception as e:
        logger.error(f"❌ Erreur critique au démarrage: {e}")
        sys.exit(1)

if __name__ == "__main__":
    sys.exit(main())
