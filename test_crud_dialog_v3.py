#!/usr/bin/env python3
"""
Test Dialog CRUD V3 - Création de vues personnalisées avec agrégations et relecture
Interface avancée pour utilisateurs non-techniques ("moldus")
Nouvelles fonctionnalités: SUM, AVG, MAX, MIN, groupement temporel, filtres, RELECTURE

Auteur: Assistant IA
Date: 2025-07-17
Version: 3.0
"""

import sys
import os
from PySide6.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QHBoxLayout, QGridLayout,
    QLabel, QComboBox, QPushButton, QGroupBox, QTextEdit, QSplitter,
    QListWidget, QListWidgetItem, QFrame, QScrollArea, QWidget,
    QCheckBox, QSpinBox, QDateEdit, QLineEdit, QTabWidget, QMessageBox
)
from PySide6.QtCore import Qt, QSize, Signal, QDate
from PySide6.QtGui import QFont, QIcon
import json
from datetime import datetime, timedelta

# Imports pour l'accès à la base de données
try:
    from sqlalchemy import create_engine, text, inspect
    from sqlalchemy.exc import SQLAlchemyError
    import pandas as pd
    DB_AVAILABLE = True
except ImportError:
    DB_AVAILABLE = False
    print("⚠️ Modules de base de données non disponibles. Fonctionnalité limitée.")

class DatabaseHelper:
    """Helper simplifié pour l'accès à la base de données (inspiré de DatabaseManager)"""
    
    def __init__(self):
        self.engine = None
        self.connected = False
        
        if DB_AVAILABLE:
            self._try_connect()
    
    def _try_connect(self):
        """Tentative de connexion à la base de données"""
        try:
            # Configuration de connexion par défaut (peut être adaptée)
            # Note: Cette configuration doit être adaptée selon votre environnement
            connection_string = "postgresql://user:password@localhost:5432/gmao_db"
            self.engine = create_engine(connection_string, encoding='utf-8')
            
            # Test de connexion
            with self.engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            
            self.connected = True
            print("✅ Connexion à la base de données réussie")
            
        except Exception as e:
            # Gestion plus robuste des erreurs d'encodage
            error_msg = str(e).encode('utf-8', errors='replace').decode('utf-8')
            print(f"⚠️ Connexion à la base de données échouée: {error_msg}")
            print("📝 Mode hors ligne activé - utilisation des données de test")
            self.connected = False
    
    def get_available_views(self):
        """Récupère la liste des vues disponibles"""
        if not self.connected:
            return []
        
        try:
            inspector = inspect(self.engine)
            all_views = inspector.get_view_names()
            
            # Filtrer les vues métier
            business_views = []
            for view in all_views:
                if (view.startswith(('vw_', 'view_', 'vue_')) or 
                    'maintenance' in view.lower() or 
                    'machine' in view.lower() or 
                    'technicien' in view.lower()):
                    
                    # Récupérer les colonnes
                    columns = inspector.get_columns(view)
                    business_views.append({
                        'name': view,
                        'column_count': len(columns),
                        'columns': [col['name'] for col in columns[:5]]
                    })
            
            return business_views
            
        except Exception as e:
            print(f"❌ Erreur lors de la récupération des vues: {e}")
            return []
    
    def create_view(self, view_name, sql_query):
        """Crée une vue dans la base de données"""
        if not self.connected:
            return False, "Pas de connexion à la base de données"
        
        try:
            with self.engine.connect() as conn:
                # Supprimer la vue si elle existe déjà
                drop_sql = f"DROP VIEW IF EXISTS {view_name};"
                conn.execute(text(drop_sql))
                
                # Créer la nouvelle vue
                conn.execute(text(sql_query))
                conn.commit()
            
            return True, f"Vue '{view_name}' créée avec succès"
            
        except Exception as e:
            return False, f"Erreur lors de la création de la vue: {e}"
    
    def delete_view(self, view_name):
        """Supprime une vue de la base de données"""
        if not self.connected:
            return False, "Pas de connexion à la base de données"
        
        try:
            with self.engine.connect() as conn:
                drop_sql = f"DROP VIEW IF EXISTS {view_name};"
                conn.execute(text(drop_sql))
                conn.commit()
            
            return True, f"Vue '{view_name}' supprimée avec succès"
            
        except Exception as e:
            return False, f"Erreur lors de la suppression de la vue: {e}"
    
    def test_view_query(self, sql_query):
        """Teste une requête SQL sans l'exécuter"""
        if not self.connected:
            return False, "Pas de connexion à la base de données"
        
        try:
            with self.engine.connect() as conn:
                # Test avec EXPLAIN pour valider la syntaxe
                test_sql = f"EXPLAIN {sql_query}"
                conn.execute(text(test_sql))
            
            return True, "Requête SQL valide"
            
        except Exception as e:
            return False, f"Erreur dans la requête SQL: {e}"
    
    def get_view_data(self, view_name, limit=100):
        """Récupère les données d'une vue"""
        if not self.connected:
            return None, "Pas de connexion à la base de données"
        
        try:
            query = f"SELECT * FROM {view_name} LIMIT {limit}"
            df = pd.read_sql(query, self.engine)
            return df, f"{len(df)} lignes récupérées"
            
        except Exception as e:
            return None, f"Erreur lors de la récupération des données: {e}"

class AdvancedViewCreatorDialog(QDialog):
    """Dialog avancé pour créer des vues personnalisées avec agrégations"""
    
    view_created = Signal(dict)  # Signal émis quand une vue est créée
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("🔧 Créateur de Vues Avancées - Version 3")
        self.setMinimumSize(1200, 800)
        
        # Données des vues créées
        self.created_views = []
        
        # Données simulées des tables GMAO
        self.tables_data = self._load_sample_tables()
        
        # Variables pour V3 (inclut V2 + relecture)
        self.selected_table1 = None
        self.selected_table2 = None
        self.selected_x_field = None
        self.selected_y_fields = []
        self.aggregation_functions = {}
        self.grouping_period = None
        self.filters = {}
        
        # Nouvelles variables pour la relecture (V3)
        self.review_comments = ""
        self.review_status = "draft"  # draft, reviewed, approved
        self.reviewer_name = ""
        self.review_date = None
        
        # Initialiser l'helper de base de données AVANT _setup_ui
        self.db_helper = DatabaseHelper()
        
        self._setup_ui()
        self._connect_signals()
        
        # Ajouter des vues de test pour démonstration si pas de DB
        if not self.db_helper.connected:
            self._add_sample_views()
        
        # Initialiser la liste des vues dans l'onglet relecture
        self._refresh_views_list()
        
    def _load_sample_tables(self):
        """Charge les données des tables GMAO (simulées)"""
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
                    "tarif_horaire": {"type": "numeric", "display": "💰 Tarif Horaire", "aggregable": True},
                    "date_embauche": {"type": "date", "display": "📅 Date Embauche", "aggregable": False},
                    "statut": {"type": "text", "display": "Statut", "aggregable": False}
                }
            },
            "piece": {
                "display_name": "🔩 Pièce",
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
    
    def _add_sample_views(self):
        """Ajoute quelques vues de test pour démonstration"""
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
    
    def _setup_ui(self):
        """Configuration de l'interface utilisateur"""
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("🚀 Créateur de Vue Personnalisée - Version 3.0")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(title_label)
        
        # Tabs principal
        self.tabs = QTabWidget()
        
        # Tab 1: Configuration de base
        basic_tab = self._create_basic_tab()
        self.tabs.addTab(basic_tab, "📊 Configuration de Base")
        
        # Tab 2: Agrégations
        aggregation_tab = self._create_aggregation_tab()
        self.tabs.addTab(aggregation_tab, "🧮 Agrégations")
        
        # Tab 3: Filtres
        filters_tab = self._create_filters_tab()
        self.tabs.addTab(filters_tab, "🔍 Filtres")
        
        # Tab 4: Prévisualisation
        preview_tab = self._create_preview_tab()
        self.tabs.addTab(preview_tab, "👀 Prévisualisation")
        
        # Tab 5: Relecture (nouveau pour V3)
        review_tab = self._create_review_tab()
        self.tabs.addTab(review_tab, "📝 Relecture")
        
        layout.addWidget(self.tabs)
        
        # Boutons d'action
        buttons_layout = QHBoxLayout()
        
        self.preview_btn = QPushButton("🔍 Générer Prévisualisation")
        self.preview_btn.setEnabled(False)
        buttons_layout.addWidget(self.preview_btn)
        
        self.save_btn = QPushButton("💾 Créer la Vue")
        self.save_btn.setEnabled(False)
        buttons_layout.addWidget(self.save_btn)
        
        buttons_layout.addStretch()
        
        cancel_btn = QPushButton("❌ Annuler")
        cancel_btn.clicked.connect(self.reject)
        buttons_layout.addWidget(cancel_btn)
        
        layout.addLayout(buttons_layout)
        self.setLayout(layout)
    
    def _create_basic_tab(self):
        """Crée l'onglet de configuration de base"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Étape 1: Sélection des tables
        step1_group = QGroupBox("📝 Étape 1: Choisir les Tables")
        step1_layout = QVBoxLayout()
        
        # Table principale
        main_table_layout = QHBoxLayout()
        main_table_layout.addWidget(QLabel("Table principale:"))
        self.main_table_combo = QComboBox()
        self.main_table_combo.addItem("-- Sélectionner --", None)
        for table_name, table_info in self.tables_data.items():
            self.main_table_combo.addItem(table_info["display_name"], table_name)
        main_table_layout.addWidget(self.main_table_combo)
        step1_layout.addLayout(main_table_layout)
        
        # Table secondaire (optionnelle)
        secondary_table_layout = QHBoxLayout()
        secondary_table_layout.addWidget(QLabel("Table secondaire:"))
        self.secondary_table_combo = QComboBox()
        self.secondary_table_combo.addItem("-- Aucune (optionnel) --", None)
        self.secondary_table_combo.setEnabled(False)
        secondary_table_layout.addWidget(self.secondary_table_combo)
        step1_layout.addLayout(secondary_table_layout)
        
        step1_group.setLayout(step1_layout)
        layout.addWidget(step1_group)
        
        # Étape 2: Sélection des champs
        step2_group = QGroupBox("📊 Étape 2: Choisir les Champs")
        step2_layout = QVBoxLayout()
        
        # Champ X (axe horizontal)
        x_layout = QHBoxLayout()
        x_layout.addWidget(QLabel("Axe X (horizontal):"))
        self.x_field_combo = QComboBox()
        self.x_field_combo.addItem("-- Sélectionner d'abord une table --", None)
        self.x_field_combo.setEnabled(False)
        x_layout.addWidget(self.x_field_combo)
        step2_layout.addLayout(x_layout)
        
        # Groupement temporel (nouveau)
        grouping_layout = QHBoxLayout()
        grouping_layout.addWidget(QLabel("Groupement temporel:"))
        self.grouping_combo = QComboBox()
        self.grouping_combo.addItems([
            "-- Aucun groupement --",
            "📅 Par jour",
            "📅 Par semaine", 
            "📅 Par mois",
            "📅 Par trimestre",
            "📅 Par année"
        ])
        self.grouping_combo.setEnabled(False)
        grouping_layout.addWidget(self.grouping_combo)
        step2_layout.addLayout(grouping_layout)
        
        # Champs Y (axes verticaux)
        y_layout = QVBoxLayout()
        y_layout.addWidget(QLabel("Axes Y (verticaux):"))
        
        # Y1
        y1_layout = QHBoxLayout()
        y1_layout.addWidget(QLabel("Y1:"))
        self.y1_field_combo = QComboBox()
        self.y1_field_combo.addItem("-- Sélectionner d'abord une table --", None)
        self.y1_field_combo.setEnabled(False)
        y1_layout.addWidget(self.y1_field_combo)
        y_layout.addLayout(y1_layout)
        
        # Y2
        y2_layout = QHBoxLayout()
        y2_layout.addWidget(QLabel("Y2:"))
        self.y2_field_combo = QComboBox()
        self.y2_field_combo.addItem("-- Optionnel --", None)
        self.y2_field_combo.setEnabled(False)
        y2_layout.addWidget(self.y2_field_combo)
        y_layout.addLayout(y2_layout)
        
        # Y3
        y3_layout = QHBoxLayout()
        y3_layout.addWidget(QLabel("Y3:"))
        self.y3_field_combo = QComboBox()
        self.y3_field_combo.addItem("-- Optionnel --", None)
        self.y3_field_combo.setEnabled(False)
        y3_layout.addWidget(self.y3_field_combo)
        y_layout.addLayout(y3_layout)
        
        step2_layout.addLayout(y_layout)
        step2_group.setLayout(step2_layout)
        layout.addWidget(step2_group)
        
        # Étape 3: Paramètres de la vue
        step3_group = QGroupBox("⚙️ Étape 3: Paramètres de la Vue")
        step3_layout = QVBoxLayout()
        
        # Nom de la vue
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("Nom de la vue:"))
        self.view_name_combo = QComboBox()
        self.view_name_combo.setEditable(True)
        self.view_name_combo.addItems([
            "vue_maintenance_couts_agrege",
            "vue_machines_performance_mensuelle",
            "vue_techniciens_activite_hebdo",
            "vue_pieces_consommation_quotidienne"
        ])
        name_layout.addWidget(self.view_name_combo)
        step3_layout.addLayout(name_layout)
        
        step3_group.setLayout(step3_layout)
        layout.addWidget(step3_group)
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_aggregation_tab(self):
        """Crée l'onglet des agrégations"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Informations
        info_label = QLabel("🧮 Configurez les fonctions d'agrégation pour chaque champ Y")
        info_label.setStyleSheet("font-weight: bold; color: #0066cc; padding: 10px;")
        layout.addWidget(info_label)
        
        # Groupbox pour les agrégations
        agg_group = QGroupBox("📊 Fonctions d'Agrégation")
        agg_layout = QVBoxLayout()
        
        # Y1 Agrégation
        y1_agg_layout = QHBoxLayout()
        y1_agg_layout.addWidget(QLabel("Y1 - Fonction:"))
        self.y1_agg_combo = QComboBox()
        self.y1_agg_combo.addItems([
            "SUM - Somme totale",
            "AVG - Moyenne",
            "MAX - Valeur maximale",
            "MIN - Valeur minimale",
            "COUNT - Nombre d'occurrences"
        ])
        self.y1_agg_combo.setEnabled(False)
        y1_agg_layout.addWidget(self.y1_agg_combo)
        agg_layout.addLayout(y1_agg_layout)
        
        # Y2 Agrégation
        y2_agg_layout = QHBoxLayout()
        y2_agg_layout.addWidget(QLabel("Y2 - Fonction:"))
        self.y2_agg_combo = QComboBox()
        self.y2_agg_combo.addItems([
            "SUM - Somme totale",
            "AVG - Moyenne",
            "MAX - Valeur maximale",
            "MIN - Valeur minimale",
            "COUNT - Nombre d'occurrences"
        ])
        self.y2_agg_combo.setEnabled(False)
        y2_agg_layout.addWidget(self.y2_agg_combo)
        agg_layout.addLayout(y2_agg_layout)
        
        # Y3 Agrégation
        y3_agg_layout = QHBoxLayout()
        y3_agg_layout.addWidget(QLabel("Y3 - Fonction:"))
        self.y3_agg_combo = QComboBox()
        self.y3_agg_combo.addItems([
            "SUM - Somme totale",
            "AVG - Moyenne",
            "MAX - Valeur maximale",
            "MIN - Valeur minimale",
            "COUNT - Nombre d'occurrences"
        ])
        self.y3_agg_combo.setEnabled(False)
        y3_agg_layout.addWidget(self.y3_agg_combo)
        agg_layout.addLayout(y3_agg_layout)
        
        agg_group.setLayout(agg_layout)
        layout.addWidget(agg_group)
        
        # Calculs dérivés
        derived_group = QGroupBox("📈 Calculs Dérivés (Optionnel)")
        derived_layout = QVBoxLayout()
        
        # Pourcentage d'évolution
        self.calc_evolution_check = QCheckBox("📊 Calculer l'évolution en pourcentage")
        derived_layout.addWidget(self.calc_evolution_check)
        
        # Ratio entre Y1 et Y2
        self.calc_ratio_check = QCheckBox("📊 Calculer le ratio Y1/Y2")
        derived_layout.addWidget(self.calc_ratio_check)
        
        # Moyenne mobile
        mobile_layout = QHBoxLayout()
        self.calc_mobile_check = QCheckBox("📊 Moyenne mobile sur")
        mobile_layout.addWidget(self.calc_mobile_check)
        self.mobile_period_spin = QSpinBox()
        self.mobile_period_spin.setRange(2, 30)
        self.mobile_period_spin.setValue(7)
        self.mobile_period_spin.setEnabled(False)
        mobile_layout.addWidget(self.mobile_period_spin)
        mobile_layout.addWidget(QLabel("périodes"))
        derived_layout.addLayout(mobile_layout)
        
        derived_group.setLayout(derived_layout)
        layout.addWidget(derived_group)
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_filters_tab(self):
        """Crée l'onglet des filtres"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Informations
        info_label = QLabel("🔍 Définissez des filtres pour affiner les données")
        info_label.setStyleSheet("font-weight: bold; color: #0066cc; padding: 10px;")
        layout.addWidget(info_label)
        
        # Filtre par dates
        date_group = QGroupBox("📅 Filtres par Date")
        date_layout = QVBoxLayout()
        
        # Activer filtre par date
        self.enable_date_filter_check = QCheckBox("Activer le filtrage par date")
        date_layout.addWidget(self.enable_date_filter_check)
        
        # Plage de dates
        date_range_layout = QHBoxLayout()
        date_range_layout.addWidget(QLabel("Du:"))
        self.date_from_edit = QDateEdit()
        self.date_from_edit.setDate(QDate.currentDate().addDays(-30))
        self.date_from_edit.setEnabled(False)
        date_range_layout.addWidget(self.date_from_edit)
        
        date_range_layout.addWidget(QLabel("Au:"))
        self.date_to_edit = QDateEdit()
        self.date_to_edit.setDate(QDate.currentDate())
        self.date_to_edit.setEnabled(False)
        date_range_layout.addWidget(self.date_to_edit)
        
        date_layout.addLayout(date_range_layout)
        date_group.setLayout(date_layout)
        layout.addWidget(date_group)
        
        # Filtre par valeurs
        value_group = QGroupBox("📊 Filtres par Valeur")
        value_layout = QVBoxLayout()
        
        # Seuil minimum
        min_layout = QHBoxLayout()
        self.enable_min_filter_check = QCheckBox("Valeur minimale:")
        min_layout.addWidget(self.enable_min_filter_check)
        self.min_value_edit = QLineEdit()
        self.min_value_edit.setPlaceholderText("0")
        self.min_value_edit.setEnabled(False)
        min_layout.addWidget(self.min_value_edit)
        value_layout.addLayout(min_layout)
        
        # Seuil maximum
        max_layout = QHBoxLayout()
        self.enable_max_filter_check = QCheckBox("Valeur maximale:")
        max_layout.addWidget(self.enable_max_filter_check)
        self.max_value_edit = QLineEdit()
        self.max_value_edit.setPlaceholderText("999999")
        self.max_value_edit.setEnabled(False)
        max_layout.addWidget(self.max_value_edit)
        value_layout.addLayout(max_layout)
        
        value_group.setLayout(value_layout)
        layout.addWidget(value_group)
        
        # Filtre par texte
        text_group = QGroupBox("📝 Filtres par Texte")
        text_layout = QVBoxLayout()
        
        # Contient
        contains_layout = QHBoxLayout()
        self.enable_contains_filter_check = QCheckBox("Contient le texte:")
        contains_layout.addWidget(self.enable_contains_filter_check)
        self.contains_text_edit = QLineEdit()
        self.contains_text_edit.setPlaceholderText("Tapez le texte à rechercher")
        self.contains_text_edit.setEnabled(False)
        contains_layout.addWidget(self.contains_text_edit)
        text_layout.addLayout(contains_layout)
        
        text_group.setLayout(text_layout)
        layout.addWidget(text_group)
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_preview_tab(self):
        """Crée l'onglet de prévisualisation"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("👀 Prévisualisation SQL Avancée")
        title_font = QFont()
        title_font.setPointSize(14)
        title_font.setBold(True)
        title_label.setFont(title_font)
        layout.addWidget(title_label)
        
        # Zone de texte pour le SQL généré
        self.sql_preview = QTextEdit()
        self.sql_preview.setReadOnly(True)
        self.sql_preview.setPlainText("-- Configurez les paramètres dans les autres onglets pour voir la requête SQL générée")
        
        # Style pour ressembler à un éditeur de code
        sql_font = QFont("Courier New", 10)
        self.sql_preview.setFont(sql_font)
        self.sql_preview.setStyleSheet("""
            QTextEdit {
                background-color: #2b2b2b;
                color: #ffffff;
                border: 1px solid #555555;
                padding: 10px;
            }
        """)
        
        layout.addWidget(self.sql_preview)
        
        # Informations sur la vue
        info_group = QGroupBox("📋 Informations de la Vue")
        info_layout = QVBoxLayout()
        
        self.info_label = QLabel("Configurez d'abord les paramètres...")
        self.info_label.setWordWrap(True)
        info_layout.addWidget(self.info_label)
        
        info_group.setLayout(info_layout)
        layout.addWidget(info_group)
        
        widget.setLayout(layout)
        return widget
    
    def _create_review_tab(self):
        """Crée l'onglet de relecture des vues"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("📝 Relecture des Vues Créées")
        title_font = QFont()
        title_font.setPointSize(14)
        title_font.setBold(True)
        title_label.setFont(title_font)
        layout.addWidget(title_label)
        
        # Section: Sélection des vues créées
        views_group = QGroupBox("📋 Vues Disponibles pour Relecture")
        views_layout = QVBoxLayout()
        
        # Sélection des vues créées (inspiré de main_window.py)
        views_selection_layout = QHBoxLayout()
        views_selection_layout.addWidget(QLabel("📋 Sélectionner une vue :"))
        self.views_combo = QComboBox()
        self.views_combo.setMinimumWidth(350)
        self.views_combo.setToolTip("Sélectionner la vue à relire")
        views_selection_layout.addWidget(self.views_combo)
        
        # Bouton pour rafraîchir la liste
        self.btn_refresh_views = QPushButton("♻️ Actualiser")
        self.btn_refresh_views.setMaximumWidth(100)
        self.btn_refresh_views.setToolTip("Actualiser la liste des vues")
        self.btn_refresh_views.clicked.connect(self._refresh_views_list)
        views_selection_layout.addWidget(self.btn_refresh_views)
        
        # Boutons pour gérer les vues de base de données
        if self.db_helper.connected:
            self.btn_preview_view = QPushButton("👁️ Aperçu")
            self.btn_preview_view.setMaximumWidth(100)
            self.btn_preview_view.setToolTip("Prévisualiser les données de la vue")
            self.btn_preview_view.clicked.connect(self._preview_view_data)
            views_selection_layout.addWidget(self.btn_preview_view)
            
            self.btn_delete_view = QPushButton("🗑️ Supprimer")
            self.btn_delete_view.setMaximumWidth(100)
            self.btn_delete_view.setToolTip("Supprimer la vue de la base de données")
            self.btn_delete_view.clicked.connect(self._delete_view_from_db)
            views_selection_layout.addWidget(self.btn_delete_view)
        
        views_selection_layout.addStretch()
        views_layout.addLayout(views_selection_layout)
        
        # Compteur de vues
        self.lbl_view_count = QLabel("0 vues")
        self.lbl_view_count.setStyleSheet("color: #666666; font-style: italic;")
        views_layout.addWidget(self.lbl_view_count)
        
        views_group.setLayout(views_layout)
        layout.addWidget(views_group)
        
        # Section: Détails de la vue sélectionnée
        details_group = QGroupBox("🔍 Détails de la Vue Sélectionnée")
        details_layout = QVBoxLayout()
        
        self.view_details_text = QTextEdit()
        self.view_details_text.setReadOnly(True)
        self.view_details_text.setMaximumHeight(200)
        self.view_details_text.setPlainText("Sélectionnez une vue pour voir ses détails...")
        details_layout.addWidget(self.view_details_text)
        
        details_group.setLayout(details_layout)
        layout.addWidget(details_group)
        
        # Section: Relecture et commentaires
        review_group = QGroupBox("📝 Relecture et Commentaires")
        review_layout = QVBoxLayout()
        
        # Nom du relecteur
        reviewer_layout = QHBoxLayout()
        reviewer_layout.addWidget(QLabel("Relecteur:"))
        self.reviewer_name_edit = QLineEdit()
        self.reviewer_name_edit.setPlaceholderText("Votre nom...")
        reviewer_layout.addWidget(self.reviewer_name_edit)
        review_layout.addLayout(reviewer_layout)
        
        # Statut de relecture
        status_layout = QHBoxLayout()
        status_layout.addWidget(QLabel("Statut:"))
        self.review_status_combo = QComboBox()
        self.review_status_combo.addItems([
            "📝 Brouillon",
            "👀 En cours de relecture", 
            "✅ Approuvé",
            "❌ Rejeté",
            "⚠️ Nécessite des modifications"
        ])
        status_layout.addWidget(self.review_status_combo)
        review_layout.addLayout(status_layout)
        
        # Zone de commentaires
        review_layout.addWidget(QLabel("Commentaires de relecture:"))
        self.review_comments_edit = QTextEdit()
        self.review_comments_edit.setPlaceholderText(
            "Ajoutez vos commentaires sur la vue:\n"
            "- Pertinence des champs sélectionnés\n"
            "- Cohérence des agrégations\n"
            "- Utilité des filtres\n"
            "- Suggestions d'amélioration\n"
            "- Validation métier..."
        )
        self.review_comments_edit.setMaximumHeight(150)
        review_layout.addWidget(self.review_comments_edit)
        
        # Boutons d'action pour la relecture
        review_buttons_layout = QHBoxLayout()
        
        self.save_review_btn = QPushButton("💾 Enregistrer la Relecture")
        self.save_review_btn.clicked.connect(self._save_review)
        review_buttons_layout.addWidget(self.save_review_btn)
        
        self.export_review_btn = QPushButton("📤 Exporter le Rapport")
        self.export_review_btn.clicked.connect(self._export_review_report)
        review_buttons_layout.addWidget(self.export_review_btn)
        
        review_buttons_layout.addStretch()
        review_layout.addLayout(review_buttons_layout)
        
        review_group.setLayout(review_layout)
        layout.addWidget(review_group)
        
        # Section: Historique des relectures
        history_group = QGroupBox("📚 Historique des Relectures")
        history_layout = QVBoxLayout()
        
        self.review_history_text = QTextEdit()
        self.review_history_text.setReadOnly(True)
        self.review_history_text.setMaximumHeight(100)
        self.review_history_text.setPlainText("Aucun historique disponible...")
        history_layout.addWidget(self.review_history_text)
        
        history_group.setLayout(history_layout)
        layout.addWidget(history_group)
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _connect_signals(self):
        """Connexion des signaux"""
        self.main_table_combo.currentIndexChanged.connect(self._on_main_table_changed)
        self.secondary_table_combo.currentIndexChanged.connect(self._on_secondary_table_changed)
        self.x_field_combo.currentIndexChanged.connect(self._on_field_changed)
        self.y1_field_combo.currentIndexChanged.connect(self._on_field_changed)
        self.y2_field_combo.currentIndexChanged.connect(self._on_field_changed)
        self.y3_field_combo.currentIndexChanged.connect(self._on_field_changed)
        self.grouping_combo.currentIndexChanged.connect(self._on_field_changed)
        
        # Signaux pour les agrégations
        self.y1_agg_combo.currentIndexChanged.connect(self._on_field_changed)
        self.y2_agg_combo.currentIndexChanged.connect(self._on_field_changed)
        self.y3_agg_combo.currentIndexChanged.connect(self._on_field_changed)
        
        # Signaux pour les filtres
        self.enable_date_filter_check.toggled.connect(self._on_filter_changed)
        self.enable_min_filter_check.toggled.connect(self._on_filter_changed)
        self.enable_max_filter_check.toggled.connect(self._on_filter_changed)
        self.enable_contains_filter_check.toggled.connect(self._on_filter_changed)
        self.calc_mobile_check.toggled.connect(self._on_calc_changed)
        
        self.preview_btn.clicked.connect(self._generate_preview)
        self.save_btn.clicked.connect(self._save_view)
        
        # Signaux pour la relecture (V3)
        self.views_combo.currentIndexChanged.connect(self._on_view_selected)
        self.reviewer_name_edit.textChanged.connect(self._on_review_data_changed)
        self.review_status_combo.currentTextChanged.connect(self._on_review_data_changed)
        self.review_comments_edit.textChanged.connect(self._on_review_data_changed)
    
    def _on_main_table_changed(self):
        """Gère le changement de table principale"""
        table_name = self.main_table_combo.currentData()
        
        if table_name:
            self.selected_table1 = table_name
            self._populate_field_combos(table_name)
            self._enable_secondary_table()
            self._validate_form()
        else:
            self.selected_table1 = None
            self._clear_field_combos()
            self._disable_secondary_table()
            self._validate_form()
    
    def _enable_secondary_table(self):
        """Active la sélection de table secondaire"""
        self.secondary_table_combo.setEnabled(True)
        self.secondary_table_combo.clear()
        self.secondary_table_combo.addItem("-- Aucune (optionnel) --", None)
        
        # Ajouter toutes les tables sauf la principale
        for table_name, table_info in self.tables_data.items():
            if table_name != self.selected_table1:
                self.secondary_table_combo.addItem(table_info["display_name"], table_name)
    
    def _disable_secondary_table(self):
        """Désactive la sélection de table secondaire"""
        self.secondary_table_combo.setEnabled(False)
        self.secondary_table_combo.clear()
        self.secondary_table_combo.addItem("-- Aucune (optionnel) --", None)
    
    def _on_secondary_table_changed(self):
        """Gère le changement de table secondaire"""
        table_name = self.secondary_table_combo.currentData()
        self.selected_table2 = table_name
        self._validate_form()
    
    def _populate_field_combos(self, table_name):
        """Remplit les combos de champs avec les champs de la table"""
        if table_name not in self.tables_data:
            return
        
        fields = self.tables_data[table_name]["fields"]
        
        # Remplir combo X (champs date/integer principalement)
        self.x_field_combo.clear()
        self.x_field_combo.addItem("-- Sélectionner --", None)
        for field_name, field_info in fields.items():
            if field_info["type"] in ["date", "integer"]:
                self.x_field_combo.addItem(field_info["display"], field_name)
        
        # Remplir combos Y (champs numériques)
        for combo in [self.y1_field_combo, self.y2_field_combo, self.y3_field_combo]:
            combo.clear()
            combo.addItem("-- Sélectionner --" if combo == self.y1_field_combo else "-- Optionnel --", None)
            for field_name, field_info in fields.items():
                if field_info["type"] in ["numeric", "integer"] and field_info.get("aggregable", False):
                    combo.addItem(field_info["display"], field_name)
        
        # Activer les combos
        self.x_field_combo.setEnabled(True)
        self.y1_field_combo.setEnabled(True)
        self.y2_field_combo.setEnabled(True)
        self.y3_field_combo.setEnabled(True)
        
        # Activer le groupement si champ date sélectionné
        self.grouping_combo.setEnabled(True)
        
        # Activer les agrégations
        self.y1_agg_combo.setEnabled(True)
        self.y2_agg_combo.setEnabled(True)
        self.y3_agg_combo.setEnabled(True)
    
    def _clear_field_combos(self):
        """Vide et désactive les combos de champs"""
        for combo in [self.x_field_combo, self.y1_field_combo, self.y2_field_combo, self.y3_field_combo]:
            combo.clear()
            combo.addItem("-- Sélectionner d'abord une table --", None)
            combo.setEnabled(False)
        
        self.grouping_combo.setEnabled(False)
        self.y1_agg_combo.setEnabled(False)
        self.y2_agg_combo.setEnabled(False)
        self.y3_agg_combo.setEnabled(False)
    
    def _on_field_changed(self):
        """Gère le changement de champ"""
        self._validate_form()
    
    def _on_filter_changed(self):
        """Gère le changement de filtre"""
        # Activer/désactiver les champs de filtres
        self.date_from_edit.setEnabled(self.enable_date_filter_check.isChecked())
        self.date_to_edit.setEnabled(self.enable_date_filter_check.isChecked())
        self.min_value_edit.setEnabled(self.enable_min_filter_check.isChecked())
        self.max_value_edit.setEnabled(self.enable_max_filter_check.isChecked())
        self.contains_text_edit.setEnabled(self.enable_contains_filter_check.isChecked())
        
        self._validate_form()
    
    def _on_calc_changed(self):
        """Gère le changement de calcul dérivé"""
        self.mobile_period_spin.setEnabled(self.calc_mobile_check.isChecked())
        self._validate_form()
    
    def _validate_form(self):
        """Valide le formulaire et active/désactive les boutons"""
        # Vérifier les champs obligatoires
        has_table = self.selected_table1 is not None
        has_x_field = self.x_field_combo.currentData() is not None
        has_y_field = self.y1_field_combo.currentData() is not None
        
        form_valid = has_table and has_x_field and has_y_field
        
        self.preview_btn.setEnabled(form_valid)
        self.save_btn.setEnabled(form_valid)
        
        if form_valid:
            self._generate_preview()
    
    def _generate_preview(self):
        """Génère la prévisualisation SQL avancée"""
        if not self.selected_table1:
            return
        
        table_name = self.selected_table1
        x_field = self.x_field_combo.currentData()
        y1_field = self.y1_field_combo.currentData()
        y2_field = self.y2_field_combo.currentData()
        y3_field = self.y3_field_combo.currentData()
        view_name = self.view_name_combo.currentText().strip()
        
        # Récupérer les fonctions d'agrégation
        y1_agg = self.y1_agg_combo.currentText().split(" - ")[0]
        y2_agg = self.y2_agg_combo.currentText().split(" - ")[0] if y2_field else None
        y3_agg = self.y3_agg_combo.currentText().split(" - ")[0] if y3_field else None
        
        # Groupement temporel
        grouping = self.grouping_combo.currentText()
        
        # Générer le SQL
        sql_lines = []
        sql_lines.append(f"-- Vue personnalisée avancée générée automatiquement")
        sql_lines.append(f"-- Table: {self.tables_data[table_name]['display_name']}")
        sql_lines.append(f"-- Axe X: {self.tables_data[table_name]['fields'][x_field]['display']}")
        sql_lines.append(f"-- Groupement: {grouping}")
        sql_lines.append("")
        sql_lines.append(f"CREATE OR REPLACE VIEW {view_name} AS")
        sql_lines.append("SELECT")
        
        # Générer le champ X avec groupement
        if "Par jour" in grouping:
            sql_lines.append(f"    DATE_TRUNC('day', {x_field}::timestamp) AS periode,")
        elif "Par semaine" in grouping:
            sql_lines.append(f"    DATE_TRUNC('week', {x_field}::timestamp) AS periode,")
        elif "Par mois" in grouping:
            sql_lines.append(f"    DATE_TRUNC('month', {x_field}::timestamp) AS periode,")
        elif "Par trimestre" in grouping:
            sql_lines.append(f"    DATE_TRUNC('quarter', {x_field}::timestamp) AS periode,")
        elif "Par année" in grouping:
            sql_lines.append(f"    DATE_TRUNC('year', {x_field}::timestamp) AS periode,")
        else:
            if self.tables_data[table_name]['fields'][x_field]['type'] == 'date':
                sql_lines.append(f"    {x_field}::date AS axe_x,")
            else:
                sql_lines.append(f"    {x_field} AS axe_x,")
        
        # Générer les champs Y avec agrégation
        y_fields = []
        if y1_field:
            y_fields.append((y1_field, y1_agg, self.tables_data[table_name]['fields'][y1_field]['display']))
        if y2_field:
            y_fields.append((y2_field, y2_agg, self.tables_data[table_name]['fields'][y2_field]['display']))
        if y3_field:
            y_fields.append((y3_field, y3_agg, self.tables_data[table_name]['fields'][y3_field]['display']))
        
        for i, (field, agg, display) in enumerate(y_fields):
            comma = "," if i < len(y_fields) - 1 else ""
            sql_lines.append(f"    {agg}({field}) AS {agg.lower()}_{field}{comma}")
        
        sql_lines.append(f"FROM {table_name}")
        
        # Ajouter les filtres
        where_conditions = []
        where_conditions.append(f"{x_field} IS NOT NULL")
        
        if self.enable_date_filter_check.isChecked():
            date_from = self.date_from_edit.date().toString("yyyy-MM-dd")
            date_to = self.date_to_edit.date().toString("yyyy-MM-dd")
            where_conditions.append(f"{x_field} BETWEEN '{date_from}' AND '{date_to}'")
        
        if self.enable_min_filter_check.isChecked() and self.min_value_edit.text():
            where_conditions.append(f"{y1_field} >= {self.min_value_edit.text()}")
        
        if self.enable_max_filter_check.isChecked() and self.max_value_edit.text():
            where_conditions.append(f"{y1_field} <= {self.max_value_edit.text()}")
        
        if where_conditions:
            sql_lines.append("WHERE " + " AND ".join(where_conditions))
        
        # Ajouter GROUP BY si nécessaire
        if "Par " in grouping:
            sql_lines.append("GROUP BY periode")
            sql_lines.append("ORDER BY periode DESC;")
        elif y_fields:
            if "Par " not in grouping:
                sql_lines.append(f"GROUP BY {x_field}")
            if self.tables_data[table_name]['fields'][x_field]['type'] == 'date':
                sql_lines.append(f"ORDER BY {x_field} DESC;")
            else:
                sql_lines.append(f"ORDER BY {x_field} DESC;")
        
        # Afficher le SQL
        sql_text = "\n".join(sql_lines)
        self.sql_preview.setPlainText(sql_text)
        
        # Mettre à jour les informations
        agg_info = []
        for field, agg, display in y_fields:
            agg_info.append(f"{agg}({display})")
        
        info_text = f"""
🎯 <b>Vue:</b> {view_name}
📊 <b>Table source:</b> {self.tables_data[table_name]['display_name']}
📈 <b>Axe X:</b> {self.tables_data[table_name]['fields'][x_field]['display']}
📊 <b>Groupement:</b> {grouping}
🧮 <b>Agrégations:</b> {', '.join(agg_info)}
🔍 <b>Filtres actifs:</b> {sum([
    self.enable_date_filter_check.isChecked(),
    self.enable_min_filter_check.isChecked(),
    self.enable_max_filter_check.isChecked(),
    self.enable_contains_filter_check.isChecked()
])}
        """.strip()
        self.info_label.setText(info_text)
    
    def _save_view(self):
        """Sauvegarde la vue créée"""
        view_data = {
            "name": self.view_name_combo.currentText().strip(),
            "main_table": self.selected_table1,
            "secondary_table": self.selected_table2,
            "x_field": self.x_field_combo.currentData(),
            "y_fields": [
                self.y1_field_combo.currentData(),
                self.y2_field_combo.currentData(),
                self.y3_field_combo.currentData()
            ],
            "aggregations": {
                "y1": self.y1_agg_combo.currentText().split(" - ")[0] if self.y1_field_combo.currentData() else None,
                "y2": self.y2_agg_combo.currentText().split(" - ")[0] if self.y2_field_combo.currentData() else None,
                "y3": self.y3_agg_combo.currentText().split(" - ")[0] if self.y3_field_combo.currentData() else None
            },
            "grouping": self.grouping_combo.currentText(),
            "filters": {
                "date_filter": self.enable_date_filter_check.isChecked(),
                "date_from": self.date_from_edit.date().toString("yyyy-MM-dd") if self.enable_date_filter_check.isChecked() else None,
                "date_to": self.date_to_edit.date().toString("yyyy-MM-dd") if self.enable_date_filter_check.isChecked() else None,
                "min_value": self.min_value_edit.text() if self.enable_min_filter_check.isChecked() else None,
                "max_value": self.max_value_edit.text() if self.enable_max_filter_check.isChecked() else None,
                "contains_text": self.contains_text_edit.text() if self.enable_contains_filter_check.isChecked() else None
            },
            "sql": self.sql_preview.toPlainText()
        }
        
        # Nettoyer les champs vides
        view_data["y_fields"] = [f for f in view_data["y_fields"] if f is not None]
        
        # Ajouter la vue à la liste pour relecture (V3)
        view_for_review = {
            "id": len(self.created_views) + 1,
            "name": view_data["name"],
            "created_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "data": view_data,
            "review_status": "📝 Brouillon",
            "reviewer": "",
            "review_comments": "",
            "review_date": None
        }
        self.created_views.append(view_for_review)
        
        # Rafraîchir la liste des vues dans l'onglet relecture
        self._refresh_views_list()
        
        self.view_created.emit(view_data)
        
        # Afficher un message de confirmation
        QMessageBox.information(
            self, 
            "Vue créée", 
            f"La vue '{view_data['name']}' a été créée avec succès !\n\n"
            f"Vous pouvez maintenant la relire dans l'onglet 'Relecture'."
        )
        
        # Basculer vers l'onglet relecture
        self.tabs.setCurrentIndex(4)  # Index de l'onglet relecture
    
    # Méthodes pour la relecture (V3)
    def _refresh_views_list(self):
        """Actualise la liste des vues dans le QComboBox"""
        self.views_combo.clear()
        
        # Utiliser la base de données si disponible
        if self.db_helper.connected:
            db_views = self.db_helper.get_available_views()
            for view_info in db_views:
                display_text = f"{view_info['name']} ({view_info['column_count']} colonnes)"
                # Créer un objet view_data compatible
                view_data = {
                    'name': view_info['name'],
                    'type': 'Vue DB',
                    'created_date': 'Base de données',
                    'columns': view_info.get('columns', []),
                    'source': 'database'
                }
                self.views_combo.addItem(display_text, view_data)
            
            # Ajouter aussi les vues créées localement
            for view_data in self.created_views:
                view_type = view_data.get('type', 'Vue locale')
                display_text = f"{view_data['name']} ({view_type}) - {view_data['created_date']}"
                self.views_combo.addItem(display_text, view_data)
            
            total_count = len(db_views) + len(self.created_views)
        else:
            # Mode hors ligne - utiliser seulement les vues locales
            for view_data in self.created_views:
                view_type = view_data.get('type', 'Vue locale')
                display_text = f"{view_data['name']} ({view_type}) - {view_data['created_date']}"
                self.views_combo.addItem(display_text, view_data)
            
            total_count = len(self.created_views)
        
        # Mettre à jour le label du nombre de vues
        self.lbl_view_count.setText(f"{total_count} vue{'s' if total_count != 1 else ''}")
    
    def _add_sample_views(self):
        """Ajoute des vues de test pour démonstration"""
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
        
        self.created_views.extend(sample_views)
    
    def _on_view_selected(self, index):
        """Gère la sélection d'une vue dans la liste"""
        view_data = self.views_combo.itemData(index)
        if view_data:
            # Afficher les détails selon le type de vue
            if view_data.get('source') == 'database':
                # Vue de base de données
                details = f"""📊 Vue: {view_data['name']}
📅 Source: {view_data['created_date']}
📈 Type: {view_data['type']}
🔍 Colonnes: {', '.join(view_data.get('columns', []))}

💬 Cette vue provient de la base de données.
Utilisez le bouton "Aperçu" pour voir les données."""
            else:
                # Vue créée localement
                details = f"""📊 Vue: {view_data['name']}
📅 Créée le: {view_data['created_date']}
📈 Table: {view_data['data']['main_table']}
🔍 Champ X: {view_data['data']['x_field']}
📊 Champs Y: {', '.join([f for f in view_data['data']['y_fields'] if f])}
🧮 Groupement: {view_data['data']['grouping']}

💬 SQL généré:
{view_data['data']['sql']}"""
            
            self.view_details_text.setPlainText(details)
            
            # Charger les données de relecture existantes
            self.reviewer_name_edit.setText(view_data.get('reviewer', ''))
            status_index = self.review_status_combo.findText(view_data.get('review_status', '📝 Brouillon'))
            if status_index >= 0:
                self.review_status_combo.setCurrentIndex(status_index)
            self.review_comments_edit.setPlainText(view_data.get('review_comments', ''))
            
            # Afficher l'historique de relecture
            history_text = f"""📋 Historique de relecture:

📝 Statut actuel: {view_data.get('review_status', 'Brouillon')}
👤 Relecteur: {view_data.get('reviewer', 'Non assigné')}
📅 Date de relecture: {view_data.get('review_date', 'Non renseignée')}

💬 Commentaires:
{view_data.get('review_comments', 'Aucun commentaire')}"""
            
            self.review_history_text.setPlainText(history_text)
    
    def _on_review_data_changed(self):
        """Gère les changements dans les données de relecture"""
        # Activer le bouton de sauvegarde si des données sont présentes
        has_reviewer = bool(self.reviewer_name_edit.text().strip())
        has_status = self.review_status_combo.currentText() != "📝 Brouillon"
        
        self.save_review_btn.setEnabled(has_reviewer or has_status)
    
    def _save_review(self):
        """Sauvegarde les données de relecture"""
        current_index = self.views_combo.currentIndex()
        if current_index < 0 or not self.created_views:
            QMessageBox.warning(self, "Attention", "Veuillez sélectionner une vue à relire.")
            return
        
        view_data = self.views_combo.itemData(current_index)
        if not view_data:
            return
        
        # Mettre à jour les données de relecture
        view_data['reviewer'] = self.reviewer_name_edit.text().strip()
        view_data['review_status'] = self.review_status_combo.currentText()
        view_data['review_comments'] = self.review_comments_edit.toPlainText()
        view_data['review_date'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Rafraîchir la liste et la sélection
        self._refresh_views_list()
        self.views_combo.setCurrentIndex(current_index)
        self._on_view_selected(current_index)
        
        QMessageBox.information(
            self, 
            "Succès", 
            "Relecture sauvegardée avec succès !"
        )
    
    def _preview_view_data(self):
        """Prévisualise les données d'une vue de base de données"""
        current_index = self.views_combo.currentIndex()
        if current_index < 0:
            QMessageBox.warning(self, "Attention", "Veuillez sélectionner une vue.")
            return
        
        view_data = self.views_combo.itemData(current_index)
        if not view_data or view_data.get('source') != 'database':
            QMessageBox.warning(self, "Attention", "Cette fonction est disponible uniquement pour les vues de base de données.")
            return
        
        view_name = view_data['name']
        
        # Récupérer les données
        df, message = self.db_helper.get_view_data(view_name, limit=50)
        
        if df is not None:
            # Créer une fenêtre de prévisualisation
            preview_dialog = QDialog(self)
            preview_dialog.setWindowTitle(f"Aperçu - {view_name}")
            preview_dialog.setMinimumSize(800, 600)
            
            layout = QVBoxLayout()
            
            # Informations sur la vue
            info_label = QLabel(f"📊 Vue: {view_name}\n📈 {message}")
            info_label.setStyleSheet("font-weight: bold; margin-bottom: 10px;")
            layout.addWidget(info_label)
            
            # Tableau des données
            table = QTableWidget()
            table.setRowCount(len(df))
            table.setColumnCount(len(df.columns))
            table.setHorizontalHeaderLabels(df.columns.tolist())
            
            # Remplir le tableau
            for i, row in df.iterrows():
                for j, value in enumerate(row):
                    table.setItem(i, j, QTableWidgetItem(str(value)))
            
            table.resizeColumnsToContents()
            layout.addWidget(table)
            
            # Bouton fermer
            close_btn = QPushButton("Fermer")
            close_btn.clicked.connect(preview_dialog.close)
            layout.addWidget(close_btn)
            
            preview_dialog.setLayout(layout)
            preview_dialog.exec()
        else:
            QMessageBox.critical(self, "Erreur", f"Impossible de récupérer les données:\n{message}")
    
    def _delete_view_from_db(self):
        """Supprime une vue de la base de données"""
        current_index = self.views_combo.currentIndex()
        if current_index < 0:
            QMessageBox.warning(self, "Attention", "Veuillez sélectionner une vue.")
            return
        
        view_data = self.views_combo.itemData(current_index)
        if not view_data or view_data.get('source') != 'database':
            QMessageBox.warning(self, "Attention", "Cette fonction est disponible uniquement pour les vues de base de données.")
            return
        
        view_name = view_data['name']
        
        # Confirmation
        reply = QMessageBox.question(
            self, 
            "Confirmation", 
            f"Êtes-vous sûr de vouloir supprimer la vue '{view_name}' de la base de données ?\n\n⚠️ Cette action est irréversible !",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            success, message = self.db_helper.delete_view(view_name)
            
            if success:
                QMessageBox.information(self, "Succès", message)
                self._refresh_views_list()  # Actualiser la liste
            else:
                QMessageBox.critical(self, "Erreur", message)
    
    def _export_review_report(self):
        """Exporte un rapport de relecture"""
        if not self.created_views:
            QMessageBox.information(self, "Information", "Aucune vue à exporter.")
            return
        
        # Générer le rapport
        report_lines = []
        report_lines.append("=" * 60)
        report_lines.append("📋 RAPPORT DE RELECTURE DES VUES")
        report_lines.append("=" * 60)
        report_lines.append(f"📅 Généré le: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"📊 Nombre de vues: {len(self.created_views)}")
        report_lines.append("")
        
        for i, view in enumerate(self.created_views, 1):
            report_lines.append(f"📊 VUE #{i}: {view['name']}")
            report_lines.append("-" * 40)
            report_lines.append(f"📅 Créée le: {view['created_date']}")
            report_lines.append(f"📝 Statut: {view['review_status']}")
            report_lines.append(f"👤 Relecteur: {view.get('reviewer', 'Non assigné')}")
            report_lines.append(f"📅 Date relecture: {view.get('review_date', 'Non renseignée')}")
            report_lines.append(f"📊 Table source: {view['data']['main_table']}")
            report_lines.append(f"📈 Champ X: {view['data']['x_field']}")
            report_lines.append(f"📊 Champs Y: {', '.join([f for f in view['data']['y_fields'] if f])}")
            report_lines.append("")
            report_lines.append("💬 Commentaires:")
            report_lines.append(view.get('review_comments', 'Aucun commentaire'))
            report_lines.append("")
            report_lines.append("🔍 SQL généré:")
            report_lines.append(view['data']['sql'])
            report_lines.append("")
            report_lines.append("=" * 60)
            report_lines.append("")
        
        # Afficher le rapport dans une nouvelle fenêtre
        report_text = "\n".join(report_lines)
        
        # Créer une fenêtre de dialogue pour afficher le rapport
        dialog = QDialog(self)
        dialog.setWindowTitle("📋 Rapport de Relecture")
        dialog.setModal(True)
        dialog.resize(800, 600)
        
        layout = QVBoxLayout()
        
        text_edit = QTextEdit()
        text_edit.setPlainText(report_text)
        text_edit.setReadOnly(True)
        text_edit.setFont(QFont("Courier New", 10))
        layout.addWidget(text_edit)
        
        # Boutons
        button_layout = QHBoxLayout()
        
        copy_btn = QPushButton("📋 Copier")
        copy_btn.clicked.connect(lambda: QApplication.clipboard().setText(report_text))
        button_layout.addWidget(copy_btn)
        
        close_btn = QPushButton("❌ Fermer")
        close_btn.clicked.connect(dialog.accept)
        button_layout.addWidget(close_btn)
        
        layout.addLayout(button_layout)
        dialog.setLayout(layout)
        
        dialog.exec()


def main():
    """Fonction de test"""
    app = QApplication(sys.argv)
    
    # Créer et afficher le dialog
    dialog = AdvancedViewCreatorDialog()
    
    # Connecter le signal pour tester
    def on_view_created(view_data):
        print("🚀 Vue avancée créée avec succès!")
        print(f"📝 Nom: {view_data['name']}")
        print(f"📊 Table: {view_data['main_table']}")
        print(f"📈 Champs: X={view_data['x_field']}, Y={view_data['y_fields']}")
        print(f"🧮 Agrégations: {view_data['aggregations']}")
        print(f"📅 Groupement: {view_data['grouping']}")
        print(f"🔍 Filtres: {view_data['filters']}")
        print(f"🔍 SQL:\n{view_data['sql']}")
    
    dialog.view_created.connect(on_view_created)
    
    # Afficher
    if dialog.exec() == QDialog.Accepted:
        print("Dialog accepté")
    else:
        print("Dialog annulé")
    
    sys.exit(0)


if __name__ == "__main__":
    main()
