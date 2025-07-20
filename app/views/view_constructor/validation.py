"""
Validation Mixin pour la validation des formulaires et données
"""

import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class ValidationMixin:
    """Mixin pour la validation des formulaires et données"""
    
    def _validate_form(self):
        """Valide le formulaire et active/désactive les boutons en conséquence"""
        try:
            # Vérifier les éléments requis
            main_table = self.main_table_combo.currentData()
            x_field = self.x_field_combo.currentData()
            y1_field = self.y1_field_combo.currentData()
            view_name = self.view_name_combo.currentText().strip()
            
            # Validation de base
            is_valid = all([
                main_table is not None,
                x_field is not None,
                y1_field is not None,
                view_name and len(view_name) > 0
            ])
            
            # Validation du nom de vue
            if is_valid and view_name:
                is_valid = self._validate_view_name(view_name)
            
            # Validation des agrégations
            if is_valid:
                is_valid = self._validate_aggregations()
            
            # Validation des filtres
            if is_valid:
                is_valid = self._validate_filters()
            
            # Activer/désactiver les boutons
            self.preview_btn.setEnabled(is_valid)
            self.save_btn.setEnabled(is_valid)
            
            # Mettre à jour l'aperçu si valide
            if is_valid:
                self._update_preview()
            
            return is_valid
            
        except Exception as e:
            logger.error(f"❌ Erreur validation formulaire: {e}")
            self.preview_btn.setEnabled(False)
            self.save_btn.setEnabled(False)
            return False
    
    def _validate_view_name(self, view_name: str) -> bool:
        """Valide le nom de la vue"""
        if not view_name:
            return False
        
        # Vérifier la longueur
        if len(view_name) < 3 or len(view_name) > 63:
            return False
        
        # Vérifier les caractères autorisés (lettres, chiffres, underscore)
        import re
        if not re.match(r'^[a-zA-Z][a-zA-Z0-9_]*$', view_name):
            return False
        
        # Vérifier que le nom ne commence pas par un chiffre
        if view_name[0].isdigit():
            return False
        
        return True
    
    def _validate_aggregations(self) -> bool:
        """Valide les fonctions d'agrégation sélectionnées"""
        try:
            # Au moins Y1 doit avoir une agrégation si un champ Y1 est sélectionné
            y1_field = self.y1_field_combo.currentData()
            if y1_field:
                y1_agg = self.y1_agg_combo.currentText()
                if not y1_agg or y1_agg.startswith("--"):
                    return False
            
            # Vérifier la cohérence des agrégations avec les types de champs
            for i in range(1, 4):
                field_combo = getattr(self, f'y{i}_field_combo')
                agg_combo = getattr(self, f'y{i}_agg_combo')
                
                field_data = field_combo.currentData()
                if field_data:
                    agg_text = agg_combo.currentText()
                    if agg_text and not agg_text.startswith("--"):
                        if not self._is_aggregation_compatible(field_data, agg_text):
                            return False
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Erreur validation agrégations: {e}")
            return False
    
    def _is_aggregation_compatible(self, field_data: str, aggregation: str) -> bool:
        """Vérifie si l'agrégation est compatible avec le type de champ"""
        if not hasattr(self, 'tables_data') or not self.tables_data:
            return True  # Mode fallback
        
        try:
            # Récupérer les informations du champ
            main_table = self.main_table_combo.currentData()
            if not main_table or main_table not in self.tables_data:
                return True
            
            fields = self.tables_data[main_table]["fields"]
            if field_data not in fields:
                return True
            
            field_type = fields[field_data]["type"]
            agg_function = aggregation.split(" - ")[0].upper()
            
            # Règles de compatibilité
            numeric_types = ["numeric", "integer", "float", "decimal"]
            
            if agg_function in ["SUM", "AVG"]:
                return field_type in numeric_types
            elif agg_function in ["MAX", "MIN"]:
                return field_type in numeric_types + ["date", "datetime"]
            elif agg_function == "COUNT":
                return True  # COUNT fonctionne avec tous les types
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Erreur vérification compatibilité agrégation: {e}")
            return True  # En cas d'erreur, on autorise
    
    def _validate_filters(self) -> bool:
        """Valide les filtres configurés"""
        try:
            # Validation des filtres de date
            if self.enable_date_filter_check.isChecked():
                date_from = self.date_from_edit.date()
                date_to = self.date_to_edit.date()
                if date_from > date_to:
                    return False
            
            # Validation des filtres de valeur
            if self.enable_min_filter_check.isChecked():
                min_text = self.min_value_edit.text().strip()
                if min_text:
                    try:
                        float(min_text)
                    except ValueError:
                        return False
            
            if self.enable_max_filter_check.isChecked():
                max_text = self.max_value_edit.text().strip()
                if max_text:
                    try:
                        float(max_text)
                    except ValueError:
                        return False
            
            # Vérifier que min < max si les deux sont activés
            if (self.enable_min_filter_check.isChecked() and 
                self.enable_max_filter_check.isChecked()):
                min_text = self.min_value_edit.text().strip()
                max_text = self.max_value_edit.text().strip()
                if min_text and max_text:
                    try:
                        min_val = float(min_text)
                        max_val = float(max_text)
                        if min_val >= max_val:
                            return False
                    except ValueError:
                        return False
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Erreur validation filtres: {e}")
            return False
    
    def _validate_view_definition(self, view_def: Dict[str, Any]) -> tuple[bool, Optional[str]]:
        """Valide une définition de vue complète"""
        try:
            # Vérifications de base
            required_fields = ['name', 'main_table', 'x_field', 'y_fields']
            for field in required_fields:
                if field not in view_def or not view_def[field]:
                    return False, f"Champ requis manquant: {field}"
            
            # Validation du nom
            if not self._validate_view_name(view_def['name']):
                return False, "Nom de vue invalide"
            
            # Validation de la table principale
            if view_def['main_table'] not in self.tables_data:
                return False, f"Table inconnue: {view_def['main_table']}"
            
            # Validation des champs
            table_fields = self.tables_data[view_def['main_table']]['fields']
            
            if view_def['x_field'] not in table_fields:
                return False, f"Champ X invalide: {view_def['x_field']}"
            
            for y_field in view_def['y_fields']:
                if y_field and y_field not in table_fields:
                    return False, f"Champ Y invalide: {y_field}"
            
            # Validation des agrégations
            aggregations = view_def.get('aggregations', {})
            for key, agg in aggregations.items():
                if agg and not agg.startswith("--"):
                    # Vérifier que l'agrégation est valide
                    valid_aggs = ["SUM", "AVG", "MAX", "MIN", "COUNT"]
                    agg_func = agg.split(" - ")[0].upper()
                    if agg_func not in valid_aggs:
                        return False, f"Agrégation invalide: {agg}"
            
            return True, None
            
        except Exception as e:
            logger.error(f"❌ Erreur validation définition vue: {e}")
            return False, f"Erreur de validation: {str(e)}"
    
    def _get_validation_errors(self) -> list[str]:
        """Retourne la liste des erreurs de validation actuelles"""
        errors = []
        
        try:
            # Vérifier la table principale
            if not self.main_table_combo.currentData():
                errors.append("Aucune table principale sélectionnée")
            
            # Vérifier le champ X
            if not self.x_field_combo.currentData():
                errors.append("Aucun champ X sélectionné")
            
            # Vérifier au moins un champ Y
            if not self.y1_field_combo.currentData():
                errors.append("Au moins un champ Y doit être sélectionné")
            
            # Vérifier le nom de la vue
            view_name = self.view_name_combo.currentText().strip()
            if not view_name:
                errors.append("Nom de vue requis")
            elif not self._validate_view_name(view_name):
                errors.append("Nom de vue invalide (lettres, chiffres, underscore uniquement)")
            
            # Vérifier les agrégations
            if self.y1_field_combo.currentData():
                y1_agg = self.y1_agg_combo.currentText()
                if not y1_agg or y1_agg.startswith("--"):
                    errors.append("Fonction d'agrégation requise pour Y1")
            
            # Vérifier les filtres de date
            if self.enable_date_filter_check.isChecked():
                if self.date_from_edit.date() > self.date_to_edit.date():
                    errors.append("Date de début postérieure à la date de fin")
            
            # Vérifier les filtres de valeur
            if self.enable_min_filter_check.isChecked():
                min_text = self.min_value_edit.text().strip()
                if min_text:
                    try:
                        float(min_text)
                    except ValueError:
                        errors.append("Valeur minimale invalide")
            
            if self.enable_max_filter_check.isChecked():
                max_text = self.max_value_edit.text().strip()
                if max_text:
                    try:
                        float(max_text)
                    except ValueError:
                        errors.append("Valeur maximale invalide")
            
        except Exception as e:
            logger.error(f"❌ Erreur récupération erreurs validation: {e}")
            errors.append(f"Erreur de validation: {str(e)}")
        
        return errors
