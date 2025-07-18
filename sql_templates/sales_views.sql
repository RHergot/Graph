-- =====================================
-- TEMPLATES SQL - MODULE SALES
-- Gestion des ventes et performance commerciale
-- =====================================

-- ====================
-- KPI 1: PERFORMANCE DES VENTES
-- ====================
-- Description: Analyse de la performance commerciale globale
-- Tables requises: ventes, lignes_ventes, clients, vendeurs
-- Métriques: CA, volumes, tendances, objectifs

CREATE OR REPLACE VIEW kpi_sales_performance AS
SELECT 
    DATE_TRUNC('day', v.date_vente) AS sale_date,
    TO_CHAR(v.date_vente, 'YYYY-MM') AS month_year,
    TO_CHAR(v.date_vente, 'YYYY-"W"WW') AS week_year,
    EXTRACT(YEAR FROM v.date_vente) AS year,
    EXTRACT(MONTH FROM v.date_vente) AS month,
    EXTRACT(WEEK FROM v.date_vente) AS week_number,
    EXTRACT(DOW FROM v.date_vente) AS day_of_week,  -- 0=Dimanche, 6=Samedi
    
    -- Métriques quotidiennes
    COUNT(v.id) AS daily_transactions,
    COUNT(DISTINCT v.client_id) AS unique_customers,
    SUM(v.montant_total) AS daily_revenue_eur,
    ROUND(AVG(v.montant_total), 2) AS avg_transaction_value_eur,
    SUM(lv.quantite) AS total_units_sold,
    
    -- Analyse par canal de vente
    COUNT(CASE WHEN v.canal_vente = 'magasin' THEN 1 END) AS store_transactions,
    COUNT(CASE WHEN v.canal_vente = 'online' THEN 1 END) AS online_transactions,
    COUNT(CASE WHEN v.canal_vente = 'telephone' THEN 1 END) AS phone_transactions,
    
    SUM(CASE WHEN v.canal_vente = 'magasin' THEN v.montant_total ELSE 0 END) AS store_revenue_eur,
    SUM(CASE WHEN v.canal_vente = 'online' THEN v.montant_total ELSE 0 END) AS online_revenue_eur,
    SUM(CASE WHEN v.canal_vente = 'telephone' THEN v.montant_total ELSE 0 END) AS phone_revenue_eur,
    
    -- Moyennes mobiles (7 jours)
    ROUND(AVG(SUM(v.montant_total)) OVER (
        ORDER BY DATE_TRUNC('day', v.date_vente) 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS revenue_7d_moving_avg,
    
    -- Comparaison avec la période précédente
    LAG(SUM(v.montant_total), 7) OVER (
        ORDER BY DATE_TRUNC('day', v.date_vente)
    ) AS revenue_same_day_last_week,
    
    ROUND(
        (SUM(v.montant_total) - LAG(SUM(v.montant_total), 7) OVER (
            ORDER BY DATE_TRUNC('day', v.date_vente)
        )) * 100.0 / NULLIF(
            LAG(SUM(v.montant_total), 7) OVER (
                ORDER BY DATE_TRUNC('day', v.date_vente)
            ), 0
        ), 2
    ) AS revenue_growth_wow_percent,
    
    -- Cumul mensuel
    SUM(SUM(v.montant_total)) OVER (
        PARTITION BY TO_CHAR(v.date_vente, 'YYYY-MM') 
        ORDER BY DATE_TRUNC('day', v.date_vente)
    ) AS monthly_cumulative_revenue_eur,
    
    -- Objectifs et performance (supposant une table objectifs_ventes)
    COALESCE(obj.objectif_ca_jour, 0) AS daily_target_eur,
    ROUND(
        SUM(v.montant_total) * 100.0 / NULLIF(COALESCE(obj.objectif_ca_jour, 1), 0), 2
    ) AS target_achievement_percent,
    
    -- Classification de performance
    CASE 
        WHEN SUM(v.montant_total) >= COALESCE(obj.objectif_ca_jour, 0) * 1.2 THEN 'EXCELLENT'
        WHEN SUM(v.montant_total) >= COALESCE(obj.objectif_ca_jour, 0) THEN 'TARGET_MET'
        WHEN SUM(v.montant_total) >= COALESCE(obj.objectif_ca_jour, 0) * 0.8 THEN 'CLOSE_TO_TARGET'
        ELSE 'BELOW_TARGET'
    END AS performance_status,
    
    -- Indicateurs de saisonnalité
    CASE 
        WHEN EXTRACT(DOW FROM v.date_vente) IN (0, 6) THEN 'WEEKEND'
        ELSE 'WEEKDAY'
    END AS day_type,
    
    CASE 
        WHEN EXTRACT(MONTH FROM v.date_vente) IN (12, 1, 2) THEN 'WINTER'
        WHEN EXTRACT(MONTH FROM v.date_vente) IN (3, 4, 5) THEN 'SPRING'
        WHEN EXTRACT(MONTH FROM v.date_vente) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END AS season
    
FROM ventes v
INNER JOIN lignes_ventes lv ON v.id = lv.vente_id
LEFT JOIN objectifs_ventes obj ON DATE_TRUNC('day', v.date_vente) = obj.date_objectif

WHERE v.date_vente >= CURRENT_DATE - INTERVAL '6 months'
  AND v.statut = 'validee'

GROUP BY 
    DATE_TRUNC('day', v.date_vente),
    TO_CHAR(v.date_vente, 'YYYY-MM'),
    TO_CHAR(v.date_vente, 'YYYY-"W"WW'),
    EXTRACT(YEAR FROM v.date_vente),
    EXTRACT(MONTH FROM v.date_vente),
    EXTRACT(WEEK FROM v.date_vente),
    EXTRACT(DOW FROM v.date_vente),
    COALESCE(obj.objectif_ca_jour, 0),
    CASE 
        WHEN EXTRACT(DOW FROM v.date_vente) IN (0, 6) THEN 'WEEKEND'
        ELSE 'WEEKDAY'
    END,
    CASE 
        WHEN EXTRACT(MONTH FROM v.date_vente) IN (12, 1, 2) THEN 'WINTER'
        WHEN EXTRACT(MONTH FROM v.date_vente) IN (3, 4, 5) THEN 'SPRING'
        WHEN EXTRACT(MONTH FROM v.date_vente) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END

ORDER BY 
    sale_date DESC;

-- Commentaires
COMMENT ON VIEW kpi_sales_performance IS 'Performance des ventes avec tendances, objectifs et saisonnalité';
COMMENT ON COLUMN kpi_sales_performance.revenue_7d_moving_avg IS 'Moyenne mobile du CA sur 7 jours';
COMMENT ON COLUMN kpi_sales_performance.revenue_growth_wow_percent IS 'Croissance du CA par rapport à la même période semaine précédente';
COMMENT ON COLUMN kpi_sales_performance.performance_status IS 'Statut: EXCELLENT/TARGET_MET/CLOSE_TO_TARGET/BELOW_TARGET';

-- ====================
-- KPI 2: ANALYSE CLIENTS ET SEGMENTATION
-- ====================
-- Description: Segmentation et analyse comportementale des clients
-- Tables requises: clients, ventes, lignes_ventes
-- Métriques: RFM, LTV, segments

CREATE OR REPLACE VIEW kpi_sales_customer_analysis AS
SELECT 
    c.id AS customer_id,
    c.nom AS customer_name,
    c.type_client AS customer_type,
    c.segment AS customer_segment,
    c.ville AS customer_city,
    c.pays AS customer_country,
    
    -- Métriques de base (12 derniers mois)
    COUNT(v.id) AS total_orders_12m,
    SUM(v.montant_total) AS total_spent_12m_eur,
    ROUND(AVG(v.montant_total), 2) AS avg_order_value_eur,
    SUM(lv.quantite) AS total_items_purchased,
    
    -- Analyse RFM (Recency, Frequency, Monetary)
    EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) AS recency_days,
    COUNT(v.id) AS frequency_orders,
    SUM(v.montant_total) AS monetary_value_eur,
    
    -- Scores RFM (1-5, 5 étant le meilleur)
    CASE 
        WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 30 THEN 5
        WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 60 THEN 4
        WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 90 THEN 3
        WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 180 THEN 2
        ELSE 1
    END AS recency_score,
    
    CASE 
        WHEN COUNT(v.id) >= 20 THEN 5
        WHEN COUNT(v.id) >= 10 THEN 4
        WHEN COUNT(v.id) >= 5 THEN 3
        WHEN COUNT(v.id) >= 2 THEN 2
        ELSE 1
    END AS frequency_score,
    
    CASE 
        WHEN SUM(v.montant_total) >= 10000 THEN 5
        WHEN SUM(v.montant_total) >= 5000 THEN 4
        WHEN SUM(v.montant_total) >= 2000 THEN 3
        WHEN SUM(v.montant_total) >= 500 THEN 2
        ELSE 1
    END AS monetary_score,
    
    -- Segmentation RFM
    CASE 
        WHEN (CASE 
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 30 THEN 5
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 60 THEN 4
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 90 THEN 3
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 180 THEN 2
            ELSE 1
        END) >= 4 AND 
        (CASE 
            WHEN COUNT(v.id) >= 20 THEN 5
            WHEN COUNT(v.id) >= 10 THEN 4
            WHEN COUNT(v.id) >= 5 THEN 3
            WHEN COUNT(v.id) >= 2 THEN 2
            ELSE 1
        END) >= 4 AND 
        (CASE 
            WHEN SUM(v.montant_total) >= 10000 THEN 5
            WHEN SUM(v.montant_total) >= 5000 THEN 4
            WHEN SUM(v.montant_total) >= 2000 THEN 3
            WHEN SUM(v.montant_total) >= 500 THEN 2
            ELSE 1
        END) >= 4 THEN 'CHAMPIONS'
        
        WHEN (CASE 
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 30 THEN 5
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 60 THEN 4
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 90 THEN 3
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 180 THEN 2
            ELSE 1
        END) >= 3 AND 
        (CASE 
            WHEN SUM(v.montant_total) >= 10000 THEN 5
            WHEN SUM(v.montant_total) >= 5000 THEN 4
            WHEN SUM(v.montant_total) >= 2000 THEN 3
            WHEN SUM(v.montant_total) >= 500 THEN 2
            ELSE 1
        END) >= 4 THEN 'LOYAL_CUSTOMERS'
        
        WHEN (CASE 
            WHEN SUM(v.montant_total) >= 10000 THEN 5
            WHEN SUM(v.montant_total) >= 5000 THEN 4
            WHEN SUM(v.montant_total) >= 2000 THEN 3
            WHEN SUM(v.montant_total) >= 500 THEN 2
            ELSE 1
        END) >= 4 THEN 'BIG_SPENDERS'
        
        WHEN (CASE 
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 30 THEN 5
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 60 THEN 4
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 90 THEN 3
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 180 THEN 2
            ELSE 1
        END) >= 4 THEN 'NEW_CUSTOMERS'
        
        WHEN (CASE 
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 30 THEN 5
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 60 THEN 4
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 90 THEN 3
            WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) <= 180 THEN 2
            ELSE 1
        END) <= 2 AND 
        (CASE 
            WHEN SUM(v.montant_total) >= 10000 THEN 5
            WHEN SUM(v.montant_total) >= 5000 THEN 4
            WHEN SUM(v.montant_total) >= 2000 THEN 3
            WHEN SUM(v.montant_total) >= 500 THEN 2
            ELSE 1
        END) >= 3 THEN 'AT_RISK'
        
        ELSE 'LOST_CUSTOMERS'
    END AS rfm_segment,
    
    -- Lifetime Value (LTV) estimé
    ROUND(
        SUM(v.montant_total) / NULLIF(
            EXTRACT(days FROM (MAX(v.date_vente) - MIN(v.date_vente))) + 1, 0
        ) * 365 * 2,  -- Projection sur 2 ans
        2
    ) AS estimated_ltv_eur,
    
    -- Préférences produits
    modes.preferred_category,
    modes.preferred_channel,
    
    -- Dates importantes
    MIN(v.date_vente) AS first_purchase_date,
    MAX(v.date_vente) AS last_purchase_date,
    EXTRACT(days FROM (MAX(v.date_vente) - MIN(v.date_vente))) + 1 AS customer_lifespan_days,
    
    -- Indicateurs de fidélité
    ROUND(
        COUNT(v.id)::numeric / NULLIF(
            EXTRACT(days FROM (MAX(v.date_vente) - MIN(v.date_vente))) + 1, 0
        ) * 30, 2
    ) AS avg_orders_per_month,
    
    -- Potentiel de croissance
    CASE 
        WHEN COUNT(v.id) = 1 THEN 'SINGLE_PURCHASE'
        WHEN EXTRACT(days FROM (CURRENT_DATE - MAX(v.date_vente))) > 180 THEN 'REACTIVATION_NEEDED'
        WHEN SUM(v.montant_total) < 1000 AND COUNT(v.id) >= 5 THEN 'UPSELL_OPPORTUNITY'
        WHEN COUNT(v.id) < 5 AND SUM(v.montant_total) >= 2000 THEN 'ENGAGEMENT_OPPORTUNITY'
        ELSE 'MAINTAIN_RELATIONSHIP'
    END AS growth_opportunity
    
FROM clients c
INNER JOIN ventes v ON c.id = v.client_id
INNER JOIN lignes_ventes lv ON v.id = lv.vente_id
LEFT JOIN (
    -- Préférences modales
    SELECT 
        client_id,
        MODE() WITHIN GROUP (ORDER BY categorie) AS preferred_category,
        MODE() WITHIN GROUP (ORDER BY canal_vente) AS preferred_channel
    FROM ventes v2
    INNER JOIN lignes_ventes lv2 ON v2.id = lv2.vente_id
    INNER JOIN articles a2 ON lv2.article_id = a2.id
    WHERE v2.date_vente >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY client_id
) modes ON c.id = modes.client_id

WHERE v.date_vente >= CURRENT_DATE - INTERVAL '12 months'
  AND v.statut = 'validee'

GROUP BY 
    c.id, c.nom, c.type_client, c.segment, c.ville, c.pays,
    modes.preferred_category, modes.preferred_channel

ORDER BY 
    total_spent_12m_eur DESC,
    frequency_orders DESC;

-- Commentaires
COMMENT ON VIEW kpi_sales_customer_analysis IS 'Analyse RFM et segmentation client avec LTV et opportunités de croissance';
COMMENT ON COLUMN kpi_sales_customer_analysis.rfm_segment IS 'Segment RFM: CHAMPIONS/LOYAL_CUSTOMERS/BIG_SPENDERS/NEW_CUSTOMERS/AT_RISK/LOST_CUSTOMERS';
COMMENT ON COLUMN kpi_sales_customer_analysis.estimated_ltv_eur IS 'Lifetime Value estimée sur 2 ans basée sur l\'historique';
COMMENT ON COLUMN kpi_sales_customer_analysis.growth_opportunity IS 'Opportunité: SINGLE_PURCHASE/REACTIVATION_NEEDED/UPSELL_OPPORTUNITY/ENGAGEMENT_OPPORTUNITY/MAINTAIN_RELATIONSHIP';

-- ====================
-- KPI 3: ANALYSE PRODUITS ET RENTABILITÉ
-- ====================
-- Description: Performance des produits et analyse de rentabilité
-- Tables requises: articles, lignes_ventes, ventes
-- Métriques: marge, rotation, contribution

CREATE OR REPLACE VIEW kpi_sales_product_profitability AS
SELECT 
    a.id AS product_id,
    a.nom AS product_name,
    a.reference AS product_reference,
    a.categorie AS product_category,
    a.marque AS product_brand,
    
    -- Volumes de vente (3 derniers mois)
    COUNT(lv.id) AS line_items_sold_3m,
    SUM(lv.quantite) AS total_quantity_sold_3m,
    COUNT(DISTINCT lv.vente_id) AS orders_containing_product_3m,
    
    -- Métriques financières
    SUM(lv.quantite * lv.prix_unitaire) AS total_revenue_3m_eur,
    SUM(lv.quantite * a.cout_unitaire) AS total_cost_3m_eur,
    SUM(lv.quantite * (lv.prix_unitaire - a.cout_unitaire)) AS total_margin_3m_eur,
    
    -- Moyennes et prix
    ROUND(AVG(lv.prix_unitaire), 2) AS avg_selling_price_eur,
    a.cout_unitaire AS unit_cost_eur,
    ROUND(AVG(lv.prix_unitaire - a.cout_unitaire), 2) AS avg_unit_margin_eur,
    
    -- Ratios de rentabilité
    ROUND(
        (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0), 
        2
    ) AS margin_rate_percent,
    
    ROUND(
        SUM(lv.quantite * (lv.prix_unitaire - a.cout_unitaire)) * 100.0 / 
        NULLIF(SUM(lv.quantite * lv.prix_unitaire), 0), 
        2
    ) AS total_margin_rate_percent,
    
    -- Contribution au CA
    ROUND(
        SUM(lv.quantite * lv.prix_unitaire) * 100.0 / 
        total_sales.total_revenue_all_products,
        2
    ) AS revenue_contribution_percent,
    
    -- Analyse ABC (contribution au CA)
    CASE 
        WHEN SUM(lv.quantite * lv.prix_unitaire) * 100.0 / 
             total_sales.total_revenue_all_products >= 20 THEN 'A'
        WHEN SUM(lv.quantite * lv.prix_unitaire) * 100.0 / 
             total_sales.total_revenue_all_products >= 5 THEN 'B'
        ELSE 'C'
    END AS abc_revenue_category,
    
    -- Analyse ABC (contribution à la marge)
    CASE 
        WHEN SUM(lv.quantite * (lv.prix_unitaire - a.cout_unitaire)) * 100.0 / 
             total_sales.total_margin_all_products >= 20 THEN 'A'
        WHEN SUM(lv.quantite * (lv.prix_unitaire - a.cout_unitaire)) * 100.0 / 
             total_sales.total_margin_all_products >= 5 THEN 'B'
        ELSE 'C'
    END AS abc_margin_category,
    
    -- Vitesse de rotation
    ROUND(
        SUM(lv.quantite) / NULLIF(a.stock_actuel, 0) * 4,  -- Annualisé sur base 3 mois
        2
    ) AS annual_turnover_rate,
    
    -- Classification de performance
    CASE 
        WHEN SUM(lv.quantite * (lv.prix_unitaire - a.cout_unitaire)) >= 1000 AND 
             SUM(lv.quantite) >= 50 THEN 'STAR_PRODUCT'
        WHEN (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0) >= 30 AND
             SUM(lv.quantite) >= 20 THEN 'CASH_COW'
        WHEN SUM(lv.quantite) >= 100 AND 
             (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0) < 15 THEN 'VOLUME_PRODUCT'
        WHEN SUM(lv.quantite) < 10 AND 
             (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0) >= 40 THEN 'NICHE_PRODUCT'
        WHEN SUM(lv.quantite) < 5 THEN 'SLOW_MOVER'
        ELSE 'STANDARD_PRODUCT'
    END AS product_performance_category,
    
    -- Tendances
    ROUND(
        (SUM(CASE WHEN v.date_vente >= CURRENT_DATE - INTERVAL '1 month' THEN lv.quantite ELSE 0 END) - 
         SUM(CASE WHEN v.date_vente < CURRENT_DATE - INTERVAL '1 month' AND v.date_vente >= CURRENT_DATE - INTERVAL '2 months' THEN lv.quantite ELSE 0 END)) * 100.0 /
        NULLIF(SUM(CASE WHEN v.date_vente < CURRENT_DATE - INTERVAL '1 month' AND v.date_vente >= CURRENT_DATE - INTERVAL '2 months' THEN lv.quantite ELSE 0 END), 0),
        2
    ) AS sales_trend_last_month_percent,
    
    -- Recommandations d'action
    CASE 
        WHEN SUM(lv.quantite) < 5 AND a.stock_actuel > 50 THEN 'REDUCE_INVENTORY'
        WHEN (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0) < 10 THEN 'INCREASE_PRICE'
        WHEN SUM(lv.quantite) >= 100 AND 
             (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0) >= 25 THEN 'PROMOTE_MORE'
        WHEN SUM(lv.quantite) < 10 AND 
             (AVG(lv.prix_unitaire - a.cout_unitaire) * 100.0) / NULLIF(AVG(lv.prix_unitaire), 0) < 15 THEN 'DISCONTINUE'
        ELSE 'MAINTAIN_STRATEGY'
    END AS recommended_action,
    
    -- Données de référence
    a.stock_actuel AS current_stock,
    MIN(v.date_vente) AS first_sale_date,
    MAX(v.date_vente) AS last_sale_date
    
FROM articles a
INNER JOIN lignes_ventes lv ON a.id = lv.article_id
INNER JOIN ventes v ON lv.vente_id = v.id
CROSS JOIN (
    -- Totaux pour calculs de contribution
    SELECT 
        SUM(lv2.quantite * lv2.prix_unitaire) AS total_revenue_all_products,
        SUM(lv2.quantite * (lv2.prix_unitaire - a2.cout_unitaire)) AS total_margin_all_products
    FROM lignes_ventes lv2
    INNER JOIN ventes v2 ON lv2.vente_id = v2.id
    INNER JOIN articles a2 ON lv2.article_id = a2.id
    WHERE v2.date_vente >= CURRENT_DATE - INTERVAL '3 months'
      AND v2.statut = 'validee'
) total_sales

WHERE v.date_vente >= CURRENT_DATE - INTERVAL '3 months'
  AND v.statut = 'validee'
  AND a.actif = true

GROUP BY 
    a.id, a.nom, a.reference, a.categorie, a.marque, 
    a.cout_unitaire, a.stock_actuel,
    total_sales.total_revenue_all_products,
    total_sales.total_margin_all_products

HAVING SUM(lv.quantite) > 0  -- Exclure les produits sans ventes

ORDER BY 
    total_margin_3m_eur DESC,
    total_revenue_3m_eur DESC;

-- Commentaires
COMMENT ON VIEW kpi_sales_product_profitability IS 'Analyse de rentabilité des produits avec classification ABC et recommandations';
COMMENT ON COLUMN kpi_sales_product_profitability.product_performance_category IS 'Catégorie: STAR_PRODUCT/CASH_COW/VOLUME_PRODUCT/NICHE_PRODUCT/SLOW_MOVER/STANDARD_PRODUCT';
COMMENT ON COLUMN kpi_sales_product_profitability.recommended_action IS 'Action recommandée: REDUCE_INVENTORY/INCREASE_PRICE/PROMOTE_MORE/DISCONTINUE/MAINTAIN_STRATEGY';
