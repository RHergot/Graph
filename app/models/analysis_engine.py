"""
Moteur d'analyse - Orchestration des requêtes et traitement des données
"""

from sqlalchemy import text, select, and_, or_
import pandas as pd
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime

from models.database_manager import DatabaseManager
from utils.exceptions import DataProcessingError, InvalidFilterError

logger = logging.getLogger(__name__)

class AnalysisEngine:
    """Moteur d'analyse et de construction de requêtes dynamiques"""
    
    def __init__(self, db_manager: DatabaseManager):
        """Initialisation avec gestionnaire de base de données"""
        self.db_manager = db_manager
        self.available_views = []
        self._load_available_views()
    
    def _load_available_views(self) -> None:
        """Charge la liste des VIEWs disponibles"""
        try:
            self.available_views = self.db_manager.get_available_views()
            logger.info(f"📊 {len(self.available_views)} VIEWs chargées")
        except Exception as e:
            logger.error(f"❌ Erreur chargement VIEWs: {e}")
            self.available_views = []
    
    def get_available_analyses(self) -> List[Dict]:
        """Retourne la liste des analyses disponibles"""
        return self.available_views
    
    def run_analysis(self, view_name: str, filters: Optional[Dict] = None, 
                    aggregations: Optional[Dict] = None, limit: Optional[int] = None) -> pd.DataFrame:
        """
        Exécute une analyse sur une VIEW avec filtres optionnels
        
        Args:
            view_name: Nom de la VIEW à interroger
            filters: Dictionnaire de filtres (ex: {'date_start': '2024-01-01'})
            aggregations: Agrégations à appliquer (ex: {'group_by': ['column1']})
            limit: Limite du nombre de lignes
        
        Returns:
            DataFrame pandas avec les résultats
        """
        try:
            logger.info(f"🔍 Analyse de la VIEW: {view_name}")
            
            # Validation VIEW existe
            if not self._validate_view_exists(view_name):
                raise InvalidFilterError(f"VIEW {view_name} non trouvée")
            
            # Construction requête
            query = self._build_query(view_name, filters, aggregations, limit)
            
            # Exécution
            result_df = self.db_manager.execute_query(query)
            
            logger.info(f"✅ Analyse terminée: {len(result_df)} lignes")
            return result_df
            
        except Exception as e:
            logger.error(f"❌ Erreur analyse {view_name}: {e}")
            raise DataProcessingError(f"Erreur lors de l'analyse: {e}")
    
    def _validate_view_exists(self, view_name: str) -> bool:
        """Valide que la VIEW existe dans la liste disponible"""
        return any(view['name'] == view_name for view in self.available_views)
    
    def _build_query(self, view_name: str, filters: Optional[Dict] = None, 
                    aggregations: Optional[Dict] = None, limit: Optional[int] = None) -> str:
        """Construit la requête SQL dynamique"""
        
        # Base de la requête
        if aggregations and 'group_by' in aggregations:
            # Construction SELECT avec agrégations
            select_clause = self._build_aggregation_select(aggregations)
            group_clause = f"GROUP BY {', '.join(aggregations['group_by'])}"
        else:
            select_clause = "*"
            group_clause = ""
        
        query = f"SELECT {select_clause} FROM {view_name}"
        
        # Application des filtres
        if filters:
            where_clause = self._build_where_clause(view_name, filters)
            if where_clause:
                query += f" WHERE {where_clause}"
        
        # Ajout GROUP BY
        if group_clause:
            query += f" {group_clause}"
        
        # Ajout ORDER BY (par défaut première colonne)
        if aggregations and 'order_by' in aggregations:
            query += f" ORDER BY {aggregations['order_by']}"
        
        # Limitation
        if limit:
            query += f" LIMIT {limit}"
        
        logger.debug(f"🔧 Requête construite: {query}")
        return text(query)
    
    def _build_where_clause(self, view_name: str, filters: Dict) -> str:
        """Construit la clause WHERE à partir des filtres"""
        conditions = []
        
        for key, value in filters.items():
            if value is None:
                continue
                
            if key == 'date_start' and value:
                # Filtre date de début (trouve la colonne de date dynamiquement)
                date_column = self._find_date_column(view_name)
                if date_column:
                    conditions.append(f"{date_column} >= '{value}'")
                else:
                    logger.warning(f"⚠️ Filtre date_start ignoré: aucune colonne de date trouvée dans {view_name}")
            
            elif key == 'date_end' and value:
                # Filtre date de fin
                date_column = self._find_date_column(view_name)
                if date_column:
                    conditions.append(f"{date_column} <= '{value}'")
                else:
                    logger.warning(f"⚠️ Filtre date_end ignoré: aucune colonne de date trouvée dans {view_name}")
            
            elif key.startswith('filter_') and value:
                # Filtres génériques
                column_name = key.replace('filter_', '')
                if isinstance(value, str):
                    conditions.append(f"{column_name} ILIKE '%{value}%'")
                else:
                    conditions.append(f"{column_name} = {value}")
        
        return " AND ".join(conditions)
    
    def _find_date_column(self, view_name: Optional[str] = None) -> Optional[str]:
        """Trouve la première colonne de type date dans la VIEW"""
        if not view_name:
            return None
            
        try:
            # Récupération de la structure de la VIEW
            structure = self.db_manager.get_view_structure(view_name)
            columns = structure.get('columns', [])
            
            # Recherche de colonnes de type date/timestamp
            date_columns = []
            for col in columns:
                col_type = col.get('type', '').lower()
                col_name = col.get('name', '').lower()
                
                # Types de dates PostgreSQL
                if any(date_type in col_type for date_type in [
                    'date', 'timestamp', 'timestamptz', 'time'
                ]):
                    date_columns.append(col['name'])
                
                # Noms courants de colonnes de dates
                elif any(date_name in col_name for date_name in [
                    'date', 'created', 'updated', 'periode', 'time', 'jour', 'heure'
                ]):
                    date_columns.append(col['name'])
            
            if date_columns:
                logger.info(f"📅 Colonnes date détectées dans {view_name}: {date_columns}")
                return date_columns[0]  # Retourne la première colonne de date trouvée
            else:
                logger.warning(f"⚠️ Aucune colonne de date trouvée dans {view_name}")
                return None
                
        except Exception as e:
            logger.error(f"❌ Erreur détection colonne date pour {view_name}: {e}")
            return None
    
    def _build_aggregation_select(self, aggregations: Dict) -> str:
        """Construit la clause SELECT avec agrégations"""
        select_parts = []
        
        # Colonnes de groupement
        if 'group_by' in aggregations:
            select_parts.extend(aggregations['group_by'])
        
        # Agrégations
        if 'sum' in aggregations:
            for col in aggregations['sum']:
                select_parts.append(f"SUM({col}) as sum_{col}")
        
        if 'count' in aggregations:
            for col in aggregations['count']:
                select_parts.append(f"COUNT({col}) as count_{col}")
        
        if 'avg' in aggregations:
            for col in aggregations['avg']:
                select_parts.append(f"AVG({col}) as avg_{col}")
        
        return ", ".join(select_parts) if select_parts else "*"
    
    def get_view_sample(self, view_name: str, limit: int = 10) -> pd.DataFrame:
        """Retourne un échantillon de données d'une VIEW"""
        try:
            return self.run_analysis(view_name, limit=limit)
        except Exception as e:
            logger.error(f"❌ Erreur échantillon {view_name}: {e}")
            return pd.DataFrame()
    
    def get_view_info(self, view_name: str) -> Dict:
        """Retourne les informations détaillées d'une VIEW"""
        try:
            structure = self.db_manager.get_view_structure(view_name)
            sample = self.get_view_sample(view_name, 5)
            
            return {
                'structure': structure,
                'sample_data': sample.to_dict('records') if not sample.empty else [],
                'row_count_sample': len(sample)
            }
        except Exception as e:
            logger.error(f"❌ Erreur info VIEW {view_name}: {e}")
            return {'error': str(e)}
    
    def refresh_views(self) -> int:
        """Actualise la liste des VIEWs disponibles"""
        self._load_available_views()
        return len(self.available_views)
