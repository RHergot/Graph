-- =====================================
-- VALIDATION SCHÉMA - MODULE STOCKS
-- Script de vérification avant création des VIEWs
-- Tables: piece, entrees_stock, sorties_stock
-- =====================================

-- Vérification existence des tables requises
SELECT 'TABLES_CHECK' as verification_type;

SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('piece', 'entrees_stock', 'sorties_stock', 'mouvement_stock')
ORDER BY table_name;

-- Vérification structure table piece
SELECT 'PIECE_STRUCTURE' as verification_type;

SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'piece'
ORDER BY ordinal_position;

-- Vérification structure table entrees_stock ou mouvement_stock
SELECT 'MOUVEMENT_STOCK_STRUCTURE' as verification_type;

SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('entrees_stock', 'sorties_stock', 'mouvement_stock')
ORDER BY table_name, ordinal_position;

-- Vérification données échantillon
SELECT 'SAMPLE_DATA_CHECK' as verification_type;

SELECT 
    'piece' as table_name,
    COUNT(*) as row_count,
    MIN(prix_unitaire) as min_price,
    MAX(prix_unitaire) as max_price
FROM piece
WHERE EXISTS (SELECT 1 FROM piece LIMIT 1);

-- Échantillon de données piece
SELECT 'PIECE_SAMPLE' as verification_type;

SELECT *
FROM piece
LIMIT 5;

-- Échantillon mouvement_stock
SELECT 'MOUVEMENT_STOCK_SAMPLE' as verification_type;

SELECT *
FROM mouvement_stock
LIMIT 5;

-- Types de mouvements disponibles
SELECT 'TYPE_MOUVEMENT_VALUES' as verification_type;

SELECT DISTINCT type_mouvement_id, COUNT(*) as nb_mouvements
FROM mouvement_stock 
GROUP BY type_mouvement_id
ORDER BY type_mouvement_id;

-- Vérification tables de mouvements disponibles
SELECT 'MOVEMENT_TABLES_CHECK' as verification_type;

SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mouvement_stock') 
        THEN 'mouvement_stock table exists'
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'entrees_stock') 
        THEN 'entrees_stock table exists'
        ELSE 'no movement tables found'
    END as movement_table_status;
