#!/usr/bin/env python3
"""
Script de test de connexion à la base de données
"""

import sys

from models.database_manager import DatabaseManager
from sqlalchemy import text


def test_database_connection():
    """Test complet de la connexion et exploration de la base"""
    print("🔧 Test de connexion à la base de données PostgreSQL")
    print("=" * 60)

    try:
        # Initialisation
        db = DatabaseManager()
        print("✅ DatabaseManager initialisé")

        # Test de connexion
        if db.test_connection():
            print("✅ Connexion PostgreSQL réussie!")

            # Informations de connexion
            info = db.get_connection_info()
            print(f"📋 Host: {info['host']}:{info['port']}")
            print(f"📋 Database: {info['database']}")
            print(f"📋 User: {info['username']}")
            print()

            # Exploration de la base
            with db.get_connection() as conn:
                # Schémas
                result = conn.execute(
                    text(
                        """
                    SELECT schema_name 
                    FROM information_schema.schemata 
                    WHERE schema_name NOT IN (
                        'information_schema', 'pg_catalog', 'pg_toast'
                    )
                    ORDER BY schema_name
                """
                    )
                )
                schemas = [row[0] for row in result]
                print(f"📊 Schémas disponibles ({len(schemas)}): {schemas}")
                print()

                # Tables et vues
                result = conn.execute(
                    text(
                        """
                    SELECT table_schema, table_name, table_type
                    FROM information_schema.tables 
                    WHERE table_schema NOT IN (
                        'information_schema', 'pg_catalog'
                    )
                    ORDER BY table_schema, table_name
                    LIMIT 50
                """
                    )
                )
                tables = list(result)
                print(f"📋 Tables/VIEWs trouvées ({len(tables)}):")

                view_count = 0
                table_count = 0

                for schema, name, type_ in tables:
                    if type_ == "VIEW":
                        icon = "👁️"
                        view_count += 1
                    else:
                        icon = "🏠"
                        table_count += 1
                    print(f"   {icon} {schema}.{name} ({type_})")

                print()
                print(f"📊 Résumé: {table_count} tables, {view_count} vues")

                # Test spécifique des VIEWs avec préfixe v_
                print()
                print("🔍 Recherche VIEWs avec préfixe 'v_'...")
                result = conn.execute(
                    text(
                        """
                    SELECT table_schema, table_name
                    FROM information_schema.views 
                    WHERE table_schema NOT IN (
                        'information_schema', 'pg_catalog'
                    )
                    AND table_name LIKE 'v_%'
                    ORDER BY table_schema, table_name
                """
                    )
                )
                v_views = list(result)

                if v_views:
                    print(
                        f"🎯 VIEWs avec préfixe 'v_' trouvées ({len(v_views)}):"
                    )
                    for schema, name in v_views:
                        print(f"   📊 {schema}.{name}")
                else:
                    print("⚠️ Aucune VIEW avec préfixe 'v_' détectée")

                # Toutes les VIEWs disponibles
                print()
                print("📋 Toutes les VIEWs disponibles:")
                result = conn.execute(
                    text(
                        """
                    SELECT table_schema, table_name
                    FROM information_schema.views 
                    WHERE table_schema NOT IN (
                        'information_schema', 'pg_catalog'
                    )
                    ORDER BY table_schema, table_name
                """
                    )
                )
                all_views = list(result)

                for schema, name in all_views:
                    if name.startswith("v_"):
                        icon = "🎯"  # VIEWs avec préfixe v_
                    else:
                        icon = "👁️"  # Autres VIEWs
                    print(f"   {icon} {schema}.{name}")

        else:
            print("❌ Échec de la connexion PostgreSQL")
            return False

    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        import traceback

        traceback.print_exc()
        return False  # Test de la méthode get_available_views de l'application
        print()
        print("🎯 Test méthode get_available_views()...")
        views = db.get_available_views()
        print(f"✅ VIEWs métier détectées: {len(views)}")

        for view in views:
            print(f"   📊 {view['name']} ({view['column_count']} colonnes)")
            print(f"      Desc: {view['description']}")
            print(f"      Colonnes: {view['columns']}")
            print()

        # Test de la méthode get_available_views de l'application
        print()
        print("🎯 Test méthode get_available_views()...")
        views = db.get_available_views()
        print(f"✅ VIEWs métier détectées: {len(views)}")

        for view in views:
            print(f"   📊 {view['name']} ({view['column_count']} colonnes)")
            print(f"      Desc: {view['description']}")
            if view["columns"]:
                print(
                    f"      Premières colonnes: {', '.join(view['columns'])}"
                )
            print()

        return True


if __name__ == "__main__":
    success = test_database_connection()
    sys.exit(0 if success else 1)
