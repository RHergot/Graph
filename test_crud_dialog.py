#!/usr/bin/env python3
"""
Test Dialog CRUD - Création de vues personnalisées
Interface simplifiée pour utilisateurs non-techniques ("moldus")

Auteur: Assistant IA
Date: 2025-07-17
"""

import sys
import os
from PySide6.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QHBoxLayout, QGridLayout,
    QLabel, QComboBox, QPushButton, QGroupBox, QTextEdit, QSplitter,
    QListWidget, QListWidgetItem, QFrame, QScrollArea, QWidget
)
from PySide6.QtCore import Qt, QSize, Signal
from PySide6.QtGui import QFont, QIcon
import json

class CustomViewCreatorDialog(QDialog):
    """Dialog pour créer des vues personnalisées de manière intuitive"""
    
    view_created = Signal(dict)  # Signal émis quand une vue est créée
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("🎨 Créer une Vue Personnalisée")
        self.setFixedSize(900, 700)
        self.setModal(True)
        
        # Données simulées des tables GMAO
        self.tables_data = self._load_sample_tables()
        
        # Variables de state
        self.selected_table1 = None
        self.selected_table2 = None
        self.selected_x_field = None
        self.selected_y_fields = []
        
        self._setup_ui()
        self._connect_signals()
        
    def _load_sample_tables(self):
        """Charge les données des tables GMAO (simulées)"""
        return {
            "maintenance": {
                "display_name": "🔧 Maintenance",
                "fields": {
                    "id_maintenance": {"type": "integer", "display": "ID Maintenance"},
                    "ot_id": {"type": "integer", "display": "N° Ordre de Travail"},
                    "machine_id": {"type": "integer", "display": "ID Machine"},
                    "technicien_id": {"type": "integer", "display": "ID Technicien"},
                    "date_debut_reelle": {"type": "date", "display": "📅 Date Début"},
                    "date_fin_reelle": {"type": "date", "display": "📅 Date Fin"},
                    "duree_intervention_h": {"type": "numeric", "display": "⏱️ Durée (h)"},
                    "type_reel": {"type": "text", "display": "Type Intervention"},
                    "cout_main_oeuvre": {"type": "numeric", "display": "💰 Coût Main d'Œuvre"},
                    "cout_pieces_internes": {"type": "numeric", "display": "💰 Coût Pièces Internes"},
                    "cout_pieces_externes": {"type": "numeric", "display": "💰 Coût Pièces Externes"},
                    "cout_total": {"type": "numeric", "display": "💰 Coût Total"},
                    "evaluation_qualite": {"type": "integer", "display": "⭐ Évaluation Qualité"},
                    "impact_production": {"type": "text", "display": "📊 Impact Production"}
                }
            },
            "machine": {
                "display_name": "⚙️ Machine",
                "fields": {
                    "id_machine": {"type": "integer", "display": "ID Machine"},
                    "nom": {"type": "text", "display": "Nom Machine"},
                    "modele": {"type": "text", "display": "Modèle"},
                    "fabricant": {"type": "text", "display": "Fabricant"},
                    "date_installation": {"type": "date", "display": "📅 Date Installation"},
                    "valeur_achat": {"type": "numeric", "display": "💰 Valeur Achat"},
                    "etat": {"type": "text", "display": "État"},
                    "localisation": {"type": "text", "display": "📍 Localisation"},
                    "criticite": {"type": "integer", "display": "🔥 Criticité"}
                }
            },
            "technicien": {
                "display_name": "👨‍🔧 Technicien",
                "fields": {
                    "id_technicien": {"type": "integer", "display": "ID Technicien"},
                    "nom": {"type": "text", "display": "Nom"},
                    "prenom": {"type": "text", "display": "Prénom"},
                    "specialite": {"type": "text", "display": "Spécialité"},
                    "niveau_competence": {"type": "integer", "display": "📊 Niveau Compétence"},
                    "tarif_horaire": {"type": "numeric", "display": "💰 Tarif Horaire"},
                    "date_embauche": {"type": "date", "display": "📅 Date Embauche"},
                    "statut": {"type": "text", "display": "Statut"}
                }
            },
            "piece": {
                "display_name": "🔩 Pièce",
                "fields": {
                    "id_piece": {"type": "integer", "display": "ID Pièce"},
                    "nom": {"type": "text", "display": "Nom Pièce"},
                    "reference": {"type": "text", "display": "Référence"},
                    "categorie": {"type": "text", "display": "Catégorie"},
                    "prix_unitaire": {"type": "numeric", "display": "💰 Prix Unitaire"},
                    "stock_actuel": {"type": "integer", "display": "📦 Stock Actuel"},
                    "stock_alerte": {"type": "integer", "display": "⚠️ Stock Alerte"},
                    "fournisseur_pref_id": {"type": "integer", "display": "ID Fournisseur Préféré"}
                }
            }
        }
    
    def _setup_ui(self):
        """Configuration de l'interface utilisateur"""
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("🎨 Créateur de Vue Personnalisée")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(title_label)
        
        # Splitter principal
        splitter = QSplitter(Qt.Horizontal)
        
        # Panneau de configuration (gauche)
        config_widget = self._create_config_panel()
        splitter.addWidget(config_widget)
        
        # Panneau de prévisualisation (droite)
        preview_widget = self._create_preview_panel()
        splitter.addWidget(preview_widget)
        
        splitter.setSizes([400, 500])
        layout.addWidget(splitter)
        
        # Boutons d'action
        buttons_layout = QHBoxLayout()
        
        self.preview_btn = QPushButton("🔍 Prévisualiser")
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
    
    def _create_config_panel(self):
        """Crée le panneau de configuration"""
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
            "vue_maintenance_couts",
            "vue_machines_performance",
            "vue_techniciens_activite",
            "vue_pieces_consommation"
        ])
        name_layout.addWidget(self.view_name_combo)
        step3_layout.addLayout(name_layout)
        
        step3_group.setLayout(step3_layout)
        layout.addWidget(step3_group)
        
        layout.addStretch()
        widget.setLayout(layout)
        return widget
    
    def _create_preview_panel(self):
        """Crée le panneau de prévisualisation"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("🔍 Prévisualisation SQL")
        title_font = QFont()
        title_font.setPointSize(14)
        title_font.setBold(True)
        title_label.setFont(title_font)
        layout.addWidget(title_label)
        
        # Zone de texte pour le SQL généré
        self.sql_preview = QTextEdit()
        self.sql_preview.setReadOnly(True)
        self.sql_preview.setPlainText("-- Sélectionnez les tables et champs pour voir la requête SQL générée")
        
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
                if field_info["type"] in ["numeric", "integer"]:
                    combo.addItem(field_info["display"], field_name)
        
        # Activer les combos
        self.x_field_combo.setEnabled(True)
        self.y1_field_combo.setEnabled(True)
        self.y2_field_combo.setEnabled(True)
        self.y3_field_combo.setEnabled(True)
    
    def _clear_field_combos(self):
        """Vide et désactive les combos de champs"""
        for combo in [self.x_field_combo, self.y1_field_combo, self.y2_field_combo, self.y3_field_combo]:
            combo.clear()
            combo.addItem("-- Sélectionner d'abord une table --", None)
            combo.setEnabled(False)
    
    def _on_field_changed(self):
        """Gère le changement de champ"""
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
        """Génère la prévisualisation SQL"""
        if not self.selected_table1:
            return
        
        table_name = self.selected_table1
        x_field = self.x_field_combo.currentData()
        y1_field = self.y1_field_combo.currentData()
        y2_field = self.y2_field_combo.currentData()
        y3_field = self.y3_field_combo.currentData()
        view_name = self.view_name_combo.currentText().strip()
        
        # Générer le SQL
        sql_lines = []
        sql_lines.append(f"-- Vue personnalisée générée automatiquement")
        sql_lines.append(f"-- Table: {self.tables_data[table_name]['display_name']}")
        sql_lines.append(f"-- Axe X: {self.tables_data[table_name]['fields'][x_field]['display']}")
        sql_lines.append("")
        sql_lines.append(f"CREATE OR REPLACE VIEW {view_name} AS")
        sql_lines.append("SELECT")
        
        # Champ X
        x_display = self.tables_data[table_name]['fields'][x_field]['display']
        if self.tables_data[table_name]['fields'][x_field]['type'] == 'date':
            sql_lines.append(f"    TO_DATE({x_field}, 'YYYY-MM-DD') AS axe_x,")
        else:
            sql_lines.append(f"    {x_field} AS axe_x,")
        
        # Champs Y
        y_fields = []
        if y1_field:
            y_fields.append((y1_field, self.tables_data[table_name]['fields'][y1_field]['display']))
        if y2_field:
            y_fields.append((y2_field, self.tables_data[table_name]['fields'][y2_field]['display']))
        if y3_field:
            y_fields.append((y3_field, self.tables_data[table_name]['fields'][y3_field]['display']))
        
        for i, (field, display) in enumerate(y_fields):
            comma = "," if i < len(y_fields) - 1 else ""
            sql_lines.append(f"    {field} AS y{i+1}_value{comma}")
        
        sql_lines.append(f"FROM {table_name}")
        sql_lines.append(f"WHERE {x_field} IS NOT NULL")
        
        # Ajouter ORDER BY si c'est une date
        if self.tables_data[table_name]['fields'][x_field]['type'] == 'date':
            sql_lines.append(f"ORDER BY TO_DATE({x_field}, 'YYYY-MM-DD') DESC;")
        else:
            sql_lines.append(f"ORDER BY {x_field} DESC;")
        
        # Afficher le SQL
        sql_text = "\n".join(sql_lines)
        self.sql_preview.setPlainText(sql_text)
        
        # Mettre à jour les informations
        info_text = f"""
🎯 <b>Vue:</b> {view_name}
📊 <b>Table source:</b> {self.tables_data[table_name]['display_name']}
📈 <b>Axe X:</b> {x_display}
📊 <b>Axes Y:</b> {', '.join([display for _, display in y_fields])}
🔢 <b>Champs numériques:</b> {len(y_fields)}
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
    dialog = CustomViewCreatorDialog()
    
    # Connecter le signal pour tester
    def on_view_created(view_data):
        print("🎉 Vue créée avec succès!")
        print(f"📝 Nom: {view_data['name']}")
        print(f"📊 Table: {view_data['main_table']}")
        print(f"📈 Champs: X={view_data['x_field']}, Y={view_data['y_fields']}")
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
