"""
UI Components Mixin pour la création des composants d'interface
"""

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QGroupBox,
    QLabel, QComboBox, QPushButton, QTextEdit, QTabWidget,
    QCheckBox, QSpinBox, QDateEdit, QLineEdit, QTableWidget,
    QTableWidgetItem, QHeaderView, QMessageBox
)
from PySide6.QtCore import QDate
from PySide6.QtGui import QFont
import logging

logger = logging.getLogger(__name__)


class UIComponentsMixin:
    """Mixin pour la création des composants d'interface utilisateur"""
    
    def setup_ui_components(self):
        """Configure tous les composants UI"""
        # Créer le widget à onglets
        self.tabs = QTabWidget()
        
        # Créer tous les onglets
        self._create_all_tabs()
        
        # Ajouter les onglets au layout principal
        self.main_content_layout.addWidget(self.tabs)
        
        # Connecter les signaux
        self._connect_ui_signals()
    
    def _create_all_tabs(self):
        """Crée tous les onglets de l'interface"""
        # Tab 1: Configuration de base
        self.tabs.addTab(self._create_basic_tab(), "📊 Configuration de Base")
        
        # Tab 2: Agrégations
        self.tabs.addTab(self._create_aggregation_tab(), "🧮 Agrégations")
        
        # Tab 3: Filtres
        self.tabs.addTab(self._create_filters_tab(), "🔍 Filtres")
        
        # Tab 4: Prévisualisation
        self.tabs.addTab(self._create_preview_tab(), "👀 Prévisualisation")
        
        # Tab 5: Relecture
        self.tabs.addTab(self._create_review_tab(), "📝 Relecture")
    
    def _create_basic_tab(self):
        """Crée l'onglet de configuration de base"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Étape 1: Sélection des tables
        layout.addWidget(self._create_table_selection_group())
        
        # Étape 2: Sélection des champs
        layout.addWidget(self._create_field_selection_group())
        
        # Étape 3: Paramètres de la vue
        layout.addWidget(self._create_view_parameters_group())
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_table_selection_group(self):
        """Crée le groupe de sélection des tables"""
        group = QGroupBox("📝 Étape 1: Choisir les Tables")
        layout = QVBoxLayout()
        
        # Table principale
        main_layout = QHBoxLayout()
        main_layout.addWidget(QLabel("Table principale:"))
        self.main_table_combo = QComboBox()
        self.main_table_combo.addItem("-- Sélectionner --", None)
        main_layout.addWidget(self.main_table_combo)
        layout.addLayout(main_layout)
        
        # Table secondaire
        secondary_layout = QHBoxLayout()
        secondary_layout.addWidget(QLabel("Table secondaire:"))
        self.secondary_table_combo = QComboBox()
        self.secondary_table_combo.addItem("-- Aucune (optionnel) --", None)
        self.secondary_table_combo.setEnabled(False)
        secondary_layout.addWidget(self.secondary_table_combo)
        layout.addLayout(secondary_layout)
        
        group.setLayout(layout)
        return group
    
    def _create_field_selection_group(self):
        """Crée le groupe de sélection des champs"""
        group = QGroupBox("📊 Étape 2: Choisir les Champs")
        layout = QVBoxLayout()
        
        # Champ X
        x_layout = QHBoxLayout()
        x_layout.addWidget(QLabel("Axe X (horizontal):"))
        self.x_field_combo = QComboBox()
        self.x_field_combo.addItem("-- Sélectionner d'abord une table --", None)
        self.x_field_combo.setEnabled(False)
        x_layout.addWidget(self.x_field_combo)
        layout.addLayout(x_layout)
        
        # Groupement temporel
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
        layout.addLayout(grouping_layout)
        
        # Champs Y
        layout.addWidget(self._create_y_fields_section())
        
        group.setLayout(layout)
        return group
    
    def _create_y_fields_section(self):
        """Crée la section des champs Y"""
        y_widget = QWidget()
        y_layout = QVBoxLayout()
        y_layout.addWidget(QLabel("Axes Y (verticaux):"))
        
        # Y1, Y2, Y3
        for i, label in enumerate(["Y1:", "Y2:", "Y3:"], 1):
            field_layout = QHBoxLayout()
            field_layout.addWidget(QLabel(label))
            
            combo = QComboBox()
            placeholder = "-- Sélectionner d'abord une table --" if i == 1 else "-- Optionnel --"
            combo.addItem(placeholder, None)
            combo.setEnabled(False)
            
            setattr(self, f'y{i}_field_combo', combo)
            field_layout.addWidget(combo)
            y_layout.addLayout(field_layout)
        
        y_widget.setLayout(y_layout)
        return y_widget
    
    def _create_view_parameters_group(self):
        """Crée le groupe des paramètres de la vue"""
        group = QGroupBox("⚙️ Étape 3: Paramètres de la Vue")
        layout = QVBoxLayout()
        
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
        layout.addLayout(name_layout)
        
        group.setLayout(layout)
        return group
    
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
        
        # Créer les combos d'agrégation pour Y1, Y2, Y3
        aggregation_options = [
            "SUM - Somme totale",
            "AVG - Moyenne",
            "MAX - Valeur maximale",
            "MIN - Valeur minimale",
            "COUNT - Nombre d'occurrences"
        ]
        
        for i in range(1, 4):
            agg_layout_row = QHBoxLayout()
            agg_layout_row.addWidget(QLabel(f"Y{i} - Fonction:"))
            
            combo = QComboBox()
            combo.addItems(aggregation_options)
            combo.setEnabled(False)
            setattr(self, f'y{i}_agg_combo', combo)
            
            agg_layout_row.addWidget(combo)
            agg_layout.addLayout(agg_layout_row)
        
        agg_group.setLayout(agg_layout)
        layout.addWidget(agg_group)
        
        # Calculs dérivés
        layout.addWidget(self._create_derived_calculations_group())
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_derived_calculations_group(self):
        """Crée le groupe des calculs dérivés"""
        group = QGroupBox("📈 Calculs Dérivés (Optionnel)")
        layout = QVBoxLayout()
        
        # Pourcentage d'évolution
        self.calc_evolution_check = QCheckBox("📊 Calculer l'évolution en pourcentage")
        layout.addWidget(self.calc_evolution_check)
        
        # Ratio entre Y1 et Y2
        self.calc_ratio_check = QCheckBox("📊 Calculer le ratio Y1/Y2")
        layout.addWidget(self.calc_ratio_check)
        
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
        layout.addLayout(mobile_layout)
        
        group.setLayout(layout)
        return group
    
    def _create_filters_tab(self):
        """Crée l'onglet des filtres"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Informations
        info_label = QLabel("🔍 Définissez des filtres pour affiner les données")
        info_label.setStyleSheet("font-weight: bold; color: #0066cc; padding: 10px;")
        layout.addWidget(info_label)
        
        # Filtres par date
        layout.addWidget(self._create_date_filters_group())
        
        # Filtres par valeur
        layout.addWidget(self._create_value_filters_group())
        
        # Filtres par texte
        layout.addWidget(self._create_text_filters_group())
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_date_filters_group(self):
        """Crée le groupe des filtres par date"""
        group = QGroupBox("📅 Filtres par Date")
        layout = QVBoxLayout()
        
        # Activer filtre par date
        self.enable_date_filter_check = QCheckBox("Activer le filtrage par date")
        layout.addWidget(self.enable_date_filter_check)
        
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
        
        layout.addLayout(date_range_layout)
        group.setLayout(layout)
        return group
    
    def _create_value_filters_group(self):
        """Crée le groupe des filtres par valeur"""
        group = QGroupBox("📊 Filtres par Valeur")
        layout = QVBoxLayout()
        
        # Seuil minimum
        min_layout = QHBoxLayout()
        self.enable_min_filter_check = QCheckBox("Valeur minimale:")
        min_layout.addWidget(self.enable_min_filter_check)
        
        self.min_value_edit = QLineEdit()
        self.min_value_edit.setPlaceholderText("0")
        self.min_value_edit.setEnabled(False)
        min_layout.addWidget(self.min_value_edit)
        layout.addLayout(min_layout)
        
        # Seuil maximum
        max_layout = QHBoxLayout()
        self.enable_max_filter_check = QCheckBox("Valeur maximale:")
        max_layout.addWidget(self.enable_max_filter_check)
        
        self.max_value_edit = QLineEdit()
        self.max_value_edit.setPlaceholderText("999999")
        self.max_value_edit.setEnabled(False)
        max_layout.addWidget(self.max_value_edit)
        layout.addLayout(max_layout)
        
        group.setLayout(layout)
        return group
    
    def _create_text_filters_group(self):
        """Crée le groupe des filtres par texte"""
        group = QGroupBox("📝 Filtres par Texte")
        layout = QVBoxLayout()
        
        # Contient
        contains_layout = QHBoxLayout()
        self.enable_contains_filter_check = QCheckBox("Contient le texte:")
        contains_layout.addWidget(self.enable_contains_filter_check)
        
        self.contains_text_edit = QLineEdit()
        self.contains_text_edit.setPlaceholderText("Tapez le texte à rechercher")
        self.contains_text_edit.setEnabled(False)
        contains_layout.addWidget(self.contains_text_edit)
        layout.addLayout(contains_layout)
        
        group.setLayout(layout)
        return group
    
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
        layout.addWidget(self._create_view_selection_group())
        
        # Section: Détails de la vue sélectionnée
        layout.addWidget(self._create_view_details_group())
        
        # Section: Relecture et commentaires
        layout.addWidget(self._create_review_form_group())
        
        # Section: Historique des relectures
        layout.addWidget(self._create_review_history_group())
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_view_selection_group(self):
        """Crée le groupe de sélection des vues"""
        group = QGroupBox("📋 Vues Disponibles pour Relecture")
        layout = QVBoxLayout()
        
        # Sélection des vues créées
        selection_layout = QHBoxLayout()
        selection_layout.addWidget(QLabel("📋 Sélectionner une vue :"))
        
        self.views_combo = QComboBox()
        self.views_combo.setMinimumWidth(350)
        self.views_combo.setToolTip("Sélectionner la vue à relire")
        selection_layout.addWidget(self.views_combo)
        
        # Boutons d'action
        self.btn_refresh_views = QPushButton("♻️ Actualiser")
        self.btn_refresh_views.setMaximumWidth(100)
        selection_layout.addWidget(self.btn_refresh_views)
        
        if self.has_database_connection():
            self.btn_preview_view = QPushButton("👁️ Aperçu")
            self.btn_preview_view.setMaximumWidth(100)
            selection_layout.addWidget(self.btn_preview_view)
            
            self.btn_delete_view = QPushButton("🗑️ Supprimer")
            self.btn_delete_view.setMaximumWidth(100)
            selection_layout.addWidget(self.btn_delete_view)
        
        selection_layout.addStretch()
        layout.addLayout(selection_layout)
        
        # Compteur de vues
        self.lbl_view_count = QLabel("0 vues")
        self.lbl_view_count.setStyleSheet("color: #666666; font-style: italic;")
        layout.addWidget(self.lbl_view_count)
        
        group.setLayout(layout)
        return group
    
    def _create_view_details_group(self):
        """Crée le groupe des détails de la vue"""
        group = QGroupBox("🔍 Détails de la Vue Sélectionnée")
        layout = QVBoxLayout()
        
        self.view_details_text = QTextEdit()
        self.view_details_text.setReadOnly(True)
        self.view_details_text.setMaximumHeight(200)
        self.view_details_text.setPlainText("Sélectionnez une vue pour voir ses détails...")
        layout.addWidget(self.view_details_text)
        
        group.setLayout(layout)
        return group
    
    def _create_review_form_group(self):
        """Crée le groupe du formulaire de relecture"""
        group = QGroupBox("📝 Relecture et Commentaires")
        layout = QVBoxLayout()
        
        # Nom du relecteur
        reviewer_layout = QHBoxLayout()
        reviewer_layout.addWidget(QLabel("Relecteur:"))
        self.reviewer_name_edit = QLineEdit()
        self.reviewer_name_edit.setPlaceholderText("Votre nom...")
        reviewer_layout.addWidget(self.reviewer_name_edit)
        layout.addLayout(reviewer_layout)
        
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
        layout.addLayout(status_layout)
        
        # Zone de commentaires
        layout.addWidget(QLabel("Commentaires de relecture:"))
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
        layout.addWidget(self.review_comments_edit)
        
        # Boutons d'action pour la relecture
        review_buttons_layout = QHBoxLayout()
        
        self.save_review_btn = QPushButton("💾 Enregistrer la Relecture")
        review_buttons_layout.addWidget(self.save_review_btn)
        
        self.export_review_btn = QPushButton("📤 Exporter le Rapport")
        review_buttons_layout.addWidget(self.export_review_btn)
        
        review_buttons_layout.addStretch()
        layout.addLayout(review_buttons_layout)
        
        group.setLayout(layout)
        return group
    
    def _create_review_history_group(self):
        """Crée le groupe de l'historique des relectures"""
        group = QGroupBox("📚 Historique des Relectures")
        layout = QVBoxLayout()
        
        self.review_history_text = QTextEdit()
        self.review_history_text.setReadOnly(True)
        self.review_history_text.setMaximumHeight(100)
        self.review_history_text.setPlainText("Aucun historique disponible...")
        layout.addWidget(self.review_history_text)
        
        group.setLayout(layout)
        return group
    
    def _connect_ui_signals(self):
        """Connecte tous les signaux de l'interface utilisateur"""
        # Signaux pour les tables
        self.main_table_combo.currentIndexChanged.connect(self._on_main_table_changed)
        self.secondary_table_combo.currentIndexChanged.connect(self._on_secondary_table_changed)
        
        # Signaux pour les champs
        self.x_field_combo.currentTextChanged.connect(self._validate_form)
        self.y1_field_combo.currentTextChanged.connect(self._validate_form)
        
        # Signaux pour les filtres
        self.enable_date_filter_check.toggled.connect(self._on_filter_changed)
        self.enable_min_filter_check.toggled.connect(self._on_filter_changed)
        self.enable_max_filter_check.toggled.connect(self._on_filter_changed)
        self.enable_contains_filter_check.toggled.connect(self._on_filter_changed)
        
        # Signaux pour les calculs dérivés
        self.calc_mobile_check.toggled.connect(self._on_calc_changed)
        
        # Signaux pour les boutons principaux
        self.save_btn.clicked.connect(self._save_view)
        
        # Signaux pour la relecture
        self.btn_refresh_views.clicked.connect(self._refresh_views_list)
        self.views_combo.currentIndexChanged.connect(self._on_view_selected)
        self.save_review_btn.clicked.connect(self._save_review)
        self.export_review_btn.clicked.connect(self._export_review_report)
        
        # Signaux pour les boutons de base de données (si disponibles)
        if self.has_database_connection():
            if hasattr(self, 'btn_preview_view'):
                self.btn_preview_view.clicked.connect(self._preview_view_data)
            if hasattr(self, 'btn_delete_view'):
                self.btn_delete_view.clicked.connect(self._delete_view_from_db)
    
    def populate_table_combos(self):
        """Remplit les combos de tables avec les données disponibles"""
        self.main_table_combo.clear()
        self.main_table_combo.addItem("-- Sélectionner --", None)
        
        for table_name, table_info in self.tables_data.items():
            self.main_table_combo.addItem(table_info["display_name"], table_name)
