-- =====================================
-- TEMPLATES SQL - MODULE PURCHASES ADAPTÉ
-- Gestion des achats et fournisseurs
-- Version adaptée au schéma réel GMAO
-- =====================================

-- ====================
-- KPI 1: PERFORMANCE DES FOURNISSEURS
-- ====================
-- Description: Évaluation de la performance des fournisseurs
-- Tables requises: commande, fournisseur, ligne_commande
-- Métriques: délais, qualité, coûts, fiabilité

CREATE OR REPLACE VIEW kpi_purchases_supplier_performance AS
SELECT 
    f.id_fournisseur AS supplier_id,
    f.nom AS supplier_name,
    f.delai_livraison_moyen_j AS standard_delivery_days,
    f.note_qualite AS supplier_rating,
    TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM') AS period_month,
    EXTRACT(YEAR FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) AS year,
    EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) AS month,
    
    -- Compteurs de commandes
    COUNT(c.id_commande) AS total_orders,
    COUNT(CASE WHEN c.statut = 'Livree' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN c.statut = 'Annulee' THEN 1 END) AS cancelled_orders,
    COUNT(CASE WHEN c.statut IN ('Brouillon', 'Validee', 'Envoyee', 'Partielle') THEN 1 END) AS pending_orders,
    
    -- Valeurs financières
    ROUND(SUM(c.total_ht)::NUMERIC, 2) AS total_order_value_eur,
    ROUND(AVG(c.total_ht)::NUMERIC, 2) AS avg_order_value_eur,
    ROUND(SUM(CASE WHEN c.statut = 'Livree' THEN c.total_ht ELSE 0 END)::NUMERIC, 2) AS delivered_value_eur,
    
    -- Délais de livraison (quand les dates sont renseignées)
    ROUND(AVG(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD'))
        END
    )::NUMERIC, 1) AS avg_delivery_days,
    
    ROUND(AVG(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
            (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD'))
        END
    )::NUMERIC, 1) AS avg_delay_days,
    
    -- Respect des délais
    COUNT(CASE 
        WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
             AND TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') <= TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD') THEN 1 
    END) AS on_time_deliveries,
    
    ROUND(
        COUNT(CASE 
            WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                 AND TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') <= TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD') THEN 1 
        END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0)::NUMERIC,
        2
    ) AS on_time_delivery_rate_percent,
    
    -- Analyse des lignes de commande
    COUNT(lc.id_ligne) AS total_line_items,
    COUNT(CASE WHEN lc.statut_ligne = 'Complete' THEN 1 END) AS completed_line_items,
    COUNT(CASE WHEN lc.quantite_recue < lc.quantite_commandee THEN 1 END) AS partial_deliveries,
    ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht)::NUMERIC, 2) AS total_line_value_eur,
    
    -- Flexibilité (livraisons rapides <= 7 jours)
    COUNT(CASE 
        WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL AND
             EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD'))) <= 7 THEN 1 
    END) AS fast_deliveries_7d,
    
    -- Score de performance global (0-100)
    ROUND(
        (
            -- Respect délais (40%) - Pas de retard = 100, chaque jour de retard = -10
            GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                    GREATEST(0, EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD'))))
                END
            ), 0) * 10))::NUMERIC * 0.40 +
            
            -- Qualité fournisseur (30%)
            COALESCE(f.note_qualite, 3) * 20 * 0.30 +
            
            -- Fiabilité (20%) - Taux de commandes non annulées
            (100 - COUNT(CASE WHEN c.statut = 'Annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id_commande), 1))::NUMERIC * 0.20 +
            
            -- Réactivité (10%) - Bonus pour livraisons rapides
            LEAST(100, COUNT(CASE 
                WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL AND
                     EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD'))) <= 7 THEN 1 
            END) * 100.0 / NULLIF(COUNT(CASE WHEN c.date_livraison_reelle IS NOT NULL THEN 1 END), 1))::NUMERIC * 0.10
        ),
        1
    ) AS performance_score,
    
    -- Classification de performance
    CASE 
        WHEN ROUND(
            (
                GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                    CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                        GREATEST(0, EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD'))))
                    END
                ), 0) * 10))::NUMERIC * 0.40 +
                COALESCE(f.note_qualite, 3) * 20 * 0.30 +
                (100 - COUNT(CASE WHEN c.statut = 'Annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id_commande), 1))::NUMERIC * 0.20 +
                LEAST(100, COUNT(CASE 
                    WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL AND
                         EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD'))) <= 7 THEN 1 
                END) * 100.0 / NULLIF(COUNT(CASE WHEN c.date_livraison_reelle IS NOT NULL THEN 1 END), 1))::NUMERIC * 0.10
            ),
            1
        ) >= 80 THEN 'EXCELLENT'
        WHEN ROUND(
            (
                GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                    CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                        GREATEST(0, EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD'))))
                    END
                ), 0) * 10))::NUMERIC * 0.40 +
                COALESCE(f.note_qualite, 3) * 20 * 0.30 +
                (100 - COUNT(CASE WHEN c.statut = 'Annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id_commande), 1))::NUMERIC * 0.20 +
                LEAST(100, COUNT(CASE 
                    WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL AND
                         EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD'))) <= 7 THEN 1 
                END) * 100.0 / NULLIF(COUNT(CASE WHEN c.date_livraison_reelle IS NOT NULL THEN 1 END), 1))::NUMERIC * 0.10
            ),
            1
        ) >= 60 THEN 'GOOD'
        WHEN ROUND(
            (
                GREATEST(0, LEAST(100, 100 - COALESCE(AVG(
                    CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 
                        GREATEST(0, EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD'))))
                    END
                ), 0) * 10))::NUMERIC * 0.40 +
                COALESCE(f.note_qualite, 3) * 20 * 0.30 +
                (100 - COUNT(CASE WHEN c.statut = 'Annulee' THEN 1 END) * 100.0 / NULLIF(COUNT(c.id_commande), 1))::NUMERIC * 0.20 +
                LEAST(100, COUNT(CASE 
                    WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL AND
                         EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD'))) <= 7 THEN 1 
                END) * 100.0 / NULLIF(COUNT(CASE WHEN c.date_livraison_reelle IS NOT NULL THEN 1 END), 1))::NUMERIC * 0.10
            ),
            1
        ) >= 40 THEN 'AVERAGE'
        ELSE 'POOR'
    END AS performance_category,
    
    -- Métadonnées
    MAX(CASE WHEN c.date_livraison_reelle IS NOT NULL THEN TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') END) AS last_delivery_date,
    CURRENT_DATE AS analysis_date
    
FROM commande c
INNER JOIN fournisseur f ON c.fournisseur_id = f.id_fournisseur
LEFT JOIN ligne_commande lc ON c.id_commande = lc.commande_id

WHERE TO_DATE(c.date_commande, 'YYYY-MM-DD') >= CURRENT_DATE - INTERVAL '12 months'

GROUP BY 
    f.id_fournisseur, f.nom, f.delai_livraison_moyen_j, f.note_qualite,
    TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM'),
    EXTRACT(YEAR FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')),
    EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD'))

ORDER BY 
    period_month DESC,
    performance_score DESC,
    total_order_value_eur DESC;

-- Commentaires
COMMENT ON VIEW kpi_purchases_supplier_performance IS 'Évaluation complète de la performance des fournisseurs - Version GMAO';
COMMENT ON COLUMN kpi_purchases_supplier_performance.performance_score IS 'Score global 0-100 basé sur délais, qualité, respect et fiabilité';
COMMENT ON COLUMN kpi_purchases_supplier_performance.performance_category IS 'Classification: EXCELLENT/GOOD/AVERAGE/POOR';

-- ====================
-- KPI 2: ANALYSE DES COÛTS D'ACHAT
-- ====================
-- Description: Suivi des coûts et optimisation des achats
-- Tables requises: commande, ligne_commande, piece
-- Métriques: évolution prix, volumes, économies

CREATE OR REPLACE VIEW kpi_purchases_cost_analysis AS
SELECT 
    p.categorie AS product_category,
    f.nom AS main_supplier,
    TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM') AS period_month,
    
    -- Volumes d'achat
    COUNT(DISTINCT c.id_commande) AS purchase_orders_count,
    COUNT(lc.id_ligne) AS line_items_count,
    SUM(lc.quantite_commandee) AS total_quantity_purchased,
    
    -- Valeurs d'achat
    ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht)::NUMERIC, 2) AS total_purchase_value_eur,
    ROUND(AVG(lc.prix_unitaire_ht)::NUMERIC, 2) AS avg_unit_price_eur,
    ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2) AS weighted_avg_price_eur,
    
    -- Comparaison avec période précédente
    LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
        OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM')) AS prev_month_avg_price,
    
    ROUND(
        (ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2) - 
         LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
            OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM'))) * 100.0 /
        NULLIF(LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
            OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM')), 0)::NUMERIC,
        2
    ) AS price_evolution_percent,
    
    -- Analyse des frais de port
    COUNT(CASE WHEN c.frais_port > 0 THEN 1 END) AS orders_with_shipping,
    ROUND(AVG(c.frais_port)::NUMERIC, 2) AS avg_shipping_cost,
    ROUND(SUM(c.frais_port)::NUMERIC, 2) AS total_shipping_cost,
    
    -- Concentration des achats
    COUNT(DISTINCT c.fournisseur_id) AS suppliers_count,
    
    -- Analyse de la saisonnalité
    CASE 
        WHEN EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) IN (12, 1, 2) THEN 'WINTER'
        WHEN EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) IN (3, 4, 5) THEN 'SPRING'
        WHEN EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END AS season,
    
    -- Optimisation potentielle
    CASE 
        WHEN COUNT(DISTINCT c.fournisseur_id) = 1 THEN 'MONOPOLY_RISK'
        WHEN COUNT(DISTINCT c.fournisseur_id) >= 3 THEN 'COMPETITIVE'
        WHEN ROUND(AVG(c.frais_port)::NUMERIC, 2) > 50 THEN 'HIGH_SHIPPING_COSTS'
        ELSE 'OPTIMIZED'
    END AS optimization_opportunity,
    
    -- Tendance des prix
    CASE 
        WHEN ROUND(
            (ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2) - 
             LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
                OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM'))) * 100.0 /
            NULLIF(LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
                OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM')), 0)::NUMERIC,
            2
        ) > 5 THEN 'INCREASING'
        WHEN ROUND(
            (ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2) - 
             LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
                OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM'))) * 100.0 /
            NULLIF(LAG(ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht) / NULLIF(SUM(lc.quantite_commandee), 0)::NUMERIC, 2)) 
                OVER (PARTITION BY p.categorie ORDER BY TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM')), 0)::NUMERIC,
            2
        ) < -5 THEN 'DECREASING'
        ELSE 'STABLE'
    END AS price_trend,
    
    -- Métadonnées
    COUNT(CASE WHEN c.statut IN ('Livree') THEN 1 END) AS delivered_orders,
    ROUND(AVG(c.total_ht)::NUMERIC, 2) AS avg_order_total_eur
    
FROM commande c
INNER JOIN ligne_commande lc ON c.id_commande = lc.commande_id
INNER JOIN piece p ON lc.piece_id = p.id_piece
INNER JOIN fournisseur f ON c.fournisseur_id = f.id_fournisseur

WHERE TO_DATE(c.date_commande, 'YYYY-MM-DD') >= CURRENT_DATE - INTERVAL '24 months'
  AND c.statut IN ('Validee', 'Envoyee', 'Partielle', 'Livree')

GROUP BY 
    p.categorie, f.nom,
    TO_CHAR(TO_DATE(c.date_commande, 'YYYY-MM-DD'), 'YYYY-MM'),
    CASE 
        WHEN EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) IN (12, 1, 2) THEN 'WINTER'
        WHEN EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) IN (3, 4, 5) THEN 'SPRING'
        WHEN EXTRACT(MONTH FROM TO_DATE(c.date_commande, 'YYYY-MM-DD')) IN (6, 7, 8) THEN 'SUMMER'
        ELSE 'AUTUMN'
    END

ORDER BY 
    period_month DESC,
    total_purchase_value_eur DESC;

-- Commentaires
COMMENT ON VIEW kpi_purchases_cost_analysis IS 'Analyse des coûts d\'achat avec évolution des prix - Version GMAO';
COMMENT ON COLUMN kpi_purchases_cost_analysis.price_evolution_percent IS 'Évolution du prix moyen par rapport au mois précédent';
COMMENT ON COLUMN kpi_purchases_cost_analysis.optimization_opportunity IS 'Opportunité: MONOPOLY_RISK/COMPETITIVE/HIGH_SHIPPING_COSTS/OPTIMIZED';

-- ====================
-- KPI 3: DÉLAIS ET CYCLES D'APPROVISIONNEMENT
-- ====================
-- Description: Analyse des cycles et délais d'approvisionnement
-- Tables requises: commande, ligne_commande, fournisseur, piece
-- Métriques: lead times, cycles, prévisions

CREATE OR REPLACE VIEW kpi_purchases_lead_times AS
SELECT 
    f.id_fournisseur AS supplier_id,
    f.nom AS supplier_name,
    p.categorie AS product_category,
    p.id_piece AS article_id,
    p.nom AS article_name,
    
    -- Compteurs sur les 6 derniers mois
    COUNT(c.id_commande) AS orders_count_6m,
    
    -- Délais moyens (quand les dates sont disponibles)
    ROUND(AVG(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
        END
    )::NUMERIC, 1) AS avg_total_lead_time_days,
    
    -- Délai standard du fournisseur pour comparaison
    f.delai_livraison_moyen_j AS supplier_standard_days,
    
    -- Variabilité des délais
    ROUND(STDDEV(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
        END
    )::NUMERIC, 1) AS lead_time_std_deviation,
    
    MIN(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
        END
    ) AS min_lead_time_days,
    
    MAX(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
        END
    ) AS max_lead_time_days,
    
    -- Percentiles pour une meilleure analyse
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
        END
    ) AS median_lead_time_days,
    
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY 
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
        END
    ) AS p90_lead_time_days,
    
    -- Prédictibilité
    CASE 
        WHEN ROUND(STDDEV(
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        )::NUMERIC, 1) <= 2 THEN 'VERY_PREDICTABLE'
        WHEN ROUND(STDDEV(
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        )::NUMERIC, 1) <= 5 THEN 'PREDICTABLE'
        WHEN ROUND(STDDEV(
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        )::NUMERIC, 1) <= 10 THEN 'MODERATELY_PREDICTABLE'
        ELSE 'UNPREDICTABLE'
    END AS lead_time_predictability,
    
    -- Performance par rapport aux délais annoncés
    COUNT(CASE 
        WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
             AND TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') <= TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD') THEN 1 
    END) AS on_time_count,
    
    ROUND(
        COUNT(CASE 
            WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                 AND TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') <= TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD') THEN 1 
        END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL THEN 1 END), 0)::NUMERIC,
        2
    ) AS on_time_rate_percent,
    
    -- Analyse des retards
    ROUND(AVG(
        CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_livraison_prevue IS NOT NULL 
                  AND TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') > TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD') THEN 
            EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_livraison_prevue, 'YYYY-MM-DD')))
        END
    )::NUMERIC, 1) AS avg_delay_when_late_days,
    
    -- Recommandations de stock de sécurité (basé sur P90)
    ROUND(
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY 
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        ) * COALESCE(p.stock_alerte::NUMERIC / 30.0, 1) * 1.2,  -- Facteur de sécurité 20%
        0
    ) AS recommended_safety_stock,
    
    -- Classification globale du délai
    CASE 
        WHEN ROUND(AVG(
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        )::NUMERIC, 1) <= 7 THEN 'FAST'
        WHEN ROUND(AVG(
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        )::NUMERIC, 1) <= 14 THEN 'STANDARD'
        WHEN ROUND(AVG(
            CASE WHEN c.date_livraison_reelle IS NOT NULL AND c.date_commande IS NOT NULL THEN 
                EXTRACT(days FROM (TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') - TO_DATE(c.date_commande, 'YYYY-MM-DD')))
            END
        )::NUMERIC, 1) <= 30 THEN 'SLOW'
        ELSE 'VERY_SLOW'
    END AS lead_time_category,
    
    -- Métadonnées
    MAX(CASE WHEN c.date_livraison_reelle IS NOT NULL THEN TO_DATE(c.date_livraison_reelle, 'YYYY-MM-DD') END) AS last_delivery_date,
    ROUND(AVG(lc.quantite_commandee)::NUMERIC, 1) AS avg_order_quantity,
    ROUND(SUM(lc.quantite_commandee * lc.prix_unitaire_ht)::NUMERIC, 2) AS total_value_eur
    
FROM commande c
INNER JOIN fournisseur f ON c.fournisseur_id = f.id_fournisseur
INNER JOIN ligne_commande lc ON c.id_commande = lc.commande_id
INNER JOIN piece p ON lc.piece_id = p.id_piece

WHERE TO_DATE(c.date_commande, 'YYYY-MM-DD') >= CURRENT_DATE - INTERVAL '6 months'
  AND c.statut IN ('Validee', 'Envoyee', 'Partielle', 'Livree')

GROUP BY 
    f.id_fournisseur, f.nom, f.delai_livraison_moyen_j,
    p.categorie, p.id_piece, p.nom, p.stock_alerte

HAVING COUNT(c.id_commande) >= 1  -- Au moins 1 commande pour des statistiques

ORDER BY 
    avg_total_lead_time_days DESC,
    lead_time_std_deviation DESC;

-- Commentaires
COMMENT ON VIEW kpi_purchases_lead_times IS 'Analyse détaillée des délais d\'approvisionnement - Version GMAO';
COMMENT ON COLUMN kpi_purchases_lead_times.lead_time_predictability IS 'Prédictibilité: VERY_PREDICTABLE/PREDICTABLE/MODERATELY_PREDICTABLE/UNPREDICTABLE';
COMMENT ON COLUMN kpi_purchases_lead_times.recommended_safety_stock IS 'Stock de sécurité recommandé basé sur P90 et stock d\'alerte';
COMMENT ON COLUMN kpi_purchases_lead_times.lead_time_category IS 'Classification: FAST/STANDARD/SLOW/VERY_SLOW';
