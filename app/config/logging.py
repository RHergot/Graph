"""
Configuration centralisée du système de logging
"""

import logging
import logging.handlers
import os


def setup_logging():
    """Configuration centralisée du logging"""

    # Création dossier logs si inexistant
    logs_dir = "logs"
    if not os.path.exists(logs_dir):
        os.makedirs(logs_dir)

    # Configuration du logger principal
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # Nettoyage handlers existants
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)

    # Format des messages
    formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")

    # Handler fichier avec rotation
    file_handler = logging.handlers.RotatingFileHandler(
        f"{logs_dir}/reporting_module.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    # Handler console pour développement
    console_handler = logging.StreamHandler()
    console_formatter = logging.Formatter("%(levelname)s - %(message)s")
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    logger.info("📝 Système de logging initialisé")
    return logger
