"""
Review Manager Mixin pour la gestion des relectures de vues
"""

import logging
from datetime import datetime
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)


class ReviewManagerMixin:
    """Mixin pour la gestion des relectures et commentaires de vues"""
    
    def _refresh_views_list(self):
        """Actualise la liste des vues disponibles pour relecture"""
        try:
            self.views_combo.clear()
            self.views_combo.addItem("-- Sélectionner une vue --", None)
            
            # Charger les vues depuis la base de données si disponible
            if self.has_database_connection():
                self._load_database_views()
            
            # Ajouter les vues créées localement
            self._load_local_views()
            
            # Mettre à jour le compteur
            view_count = self.views_combo.count() - 1  # -1 pour l'item placeholder
            self.lbl_view_count.setText(f"{view_count} vue(s)")
            
            logger.info(f"📋 Liste des vues actualisée: {view_count} vues")
            
        except Exception as e:
            logger.error(f"❌ Erreur actualisation liste vues: {e}")
            self._show_error(f"Erreur lors de l'actualisation: {str(e)}")
    
    def _load_database_views(self):
        """Charge les vues depuis la base de données"""
        try:
            if hasattr(self, 'view_crud_manager') and self.view_crud_manager:
                # Utiliser ViewCrudManager si disponible
                db_views = self.view_crud_manager.get_all_views()
            else:
                # Fallback direct via DatabaseManager
                db_views = self._get_views_from_database()
            
            for view in db_views:
                view_name = view.get('name', 'Vue sans nom')
                display_text = f"🗃️ {view_name} (Base de données)"
                self.views_combo.addItem(display_text, view)
                
        except Exception as e:
            logger.warning(f"⚠️ Impossible de charger les vues de la base: {e}")
    
    def _get_views_from_database(self) -> List[Dict[str, Any]]:
        """Récupère les vues directement depuis la base de données (fallback)"""
        try:
            # Requête pour récupérer les vues utilisateur
            query = """
                SELECT schemaname, viewname, definition 
                FROM pg_views 
                WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
                ORDER BY viewname
            """
            
            df = self.database_manager.execute_query(query)
            views = []
            
            if df is not None and not df.empty:
                for _, row in df.iterrows():
                    views.append({
                        'name': row['viewname'],
                        'schema': row['schemaname'],
                        'definition': row['definition'],
                        'source': 'database'
                    })
            
            return views
            
        except Exception as e:
            logger.error(f"❌ Erreur récupération vues base: {e}")
            return []
    
    def _load_local_views(self):
        """Charge les vues créées localement"""
        try:
            for view in self.created_views:
                view_name = view.get('name', 'Vue sans nom')
                created_date = view.get('created_date', '')
                status = view.get('review_status', '📝 Brouillon')
                
                display_text = f"📝 {view_name} ({status}) - {created_date}"
                self.views_combo.addItem(display_text, view)
                
        except Exception as e:
            logger.error(f"❌ Erreur chargement vues locales: {e}")
    
    def _on_view_selected(self):
        """Gère la sélection d'une vue dans la liste"""
        try:
            selected_view = self.views_combo.currentData()
            
            if selected_view is None:
                self._clear_view_details()
                return
            
            # Afficher les détails de la vue
            self._display_view_details(selected_view)
            
            # Charger les informations de relecture si disponibles
            self._load_review_info(selected_view)
            
        except Exception as e:
            logger.error(f"❌ Erreur sélection vue: {e}")
            self._clear_view_details()
    
    def _display_view_details(self, view: Dict[str, Any]):
        """Affiche les détails d'une vue sélectionnée"""
        try:
            details = []
            
            # Informations de base
            details.append(f"📋 Nom: {view.get('name', 'N/A')}")
            details.append(f"📅 Créée le: {view.get('created_date', 'N/A')}")
            
            # Source de la vue
            source = view.get('source', 'local')
            if source == 'database':
                details.append(f"🗃️ Source: Base de données")
                details.append(f"📊 Schéma: {view.get('schema', 'N/A')}")
            else:
                details.append(f"📝 Source: Créée localement")
            
            # Données de configuration si disponibles
            data = view.get('data', {})
            if data:
                details.append(f"\n📊 Configuration:")
                details.append(f"  • Table principale: {data.get('main_table', 'N/A')}")
                details.append(f"  • Champ X: {data.get('x_field', 'N/A')}")
                
                y_fields = data.get('y_fields', [])
                y_fields_str = ', '.join([f for f in y_fields if f]) or 'N/A'
                details.append(f"  • Champs Y: {y_fields_str}")
                
                aggregations = data.get('aggregations', {})
                if aggregations:
                    agg_str = ', '.join([f"{k}:{v}" for k, v in aggregations.items()])
                    details.append(f"  • Agrégations: {agg_str}")
                
                grouping = data.get('grouping', '')
                if grouping and grouping != "-- Aucun groupement --":
                    details.append(f"  • Groupement: {grouping}")
            
            # SQL si disponible
            sql = view.get('sql') or data.get('sql')
            if sql:
                details.append(f"\n💻 Requête SQL:")
                # Limiter l'affichage du SQL pour éviter de surcharger
                sql_preview = sql[:500] + "..." if len(sql) > 500 else sql
                details.append(sql_preview)
            
            self.view_details_text.setPlainText('\n'.join(details))
            
        except Exception as e:
            logger.error(f"❌ Erreur affichage détails vue: {e}")
            self.view_details_text.setPlainText(f"Erreur lors de l'affichage: {str(e)}")
    
    def _load_review_info(self, view: Dict[str, Any]):
        """Charge les informations de relecture d'une vue"""
        try:
            # Charger le statut de relecture
            review_status = view.get('review_status', '📝 Brouillon')
            status_index = self.review_status_combo.findText(review_status)
            if status_index >= 0:
                self.review_status_combo.setCurrentIndex(status_index)
            
            # Charger le nom du relecteur
            reviewer = view.get('reviewer', '')
            self.reviewer_name_edit.setText(reviewer)
            
            # Charger les commentaires
            comments = view.get('review_comments', '')
            self.review_comments_edit.setPlainText(comments)
            
            # Charger l'historique
            self._load_review_history(view)
            
        except Exception as e:
            logger.error(f"❌ Erreur chargement info relecture: {e}")
    
    def _load_review_history(self, view: Dict[str, Any]):
        """Charge l'historique des relectures d'une vue"""
        try:
            history_lines = []
            
            # Historique de création
            created_date = view.get('created_date')
            if created_date:
                history_lines.append(f"📅 {created_date} - Vue créée")
            
            # Historique de relecture
            review_date = view.get('review_date')
            reviewer = view.get('reviewer')
            review_status = view.get('review_status')
            
            if review_date and reviewer:
                history_lines.append(f"📝 {review_date} - Relecture par {reviewer}: {review_status}")
            
            # Afficher l'historique
            if history_lines:
                self.review_history_text.setPlainText('\n'.join(history_lines))
            else:
                self.review_history_text.setPlainText("Aucun historique disponible...")
                
        except Exception as e:
            logger.error(f"❌ Erreur chargement historique: {e}")
            self.review_history_text.setPlainText("Erreur lors du chargement de l'historique")
    
    def _clear_view_details(self):
        """Efface les détails de la vue"""
        self.view_details_text.setPlainText("Sélectionnez une vue pour voir ses détails...")
        self.reviewer_name_edit.clear()
        self.review_status_combo.setCurrentIndex(0)
        self.review_comments_edit.clear()
        self.review_history_text.setPlainText("Aucun historique disponible...")
    
    def _save_review(self):
        """Sauvegarde la relecture d'une vue"""
        try:
            selected_view = self.views_combo.currentData()
            if not selected_view:
                self._show_warning("Aucune vue sélectionnée")
                return
            
            # Récupérer les données de relecture
            reviewer = self.reviewer_name_edit.text().strip()
            status = self.review_status_combo.currentText()
            comments = self.review_comments_edit.toPlainText().strip()
            
            if not reviewer:
                self._show_warning("Veuillez saisir le nom du relecteur")
                return
            
            # Mettre à jour la vue avec les informations de relecture
            selected_view['reviewer'] = reviewer
            selected_view['review_status'] = status
            selected_view['review_comments'] = comments
            selected_view['review_date'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Sauvegarder en base si possible
            if self.has_database_connection() and hasattr(self, 'view_crud_manager'):
                try:
                    self.view_crud_manager.update_view_review(
                        selected_view['name'], 
                        reviewer, 
                        status, 
                        comments
                    )
                except Exception as e:
                    logger.warning(f"⚠️ Impossible de sauvegarder en base: {e}")
            
            # Actualiser l'affichage
            self._load_review_history(selected_view)
            self._refresh_views_list()
            
            self._show_info("Relecture sauvegardée avec succès!")
            
        except Exception as e:
            logger.error(f"❌ Erreur sauvegarde relecture: {e}")
            self._show_error(f"Erreur lors de la sauvegarde: {str(e)}")
    
    def _export_review_report(self):
        """Exporte un rapport de relecture"""
        try:
            selected_view = self.views_combo.currentData()
            if not selected_view:
                self._show_warning("Aucune vue sélectionnée")
                return
            
            # Générer le rapport
            report = self._generate_review_report(selected_view)
            
            # Proposer la sauvegarde
            from PySide6.QtWidgets import QFileDialog
            
            filename, _ = QFileDialog.getSaveFileName(
                self,
                "Exporter le rapport de relecture",
                f"rapport_relecture_{selected_view.get('name', 'vue')}.txt",
                "Fichiers texte (*.txt);;Tous les fichiers (*)"
            )
            
            if filename:
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write(report)
                
                self._show_info(f"Rapport exporté vers: {filename}")
            
        except Exception as e:
            logger.error(f"❌ Erreur export rapport: {e}")
            self._show_error(f"Erreur lors de l'export: {str(e)}")
    
    def _generate_review_report(self, view: Dict[str, Any]) -> str:
        """Génère un rapport de relecture textuel"""
        try:
            lines = []
            lines.append("=" * 60)
            lines.append("RAPPORT DE RELECTURE DE VUE")
            lines.append("=" * 60)
            lines.append("")
            
            # Informations de base
            lines.append(f"Nom de la vue: {view.get('name', 'N/A')}")
            lines.append(f"Date de création: {view.get('created_date', 'N/A')}")
            lines.append(f"Source: {view.get('source', 'local')}")
            lines.append("")
            
            # Configuration de la vue
            data = view.get('data', {})
            if data:
                lines.append("CONFIGURATION DE LA VUE:")
                lines.append("-" * 30)
                lines.append(f"Table principale: {data.get('main_table', 'N/A')}")
                lines.append(f"Champ X: {data.get('x_field', 'N/A')}")
                
                y_fields = data.get('y_fields', [])
                for i, field in enumerate(y_fields, 1):
                    if field:
                        lines.append(f"Champ Y{i}: {field}")
                
                aggregations = data.get('aggregations', {})
                if aggregations:
                    lines.append("Agrégations:")
                    for key, agg in aggregations.items():
                        lines.append(f"  {key}: {agg}")
                
                lines.append("")
            
            # Informations de relecture
            lines.append("RELECTURE:")
            lines.append("-" * 30)
            lines.append(f"Relecteur: {view.get('reviewer', 'N/A')}")
            lines.append(f"Statut: {view.get('review_status', 'N/A')}")
            lines.append(f"Date de relecture: {view.get('review_date', 'N/A')}")
            lines.append("")
            
            # Commentaires
            comments = view.get('review_comments', '')
            if comments:
                lines.append("COMMENTAIRES:")
                lines.append("-" * 30)
                lines.append(comments)
                lines.append("")
            
            # SQL
            sql = view.get('sql') or data.get('sql', '')
            if sql:
                lines.append("REQUÊTE SQL:")
                lines.append("-" * 30)
                lines.append(sql)
                lines.append("")
            
            # Footer
            lines.append("=" * 60)
            lines.append(f"Rapport généré le: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            lines.append("=" * 60)
            
            return '\n'.join(lines)
            
        except Exception as e:
            logger.error(f"❌ Erreur génération rapport: {e}")
            return f"Erreur lors de la génération du rapport: {str(e)}"
    
    def _delete_view_from_db(self):
        """Supprime une vue de la base de données"""
        if not self.has_database_connection():
            self._show_warning("Aucune connexion à la base de données disponible")
            return
        
        try:
            selected_view = self.views_combo.currentData()
            if not selected_view:
                self._show_warning("Aucune vue sélectionnée")
                return
            
            view_name = selected_view.get('name', '')
            if not view_name:
                self._show_warning("Nom de vue invalide")
                return
            
            # Demander confirmation
            from PySide6.QtWidgets import QMessageBox
            
            reply = QMessageBox.question(
                self,
                "Confirmer la suppression",
                f"Êtes-vous sûr de vouloir supprimer la vue '{view_name}' ?\n\n"
                "Cette action est irréversible.",
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No
            )
            
            if reply == QMessageBox.Yes:
                # Supprimer la vue
                if hasattr(self, 'view_crud_manager') and self.view_crud_manager:
                    self.view_crud_manager.delete_view(view_name)
                else:
                    # Fallback direct
                    drop_query = f"DROP VIEW IF EXISTS {view_name}"
                    self.database_manager.execute_query(drop_query)
                
                # Actualiser la liste
                self._refresh_views_list()
                self._clear_view_details()
                
                self._show_info(f"Vue '{view_name}' supprimée avec succès")
        
        except Exception as e:
            logger.error(f"❌ Erreur suppression vue: {e}")
            self._show_error(f"Erreur lors de la suppression: {str(e)}")
    
    def _on_filter_changed(self):
        """Gère les changements de filtres"""
        try:
            # Activer/désactiver les champs selon les checkboxes
            self.date_from_edit.setEnabled(self.enable_date_filter_check.isChecked())
            self.date_to_edit.setEnabled(self.enable_date_filter_check.isChecked())
            
            self.min_value_edit.setEnabled(self.enable_min_filter_check.isChecked())
            self.max_value_edit.setEnabled(self.enable_max_filter_check.isChecked())
            
            self.contains_text_edit.setEnabled(self.enable_contains_filter_check.isChecked())
            
            # Revalider le formulaire
            self._validate_form()
            
        except Exception as e:
            logger.error(f"❌ Erreur changement filtre: {e}")
    
    def _on_calc_changed(self):
        """Gère les changements de calculs dérivés"""
        try:
            # Activer/désactiver le spin box de la moyenne mobile
            self.mobile_period_spin.setEnabled(self.calc_mobile_check.isChecked())
            
            # Revalider le formulaire
            self._validate_form()
            
        except Exception as e:
            logger.error(f"❌ Erreur changement calcul: {e}")
    
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
