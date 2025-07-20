"""
Preview Generator Mixin pour la génération de prévisualisations SQL
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class PreviewGeneratorMixin:
    """Mixin pour la génération de prévisualisations SQL et de données"""
    
    def _update_preview(self):
        """Met à jour l'aperçu SQL dans l'onglet prévisualisation"""
        try:
            view_def = self._create_view_definition()
            if not view_def:
                self._clear_preview()
                return
            
            # Générer le SQL
            sql_query = self._generate_sql_from_definition(view_def)
            
            # Mettre à jour l'aperçu
            self.sql_preview.setPlainText(sql_query)
            
            # Mettre à jour les informations
            self._update_preview_info(view_def)
            
        except Exception as e:
            logger.error(f"❌ Erreur mise à jour aperçu: {e}")
            self._clear_preview()
    
    def _generate_preview(self):
        """Génère et affiche la prévisualisation de la vue"""
        try:
            view_def = self._create_view_definition()
            if not view_def:
                self._show_error("Impossible de créer la définition de vue")
                return
            
            # Utiliser ViewBuilder si disponible
            if hasattr(self, 'view_builder') and self.view_builder:
                try:
                    sql_query = self.view_builder.build_sql(view_def)
                except Exception as e:
                    logger.warning(f"⚠️ ViewBuilder failed, using fallback: {e}")
                    sql_query = self._generate_sql_from_definition(view_def)
            else:
                sql_query = self._generate_sql_from_definition(view_def)
            
            # Mettre à jour l'aperçu
            self.sql_preview.setPlainText(sql_query)
            self._update_preview_info(view_def)
            
            # Basculer vers l'onglet prévisualisation
            self.tabs.setCurrentIndex(3)  # Index de l'onglet prévisualisation
            
            # Afficher un message de succès
            self._show_info("Prévisualisation générée avec succès!")
            
        except Exception as e:
            logger.error(f"❌ Erreur génération prévisualisation: {e}")
            self._show_error(f"Erreur lors de la génération: {str(e)}")
    
    def _generate_sql_from_definition(self, view_def: Dict[str, Any]) -> str:
        """Génère le SQL à partir d'une définition de vue (méthode fallback)"""
        try:
            # Construire la requête SELECT
            select_parts = []
            
            # Champ X avec groupement temporel si applicable
            x_field = view_def['x_field']
            grouping = view_def.get('grouping', '')
            
            if grouping and grouping != "-- Aucun groupement --":
                # Appliquer le groupement temporel
                if "jour" in grouping:
                    select_parts.append(f"DATE_TRUNC('day', {x_field}::timestamp) AS periode")
                elif "semaine" in grouping:
                    select_parts.append(f"DATE_TRUNC('week', {x_field}::timestamp) AS periode")
                elif "mois" in grouping:
                    select_parts.append(f"DATE_TRUNC('month', {x_field}::timestamp) AS periode")
                elif "trimestre" in grouping:
                    select_parts.append(f"DATE_TRUNC('quarter', {x_field}::timestamp) AS periode")
                elif "année" in grouping:
                    select_parts.append(f"DATE_TRUNC('year', {x_field}::timestamp) AS periode")
                else:
                    select_parts.append(f"{x_field} AS periode")
            else:
                select_parts.append(f"{x_field}")
            
            # Champs Y avec agrégations
            aggregations = view_def.get('aggregations', {})
            y_fields = view_def.get('y_fields', [])
            
            for i, y_field in enumerate(y_fields, 1):
                if y_field:
                    agg_key = f'y{i}'
                    agg = aggregations.get(agg_key, 'SUM')
                    
                    # Extraire la fonction d'agrégation
                    if ' - ' in agg:
                        agg_func = agg.split(' - ')[0].upper()
                    else:
                        agg_func = agg.upper()
                    
                    select_parts.append(f"{agg_func}({y_field}) AS {agg_func.lower()}_{y_field}")
            
            # Construire la clause FROM
            from_clause = view_def['main_table']
            
            # Construire la clause WHERE
            where_conditions = []
            
            # Filtres de date
            filters = view_def.get('filters', {})
            if filters.get('date_filter'):
                where_conditions.append(f"{x_field} IS NOT NULL")
                
                date_from = filters.get('date_from')
                date_to = filters.get('date_to')
                if date_from:
                    where_conditions.append(f"{x_field} >= '{date_from}'")
                if date_to:
                    where_conditions.append(f"{x_field} <= '{date_to}'")
            
            # Filtres de valeur
            if filters.get('min_value') is not None:
                # Appliquer sur le premier champ Y
                if y_fields and y_fields[0]:
                    where_conditions.append(f"{y_fields[0]} >= {filters['min_value']}")
            
            if filters.get('max_value') is not None:
                # Appliquer sur le premier champ Y
                if y_fields and y_fields[0]:
                    where_conditions.append(f"{y_fields[0]} <= {filters['max_value']}")
            
            # Filtres de texte
            if filters.get('contains_text'):
                # Appliquer sur les champs texte (simplification)
                text_filter = filters['contains_text']
                where_conditions.append(f"CAST({x_field} AS TEXT) ILIKE '%{text_filter}%'")
            
            # Construire la requête complète
            sql_parts = [
                f"CREATE OR REPLACE VIEW {view_def['name']} AS",
                f"SELECT {', '.join(select_parts)}",
                f"FROM {from_clause}"
            ]
            
            if where_conditions:
                sql_parts.append(f"WHERE {' AND '.join(where_conditions)}")
            
            # GROUP BY si nécessaire
            if grouping and grouping != "-- Aucun groupement --":
                sql_parts.append("GROUP BY periode")
                sql_parts.append("ORDER BY periode DESC")
            
            return "\n".join(sql_parts) + ";"
            
        except Exception as e:
            logger.error(f"❌ Erreur génération SQL: {e}")
            return f"-- Erreur lors de la génération SQL: {str(e)}"
    
    def _update_preview_info(self, view_def: Dict[str, Any]):
        """Met à jour les informations de la vue dans l'aperçu"""
        try:
            info_lines = []
            
            # Informations de base
            info_lines.append(f"📋 Nom de la vue: {view_def['name']}")
            info_lines.append(f"🗃️ Table principale: {view_def['main_table']}")
            info_lines.append(f"📊 Champ X: {view_def['x_field']}")
            
            # Champs Y
            y_fields = view_def.get('y_fields', [])
            aggregations = view_def.get('aggregations', {})
            
            for i, y_field in enumerate(y_fields, 1):
                if y_field:
                    agg = aggregations.get(f'y{i}', 'SUM')
                    info_lines.append(f"📈 Y{i}: {y_field} ({agg})")
            
            # Groupement
            grouping = view_def.get('grouping', '')
            if grouping and grouping != "-- Aucun groupement --":
                info_lines.append(f"📅 Groupement: {grouping}")
            
            # Filtres
            filters = view_def.get('filters', {})
            active_filters = []
            
            if filters.get('date_filter'):
                active_filters.append("Filtre par date")
            if filters.get('min_value') is not None:
                active_filters.append(f"Valeur min: {filters['min_value']}")
            if filters.get('max_value') is not None:
                active_filters.append(f"Valeur max: {filters['max_value']}")
            if filters.get('contains_text'):
                active_filters.append(f"Contient: '{filters['contains_text']}'")
            
            if active_filters:
                info_lines.append(f"🔍 Filtres actifs: {', '.join(active_filters)}")
            
            # Calculs dérivés
            derived_calcs = []
            if view_def.get('calc_evolution'):
                derived_calcs.append("Évolution %")
            if view_def.get('calc_ratio'):
                derived_calcs.append("Ratio Y1/Y2")
            if view_def.get('calc_mobile'):
                period = view_def.get('mobile_period', 7)
                derived_calcs.append(f"Moyenne mobile ({period})")
            
            if derived_calcs:
                info_lines.append(f"📈 Calculs dérivés: {', '.join(derived_calcs)}")
            
            # Timestamp de génération
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            info_lines.append(f"⏰ Généré le: {timestamp}")
            
            self.info_label.setText("\n".join(info_lines))
            
        except Exception as e:
            logger.error(f"❌ Erreur mise à jour info aperçu: {e}")
            self.info_label.setText("Erreur lors de la mise à jour des informations")
    
    def _clear_preview(self):
        """Efface l'aperçu"""
        self.sql_preview.setPlainText("-- Configurez les paramètres dans les autres onglets pour voir la requête SQL générée")
        self.info_label.setText("Configurez d'abord les paramètres...")
    
    def _create_view_definition(self) -> Optional[Dict[str, Any]]:
        """Crée une définition de vue à partir des paramètres de l'interface"""
        try:
            # Vérifier les éléments requis
            main_table = self.main_table_combo.currentData()
            x_field = self.x_field_combo.currentData()
            view_name = self.view_name_combo.currentText().strip()
            
            if not all([main_table, x_field, view_name]):
                return None
            
            # Récupérer les champs Y
            y_fields = []
            for i in range(1, 4):
                combo = getattr(self, f'y{i}_field_combo')
                field = combo.currentData()
                y_fields.append(field)
            
            # Récupérer les agrégations
            aggregations = {}
            for i in range(1, 4):
                combo = getattr(self, f'y{i}_agg_combo')
                agg = combo.currentText()
                if agg and not agg.startswith("--"):
                    aggregations[f'y{i}'] = agg
            
            # Récupérer les filtres
            filters = {}
            
            if self.enable_date_filter_check.isChecked():
                filters['date_filter'] = True
                filters['date_from'] = self.date_from_edit.date().toString("yyyy-MM-dd")
                filters['date_to'] = self.date_to_edit.date().toString("yyyy-MM-dd")
            
            if self.enable_min_filter_check.isChecked():
                min_text = self.min_value_edit.text().strip()
                if min_text:
                    try:
                        filters['min_value'] = float(min_text)
                    except ValueError:
                        pass
            
            if self.enable_max_filter_check.isChecked():
                max_text = self.max_value_edit.text().strip()
                if max_text:
                    try:
                        filters['max_value'] = float(max_text)
                    except ValueError:
                        pass
            
            if self.enable_contains_filter_check.isChecked():
                contains_text = self.contains_text_edit.text().strip()
                if contains_text:
                    filters['contains_text'] = contains_text
            
            # Récupérer les calculs dérivés
            calc_evolution = self.calc_evolution_check.isChecked()
            calc_ratio = self.calc_ratio_check.isChecked()
            calc_mobile = self.calc_mobile_check.isChecked()
            mobile_period = self.mobile_period_spin.value() if calc_mobile else None
            
            # Construire la définition
            view_def = {
                'name': view_name,
                'main_table': main_table,
                'x_field': x_field,
                'y_fields': y_fields,
                'aggregations': aggregations,
                'grouping': self.grouping_combo.currentText(),
                'filters': filters,
                'calc_evolution': calc_evolution,
                'calc_ratio': calc_ratio,
                'calc_mobile': calc_mobile,
                'mobile_period': mobile_period
            }
            
            return view_def
            
        except Exception as e:
            logger.error(f"❌ Erreur création définition vue: {e}")
            return None
    
    def _preview_view_data(self):
        """Prévisualise les données d'une vue existante depuis la base de données"""
        if not self.has_database_connection():
            self._show_warning("Aucune connexion à la base de données disponible")
            return
        
        try:
            # Récupérer la vue sélectionnée
            selected_view = self.views_combo.currentData()
            if not selected_view:
                self._show_warning("Aucune vue sélectionnée")
                return
            
            view_name = selected_view.get('name', '')
            if not view_name:
                self._show_warning("Nom de vue invalide")
                return
            
            # Exécuter la requête de prévisualisation
            preview_query = f"SELECT * FROM {view_name} LIMIT 100"
            
            try:
                df = self.database_manager.execute_query(preview_query)
                
                if df is not None and not df.empty:
                    self._show_data_preview(df, view_name)
                else:
                    self._show_info("La vue est vide ou n'existe pas")
                    
            except Exception as e:
                logger.error(f"❌ Erreur exécution requête prévisualisation: {e}")
                self._show_error(f"Erreur lors de l'exécution de la requête: {str(e)}")
        
        except Exception as e:
            logger.error(f"❌ Erreur prévisualisation données vue: {e}")
            self._show_error(f"Erreur lors de la prévisualisation: {str(e)}")
    
    def _show_data_preview(self, df, view_name: str):
        """Affiche un aperçu des données dans une nouvelle fenêtre"""
        try:
            from PySide6.QtWidgets import QDialog, QVBoxLayout, QTableWidget, QTableWidgetItem, QHeaderView, QPushButton, QLabel
            
            # Créer la fenêtre de prévisualisation
            preview_dialog = QDialog(self)
            preview_dialog.setWindowTitle(f"Aperçu des données - {view_name}")
            preview_dialog.setMinimumSize(800, 600)
            
            layout = QVBoxLayout()
            
            # Titre
            title_label = QLabel(f"📊 Aperçu des données de la vue: {view_name}")
            title_label.setStyleSheet("font-weight: bold; font-size: 14px; margin: 10px;")
            layout.addWidget(title_label)
            
            # Informations sur les données
            info_label = QLabel(f"📈 {len(df)} lignes × {len(df.columns)} colonnes")
            info_label.setStyleSheet("color: #666666; margin: 5px 10px;")
            layout.addWidget(info_label)
            
            # Table des données
            table = QTableWidget()
            table.setRowCount(len(df))
            table.setColumnCount(len(df.columns))
            table.setHorizontalHeaderLabels(df.columns.tolist())
            
            # Remplir la table
            for i, row in df.iterrows():
                for j, value in enumerate(row):
                    item = QTableWidgetItem(str(value))
                    table.setItem(i, j, item)
            
            # Ajuster les colonnes
            table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeToContents)
            layout.addWidget(table)
            
            # Bouton fermer
            close_btn = QPushButton("Fermer")
            close_btn.clicked.connect(preview_dialog.accept)
            layout.addWidget(close_btn)
            
            preview_dialog.setLayout(layout)
            preview_dialog.exec()
            
        except Exception as e:
            logger.error(f"❌ Erreur affichage aperçu données: {e}")
            self._show_error(f"Erreur lors de l'affichage: {str(e)}")
    
    def _show_info(self, message: str):
        """Affiche un message d'information"""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.information(self, "Information", message)
    
    def _show_warning(self, message: str):
        """Affiche un message d'avertissement"""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.warning(self, "Avertissement", message)
    
    def _show_error(self, message: str):
        """Affiche un message d'erreur"""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.critical(self, "Erreur", message)
