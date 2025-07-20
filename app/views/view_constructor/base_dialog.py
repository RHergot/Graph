"""
Base Dialog pour le constructeur de vues avancées
"""

from PySide6.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QPushButton, QLabel
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont
import logging

logger = logging.getLogger(__name__)


class BaseViewConstructorDialog(QDialog):
    """Classe de base pour le constructeur de vues avancées"""
    
    view_created = Signal(dict)  # Signal émis quand une vue est créée
    
    def __init__(self, parent=None, database_manager=None, analysis_engine=None):
        super().__init__(parent)
        self.setWindowTitle("🔧 Créateur de Vues Avancées - Version 3")
        self.setMinimumSize(1200, 800)
        
        # Services injectés
        self.database_manager = database_manager
        self.analysis_engine = analysis_engine
        
        # Initialiser les attributs de base
        self._init_attributes()
        
        # Configuration de l'interface
        self._setup_base_ui()
        
        logger.info("🔧 BaseViewConstructorDialog initialisé")
    
    def _init_attributes(self):
        """Initialise tous les attributs nécessaires"""
        # Données des vues créées
        self.created_views = []
        
        # Variables pour la sélection
        self.selected_table1 = None
        self.selected_table2 = None
        
        # Données des tables
        self.tables_data = {}
        
        # Gestionnaires
        self.view_builder = None
        self.view_crud_manager = None
    
    def _setup_base_ui(self):
        """Configuration de base de l'interface utilisateur"""
        layout = QVBoxLayout()
        
        # Titre
        title_label = QLabel("🚀 Créateur de Vue Personnalisée - Version 3.0")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(title_label)
        
        # Zone principale (sera remplie par les mixins)
        self.main_content_layout = QVBoxLayout()
        layout.addLayout(self.main_content_layout)
        
        # Boutons d'action
        self._setup_action_buttons(layout)
        
        self.setLayout(layout)
    
    def _setup_action_buttons(self, layout):
        """Configure les boutons d'action principaux"""
        buttons_layout = QHBoxLayout()
        
        self.preview_btn = QPushButton("🔍 Générer Prévisualisation")
        self.preview_btn.setEnabled(False)
        self.preview_btn.setStyleSheet(self._get_button_style("#0066cc", "#0052a3"))
        buttons_layout.addWidget(self.preview_btn)
        
        self.save_btn = QPushButton("💾 Créer ma vue")
        self.save_btn.setEnabled(False)
        self.save_btn.setStyleSheet(self._get_button_style("#28a745", "#218838"))
        buttons_layout.addWidget(self.save_btn)
        
        buttons_layout.addStretch()
        
        cancel_btn = QPushButton("❌ Annuler")
        cancel_btn.clicked.connect(self.reject)
        buttons_layout.addWidget(cancel_btn)
        
        layout.addLayout(buttons_layout)
    
    def _get_button_style(self, bg_color, hover_color):
        """Retourne le style CSS pour les boutons"""
        return f"""
            QPushButton {{
                background-color: {bg_color};
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 5px;
                font-weight: bold;
            }}
            QPushButton:hover {{
                background-color: {hover_color};
            }}
            QPushButton:disabled {{
                background-color: #cccccc;
                color: #666666;
            }}
        """
    
    def get_database_manager(self):
        """Retourne le gestionnaire de base de données"""
        return self.database_manager
    
    def get_analysis_engine(self):
        """Retourne le moteur d'analyse"""
        return self.analysis_engine
    
    def has_database_connection(self):
        """Vérifie si une connexion à la base de données est disponible"""
        return self.database_manager is not None
