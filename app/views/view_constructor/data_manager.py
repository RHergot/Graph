"""
Data Manager Mixin pour la gestion des données des tables
"""

import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)


class DataManagerMixin:
    """Mixin pour la gestion des données des tables et vues"""
    
    def load_tables_data(self):
        """Charge les données des tables (dynamiquement si services disponibles)"""
        if self.has_database_connection():
            return self._load_real_tables_data()
        else:
            return self._load_sample_tables()
    
    def _load_real_tables_data(self) -> Dict[str, Any]:
        """Charge les données des tables réelles via DatabaseManager"""
        try:
            tables_metadata = self.database_manager.get_tables_metadata()
            tables_data = {}
            
            for table_info in tables_metadata:
                table_name = table_info['name']
                fields = table_info.get('fields', [])
                
                # Adapter les champs pour compatibilité avec le format attendu
                adapted_fields = {}
                for field in fields:
                    adapted_fields[field['name']] = {
                        'type': field['type'],
                        'display': field['display_name'],
                        'aggregable': field.get('aggregable', False)
                    }
                
                tables_data[table_name] = {
                    'display_name': table_info['display_name'],
                    'fields': adapted_fields
                }
            
            logger.info(f"📊 Loaded {len(tables_data)} real tables for view constructor")
            return tables_data
        
        except Exception as e:
            logger.error(f"❌ Erreur _load_real_tables_data: {e}")
            # Fallback vers les données de test en cas d'erreur
            return self._load_sample_tables()
    
    def _load_sample_tables(self) -> Dict[str, Any]:
        """Données de test pour le mode hors ligne"""
        return {
            "maintenance": {
                "display_name": "🔧 Maintenance",
                "fields": {
                    "date_debut_reelle": {"type": "date", "display": "📅 Date Début", "aggregable": False},
                    "cout_total": {"type": "numeric", "display": "💰 Coût Total", "aggregable": True},
                    "duree_intervention_h": {"type": "numeric", "display": "⏱️ Durée (h)", "aggregable": True}
                }
            },
            "machine": {
                "display_name": "🏭 Machines",
                "fields": {
                    "date_installation": {"type": "date", "display": "📅 Date Installation", "aggregable": False},
                    "valeur_achat": {"type": "numeric", "display": "💰 Valeur Achat", "aggregable": True},
                    "criticite": {"type": "integer", "display": "⚠️ Criticité", "aggregable": True}
                }
            },
            "technicien": {
                "display_name": "👨‍🔧 Techniciens",
                "fields": {
                    "date_embauche": {"type": "date", "display": "📅 Date Embauche", "aggregable": False},
                    "niveau_competence": {"type": "integer", "display": "📊 Niveau Compétence", "aggregable": True},
                    "tarif_horaire": {"type": "numeric", "display": "💰 Tarif Horaire", "aggregable": True}
                }
            }
        }
    
    def get_table_fields(self, table_name: str, field_type: str = None) -> Dict[str, Any]:
        """Retourne les champs d'une table, optionnellement filtrés par type"""
        if table_name not in self.tables_data:
            return {}
        
        fields = self.tables_data[table_name]["fields"]
        
        if field_type:
            return {name: info for name, info in fields.items() 
                   if info["type"] == field_type}
        
        return fields
    
    def get_aggregable_fields(self, table_name: str) -> Dict[str, Any]:
        """Retourne les champs agrégables d'une table"""
        if table_name not in self.tables_data:
            return {}
        
        fields = self.tables_data[table_name]["fields"]
        return {name: info for name, info in fields.items() 
               if info.get("aggregable", False)}
    
    def get_date_fields(self, table_name: str) -> Dict[str, Any]:
        """Retourne les champs de type date d'une table"""
        return self.get_table_fields(table_name, "date")
    
    def get_numeric_fields(self, table_name: str) -> Dict[str, Any]:
        """Retourne les champs numériques d'une table"""
        if table_name not in self.tables_data:
            return {}
        
        fields = self.tables_data[table_name]["fields"]
        return {name: info for name, info in fields.items() 
               if info["type"] in ["numeric", "integer"]}
    
    def add_sample_views(self):
        """Ajoute des vues de test pour démonstration"""
        from datetime import datetime
        
        sample_views = [
            {
                "id": 1,
                "name": "vue_maintenance_mensuelle",
                "created_date": "2025-01-15 10:30:00",
                "data": {
                    "name": "vue_maintenance_mensuelle",
                    "main_table": "maintenance",
                    "x_field": "date_debut_reelle",
                    "y_fields": ["cout_total", "duree_intervention_h"],
                    "aggregations": {"y1": "SUM", "y2": "AVG"},
                    "grouping": "📅 Par mois",
                    "filters": {"date_filter": True},
                    "sql": "CREATE OR REPLACE VIEW vue_maintenance_mensuelle AS\nSELECT DATE_TRUNC('month', date_debut_reelle::timestamp) AS periode,\n    SUM(cout_total) AS sum_cout_total,\n    AVG(duree_intervention_h) AS avg_duree_intervention_h\nFROM maintenance\nWHERE date_debut_reelle IS NOT NULL\nGROUP BY periode\nORDER BY periode DESC;"
                },
                "review_status": "📝 Brouillon",
                "reviewer": "",
                "review_comments": "",
                "review_date": None
            },
            {
                "id": 2,
                "name": "vue_machines_criticite",
                "created_date": "2025-01-16 14:20:00",
                "data": {
                    "name": "vue_machines_criticite",
                    "main_table": "machine",
                    "x_field": "date_installation",
                    "y_fields": ["valeur_achat", "criticite"],
                    "aggregations": {"y1": "SUM", "y2": "MAX"},
                    "grouping": "📅 Par année",
                    "filters": {"date_filter": False},
                    "sql": "CREATE OR REPLACE VIEW vue_machines_criticite AS\nSELECT DATE_TRUNC('year', date_installation::timestamp) AS periode,\n    SUM(valeur_achat) AS sum_valeur_achat,\n    MAX(criticite) AS max_criticite\nFROM machine\nWHERE date_installation IS NOT NULL\nGROUP BY periode\nORDER BY periode DESC;"
                },
                "review_status": "👀 En cours de relecture",
                "reviewer": "Jean Dupont",
                "review_comments": "Vue intéressante mais il faudrait ajouter un filtre sur l'état des machines.",
                "review_date": "2025-01-16 15:45:00"
            },
            {
                "id": 3,
                "name": "vue_techniciens_performance",
                "created_date": "2025-01-17 09:15:00",
                "data": {
                    "name": "vue_techniciens_performance",
                    "main_table": "technicien",
                    "x_field": "date_embauche",
                    "y_fields": ["niveau_competence", "tarif_horaire"],
                    "aggregations": {"y1": "AVG", "y2": "AVG"},
                    "grouping": "📅 Par trimestre",
                    "filters": {"date_filter": True},
                    "sql": "CREATE OR REPLACE VIEW vue_techniciens_performance AS\nSELECT DATE_TRUNC('quarter', date_embauche::timestamp) AS periode,\n    AVG(niveau_competence) AS avg_niveau_competence,\n    AVG(tarif_horaire) AS avg_tarif_horaire\nFROM technicien\nWHERE date_embauche IS NOT NULL\nGROUP BY periode\nORDER BY periode DESC;"
                },
                "review_status": "✅ Approuvé",
                "reviewer": "Marie Martin",
                "review_comments": "Excellente vue pour analyser l'évolution des compétences. Approuvée pour mise en production.",
                "review_date": "2025-01-17 11:30:00"
            }
        ]
        
        self.created_views.extend(sample_views)
