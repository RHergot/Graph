#!/usr/bin/env python3
"""
Constructeur de vues avancées refactorisé - Version 3

Ce module utilise maintenant une architecture modulaire avec des mixins
pour une meilleure maintenabilité et séparation des responsabilités.

Architecture refactorisée :
- BaseViewConstructorDialog : Configuration de base
- UIComponentsMixin : Gestion des composants d'interface
- DataManagerMixin : Gestion des données des tables
- ValidationMixin : Validation des formulaires
- PreviewGeneratorMixin : Génération de prévisualisations SQL
- ReviewManagerMixin : Gestion des relectures

Auteur: Assistant IA
Version: 3.1 (Refactorisée)
"""

import logging
from .view_constructor.main_dialog import AdvancedViewCreatorDialog

logger = logging.getLogger(__name__)

# Export de la classe principale pour compatibilité
__all__ = ['AdvancedViewCreatorDialog']


def main():
    """Fonction principale pour tester le dialog de manière autonome"""
    import sys
    from PySide6.QtWidgets import QApplication
    
    app = QApplication(sys.argv)
    
    # Créer le dialog sans services (mode test)
    dialog = AdvancedViewCreatorDialog()
    dialog.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
