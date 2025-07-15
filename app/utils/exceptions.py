"""
Exceptions personnalisées pour le module de reporting
"""


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


class QueryExecutionError(ReportingModuleException):
    """Erreur lors de l'exécution d'une requête SQL"""

    pass


class ConfigurationError(ReportingModuleException):
    """Erreur de configuration de l'application"""

    pass
