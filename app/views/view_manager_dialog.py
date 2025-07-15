"""
Dialogue de gestion des VIEWs PostgreSQL
"""

from PySide6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QTabWidget,
                               QTextEdit, QLineEdit, QPushButton, QLabel,
                               QMessageBox, QSplitter, QListWidget, QGroupBox,
                               QCheckBox, QWidget)
from PySide6.QtCore import Signal, Qt
from PySide6.QtGui import QFont, QSyntaxHighlighter, QTextCharFormat, QColor
import logging

logger = logging.getLogger(__name__)

class SQLSyntaxHighlighter(QSyntaxHighlighter):
    """Coloration syntaxique basique pour SQL"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setup_highlighting_rules()
    
    def setup_highlighting_rules(self):
        keyword_format = QTextCharFormat()
        keyword_format.setColor(QColor(0, 0, 255))
        keyword_format.setFontWeight(QFont.Bold)
        
        keywords = [
            'SELECT', 'FROM', 'WHERE', 'JOIN', 'INNER', 'LEFT', 'RIGHT',
            'GROUP BY', 'ORDER BY', 'HAVING', 'AS', 'AND', 'OR', 'NOT',
            'CREATE', 'VIEW', 'TABLE', 'INSERT', 'UPDATE', 'DELETE',
            'COUNT', 'SUM', 'AVG', 'MAX', 'MIN', 'DISTINCT'
        ]
        
        self.highlighting_rules = []
        for keyword in keywords:
            pattern = f'\\b{keyword}\\b'
            self.highlighting_rules.append((pattern, keyword_format))
    
    def highlightBlock(self, text):
        import re
        for pattern, format in self.highlighting_rules:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                self.setFormat(match.start(), match.end() - match.start(), format)

class ViewManagerDialog(QDialog):
    """Dialogue de gestion des VIEWs"""
    
    view_created = Signal(str)
    view_deleted = Signal(str)
    
    def __init__(self, database_manager, parent=None):
        super().__init__(parent)
        self.database_manager = database_manager
        self.setup_ui()
        self.load_existing_views()
    
    def setup_ui(self):
        """Configuration de l'interface utilisateur"""
        self.setWindowTitle("🔧 Gestionnaire de VIEWs")
        self.setMinimumSize(800, 600)
        self.resize(1000, 700)
        
        layout = QVBoxLayout(self)
        
        self.tab_widget = QTabWidget()
        
        self.setup_create_tab()
        self.setup_manage_tab()
        
        layout.addWidget(self.tab_widget)
        
        buttons_layout = QHBoxLayout()
        buttons_layout.addStretch()
        
        self.btn_close = QPushButton("Fermer")
        self.btn_close.clicked.connect(self.accept)
        buttons_layout.addWidget(self.btn_close)
        
        layout.addLayout(buttons_layout)
    
    def setup_create_tab(self):
        """Configuration de l'onglet de création"""
        create_widget = QWidget()
        layout = QVBoxLayout(create_widget)
        
        name_group = QGroupBox("Nom de la VIEW")
        name_layout = QVBoxLayout(name_group)
        
        self.view_name_edit = QLineEdit()
        self.view_name_edit.setPlaceholderText("ex: vw_mon_rapport")
        name_layout.addWidget(self.view_name_edit)
        
        layout.addWidget(name_group)
        
        sql_group = QGroupBox("Requête SQL")
        sql_layout = QVBoxLayout(sql_group)
        
        self.sql_editor = QTextEdit()
        self.sql_editor.setPlaceholderText(
            "SELECT column1, column2\nFROM table_name\nWHERE condition;"
        )
        
        font = QFont("Courier New", 10)
        self.sql_editor.setFont(font)
        
        self.highlighter = SQLSyntaxHighlighter(self.sql_editor.document())
        
        sql_layout.addWidget(self.sql_editor)
        layout.addWidget(sql_group)
        
        actions_layout = QHBoxLayout()
        
        self.btn_validate = QPushButton("🔍 Valider SQL")
        self.btn_validate.clicked.connect(self.validate_sql)
        actions_layout.addWidget(self.btn_validate)
        
        self.btn_create = QPushButton("✅ Créer VIEW")
        self.btn_create.clicked.connect(self.create_view)
        actions_layout.addWidget(self.btn_create)
        
        actions_layout.addStretch()
        layout.addLayout(actions_layout)
        
        self.tab_widget.addTab(create_widget, "➕ Créer VIEW")
    
    def setup_manage_tab(self):
        """Configuration de l'onglet de gestion"""
        manage_widget = QWidget()
        layout = QHBoxLayout(manage_widget)
        
        left_panel = QGroupBox("VIEWs existantes")
        left_layout = QVBoxLayout(left_panel)
        
        self.views_list = QListWidget()
        self.views_list.itemClicked.connect(self.on_view_selected)
        left_layout.addWidget(self.views_list)
        
        manage_buttons = QHBoxLayout()
        
        self.btn_refresh = QPushButton("🔄 Actualiser")
        self.btn_refresh.clicked.connect(self.load_existing_views)
        manage_buttons.addWidget(self.btn_refresh)
        
        self.btn_delete = QPushButton("🗑️ Supprimer")
        self.btn_delete.clicked.connect(self.delete_view)
        self.btn_delete.setEnabled(False)
        manage_buttons.addWidget(self.btn_delete)
        
        left_layout.addLayout(manage_buttons)
        layout.addWidget(left_panel)
        
        right_panel = QGroupBox("Détails de la VIEW")
        right_layout = QVBoxLayout(right_panel)
        
        self.view_details = QTextEdit()
        self.view_details.setReadOnly(True)
        self.view_details.setFont(QFont("Courier New", 9))
        right_layout.addWidget(self.view_details)
        
        layout.addWidget(right_panel)
        
        self.tab_widget.addTab(manage_widget, "📋 Gérer VIEWs")
    
    def validate_sql(self):
        """Valide la syntaxe SQL"""
        sql = self.sql_editor.toPlainText().strip()
        if not sql:
            QMessageBox.warning(self, "Attention", "Veuillez saisir une requête SQL")
            return
        
        try:
            test_query = f"SELECT * FROM ({sql}) AS test_query LIMIT 0"
            self.database_manager.execute_query(test_query)
            QMessageBox.information(self, "Validation", "✅ Syntaxe SQL valide")
        except Exception as e:
            QMessageBox.critical(self, "Erreur SQL", f"❌ Erreur de syntaxe:\n{str(e)}")
    
    def create_view(self):
        """Crée une nouvelle VIEW"""
        view_name = self.view_name_edit.text().strip()
        sql = self.sql_editor.toPlainText().strip()
        
        if not view_name or not sql:
            QMessageBox.warning(self, "Attention", "Veuillez remplir le nom et la requête SQL")
            return
        
        try:
            success = self.database_manager.create_view(view_name, sql)
            if success:
                QMessageBox.information(self, "Succès", f"✅ VIEW '{view_name}' créée avec succès")
                self.view_created.emit(view_name)
                self.load_existing_views()
                self.view_name_edit.clear()
                self.sql_editor.clear()
        except Exception as e:
            QMessageBox.critical(self, "Erreur", f"❌ Impossible de créer la VIEW:\n{str(e)}")
    
    def delete_view(self):
        """Supprime une VIEW sélectionnée"""
        current_item = self.views_list.currentItem()
        if not current_item:
            return
        
        view_name = current_item.text()
        
        reply = QMessageBox.question(
            self, "Confirmation",
            f"Êtes-vous sûr de vouloir supprimer la VIEW '{view_name}' ?",
            QMessageBox.Yes | QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            try:
                success = self.database_manager.drop_view(view_name)
                if success:
                    QMessageBox.information(self, "Succès", f"✅ VIEW '{view_name}' supprimée")
                    self.view_deleted.emit(view_name)
                    self.load_existing_views()
            except Exception as e:
                QMessageBox.critical(self, "Erreur", f"❌ Impossible de supprimer la VIEW:\n{str(e)}")
    
    def on_view_selected(self, item):
        """Gestion de la sélection d'une VIEW"""
        view_name = item.text()
        self.btn_delete.setEnabled(True)
        
        try:
            definition = self.database_manager.get_view_definition(view_name)
            structure = self.database_manager.get_view_structure(view_name)
            
            details = f"VIEW: {view_name}\n\n"
            details += f"Colonnes ({len(structure.get('columns', []))}):\n"
            for col in structure.get('columns', []):
                details += f"  • {col['name']} ({col['type']})\n"
            
            details += f"\nDéfinition SQL:\n{definition}"
            
            self.view_details.setPlainText(details)
        except Exception as e:
            self.view_details.setPlainText(f"Erreur lors du chargement des détails: {e}")
    
    def load_existing_views(self):
        """Charge la liste des VIEWs existantes"""
        try:
            views = self.database_manager.get_available_views()
            self.views_list.clear()
            
            for view in views:
                self.views_list.addItem(view['name'])
            
            self.btn_delete.setEnabled(False)
            self.view_details.clear()
            
        except Exception as e:
            logger.error(f"❌ Erreur chargement VIEWs: {e}")
