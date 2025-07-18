"""
Constructeur de vues SQL avancées
Migré depuis views_construct.py pour une meilleure architecture
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)

class ModuleType(Enum):
    """Types de modules pour les vues"""
    TEMPORAL = "temporal"
    AGGREGATION = "aggregation"
    COMPARISON = "comparison"
    PERFORMANCE = "performance"

@dataclass
class ViewDefinition:
    """Définition d'une vue SQL"""
    name: str
    main_table: str
    x_field: str
    y_fields: List[str]
    aggregations: Dict[str, str]
    grouping: str
    filters: Dict[str, Any]
    secondary_table: Optional[str] = None
    join_condition: Optional[str] = None
    sql: Optional[str] = None
    module_type: ModuleType = ModuleType.AGGREGATION

class ViewBuilder:
    """
    Constructeur de vues SQL avancées
    Sépare la logique de construction SQL de l'interface utilisateur
    """
    
    def __init__(self):
        """Initialise le constructeur de vues"""
        self.tables_metadata = self._load_tables_metadata()
    
    def _load_tables_metadata(self) -> Dict:
        """Charge les métadonnées des tables GMAO"""
        return {
            "maintenance": {
                "display_name": "🔧 Maintenance",
                "fields": {
                    "id_maintenance": {"type": "integer", "display": "ID Maintenance", "aggregable": False},
                    "ot_id": {"type": "integer", "display": "N° Ordre de Travail", "aggregable": False},
                    "machine_id": {"type": "integer", "display": "ID Machine", "aggregable": False},
                    "technicien_id": {"type": "integer", "display": "ID Technicien", "aggregable": False},
                    "date_debut_reelle": {"type": "date", "display": "📅 Date Début", "aggregable": False},
                    "date_fin_reelle": {"type": "date", "display": "📅 Date Fin", "aggregable": False},
                    "duree_intervention_h": {"type": "numeric", "display": "⏱️ Durée (h)", "aggregable": True},
                    "type_reel": {"type": "text", "display": "Type Intervention", "aggregable": False},
                    "cout_main_oeuvre": {"type": "numeric", "display": "💰 Coût Main d'Œuvre", "aggregable": True},
                    "cout_pieces_internes": {"type": "numeric", "display": "💰 Coût Pièces Internes", "aggregable": True},
                    "cout_pieces_externes": {"type": "numeric", "display": "💰 Coût Pièces Externes", "aggregable": True},
                    "cout_total": {"type": "numeric", "display": "💰 Coût Total", "aggregable": True},
                    "evaluation_qualite": {"type": "integer", "display": "⭐ Évaluation Qualité", "aggregable": True},
                    "impact_production": {"type": "text", "display": "📊 Impact Production", "aggregable": False}
                }
            },
            "machine": {
                "display_name": "⚙️ Machine",
                "fields": {
                    "id_machine": {"type": "integer", "display": "ID Machine", "aggregable": False},
                    "nom": {"type": "text", "display": "Nom Machine", "aggregable": False},
                    "modele": {"type": "text", "display": "Modèle", "aggregable": False},
                    "fabricant": {"type": "text", "display": "Fabricant", "aggregable": False},
                    "date_installation": {"type": "date", "display": "📅 Date Installation", "aggregable": False},
                    "valeur_achat": {"type": "numeric", "display": "💰 Valeur Achat", "aggregable": True},
                    "etat": {"type": "text", "display": "État", "aggregable": False},
                    "localisation": {"type": "text", "display": "📍 Localisation", "aggregable": False},
                    "criticite": {"type": "integer", "display": "🔥 Criticité", "aggregable": True}
                }
            },
            "technicien": {
                "display_name": "👨‍🔧 Technicien",
                "fields": {
                    "id_technicien": {"type": "integer", "display": "ID Technicien", "aggregable": False},
                    "nom": {"type": "text", "display": "Nom", "aggregable": False},
                    "prenom": {"type": "text", "display": "Prénom", "aggregable": False},
                    "specialite": {"type": "text", "display": "Spécialité", "aggregable": False},
                    "niveau_competence": {"type": "integer", "display": "📊 Niveau Compétence", "aggregable": True},
                    "date_embauche": {"type": "date", "display": "📅 Date Embauche", "aggregable": False},
                    "salaire_horaire": {"type": "numeric", "display": "💰 Salaire Horaire", "aggregable": True},
                    "statut": {"type": "text", "display": "Statut", "aggregable": False}
                }
            },
            "piece_detachee": {
                "display_name": "🔩 Pièce Détachée",
                "fields": {
                    "id_piece": {"type": "integer", "display": "ID Pièce", "aggregable": False},
                    "nom": {"type": "text", "display": "Nom Pièce", "aggregable": False},
                    "reference": {"type": "text", "display": "Référence", "aggregable": False},
                    "categorie": {"type": "text", "display": "Catégorie", "aggregable": False},
                    "prix_unitaire": {"type": "numeric", "display": "💰 Prix Unitaire", "aggregable": True},
                    "stock_actuel": {"type": "integer", "display": "📦 Stock Actuel", "aggregable": True},
                    "stock_alerte": {"type": "integer", "display": "⚠️ Stock Alerte", "aggregable": True},
                    "fournisseur_pref_id": {"type": "integer", "display": "ID Fournisseur Préféré", "aggregable": False}
                }
            }
        }
    
    def validate_view_definition(self, view_def: ViewDefinition) -> Tuple[bool, List[str]]:
        """Valide une définition de vue"""
        errors = []
        
        # Validation du nom
        if not view_def.name or not view_def.name.strip():
            errors.append("Le nom de la vue est requis")
        
        # Validation de la table principale
        if not view_def.main_table or view_def.main_table not in self.tables_metadata:
            errors.append("Table principale invalide")
        
        # Validation des champs
        if not view_def.x_field:
            errors.append("Champ X requis")
        
        if not view_def.y_fields or not any(view_def.y_fields):
            errors.append("Au moins un champ Y requis")
        
        # Validation des agrégations
        valid_aggregations = ['SUM', 'AVG', 'COUNT', 'MIN', 'MAX']
        for field, agg in view_def.aggregations.items():
            if agg and agg not in valid_aggregations:
                errors.append(f"Agrégation invalide pour {field}: {agg}")
        
        return len(errors) == 0, errors
    
    def build_sql_query(self, view_def: ViewDefinition) -> str:
        """Construit la requête SQL pour une vue"""
        try:
            # Validation préalable
            is_valid, errors = self.validate_view_definition(view_def)
            if not is_valid:
                raise ValueError(f"Définition invalide: {', '.join(errors)}")
            
            # Construction de la requête
            select_parts = []
            
            # Champ X (groupement)
            x_field = view_def.x_field
            if view_def.grouping == 'monthly':
                select_parts.append(f"DATE_TRUNC('month', {x_field}) as {x_field}_grouped")
            elif view_def.grouping == 'weekly':
                select_parts.append(f"DATE_TRUNC('week', {x_field}) as {x_field}_grouped")
            elif view_def.grouping == 'daily':
                select_parts.append(f"DATE_TRUNC('day', {x_field}) as {x_field}_grouped")
            else:
                select_parts.append(f"{x_field}")
            
            # Champs Y avec agrégations
            for i, y_field in enumerate(view_def.y_fields, 1):
                if y_field:  # Ignorer les champs vides
                    agg_func = view_def.aggregations.get(f'y{i}', 'SUM')
                    if agg_func and agg_func != 'NONE':
                        select_parts.append(f"{agg_func}({y_field}) as {y_field}_{agg_func.lower()}")
                    else:
                        select_parts.append(f"{y_field}")
            
            # Construction de la clause FROM
            from_clause = view_def.main_table
            
            # Jointure si table secondaire
            if view_def.secondary_table and view_def.join_condition:
                from_clause += f" JOIN {view_def.secondary_table} ON {view_def.join_condition}"
            
            # Construction de la clause WHERE (filtres)
            where_conditions = []
            for filter_name, filter_value in view_def.filters.items():
                if filter_value:
                    if filter_name == 'date_start':
                        where_conditions.append(f"{x_field} >= '{filter_value}'")
                    elif filter_name == 'date_end':
                        where_conditions.append(f"{x_field} <= '{filter_value}'")
                    elif filter_name == 'min_value':
                        where_conditions.append(f"{view_def.y_fields[0]} >= {filter_value}")
                    elif filter_name == 'max_value':
                        where_conditions.append(f"{view_def.y_fields[0]} <= {filter_value}")
                    elif filter_name == 'contains_text':
                        where_conditions.append(f"{x_field} ILIKE '%{filter_value}%'")
            
            # Construction de la clause GROUP BY
            group_by_clause = ""
            if view_def.grouping != 'none':
                if view_def.grouping in ['monthly', 'weekly', 'daily']:
                    group_by_clause = f"GROUP BY {x_field}_grouped"
                else:
                    group_by_clause = f"GROUP BY {x_field}"
            
            # Construction de la clause ORDER BY
            order_by_clause = ""
            if view_def.grouping != 'none':
                if view_def.grouping in ['monthly', 'weekly', 'daily']:
                    order_by_clause = f"ORDER BY {x_field}_grouped"
                else:
                    order_by_clause = f"ORDER BY {x_field}"
            
            # Assemblage final
            sql_parts = [
                f"CREATE VIEW {view_def.name} AS",
                f"SELECT {', '.join(select_parts)}",
                f"FROM {from_clause}"
            ]
            
            if where_conditions:
                sql_parts.append(f"WHERE {' AND '.join(where_conditions)}")
            
            if group_by_clause:
                sql_parts.append(group_by_clause)
            
            if order_by_clause:
                sql_parts.append(order_by_clause)
            
            sql_query = "\n".join(sql_parts) + ";"
            
            # Mettre à jour la définition avec le SQL généré
            view_def.sql = sql_query
            
            return sql_query
            
        except Exception as e:
            logger.error(f"Erreur construction SQL: {e}")
            raise
    
    def get_view_info(self, view_def: ViewDefinition) -> Dict[str, Any]:
        """Génère les informations détaillées d'une vue"""
        try:
            table_info = self.tables_metadata.get(view_def.main_table, {})
            
            # Informations sur les agrégations
            agg_info = []
            for i, y_field in enumerate(view_def.y_fields, 1):
                if y_field:
                    agg = view_def.aggregations.get(f'y{i}', 'SUM')
                    field_display = table_info.get('fields', {}).get(y_field, {}).get('display', y_field)
                    if agg and agg != 'NONE':
                        agg_info.append(f"{agg}({field_display})")
                    else:
                        agg_info.append(field_display)
            
            # Informations sur le groupement
            grouping_display = {
                'monthly': 'Par mois',
                'weekly': 'Par semaine', 
                'daily': 'Par jour',
                'none': 'Aucun groupement'
            }.get(view_def.grouping, view_def.grouping)
            
            # Compter les filtres actifs
            active_filters = sum(1 for v in view_def.filters.values() if v)
            
            return {
                'name': view_def.name,
                'table_display': table_info.get('display_name', view_def.main_table),
                'x_field_display': table_info.get('fields', {}).get(view_def.x_field, {}).get('display', view_def.x_field),
                'aggregations': agg_info,
                'grouping': grouping_display,
                'active_filters': active_filters,
                'module_type': view_def.module_type.value
            }
            
        except Exception as e:
            logger.error(f"Erreur génération info vue: {e}")
            return {}
    
    def get_table_metadata(self, table_name: str) -> Dict:
        """Récupère les métadonnées d'une table"""
        return self.tables_metadata.get(table_name, {})
    
    def get_available_tables(self) -> List[str]:
        """Récupère la liste des tables disponibles"""
        return list(self.tables_metadata.keys())
    
    def get_aggregable_fields(self, table_name: str) -> List[str]:
        """Récupère les champs agrégeables d'une table"""
        table_info = self.tables_metadata.get(table_name, {})
        fields = table_info.get('fields', {})
        return [field_name for field_name, field_info in fields.items() 
                if field_info.get('aggregable', False)]
    
    def get_date_fields(self, table_name: str) -> List[str]:
        """Récupère les champs de type date d'une table"""
        table_info = self.tables_metadata.get(table_name, {})
        fields = table_info.get('fields', {})
        return [field_name for field_name, field_info in fields.items() 
                if field_info.get('type') == 'date']