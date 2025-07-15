"""
Contrôleur principal - Orchestration MVC et gestion des événements
"""

import logging
from typing import Dict, Optional

from models.analysis_engine import AnalysisEngine
from PySide6.QtCore import QObject
from utils.worker import AnalysisWorker, ViewDiscoveryWorker, ViewInfoWorker
from views.main_window import MainWindow

logger = logging.getLogger(__name__)


class MainController(QObject):
    """Contrôleur principal de l'application MVC"""

    def __init__(
        self,
        analysis_engine: AnalysisEngine,
        main_window: MainWindow,
    ):
        """
        Initialisation du contrôleur

        Args:
            analysis_engine: Moteur d'analyse (Modèle)
            main_window: Interface principale (Vue)
        """
        super().__init__()
        self.analysis_engine = analysis_engine
        self.main_window = main_window

        # Workers actifs
        self.current_analysis_worker: Optional[AnalysisWorker] = None
        self.current_discovery_worker: Optional[ViewDiscoveryWorker] = None
        self.current_info_worker: Optional[ViewInfoWorker] = None

        # État de l'application
        self.is_connected = False
        self.available_views = []

        # Configuration
        self.setup_connections()
        self.initialize_application()

        logger.info("🎮 Main controller initialized")

    def setup_connections(self):
        """Configuration des connexions signaux/slots"""

        # Signaux de la vue vers le contrôleur
        self.main_window.generate_clicked.connect(self.on_generate_analysis)
        self.main_window.report_selected.connect(self.on_report_selected)
        self.main_window.filters_changed.connect(self.on_filters_changed)
        self.main_window.view_structure_requested.connect(
            self.on_view_structure_requested
        )
        self.main_window.view_management_requested.connect(
            self.on_view_management_requested
        )

        logger.info("🔗 Signal/slot connections configured")

    def initialize_application(self):
        """Initialisation de l'application au démarrage"""
        # Test de connexion et chargement des VIEWs
        self.refresh_views()

        # Mise à jour du statut de connexion
        try:
            connection_info = (
                self.analysis_engine.db_manager.get_connection_info()
            )
            self.main_window.update_connection_status(True, connection_info)
            self.is_connected = True
        except Exception as e:
            logger.error(f"❌ Erreur connexion: {e}")
            self.main_window.update_connection_status(False)
            self.main_window.show_error(
                f"Erreur de connexion à la base de données: {e}"
            )

    # === GESTION DES ÉVÉNEMENTS DE LA VUE ===

    def on_generate_analysis(self, params: Dict):
        """
        Gestion de la demande de génération d'analyse

        Args:
            params: Paramètres de l'analyse (view_name, filtres, etc.)
        """
        try:
            view_name = params.get("view_name", "")

            # Extraction du nom réel de la VIEW
            # (suppression info additionnelle)
            if " (" in view_name:
                view_name = view_name.split(" (")[0]

            if (
                not view_name or view_name == "Aucun rapport disponible"
            ):
                self.main_window.show_warning(
                    "Veuillez sélectionner un rapport valide"
                )
                return

            logger.info(f"🚀 Lancement analyse pour {view_name}")

            # Annulation de l'analyse précédente si active
            if (
                self.current_analysis_worker
                and self.current_analysis_worker.isRunning()
            ):
                self.current_analysis_worker.cancel()
                # Attente max 1 seconde
                self.current_analysis_worker.wait(1000)

            # Affichage du chargement
            self.main_window.show_loading(f"Analyse de {view_name}...")

            # Préparation des paramètres
            analysis_params = params.copy()
            analysis_params["view_name"] = view_name

            # Création et lancement du worker
            self.current_analysis_worker = AnalysisWorker(
                self.analysis_engine, analysis_params
            )

            # Connexion des signaux du worker
            self.current_analysis_worker.finished.connect(
                self.on_analysis_finished
            )
            self.current_analysis_worker.error.connect(self.on_analysis_error)
            self.current_analysis_worker.progress.connect(
                self.on_analysis_progress
            )

            # Démarrage
            self.current_analysis_worker.start()

        except Exception as e:
            logger.error(f"❌ Erreur lancement analyse: {e}")
            self.main_window.hide_loading()
            self.main_window.show_error(
                f"Erreur lors du lancement de l'analyse: {e}"
            )

    def on_report_selected(self, report_name: str):
        """
        Gestion de la sélection d'un rapport

        Args:
            report_name: Nom du rapport sélectionné
        """
        if not report_name or report_name == "Aucun rapport disponible":
            return

        # Extraction du nom réel
        view_name = (
            report_name.split(" (")[0] if " (" in report_name else report_name
        )

        logger.info(f"📋 Report selected: {view_name}")

        # Récupération des informations de la VIEW en arrière-plan
        if self.current_info_worker and self.current_info_worker.isRunning():
            self.current_info_worker.terminate()

        self.current_info_worker = ViewInfoWorker(
            self.analysis_engine, view_name
        )
        self.current_info_worker.finished.connect(
            self.on_view_info_received
        )
        self.current_info_worker.error.connect(self.on_view_info_error)
        self.current_info_worker.start()

    def on_filters_changed(self, filters: Dict):
        """
        Gestion du changement des filtres

        Args:
            filters: Nouveaux filtres appliqués
        """
        # Pour l'instant, simple logging
        # Peut être étendu pour un rafraîchissement automatique
        logger.debug(f"🔍 Filters modified: {filters}")

    def on_view_structure_requested(self, request: str):
        """
        Gestion des demandes de structure de VIEW

        Args:
            request: Type de demande ('refresh' pour actualiser)
        """
        if request == "refresh":
            logger.info("♻️ VIEWs refresh requested")
            self.refresh_views()

    # === GESTION DES RÉPONSES DES WORKERS ===

    def on_analysis_finished(self, dataframe):
        """
        Gestion de la fin d'analyse

        Args:
            dataframe: Résultats de l'analyse
        """
        try:
            logger.info(f"✅ Analysis completed: {len(dataframe)} rows")

            # Masquage du chargement
            self.main_window.hide_loading()

            # Affichage des résultats
            self.main_window.display_data(dataframe)

            # Nettoyage
            if self.current_analysis_worker:
                self.current_analysis_worker.deleteLater()
                self.current_analysis_worker = None

        except Exception as e:
            logger.error(f"❌ Error processing results: {e}")
            self.main_window.show_error(
                f"Erreur lors de l'affichage des résultats: {e}"
            )

    def on_analysis_error(self, error_message: str):
        """
        Gestion des erreurs d'analyse

        Args:
            error_message: Message d'erreur
        """
        logger.error(f"❌ Erreur analyse: {error_message}")

        self.main_window.hide_loading()
        self.main_window.show_error(f"Erreur d'analyse: {error_message}")

        # Nettoyage
        if self.current_analysis_worker:
            self.current_analysis_worker.deleteLater()
            self.current_analysis_worker = None

    def on_analysis_progress(self, message: str):
        """
        Gestion des messages de progression

        Args:
            message: Message de progression
        """
        # Mise à jour du statut
        if hasattr(self.main_window, "lbl_status"):
            self.main_window.lbl_status.setText(message)

    def on_views_discovered(self, views_list: list):
        """
        Gestion de la découverte des VIEWs

        Args:
            views_list: Liste des VIEWs découvertes
        """
        try:
            logger.info(f"📊 {len(views_list)} VIEWs discovered")

            self.available_views = views_list
            self.main_window.populate_views(views_list)

            # Masquage du chargement
            self.main_window.hide_loading()

            # Nettoyage
            if self.current_discovery_worker:
                self.current_discovery_worker.deleteLater()
                self.current_discovery_worker = None

        except Exception as e:
            logger.error(f"❌ Erreur traitement VIEWs: {e}")
            self.main_window.show_error(
                f"Erreur lors du chargement des rapports: {e}"
            )

    def on_views_discovery_error(self, error_message: str):
        """
        Gestion des erreurs de découverte

        Args:
            error_message: Message d'erreur
        """
        logger.error(f"❌ Error discovering VIEWs: {error_message}")

        self.main_window.hide_loading()
        self.main_window.show_error(
            f"Erreur lors de la découverte des rapports: {error_message}"
        )

        # Nettoyage
        if self.current_discovery_worker:
            self.current_discovery_worker.deleteLater()
            self.current_discovery_worker = None

    def on_view_info_received(self, view_name: str, info: dict):
        """
        Gestion de la réception d'informations de VIEW

        Args:
            view_name: Nom de la VIEW
            info: Informations détaillées
        """
        logger.info(f"ℹ️ Information received for {view_name}")
        self.main_window.update_view_info(view_name, info)

        # Nettoyage
        if self.current_info_worker:
            self.current_info_worker.deleteLater()
            self.current_info_worker = None

    def on_view_info_error(self, view_name: str, error_message: str):
        """
        Gestion des erreurs d'information de VIEW

        Args:
            view_name: Nom de la VIEW
            error_message: Message d'erreur
        """
        logger.warning(f"⚠️ Erreur info VIEW {view_name}: {error_message}")
        self.main_window.update_view_info(view_name, {"error": error_message})

        # Nettoyage
        if self.current_info_worker:
            self.current_info_worker.deleteLater()
            self.current_info_worker = None

    # === MÉTHODES UTILITAIRES ===

    def refresh_views(self):
        """Actualisation de la liste des VIEWs disponibles"""
        try:
            # Annulation de la découverte précédente si active
            if (
                self.current_discovery_worker
                and self.current_discovery_worker.isRunning()
            ):
                self.current_discovery_worker.terminate()

            # Affichage du chargement
            self.main_window.show_loading("Découverte des rapports...")

            # Création et lancement du worker de découverte
            self.current_discovery_worker = ViewDiscoveryWorker(
                self.analysis_engine.db_manager
            )

            # Connexion des signaux
            self.current_discovery_worker.finished.connect(
                self.on_views_discovered
            )
            self.current_discovery_worker.error.connect(
                self.on_views_discovery_error
            )

            # Démarrage
            self.current_discovery_worker.start()

        except Exception as e:
            logger.error(f"❌ Erreur actualisation VIEWs: {e}")
            self.main_window.hide_loading()
            self.main_window.show_error(f"Erreur lors de l'actualisation: {e}")

    def on_view_management_requested(self):
        """Gestion de la demande d'ouverture du gestionnaire de VIEWs"""
        try:
            from views.view_manager_dialog import ViewManagerDialog

            dialog = ViewManagerDialog(
                self.analysis_engine.db_manager, self.main_window
            )

            dialog.view_created.connect(self.on_view_created)
            dialog.view_deleted.connect(self.on_view_deleted)

            dialog.exec()

        except Exception as e:
            logger.error(f"❌ Erreur ouverture gestionnaire VIEWs: {e}")
            self.main_window.show_error(
                f"Impossible d'ouvrir le gestionnaire de VIEWs: {e}"
            )

    def on_view_created(self, view_name: str):
        """Gestion de la création d'une nouvelle VIEW"""
        logger.info(f"✅ Nouvelle VIEW créée: {view_name}")
        self.refresh_views()

    def on_view_deleted(self, view_name: str):
        """Gestion de la suppression d'une VIEW"""
        logger.info(f"🗑️ VIEW supprimée: {view_name}")
        self.refresh_views()

    def cleanup(self):
        """Nettoyage avant fermeture de l'application"""
        logger.info("🧹 Controller cleanup")

        # Arrêt des workers actifs
        workers = [
            self.current_analysis_worker,
            self.current_discovery_worker,
            self.current_info_worker,
        ]

        for worker in workers:
            if worker and worker.isRunning():
                if hasattr(worker, "cancel"):
                    worker.cancel()
                worker.terminate()
                worker.wait(1000)  # Attente max 1 seconde

        logger.info("✅ Cleanup completed")

    def get_application_state(self) -> Dict:
        """Retourne l'état actuel de l'application"""
        return {
            "connected": self.is_connected,
            "views_count": len(self.available_views),
            "current_view": self.main_window.combo_views.currentText(),
            "has_data": not self.main_window.current_data.empty,
        }
