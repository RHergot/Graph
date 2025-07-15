"""
Analyseur de tables pour l'aide à la création de VIEWs
Exploration automatique du schéma de base de données
"""

import logging
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from collections import defaultdict

from app.models.database_manager import DatabaseManager

logger = logging.getLogger(__name__)

@dataclass
class ColumnInfo:
    """Informations sur une colonne"""
    name: str
    data_type: str
    is_nullable: bool
    default_value: Optional[str]
    max_length: Optional[int]
    is_primary_key: bool
    is_foreign_key: bool
    referenced_table: Optional[str]
    referenced_column: Optional[str]
    comment: Optional[str]

@dataclass
class TableInfo:
    """Informations sur une table"""
    name: str
    schema: str
    columns: List[ColumnInfo]
    row_count: int
    table_size_mb: float
    comment: Optional[str]
    indexes: List[str]
    foreign_keys: List[Dict[str, str]]

class DatabaseSchemaAnalyzer:
    """
    Analyseur de schéma de base de données
    Aide à la découverte et l'analyse des tables pour la création de VIEWs
    """
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self._tables_cache = {}
        self._relationships_cache = {}
    
    def analyze_all_tables(self, schema_name: str = 'public') -> Dict[str, TableInfo]:
        """
        Analyse toutes les tables d'un schéma
        
        Args:
            schema_name: Nom du schéma à analyser
            
        Returns:
            Dict: {table_name: TableInfo}
        """
        try:
            # Récupération de la liste des tables
            tables_list = self._get_tables_list(schema_name)
            
            all_tables = {}
            for table_name in tables_list:
                table_info = self.analyze_table(table_name, schema_name)
                if table_info:
                    all_tables[table_name] = table_info
            
            logger.info(f"Analyse terminée: {len(all_tables)} tables analysées")
            return all_tables
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse des tables: {e}")
            return {}
    
    def analyze_table(self, table_name: str, schema_name: str = 'public') -> Optional[TableInfo]:
        """
        Analyse détaillée d'une table
        
        Args:
            table_name: Nom de la table
            schema_name: Nom du schéma
            
        Returns:
            TableInfo: Informations détaillées sur la table
        """
        try:
            # Vérification du cache
            cache_key = f"{schema_name}.{table_name}"
            if cache_key in self._tables_cache:
                return self._tables_cache[cache_key]
            
            # Récupération des informations de colonnes
            columns = self._get_table_columns(table_name, schema_name)
            
            # Récupération des informations générales
            row_count = self._get_table_row_count(table_name, schema_name)
            table_size = self._get_table_size(table_name, schema_name)
            comment = self._get_table_comment(table_name, schema_name)
            indexes = self._get_table_indexes(table_name, schema_name)
            foreign_keys = self._get_table_foreign_keys(table_name, schema_name)
            
            table_info = TableInfo(
                name=table_name,
                schema=schema_name,
                columns=columns,
                row_count=row_count,
                table_size_mb=table_size,
                comment=comment,
                indexes=indexes,
                foreign_keys=foreign_keys
            )
            
            # Mise en cache
            self._tables_cache[cache_key] = table_info
            
            return table_info
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de la table {table_name}: {e}")
            return None
    
    def find_related_tables(self, table_name: str, schema_name: str = 'public') -> Dict[str, List[str]]:
        """
        Trouve les tables liées par des clés étrangères
        
        Args:
            table_name: Nom de la table de référence
            schema_name: Nom du schéma
            
        Returns:
            Dict: {'references': [tables referenced], 'referenced_by': [tables that reference]}
        """
        try:
            cache_key = f"relationships_{schema_name}.{table_name}"
            if cache_key in self._relationships_cache:
                return self._relationships_cache[cache_key]
            
            # Tables référencées par cette table
            references_sql = """
            SELECT DISTINCT
                ccu.table_name AS referenced_table
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu 
                ON ccu.constraint_name = tc.constraint_name
                AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND tc.table_name = %s
                AND tc.table_schema = %s
            """
            
            references_result = self.db_manager.execute_query(
                references_sql, (table_name, schema_name), fetch_results=True
            )
            references = [row['referenced_table'] for row in references_result]
            
            # Tables qui référencent cette table
            referenced_by_sql = """
            SELECT DISTINCT
                tc.table_name AS referencing_table
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu 
                ON ccu.constraint_name = tc.constraint_name
                AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
                AND ccu.table_name = %s
                AND ccu.table_schema = %s
            """
            
            referenced_by_result = self.db_manager.execute_query(
                referenced_by_sql, (table_name, schema_name), fetch_results=True
            )
            referenced_by = [row['referencing_table'] for row in referenced_by_result]
            
            relationships = {
                'references': references,
                'referenced_by': referenced_by
            }
            
            # Mise en cache
            self._relationships_cache[cache_key] = relationships
            
            return relationships
            
        except Exception as e:
            logger.error(f"Erreur lors de la recherche des relations pour {table_name}: {e}")
            return {'references': [], 'referenced_by': []}
    
    def suggest_joins_for_view(self, base_table: str, target_tables: List[str], 
                              schema_name: str = 'public') -> List[str]:
        """
        Suggère des clauses JOIN pour une VIEW
        
        Args:
            base_table: Table de base
            target_tables: Tables à joindre
            schema_name: Nom du schéma
            
        Returns:
            List[str]: Clauses JOIN suggérées
        """
        try:
            join_suggestions = []
            
            for target_table in target_tables:
                if target_table == base_table:
                    continue
                
                # Recherche des liens directs
                join_clause = self._find_direct_join(base_table, target_table, schema_name)
                if join_clause:
                    join_suggestions.append(join_clause)
                    continue
                
                # Recherche des liens indirects (via table de liaison)
                indirect_joins = self._find_indirect_joins(base_table, target_table, schema_name)
                if indirect_joins:
                    join_suggestions.extend(indirect_joins)
            
            return join_suggestions
            
        except Exception as e:
            logger.error(f"Erreur lors de la suggestion de JOINs: {e}")
            return []
    
    def suggest_columns_for_kpi(self, tables: List[str], kpi_type: str = 'general', 
                               schema_name: str = 'public') -> Dict[str, List[str]]:
        """
        Suggère des colonnes pour un KPI basé sur les tables
        
        Args:
            tables: Liste des tables à analyser
            kpi_type: Type de KPI (general, financial, temporal, count)
            schema_name: Nom du schéma
            
        Returns:
            Dict: {category: [column_suggestions]}
        """
        try:
            suggestions = {
                'identifiers': [],
                'measures': [],
                'dimensions': [],
                'dates': [],
                'calculated': []
            }
            
            for table in tables:
                table_info = self.analyze_table(table, schema_name)
                if not table_info:
                    continue
                
                for column in table_info.columns:
                    column_name = f"{table}.{column.name}"
                    
                    # Identification des identifiants
                    if column.is_primary_key or column.name.endswith('_id') or 'id' in column.name.lower():
                        suggestions['identifiers'].append(column_name)
                    
                    # Identification des mesures
                    elif self._is_numeric_type(column.data_type):
                        if any(keyword in column.name.lower() for keyword in 
                              ['montant', 'prix', 'cout', 'total', 'quantite', 'nombre', 'count']):
                            suggestions['measures'].append(column_name)
                    
                    # Identification des dimensions
                    elif self._is_text_type(column.data_type):
                        if any(keyword in column.name.lower() for keyword in 
                              ['nom', 'type', 'statut', 'categorie', 'classe', 'groupe']):
                            suggestions['dimensions'].append(column_name)
                    
                    # Identification des dates
                    elif self._is_date_type(column.data_type):
                        suggestions['dates'].append(column_name)
            
            # Suggestions de calculs basés sur le type de KPI
            if kpi_type == 'financial':
                suggestions['calculated'].extend([
                    'SUM(montant_total) AS total_revenue',
                    'AVG(prix_unitaire) AS avg_price',
                    'COUNT(*) AS transaction_count'
                ])
            elif kpi_type == 'temporal':
                suggestions['calculated'].extend([
                    'DATE_TRUNC(\'month\', date_column) AS month',
                    'EXTRACT(year FROM date_column) AS year',
                    'AGE(date_fin, date_debut) AS duration'
                ])
            elif kpi_type == 'count':
                suggestions['calculated'].extend([
                    'COUNT(*) AS total_count',
                    'COUNT(DISTINCT column) AS unique_count',
                    'COUNT(*) FILTER (WHERE condition) AS conditional_count'
                ])
            
            return suggestions
            
        except Exception as e:
            logger.error(f"Erreur lors de la suggestion de colonnes: {e}")
            return {key: [] for key in ['identifiers', 'measures', 'dimensions', 'dates', 'calculated']}
    
    def analyze_data_quality(self, table_name: str, schema_name: str = 'public') -> Dict[str, Any]:
        """
        Analyse la qualité des données d'une table
        
        Args:
            table_name: Nom de la table
            schema_name: Nom du schéma
            
        Returns:
            Dict: Rapport de qualité des données
        """
        try:
            table_info = self.analyze_table(table_name, schema_name)
            if not table_info:
                return {}
            
            quality_report = {
                'table_name': table_name,
                'total_rows': table_info.row_count,
                'columns_analysis': {},
                'overall_score': 0
            }
            
            total_score = 0
            analyzed_columns = 0
            
            for column in table_info.columns:
                column_analysis = self._analyze_column_quality(table_name, column, schema_name)
                quality_report['columns_analysis'][column.name] = column_analysis
                
                if column_analysis['score'] is not None:
                    total_score += column_analysis['score']
                    analyzed_columns += 1
            
            # Score global
            if analyzed_columns > 0:
                quality_report['overall_score'] = round(total_score / analyzed_columns, 2)
            
            return quality_report
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de qualité de {table_name}: {e}")
            return {}
    
    def export_schema_documentation(self, schema_name: str = 'public') -> Dict[str, Any]:
        """
        Exporte la documentation complète du schéma
        
        Args:
            schema_name: Nom du schéma
            
        Returns:
            Dict: Documentation complète
        """
        try:
            all_tables = self.analyze_all_tables(schema_name)
            
            documentation = {
                'schema_name': schema_name,
                'analysis_date': str(logging.Formatter().formatTime()),
                'summary': {
                    'total_tables': len(all_tables),
                    'total_columns': sum(len(table.columns) for table in all_tables.values()),
                    'total_rows': sum(table.row_count for table in all_tables.values()),
                    'total_size_mb': sum(table.table_size_mb for table in all_tables.values())
                },
                'tables': {},
                'relationships': {}
            }
            
            # Documentation des tables
            for table_name, table_info in all_tables.items():
                documentation['tables'][table_name] = {
                    'row_count': table_info.row_count,
                    'size_mb': table_info.table_size_mb,
                    'comment': table_info.comment,
                    'columns': [
                        {
                            'name': col.name,
                            'type': col.data_type,
                            'nullable': col.is_nullable,
                            'primary_key': col.is_primary_key,
                            'foreign_key': col.is_foreign_key,
                            'comment': col.comment
                        }
                        for col in table_info.columns
                    ]
                }
                
                # Relations
                relationships = self.find_related_tables(table_name, schema_name)
                documentation['relationships'][table_name] = relationships
            
            return documentation
            
        except Exception as e:
            logger.error(f"Erreur lors de l'export de documentation: {e}")
            return {}
    
    # Méthodes privées utilitaires
    
    def _get_tables_list(self, schema_name: str) -> List[str]:
        """Récupère la liste des tables d'un schéma"""
        sql = """
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = %s 
        AND table_type = 'BASE TABLE'
        ORDER BY table_name
        """
        
        result = self.db_manager.execute_query(sql, (schema_name,), fetch_results=True)
        return [row['table_name'] for row in result]
    
    def _get_table_columns(self, table_name: str, schema_name: str) -> List[ColumnInfo]:
        """Récupère les informations des colonnes d'une table"""
        sql = """
        SELECT 
            c.column_name,
            c.data_type,
            c.is_nullable,
            c.column_default,
            c.character_maximum_length,
            CASE WHEN pk.column_name IS NOT NULL THEN true ELSE false END AS is_primary_key,
            CASE WHEN fk.column_name IS NOT NULL THEN true ELSE false END AS is_foreign_key,
            fk.referenced_table,
            fk.referenced_column,
            col_desc.description AS comment
        FROM information_schema.columns c
        LEFT JOIN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = %s 
            AND tc.table_schema = %s
            AND tc.constraint_type = 'PRIMARY KEY'
        ) pk ON c.column_name = pk.column_name
        LEFT JOIN (
            SELECT 
                kcu.column_name,
                ccu.table_name AS referenced_table,
                ccu.column_name AS referenced_column
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu 
                ON ccu.constraint_name = tc.constraint_name
            WHERE tc.table_name = %s 
            AND tc.table_schema = %s
            AND tc.constraint_type = 'FOREIGN KEY'
        ) fk ON c.column_name = fk.column_name
        LEFT JOIN (
            SELECT 
                a.attname AS column_name,
                d.description
            FROM pg_attribute a
            LEFT JOIN pg_description d ON a.attrelid = d.objoid AND a.attnum = d.objsubid
            WHERE a.attrelid = %s::regclass
            AND a.attnum > 0 
            AND NOT a.attisdropped
        ) col_desc ON c.column_name = col_desc.column_name
        WHERE c.table_name = %s 
        AND c.table_schema = %s
        ORDER BY c.ordinal_position
        """
        
        full_table_name = f"{schema_name}.{table_name}"
        result = self.db_manager.execute_query(
            sql, 
            (table_name, schema_name, table_name, schema_name, full_table_name, table_name, schema_name), 
            fetch_results=True
        )
        
        columns = []
        for row in result:
            column = ColumnInfo(
                name=row['column_name'],
                data_type=row['data_type'],
                is_nullable=row['is_nullable'] == 'YES',
                default_value=row['column_default'],
                max_length=row['character_maximum_length'],
                is_primary_key=row['is_primary_key'],
                is_foreign_key=row['is_foreign_key'],
                referenced_table=row.get('referenced_table'),
                referenced_column=row.get('referenced_column'),
                comment=row.get('comment')
            )
            columns.append(column)
        
        return columns
    
    def _get_table_row_count(self, table_name: str, schema_name: str) -> int:
        """Récupère le nombre de lignes d'une table"""
        try:
            sql = f"SELECT COUNT(*) as row_count FROM {schema_name}.{table_name}"
            result = self.db_manager.execute_query(sql, fetch_results=True)
            return result[0]['row_count'] if result else 0
        except:
            return 0
    
    def _get_table_size(self, table_name: str, schema_name: str) -> float:
        """Récupère la taille d'une table en MB"""
        try:
            sql = """
            SELECT 
                ROUND(pg_total_relation_size(%s::regclass) / 1024.0 / 1024.0, 2) AS size_mb
            """
            full_table_name = f"{schema_name}.{table_name}"
            result = self.db_manager.execute_query(sql, (full_table_name,), fetch_results=True)
            return float(result[0]['size_mb']) if result else 0.0
        except:
            return 0.0
    
    def _get_table_comment(self, table_name: str, schema_name: str) -> Optional[str]:
        """Récupère le commentaire d'une table"""
        try:
            sql = """
            SELECT obj_description(%s::regclass, 'pg_class') AS comment
            """
            full_table_name = f"{schema_name}.{table_name}"
            result = self.db_manager.execute_query(sql, (full_table_name,), fetch_results=True)
            return result[0]['comment'] if result and result[0]['comment'] else None
        except:
            return None
    
    def _get_table_indexes(self, table_name: str, schema_name: str) -> List[str]:
        """Récupère les index d'une table"""
        try:
            sql = """
            SELECT indexname 
            FROM pg_indexes 
            WHERE tablename = %s 
            AND schemaname = %s
            """
            result = self.db_manager.execute_query(sql, (table_name, schema_name), fetch_results=True)
            return [row['indexname'] for row in result]
        except:
            return []
    
    def _get_table_foreign_keys(self, table_name: str, schema_name: str) -> List[Dict[str, str]]:
        """Récupère les clés étrangères d'une table"""
        try:
            sql = """
            SELECT 
                kcu.column_name,
                ccu.table_name AS referenced_table,
                ccu.column_name AS referenced_column
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu 
                ON ccu.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_name = %s
            AND tc.table_schema = %s
            """
            
            result = self.db_manager.execute_query(sql, (table_name, schema_name), fetch_results=True)
            return [
                {
                    'column': row['column_name'],
                    'referenced_table': row['referenced_table'],
                    'referenced_column': row['referenced_column']
                }
                for row in result
            ]
        except:
            return []
    
    def _find_direct_join(self, table1: str, table2: str, schema_name: str) -> Optional[str]:
        """Trouve un JOIN direct entre deux tables"""
        # Recherche FK de table1 vers table2
        table1_info = self.analyze_table(table1, schema_name)
        if table1_info:
            for fk in table1_info.foreign_keys:
                if fk['referenced_table'] == table2:
                    return f"LEFT JOIN {table2} ON {table1}.{fk['column']} = {table2}.{fk['referenced_column']}"
        
        # Recherche FK de table2 vers table1
        table2_info = self.analyze_table(table2, schema_name)
        if table2_info:
            for fk in table2_info.foreign_keys:
                if fk['referenced_table'] == table1:
                    return f"LEFT JOIN {table2} ON {table1}.{fk['referenced_column']} = {table2}.{fk['column']}"
        
        return None
    
    def _find_indirect_joins(self, table1: str, table2: str, schema_name: str) -> List[str]:
        """Trouve des JOINs indirects via une table de liaison"""
        # Implémentation simplifiée - à développer selon les besoins
        return []
    
    def _is_numeric_type(self, data_type: str) -> bool:
        """Vérifie si un type de données est numérique"""
        numeric_types = ['integer', 'bigint', 'smallint', 'decimal', 'numeric', 'real', 'double precision', 'money']
        return data_type.lower() in numeric_types
    
    def _is_text_type(self, data_type: str) -> bool:
        """Vérifie si un type de données est textuel"""
        text_types = ['character varying', 'varchar', 'character', 'char', 'text']
        return any(text_type in data_type.lower() for text_type in text_types)
    
    def _is_date_type(self, data_type: str) -> bool:
        """Vérifie si un type de données est temporel"""
        date_types = ['date', 'timestamp', 'time', 'interval']
        return any(date_type in data_type.lower() for date_type in date_types)
    
    def _analyze_column_quality(self, table_name: str, column: ColumnInfo, schema_name: str) -> Dict[str, Any]:
        """Analyse la qualité d'une colonne"""
        try:
            analysis = {
                'null_count': 0,
                'null_percentage': 0,
                'unique_count': 0,
                'unique_percentage': 0,
                'score': None
            }
            
            # Comptage des valeurs NULL
            null_sql = f"SELECT COUNT(*) as null_count FROM {schema_name}.{table_name} WHERE {column.name} IS NULL"
            null_result = self.db_manager.execute_query(null_sql, fetch_results=True)
            if null_result:
                analysis['null_count'] = null_result[0]['null_count']
            
            # Comptage des valeurs uniques
            unique_sql = f"SELECT COUNT(DISTINCT {column.name}) as unique_count FROM {schema_name}.{table_name}"
            unique_result = self.db_manager.execute_query(unique_sql, fetch_results=True)
            if unique_result:
                analysis['unique_count'] = unique_result[0]['unique_count']
            
            # Calcul des pourcentages
            total_rows = self._get_table_row_count(table_name, schema_name)
            if total_rows > 0:
                analysis['null_percentage'] = round((analysis['null_count'] / total_rows) * 100, 2)
                analysis['unique_percentage'] = round((analysis['unique_count'] / total_rows) * 100, 2)
            
            # Score de qualité (0-100)
            score = 100
            if column.is_nullable and analysis['null_percentage'] > 50:
                score -= 30
            elif not column.is_nullable and analysis['null_count'] > 0:
                score -= 50
            
            if column.is_primary_key and analysis['unique_percentage'] < 100:
                score -= 40
            
            analysis['score'] = max(0, score)
            
            return analysis
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de qualité de la colonne {column.name}: {e}")
            return {'null_count': 0, 'null_percentage': 0, 'unique_count': 0, 'unique_percentage': 0, 'score': None}
    
    def clear_cache(self):
        """Vide le cache"""
        self._tables_cache.clear()
        self._relationships_cache.clear()
        logger.info("Cache de l'analyseur de schéma vidé")
