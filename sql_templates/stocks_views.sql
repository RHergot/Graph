-- =====================================
-- TEMPLATES SQL - MODULE STOCKS
-- Gestion des stocks et inventaires
-- Version adaptée au schéma réel: tables PIECE et MOUVEMENT_STOCK
-- =====================================

-- ====================
-- KPI 1: ROTATION DES STOCKS
-- ====================
-- Description: Analyse de la rotation et performance des stocks
-- Tables requises: piece, mouvement_stock, type_mouvement
-- Métriques: taux de rotation, statut des stocks, valeurs

CREATE OR REPLACE VIEW kpi_stocks_inventory_turnover AS
SELECT 
    p.id_piece AS article_id,
    p.nom AS article_name,
    p.reference AS article_reference,
    p.categorie AS category,
    p.fournisseur_pref_id AS supplier_id,
    
    -- Stocks actuels
    p.stock_actuel AS current_stock_qty,
    p.stock_alerte AS min_stock_qty,
    p.stock_reserve AS reserve_stock_qty,
    p.prix_unitaire AS unit_price_eur,
    ROUND((p.stock_actuel * p.prix_unitaire)::NUMERIC, 2) AS current_stock_value_eur,
    
    -- Mouvements des 3 derniers mois 
    -- SORTIES (impact_stock = -1): consommation, retours, transferts sortants, pertes
    COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0) AS units_consumed_3m,
    -- ENTRÉES (impact_stock = 1): achats, retours, ajustements, transferts entrants
    COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (1, 2, 3, 7, 42) THEN ms.quantite ELSE 0 END), 0) AS units_received_3m,
    COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.cout_total ELSE 0 END), 0) AS consumption_value_3m_eur,
    
    -- Calculs de rotation
    CASE 
        WHEN p.stock_actuel > 0 THEN 
            ROUND((COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0)::NUMERIC / p.stock_actuel * 4), 2)  -- Annualisé
        ELSE 0 
    END AS annual_turnover_rate,
    
    CASE 
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0) > 0 THEN 
            ROUND((p.stock_actuel / (COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0)::NUMERIC / 3.0) * 30), 1)  -- Jours de stock
        ELSE 999 
    END AS days_of_stock,
    
    -- Statuts et classifications
    CASE 
        WHEN p.stock_actuel <= p.stock_alerte THEN 'CRITICAL_LOW'
        WHEN p.stock_actuel <= p.stock_alerte * 1.2 THEN 'LOW'
        WHEN p.stock_actuel >= p.stock_alerte * 10 THEN 'OVERSTOCK'
        WHEN p.stock_actuel >= p.stock_alerte * 5 THEN 'HIGH'
        ELSE 'NORMAL'
    END AS stock_status,
    
    CASE 
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0) = 0 THEN 'NO_MOVEMENT'
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0)::NUMERIC / NULLIF(p.stock_actuel, 0) * 4 >= 12 THEN 'FAST_MOVING'
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0)::NUMERIC / NULLIF(p.stock_actuel, 0) * 4 >= 4 THEN 'MEDIUM_MOVING'
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.quantite ELSE 0 END), 0)::NUMERIC / NULLIF(p.stock_actuel, 0) * 4 >= 1 THEN 'SLOW_MOVING'
        ELSE 'DEAD_STOCK'
    END AS movement_category,
    
    -- ABC Analysis (valeur des mouvements)
    CASE 
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.cout_total ELSE 0 END), 0) >= 5000 THEN 'A'
        WHEN COALESCE(SUM(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.cout_total ELSE 0 END), 0) >= 1000 THEN 'B'
        ELSE 'C'
    END AS abc_category,
    
    -- Métadonnées
    COALESCE(
        MAX(CASE WHEN ms.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43) THEN ms.date_mouvement END),
        MAX(CASE WHEN ms.type_mouvement_id IN (1, 2, 3, 7, 42) THEN ms.date_mouvement END)
    ) AS last_consumption_date,
    MAX(CASE WHEN ms.type_mouvement_id IN (1, 2, 3, 7, 42) THEN ms.date_mouvement END) AS last_receipt_date,
    CURRENT_DATE AS analysis_date
    
FROM piece p
LEFT JOIN mouvement_stock ms ON p.id_piece = ms.piece_id 
    AND ms.date_mouvement >= CURRENT_DATE - INTERVAL '3 months'
    AND ms.valide = true
    
WHERE p.statut = 'actif'

GROUP BY 
    p.id_piece, p.nom, p.reference, p.categorie, p.fournisseur_pref_id,
    p.stock_actuel, p.stock_alerte, p.stock_reserve, p.prix_unitaire

ORDER BY 
    annual_turnover_rate DESC,
    current_stock_value_eur DESC;

-- Commentaires
COMMENT ON VIEW kpi_stocks_inventory_turnover IS 'Analyse de la rotation des stocks avec classification ABC et statuts';
COMMENT ON COLUMN kpi_stocks_inventory_turnover.annual_turnover_rate IS 'Taux de rotation annualisé basé sur les 3 derniers mois';
COMMENT ON COLUMN kpi_stocks_inventory_turnover.days_of_stock IS 'Nombre de jours de stock restant au rythme actuel';
COMMENT ON COLUMN kpi_stocks_inventory_turnover.movement_category IS 'Classification: FAST/MEDIUM/SLOW_MOVING, DEAD_STOCK, NO_MOVEMENT';

-- ====================
-- KPI 2: VALEUR ET OBSOLESCENCE DES STOCKS
-- ====================
-- Description: Analyse de la valeur des stocks et détection d'obsolescence
-- Tables requises: piece, mouvement_stock
-- Métriques: valeur totale, âge moyen, obsolescence

DROP VIEW IF EXISTS kpi_stocks_value_aging;
CREATE VIEW kpi_stocks_value_aging AS
SELECT 
    p.categorie AS category,
    p.fournisseur_pref_id AS supplier_id,
    
    -- Compteurs
    COUNT(p.id_piece) AS total_articles,
    COUNT(CASE WHEN p.stock_actuel > 0 THEN 1 END) AS articles_in_stock,
    
    -- Valeurs
    ROUND(SUM(p.stock_actuel * p.prix_unitaire)::NUMERIC, 2) AS total_stock_value_eur,
    ROUND(AVG(p.stock_actuel * p.prix_unitaire)::NUMERIC, 2) AS avg_article_value_eur,
    
    -- Analyse par âge des stocks (dernière sortie)
    COUNT(CASE 
        WHEN last_movement.days_since_last_out <= 30 THEN 1 
    END) AS articles_moved_last_30d,
    
    COUNT(CASE 
        WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL THEN 1 
    END) AS articles_not_moved_90d,
    
    COUNT(CASE 
        WHEN last_movement.days_since_last_out > 180 OR last_movement.days_since_last_out IS NULL THEN 1 
    END) AS articles_not_moved_180d,
    
    -- Valeurs d'obsolescence
    ROUND(SUM(CASE 
        WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
        THEN p.stock_actuel * p.prix_unitaire 
        ELSE 0 
    END)::NUMERIC, 2) AS obsolete_stock_value_90d_eur,
    
    ROUND(SUM(CASE 
        WHEN last_movement.days_since_last_out > 180 OR last_movement.days_since_last_out IS NULL 
        THEN p.stock_actuel * p.prix_unitaire 
        ELSE 0 
    END)::NUMERIC, 2) AS obsolete_stock_value_180d_eur,
    
    -- Ratios d'obsolescence
    ROUND(
        (SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN p.stock_actuel * p.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(p.stock_actuel * p.prix_unitaire), 0))::NUMERIC,
        2
    ) AS obsolescence_ratio_90d_percent,
    
    -- Classification du risque
    CASE 
        WHEN (SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN p.stock_actuel * p.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(p.stock_actuel * p.prix_unitaire), 0))::NUMERIC >= 50 THEN 'HIGH_RISK'
        WHEN (SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN p.stock_actuel * p.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(p.stock_actuel * p.prix_unitaire), 0))::NUMERIC >= 25 THEN 'MEDIUM_RISK'
        WHEN (SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN p.stock_actuel * p.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(p.stock_actuel * p.prix_unitaire), 0))::NUMERIC >= 10 THEN 'LOW_RISK'
        ELSE 'MINIMAL_RISK'
    END AS obsolescence_risk_level
    
FROM piece p
LEFT JOIN (
    SELECT 
        piece_id,
        EXTRACT(days FROM (CURRENT_DATE - MAX(date_mouvement))) AS days_since_last_out
    FROM mouvement_stock 
    WHERE type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43)  -- Sorties uniquement
      AND valide = true
    GROUP BY piece_id
) last_movement ON p.id_piece = last_movement.piece_id

WHERE p.statut = 'actif'
  AND p.stock_actuel > 0

GROUP BY 
    p.categorie, p.fournisseur_pref_id

ORDER BY 
    total_stock_value_eur DESC,
    obsolescence_ratio_90d_percent DESC;

-- Commentaires
COMMENT ON VIEW kpi_stocks_value_aging IS 'Analyse de la valeur et obsolescence des stocks par catégorie';
COMMENT ON COLUMN kpi_stocks_value_aging.obsolescence_ratio_90d_percent IS 'Pourcentage de valeur de stock sans mouvement depuis 90 jours';
COMMENT ON COLUMN kpi_stocks_value_aging.obsolescence_risk_level IS 'Niveau de risque: MINIMAL/LOW/MEDIUM/HIGH_RISK';
-- ====================
-- KPI 3: PERFORMANCE DES RÉAPPROVISIONNEMENTS
-- ====================
-- Description: Analyse des commandes et réapprovisionnements
-- Tables requises: piece, mouvement_stock
-- Métriques: délais, ruptures de stock, prévisions

CREATE OR REPLACE VIEW kpi_stocks_replenishment_performance AS
SELECT 
    p.id_piece AS article_id,
    p.nom AS article_name,
    p.categorie AS category,
    p.fournisseur_pref_id AS supplier_id,
    
    -- Statut actuel
    p.stock_actuel AS current_stock,
    p.stock_alerte AS reorder_point,
    p.stock_reserve AS reserve_stock,
    
    -- Analyse des entrées (3 derniers mois)
    COUNT(ms_in.id) AS replenishment_count_3m,
    COALESCE(SUM(ms_in.quantite), 0) AS total_qty_received_3m,
    ROUND(COALESCE(AVG(ms_in.quantite), 0)::NUMERIC, 1) AS avg_replenishment_qty,
    
    -- Analyse des sorties pour calcul de consommation
    ROUND(COALESCE(AVG(ms_out.quantite), 0)::NUMERIC / 30.0, 2) AS daily_consumption_avg,
    
    -- Prédiction de rupture de stock
    CASE 
        WHEN p.stock_actuel <= 0 THEN 'OUT_OF_STOCK'
        WHEN p.stock_actuel <= p.stock_alerte THEN 'REORDER_NOW'
        WHEN movement_forecast.daily_consumption > 0 AND 
             p.stock_actuel / movement_forecast.daily_consumption <= 14 THEN 'REORDER_SOON'
        ELSE 'STOCK_OK'
    END AS stock_alert_status,
    
    -- Prévision de rupture (jours)
    CASE 
        WHEN movement_forecast.daily_consumption > 0 THEN 
            ROUND(p.stock_actuel / movement_forecast.daily_consumption, 0)
        ELSE 999
    END AS days_until_stockout,
    
    -- Performance globale basée sur rotation et stock
    CASE 
        WHEN p.stock_actuel <= 0 THEN 'CRITICAL'
        WHEN p.stock_actuel <= p.stock_alerte THEN 'POOR'
        WHEN p.stock_actuel >= p.stock_alerte * 10 THEN 'OVERSTOCKED'
        WHEN COUNT(ms_in.id) >= 3 AND COUNT(ms_out.id) >= 3 THEN 'GOOD'
        WHEN COUNT(ms_in.id) >= 1 OR COUNT(ms_out.id) >= 1 THEN 'AVERAGE'
        ELSE 'NO_DATA'
    END AS replenishment_performance,
    
    -- Dernières dates
    MAX(ms_in.date_mouvement) AS last_receipt_date,
    MAX(ms_out.date_mouvement) AS last_consumption_date,
    movement_forecast.daily_consumption AS daily_consumption_forecast
    
FROM piece p
LEFT JOIN mouvement_stock ms_in ON p.id_piece = ms_in.piece_id 
    AND ms_in.date_mouvement >= CURRENT_DATE - INTERVAL '3 months'
    AND ms_in.type_mouvement_id IN (1, 2, 3, 7, 42)  -- Entrées
    AND ms_in.valide = true
LEFT JOIN mouvement_stock ms_out ON p.id_piece = ms_out.piece_id 
    AND ms_out.date_mouvement >= CURRENT_DATE - INTERVAL '3 months'
    AND ms_out.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43)  -- Sorties
    AND ms_out.valide = true
LEFT JOIN (
    SELECT 
        piece_id,
        AVG(quantite) / 30.0 AS daily_consumption  -- Consommation journalière moyenne
    FROM mouvement_stock 
    WHERE date_mouvement >= CURRENT_DATE - INTERVAL '90 days'
      AND type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43)  -- Sorties uniquement
      AND valide = true
    GROUP BY piece_id
) movement_forecast ON p.id_piece = movement_forecast.piece_id

WHERE p.statut = 'actif'

GROUP BY 
    p.id_piece, p.nom, p.categorie, p.fournisseur_pref_id,
    p.stock_actuel, p.stock_alerte, p.stock_reserve,
    movement_forecast.daily_consumption

ORDER BY 
    days_until_stockout ASC,
    current_stock ASC;

-- Commentaires
COMMENT ON VIEW kpi_stocks_replenishment_performance IS 'Performance des réapprovisionnements avec alertes de rupture';
COMMENT ON COLUMN kpi_stocks_replenishment_performance.stock_alert_status IS 'Statut: OUT_OF_STOCK/REORDER_NOW/REORDER_SOON/STOCK_OK';
COMMENT ON COLUMN kpi_stocks_replenishment_performance.days_until_stockout IS 'Prévision de rupture en jours basée sur la consommation';

-- ====================
-- KPI 4: DASHBOARD SYNTHÈSE STOCKS
-- ====================
-- Description: Vue de synthèse pour tableau de bord général des stocks
-- Tables requises: piece, mouvement_stock
-- Métriques: indicateurs globaux et alertes

CREATE OR REPLACE VIEW kpi_stocks_dashboard AS
SELECT 
    'SYNTHESE_GENERALE' as type_kpi,
    
    -- Compteurs généraux
    COUNT(DISTINCT p.id_piece) as nb_articles_total,
    COUNT(DISTINCT CASE WHEN p.stock_actuel > 0 THEN p.id_piece END) as nb_articles_en_stock,
    COUNT(DISTINCT CASE WHEN p.stock_actuel <= p.stock_alerte THEN p.id_piece END) as nb_articles_alerte_min,
    COUNT(DISTINCT CASE WHEN p.stock_actuel >= p.stock_alerte * 10 THEN p.id_piece END) as nb_articles_surstockage,
    COUNT(DISTINCT CASE WHEN p.stock_actuel <= 0 THEN p.id_piece END) as nb_articles_rupture,
    
    -- Valeurs financières
    ROUND(SUM(p.stock_actuel * p.prix_unitaire)::NUMERIC, 2) as valeur_stock_total,
    ROUND(AVG(p.stock_actuel * p.prix_unitaire)::NUMERIC, 2) as valeur_moyenne_article,
    ROUND(SUM(CASE WHEN p.stock_actuel <= p.stock_alerte THEN p.stock_actuel * p.prix_unitaire ELSE 0 END)::NUMERIC, 2) as valeur_stock_critique,
    
    -- Mouvements (3 derniers mois)
    COUNT(DISTINCT ms_out.id) as nb_sorties_3m,
    COUNT(DISTINCT ms_in.id) as nb_entrees_3m,
    COALESCE(SUM(ms_out.quantite), 0) as quantite_sortie_3m,
    COALESCE(SUM(ms_in.quantite), 0) as quantite_entree_3m,
    ROUND(COALESCE(SUM(ms_out.cout_total), 0)::NUMERIC, 2) as valeur_consommation_3m,
    
    -- Ratios et indicateurs
    ROUND(
        COUNT(DISTINCT CASE WHEN p.stock_actuel <= p.stock_alerte THEN p.id_piece END) * 100.0 / 
        NULLIF(COUNT(DISTINCT p.id_piece), 0)::NUMERIC, 2
    ) as taux_alerte_stock_pct,
    
    ROUND(
        COUNT(DISTINCT CASE WHEN p.stock_actuel <= 0 THEN p.id_piece END) * 100.0 / 
        NULLIF(COUNT(DISTINCT p.id_piece), 0)::NUMERIC, 2
    ) as taux_rupture_pct,
    
    -- Obsolescence approximative (articles sans sortie depuis 90 jours)
    COUNT(DISTINCT CASE 
        WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
        THEN p.id_piece 
    END) as nb_articles_obsoletes_90j,
    
    ROUND(
        SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN p.stock_actuel * p.prix_unitaire 
            ELSE 0 
        END)::NUMERIC, 2
    ) as valeur_obsolescence_90j,
    
    -- Performance globale
    CASE 
        WHEN COUNT(DISTINCT CASE WHEN p.stock_actuel <= 0 THEN p.id_piece END) * 100.0 / 
             NULLIF(COUNT(DISTINCT p.id_piece), 0) >= 10 THEN 'CRITIQUE'
        WHEN COUNT(DISTINCT CASE WHEN p.stock_actuel <= p.stock_alerte THEN p.id_piece END) * 100.0 / 
             NULLIF(COUNT(DISTINCT p.id_piece), 0) >= 20 THEN 'ATTENTION'
        WHEN COUNT(DISTINCT CASE WHEN p.stock_actuel >= p.stock_alerte * 10 THEN p.id_piece END) * 100.0 / 
             NULLIF(COUNT(DISTINCT p.id_piece), 0) >= 15 THEN 'SURSTOCKAGE'
        ELSE 'NORMAL'
    END as statut_global_stocks,
    
    -- Métadonnées
    CURRENT_DATE as date_maj
    
FROM piece p
LEFT JOIN mouvement_stock ms_out ON p.id_piece = ms_out.piece_id 
    AND ms_out.date_mouvement >= CURRENT_DATE - INTERVAL '3 months'
    AND ms_out.type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43)  -- Sorties
    AND ms_out.valide = true
LEFT JOIN mouvement_stock ms_in ON p.id_piece = ms_in.piece_id 
    AND ms_in.date_mouvement >= CURRENT_DATE - INTERVAL '3 months'
    AND ms_in.type_mouvement_id IN (1, 2, 3, 7, 42)  -- Entrées
    AND ms_in.valide = true
LEFT JOIN (
    SELECT 
        piece_id,
        EXTRACT(days FROM (CURRENT_DATE - MAX(date_mouvement))) AS days_since_last_out
    FROM mouvement_stock 
    WHERE type_mouvement_id IN (4, 5, 6, 8, 9, 10, 43)  -- Sorties uniquement
      AND valide = true
    GROUP BY piece_id
) last_movement ON p.id_piece = last_movement.piece_id

WHERE p.statut = 'actif';

-- Commentaires
COMMENT ON VIEW kpi_stocks_dashboard IS 'Dashboard de synthèse des KPIs stocks avec alertes et indicateurs globaux';
COMMENT ON COLUMN kpi_stocks_dashboard.valeur_stock_total IS 'Valeur totale du stock en euros';
COMMENT ON COLUMN kpi_stocks_dashboard.taux_alerte_stock_pct IS 'Pourcentage d''articles en alerte stock minimum';
COMMENT ON COLUMN kpi_stocks_dashboard.statut_global_stocks IS 'Statut global: NORMAL/ATTENTION/CRITIQUE/SURSTOCKAGE';
