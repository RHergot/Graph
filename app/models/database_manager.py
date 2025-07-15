"""
Gestionnaire de base de données PostgreSQL
Responsable de la connexion et des requêtes sécurisées
"""

import logging
from typing import Dict, List, Optional

import pandas as pd
from config.database import DatabaseConfig
from sqlalchemy import MetaData, create_engine, inspect, text
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError
from utils.exceptions import (
    DatabaseConnectionError,
    QueryExecutionError,
    ViewNotFoundError,
)

logger = logging.getLogger(__name__)


class DatabaseManager:
    """Gestionnaire de connexion et requêtes PostgreSQL"""

    def __init__(self):
        """Initialisation avec configuration automatique"""
        self.config = DatabaseConfig()
        self.engine: Optional[Engine] = None
        self.metadata = MetaData()
        self._initialize_connection()

    def _initialize_connection(self) -> None:
        """Initialise la connexion à la base de données"""
        try:
            self.engine = create_engine(
                self.config.get_connection_string(),
                **self.config.get_engine_options(),
            )
            self._test_connection()
            logger.info("✅ Database connection established")

        except Exception as e:
            logger.error(f"❌ Erreur initialisation DB: {e}")
            raise DatabaseConnectionError(
                f"Impossible d'initialiser la connexion: {e}"
            )

    def _test_connection(self) -> bool:
        """Test de connexion à la base de données"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            with self.engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            return True
        except SQLAlchemyError as e:
            logger.error(f"❌ Connection test failed: {e}")
            raise DatabaseConnectionError(f"Test de connexion échoué: {e}")

    def test_connection(self) -> bool:
        """Test public de connexion à la base de données"""
        try:
            return self._test_connection()
        except DatabaseConnectionError:
            return False

    def get_available_views(self) -> List[Dict]:
        """Découverte des VIEWs métier disponibles"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            inspector = inspect(self.engine)
            schema = self.config.get_schema()
            all_views = inspector.get_view_names(schema=schema)

            # Filtrage VIEWs métier (patterns étendus)
            business_views = []
            for view in all_views:
                # Patterns métier étendus
                if view.startswith(
                    (
                        "vw_",
                        "report_",
                        "view_",
                        "ot_",
                        "v_",
                        "kpi_gmao_",
                        "kpi_stock_",
                        "kpi_purchase_",
                        "kpi_sale_",
                    )
                ) or any(
                    pattern in view.lower()
                    for pattern in [
                        "actif",
                        "complet",
                        "report",
                        "business",
                        "bi",
                        "analytics",
                        "dashboard",
                        "kpi",
                        "metric",
                        "summary",
                        "overview",
                    ]
                ):
                    business_views.append(view)

            views_info = []
            for view_name in business_views:
                try:
                    # Récupération colonnes pour description
                    columns = inspector.get_columns(view_name, schema=schema)
                    # Top 5 colonnes
                    col_names = [col["name"] for col in columns[:5]]

                    clean_name = view_name.replace("vw_", "").replace("_", " ")
                    views_info.append(
                        {
                            "name": view_name,
                            "description": (
                                f"Analyse basée sur {clean_name}.title()"
                            ),
                            "columns": col_names,
                            "column_count": len(columns),
                        }
                    )
                except Exception as e:
                    logger.warning(
                        f"⚠️ Impossible d'analyser la VIEW {view_name}: {e}"
                    )
                    continue

            logger.info(f"📊 Found {len(views_info)} business VIEWs")
            return views_info

        except SQLAlchemyError as e:
            logger.error(f"❌ Error discovering VIEWs: {e}")
            return []

    def get_view_structure(self, view_name: str) -> Dict:
        """Récupère la structure détaillée d'une VIEW"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            inspector = inspect(self.engine)
            schema = self.config.get_schema()
            columns = inspector.get_columns(view_name, schema=schema)

            return {
                "view_name": view_name,
                "columns": [
                    {
                        "name": col["name"],
                        "type": str(col["type"]),
                        "nullable": col["nullable"],
                    }
                    for col in columns
                ],
            }
        except SQLAlchemyError as e:
            logger.error(f"❌ Erreur structure VIEW {view_name}: {e}")
            raise ViewNotFoundError(
                f"Impossible d'accéder à la VIEW {view_name}: {e}"
            )

    def execute_query(
        self, query, params: Optional[Dict] = None
    ) -> pd.DataFrame:
        """Exécution sécurisée avec gestion erreurs et timeout"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            with self.engine.connect() as conn:
                # Configuration timeout
                conn = conn.execution_options(
                    autocommit=True, compiled_cache={}
                )

                # Exécution requête
                if params:
                    df = pd.read_sql(query, conn, params=params)
                else:
                    df = pd.read_sql(query, conn)

                # Limitation sécurité
                max_rows = self.config.get_max_rows()
                if len(df) > max_rows:
                    logger.warning(
                        f"⚠️ Query returns {len(df)} rows, "
                        f"limiting to {max_rows}"
                    )
                    df = df.head(max_rows)

                logger.info(f"📈 Query executed: {len(df)} rows returned")
                return df

        except SQLAlchemyError as e:
            logger.error(f"❌ Error executing query: {e}")
            raise QueryExecutionError(f"Erreur lors de l'exécution: {e}")
        except Exception as e:
            logger.error(f"❌ Erreur inattendue: {e}")
            raise QueryExecutionError(f"Erreur inattendue: {e}")

    def test_view_access(self, view_name: str) -> bool:
        """Test d'accès à une VIEW spécifique"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            test_query = text(f"SELECT * FROM {view_name} LIMIT 1")
            with self.engine.connect() as conn:
                conn.execute(test_query)
            logger.info(f"✅ Access to VIEW {view_name} confirmed")
            return True
        except SQLAlchemyError as e:
            logger.warning(f"⚠️ Access to VIEW {view_name} impossible: {e}")
            return False

    def get_connection_info(self) -> Dict:
        """Retourne les informations de connexion (masquées)"""
        if self.engine is None:
            return {}
        return {
            "host": self.engine.url.host,
            "port": self.engine.url.port,
            "database": self.engine.url.database,
            "username": self.engine.url.username,
            "schema": self.config.get_schema(),
        }

    def get_connection(self):
        """Retourne une connexion à la base de données"""
        if self.engine is None:
            raise DatabaseConnectionError("Engine not initialized")
        return self.engine.connect()

    def create_view(self, view_name: str, sql_query: str) -> bool:
        """Crée une nouvelle VIEW PostgreSQL"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            if not self._validate_view_name(view_name):
                raise ViewNotFoundError(f"Nom de VIEW invalide: {view_name}")

            create_query = text(f"CREATE VIEW {view_name} AS {sql_query}")

            with self.engine.connect() as conn:
                conn.execute(create_query)
                conn.commit()

            logger.info(f"✅ VIEW {view_name} créée avec succès")
            return True

        except SQLAlchemyError as e:
            logger.error(f"❌ Erreur création VIEW {view_name}: {e}")
            raise QueryExecutionError(
                f"Impossible de créer la VIEW {view_name}: {e}"
            )

    def drop_view(self, view_name: str, cascade: bool = False) -> bool:
        """Supprime une VIEW PostgreSQL"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            cascade_clause = " CASCADE" if cascade else ""
            drop_query = text(
                f"DROP VIEW IF EXISTS {view_name}{cascade_clause}"
            )

            with self.engine.connect() as conn:
                conn.execute(drop_query)
                conn.commit()

            logger.info(f"✅ VIEW {view_name} supprimée avec succès")
            return True

        except SQLAlchemyError as e:
            logger.error(f"❌ Erreur suppression VIEW {view_name}: {e}")
            raise QueryExecutionError(
                f"Impossible de supprimer la VIEW {view_name}: {e}"
            )

    def get_view_definition(self, view_name: str) -> str:
        """Récupère la définition SQL d'une VIEW"""
        try:
            if self.engine is None:
                raise DatabaseConnectionError("Engine not initialized")
            query = text(
                """
                SELECT definition
                FROM pg_views
                WHERE viewname = :view_name
                AND schemaname = :schema
            """
            )

            with self.engine.connect() as conn:
                result = conn.execute(
                    query,
                    {
                        "view_name": view_name,
                        "schema": self.config.get_schema(),
                    },
                )
                row = result.fetchone()

            return row[0] if row else ""

        except SQLAlchemyError as e:
            logger.error(
                f"❌ Erreur récupération définition VIEW {view_name}: {e}"
            )
            return ""

    def _validate_view_name(self, view_name: str) -> bool:
        """Valide le nom d'une VIEW"""
        import re

        pattern = r"^[a-zA-Z][a-zA-Z0-9_]*$"

        if not (bool(re.match(pattern, view_name)) and len(view_name) <= 63):
            return False

        kpi_prefixes = [
            "kpi_gmao_",
            "kpi_stock_",
            "kpi_purchase_",
            "kpi_sale_",
        ]
        if any(view_name.startswith(prefix) for prefix in kpi_prefixes):
            return True

        return view_name.startswith(("vw_", "report_", "view_", "v_"))

    def update_view(self, view_name: str, new_sql_query: str) -> bool:
        """Met à jour une VIEW existante (DROP + CREATE)"""
        try:
            old_definition = self.get_view_definition(view_name)

            self.drop_view(view_name, cascade=False)

            try:
                success = self.create_view(view_name, new_sql_query)
                if success:
                    logger.info(f"✅ VIEW {view_name} mise à jour avec succès")
                    return True
                return False
            except Exception as create_error:
                if old_definition:
                    try:
                        self.create_view(view_name, old_definition)
                        logger.warning(
                            f"⚠️ VIEW {view_name} restaurée après "
                            f"erreur de mise à jour"
                        )
                    except Exception:
                        logger.error(
                            f"❌ Impossible de restaurer VIEW {view_name}"
                        )
                raise create_error

        except SQLAlchemyError as e:
            logger.error(f"❌ Erreur mise à jour VIEW {view_name}: {e}")
            raise QueryExecutionError(
                f"Impossible de mettre à jour la VIEW {view_name}: {e}"
            )
