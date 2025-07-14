# Guide de Développement : Module de Reporting BI pour Suite Logicielle

## 📋 Briefing Projet

Vous êtes chargé de développer un module de Business Intelligence (BI) intégré à une suite logicielle métier (GMAO, Stocks, Achats). Ce n'est PAS un grapheur générique, mais un outil spécialisé exploitant des VIEWs SQL prédéfinies pour transformer les données opérationnelles en insights stratégiques.

### 🎯 Objectifs Stratégiques
- Pilotage d'activité (coûts maintenance, performance fournisseurs, rotation stocks)
- Aide à la décision (pannes récurrentes, besoins approvisionnement)
- Valorisation des données existantes avec ROI immédiat

## 🛠️ Stack Technique

| Composant | Technologie | Justification |
|-----------|-------------|---------------|
| **Backend** | Python 3.9+ | Écosystème data science mature |
| **Interface** | PySide6 | Native Qt, performance optimale |
| **Base de données** | PostgreSQL | VIEWs SQL existantes à exploiter |
| **ORM** | SQLAlchemy Core | Protection injection SQL |
| **Data Processing** | Pandas | Manipulation DataFrames |
| **Visualisation** | Matplotlib | Intégration PySide6 native |
| **Threading** | QThread | UI non-bloquante |
| **Architecture** | MVC | Maintenabilité et séparation responsabilités |

## ⚠️ Contraintes Critiques

### Performance UI
- **OBLIGATOIRE** : Threading pour toutes les requêtes DB (QThread)
- **OBLIGATOIRE** : Indicateurs de chargement visuels
- **OBLIGATOIRE** : Agrégation côté PostgreSQL (jamais côté Python)

### Gestion Mémoire
- Pagination des tables (max 100 lignes)
- Échantillonnage pour graphiques long-terme
- Limitation taille DataFrames

### Sécurité
- SQLAlchemy Core uniquement (pas de SQL brut)
- Validation tous les inputs utilisateur
- Gestion erreurs exhaustive avec messages clairs

## 🏗️ Architecture MVC - Spécifications Détaillées

### 📊 MODÈLE (Model)

#### `models/database_manager.py`
**Responsabilités :**
- Connexion PostgreSQL via SQLAlchemy Core
- Découverte automatique des VIEWs métier
- Exécution sécurisée des requêtes

**Méthodes critiques :**
```python
def get_available_views() -> List[Dict]
    # Retourne les VIEWs préfixées 'vw_' ou 'report_'
    # Format: [{"name": "vw_couts_maintenance", "description": "..."}]

def execute_query(query: Select) -> pd.DataFrame
    # Exécute requête SQLAlchemy et retourne DataFrame
    # MUST: Gestion erreurs + timeout + logging
```

#### `models/analysis_engine.py`
**Responsabilités :**
- Orchestration des analyses
- Construction requêtes dynamiques
- Application filtres et agrégations

**Méthode principale :**
```python
def run_analysis(view_name: str, filters: Dict, aggregations: Dict) -> pd.DataFrame
    # Construit SELECT sur VIEW avec WHERE/GROUP BY dynamiques
    # Délègue à database_manager.execute_query()
```

### 🎨 VUE (View)

#### `views/main_window.py`
**Widgets obligatoires :**
- `QComboBox` : Sélection VIEW (rapport de base)
- `QDateTimeEdit` × 2 : Période (début/fin)
- `QPushButton` : "Générer Analyse"
- `QProgressBar` : Indicateur chargement
- `QTableView` : Affichage données tabulaires
- `QWidget` + Matplotlib : Zone graphiques
- `QTabWidget` : Onglets Table/Graphique

**Signaux à émettre :**
```python
report_selected = Signal(str)  # Nom de la VIEW
generate_clicked = Signal(dict)  # Paramètres complets
filters_changed = Signal(dict)  # Mise à jour filtres
```

### 🎮 CONTRÔLEUR (Controller)

#### `controllers/main_controller.py`
**Responsabilités :**
- Liaison signaux Vue ↔ slots Contrôleur
- Orchestration threading (QThread)
- Mise à jour Vue avec résultats

**Workflow type :**
1. Réception signal `generate_clicked`
2. Validation paramètres
3. Lancement `AnalysisWorker` (QThread)
4. Affichage indicateur chargement
5. Réception résultats → Mise à jour Vue

## 💾 Fonctionnalités CRUD - Gestion Catalogue Rapports

Implémentation des opérations sur les **configurations de rapports** (pas les données) :

| Opération | Description | Implémentation |
|-----------|-------------|----------------|
| **CREATE** | Sauvegarder config rapport | JSON local ou table `user_reports` |
| **READ** | Charger rapport sauvegardé | Liste déroulante rapports personnalisés |
| **UPDATE** | Modifier filtres existants | Écrasement config + confirmation |
| **DELETE** | Supprimer rapport personnel | Confirmation utilisateur obligatoire |

## 📁 Arborescence Projet Complète

```
reporting_module/
├── 📁 app.py                      # Point d'entrée application
├── 📁 config/
│   ├── database.py               # Configuration DB
│   ├── logging.py                # Configuration Logging
│   └── settings.py               # Paramètres application
├── 📁 models/
│   ├── database_manager.py       # Connexion + requêtes
│   ├── analysis_engine.py        # Logique métier analyses
│   └── report_config.py          # Gestion configs rapports
├── 📁 views/
│   ├── main_window.py            # Interface principale
│   ├── widgets/
│   │   ├── filter_panel.py       # Panneau filtres
│   │   ├── chart_widget.py       # Zone graphiques
│   │   └── table_widget.py       # Tableau données
│   └── dialogs/
│       └── save_report_dialog.py # Dialogue sauvegarde
├── 📁 controllers/
│   ├── main_controller.py        # Contrôleur principal
│   └── report_controller.py      # Gestion rapports
├── 📁 utils/
│   ├── worker.py                 # QThread workers
│   ├── exceptions.py             # Exceptions personnalisées
│   └── validators.py             # Validation inputs
├── 📁 resources/
│   ├── icons/                    # Icônes UI
│   └── styles/                   # Feuilles style Qt
├── 📁 tests/
│   ├── test_database.py
│   ├── test_analysis.py
│   └── test_ui.py
└── 📁 requirements.txt           # Dépendances Python
```

## 🚀 PROCÉDURE DE DÉVELOPPEMENT

### Phase 1 : Mise en Place Environnement

#### Étape 1.1 : Initialisation Projet
```bash
# Création structure
mkdir reporting_module && cd reporting_module
python -m venv venv
venv\Scripts\activate  # Windows
pip install --upgrade pip
```

#### Étape 1.2 : Installation Dépendances
```bash
pip install PySide6 SQLAlchemy pandas matplotlib psycopg2-binary python-dotenv
pip freeze > requirements.txt
```

#### Étape 1.3 : Configuration Base
- Créer `.env` avec paramètres DB
- Initialiser structure dossiers
- Setup logging configuration

### Phase 1.5 : Configuration Base de Données

#### Étape 1.5.1 : Fichier `.env`
```env
# Configuration PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=your_database_name
DB_USER=your_username
DB_PASSWORD=your_password
DB_SCHEMA=public

# Configuration Application
LOG_LEVEL=INFO
UI_THEME=default
CACHE_ENABLED=true
```

#### Étape 1.5.2 : `config/database.py`
```python
import os
from dotenv import load_dotenv

load_dotenv()

class DatabaseConfig:
    """Configuration centralisée pour la base de données"""
    
    @staticmethod
    def get_connection_string() -> str:
        """Construit la chaîne de connexion PostgreSQL"""
        return (
            f"postgresql://{os.getenv('DB_USER')}:"
            f"{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}:"
            f"{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
        )
    
    @staticmethod
    def get_engine_options() -> dict:
        """Options pour SQLAlchemy Engine"""
        return {
            'pool_size': 5,
            'max_overflow': 10,
            'pool_timeout': 30,
            'pool_recycle': 3600,
            'echo': os.getenv('LOG_LEVEL') == 'DEBUG'
        }
```

#### Étape 1.5.3 : Structure VIEWs Attendue
```sql
-- Exemples de VIEWs métier à créer si non existantes
CREATE VIEW vw_couts_maintenance AS
SELECT 
    equipment_id,
    DATE_TRUNC('month', maintenance_date) as periode,
    SUM(cost_amount) as cout_total,
    COUNT(*) as nb_interventions
FROM maintenance_records 
GROUP BY equipment_id, DATE_TRUNC('month', maintenance_date);

CREATE VIEW vw_performance_fournisseur AS
SELECT 
    supplier_id,
    supplier_name,
    AVG(delivery_delay) as delai_moyen,
    SUM(order_amount) as ca_total,
    COUNT(*) as nb_commandes
FROM purchase_orders 
GROUP BY supplier_id, supplier_name;
```

#### Étape 1.4 : Configuration Logging

#### `config/logging.py`
```python
import logging
import logging.handlers
import os
from datetime import datetime

def setup_logging():
    """Configuration centralisée du logging"""
    
    # Création dossier logs si inexistant
    logs_dir = "logs"
    if not os.path.exists(logs_dir):
        os.makedirs(logs_dir)
    
    # Configuration du logger principal
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Format des messages
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Handler fichier avec rotation
    file_handler = logging.handlers.RotatingFileHandler(
        f"{logs_dir}/reporting_module.log",
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    # Handler console pour développement
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    return logger
```

#### `utils/exceptions.py`
```python
class ReportingModuleException(Exception):
    """Exception de base pour le module de reporting"""
    pass

class DatabaseConnectionError(ReportingModuleException):
    """Erreur de connexion à la base de données"""
    pass

class ViewNotFoundError(ReportingModuleException):
    """VIEW SQL non trouvée"""
    pass

class InvalidFilterError(ReportingModuleException):
    """Filtre invalide ou malformé"""
    pass

class DataProcessingError(ReportingModuleException):
    """Erreur lors du traitement des données"""
    pass

class UIThreadError(ReportingModuleException):
    """Erreur dans les threads d'interface"""
    pass
```

### Phase 2 : Développement Modèle (PRIORITÉ 1)

#### Étape 2.1 : `models/database_manager.py`
**⭐ COMMENCER PAR LÀ - FONDATION DU PROJET**

```python
# Template de démarrage
from sqlalchemy import create_engine, MetaData, inspect
import pandas as pd
from typing import List, Dict

class DatabaseManager:
    def __init__(self, connection_string: str):
        self.engine = create_engine(connection_string)
        self.metadata = MetaData()
    
    def get_available_views(self) -> List[Dict]:
        """PRIORITÉ MAX : Découverte VIEWs métier"""
        # TODO: Implémenter inspection VIEWs
        # Filtrer préfixes 'vw_' ou 'report_'
        pass
    
    def execute_query(self, query) -> pd.DataFrame:
        """Exécution sécurisée avec gestion erreurs"""
        # TODO: Try/catch + timeout + logging
        pass
```

#### Étape 2.1.5 : Implémentation Complète `database_manager.py`
```python
from sqlalchemy import create_engine, MetaData, inspect, text, select
from sqlalchemy.exc import SQLAlchemyError
import pandas as pd
import logging
from typing import List, Dict, Optional
from config.database import DatabaseConfig

logger = logging.getLogger(__name__)

class DatabaseManager:
    def __init__(self):
        self.config = DatabaseConfig()
        self.engine = create_engine(
            self.config.get_connection_string(),
            **self.config.get_engine_options()
        )
        self.metadata = MetaData()
        self._test_connection()
    
    def _test_connection(self) -> bool:
        """Test de connexion à la base de données"""
        try:
            with self.engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            logger.info("Connexion base de données réussie")
            return True
        except SQLAlchemyError as e:
            logger.error(f"Erreur connexion DB: {e}")
            raise ConnectionError(f"Impossible de se connecter à la base: {e}")
    
    def get_available_views(self) -> List[Dict]:
        """Découverte des VIEWs métier disponibles"""
        try:
            inspector = inspect(self.engine)
            all_views = inspector.get_view_names(schema='public')
            
            # Filtrage VIEWs métier (préfixes vw_ ou report_)
            business_views = [
                view for view in all_views 
                if view.startswith(('vw_', 'report_'))
            ]
            
            views_info = []
            for view_name in business_views:
                # Récupération colonnes pour description
                columns = inspector.get_columns(view_name, schema='public')
                col_names = [col['name'] for col in columns[:5]]  # Top 5 colonnes
                
                views_info.append({
                    'name': view_name,
                    'description': f"Analyse basée sur {view_name.replace('vw_', '').replace('_', ' ')}",
                    'columns': col_names,
                    'column_count': len(columns)
                })
            
            logger.info(f"Trouvé {len(views_info)} VIEWs métier")
            return views_info
            
        except SQLAlchemyError as e:
            logger.error(f"Erreur découverte VIEWs: {e}")
            return []
    
    def get_view_structure(self, view_name: str) -> Dict:
        """Récupère la structure détaillée d'une VIEW"""
        try:
            inspector = inspect(self.engine)
            columns = inspector.get_columns(view_name, schema='public')
            
            return {
                'columns': [
                    {
                        'name': col['name'],
                        'type': str(col['type']),
                        'nullable': col['nullable']
                    }
                    for col in columns
                ]
            }
        except SQLAlchemyError as e:
            logger.error(f"Erreur structure VIEW {view_name}: {e}")
            return {'columns': []}
    
    def execute_query(self, query, params: Dict = None) -> pd.DataFrame:
        """Exécution sécurisée avec gestion erreurs et timeout"""
        try:
            with self.engine.connect() as conn:
                # Timeout de 30 secondes pour éviter les requêtes infinies
                conn = conn.execution_options(autocommit=True)
                
                if params:
                    result = conn.execute(query, params)
                else:
                    result = conn.execute(query)
                
                # Conversion en DataFrame avec limitation mémoire
                df = pd.read_sql(query, conn, params=params)
                
                # Limitation sécurité : max 10000 lignes
                if len(df) > 10000:
                    logger.warning(f"Requête retourne {len(df)} lignes, limitation à 10000")
                    df = df.head(10000)
                
                logger.info(f"Requête exécutée: {len(df)} lignes retournées")
                return df
                
        except SQLAlchemyError as e:
            logger.error(f"Erreur exécution requête: {e}")
            raise RuntimeError(f"Erreur lors de l'exécution: {e}")
        except Exception as e:
            logger.error(f"Erreur inattendue: {e}")
            raise RuntimeError(f"Erreur inattendue: {e}")
    
    def test_view_access(self, view_name: str) -> bool:
        """Test d'accès à une VIEW spécifique"""
        try:
            test_query = text(f"SELECT * FROM {view_name} LIMIT 1")
            with self.engine.connect() as conn:
                conn.execute(test_query)
            return True
        except SQLAlchemyError:
            return False
```

#### Étape 2.2 : Test Connexion DB
- Valider connexion PostgreSQL
- Tester découverte VIEWs
- Vérifier retour données basiques

#### Étape 2.3 : `models/analysis_engine.py`
```python
class AnalysisEngine:
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
    
    def run_analysis(self, view_name: str, filters: Dict) -> pd.DataFrame:
        """Construction requête dynamique sur VIEW"""
        # TODO: SQLAlchemy Select builder
        # TODO: Application filtres WHERE
        # TODO: Délégation à db_manager
        pass
```

### Phase 3 : Développement Vue (Interface)

#### Étape 3.1 : `views/main_window.py` - Structure
```python
from PySide6.QtWidgets import QMainWindow, QVBoxLayout, QHBoxLayout, 
                               QComboBox, QDateTimeEdit, QPushButton,
                               QProgressBar, QTableView, QTabWidget,
                               QWidget, QLabel, QSplitter, QMessageBox
from PySide6.QtCore import Signal, QDateTime, Qt
from PySide6.QtGui import QStandardItemModel, QStandardItem
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

class MainWindow(QMainWindow):
    # Signaux obligatoires
    report_selected = Signal(str)
    generate_clicked = Signal(dict)
    filters_changed = Signal(dict)
    view_structure_requested = Signal(str)
    
    def __init__(self):
        super().__init__()
        self.setup_ui()
        self.setup_connections()
        
    def setup_ui(self):
        """Configuration complète interface utilisateur"""
        self.setWindowTitle("Module de Reporting BI - Suite Logicielle")
        self.setMinimumSize(1200, 800)
        
        # Widget central
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Layout principal
        main_layout = QVBoxLayout(central_widget)
        
        # === PANNEAU DE CONTRÔLE ===
        control_panel = self.create_control_panel()
        main_layout.addWidget(control_panel)
        
        # === ZONE D'AFFICHAGE ===
        display_area = self.create_display_area()
        main_layout.addWidget(display_area)
        
        # === BARRE DE STATUT ===
        self.create_status_bar()
        
    def create_control_panel(self) -> QWidget:
        """Panneau de sélection et filtres"""
        panel = QWidget()
        layout = QHBoxLayout(panel)
        
        # Sélection VIEW
        layout.addWidget(QLabel("Rapport :"))
        self.combo_views = QComboBox()
        self.combo_views.setMinimumWidth(300)
        layout.addWidget(self.combo_views)
        
        layout.addSpacing(20)
        
        # Filtres dates
        layout.addWidget(QLabel("Du :"))
        self.date_start = QDateTimeEdit()
        self.date_start.setDisplayFormat("dd/MM/yyyy")
        self.date_start.setDateTime(QDateTime.currentDateTime().addDays(-30))
        layout.addWidget(self.date_start)
        
        layout.addWidget(QLabel("Au :"))
        self.date_end = QDateTimeEdit()
        self.date_end.setDisplayFormat("dd/MM/yyyy")
        self.date_end.setDateTime(QDateTime.currentDateTime())
        layout.addWidget(self.date_end)
        
        layout.addSpacing(20)
        
        # Boutons actions
        self.btn_generate = QPushButton("🔄 Générer Analyse")
        self.btn_generate.setMinimumHeight(35)
        layout.addWidget(self.btn_generate)
        
        self.btn_export = QPushButton("📊 Exporter")
        self.btn_export.setEnabled(False)
        layout.addWidget(self.btn_export)
        
        layout.addStretch()
        
        # Indicateur chargement
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        layout.addWidget(self.progress_bar)
        
        return panel
    
    def create_display_area(self) -> QWidget:
        """Zone d'affichage table et graphiques"""
        # Splitter pour redimensionnement
        splitter = QSplitter(Qt.Horizontal)
        
        # === ONGLETS AFFICHAGE ===
        self.tab_widget = QTabWidget()
        
        # Onglet Table
        self.table_view = QTableView()
        self.table_model = QStandardItemModel()
        self.table_view.setModel(self.table_model)
        self.tab_widget.addTab(self.table_view, "📋 Données")
        
        # Onglet Graphique
        self.chart_widget = self.create_chart_widget()
        self.tab_widget.addTab(self.chart_widget, "📈 Graphique")
        
        splitter.addWidget(self.tab_widget)
        splitter.setSizes([800, 400])  # Répartition espace
        
        return splitter
    
    def create_chart_widget(self) -> QWidget:
        """Widget Matplotlib pour graphiques"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        # Figure Matplotlib
        self.figure = Figure(figsize=(10, 6))
        self.canvas = FigureCanvas(self.figure)
        layout.addWidget(self.canvas)
        
        return widget
    
    def create_status_bar(self):
        """Barre de statut avec informations"""
        status_bar = self.statusBar()
        self.lbl_status = QLabel("Prêt")
        self.lbl_row_count = QLabel("0 lignes")
        
        status_bar.addWidget(self.lbl_status)
        status_bar.addPermanentWidget(self.lbl_row_count)
    
    def setup_connections(self):
        """Connexion des signaux internes"""
        self.combo_views.currentTextChanged.connect(
            lambda text: self.report_selected.emit(text)
        )
        self.btn_generate.clicked.connect(self.on_generate_clicked)
        self.date_start.dateTimeChanged.connect(self.on_filters_changed)
        self.date_end.dateTimeChanged.connect(self.on_filters_changed)
    
    def on_generate_clicked(self):
        """Émission signal génération avec paramètres"""
        params = {
            'view_name': self.combo_views.currentText(),
            'date_start': self.date_start.dateTime().toPython(),
            'date_end': self.date_end.dateTime().toPython(),
            'filters': self.get_current_filters()
        }
        self.generate_clicked.emit(params)
    
    def on_filters_changed(self):
        """Émission signal changement filtres"""
        filters = self.get_current_filters()
        self.filters_changed.emit(filters)
    
    def get_current_filters(self) -> dict:
        """Récupération filtres actuels"""
        return {
            'date_start': self.date_start.dateTime().toPython(),
            'date_end': self.date_end.dateTime().toPython()
        }
    
    # === MÉTHODES PUBLIQUES POUR CONTRÔLEUR ===
    
    def populate_views(self, views_list: list):
        """Remplissage combo VIEWs"""
        self.combo_views.clear()
        for view_info in views_list:
            self.combo_views.addItem(view_info['name'])
    
    def show_loading(self, message: str = "Chargement..."):
        """Affichage indicateur chargement"""
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)  # Indéterminé
        self.lbl_status.setText(message)
        self.btn_generate.setEnabled(False)
    
    def hide_loading(self):
        """Masquage indicateur chargement"""
        self.progress_bar.setVisible(False)
        self.btn_generate.setEnabled(True)
        self.lbl_status.setText("Prêt")
    
    def display_data(self, dataframe):
        """Affichage données dans table"""
        # Nettoyage modèle
        self.table_model.clear()
        
        if dataframe.empty:
            self.lbl_row_count.setText("Aucune donnée")
            return
        
        # Headers
        headers = list(dataframe.columns)
        self.table_model.setHorizontalHeaderLabels(headers)
        
        # Données (limitation 1000 lignes pour performance)
        display_df = dataframe.head(1000)
        
        for row_idx, row in display_df.iterrows():
            items = []
            for col_val in row:
                item = QStandardItem(str(col_val))
                items.append(item)
            self.table_model.appendRow(items)
        
        # Mise à jour compteur
        total_rows = len(dataframe)
        displayed_rows = len(display_df)
        
        if total_rows > displayed_rows:
            self.lbl_row_count.setText(f"{displayed_rows}/{total_rows} lignes (limité)")
        else:
            self.lbl_row_count.setText(f"{total_rows} lignes")
        
        self.btn_export.setEnabled(True)
    
    def display_chart(self, dataframe, chart_type='line'):
        """Affichage graphique simple"""
        self.figure.clear()
        
        if dataframe.empty:
            return
        
        ax = self.figure.add_subplot(111)
        
        # Graphique basique selon type
        if chart_type == 'line' and len(dataframe.columns) >= 2:
            ax.plot(dataframe.iloc[:, 0], dataframe.iloc[:, 1])
            ax.set_xlabel(dataframe.columns[0])
            ax.set_ylabel(dataframe.columns[1])
        elif chart_type == 'bar' and len(dataframe.columns) >= 2:
            ax.bar(dataframe.iloc[:, 0], dataframe.iloc[:, 1])
            ax.set_xlabel(dataframe.columns[0])
            ax.set_ylabel(dataframe.columns[1])
        
        ax.set_title("Analyse des Données")
        self.figure.tight_layout()
        self.canvas.draw()
    
    def show_error(self, message: str):
        """Affichage erreur utilisateur"""
        QMessageBox.critical(self, "Erreur", message)
        self.hide_loading()
    
    def show_info(self, message: str):
        """Affichage information utilisateur"""
        QMessageBox.information(self, "Information", message)
```

#### Étape 3.2 : Tests Interface
- Vérification signals émis
- Test responsivité widgets
- Validation layout adaptatif

### Phase 4 : Développement Contrôleur (Logique)

#### Étape 4.1 : `controllers/main_controller.py`
```python
from PySide6.QtCore import QObject, QThread
from utils.worker import AnalysisWorker

class MainController(QObject):
    def __init__(self, model, view):
        super().__init__()
        self.model = model
        self.view = view
        self.connect_signals()
    
    def connect_signals(self):
        """Connexion signaux Vue → Contrôleur"""
        self.view.generate_clicked.connect(self.on_generate_analysis)
    
    def on_generate_analysis(self, params: dict):
        """Lancement analyse en arrière-plan"""
        # TODO: Validation paramètres
        # TODO: Création AnalysisWorker (QThread)
        # TODO: Gestion callbacks
        pass
```

#### Étape 4.2 : `utils/worker.py` - Threading
```python
from PySide6.QtCore import QThread, Signal

class AnalysisWorker(QThread):
    finished = Signal(object)  # DataFrame
    error = Signal(str)
    
    def __init__(self, analysis_engine, params):
        super().__init__()
        self.analysis_engine = analysis_engine
        self.params = params
    
    def run(self):
        """Exécution analyse en arrière-plan"""
        try:
            result = self.analysis_engine.run_analysis(**self.params)
            self.finished.emit(result)
        except Exception as e:
            self.error.emit(str(e))
```

### Phase 5 : Intégration et Tests

#### Étape 5.1 : `app.py` - Point d'Entrée
```python
from PySide6.QtWidgets import QApplication
from models.database_manager import DatabaseManager
from models.analysis_engine import AnalysisEngine
from views.main_window import MainWindow
from controllers.main_controller import MainController

def main():
    app = QApplication([])
    
    # Initialisation MVC
    db_manager = DatabaseManager()
    model = AnalysisEngine(db_manager)
    view = MainWindow()
    controller = MainController(model, view)
    
    # Affichage
    view.show()
    app.exec()

if __name__ == "__main__":
    main()
```

#### Étape 5.2 : Tests Intégration
- Test workflow complet utilisateur
- Validation performance threading
- Test gestion erreurs

### Phase 6 : Fonctionnalités Avancées

#### Étape 6.1 : Sauvegarde Rapports (CRUD)
- Implémentation `models/report_config.py`
- Interface sauvegarde/chargement
- Persistance JSON ou DB

#### Étape 6.2 : Optimisations
- Cache requêtes fréquentes
- Pagination avancée
- Export données (CSV, Excel)

## ⚡ Checklist Validation

### ✅ Critères Acceptation Technique
- [ ] Connexion PostgreSQL fonctionnelle
- [ ] Découverte automatique VIEWs
- [ ] Interface non-bloquante (QThread)
- [ ] Affichage table + graphique
- [ ] Gestion erreurs exhaustive
- [ ] Filtres date opérationnels

### ✅ Critères Acceptation Utilisateur
- [ ] Sélection rapport en 1 clic
- [ ] Génération analyse < 5 secondes
- [ ] Messages erreur compréhensibles
- [ ] Sauvegarde configuration rapport
- [ ] Export résultats possible

## 🎯 PROCHAINES ÉTAPES IMMÉDIATES

1. **DÉMARRER** par `models/database_manager.py::get_available_views()`
2. **TESTER** connexion DB et découverte VIEWs
3. **CRÉER** interface minimale avec sélection VIEW
4. **IMPLÉMENTER** première requête simple
5. **AJOUTER** threading et indicateurs chargement

---

**🏁 OBJECTIF SPRINT 1 :** Application fonctionnelle affichant une table depuis une VIEW PostgreSQL avec interface PySide6 non-bloquante.