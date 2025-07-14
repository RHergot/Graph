"""
Configuration centralisée pour la base de données PostgreSQL
"""

import os
from dotenv import load_dotenv

# Chargement variables d'environnement
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
    
    @staticmethod
    def get_schema() -> str:
        """Retourne le schéma de base de données"""
        return os.getenv('DB_SCHEMA', 'public')
    
    @staticmethod
    def get_max_rows() -> int:
        """Limite maximale de lignes pour les requêtes"""
        return int(os.getenv('MAX_QUERY_ROWS', 10000))
