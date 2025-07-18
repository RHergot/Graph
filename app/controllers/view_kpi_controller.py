"""
Contrôleur pour la gestion des VIEWs KPI
Interface entre l'interface utilisateur et le système de gestion des VIEWs
"""

import logging
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
from PySide6.QtCore import QObject, Signal, QThread, QTimer
from PySide6.QtWidgets import QMessageBox, QProgressDialog, QApplication

from app.models.view_manager import ViewManager
from app.models.database_manager import DatabaseManager
from view_builder import ViewBuilder, ViewDefinition, ModuleType
from app.utils.view_exceptions import *

logger = logging.getLogger(__name__)

class ViewCreationWorker(QThread):
    """Worker thread pour la création de VIEWs en arrière-plan"""
    
    # Signaux
    progress_updated = Signal(int)  # Pourcentage de progression
    view_created = Signal(str)  # Nom de la VIEW créée
    error_occurred = Signal(str)  # Message d'erreur
    creation_completed = Signal(dict)  # Résultats finaux
    
    def __init__(self, view_manager: ViewManager, views_to_create: List[ViewDefinition]):
        super().__init__()
        self.view_manager = view_manager
        self.views_to_create = views_to_create
        self.results = {'success': [], 'errors': []}
    
    def run(self):
        """Processus de création des VIEWs"""
        try:
            total_views = len(self.views_to_create)
            
            for i, view_def in enumerate(self.views_to_create):
                try:
                    # Mise à jour de la progression
                    progress = int((i / total_views) * 100)
                    self.progress_updated.emit(progress)
                    
                    # Création de la VIEW
                    success = self.view_manager.create_view(view_def, force_recreate=True)
                    
                    if success:
                        view_name = f"{view_def.module.value}_{view_def.name}"
                        self.results['success'].append(view_name)
                        self.view_created.emit(view_name)
                        logger.info(f"VIEW {view_name} créée avec succès")
                    
                except Exception as e:
                    error_msg = f"Erreur lors de la création de {view_def.name}: {str(e)}"
                    self.results['errors'].append(error_msg)
                    self.error_occurred.emit(error_msg)
                    logger.error(error_msg)
            
            # Progression finale
            self.progress_updated.emit(100)
            
            # Émission des résultats finaux
            self.creation_completed.emit(self.results)
            
        except Exception as e:
            error_msg = f"Erreur critique dans le processus de création: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)

class ViewKpiController(QObject):
    """
    Contrôleur principal pour la gestion des VIEWs KPI
    Orchestration des opérations et interface avec l'UI
    """
    
    # Signaux pour communication avec l'UI
    views_refreshed = Signal(list)  # Liste des VIEWs disponibles
    view_data_loaded = Signal(str, list)  # Nom de VIEW et données
    view_schema_loaded = Signal(str, dict)  # Nom de VIEW et schéma
    operation_completed = Signal(str, bool, str)  # Opération, succès, message
    error_occurred = Signal(str)  # Message d'erreur
    
    def __init__(self, db_manager: DatabaseManager):
        super().__init__()
        self.db_manager = db_manager
        self.view_manager = ViewManager(db_manager)
        self.view_builder = ViewBuilder()
        
        # Cache pour optimiser les performances
        self._views_cache = {}
        self._schema_cache = {}
        
        # Timer pour rafraîchissement automatique
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self.refresh_views_list)
        
        logger.info("ViewKpiController initialisé")
    
    def start_auto_refresh(self, interval_minutes: int = 5):
        """Démarre le rafraîchissement automatique des VIEWs"""
        self.refresh_timer.start(interval_minutes * 60 * 1000)  # Conversion en millisecondes
        logger.info(f"Rafraîchissement automatique démarré ({interval_minutes} min)")
    
    def stop_auto_refresh(self):
        """Arrête le rafraîchissement automatique"""
        self.refresh_timer.stop()
        logger.info("Rafraîchissement automatique arrêté")
    
    def refresh_views_list(self, module_filter: Optional[ModuleType] = None):
        """
        Rafraîchit la liste des VIEWs KPI disponibles
        
        Args:
            module_filter: Filtre par module (optionnel)
        """
        try:
            views_list = self.view_manager.list_kpi_views(module_filter)
            self._views_cache = {view['name']: view for view in views_list}
            self.views_refreshed.emit(views_list)
            logger.info(f"Liste des VIEWs rafraîchie: {len(views_list)} VIEWs trouvées")
            
        except Exception as e:
            error_msg = f"Erreur lors du rafraîchissement des VIEWs: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def load_view_data(self, view_name: str, limit: Optional[int] = 1000, 
                      filters: Optional[Dict[str, Any]] = None):
        """
        Charge les données d'une VIEW
        
        Args:
            view_name: Nom de la VIEW
            limit: Nombre maximum de lignes
            filters: Filtres à appliquer
        """
        try:
            data = self.view_manager.get_view_data(view_name, limit, filters)
            self.view_data_loaded.emit(view_name, data)
            logger.info(f"Données chargées pour {view_name}: {len(data)} lignes")
            
        except Exception as e:
            error_msg = f"Erreur lors du chargement des données de {view_name}: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def load_view_schema(self, view_name: str):
        """
        Charge le schéma d'une VIEW
        
        Args:
            view_name: Nom de la VIEW
        """
        try:
            # Vérification du cache
            if view_name in self._schema_cache:
                schema = self._schema_cache[view_name]
            else:
                schema = self.view_manager.get_view_schema(view_name)
                self._schema_cache[view_name] = schema
            
            self.view_schema_loaded.emit(view_name, schema)
            logger.info(f"Schéma chargé pour {view_name}: {len(schema['columns'])} colonnes")
            
        except Exception as e:
            error_msg = f"Erreur lors du chargement du schéma de {view_name}: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def create_views_from_templates(self, module: ModuleType, 
                                  view_names: Optional[List[str]] = None,
                                  show_progress: bool = True):
        """
        Crée des VIEWs à partir des templates
        
        Args:
            module: Module pour lequel créer les VIEWs
            view_names: Noms spécifiques des VIEWs (toutes si None)
            show_progress: Affichage de la progression
        """
        try:
            # Récupération des templates
            templates = self.view_builder.get_available_templates(module)
            
            if not templates:
                self.error_occurred.emit(f"Aucun template disponible pour le module {module.value}")
                return
            
            # Filtrage des templates si spécifié
            if view_names:
                templates = {name: template for name, template in templates.items() 
                           if name in view_names}
            
            views_to_create = list(templates.values())
            
            if show_progress:
                # Création avec interface de progression
                self._create_views_with_progress(views_to_create)
            else:
                # Création directe
                self._create_views_direct(views_to_create)
                
        except Exception as e:
            error_msg = f"Erreur lors de la création des VIEWs pour {module.value}: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def _create_views_with_progress(self, views_to_create: List[ViewDefinition]):
        """Crée les VIEWs avec une barre de progression"""
        try:
            # Création de la boîte de dialogue de progression
            self.progress_dialog = QProgressDialog(
                "Création des VIEWs KPI en cours...", 
                "Annuler", 
                0, 100
            )
            self.progress_dialog.setWindowTitle("Création de VIEWs")
            self.progress_dialog.setModal(True)
            self.progress_dialog.show()
            
            # Création du worker thread
            self.creation_worker = ViewCreationWorker(self.view_manager, views_to_create)
            
            # Connexion des signaux
            self.creation_worker.progress_updated.connect(self.progress_dialog.setValue)
            self.creation_worker.view_created.connect(self._on_view_created)
            self.creation_worker.error_occurred.connect(self._on_creation_error)
            self.creation_worker.creation_completed.connect(self._on_creation_completed)
            self.progress_dialog.canceled.connect(self.creation_worker.terminate)
            
            # Démarrage du processus
            self.creation_worker.start()
            
        except Exception as e:
            error_msg = f"Erreur lors de l'initialisation de la création: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def _create_views_direct(self, views_to_create: List[ViewDefinition]):
        """Crée les VIEWs directement sans progression"""
        success_count = 0
        error_count = 0
        
        for view_def in views_to_create:
            try:
                success = self.view_manager.create_view(view_def, force_recreate=True)
                if success:
                    success_count += 1
                    logger.info(f"VIEW {view_def.name} créée")
                else:
                    error_count += 1
                    
            except Exception as e:
                error_count += 1
                logger.error(f"Erreur création {view_def.name}: {e}")
        
        # Rapport final
        message = f"Création terminée: {success_count} succès, {error_count} erreurs"
        self.operation_completed.emit("create_views", error_count == 0, message)
    
    def _on_view_created(self, view_name: str):
        """Callback quand une VIEW est créée avec succès"""
        # Mise à jour du cache
        self._views_cache.pop(view_name, None)
        self._schema_cache.pop(view_name, None)
    
    def _on_creation_error(self, error_message: str):
        """Callback quand une erreur survient lors de la création"""
        logger.error(f"Erreur de création: {error_message}")
    
    def _on_creation_completed(self, results: Dict[str, List]):
        """Callback quand la création est terminée"""
        try:
            # Fermeture de la boîte de dialogue
            if hasattr(self, 'progress_dialog'):
                self.progress_dialog.close()
            
            # Nettoyage du worker
            if hasattr(self, 'creation_worker'):
                self.creation_worker.quit()
                self.creation_worker.wait()
            
            # Rapport des résultats
            success_count = len(results['success'])
            error_count = len(results['errors'])
            
            message = f"Création terminée: {success_count} VIEWs créées, {error_count} erreurs"
            
            if error_count > 0:
                error_details = "\n".join(results['errors'][:5])  # Max 5 erreurs affichées
                if len(results['errors']) > 5:
                    error_details += f"\n... et {len(results['errors']) - 5} autres erreurs"
                message += f"\n\nDétails des erreurs:\n{error_details}"
            
            self.operation_completed.emit("create_views", error_count == 0, message)
            
            # Rafraîchissement de la liste des VIEWs
            self.refresh_views_list()
            
        except Exception as e:
            error_msg = f"Erreur lors de la finalisation: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def delete_view(self, view_name: str, confirm: bool = True):
        """
        Supprime une VIEW
        
        Args:
            view_name: Nom de la VIEW à supprimer
            confirm: Demander confirmation
        """
        try:
            if confirm:
                reply = QMessageBox.question(
                    None,
                    "Confirmation de suppression",
                    f"Êtes-vous sûr de vouloir supprimer la VIEW '{view_name}' ?\n\n"
                    "Cette action est irréversible.",
                    QMessageBox.Yes | QMessageBox.No,
                    QMessageBox.No
                )
                
                if reply != QMessageBox.Yes:
                    return
            
            # Suppression
            success = self.view_manager.delete_view(view_name)
            
            if success:
                # Nettoyage du cache
                self._views_cache.pop(view_name, None)
                self._schema_cache.pop(view_name, None)
                
                message = f"VIEW '{view_name}' supprimée avec succès"
                self.operation_completed.emit("delete_view", True, message)
                
                # Rafraîchissement de la liste
                self.refresh_views_list()
            else:
                self.operation_completed.emit("delete_view", False, f"Échec de la suppression de '{view_name}'")
                
        except Exception as e:
            error_msg = f"Erreur lors de la suppression de {view_name}: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def refresh_view(self, view_name: str):
        """
        Rafraîchit une VIEW matérialisée
        
        Args:
            view_name: Nom de la VIEW à rafraîchir
        """
        try:
            success = self.view_manager.refresh_view(view_name)
            
            if success:
                message = f"VIEW '{view_name}' rafraîchie avec succès"
                self.operation_completed.emit("refresh_view", True, message)
            else:
                self.operation_completed.emit("refresh_view", False, f"Échec du rafraîchissement de '{view_name}'")
                
        except Exception as e:
            error_msg = f"Erreur lors du rafraîchissement de {view_name}: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
    
    def get_available_modules(self) -> List[ModuleType]:
        """Retourne la liste des modules disponibles"""
        return list(ModuleType)
    
    def get_module_templates(self, module: ModuleType) -> Dict[str, str]:
        """
        Retourne les templates disponibles pour un module
        
        Returns:
            Dict: {template_name: description}
        """
        templates = self.view_builder.get_available_templates(module)
        return {name: template.description for name, template in templates.items()}
    
    def export_view_definitions(self) -> Dict[str, Any]:
        """Exporte les définitions de toutes les VIEWs"""
        try:
            all_templates = self.view_builder.get_all_templates()
            export_data = {
                'export_date': datetime.now().isoformat(),
                'modules': {}
            }
            
            for module, templates in all_templates.items():
                export_data['modules'][module.value] = {
                    'templates': {
                        name: {
                            'description': template.description,
                            'base_tables': template.base_tables,
                            'columns': template.columns,
                            'joins': template.joins,
                            'filters': template.filters,
                            'group_by': template.group_by,
                            'order_by': template.order_by,
                            'comments': template.comments
                        }
                        for name, template in templates.items()
                    }
                }
            
            return export_data
            
        except Exception as e:
            error_msg = f"Erreur lors de l'export: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
            return {}
    
    def get_view_statistics(self) -> Dict[str, Any]:
        """Retourne des statistiques sur les VIEWs"""
        try:
            all_views = self.view_manager.list_kpi_views()
            
            stats = {
                'total_views': len(all_views),
                'by_module': {},
                'total_rows': 0,
                'last_refresh': datetime.now().isoformat()
            }
            
            for view in all_views:
                module = view.get('module', 'unknown')
                if module not in stats['by_module']:
                    stats['by_module'][module] = 0
                stats['by_module'][module] += 1
                stats['total_rows'] += view.get('row_count', 0)
            
            return stats
            
        except Exception as e:
            error_msg = f"Erreur lors du calcul des statistiques: {str(e)}"
            self.error_occurred.emit(error_msg)
            logger.error(error_msg)
            return {}
    
    def cleanup_cache(self):
        """Nettoie le cache"""
        self._views_cache.clear()
        self._schema_cache.clear()
        logger.info("Cache nettoyé")
