"""
Templates KPI prédéfinis pour les différents domaines métier
"""

from typing import Dict, List


class KPITemplates:
    """Gestionnaire des templates KPI prédéfinis"""

    @staticmethod
    def get_templates() -> Dict[str, List[Dict]]:
        """Retourne tous les templates organisés par domaine"""
        return {
            "GMAO": KPITemplates.get_gmao_templates(),
            "Stock": KPITemplates.get_stock_templates(),
            "Purchase": KPITemplates.get_purchase_templates(),
            "Sale": KPITemplates.get_sale_templates(),
        }

    @staticmethod
    def get_gmao_templates() -> List[Dict]:
        """Templates KPI pour la GMAO"""
        return [
            {
                "name": "kpi_gmao_maintenance_mensuelle",
                "description": "KPI maintenance par mois et machine",
                "sql": """SELECT
    DATE_TRUNC('month', m.date_debut) as mois,
    ma.nom as machine,
    COUNT(*) as nb_maintenances,
    AVG(EXTRACT(EPOCH FROM (m.date_fin - m.date_debut))/3600)
        as duree_moyenne_heures,
    SUM(CASE WHEN m.type_maintenance = 'preventive' THEN 1 ELSE 0 END)
        as nb_preventives,
    SUM(CASE WHEN m.type_maintenance = 'corrective' THEN 1 ELSE 0 END)
        as nb_correctives
FROM maintenance m
JOIN machine ma ON m.machine_id = ma.id
WHERE m.date_debut >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', m.date_debut), ma.nom
ORDER BY mois DESC, machine""",
            },
            {
                "name": "kpi_gmao_disponibilite_machine",
                "description": "Taux de disponibilité des machines",
                "sql": """SELECT
    ma.nom as machine,
    ma.emplacement,
    COUNT(m.id) as nb_pannes,
    SUM(EXTRACT(EPOCH FROM (m.date_fin - m.date_debut))/3600) as heures_arret,
    ROUND((1 - SUM(EXTRACT(EPOCH FROM (m.date_fin - m.date_debut)))
          /3600.0/720.0) * 100, 2) as taux_disponibilite_pct
FROM machine ma
LEFT JOIN maintenance m ON ma.id = m.machine_id
    AND m.date_debut >= CURRENT_DATE - INTERVAL '1 month'
    AND m.type_maintenance = 'corrective'
GROUP BY ma.id, ma.nom, ma.emplacement
ORDER BY taux_disponibilite_pct ASC""",
            },
            {
                "name": "kpi_gmao_couts_maintenance",
                "description": "Analyse des coûts de maintenance",
                "sql": """SELECT
    ma.nom as machine,
    DATE_TRUNC('month', m.date_debut) as mois,
    SUM(mfe.montant) as cout_externe,
    COUNT(DISTINCT mi.intervenant_id) as nb_intervenants,
    AVG(EXTRACT(EPOCH FROM (m.date_fin - m.date_debut))/3600) as duree_moyenne
FROM maintenance m
JOIN machine ma ON m.machine_id = ma.id
LEFT JOIN maintenance_frais_externe mfe ON m.id = mfe.maintenance_id
LEFT JOIN maintenance_intervenant mi ON m.id = mi.maintenance_id
WHERE m.date_debut >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY ma.nom, DATE_TRUNC('month', m.date_debut)
ORDER BY mois DESC, cout_externe DESC""",
            },
            {
                "name": "kpi_gmao_ordres_travail",
                "description": "Suivi des ordres de travail",
                "sql": """SELECT
    DATE_TRUNC('week', ot.date_creation) as semaine,
    ot.statut,
    COUNT(*) as nb_ordres,
    AVG(EXTRACT(EPOCH FROM (ot.date_fin - ot.date_debut))/3600)
        as duree_moyenne_heures,
    COUNT(DISTINCT ot.machine_id) as nb_machines_concernees
FROM ordre_travail ot
WHERE ot.date_creation >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY DATE_TRUNC('week', ot.date_creation), ot.statut
ORDER BY semaine DESC, statut""",
            },
        ]

    @staticmethod
    def get_stock_templates() -> List[Dict]:
        """Templates KPI pour la gestion des stocks"""
        return [
            {
                "name": "kpi_stock_rotation",
                "description": "Analyse de rotation des stocks",
                "sql": """SELECT
    p.nom as piece,
    pc.nom as categorie,
    SUM(CASE WHEN ms.type_mouvement = 'sortie' THEN ms.quantite ELSE 0 END)
        as sorties_totales,
    AVG(CASE WHEN ms.type_mouvement = 'entree' THEN ms.quantite ELSE 0 END)
        as stock_moyen,
    CASE
        WHEN AVG(CASE WHEN ms.type_mouvement = 'entree'
                      THEN ms.quantite ELSE 0 END) > 0
        THEN SUM(CASE WHEN ms.type_mouvement = 'sortie'
                      THEN ms.quantite ELSE 0 END) /
             AVG(CASE WHEN ms.type_mouvement = 'entree'
                      THEN ms.quantite ELSE 0 END)
        ELSE 0
    END as taux_rotation
FROM piece p
JOIN piece_category pc ON p.category_id = pc.id
LEFT JOIN mouvement_stock ms ON p.id = ms.piece_id
    AND ms.date_mouvement >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY p.id, p.nom, pc.nom
HAVING SUM(CASE WHEN ms.type_mouvement = 'sortie'
           THEN ms.quantite ELSE 0 END) > 0
ORDER BY taux_rotation DESC""",
            },
            {
                "name": "kpi_stock_valorisation",
                "description": "Valorisation des stocks par emplacement",
                "sql": """SELECT
    e.nom as emplacement,
    e.zone,
    COUNT(DISTINCT p.id) as nb_pieces_differentes,
    SUM(ms.quantite * p.prix_unitaire) as valeur_stock_euro,
    AVG(p.prix_unitaire) as prix_moyen_piece,
    SUM(ms.quantite) as quantite_totale
FROM emplacement_stock es
JOIN emplacement e ON es.emplacement_id = e.id
JOIN mouvement_stock ms ON es.id = ms.emplacement_stock_id
JOIN piece p ON ms.piece_id = p.id
WHERE ms.type_mouvement = 'entree'
GROUP BY e.id, e.nom, e.zone
ORDER BY valeur_stock_euro DESC""",
            },
            {
                "name": "kpi_stock_mouvements_mensuels",
                "description": "Évolution des mouvements de stock",
                "sql": """SELECT
    DATE_TRUNC('month', ms.date_mouvement) as mois,
    ms.type_mouvement,
    COUNT(*) as nb_mouvements,
    SUM(ms.quantite) as quantite_totale,
    COUNT(DISTINCT ms.piece_id) as nb_pieces_concernees,
    COUNT(DISTINCT ms.emplacement_stock_id) as nb_emplacements
FROM mouvement_stock ms
WHERE ms.date_mouvement >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', ms.date_mouvement), ms.type_mouvement
ORDER BY mois DESC, type_mouvement""",
            },
        ]

    @staticmethod
    def get_purchase_templates() -> List[Dict]:
        """Templates KPI pour les achats"""
        return [
            {
                "name": "kpi_purchase_performance_fournisseur",
                "description": "Performance des fournisseurs",
                "sql": """SELECT
    f.nom as fournisseur,
    f.ville,
    COUNT(DISTINCT c.id) as nb_commandes,
    AVG(EXTRACT(EPOCH FROM (lr.date_reception - c.date_commande))/86400)
        as delai_moyen_jours,
    SUM(lc.quantite * lc.prix_unitaire) as ca_total_euro,
    AVG(lc.prix_unitaire) as prix_moyen,
    COUNT(DISTINCT p.id) as nb_pieces_fournies
FROM fournisseur f
JOIN commande c ON f.id = c.fournisseur_id
JOIN ligne_commande lc ON c.id = lc.commande_id
JOIN piece p ON lc.piece_id = p.id
LEFT JOIN lot_reception lr ON c.id = lr.commande_id
WHERE c.date_commande >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY f.id, f.nom, f.ville
ORDER BY ca_total_euro DESC""",
            },
            {
                "name": "kpi_purchase_demandes_achat",
                "description": "Suivi des demandes d'achat",
                "sql": """SELECT
    DATE_TRUNC('month', da.date_demande) as mois,
    da.statut,
    COUNT(*) as nb_demandes,
    SUM(dal.quantite * dal.prix_estime) as montant_estime_euro,
    AVG(EXTRACT(EPOCH FROM (da.date_traitement - da.date_demande))/86400)
        as delai_traitement_jours
FROM demandes_achat da
JOIN demandes_achat_lignes dal ON da.id = dal.demande_id
WHERE da.date_demande >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', da.date_demande), da.statut
ORDER BY mois DESC, statut""",
            },
            {
                "name": "kpi_purchase_appels_offre",
                "description": "Analyse des appels d'offre",
                "sql": """SELECT
    ao.titre,
    ao.statut,
    COUNT(DISTINCT afc.fournisseur_id) as nb_fournisseurs_consultes,
    COUNT(DISTINCT or_rec.id) as nb_offres_recues,
    AVG(or_rec.montant_total) as montant_moyen_offres,
    MIN(or_rec.montant_total) as meilleure_offre
FROM appel_offre ao
LEFT JOIN ao_fournisseur_consulte afc ON ao.id = afc.appel_offre_id
LEFT JOIN offre_recue or_rec ON ao.id = or_rec.appel_offre_id
WHERE ao.date_creation >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY ao.id, ao.titre, ao.statut
ORDER BY ao.date_creation DESC""",
            },
        ]

    @staticmethod
    def get_sale_templates() -> List[Dict]:
        """Templates KPI pour les ventes"""
        return [
            {
                "name": "kpi_sale_commandes_mensuelles",
                "description": "Évolution des commandes de vente",
                "sql": """SELECT
    DATE_TRUNC('month', o.created_at) as mois,
    COUNT(*) as nb_commandes,
    SUM(o.total_amount) as ca_total_euro,
    AVG(o.total_amount) as panier_moyen_euro,
    COUNT(DISTINCT o.customer_id) as nb_clients_uniques
FROM orders o
WHERE o.created_at >= CURRENT_DATE - INTERVAL '12 months'
    AND o.status != 'cancelled'
GROUP BY DATE_TRUNC('month', o.created_at)
ORDER BY mois DESC""",
            },
            {
                "name": "kpi_sale_performance_produits",
                "description": "Performance des produits vendus",
                "sql": """SELECT
    p.nom as produit,
    pc.nom as categorie,
    SUM(ol.quantity) as quantite_vendue,
    SUM(ol.quantity * ol.unit_price) as ca_produit_euro,
    AVG(ol.unit_price) as prix_moyen,
    COUNT(DISTINCT ol.order_id) as nb_commandes_concernees
FROM orders o
JOIN order_lines ol ON o.id = ol.order_id
JOIN piece p ON ol.product_id = p.id
JOIN piece_category pc ON p.category_id = pc.id
WHERE o.created_at >= CURRENT_DATE - INTERVAL '6 months'
    AND o.status = 'completed'
GROUP BY p.id, p.nom, pc.nom
ORDER BY ca_produit_euro DESC""",
            },
        ]
