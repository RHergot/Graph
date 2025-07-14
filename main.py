#!/usr/bin/env python3
"""
Module de Reporting BI - Suite Logicielle
Point d'entrée principal de l'application

Auteur: Assistant IA
Date: 2025-01-14
"""

import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt, QTranslator, QLocale

# Configuration du chemin d'import pour accéder au module app
sys.path.insert(0, 'app')

from app.config.logging import setup_logging
from app.models.database_manager import DatabaseManager
from app.models.analysis_engine import AnalysisEngine
from app.views.main_window import MainWindow
from app.controllers.main_controller import MainController

def main():
    """Point d'entrée principal de l'application"""
    
    # Configuration logging
    logger = setup_logging()
    logger.info("🚀 Starting BI Reporting Module")
    
    # Création application Qt
    app = QApplication(sys.argv)
    app.setApplicationName("BI Reporting Module")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("Software Suite")
    
    # Configuration du système de traduction
    translator = QTranslator()
    # Pour l'instant, langue par défaut anglais (pas de fichier de traduction chargé)
    # Plus tard on pourra charger : translator.load("translations/app_fr.qm")
    app.installTranslator(translator)
    
    try:
        # Initialisation couche modèle
        logger.info("📊 Initializing database...")
        db_manager = DatabaseManager()
        analysis_engine = AnalysisEngine(db_manager)
        
        # Initialisation interface
        logger.info("🎨 Creating user interface...")
        main_window = MainWindow()
        
        # Initialisation contrôleur
        logger.info("🎮 Configuring controller...")
        controller = MainController(analysis_engine, main_window)
        
        # Affichage interface
        main_window.show()
        logger.info("✅ Application ready")
        
        # Boucle événements Qt
        return app.exec()
        
    except Exception as e:
        logger.error(f"❌ Critical startup error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    sys.exit(main())
