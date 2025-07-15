"""
Interface principale de l'application - Fenêtre Qt principale
"""

import logging
from typing import Optional

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from PySide6.QtCore import QDateTime, Qt, Signal
from PySide6.QtGui import QFont, QStandardItem, QStandardItemModel
from PySide6.QtWidgets import (
    QComboBox,
    QDateTimeEdit,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSplitter,
    QTableView,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

logger = logging.getLogger(__name__)


class MainWindow(QMainWindow):
    """Main window of the BI application"""

    # Signaux émis vers le contrôleur
    report_selected = Signal(str)  # Nom de la VIEW sélectionnée
    generate_clicked = Signal(dict)  # Paramètres complets d'analyse
    filters_changed = Signal(dict)  # Changement de filtres
    view_structure_requested = Signal(str)  # Demande structure VIEW

    def __init__(self):
        super().__init__()
        self.current_data = pd.DataFrame()  # Données actuelles
        self.setup_ui()
        self.setup_connections()
        logger.info("🎨 Main interface initialized")

    def setup_ui(self):
        """Complete user interface configuration"""
        self.setWindowTitle(self.tr("📊 BI Reporting Module - Software Suite"))

        # Configuration taille Full HD (1920x1080)
        self.resize(1920, 1080)
        self.setMinimumSize(1400, 900)

        # Centrer la fenêtre sur l'écran
        from PySide6.QtWidgets import QApplication

        screen = QApplication.primaryScreen()
        if screen:
            screen_geometry = screen.geometry()
            window_geometry = self.frameGeometry()
            center_point = screen_geometry.center()
            window_geometry.moveCenter(center_point)
            self.move(window_geometry.topLeft())

        # Widget central
        central_widget = QWidget()
        self.setCentralWidget(central_widget)

        # Layout principal
        main_layout = QVBoxLayout(central_widget)
        main_layout.setSpacing(10)
        main_layout.setContentsMargins(10, 10, 10, 10)

        # === PANNEAU DE CONTRÔLE ===
        control_panel = self.create_control_panel()
        main_layout.addWidget(control_panel)

        # === ZONE D'AFFICHAGE ===
        display_area = self.create_display_area()
        main_layout.addWidget(display_area)

        # === BARRE DE STATUT ===
        self.create_status_bar()

        # Style par défaut
        self.setStyleSheet(
            """
            QMainWindow {
                background-color: #f5f5f5;
            }
            QComboBox, QDateTimeEdit, QPushButton {
                padding: 5px;
                border: 1px solid #ccc;
                border-radius: 3px;
            }
            QPushButton {
                background-color: #4CAF50;
                color: white;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #45a049;
            }
            QPushButton:disabled {
                background-color: #cccccc;
                color: #666666;
            }
        """
        )

    def create_control_panel(self) -> QWidget:
        """Création du panneau de contrôle avec filtres"""
        panel = QWidget()
        panel.setMaximumHeight(100)
        layout = QHBoxLayout(panel)
        layout.setSpacing(15)

        # === SÉLECTION RAPPORT ===
        layout.addWidget(QLabel(self.tr("📋 Report:")))
        self.combo_views = QComboBox()
        self.combo_views.setMinimumWidth(350)
        self.combo_views.setToolTip(self.tr("Select the report to analyze"))
        layout.addWidget(self.combo_views)

        layout.addSpacing(20)

        # === FILTRES DATES ===
        layout.addWidget(QLabel(self.tr("📅 From:")))
        self.date_start = QDateTimeEdit()
        self.date_start.setDisplayFormat("dd/MM/yyyy")
        self.date_start.setDateTime(QDateTime.currentDateTime().addDays(-30))
        self.date_start.setCalendarPopup(True)
        layout.addWidget(self.date_start)

        layout.addWidget(QLabel(self.tr("To:")))
        self.date_end = QDateTimeEdit()
        self.date_end.setDisplayFormat("dd/MM/yyyy")
        self.date_end.setDateTime(QDateTime.currentDateTime())
        self.date_end.setCalendarPopup(True)
        layout.addWidget(self.date_end)

        layout.addSpacing(20)

        # === BOUTONS ACTIONS ===
        self.btn_generate = QPushButton(self.tr("🔄 Generate Analysis"))
        self.btn_generate.setMinimumHeight(40)
        self.btn_generate.setMinimumWidth(150)
        self.btn_generate.setToolTip(self.tr("Run analysis with current parameters"))
        layout.addWidget(self.btn_generate)

        self.btn_refresh = QPushButton(self.tr("♻️ Refresh"))
        self.btn_refresh.setMinimumHeight(40)
        self.btn_refresh.setToolTip(self.tr("Refresh reports list"))
        layout.addWidget(self.btn_refresh)

        self.btn_export = QPushButton(self.tr("📊 Export"))
        self.btn_export.setMinimumHeight(40)
        self.btn_export.setEnabled(False)
        self.btn_export.setToolTip(self.tr("Export current data"))
        layout.addWidget(self.btn_export)

        layout.addStretch()

        # === INDICATEUR CHARGEMENT ===
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setMinimumWidth(200)
        layout.addWidget(self.progress_bar)

        return panel

    def create_display_area(self) -> QWidget:
        """Création de la zone d'affichage avec onglets"""
        # Splitter principal pour redimensionnement
        main_splitter = QSplitter(Qt.Vertical)

        # === ONGLETS PRINCIPAUX ===
        self.tab_widget = QTabWidget()

        # Onglet Table de données
        self.setup_data_tab()

        # Onglet Graphiques
        self.setup_chart_tab()

        # Onglet Informations
        self.setup_info_tab()

        main_splitter.addWidget(self.tab_widget)
        main_splitter.setSizes([600])

        return main_splitter

    def setup_data_tab(self):
        """Configuration de l'onglet données tabulaires"""
        # Modèle de données
        self.table_view = QTableView()
        self.table_model = QStandardItemModel()
        self.table_view.setModel(self.table_model)

        # Configuration affichage
        self.table_view.setAlternatingRowColors(True)
        self.table_view.setSortingEnabled(True)
        self.table_view.horizontalHeader().setSectionResizeMode(QHeaderView.Interactive)
        self.table_view.setSelectionBehavior(QTableView.SelectRows)

        self.tab_widget.addTab(self.table_view, self.tr("📋 Data"))

    def setup_chart_tab(self):
        """Configuration de l'onglet graphiques"""
        chart_widget = QWidget()
        layout = QVBoxLayout(chart_widget)

        # === CONTRÔLES GRAPHIQUE SUR UNE LIGNE ===
        controls_frame = QWidget()
        controls_layout = QHBoxLayout(controls_frame)  # Une seule ligne horizontale
        controls_frame.setMaximumHeight(60)

        # Type de graphique
        controls_layout.addWidget(QLabel(self.tr("📊 Type:")))
        self.combo_chart_type = QComboBox()
        self.combo_chart_type.addItems(
            [
                self.tr("Line"),
                self.tr("Bars"),
                self.tr("Pie"),
                self.tr("Histogram"),
                self.tr("Scatter"),
            ]
        )
        self.combo_chart_type.setMinimumWidth(120)
        controls_layout.addWidget(self.combo_chart_type)

        controls_layout.addSpacing(15)

        # Colonne X (obligatoire)
        controls_layout.addWidget(QLabel(self.tr("📐 X:")))
        self.combo_column_x = QComboBox()
        self.combo_column_x.setMinimumWidth(150)
        self.combo_column_x.setToolTip(self.tr("Select the column for X axis"))
        controls_layout.addWidget(self.combo_column_x)

        controls_layout.addSpacing(10)

        # Colonne Y1 (obligatoire)
        controls_layout.addWidget(QLabel(self.tr("📈 Y1:")))
        self.combo_column_y1 = QComboBox()
        self.combo_column_y1.setMinimumWidth(150)
        self.combo_column_y1.setToolTip(self.tr("Main column for Y axis"))
        controls_layout.addWidget(self.combo_column_y1)

        controls_layout.addSpacing(10)

        # Colonne Y2 (optionnelle)
        controls_layout.addWidget(QLabel(self.tr("📊 Y2:")))
        self.combo_column_y2 = QComboBox()
        self.combo_column_y2.setMinimumWidth(150)
        self.combo_column_y2.setToolTip(self.tr("Optional column for second Y axis"))
        controls_layout.addWidget(self.combo_column_y2)

        controls_layout.addSpacing(10)

        # Colonne Y3 (optionnelle)
        controls_layout.addWidget(QLabel(self.tr("📉 Y3:")))
        self.combo_column_y3 = QComboBox()
        self.combo_column_y3.setMinimumWidth(150)
        self.combo_column_y3.setToolTip(self.tr("Optional column for third Y axis"))
        controls_layout.addWidget(self.combo_column_y3)

        controls_layout.addSpacing(20)

        # Bouton de génération
        self.btn_generate_chart = QPushButton(self.tr("🎨 Generate"))
        self.btn_generate_chart.setMinimumHeight(35)
        self.btn_generate_chart.setMinimumWidth(120)
        self.btn_generate_chart.setToolTip(
            self.tr("Generate chart with selected columns")
        )
        controls_layout.addWidget(self.btn_generate_chart)

        # Checkbox auto-refresh
        from PySide6.QtWidgets import QCheckBox

        self.checkbox_auto_refresh = QCheckBox(self.tr("Auto"))
        self.checkbox_auto_refresh.setChecked(True)
        self.checkbox_auto_refresh.setToolTip(self.tr("Automatic chart refresh"))
        controls_layout.addWidget(self.checkbox_auto_refresh)

        controls_layout.addStretch()

        layout.addWidget(controls_frame)

        # === ZONE MATPLOTLIB ===
        self.figure = Figure(figsize=(15, 8))
        self.canvas = FigureCanvas(self.figure)
        layout.addWidget(self.canvas)

        self.tab_widget.addTab(chart_widget, "📈 Graphiques")

    def setup_info_tab(self):
        """Configuration de l'onglet informations"""
        info_widget = QWidget()
        layout = QVBoxLayout(info_widget)

        self.info_label = QLabel(self.tr("ℹ️ Select a report to see information"))
        self.info_label.setWordWrap(True)
        self.info_label.setAlignment(Qt.AlignTop)
        layout.addWidget(self.info_label)

        layout.addStretch()
        self.tab_widget.addTab(info_widget, "ℹ️ Informations")

    def create_status_bar(self):
        """Création de la barre de statut"""
        status_bar = self.statusBar()

        self.lbl_status = QLabel(self.tr("Ready"))
        self.lbl_connection = QLabel(self.tr("🔌 Disconnected"))
        self.lbl_row_count = QLabel("0 lignes")
        self.lbl_view_count = QLabel("0 rapports")

        status_bar.addWidget(self.lbl_status)
        status_bar.addPermanentWidget(self.lbl_view_count)
        status_bar.addPermanentWidget(self.lbl_row_count)
        status_bar.addPermanentWidget(self.lbl_connection)

    def setup_connections(self):
        """Configuration des connexions de signaux internes"""
        # Changements de sélection
        self.combo_views.currentTextChanged.connect(
            lambda text: self.report_selected.emit(text) if text else None
        )

        # Actions utilisateur
        self.btn_generate.clicked.connect(self.on_generate_clicked)
        self.btn_refresh.clicked.connect(self.on_refresh_clicked)

        # Changements de filtres
        self.date_start.dateTimeChanged.connect(self.on_filters_changed)
        self.date_end.dateTimeChanged.connect(self.on_filters_changed)

        # Changement type graphique
        self.combo_chart_type.currentTextChanged.connect(self.on_chart_type_changed)

        # === NOUVEAUX CONTRÔLES GRAPHIQUES ===
        # Génération manuelle de graphique
        self.btn_generate_chart.clicked.connect(self.on_generate_chart_clicked)

        # Changements de colonnes (actualisation automatique si activée)
        self.combo_column_x.currentTextChanged.connect(self.on_column_selection_changed)
        self.combo_column_y1.currentTextChanged.connect(
            self.on_column_selection_changed
        )
        self.combo_column_y2.currentTextChanged.connect(
            self.on_column_selection_changed
        )
        self.combo_column_y3.currentTextChanged.connect(
            self.on_column_selection_changed
        )

    # === SLOTS INTERNES ===

    def on_generate_clicked(self):
        """Gestion du clic sur Générer"""
        if not self.combo_views.currentText():
            self.show_warning(self.tr("Please select a report"))
            return

        params = {
            "view_name": self.combo_views.currentText(),
            "date_start": self.date_start.dateTime().toPython(),
            "date_end": self.date_end.dateTime().toPython(),
            "filters": self.get_current_filters(),
        }
        self.generate_clicked.emit(params)

    def on_refresh_clicked(self):
        """Gestion du clic sur Actualiser"""
        # Signal pour actualiser les VIEWs
        self.view_structure_requested.emit("refresh")

    def on_filters_changed(self):
        """Gestion du changement des filtres"""
        filters = self.get_current_filters()
        self.filters_changed.emit(filters)

    def on_chart_type_changed(self):
        """Gestion du changement de type de graphique"""
        if not self.current_data.empty:
            self.display_chart(self.current_data, self.get_chart_type())

    def on_generate_chart_clicked(self):
        """Gestion du clic sur génération manuelle de graphique"""
        if self.current_data.empty:
            self.show_warning(self.tr("No data available to generate a chart"))
            return

        # Validation des colonnes sélectionnées
        if (
            not self.combo_column_x.currentText()
            or not self.combo_column_y1.currentText()
        ):
            self.show_warning(self.tr("Please select at least X and Y1 columns"))
            return

        # Génération du graphique avec les colonnes sélectionnées
        self.display_chart_with_columns()

    def on_column_selection_changed(self):
        """Gestion du changement de sélection de colonnes"""
        # Log pour debug
        x_col = self.combo_column_x.currentText()
        y1_col = self.combo_column_y1.currentText()
        logger.debug(f"Colonnes changées: X='{x_col}', Y1='{y1_col}'")

        # Actualisation automatique si activée
        if (
            hasattr(self, "checkbox_auto_refresh")
            and self.checkbox_auto_refresh.isChecked()
            and not self.current_data.empty
            and self.combo_column_x.currentText()
            and self.combo_column_y1.currentText()
        ):
            logger.debug("Auto-refresh activé, génération du graphique...")
            self.display_chart_with_columns()

    def get_current_filters(self) -> dict:
        """Récupération des filtres actuels"""
        return {
            "date_start": self.date_start.dateTime().toPython(),
            "date_end": self.date_end.dateTime().toPython(),
        }

    def get_chart_type(self) -> str:
        """Chart type conversion for matplotlib"""
        mapping = {
            "Line": "line",
            "Bars": "bar",
            "Pie": "pie",
            "Histogram": "hist",
            "Scatter": "scatter",
            # Support pour les anciens noms français si encore présents
            "Ligne": "line",
            "Barres": "bar",
            "Secteurs": "pie",
            "Histogramme": "hist",
            "Nuage de points": "scatter",
        }
        current_text = self.combo_chart_type.currentText()
        return mapping.get(current_text, "line")

    # === MÉTHODES PUBLIQUES POUR LE CONTRÔLEUR ===

    def populate_views(self, views_list: list):
        """Populate the list of available reports"""
        self.combo_views.clear()

        if not views_list:
            self.combo_views.addItem(self.tr("No reports available"))
            self.lbl_view_count.setText(self.tr("0 reports"))
            return

        for view_info in views_list:
            display_text = f"{view_info['name']} ({view_info['column_count']} columns)"
            self.combo_views.addItem(display_text, view_info["name"])

        self.lbl_view_count.setText(self.tr(f"{len(views_list)} reports"))
        logger.info(f"🔄 {len(views_list)} reports loaded in interface")

    def show_loading(self, message: str = "Loading..."):
        """Display loading indicator"""
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)  # Mode indéterminé
        self.lbl_status.setText(message)
        self.btn_generate.setEnabled(False)
        self.btn_refresh.setEnabled(False)

    def hide_loading(self):
        """Hide loading indicator"""
        self.progress_bar.setVisible(False)
        self.btn_generate.setEnabled(True)
        self.btn_refresh.setEnabled(True)
        self.lbl_status.setText(self.tr("Ready"))

    def display_data(self, dataframe: pd.DataFrame):
        """Display data in the table"""
        try:
            # Sauvegarde des données actuelles
            self.current_data = dataframe.copy()

            # === POPULATION DES SÉLECTEURS DE COLONNES ===
            self.populate_column_selectors(dataframe)

            # Nettoyage du modèle
            self.table_model.clear()

            if dataframe.empty:
                self.lbl_row_count.setText(self.tr("No data"))
                self.btn_export.setEnabled(False)
                return

            # Configuration des en-têtes
            headers = list(dataframe.columns)
            self.table_model.setHorizontalHeaderLabels(headers)

            # Limitation d'affichage pour performance
            display_limit = 1000
            display_df = dataframe.head(display_limit)

            # Remplissage des données - Using efficient itertuples instead of iterrows
            for row_data in display_df.itertuples(index=False, name=None):
                items = []
                for col_val in row_data:
                    # Formatage des valeurs
                    if pd.isna(col_val):
                        display_val = ""
                    elif isinstance(col_val, float):
                        display_val = f"{col_val:.2f}"
                    else:
                        display_val = str(col_val)

                    item = QStandardItem(display_val)
                    items.append(item)
                self.table_model.appendRow(items)

            # Ajustement automatique des colonnes
            self.table_view.resizeColumnsToContents()

            # Mise à jour des compteurs
            total_rows = len(dataframe)
            displayed_rows = len(display_df)

            if total_rows > displayed_rows:
                self.lbl_row_count.setText(
                    self.tr(f"{displayed_rows}/{total_rows} rows (limited)")
                )
            else:
                self.lbl_row_count.setText(f"{total_rows} rows")

            self.btn_export.setEnabled(True)

            # === GÉNÉRATION AUTOMATIQUE DU GRAPHIQUE ===
            # Si l'auto-refresh est activé et que des colonnes sont sélectionnées
            if (
                hasattr(self, "checkbox_auto_refresh")
                and self.checkbox_auto_refresh.isChecked()
            ):
                self.display_chart_with_columns()
            else:
                # Sinon, graphique par défaut avec les 2 premières colonnes
                self.display_chart(dataframe, self.get_chart_type())

            logger.info(f"📊 Data displayed: {displayed_rows} rows")

        except Exception as e:
            logger.error(f"❌ Error displaying data: {e}")
            self.show_error(f"Display error: {e}")

    def display_chart(self, dataframe: pd.DataFrame, chart_type: str = "line"):
        """Generate and display chart"""
        try:
            self.figure.clear()

            if dataframe.empty:
                ax = self.figure.add_subplot(111)
                ax.text(
                    0.5,
                    0.5,
                    self.tr("No data to display"),
                    horizontalalignment="center",
                    verticalalignment="center",
                    transform=ax.transAxes,
                    fontsize=14,
                )
                self.canvas.draw()
                return

            ax = self.figure.add_subplot(111)

            # Sélection des colonnes pour le graphique
            if len(dataframe.columns) >= 2:
                x_col = dataframe.columns[0]
                y_col = dataframe.columns[1]

                if chart_type == "line":
                    ax.plot(dataframe[x_col], dataframe[y_col], marker="o")
                elif chart_type == "bar":
                    ax.bar(dataframe[x_col], dataframe[y_col])
                elif (
                    chart_type == "pie" and len(dataframe) <= 20
                ):  # Limite pour lisibilité
                    ax.pie(dataframe[y_col], labels=dataframe[x_col], autopct="%1.1f%%")
                elif chart_type == "hist":
                    ax.hist(dataframe[y_col], bins=20)
                else:
                    # Fallback sur graphique en ligne
                    ax.plot(dataframe[x_col], dataframe[y_col], marker="o")

                ax.set_xlabel(x_col)
                if chart_type != "pie":
                    ax.set_ylabel(y_col)
                ax.set_title(f"Analysis: {x_col} vs {y_col}")
            else:
                ax.text(
                    0.5,
                    0.5,
                    self.tr("Insufficient data for chart"),
                    horizontalalignment="center",
                    verticalalignment="center",
                    transform=ax.transAxes,
                    fontsize=12,
                )

            self.figure.tight_layout()
            self.canvas.draw()

        except Exception as e:
            logger.error(f"❌ Error generating chart: {e}")
            # Affichage d'un message d'erreur sur le graphique
            self.figure.clear()
            ax = self.figure.add_subplot(111)
            ax.text(
                0.5,
                0.5,
                f"Chart error: {str(e)}",
                horizontalalignment="center",
                verticalalignment="center",
                transform=ax.transAxes,
                fontsize=10,
                color="red",
            )
            self.canvas.draw()

    def populate_column_selectors(self, dataframe: pd.DataFrame):
        """Populate column selectors with DataFrame headers"""
        if dataframe.empty:
            # Vider les combobox si pas de données
            for combo in [
                self.combo_column_x,
                self.combo_column_y1,
                self.combo_column_y2,
                self.combo_column_y3,
            ]:
                combo.clear()
                combo.addItem(self.tr("-- No columns --"))
            return

        columns = list(dataframe.columns)

        # Nettoyage et remplissage des combobox
        for combo in [
            self.combo_column_x,
            self.combo_column_y1,
            self.combo_column_y2,
            self.combo_column_y3,
        ]:
            combo.clear()

        # ComboBox X - toutes les colonnes
        self.combo_column_x.addItem(self.tr("-- Select X --"))
        self.combo_column_x.addItems(columns)

        # ComboBox Y1 - toutes les colonnes
        self.combo_column_y1.addItem(self.tr("-- Select Y1 --"))
        self.combo_column_y1.addItems(columns)

        # ComboBox Y2 et Y3 - avec option "Aucune"
        for combo in [self.combo_column_y2, self.combo_column_y3]:
            combo.addItem(self.tr("-- None --"))
            combo.addItems(columns)

        # Sélection automatique intelligente si possible
        if len(columns) >= 2:
            # Auto-sélection de la première colonne pour X
            self.combo_column_x.setCurrentIndex(1)  # Index 1 = première vraie colonne
            # Auto-sélection de la deuxième colonne pour Y1
            self.combo_column_y1.setCurrentIndex(2)  # Index 2 = deuxième vraie colonne

        logger.info(f"🎯 Available columns for charts: {columns}")

    def display_chart_with_columns(self):
        """Generate a custom chart with selected columns"""
        try:
            if self.current_data is None or self.current_data.empty:
                logger.warning("⚠️ No data available for chart")
                return

            # === GÉNÉRATION DU DATAFRAME FILTRÉ ENTRE DATES ===
            filtered_df = self.current_data.copy()

            # Récupération des dates de filtrage
            start_date = self.date_start.date().toPython()
            end_date = self.date_end.date().toPython()

            # Détection de la colonne de date dans le DataFrame
            date_columns = []
            for col in filtered_df.columns:
                if filtered_df[col].dtype in ["datetime64[ns]", "object"]:
                    try:
                        # Test de conversion en datetime
                        sample_val = (
                            filtered_df[col].dropna().iloc[0]
                            if not filtered_df[col].dropna().empty
                            else None
                        )
                        if (
                            sample_val
                            and pd.to_datetime(sample_val, errors="coerce")
                            is not pd.NaT
                        ):
                            date_columns.append(col)
                    except:
                        continue

            # Filtrage par dates si une colonne de date est trouvée
            if date_columns:
                date_col = date_columns[
                    0
                ]  # Utilisation de la première colonne de date trouvée
                try:
                    # Conversion en datetime si nécessaire
                    if filtered_df[date_col].dtype == "object":
                        filtered_df[date_col] = pd.to_datetime(
                            filtered_df[date_col], errors="coerce"
                        )

                    # Application du filtre
                    mask = (filtered_df[date_col].dt.date >= start_date) & (
                        filtered_df[date_col].dt.date <= end_date
                    )
                    filtered_df = filtered_df[mask]

                    logger.info(
                        f"📅 Date filtering: {len(filtered_df)} rows retained on column '{date_col}'"
                    )
                except Exception as e:
                    logger.warning(f"⚠️ Unable to filter by dates: {e}")
            else:
                logger.info("ℹ️ No date column detected, displaying without time filter")

            if filtered_df.empty:
                self.show_error(self.tr("No data in selected date range"))
                return

            # === RÉCUPÉRATION DES COLONNES SÉLECTIONNÉES ===
            x_column = self.combo_column_x.currentText()
            y_columns = []

            # Collecte des colonnes Y sélectionnées (non vides)
            for combo in [
                self.combo_column_y1,
                self.combo_column_y2,
                self.combo_column_y3,
            ]:
                y_col = combo.currentText()
                if y_col and not y_col.startswith("--"):
                    y_columns.append(y_col)

            if not x_column or x_column.startswith("--") or not y_columns:
                logger.debug(f"Selection invalide: X='{x_column}', Y={y_columns}")
                return  # Retour silencieux pour éviter les messages répétitifs

            # === GÉNÉRATION DU GRAPHIQUE ===
            self.figure.clear()
            ax1 = self.figure.add_subplot(111)  # Axe principal (gauche)

            # Configuration selon le type de graphique
            chart_type = self.combo_chart_type.currentText()
            logger.debug(f"Type de graphique sélectionné: '{chart_type}'")

            colors = ["#2E86AB", "#A23B72", "#F18F01", "#C73E1D"]  # Palette de couleurs

            # Variables pour gérer les axes multiples
            ax2 = None  # Axe secondaire (droite)
            left_axis_series = []  # Séries pour axe gauche
            right_axis_series = []  # Séries pour axe droite

            # === RÉPARTITION DES SÉRIES SUR LES AXES ===
            # Stratégie: 2 premières séries à gauche, 3ème à droite
            for i, y_col in enumerate(y_columns):
                if i < 2:  # Y1 et Y2 à gauche
                    left_axis_series.append((i, y_col))
                else:  # Y3 à droite
                    right_axis_series.append((i, y_col))

            # === CRÉATION DE L'AXE SECONDAIRE SI NÉCESSAIRE ===
            if right_axis_series:
                ax2 = ax1.twinx()  # Création de l'axe Y secondaire (droite)

            # === TRACÉ DES SÉRIES SUR L'AXE GAUCHE ===
            for i, y_col in left_axis_series:
                color = colors[i % len(colors)]

                try:
                    # Nettoyage des données (suppression des NaN)
                    clean_data = filtered_df[[x_column, y_col]].dropna()

                    if clean_data.empty:
                        continue

                    x_data = clean_data[x_column]
                    y_data = clean_data[y_col]

                    # Conversion du type pour matplotlib
                    matplotlib_type = self.get_chart_type()
                    logger.debug(
                        f"Type matplotlib: '{matplotlib_type}' pour colonne {y_col}"
                    )

                    if matplotlib_type == "line":
                        line = ax1.plot(
                            x_data,
                            y_data,
                            marker="o",
                            color=color,
                            label=f"{y_col} (L)",
                            linewidth=2,
                            markersize=4,
                        )
                    elif matplotlib_type == "bar":
                        # Pour les barres multiples sur le même axe, décalage
                        bar_width = 0.35  # Largeur réduite pour permettre les groupes
                        x_pos = range(len(x_data))
                        offset = (i - 0.5) * bar_width
                        ax1.bar(
                            [x + offset for x in x_pos],
                            y_data,
                            bar_width,
                            color=color,
                            label=f"{y_col} (L)",
                            alpha=0.8,
                        )
                        if i == 0:  # Seulement pour la première série
                            ax1.set_xticks(x_pos)
                            ax1.set_xticklabels(x_data)
                    elif matplotlib_type == "scatter":
                        ax1.scatter(
                            x_data,
                            y_data,
                            color=color,
                            label=f"{y_col} (L)",
                            s=60,
                            alpha=0.7,
                        )

                except Exception as e:
                    logger.warning(f"⚠️ Error for column {y_col} (left axis): {e}")
                    continue

            # === TRACÉ DES SÉRIES SUR L'AXE DROIT ===
            if ax2 and right_axis_series:
                for i, y_col in right_axis_series:
                    color = colors[i % len(colors)]

                    try:
                        # Nettoyage des données (suppression des NaN)
                        clean_data = filtered_df[[x_column, y_col]].dropna()

                        if clean_data.empty:
                            continue

                        x_data = clean_data[x_column]
                        y_data = clean_data[y_col]

                        # Conversion du type pour matplotlib
                        matplotlib_type = self.get_chart_type()

                        if matplotlib_type == "line":
                            line = ax2.plot(
                                x_data,
                                y_data,
                                marker="s",
                                color=color,
                                label=f"{y_col} (R)",
                                linewidth=2,
                                markersize=4,
                                linestyle="--",
                            )
                        elif matplotlib_type == "bar":
                            # Barres pour axe droit avec offset différent
                            bar_width = 0.35
                            x_pos = range(len(x_data))
                            offset = 0.35  # Décalage pour axe droit
                            ax2.bar(
                                [x + offset for x in x_pos],
                                y_data,
                                bar_width,
                                color=color,
                                label=f"{y_col} (R)",
                                alpha=0.6,
                            )
                        elif matplotlib_type == "scatter":
                            ax2.scatter(
                                x_data,
                                y_data,
                                color=color,
                                label=f"{y_col} (R)",
                                s=60,
                                alpha=0.7,
                                marker="^",
                            )

                    except Exception as e:
                        logger.warning(f"⚠️ Error for column {y_col} (right axis): {e}")
                        continue

            # === CONFIGURATION DU GRAPHIQUE ===
            # Configuration de l'axe principal (gauche)
            ax1.set_xlabel(x_column, fontsize=12, fontweight="bold")
            ax1.set_ylabel(
                self.tr("Values (Left Axis)"),
                fontsize=12,
                fontweight="bold",
                color="#2E86AB",
            )
            ax1.set_title(
                f"{chart_type} Chart - Period from {start_date} to {end_date}",
                fontsize=14,
                fontweight="bold",
                pad=20,
            )

            # Configuration de l'axe secondaire (droite) si présent
            if ax2:
                ax2.set_ylabel(
                    self.tr("Values (Right Axis)"),
                    fontsize=12,
                    fontweight="bold",
                    color="#F18F01",
                )
                # Couleur des graduations de l'axe droit
                ax2.tick_params(axis="y", labelcolor="#F18F01")
                ax2.yaxis.label.set_color("#F18F01")

            # Couleur des graduations de l'axe gauche
            ax1.tick_params(axis="y", labelcolor="#2E86AB")
            ax1.yaxis.label.set_color("#2E86AB")

            # === LÉGENDES COMBINÉES ===
            # Récupération des légendes des deux axes
            lines1, labels1 = ax1.get_legend_handles_labels()
            lines2, labels2 = ax2.get_legend_handles_labels() if ax2 else ([], [])

            # Combinaison des légendes - TOUJOURS afficher si on a des séries
            if lines1 or lines2:
                all_lines = lines1 + lines2
                all_labels = labels1 + labels2
                ax1.legend(
                    all_lines,
                    all_labels,
                    loc="upper left",
                    frameon=True,
                    fancybox=True,
                    shadow=True,
                    fontsize=10,
                )

            # Grille sur l'axe principal
            ax1.grid(True, alpha=0.3, linestyle="--")

            # Rotation des labels X si nombreux
            if len(x_data) > 10:
                plt.setp(ax1.get_xticklabels(), rotation=45, ha="right")

            # Ajustement du layout
            self.figure.tight_layout()
            self.canvas.draw()

            logger.info(
                f"📈 Chart generated: {len(y_columns)} series, {len(filtered_df)} points"
            )

        except Exception as e:
            logger.error(f"❌ Error generating custom chart: {e}")
            self.show_error(f"Chart generation error: {e}")

    def update_connection_status(self, connected: bool, info: Optional[dict] = None):
        """Update connection status"""
        if connected:
            self.lbl_connection.setText(self.tr("🟢 Connected"))
            if info:
                tooltip = f"Host: {info.get('host', 'N/A')}\nDB: {info.get('database', 'N/A')}"
                self.lbl_connection.setToolTip(tooltip)
        else:
            self.lbl_connection.setText(self.tr("🔴 Disconnected"))
            self.lbl_connection.setToolTip(self.tr("Database connection failed"))

    def update_view_info(self, view_name: str, info: dict):
        """Update information for selected VIEW"""
        if "error" in info:
            self.info_label.setText(f"❌ Error: {info['error']}")
        else:
            structure = info.get("structure", {})
            columns = structure.get("columns", [])

            info_text = f"📋 Report: {view_name}\n\n"
            info_text += f"🏗️ Structure:\n"
            info_text += f"  - Number of columns: {len(columns)}\n\n"

            if columns:
                info_text += "📊 Available columns:\n"
                for col in columns[:10]:  # Limite à 10 pour l'affichage
                    info_text += f"  • {col['name']} ({col['type']})\n"

                if len(columns) > 10:
                    info_text += f"  ... and {len(columns) - 10} other columns\n"

            self.info_label.setText(info_text)

    # === DIALOGUES ET MESSAGES ===

    def show_error(self, message: str):
        """Display error message"""
        QMessageBox.critical(self, self.tr("❌ Error"), message)
        self.hide_loading()

    def show_warning(self, message: str):
        """Display warning message"""
        QMessageBox.warning(self, self.tr("⚠️ Warning"), message)

    def show_info(self, message: str):
        """Display information message"""
        QMessageBox.information(self, self.tr("ℹ️ Information"), message)
