-- =========================================
-- TEMPLATES SQL - MODULE GMAO
-- Gestion de la Maintenance Assistée par Ordinateur
-- Version adaptée au schéma réel de la base de données
-- =========================================

-- ====================
-- KPI 1: DISPONIBILITÉ DES MACHINES
-- ====================
-- Description: Calcul du taux de disponibilité des machines par période
-- Tables requises: machine, ordre_travail, maintenance
-- Métriques: taux de disponibilité, heures d'arrêt, nombre d'interventions

CREATE OR REPLACE VIEW kpi_gmao_machine_availability AS
SELECT 
    m.id_machine,
    m.nom,
    m.serial as numero_serie,
    m.modele,
    m.etat,
    m.localisation,
    COUNT(CASE WHEN ot.statut = 'Terminé' THEN 1 END) as nb_interventions_terminees,
    COUNT(CASE WHEN ot.statut = 'EnCours' THEN 1 END) as nb_interventions_en_cours,
    COUNT(CASE WHEN ot.statut = 'Planifié' THEN 1 END) as nb_interventions_planifiees,
    COUNT(CASE WHEN ot.statut = 'AttentePieces' THEN 1 END) as nb_attente_pieces,
    COUNT(CASE WHEN ot.statut = 'Pret' THEN 1 END) as nb_pret,
    COUNT(CASE WHEN ot.statut = 'Créé' THEN 1 END) as nb_cree,
    COALESCE(SUM(mt.duree_intervention_h), 0) as heures_maintenance_total,
    ROUND(
        (CASE 
            WHEN (CURRENT_DATE - DATE('2024-01-01')) * 24 > 0 
            THEN ((CURRENT_DATE - DATE('2024-01-01')) * 24 - 
                  COALESCE(SUM(mt.duree_intervention_h), 0)) / 
                 ((CURRENT_DATE - DATE('2024-01-01')) * 24) * 100
            ELSE 100
        END)::NUMERIC, 2
    ) as taux_disponibilite_pct
FROM machine m
LEFT JOIN ordre_travail ot ON m.id_machine = ot.machine_id 
    AND DATE(ot.date_creation) >= '2024-01-01'
LEFT JOIN maintenance mt ON ot.id_ot = mt.ot_id
GROUP BY m.id_machine, m.nom, m.serial, m.modele, m.etat, m.localisation
ORDER BY taux_disponibilite_pct DESC;

-- Commentaires
COMMENT ON VIEW kpi_gmao_machine_availability IS 'KPI de disponibilité des machines avec taux en pourcentage';
COMMENT ON COLUMN kpi_gmao_machine_availability.taux_disponibilite_pct IS 'Taux de disponibilité en pourcentage (0-100)';
COMMENT ON COLUMN kpi_gmao_machine_availability.heures_maintenance_total IS 'Heures de maintenance cumulées';

-- ====================
-- KPI 2: COÛTS DE MAINTENANCE
-- ====================
-- Description: Analyse des coûts de maintenance sur les 12 derniers mois
-- Tables requises: machine, ordre_travail, maintenance
-- Métriques: coût total, coût moyen, répartition par type

CREATE OR REPLACE VIEW kpi_gmao_maintenance_costs AS
SELECT 
    m.id_machine,
    m.nom as nom_machine,
    m.serial as numero_serie,
    m.modele,
    COUNT(mt.id_maintenance) as nb_interventions,
    COALESCE(SUM(mt.cout_total), 0) as cout_total,
    COALESCE(SUM(mt.cout_main_oeuvre), 0) as cout_main_oeuvre,
    COALESCE(SUM(mt.cout_pieces_internes), 0) as cout_pieces_internes,
    COALESCE(SUM(mt.cout_pieces_externes), 0) as cout_pieces_externes,
    COALESCE(SUM(mt.cout_autres_frais), 0) as cout_autres_frais,
    ROUND(
        (CASE 
            WHEN COUNT(mt.id_maintenance) > 0 
            THEN COALESCE(SUM(mt.cout_total), 0) / COUNT(mt.id_maintenance)
            ELSE 0 
        END)::NUMERIC, 2
    ) as cout_moyen_par_intervention,
    DATE_TRUNC('month', CURRENT_DATE) as periode_reference
FROM machine m
LEFT JOIN ordre_travail ot ON m.id_machine = ot.machine_id
LEFT JOIN maintenance mt ON ot.id_ot = mt.ot_id
    AND DATE(mt.date_debut_reelle) >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
GROUP BY m.id_machine, m.nom, m.serial, m.modele
HAVING COUNT(mt.id_maintenance) > 0 OR m.etat = 'EN_SERVICE'
ORDER BY cout_total DESC;

-- Commentaires
COMMENT ON VIEW kpi_gmao_maintenance_costs IS 'Analyse des coûts de maintenance par machine sur 12 mois';
COMMENT ON COLUMN kpi_gmao_maintenance_costs.cout_moyen_par_intervention IS 'Coût moyen par intervention en euros';
COMMENT ON COLUMN kpi_gmao_maintenance_costs.cout_total IS 'Coût total de maintenance sur la période';

-- ====================
-- KPI 3: TEMPS DE RÉPONSE AUX INTERVENTIONS
-- ====================
-- Description: Analyse des délais de traitement des ordres de travail
-- Tables requises: machine, ordre_travail, maintenance
-- Métriques: temps de réponse, durée d'intervention, taux de completion

CREATE OR REPLACE VIEW kpi_gmao_response_times AS
SELECT 
    m.id_machine,
    m.nom as nom_machine,
    m.modele,
    ot.type as type_intervention,
    ot.priorite,
    COUNT(*) as nb_ordres_travail,
    ROUND(
        (AVG(
            CASE 
                WHEN mt.date_debut_reelle IS NOT NULL AND ot.date_creation IS NOT NULL
                THEN DATE(mt.date_debut_reelle) - DATE(ot.date_creation)
                ELSE NULL
            END
        ))::NUMERIC, 2
    ) as delai_moyen_jours,
    ROUND(
        (AVG(
            CASE 
                WHEN mt.date_fin_reelle IS NOT NULL AND mt.date_debut_reelle IS NOT NULL
                THEN mt.duree_intervention_h
                ELSE NULL
            END
        ))::NUMERIC, 2
    ) as duree_moyenne_intervention_h,
    COUNT(CASE WHEN ot.statut = 'Terminé' THEN 1 END) as nb_termines,
    COUNT(CASE WHEN ot.statut = 'EnCours' THEN 1 END) as nb_en_cours,
    COUNT(CASE WHEN ot.statut = 'Planifié' THEN 1 END) as nb_planifies,
    COUNT(CASE WHEN ot.statut = 'AttentePieces' THEN 1 END) as nb_attente_pieces,
    COUNT(CASE WHEN ot.statut = 'Pret' THEN 1 END) as nb_pret,
    COUNT(CASE WHEN ot.statut = 'Créé' THEN 1 END) as nb_cree,
    ROUND(
        (COUNT(CASE WHEN ot.statut = 'Terminé' THEN 1 END) * 100.0 / COUNT(*))::NUMERIC, 2
    ) as taux_completion_pct
FROM machine m
INNER JOIN ordre_travail ot ON m.id_machine = ot.machine_id
LEFT JOIN maintenance mt ON ot.id_ot = mt.ot_id
WHERE DATE(ot.date_creation) >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
GROUP BY m.id_machine, m.nom, m.modele, ot.type, ot.priorite
HAVING COUNT(*) >= 1
ORDER BY delai_moyen_jours ASC, taux_completion_pct DESC;

-- Commentaires
COMMENT ON VIEW kpi_gmao_response_times IS 'KPI des temps de réponse et délais d''intervention';
COMMENT ON COLUMN kpi_gmao_response_times.delai_moyen_jours IS 'Délai moyen entre création OT et début intervention';
COMMENT ON COLUMN kpi_gmao_response_times.taux_completion_pct IS 'Taux de completion des ordres de travail en %';

-- ====================
-- KPI 4: DASHBOARD SYNTHÈSE GMAO
-- ====================
-- Description: Vue de synthèse pour tableau de bord général
-- Tables requises: machine, ordre_travail, maintenance
-- Métriques: indicateurs globaux sur 12 mois

CREATE OR REPLACE VIEW kpi_gmao_dashboard AS
SELECT 
    'SYNTHESE_GENERALE' as type_kpi,
    COUNT(DISTINCT m.id_machine) as nb_machines_total,
    COUNT(DISTINCT CASE WHEN m.etat = 'EN_SERVICE' THEN m.id_machine END) as nb_machines_actives,
    COUNT(DISTINCT ot.id_ot) as nb_ordres_travail_total,
    COUNT(DISTINCT CASE WHEN ot.statut = 'Terminé' THEN ot.id_ot END) as nb_ot_termines,
    COUNT(DISTINCT CASE WHEN ot.statut = 'EnCours' THEN ot.id_ot END) as nb_ot_en_cours,
    COUNT(DISTINCT CASE WHEN ot.statut = 'Planifié' THEN ot.id_ot END) as nb_ot_planifies,
    COUNT(DISTINCT CASE WHEN ot.statut = 'AttentePieces' THEN ot.id_ot END) as nb_ot_attente_pieces,
    COUNT(DISTINCT CASE WHEN ot.statut = 'Pret' THEN ot.id_ot END) as nb_ot_pret,
    COUNT(DISTINCT CASE WHEN ot.statut = 'Créé' THEN ot.id_ot END) as nb_ot_cree,
    COUNT(DISTINCT mt.id_maintenance) as nb_maintenances_realisees,
    ROUND(COALESCE(SUM(mt.cout_total), 0)::NUMERIC, 2) as cout_maintenance_total,
    ROUND(COALESCE(AVG(mt.duree_intervention_h), 0)::NUMERIC, 2) as duree_moyenne_intervention,
    CURRENT_DATE as date_maj
FROM machine m
LEFT JOIN ordre_travail ot ON m.id_machine = ot.machine_id
    AND DATE(ot.date_creation) >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
LEFT JOIN maintenance mt ON ot.id_ot = mt.ot_id;

-- Commentaires
COMMENT ON VIEW kpi_gmao_dashboard IS 'Dashboard de synthèse des KPIs GMAO sur 12 mois';
COMMENT ON COLUMN kpi_gmao_dashboard.cout_maintenance_total IS 'Coût total de maintenance sur la période';
COMMENT ON COLUMN kpi_gmao_dashboard.nb_machines_actives IS 'Nombre de machines en service actif';