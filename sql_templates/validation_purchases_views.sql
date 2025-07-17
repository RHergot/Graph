-- =====================================
-- VALIDATION SCHEMA PURCHASES - MODULE ACHATS
-- Adaptation au schéma réel GMAO
-- =====================================

-- Vérification des tables principales
SELECT 'commande' as table_name, COUNT(*) as row_count FROM commande
UNION ALL
SELECT 'fournisseur' as table_name, COUNT(*) as row_count FROM fournisseur
UNION ALL  
SELECT 'ligne_commande' as table_name, COUNT(*) as row_count FROM ligne_commande
UNION ALL
SELECT 'demandes_achat' as table_name, COUNT(*) as row_count FROM demandes_achat;

-- Test de structure des colonnes critiques
SELECT 
    'VALIDATION_COLONNES' as check_type,
    'commande' as table_name,
    id_commande,
    fournisseur_id,
    date_commande,
    date_livraison_prevue,
    date_livraison_reelle,
    statut,
    total_ht
FROM commande 
LIMIT 3;

-- Test fournisseurs  
SELECT 
    'VALIDATION_FOURNISSEURS' as check_type,
    id_fournisseur,
    nom,
    delai_livraison_moyen_j,
    note_qualite
FROM fournisseur
LIMIT 3;

-- Test lignes commandes
SELECT 
    'VALIDATION_LIGNES' as check_type,
    commande_id,
    piece_id,
    quantite_commandee,
    prix_unitaire_ht,
    quantite_recue,
    statut_ligne
FROM ligne_commande
LIMIT 3;

-- Vérification des statuts possibles
SELECT DISTINCT 
    'STATUTS_COMMANDE' as info_type,
    statut,
    COUNT(*) as occurrences
FROM commande 
GROUP BY statut
ORDER BY occurrences DESC;

SELECT DISTINCT 
    'STATUTS_LIGNE' as info_type,
    statut_ligne,
    COUNT(*) as occurrences
FROM ligne_commande 
GROUP BY statut_ligne
ORDER BY occurrences DESC;

-- Test de jointures critiques
SELECT 
    'TEST_JOINTURES' as validation_type,
    c.id_commande,
    f.nom as fournisseur_nom,
    COUNT(lc.id_ligne) as nb_lignes
FROM commande c
INNER JOIN fournisseur f ON c.fournisseur_id = f.id_fournisseur
LEFT JOIN ligne_commande lc ON c.id_commande = lc.commande_id
GROUP BY c.id_commande, f.nom
LIMIT 5;
