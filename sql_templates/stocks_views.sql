-- =====================================
-- TEMPLATES SQL - MODULE STOCKS
-- Gestion des stocks et inventaires
-- =====================================

-- ====================
-- KPI 1: ROTATION DES STOCKS
-- ====================
-- Description: Analyse de la rotation et performance des stocks
-- Tables requises: articles, entrees_stock, sorties_stock
-- Métriques: taux de rotation, statut des stocks, valeurs

CREATE OR REPLACE VIEW kpi_stocks_inventory_turnover AS
SELECT 
    a.id AS article_id,
    a.nom AS article_name,
    a.reference AS article_reference,
    a.categorie AS category,
    a.fournisseur_principal AS main_supplier,
    
    -- Stocks actuels
    a.stock_actuel AS current_stock_qty,
    a.stock_min AS min_stock_qty,
    a.stock_max AS max_stock_qty,
    a.prix_unitaire AS unit_price_eur,
    ROUND(a.stock_actuel * a.prix_unitaire, 2) AS current_stock_value_eur,
    
    -- Mouvements des 3 derniers mois
    COALESCE(SUM(s.quantite), 0) AS units_sold_3m,
    COALESCE(SUM(e.quantite), 0) AS units_received_3m,
    COALESCE(SUM(s.quantite * s.prix_unitaire), 0) AS sales_value_3m_eur,
    
    -- Calculs de rotation
    CASE 
        WHEN a.stock_actuel > 0 THEN 
            ROUND(COALESCE(SUM(s.quantite), 0) / a.stock_actuel * 4, 2)  -- Annualisé
        ELSE 0 
    END AS annual_turnover_rate,
    
    CASE 
        WHEN COALESCE(SUM(s.quantite), 0) > 0 THEN 
            ROUND(a.stock_actuel / (COALESCE(SUM(s.quantite), 0) / 3.0) * 30, 1)  -- Jours de stock
        ELSE 999 
    END AS days_of_stock,
    
    -- Statuts et classifications
    CASE 
        WHEN a.stock_actuel <= a.stock_min THEN 'CRITICAL_LOW'
        WHEN a.stock_actuel <= a.stock_min * 1.2 THEN 'LOW'
        WHEN a.stock_actuel >= a.stock_max THEN 'OVERSTOCK'
        WHEN a.stock_actuel >= a.stock_max * 0.8 THEN 'HIGH'
        ELSE 'NORMAL'
    END AS stock_status,
    
    CASE 
        WHEN COALESCE(SUM(s.quantite), 0) = 0 THEN 'NO_MOVEMENT'
        WHEN COALESCE(SUM(s.quantite), 0) / a.stock_actuel * 4 >= 12 THEN 'FAST_MOVING'
        WHEN COALESCE(SUM(s.quantite), 0) / a.stock_actuel * 4 >= 4 THEN 'MEDIUM_MOVING'
        WHEN COALESCE(SUM(s.quantite), 0) / a.stock_actuel * 4 >= 1 THEN 'SLOW_MOVING'
        ELSE 'DEAD_STOCK'
    END AS movement_category,
    
    -- ABC Analysis (valeur des mouvements)
    CASE 
        WHEN COALESCE(SUM(s.quantite * s.prix_unitaire), 0) >= 5000 THEN 'A'
        WHEN COALESCE(SUM(s.quantite * s.prix_unitaire), 0) >= 1000 THEN 'B'
        ELSE 'C'
    END AS abc_category,
    
    -- Métadonnées
    MAX(s.date_sortie) AS last_sale_date,
    MAX(e.date_entree) AS last_receipt_date,
    CURRENT_DATE AS analysis_date
    
FROM articles a
LEFT JOIN sorties_stock s ON a.id = s.article_id 
    AND s.date_sortie >= CURRENT_DATE - INTERVAL '3 months'
LEFT JOIN entrees_stock e ON a.id = e.article_id 
    AND e.date_entree >= CURRENT_DATE - INTERVAL '3 months'
    
WHERE a.actif = true

GROUP BY 
    a.id, a.nom, a.reference, a.categorie, a.fournisseur_principal,
    a.stock_actuel, a.stock_min, a.stock_max, a.prix_unitaire

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
-- Tables requises: articles, sorties_stock, entrees_stock
-- Métriques: valeur totale, âge moyen, obsolescence

CREATE OR REPLACE VIEW kpi_stocks_value_aging AS
SELECT 
    a.categorie AS category,
    a.fournisseur_principal AS main_supplier,
    
    -- Compteurs
    COUNT(a.id) AS total_articles,
    COUNT(CASE WHEN a.stock_actuel > 0 THEN 1 END) AS articles_in_stock,
    
    -- Valeurs
    SUM(a.stock_actuel * a.prix_unitaire) AS total_stock_value_eur,
    ROUND(AVG(a.stock_actuel * a.prix_unitaire), 2) AS avg_article_value_eur,
    
    -- Analyse par âge des stocks
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
    SUM(CASE 
        WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
        THEN a.stock_actuel * a.prix_unitaire 
        ELSE 0 
    END) AS obsolete_stock_value_90d_eur,
    
    SUM(CASE 
        WHEN last_movement.days_since_last_out > 180 OR last_movement.days_since_last_out IS NULL 
        THEN a.stock_actuel * a.prix_unitaire 
        ELSE 0 
    END) AS obsolete_stock_value_180d_eur,
    
    -- Ratios d'obsolescence
    ROUND(
        SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN a.stock_actuel * a.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(a.stock_actuel * a.prix_unitaire), 0),
        2
    ) AS obsolescence_ratio_90d_percent,
    
    -- Classification du risque
    CASE 
        WHEN SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN a.stock_actuel * a.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(a.stock_actuel * a.prix_unitaire), 0) >= 50 THEN 'HIGH_RISK'
        WHEN SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN a.stock_actuel * a.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(a.stock_actuel * a.prix_unitaire), 0) >= 25 THEN 'MEDIUM_RISK'
        WHEN SUM(CASE 
            WHEN last_movement.days_since_last_out > 90 OR last_movement.days_since_last_out IS NULL 
            THEN a.stock_actuel * a.prix_unitaire 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(a.stock_actuel * a.prix_unitaire), 0) >= 10 THEN 'LOW_RISK'
        ELSE 'MINIMAL_RISK'
    END AS obsolescence_risk_level
    
FROM articles a
LEFT JOIN (
    SELECT 
        article_id,
        EXTRACT(days FROM (CURRENT_DATE - MAX(date_sortie))) AS days_since_last_out
    FROM sorties_stock 
    GROUP BY article_id
) last_movement ON a.id = last_movement.article_id

WHERE a.actif = true
  AND a.stock_actuel > 0

GROUP BY 
    a.categorie, a.fournisseur_principal

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
-- Tables requises: entrees_stock, articles, commandes
-- Métriques: délais, ruptures de stock, prévisions

CREATE OR REPLACE VIEW kpi_stocks_replenishment_performance AS
SELECT 
    a.id AS article_id,
    a.nom AS article_name,
    a.categorie AS category,
    a.fournisseur_principal AS main_supplier,
    
    -- Statut actuel
    a.stock_actuel AS current_stock,
    a.stock_min AS reorder_point,
    a.stock_max AS max_stock,
    
    -- Analyse des entrées (3 derniers mois)
    COUNT(e.id) AS replenishment_count_3m,
    COALESCE(SUM(e.quantite), 0) AS total_qty_received_3m,
    COALESCE(AVG(e.quantite), 0) AS avg_replenishment_qty,
    
    -- Délais de livraison
    ROUND(AVG(EXTRACT(days FROM (e.date_entree - e.date_commande))), 1) AS avg_delivery_days,
    MIN(EXTRACT(days FROM (e.date_entree - e.date_commande))) AS min_delivery_days,
    MAX(EXTRACT(days FROM (e.date_entree - e.date_commande))) AS max_delivery_days,
    
    -- Fiabilité des livraisons
    COUNT(CASE 
        WHEN e.date_entree <= e.date_livraison_prevue THEN 1 
    END) AS on_time_deliveries,
    
    ROUND(
        COUNT(CASE WHEN e.date_entree <= e.date_livraison_prevue THEN 1 END) * 100.0 / 
        NULLIF(COUNT(e.id), 0),
        2
    ) AS on_time_delivery_rate_percent,
    
    -- Prédiction de rupture de stock
    CASE 
        WHEN a.stock_actuel <= 0 THEN 'OUT_OF_STOCK'
        WHEN a.stock_actuel <= a.stock_min THEN 'REORDER_NOW'
        WHEN movement_forecast.daily_consumption > 0 AND 
             a.stock_actuel / movement_forecast.daily_consumption <= 
             COALESCE(AVG(EXTRACT(days FROM (e.date_entree - e.date_commande))), 14) THEN 'REORDER_SOON'
        ELSE 'STOCK_OK'
    END AS stock_alert_status,
    
    -- Prévision de rupture (jours)
    CASE 
        WHEN movement_forecast.daily_consumption > 0 THEN 
            ROUND(a.stock_actuel / movement_forecast.daily_consumption, 0)
        ELSE 999
    END AS days_until_stockout,
    
    -- Performance globale
    CASE 
        WHEN COUNT(e.id) = 0 THEN 'NO_DATA'
        WHEN ROUND(
            COUNT(CASE WHEN e.date_entree <= e.date_livraison_prevue THEN 1 END) * 100.0 / 
            NULLIF(COUNT(e.id), 0), 2
        ) >= 95 AND 
        ROUND(AVG(EXTRACT(days FROM (e.date_entree - e.date_commande))), 1) <= 7 THEN 'EXCELLENT'
        WHEN ROUND(
            COUNT(CASE WHEN e.date_entree <= e.date_livraison_prevue THEN 1 END) * 100.0 / 
            NULLIF(COUNT(e.id), 0), 2
        ) >= 85 AND 
        ROUND(AVG(EXTRACT(days FROM (e.date_entree - e.date_commande))), 1) <= 14 THEN 'GOOD'
        WHEN ROUND(
            COUNT(CASE WHEN e.date_entree <= e.date_livraison_prevue THEN 1 END) * 100.0 / 
            NULLIF(COUNT(e.id), 0), 2
        ) >= 70 THEN 'AVERAGE'
        ELSE 'POOR'
    END AS replenishment_performance,
    
    -- Dernières dates
    MAX(e.date_entree) AS last_receipt_date,
    movement_forecast.daily_consumption
    
FROM articles a
LEFT JOIN entrees_stock e ON a.id = e.article_id 
    AND e.date_entree >= CURRENT_DATE - INTERVAL '3 months'
    AND e.date_commande IS NOT NULL
LEFT JOIN (
    SELECT 
        article_id,
        AVG(quantite) / 30.0 AS daily_consumption  -- Consommation journalière moyenne
    FROM sorties_stock 
    WHERE date_sortie >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY article_id
) movement_forecast ON a.id = movement_forecast.article_id

WHERE a.actif = true

GROUP BY 
    a.id, a.nom, a.categorie, a.fournisseur_principal,
    a.stock_actuel, a.stock_min, a.stock_max,
    movement_forecast.daily_consumption

ORDER BY 
    days_until_stockout ASC,
    on_time_delivery_rate_percent DESC;

-- Commentaires
COMMENT ON VIEW kpi_stocks_replenishment_performance IS 'Performance des réapprovisionnements avec alertes de rupture';
COMMENT ON COLUMN kpi_stocks_replenishment_performance.stock_alert_status IS 'Statut: OUT_OF_STOCK/REORDER_NOW/REORDER_SOON/STOCK_OK';
COMMENT ON COLUMN kpi_stocks_replenishment_performance.days_until_stockout IS 'Prévision de rupture en jours basée sur la consommation';
