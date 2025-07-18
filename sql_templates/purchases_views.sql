-- =====================================
-- TEMPLATES SQL - MODULE PURCHASES
-- Gestion des achats et fournisseurs
-- =====================================

-- ====================
-- KPI 1: PERFORMANCE DES FOURNISSEURS
-- ====================
-- Description: Évaluation de la performance des fournisseurs
-- Tables requises: commandes, fournisseurs, lignes_commandes
-- Métriques: délais, qualité, coûts, fiabilité

CREATE OR REPLACE VIEW kpi_purchases_supplier_performance AS
SELECT 
    f.id AS supplier_id,
    f.nom AS supplier_name,
    f.pays AS supplier_country,
    f.type_fournisseur AS supplier_type,
    f.note_evaluation AS supplier_rating,
    TO_CHAR(c.date_commande, 'YYYY-MM') AS period_month,
    EXTRACT(YEAR FROM c.date_commande) AS year,
    EXTRACT(MONTH FROM c.date_commande) AS month,
    
    -- Compteurs de commandes
    COUNT(c.id) AS total_orders,
    COUNT(CASE WHEN c.statut = 'livree' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN c.statut = 'annulee' THEN 1 END) AS cancelled_orders,
    COUNT(CASE WHEN c.statut = 'en_cours' THEN 1 END) AS pending_orders,
    
    -- Valeurs financières
    SUM(c.montant_total) AS total_order_value_eur,
    ROUND(AVG(c.montant_total), 2) AS avg_order_value_eur,
    SUM(CASE WHEN c.statut = 'livree' THEN c.montant_total ELSE 0 END) AS delivered_value_eur,
    
    -- Délais de livraison
    ROUND(AVG(
        CASE WHEN c.date_livraison IS NOT NULL THEN 
            EXTRACT(days FROM (c.date_livraison - c.date_commande))
        END
    ), 1) AS avg_delivery_days,
    
    ROUND(AVG(
        CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
            EXTRACT(days FROM (c.date_livraison - c.date_livraison_prevue))
        END
    ), 1) AS avg_delay_days,
    
    -- Respect des délais
    COUNT(CASE 
        WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
             AND c.date_livraison <= c.date_livraison_prevue THEN 1 
    END) AS on_time_deliveries,
    
    ROUND(
        COUNT(CASE 
            WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                 AND c.date_livraison <= c.date_livraison_prevue THEN 1 
        END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0),
        2
    ) AS on_time_delivery_rate_percent,
    
    -- Qualité (basée sur les retours et réclamations)
    COUNT(CASE WHEN c.note_qualite >= 4 THEN 1 END) AS high_quality_orders,
    COUNT(CASE WHEN c.note_qualite <= 2 THEN 1 END) AS low_quality_orders,
    ROUND(AVG(c.note_qualite), 2) AS avg_quality_rating,
    
    -- Flexibilité et réactivité
    COUNT(CASE 
        WHEN c.date_livraison IS NOT NULL AND 
             EXTRACT(days FROM (c.date_livraison - c.date_commande)) <= 7 THEN 1 
    END) AS fast_deliveries_7d,
    
    -- Analyse des prix
    price_analysis.price_competitiveness,
    price_analysis.price_trend,
    
    -- Score de performance global (0-100)
    ROUND(
        (
            -- Délais (30%)
            GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                    EXTRACT(days FROM (c.date_livraison - c.date_livraison_prevue))
                END
            ), 0) * 5)) * 0.30 +
            
            -- Qualité (25%)
            COALESCE(AVG(c.note_qualite), 3) * 20 * 0.25 +
            
            -- Respect délais (25%)
            COALESCE(
                COUNT(CASE 
                    WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                         AND c.date_livraison <= c.date_livraison_prevue THEN 1 
                END) * 100.0 / 
                NULLIF(COUNT(CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0),
                50
            ) * 0.25 +
            
            -- Fiabilité (20%)
            (100 - COUNT(CASE WHEN c.statut = 'annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id), 1)) * 0.20
        ),
        1
    ) AS performance_score,
    
    -- Classification de performance
    CASE 
        WHEN ROUND(
            (
                GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                    CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                        EXTRACT(days FROM (c.date_livraison - c.date_livraison_prevue))
                    END
                ), 0) * 5)) * 0.30 +
                COALESCE(AVG(c.note_qualite), 3) * 20 * 0.25 +
                COALESCE(
                    COUNT(CASE 
                        WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                             AND c.date_livraison <= c.date_livraison_prevue THEN 1 
                    END) * 100.0 / 
                    NULLIF(COUNT(CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0),
                    50
                ) * 0.25 +
                (100 - COUNT(CASE WHEN c.statut = 'annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id), 1)) * 0.20
            ),
            1
        ) >= 80 THEN 'EXCELLENT'
        WHEN ROUND(
            (
                GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                    CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                        EXTRACT(days FROM (c.date_livraison - c.date_livraison_prevue))
                    END
                ), 0) * 5)) * 0.30 +
                COALESCE(AVG(c.note_qualite), 3) * 20 * 0.25 +
                COALESCE(
                    COUNT(CASE 
                        WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                             AND c.date_livraison <= c.date_livraison_prevue THEN 1 
                    END) * 100.0 / 
                    NULLIF(COUNT(CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0),
                    50
                ) * 0.25 +
                (100 - COUNT(CASE WHEN c.statut = 'annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id), 1)) * 0.20
            ),
            1
        ) >= 60 THEN 'GOOD'
        WHEN ROUND(
            (
                GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                    CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                        EXTRACT(days FROM (c.date_livraison - c.date_livraison_prevue))
                    END
                ), 0) * 5)) * 0.30 +
                COALESCE(AVG(c.note_qualite), 3) * 20 * 0.25 +
                COALESCE(
                    COUNT(CASE 
                        WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                             AND c.date_livraison <= c.date_livraison_prevue THEN 1 
                    END) * 100.0 / 
                    NULLIF(COUNT(CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0),
                    50
                ) * 0.25 +
                (100 - COUNT(CASE WHEN c.statut = 'annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id), 1)) * 0.20
            ),
            1
        ) >= 40 THEN 'AVERAGE'
        ELSE 'POOR'
    END AS performance_category
    
FROM commandes c
INNER JOIN fournisseurs f ON c.fournisseur_id = f.id
LEFT JOIN (
    -- Analyse comparative des prix
    SELECT 
        fournisseur_id,
        'COMPETITIVE' AS price_competitiveness,  -- Logique simplifiée
        'STABLE' AS price_trend                  -- À développer avec historique
    FROM commandes 
    GROUP BY fournisseur_id
) price_analysis ON f.id = price_analysis.fournisseur_id

WHERE c.date_commande >= CURRENT_DATE - INTERVAL '12 months'
  AND f.actif = true

GROUP BY 
    f.id, f.nom, f.pays, f.type_fournisseur, f.note_evaluation,
    TO_CHAR(c.date_commande, 'YYYY-MM'),
    EXTRACT(YEAR FROM c.date_commande),
    EXTRACT(MONTH FROM c.date_commande),
    price_analysis.price_competitiveness,
    price_analysis.price_trend

ORDER BY 
    period_month DESC,
    performance_score DESC,
    total_order_value_eur DESC;

-- Commentaires
COMMENT ON VIEW kpi_purchases_supplier_performance IS 'Évaluation complète de la performance des fournisseurs';
COMMENT ON COLUMN kpi_purchases_supplier_performance.performance_score IS 'Score global 0-100 basé sur délais, qualité, respect et fiabilité';
COMMENT ON COLUMN kpi_purchases_supplier_performance.performance_category IS 'Classification: EXCELLENT/GOOD/AVERAGE/POOR';

-- ====================
-- KPI 2: ANALYSE DES COÛTS D'ACHAT
-- ====================
-- Description: Suivi des coûts et optimisation des achats
-- Tables requises: commandes, lignes_commandes, articles
-- Métriques: évolution prix, volumes, économies

CREATE OR REPLACE VIEW kpi_purchases_cost_analysis AS
SELECT 
    a.categorie AS product_category,
    a.fournisseur_principal AS main_supplier,
    TO_CHAR(c.date_commande, 'YYYY-MM') AS period_month,
    
    -- Volumes d'achat
    COUNT(DISTINCT c.id) AS purchase_orders_count,
    COUNT(lc.id) AS line_items_count,
    SUM(lc.quantite) AS total_quantity_purchased,
    
    -- Valeurs d'achat
    SUM(lc.quantite * lc.prix_unitaire) AS total_purchase_value_eur,
    ROUND(AVG(lc.prix_unitaire), 2) AS avg_unit_price_eur,
    ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2) AS weighted_avg_price_eur,
    
    -- Comparaison avec période précédente
    LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
        OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM')) AS prev_month_avg_price,
    
    ROUND(
        (ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2) - 
         LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
            OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM'))) * 100.0 /
        NULLIF(LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
            OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM')), 0),
        2
    ) AS price_evolution_percent,
    
    -- Analyse des remises et conditions
    COUNT(CASE WHEN c.remise_percent > 0 THEN 1 END) AS orders_with_discount,
    ROUND(AVG(c.remise_percent), 2) AS avg_discount_percent,
    SUM(c.montant_total * c.remise_percent / 100) AS total_savings_eur,
    
    -- Concentration des achats
    COUNT(DISTINCT c.fournisseur_id) AS suppliers_count,
    
    -- Principaux fournisseurs pour cette catégorie
    STRING_AGG(
        DISTINCT f.nom, 
        ', ' 
        ORDER BY SUM(lc.quantite * lc.prix_unitaire) DESC
    ) AS top_suppliers,
    
    -- Analyse de la saisonnalité
    CASE 
        WHEN EXTRACT(MONTH FROM c.date_commande) IN (12, 1, 2) THEN 'WINTER'
        WHEN EXTRACT(MONTH FROM c.date_commande) IN (3, 4, 5) THEN 'SPRING'
        WHEN EXTRACT(MONTH FROM c.date_commande) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END AS season,
    
    -- Optimisation potentielle
    CASE 
        WHEN COUNT(DISTINCT c.fournisseur_id) = 1 THEN 'MONOPOLY_RISK'
        WHEN COUNT(DISTINCT c.fournisseur_id) >= 5 THEN 'FRAGMENTED'
        WHEN ROUND(AVG(c.remise_percent), 2) < 5 THEN 'LOW_NEGOTIATION'
        ELSE 'OPTIMIZED'
    END AS optimization_opportunity,
    
    -- Tendance des prix
    CASE 
        WHEN ROUND(
            (ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2) - 
             LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
                OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM'))) * 100.0 /
            NULLIF(LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
                OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM')), 0),
            2
        ) > 5 THEN 'INCREASING'
        WHEN ROUND(
            (ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2) - 
             LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
                OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM'))) * 100.0 /
            NULLIF(LAG(ROUND(SUM(lc.quantite * lc.prix_unitaire) / NULLIF(SUM(lc.quantite), 0), 2)) 
                OVER (PARTITION BY a.categorie ORDER BY TO_CHAR(c.date_commande, 'YYYY-MM')), 0),
            2
        ) < -5 THEN 'DECREASING'
        ELSE 'STABLE'
    END AS price_trend
    
FROM commandes c
INNER JOIN lignes_commandes lc ON c.id = lc.commande_id
INNER JOIN articles a ON lc.article_id = a.id
INNER JOIN fournisseurs f ON c.fournisseur_id = f.id

WHERE c.date_commande >= CURRENT_DATE - INTERVAL '24 months'
  AND c.statut IN ('livree', 'facturee')

GROUP BY 
    a.categorie, a.fournisseur_principal,
    TO_CHAR(c.date_commande, 'YYYY-MM'),
    CASE 
        WHEN EXTRACT(MONTH FROM c.date_commande) IN (12, 1, 2) THEN 'WINTER'
        WHEN EXTRACT(MONTH FROM c.date_commande) IN (3, 4, 5) THEN 'SPRING'
        WHEN EXTRACT(MONTH FROM c.date_commande) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END

ORDER BY 
    period_month DESC,
    total_purchase_value_eur DESC;

-- Commentaires
COMMENT ON VIEW kpi_purchases_cost_analysis IS 'Analyse des coûts d\'achat avec évolution des prix et opportunités d\'optimisation';
COMMENT ON COLUMN kpi_purchases_cost_analysis.price_evolution_percent IS 'Évolution du prix moyen par rapport au mois précédent';
COMMENT ON COLUMN kpi_purchases_cost_analysis.optimization_opportunity IS 'Opportunité: MONOPOLY_RISK/FRAGMENTED/LOW_NEGOTIATION/OPTIMIZED';

-- ====================
-- KPI 3: DÉLAIS ET CYCLES D'APPROVISIONNEMENT
-- ====================
-- Description: Analyse des cycles et délais d'approvisionnement
-- Tables requises: commandes, lignes_commandes, demandes_achat
-- Métriques: lead times, cycles, prévisions

CREATE OR REPLACE VIEW kpi_purchases_lead_times AS
SELECT 
    f.id AS supplier_id,
    f.nom AS supplier_name,
    a.categorie AS product_category,
    a.id AS article_id,
    a.nom AS article_name,
    
    -- Compteurs sur les 6 derniers mois
    COUNT(c.id) AS orders_count_6m,
    
    -- Délais moyens
    ROUND(AVG(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) AS avg_total_lead_time_days,
    ROUND(AVG(EXTRACT(days FROM (c.date_validation - c.date_demande))), 1) AS avg_approval_time_days,
    ROUND(AVG(EXTRACT(days FROM (c.date_commande - c.date_validation))), 1) AS avg_order_processing_days,
    ROUND(AVG(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) AS avg_supplier_delivery_days,
    
    -- Variabilité des délais
    ROUND(STDDEV(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) AS lead_time_std_deviation,
    MIN(EXTRACT(days FROM (c.date_livraison - c.date_commande))) AS min_lead_time_days,
    MAX(EXTRACT(days FROM (c.date_livraison - c.date_commande))) AS max_lead_time_days,
    
    -- Percentiles pour une meilleure analyse
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(days FROM (c.date_livraison - c.date_commande))) AS median_lead_time_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY EXTRACT(days FROM (c.date_livraison - c.date_commande))) AS p90_lead_time_days,
    
    -- Prédictibilité
    CASE 
        WHEN ROUND(STDDEV(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) <= 2 THEN 'VERY_PREDICTABLE'
        WHEN ROUND(STDDEV(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) <= 5 THEN 'PREDICTABLE'
        WHEN ROUND(STDDEV(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) <= 10 THEN 'MODERATELY_PREDICTABLE'
        ELSE 'UNPREDICTABLE'
    END AS lead_time_predictability,
    
    -- Performance par rapport aux délais annoncés
    COUNT(CASE WHEN c.date_livraison <= c.date_livraison_prevue THEN 1 END) AS on_time_count,
    ROUND(
        COUNT(CASE WHEN c.date_livraison <= c.date_livraison_prevue THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN c.date_livraison IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0),
        2
    ) AS on_time_rate_percent,
    
    -- Analyse des retards
    ROUND(AVG(
        CASE WHEN c.date_livraison > c.date_livraison_prevue THEN 
            EXTRACT(days FROM (c.date_livraison - c.date_livraison_prevue))
        END
    ), 1) AS avg_delay_when_late_days,
    
    -- Recommandations de stock de sécurité (basé sur P90)
    ROUND(
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY EXTRACT(days FROM (c.date_livraison - c.date_commande))) * 
        COALESCE(consumption.daily_avg, 1) * 1.2,  -- Facteur de sécurité 20%
        0
    ) AS recommended_safety_stock,
    
    -- Optimisation possible du cycle
    CASE 
        WHEN ROUND(AVG(EXTRACT(days FROM (c.date_validation - c.date_demande))), 1) > 3 THEN 'IMPROVE_APPROVAL'
        WHEN ROUND(AVG(EXTRACT(days FROM (c.date_commande - c.date_validation))), 1) > 2 THEN 'IMPROVE_PROCESSING'
        WHEN ROUND(AVG(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) > 
             f.delai_livraison_standard + 2 THEN 'NEGOTIATE_DELIVERY'
        ELSE 'OPTIMIZED'
    END AS optimization_focus,
    
    -- Classification globale du délai
    CASE 
        WHEN ROUND(AVG(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) <= 7 THEN 'FAST'
        WHEN ROUND(AVG(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) <= 14 THEN 'STANDARD'
        WHEN ROUND(AVG(EXTRACT(days FROM (c.date_livraison - c.date_commande))), 1) <= 30 THEN 'SLOW'
        ELSE 'VERY_SLOW'
    END AS lead_time_category,
    
    consumption.daily_avg AS avg_daily_consumption,
    MAX(c.date_livraison) AS last_delivery_date
    
FROM commandes c
INNER JOIN fournisseurs f ON c.fournisseur_id = f.id
INNER JOIN lignes_commandes lc ON c.id = lc.commande_id
INNER JOIN articles a ON lc.article_id = a.id
LEFT JOIN (
    -- Calcul de la consommation moyenne journalière
    SELECT 
        article_id,
        AVG(quantite) / 30.0 AS daily_avg
    FROM sorties_stock 
    WHERE date_sortie >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY article_id
) consumption ON a.id = consumption.article_id

WHERE c.date_commande >= CURRENT_DATE - INTERVAL '6 months'
  AND c.date_livraison IS NOT NULL
  AND c.date_commande IS NOT NULL
  AND c.statut IN ('livree', 'facturee')

GROUP BY 
    f.id, f.nom, f.delai_livraison_standard,
    a.categorie, a.id, a.nom,
    consumption.daily_avg

HAVING COUNT(c.id) >= 3  -- Au moins 3 commandes pour des statistiques fiables

ORDER BY 
    avg_total_lead_time_days DESC,
    lead_time_std_deviation DESC;

-- Commentaires
COMMENT ON VIEW kpi_purchases_lead_times IS 'Analyse détaillée des délais d\'approvisionnement avec recommandations';
COMMENT ON COLUMN kpi_purchases_lead_times.lead_time_predictability IS 'Prédictibilité: VERY_PREDICTABLE/PREDICTABLE/MODERATELY_PREDICTABLE/UNPREDICTABLE';
COMMENT ON COLUMN kpi_purchases_lead_times.recommended_safety_stock IS 'Stock de sécurité recommandé basé sur P90 et consommation';
COMMENT ON COLUMN kpi_purchases_lead_times.optimization_focus IS 'Focus d\'optimisation: IMPROVE_APPROVAL/IMPROVE_PROCESSING/NEGOTIATE_DELIVERY/OPTIMIZED';
