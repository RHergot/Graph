#!/usr/bin/env python3
"""
Test Dialog CRUD V2 - Création de vues personnalisées avec agrégations
Interface avancée pour utilisateurs non-techniques ("moldus")
Nouvelles fonctionnalités: SUM, AVG, MAX, MIN, groupement temporel, filtres

Auteur: Assistant IA
Date: 2025-07-17
Version: 2.0
"""

import sys
import os
from PySide6.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QHBoxLayout, QGridLayout,
    QLabel, QComboBox, QPushButton, QGroupBox, QTextEdit, QSplitter,
    QListWidget, QListWidgetItem, QFrame, QScrollArea, QWidget,
    QCheckBox, QSpinBox, QDateEdit, QLineEdit, QTabWidget
)
from PySide6.QtCore import Qt, QSize, Signal, QDate
from PySide6.QtGui import QFont, QIcon
import json
from datetime import datetime, timedelta

class AdvancedViewCreatorDialog(QDialog):
    """Dialog avancé pour créer des vues personnalisées avec agrégations"""
    
    view_created = Signal(dict)  # Signal émis quand une vue est créée
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("🚀 Créer une Vue Personnalisée - Version 2.0")
        self.setFixedSize(1100, 800)
        self.setModal(True)
        
        # Données simulées des tables GMAO
        self.tables_data = self._load_sample_tables()
        
        # Nouvelles variables pour V2
        self.selected_table1 = None
        self.selected_table2 = None
        self.selected_x_field = None
        self.selected_y_fields = []
        self.aggregation_functions = {}
        self.grouping_period = None
        self.filters = {}
        
        self._setup_ui()
        self._connect_signals()
        
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
    
    def _setup_ui(self):
        """Configuration de l'interface utilisateur"""
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("🚀 Créateur de Vue Personnalisée - Version 2.0")
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
        
        self.view_created.emit(view_data)
        self.accept()


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
