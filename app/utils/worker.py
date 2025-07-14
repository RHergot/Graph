"""
Workers pour l'exécution des tâches en arrière-plan (QThread)
"""

from PySide6.QtCore import QThread, Signal, QObject
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

class AnalysisWorker(QThread):
    """Worker pour l'exécution d'analyses en arrière-plan"""
    
    # Signaux émis
    finished = Signal(object)  # DataFrame des résultats
    error = Signal(str)        # Message d'erreur
    progress = Signal(str)     # Message de progression
    
    def __init__(self, analysis_engine, params: Dict[str, Any]):
        """
        Initialisation du worker
        
        Args:
            analysis_engine: Instance de AnalysisEngine
            params: Paramètres de l'analyse (view_name, filters, etc.)
        """
        super().__init__()
        self.analysis_engine = analysis_engine
        self.params = params
        self.is_cancelled = False
    
    def run(self):
        """Exécution de l'analyse en arrière-plan"""
        try:
            view_name = self.params.get('view_name', '')
            logger.info(f"🔄 Starting analysis worker for {view_name}")
            
            # Vérification annulation
            if self.is_cancelled:
                return
            
            self.progress.emit(f"Préparation de l'analyse {view_name}...")
            
            # Préparation des filtres
            filters = self._prepare_filters()
            
            if self.is_cancelled:
                return
            
            self.progress.emit("Exécution de la requête...")
            
            # Exécution de l'analyse
            result = self.analysis_engine.run_analysis(
                view_name=view_name,
                filters=filters,
                limit=self.params.get('limit', None)
            )
            
            if self.is_cancelled:
                return
            
            self.progress.emit("Finalisation...")
            
            # Émission du résultat
            self.finished.emit(result)
            logger.info(f"✅ Analysis worker completed for {view_name}")
            
        except Exception as e:
            error_msg = f"Erreur lors de l'analyse: {str(e)}"
            logger.error(f"❌ {error_msg}")
            self.error.emit(error_msg)
    
    def _prepare_filters(self) -> Dict:
        """Préparation des filtres à partir des paramètres"""
        filters = {}
        
        # Filtres de dates
        if 'date_start' in self.params and self.params['date_start']:
            filters['date_start'] = self.params['date_start'].strftime('%Y-%m-%d')
        
        if 'date_end' in self.params and self.params['date_end']:
            filters['date_end'] = self.params['date_end'].strftime('%Y-%m-%d')
        
        # Autres filtres
        if 'filters' in self.params:
            filters.update(self.params['filters'])
        
        return filters
    
    def cancel(self):
        """Annulation de l'exécution"""
        self.is_cancelled = True
        logger.info("🛑 Analysis cancellation requested")

class ViewDiscoveryWorker(QThread):
    """Worker pour la découverte des VIEWs disponibles"""
    
    # Signaux émis
    finished = Signal(list)  # Liste des VIEWs découvertes
    error = Signal(str)      # Message d'erreur
    
    def __init__(self, database_manager):
        """
        Initialisation du worker
        
        Args:
            database_manager: Instance de DatabaseManager
        """
        super().__init__()
        self.database_manager = database_manager
    
    def run(self):
        """Découverte des VIEWs en arrière-plan"""
        try:
            logger.info("🔍 Starting VIEWs discovery")
            
            # Découverte des VIEWs
            views = self.database_manager.get_available_views()
            
            # Émission du résultat
            self.finished.emit(views)
            logger.info(f"✅ Discovery completed: {len(views)} VIEWs found")
            
        except Exception as e:
            error_msg = f"Erreur lors de la découverte des VIEWs: {str(e)}"
            logger.error(f"❌ {error_msg}")
            self.error.emit(error_msg)

class ViewInfoWorker(QThread):
    """Worker pour récupérer les informations détaillées d'une VIEW"""
    
    # Signaux émis
    finished = Signal(str, dict)  # view_name, informations
    error = Signal(str, str)      # view_name, message d'erreur
    
    def __init__(self, analysis_engine, view_name: str):
        """
        Initialisation du worker
        
        Args:
            analysis_engine: Instance de AnalysisEngine
            view_name: Nom de la VIEW à analyser
        """
        super().__init__()
        self.analysis_engine = analysis_engine
        self.view_name = view_name
    
    def run(self):
        """Récupération des informations de la VIEW en arrière-plan"""
        try:
            logger.info(f"🔍 Analyse de la VIEW {self.view_name}")
            
            # Récupération des informations
            info = self.analysis_engine.get_view_info(self.view_name)
            
            # Émission du résultat
            self.finished.emit(self.view_name, info)
            logger.info(f"✅ VIEW {self.view_name} information retrieved")
            
        except Exception as e:
            error_msg = f"Erreur lors de l'analyse de la VIEW: {str(e)}"
            logger.error(f"❌ {error_msg}")
            self.error.emit(self.view_name, error_msg)
