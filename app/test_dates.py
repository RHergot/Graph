#!/usr/bin/env python3
"""
Test des corrections pour les filtres de dates
"""

from models.database_manager import DatabaseManager
from models.analysis_engine import AnalysisEngine

def test_date_columns():
    """Test de détection des colonnes de dates"""
    print("🔍 Test détection colonnes de dates")
    print("=" * 40)
    
    try:
        # Initialisation
        db = DatabaseManager()
        engine = AnalysisEngine(db)
        
        # Test sur quelques VIEWs
        test_views = [
            'v_mouvement_stats',
            'v_historique_receptions', 
            'v_kpi_machine_jour',
            'ot_actifs'
        ]
        
        for view_name in test_views:
            print(f"\n📊 Analyse de la VIEW: {view_name}")
            
            # Structure de la VIEW
            try:
                structure = db.get_view_structure(view_name)
                columns = structure.get('columns', [])
                print(f"   Colonnes ({len(columns)}):")
                
                for col in columns[:10]:  # Afficher les 10 premières
                    col_name = col.get('name', 'N/A')
                    col_type = col.get('type', 'N/A')
                    print(f"     - {col_name} ({col_type})")
                
                if len(columns) > 10:
                    print(f"     ... et {len(columns) - 10} autres colonnes")
                
                # Test détection colonne date
                date_col = engine._find_date_column(view_name)
                if date_col:
                    print(f"   ✅ Colonne de date détectée: {date_col}")
                else:
                    print(f"   ⚠️ Aucune colonne de date détectée")
                    
            except Exception as e:
                print(f"   ❌ Erreur: {e}")
        
        print("\n🎯 Test terminé")
        
    except Exception as e:
        print(f"❌ Erreur globale: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_date_columns()
