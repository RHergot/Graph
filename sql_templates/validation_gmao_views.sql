-- =========================================
-- VALIDATION DES VUES GMAO
-- Script de vérification avant exécution
-- =========================================

-- 1. Vérification des tables et colonnes utilisées
SELECT 'Vérification table machine' as check_type;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'machine' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Vérification table ordre_travail' as check_type;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'ordre_travail' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Vérification table maintenance' as check_type;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'maintenance' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Test des jointures principales
SELECT 'Test jointure machine-ordre_travail' as test_type, COUNT(*) as nb_lignes
FROM machine m
LEFT JOIN ordre_travail ot ON m.id_machine = ot.machine_id;

SELECT 'Test jointure ordre_travail-maintenance' as test_type, COUNT(*) as nb_lignes
FROM ordre_travail ot
LEFT JOIN maintenance mt ON ot.id_ot = mt.ot_id;

-- 3. Vérification des valeurs de statut existantes
SELECT 'Statuts ordre_travail utilisés' as info_type, statut, COUNT(*) as nb_occurrences
FROM ordre_travail 
GROUP BY statut
ORDER BY nb_occurrences DESC;

-- 4. Vérification des états machines
SELECT 'États machines utilisés' as info_type, etat, COUNT(*) as nb_occurrences
FROM machine 
GROUP BY etat
ORDER BY nb_occurrences DESC;

-- 5. Test de cohérence des dates
SELECT 'Vérification dates maintenance' as test_type,
       COUNT(*) as total_maintenances,
       COUNT(CASE WHEN date_debut_reelle IS NOT NULL THEN 1 END) as avec_date_debut,
       COUNT(CASE WHEN date_fin_reelle IS NOT NULL THEN 1 END) as avec_date_fin
FROM maintenance;

-- 6. Test des coûts
SELECT 'Vérification coûts maintenance' as test_type,
       COUNT(*) as total_maintenances,
       COUNT(CASE WHEN cout_total > 0 THEN 1 END) as avec_cout_total,
       AVG(cout_total) as cout_moyen,
       MAX(cout_total) as cout_max
FROM maintenance;
