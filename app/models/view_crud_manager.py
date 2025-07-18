"""
Gestionnaire CRUD pour les vues avancées
Migré depuis views_construct.py pour une meilleure architecture
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime
import json

from .database_manager import DatabaseManager
from .view_manager import ViewManager

logger = logging.getLogger(__name__)

class ViewCrudManager:
    """
    Gestionnaire CRUD pour les vues avancées créées via l'interface utilisateur
    Sépare la logique métier de l'interface utilisateur
    """
    
    def __init__(self, db_manager: DatabaseManager = None):
        """Initialise le gestionnaire CRUD"""
        self.db_manager = db_manager or DatabaseManager()
        self.view_manager = ViewManager(self.db_manager)
        self.connected = self._test_connection()
        
        # Cache local des vues créées
        self.local_views = []
        
        # Initialiser avec des vues de test si pas de connexion DB
        if not self.connected:
            self._initialize_sample_views()
    
    def _test_connection(self) -> bool:
        """Teste la connexion à la base de données"""
        try:
            return self.db_manager is not None and hasattr(self.db_manager, 'engine')
        except Exception as e:
            logger.warning(f"Connexion DB non disponible: {e}")
            return False
    
    def _initialize_sample_views(self):
        """Initialise des vues de test pour le mode hors ligne"""
        sample_views = [
            {
                'name': 'vue_maintenance_mensuelle',
                'type': 'Analyse temporelle',
                'created_date': '2024-01-15',
                'data': {
                    'main_table': 'maintenance',
                    'x_field': 'date_debut_reelle',
                    'y_fields': ['duree_intervention_h', 'cout_total'],
                    'grouping': 'monthly',
                    'sql': 'SELECT DATE_TRUNC(\'month\', date_debut_reelle) as mois, SUM(duree_intervention_h) as duree_totale, SUM(cout_total) as cout_total FROM maintenance GROUP BY DATE_TRUNC(\'month\', date_debut_reelle) ORDER BY mois;'
                },
                'review_status': '📝 Brouillon',
                'reviewer': '',
                'review_comments': '',
                'review_date': None
            },
            {
                'name': 'vue_machines_criticite',
                'type': 'Analyse par criticité',
                'created_date': '2024-01-20',
                'data': {
                    'main_table': 'machine',
                    'x_field': 'criticite',
                    'y_fields': ['valeur_achat'],
                    'grouping': 'none',
                    'sql': 'SELECT criticite, COUNT(*) as nb_machines, AVG(valeur_achat) as valeur_moyenne FROM machine GROUP BY criticite ORDER BY criticite;'
                },
                'review_status': '✅ Approuvé',
                'reviewer': 'Admin',
                'review_comments': 'Vue validée pour le reporting mensuel',
                'review_date': '2024-01-22'
            },
            {
                'name': 'vue_techniciens_performance',
                'type': 'Analyse de performance',
                'created_date': '2024-01-25',
                'data': {
                    'main_table': 'technicien',
                    'x_field': 'specialite',
                    'y_fields': ['niveau_competence'],
                    'grouping': 'none',
                    'sql': 'SELECT t.specialite, AVG(t.niveau_competence) as competence_moyenne, COUNT(m.id_maintenance) as nb_interventions FROM technicien t LEFT JOIN maintenance m ON t.id_technicien = m.technicien_id GROUP BY t.specialite;'
                },
                'review_status': '🔄 En relecture',
                'reviewer': 'Superviseur',
                'review_comments': 'À vérifier avec les données récentes',
                'review_date': None
            }
        ]
        
        self.local_views.extend(sample_views)
    
    def get_available_views(self) -> List[Dict]:
        """Récupère toutes les vues disponibles (DB + locales)"""
        views = []
        
        # Vues de la base de données
        if self.connected:
            try:
                db_views = self.db_manager.get_available_views()
                for view_info in db_views:
                    views.append({
                        'name': view_info['name'],
                        'type': 'Vue DB',
                        'created_date': 'Base de données',
                        'column_count': view_info['column_count'],
                        'columns': view_info.get('columns', [])[:5],
                        'source': 'database'
                    })
            except Exception as e:
                logger.error(f"Erreur récupération vues DB: {e}")
        
        # Vues locales
        for view in self.local_views:
            view_type = view.get('type', 'Vue locale')
            views.append({
                'name': view['name'],
                'type': view_type,
                'created_date': view['created_date'],
                'column_count': len(view.get('data', {}).get('y_fields', [])),
                'columns': view.get('data', {}).get('y_fields', []),
                'source': 'local',
                'review_status': view.get('review_status', '📝 Brouillon'),
                'reviewer': view.get('reviewer', ''),
                'review_comments': view.get('review_comments', ''),
                'review_date': view.get('review_date')
            })
        
        return views
    
    def create_view(self, view_data: Dict) -> Tuple[bool, str]:
        """Crée une nouvelle vue"""
        try:
            # Valider les données
            if not view_data.get('name'):
                return False, "Nom de vue requis"
            
            # Ajouter à la liste locale
            view_for_review = {
                'name': view_data['name'],
                'type': view_data.get('type', 'Vue personnalisée'),
                'created_date': datetime.now().strftime('%Y-%m-%d'),
                'data': view_data,
                'review_status': '📝 Brouillon',
                'reviewer': '',
                'review_comments': '',
                'review_date': None
            }
            
            self.local_views.append(view_for_review)
            
            # Créer en base si connecté
            if self.connected and view_data.get('sql'):
                try:
                    success = self.db_manager.execute_query(f"DROP VIEW IF EXISTS {view_data['name']}")
                    success = self.db_manager.execute_query(view_data['sql'])
                    logger.info(f"Vue {view_data['name']} créée en base de données")
                except Exception as e:
                    logger.warning(f"Impossible de créer la vue en DB: {e}")
            
            return True, f"Vue '{view_data['name']}' créée avec succès"
            
        except Exception as e:
            logger.error(f"Erreur création vue: {e}")
            return False, f"Erreur lors de la création: {e}"
    
    def delete_view(self, view_name: str) -> Tuple[bool, str]:
        """Supprime une vue"""
        try:
            # Supprimer de la base si connecté
            if self.connected:
                try:
                    success = self.db_manager.execute_query(f"DROP VIEW IF EXISTS {view_name}")
                    logger.info(f"Vue {view_name} supprimée de la base de données")
                except Exception as e:
                    logger.warning(f"Impossible de supprimer la vue de la DB: {e}")
            
            # Supprimer de la liste locale
            self.local_views = [v for v in self.local_views if v['name'] != view_name]
            
            return True, f"Vue '{view_name}' supprimée avec succès"
            
        except Exception as e:
            logger.error(f"Erreur suppression vue: {e}")
            return False, f"Erreur lors de la suppression: {e}"
    
    def get_view_data(self, view_name: str, limit: int = 100) -> Tuple[Any, str]:
        """Récupère les données d'une vue"""
        if not self.connected:
            return None, "Pas de connexion à la base de données"
        
        try:
            query = f"SELECT * FROM {view_name} LIMIT {limit}"
            df = self.db_manager.execute_query_to_dataframe(query)
            return df, f"{len(df)} lignes récupérées"
            
        except Exception as e:
            logger.error(f"Erreur récupération données: {e}")
            return None, f"Erreur lors de la récupération des données: {e}"
    
    def update_review(self, view_name: str, review_data: Dict) -> Tuple[bool, str]:
        """Met à jour les informations de relecture d'une vue"""
        try:
            # Trouver la vue dans la liste locale
            for view in self.local_views:
                if view['name'] == view_name:
                    view['review_status'] = review_data.get('status', view['review_status'])
                    view['reviewer'] = review_data.get('reviewer', view['reviewer'])
                    view['review_comments'] = review_data.get('comments', view['review_comments'])
                    view['review_date'] = review_data.get('date', datetime.now().strftime('%Y-%m-%d'))
                    
                    return True, f"Relecture de '{view_name}' mise à jour"
            
            return False, f"Vue '{view_name}' non trouvée"
            
        except Exception as e:
            logger.error(f"Erreur mise à jour relecture: {e}")
            return False, f"Erreur lors de la mise à jour: {e}"
    
    def export_review_report(self) -> str:
        """Génère un rapport de relecture"""
        if not self.local_views:
            return "Aucune vue à exporter."
        
        report_lines = []
        report_lines.append("=" * 60)
        report_lines.append("📋 RAPPORT DE RELECTURE DES VUES")
        report_lines.append("=" * 60)
        report_lines.append(f"📅 Généré le: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"📊 Nombre de vues: {len(self.local_views)}")
        report_lines.append("")
        
        for i, view in enumerate(self.local_views, 1):
            report_lines.append(f"📊 VUE #{i}: {view['name']}")
            report_lines.append("-" * 40)
            report_lines.append(f"📅 Créée le: {view['created_date']}")
            report_lines.append(f"📝 Statut: {view['review_status']}")
            report_lines.append(f"👤 Relecteur: {view['reviewer'] or 'Non assigné'}")
            report_lines.append(f"📅 Date relecture: {view['review_date'] or 'Non renseignée'}")
            report_lines.append(f"💬 Commentaires: {view['review_comments'] or 'Aucun'}")
            report_lines.append("")
        
        return "\n".join(report_lines)