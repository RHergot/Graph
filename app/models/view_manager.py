"""
Gestionnaire CRUD pour les VIEWs KPI
Opérations de création, lecture, mise à jour et suppression des VIEWs
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime
import json
from dataclasses import asdict

from app.models.database_manager import DatabaseManager
from view_builder import ViewDefinition, ViewBuilder, ModuleType
from app.utils.view_exceptions import *

logger = logging.getLogger(__name__)

class ViewManager:
    """
    Gestionnaire CRUD pour les VIEWs KPI
    Interface entre l'application et la base de données pour la gestion des VIEWs
    """
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.view_builder = ViewBuilder()
        self._cache = {}  # Cache des métadonnées des VIEWs
        self._last_refresh = None
    
    def create_view(self, view_def: ViewDefinition, force_recreate: bool = False) -> bool:
        """
        Crée une nouvelle VIEW dans la base de données
        
        Args:
            view_def: Définition de la VIEW
            force_recreate: Force la recréation si la VIEW existe déjà
            
        Returns:
            bool: True si la création a réussi
            
        Raises:
            ViewCreationError: En cas d'erreur de création
            ViewAlreadyExistsError: Si la VIEW existe déjà et force_recreate=False
        """
        try:
            # Validation de la définition
            is_valid, errors = self.view_builder.validate_view_definition(view_def)
            if not is_valid:
                raise ViewValidationError(f"Définition invalide: {', '.join(errors)}")
            
            view_name = self.view_builder._build_view_name(view_def.name, view_def.module)
            
            # Vérification de l'existence
            if self._view_exists(view_name) and not force_recreate:
                raise ViewAlreadyExistsError(f"La VIEW {view_name} existe déjà")
            
            # Génération du SQL
            sql = self.view_builder.generate_view_sql(view_def)
            
            # Test de validation du SQL (DRY RUN)
            if not self._validate_sql_syntax(sql, view_def):
                raise ViewCreationError(f"SQL invalide pour la VIEW {view_name}")
            
            # Exécution de la création
            self.db_manager.execute_query(sql, fetch_results=False)
            
            # Sauvegarde des métadonnées
            self._save_view_metadata(view_def)
            
            # Invalidation du cache
            self._invalidate_cache()
            
            logger.info(f"VIEW {view_name} créée avec succès")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la création de la VIEW {view_def.name}: {e}")
            if isinstance(e, ViewManagerException):
                raise
            raise ViewCreationError(f"Erreur de création: {e}")
    
    def get_view_data(self, view_name: str, limit: Optional[int] = 1000, 
                     filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """
        Récupère les données d'une VIEW
        
        Args:
            view_name: Nom de la VIEW (avec ou sans préfixe)
            limit: Limite du nombre de lignes
            filters: Filtres additionnels à appliquer
            
        Returns:
            List[Dict]: Données de la VIEW
            
        Raises:
            ViewNotFoundError: Si la VIEW n'existe pas
        """
        try:
            # Normalisation du nom
            full_view_name = self._normalize_view_name(view_name)
            
            if not self._view_exists(full_view_name):
                raise ViewNotFoundError(f"La VIEW {full_view_name} n'existe pas")
            
            # Construction de la requête
            sql = f"SELECT * FROM {full_view_name}"
            
            # Application des filtres
            if filters:
                where_conditions = self._build_filter_conditions(filters)
                if where_conditions:
                    sql += f" WHERE {where_conditions}"
            
            # Application de la limite
            if limit:
                sql += f" LIMIT {limit}"
            
            # Exécution
            results = self.db_manager.execute_query(sql, fetch_results=True)
            
            logger.info(f"Récupération de {len(results)} lignes de la VIEW {full_view_name}")
            return results
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des données de {view_name}: {e}")
            if isinstance(e, ViewManagerException):
                raise
            raise ViewDataRetrievalError(f"Erreur de récupération: {e}")
    
    def update_view(self, view_def: ViewDefinition) -> bool:
        """
        Met à jour une VIEW existante
        
        Args:
            view_def: Nouvelle définition de la VIEW
            
        Returns:
            bool: True si la mise à jour a réussi
        """
        try:
            return self.create_view(view_def, force_recreate=True)
        except Exception as e:
            logger.error(f"Erreur lors de la mise à jour de la VIEW {view_def.name}: {e}")
            raise ViewUpdateError(f"Erreur de mise à jour: {e}")
    
    def delete_view(self, view_name: str, cascade: bool = False) -> bool:
        """
        Supprime une VIEW
        
        Args:
            view_name: Nom de la VIEW à supprimer
            cascade: Suppression en cascade
            
        Returns:
            bool: True si la suppression a réussi
        """
        try:
            full_view_name = self._normalize_view_name(view_name)
            
            if not self._view_exists(full_view_name):
                raise ViewNotFoundError(f"La VIEW {full_view_name} n'existe pas")
            
            # Construction du SQL de suppression
            cascade_sql = " CASCADE" if cascade else ""
            sql = f"DROP VIEW {full_view_name}{cascade_sql};"
            
            # Exécution
            self.db_manager.execute_query(sql, fetch_results=False)
            
            # Suppression des métadonnées
            self._delete_view_metadata(full_view_name)
            
            # Invalidation du cache
            self._invalidate_cache()
            
            logger.info(f"VIEW {full_view_name} supprimée avec succès")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la suppression de la VIEW {view_name}: {e}")
            if isinstance(e, ViewManagerException):
                raise
            raise ViewDeletionError(f"Erreur de suppression: {e}")
    
    def list_kpi_views(self, module: Optional[ModuleType] = None) -> List[Dict[str, Any]]:
        """
        Liste toutes les VIEWs KPI disponibles
        
        Args:
            module: Filtre par module (optionnel)
            
        Returns:
            List[Dict]: Informations sur les VIEWs KPI
        """
        try:
            all_views = self.db_manager.get_available_views()
            
            # Filtrage des VIEWs KPI
            kpi_views = []
            for view_name in all_views:
                if self._is_kpi_view(view_name):
                    view_info = self._get_view_info(view_name)
                    
                    # Filtrage par module si spécifié
                    if module is None or view_info.get('module') == module.value:
                        kpi_views.append(view_info)
            
            logger.info(f"Trouvé {len(kpi_views)} VIEWs KPI")
            return kpi_views
            
        except Exception as e:
            logger.error(f"Erreur lors du listage des VIEWs KPI: {e}")
            raise ViewListingError(f"Erreur de listage: {e}")
    
    def get_view_schema(self, view_name: str) -> Dict[str, Any]:
        """
        Récupère le schéma d'une VIEW (colonnes, types, commentaires)
        
        Args:
            view_name: Nom de la VIEW
            
        Returns:
            Dict: Schéma de la VIEW
        """
        try:
            full_view_name = self._normalize_view_name(view_name)
            
            # Requête pour obtenir les informations de colonnes
            sql = """
            SELECT 
                column_name,
                data_type,
                is_nullable,
                column_default,
                character_maximum_length,
                numeric_precision,
                numeric_scale
            FROM information_schema.columns 
            WHERE table_name = %s 
            ORDER BY ordinal_position
            """
            
            columns_info = self.db_manager.execute_query(
                sql, 
                (full_view_name.split('.')[-1],),  # Nom sans schéma
                fetch_results=True
            )
            
            # Récupération des commentaires
            comments = self._get_column_comments(full_view_name)
            
            # Construction du schéma
            schema = {
                'view_name': full_view_name,
                'columns': []
            }
            
            for col_info in columns_info:
                column = {
                    'name': col_info['column_name'],
                    'type': col_info['data_type'],
                    'nullable': col_info['is_nullable'] == 'YES',
                    'default': col_info['column_default'],
                    'comment': comments.get(col_info['column_name'], '')
                }
                
                # Ajout des informations de taille si applicable
                if col_info['character_maximum_length']:
                    column['max_length'] = col_info['character_maximum_length']
                if col_info['numeric_precision']:
                    column['precision'] = col_info['numeric_precision']
                if col_info['numeric_scale']:
                    column['scale'] = col_info['numeric_scale']
                
                schema['columns'].append(column)
            
            return schema
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération du schéma de {view_name}: {e}")
            raise ViewSchemaError(f"Erreur de schéma: {e}")
    
    def refresh_view(self, view_name: str) -> bool:
        """
        Rafraîchit une VIEW matérialisée (si applicable)
        
        Args:
            view_name: Nom de la VIEW
            
        Returns:
            bool: True si le rafraîchissement a réussi
        """
        try:
            full_view_name = self._normalize_view_name(view_name)
            
            # Vérification si c'est une vue matérialisée
            if self._is_materialized_view(full_view_name):
                sql = f"REFRESH MATERIALIZED VIEW {full_view_name};"
                self.db_manager.execute_query(sql, fetch_results=False)
                logger.info(f"VIEW matérialisée {full_view_name} rafraîchie")
                return True
            else:
                logger.info(f"La VIEW {full_view_name} n'est pas matérialisée, pas de rafraîchissement nécessaire")
                return True
                
        except Exception as e:
            logger.error(f"Erreur lors du rafraîchissement de {view_name}: {e}")
            raise ViewRefreshError(f"Erreur de rafraîchissement: {e}")
    
    # Méthodes utilitaires privées
    
    def _view_exists(self, view_name: str) -> bool:
        """Vérifie si une VIEW existe"""
        try:
            all_views = self.db_manager.get_available_views()
            return view_name.lower() in [v.lower() for v in all_views]
        except:
            return False
    
    def _normalize_view_name(self, view_name: str) -> str:
        """Normalise le nom d'une VIEW (ajoute le préfixe si nécessaire)"""
        view_name = view_name.lower()
        
        # Si le nom contient déjà un préfixe KPI, on le retourne tel quel
        for module in ModuleType:
            prefix = self.view_builder.prefixes[module]
            if view_name.startswith(prefix):
                return view_name
        
        # Sinon, on assume que c'est un nom court et on cherche le préfixe approprié
        for module in ModuleType:
            prefix = self.view_builder.prefixes[module]
            full_name = f"{prefix}{view_name}"
            if self._view_exists(full_name):
                return full_name
        
        # Si aucun préfixe ne correspond, on retourne le nom original
        return view_name
    
    def _is_kpi_view(self, view_name: str) -> bool:
        """Vérifie si une VIEW est une VIEW KPI (basé sur le préfixe)"""
        view_name = view_name.lower()
        return any(view_name.startswith(prefix) for prefix in self.view_builder.prefixes.values())
    
    def _get_view_info(self, view_name: str) -> Dict[str, Any]:
        """Récupère les informations d'une VIEW"""
        info = {
            'name': view_name,
            'full_name': view_name,
            'module': self._get_module_from_name(view_name),
            'created_date': None,
            'description': '',
            'row_count': 0
        }
        
        # Tentative de récupération des métadonnées sauvegardées
        metadata = self._load_view_metadata(view_name)
        if metadata:
            info.update(metadata)
        
        # Récupération du nombre de lignes
        try:
            count_sql = f"SELECT COUNT(*) as row_count FROM {view_name}"
            result = self.db_manager.execute_query(count_sql, fetch_results=True)
            if result:
                info['row_count'] = result[0]['row_count']
        except:
            pass  # Ignore les erreurs de comptage
        
        return info
    
    def _get_module_from_name(self, view_name: str) -> Optional[str]:
        """Détermine le module d'une VIEW basé sur son nom"""
        view_name = view_name.lower()
        for module, prefix in self.view_builder.prefixes.items():
            if view_name.startswith(prefix):
                return module.value
        return None
    
    def _validate_sql_syntax(self, sql: str, view_def: ViewDefinition) -> bool:
        """Valide la syntaxe SQL en mode DRY RUN"""
        try:
            # Création d'une version temporaire pour tester
            temp_name = f"temp_validate_{view_def.name}_{int(datetime.now().timestamp())}"
            test_sql = sql.replace(
                self.view_builder._build_view_name(view_def.name, view_def.module),
                temp_name
            )
            
            # Test de création
            self.db_manager.execute_query(test_sql, fetch_results=False)
            
            # Nettoyage
            cleanup_sql = f"DROP VIEW {temp_name};"
            self.db_manager.execute_query(cleanup_sql, fetch_results=False)
            
            return True
        except:
            return False
    
    def _build_filter_conditions(self, filters: Dict[str, Any]) -> str:
        """Construit les conditions WHERE à partir des filtres"""
        conditions = []
        
        for column, value in filters.items():
            if isinstance(value, str):
                conditions.append(f"{column} ILIKE '%{value}%'")
            elif isinstance(value, (int, float)):
                conditions.append(f"{column} = {value}")
            elif isinstance(value, list):
                if len(value) == 2 and all(isinstance(v, (int, float)) for v in value):
                    # Range de valeurs
                    conditions.append(f"{column} BETWEEN {value[0]} AND {value[1]}")
                else:
                    # Liste de valeurs
                    values_str = "', '".join(str(v) for v in value)
                    conditions.append(f"{column} IN ('{values_str}')")
        
        return " AND ".join(conditions)
    
    def _get_column_comments(self, view_name: str) -> Dict[str, str]:
        """Récupère les commentaires des colonnes"""
        try:
            sql = """
            SELECT 
                a.attname as column_name,
                d.description as comment
            FROM pg_attribute a
            LEFT JOIN pg_description d ON a.attrelid = d.objoid AND a.attnum = d.objsubid
            WHERE a.attrelid = %s::regclass 
            AND a.attnum > 0 
            AND NOT a.attisdropped
            """
            
            results = self.db_manager.execute_query(sql, (view_name,), fetch_results=True)
            return {r['column_name']: r['comment'] or '' for r in results}
        except:
            return {}
    
    def _is_materialized_view(self, view_name: str) -> bool:
        """Vérifie si une VIEW est matérialisée"""
        try:
            sql = """
            SELECT 1 FROM pg_matviews 
            WHERE matviewname = %s
            """
            result = self.db_manager.execute_query(
                sql, 
                (view_name.split('.')[-1],), 
                fetch_results=True
            )
            return len(result) > 0
        except:
            return False
    
    def _save_view_metadata(self, view_def: ViewDefinition):
        """Sauvegarde les métadonnées d'une VIEW"""
        # Pour une implémentation future - sauvegarde dans une table de métadonnées
        pass
    
    def _load_view_metadata(self, view_name: str) -> Optional[Dict[str, Any]]:
        """Charge les métadonnées d'une VIEW"""
        # Pour une implémentation future - chargement depuis une table de métadonnées
        return None
    
    def _delete_view_metadata(self, view_name: str):
        """Supprime les métadonnées d'une VIEW"""
        # Pour une implémentation future - suppression dans une table de métadonnées
        pass
    
    def _invalidate_cache(self):
        """Invalide le cache des VIEWs"""
        self._cache.clear()
        self._last_refresh = None
