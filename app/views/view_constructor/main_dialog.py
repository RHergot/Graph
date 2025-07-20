"""
Main Dialog refactorisé pour le constructeur de vues avancées
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime

from .base_dialog import BaseViewConstructorDialog
from .ui_components import UIComponentsMixin
from .data_manager import DataManagerMixin
from .validation import ValidationMixin
from .preview_generator import PreviewGeneratorMixin
from .review_manager import ReviewManagerMixin

# Imports conditionnels pour les services
try:
    from ...models.view_builder import ViewBuilder
    from ...models.view_crud_manager import ViewCrudManager
except ImportError:
    ViewBuilder = None
    ViewCrudManager = None

logger = logging.getLogger(__name__)


class AdvancedViewCreatorDialog(
    BaseViewConstructorDialog,
    UIComponentsMixin,
    DataManagerMixin,
    ValidationMixin,
    PreviewGeneratorMixin,
    ReviewManagerMixin
):
    """
    Constructeur de vues avancées refactorisé avec architecture modulaire
    
    Cette classe combine plusieurs mixins pour séparer les responsabilités :
    - BaseViewConstructorDialog : Classe de base avec configuration générale
    - UIComponentsMixin : Création et gestion des composants d'interface
    - DataManagerMixin : Gestion des données des tables et vues
    - ValidationMixin : Validation des formulaires et données
    - PreviewGeneratorMixin : Génération de prévisualisations SQL
    - ReviewManagerMixin : Gestion des relectures et commentaires
    """
    
    def __init__(self, parent=None, database_manager=None, analysis_engine=None):
        """
        Initialise le constructeur de vues avancées
        
        Args:
            parent: Widget parent
            database_manager: Gestionnaire de base de données
            analysis_engine: Moteur d'analyse
        """
        # Initialiser la classe de base
        super().__init__(parent, database_manager, analysis_engine)
        
        # Initialiser les services métier
        self._init_business_services()
        
        # Charger les données des tables
        self.tables_data = self.load_tables_data()
        
        # Ajouter des vues de test pour démonstration
        self.add_sample_views()
        
        # Configurer l'interface utilisateur
        self.setup_ui_components()
        
        # Remplir les combos avec les données
        self.populate_table_combos()
        
        # Connecter le bouton de prévisualisation
        self.preview_btn.clicked.connect(self._generate_preview)
        
        # Actualiser la liste des vues pour relecture
        self._refresh_views_list()
        
        logger.info("🚀 AdvancedViewCreatorDialog initialisé avec succès")
    
    def _init_business_services(self):
        """Initialise les services métier"""
        try:
            # Initialiser ViewBuilder si disponible
            if ViewBuilder and self.database_manager:
                self.view_builder = ViewBuilder(self.database_manager)
            else:
                self.view_builder = None
                logger.warning("⚠️ ViewBuilder non disponible, utilisation du fallback")
            
            # Initialiser ViewCrudManager si disponible
            if ViewCrudManager and self.database_manager:
                self.view_crud_manager = ViewCrudManager(self.database_manager)
            else:
                self.view_crud_manager = None
                logger.warning("⚠️ ViewCrudManager non disponible, utilisation du fallback")
        
        except Exception as e:
            logger.error(f"❌ Erreur initialisation services métier: {e}")
            self.view_builder = None
            self.view_crud_manager = None
    
    def _on_main_table_changed(self):
        """Gère le changement de table principale"""
        try:
            main_table = self.main_table_combo.currentData()
            
            if main_table is None:
                # Désactiver et vider les autres combos
                self._disable_dependent_combos()
                return
            
            # Activer les combos dépendants
            self.x_field_combo.setEnabled(True)
            self.y1_field_combo.setEnabled(True)
            self.y2_field_combo.setEnabled(True)
            self.y3_field_combo.setEnabled(True)
            self.grouping_combo.setEnabled(True)
            
            # Remplir les combos de champs
            self._populate_field_combos(main_table)
            
            # Activer les combos d'agrégation
            self.y1_agg_combo.setEnabled(True)
            self.y2_agg_combo.setEnabled(True)
            self.y3_agg_combo.setEnabled(True)
            
            # Revalider le formulaire
            self._validate_form()
            
        except Exception as e:
            logger.error(f"❌ Erreur changement table principale: {e}")
    
    def _on_secondary_table_changed(self):
        """Gère le changement de table secondaire (pour les jointures futures)"""
        try:
            secondary_table = self.secondary_table_combo.currentData()
            
            # Pour l'instant, cette fonctionnalité n'est pas implémentée
            # mais la structure est prête pour les jointures futures
            
            if secondary_table:
                logger.info(f"📊 Table secondaire sélectionnée: {secondary_table}")
            
        except Exception as e:
            logger.error(f"❌ Erreur changement table secondaire: {e}")
    
    def _disable_dependent_combos(self):
        """Désactive et vide les combos dépendants"""
        # Champs
        for combo_name in ['x_field_combo', 'y1_field_combo', 'y2_field_combo', 'y3_field_combo']:
            combo = getattr(self, combo_name)
            combo.clear()
            combo.addItem("-- Sélectionner d'abord une table --", None)
            combo.setEnabled(False)
        
        # Groupement
        self.grouping_combo.setEnabled(False)
        
        # Agrégations
        for combo_name in ['y1_agg_combo', 'y2_agg_combo', 'y3_agg_combo']:
            combo = getattr(self, combo_name)
            combo.setEnabled(False)
    
    def _populate_field_combos(self, table_name: str):
        """Remplit les combos de champs pour une table donnée"""
        try:
            if table_name not in self.tables_data:
                logger.warning(f"⚠️ Table {table_name} non trouvée dans les données")
                return
            
            fields = self.tables_data[table_name]["fields"]
            
            # Remplir le combo X (tous les champs)
            self.x_field_combo.clear()
            self.x_field_combo.addItem("-- Sélectionner un champ --", None)
            for field_name, field_info in fields.items():
                display_text = f"{field_info['display']} ({field_info['type']})"
                self.x_field_combo.addItem(display_text, field_name)
            
            # Remplir les combos Y (champs agrégables de préférence)
            for i, combo_name in enumerate(['y1_field_combo', 'y2_field_combo', 'y3_field_combo'], 1):
                combo = getattr(self, combo_name)
                combo.clear()
                
                if i == 1:
                    combo.addItem("-- Sélectionner un champ --", None)
                else:
                    combo.addItem("-- Optionnel --", None)
                
                # Ajouter d'abord les champs agrégables
                aggregable_fields = [(name, info) for name, info in fields.items() 
                                   if info.get('aggregable', False)]
                
                for field_name, field_info in aggregable_fields:
                    display_text = f"⭐ {field_info['display']} ({field_info['type']})"
                    combo.addItem(display_text, field_name)
                
                # Puis les autres champs
                other_fields = [(name, info) for name, info in fields.items() 
                              if not info.get('aggregable', False)]
                
                for field_name, field_info in other_fields:
                    display_text = f"{field_info['display']} ({field_info['type']})"
                    combo.addItem(display_text, field_name)
        
        except Exception as e:
            logger.error(f"❌ Erreur remplissage combos champs: {e}")
    
    def _save_view(self):
        """Sauvegarde la vue créée"""
        try:
            # Créer la définition de vue
            view_def = self._create_view_definition()
            if not view_def:
                self._show_error("Impossible de créer la définition de vue")
                return
            
            # Valider la définition
            is_valid, error_msg = self._validate_view_definition(view_def)
            if not is_valid:
                self._show_error(f"Définition de vue invalide: {error_msg}")
                return
            
            # Utiliser ViewBuilder et ViewCrudManager si disponibles
            if self.view_builder and self.view_crud_manager:
                success = self._save_view_with_services(view_def)
            else:
                success = self._save_view_fallback(view_def)
            
            if success:
                # Ajouter à la liste des vues créées
                view_record = {
                    'id': len(self.created_views) + 1,
                    'name': view_def['name'],
                    'created_date': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    'data': view_def,
                    'review_status': '📝 Brouillon',
                    'reviewer': '',
                    'review_comments': '',
                    'review_date': None
                }
                
                self.created_views.append(view_record)
                
                # Actualiser la liste des vues
                self._refresh_views_list()
                
                # Émettre le signal
                self.view_created.emit(view_def)
                
                self._show_info(f"Vue '{view_def['name']}' créée avec succès!")
                
                # Basculer vers l'onglet relecture
                self.tabs.setCurrentIndex(4)
        
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde vue: {e}")
            self._show_error(f"Erreur lors de la sauvegarde: {str(e)}")
    
    def _save_view_with_services(self, view_def: Dict[str, Any]) -> bool:
        """Sauvegarde avec ViewBuilder et ViewCrudManager"""
        try:
            # Générer le SQL avec ViewBuilder
            sql_query = self.view_builder.build_sql(view_def)
            view_def['sql'] = sql_query
            
            # Sauvegarder avec ViewCrudManager
            self.view_crud_manager.create_view(view_def)
            
            return True
        
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde avec services: {e}")
            return False
    
    def _save_view_fallback(self, view_def: Dict[str, Any]) -> bool:
        """Sauvegarde en mode fallback"""
        try:
            # Générer le SQL
            sql_query = self._generate_sql_from_definition(view_def)
            view_def['sql'] = sql_query
            
            # Exécuter la création de vue si connexion disponible
            if self.has_database_connection():
                self.database_manager.execute_query(sql_query)
            
            return True
        
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde fallback: {e}")
            return False


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
