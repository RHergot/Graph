"""
Exceptions spécialisées pour la gestion des VIEWs KPI
Extensions des exceptions de base pour les opérations sur les VIEWs
"""

class ReportingModuleException(Exception):
    """Exception de base pour le module de reporting"""
    pass

class ViewManagerException(ReportingModuleException):
    """Exception de base pour le gestionnaire de VIEWs"""
    pass

class ViewCreationError(ViewManagerException):
    """Erreur lors de la création d'une VIEW"""
    pass

class ViewAlreadyExistsError(ViewManagerException):
    """VIEW existe déjà"""
    pass

class ViewValidationError(ViewManagerException):
    """Erreur de validation de la définition d'une VIEW"""
    pass

class ViewNotFoundError(ViewManagerException):
    """VIEW introuvable"""
    pass

class ViewUpdateError(ViewManagerException):
    """Erreur lors de la mise à jour d'une VIEW"""
    pass

class ViewDeletionError(ViewManagerException):
    """Erreur lors de la suppression d'une VIEW"""
    pass

class ViewDataRetrievalError(ViewManagerException):
    """Erreur lors de la récupération des données d'une VIEW"""
    pass

class ViewListingError(ViewManagerException):
    """Erreur lors du listage des VIEWs"""
    pass

class ViewSchemaError(ViewManagerException):
    """Erreur lors de la récupération du schéma d'une VIEW"""
    pass

class ViewRefreshError(ViewManagerException):
    """Erreur lors du rafraîchissement d'une VIEW"""
    pass

class ViewTemplateError(ViewManagerException):
    """Erreur dans les templates de VIEWs"""
    pass

class ViewSQLGenerationError(ViewManagerException):
    """Erreur lors de la génération du SQL d'une VIEW"""
    pass

class ViewMetadataError(ViewManagerException):
    """Erreur dans la gestion des métadonnées de VIEWs"""
    pass

class ViewPermissionError(ViewManagerException):
    """Erreur de permissions sur une VIEW"""
    pass

class ViewDependencyError(ViewManagerException):
    """Erreur de dépendances entre VIEWs"""
    pass
