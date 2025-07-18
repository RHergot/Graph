--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (Ubuntu 17.5-1.pgdg24.04+1)
-- Dumped by pg_dump version 17.5

-- Started on 2025-07-15 20:31:09

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 4419 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 1225 (class 1247 OID 19012)
-- Name: source_type; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.source_type AS ENUM (
    'GMAO',
    'STOCKS'
);


ALTER TYPE public.source_type OWNER TO gmao_app_user;

--
-- TOC entry 1234 (class 1247 OID 19051)
-- Name: statut_ao; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.statut_ao AS ENUM (
    'Ouvert',
    'Clos',
    'Annulé',
    'Archivé'
);


ALTER TYPE public.statut_ao OWNER TO gmao_app_user;

--
-- TOC entry 1084 (class 1247 OID 19667)
-- Name: statut_commande; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.statut_commande AS ENUM (
    'Brouillon',
    'Validee',
    'Envoyee',
    'Partielle',
    'Livree',
    'Annulee'
);


ALTER TYPE public.statut_commande OWNER TO gmao_app_user;

--
-- TOC entry 1174 (class 1247 OID 19811)
-- Name: statut_contrat_enum; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.statut_contrat_enum AS ENUM (
    'Brouillon',
    'Actif',
    'Expiré',
    'Renouvelé',
    'Annulé',
    'Archivé'
);


ALTER TYPE public.statut_contrat_enum OWNER TO gmao_app_user;

--
-- TOC entry 1222 (class 1247 OID 19003)
-- Name: statut_da; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.statut_da AS ENUM (
    'En attente',
    'En AO',
    'Commandé',
    'Annulé'
);


ALTER TYPE public.statut_da OWNER TO gmao_app_user;

--
-- TOC entry 1090 (class 1247 OID 19680)
-- Name: statut_ligne_commande; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.statut_ligne_commande AS ENUM (
    'Attente',
    'Partielle',
    'Complete',
    'Annulee'
);


ALTER TYPE public.statut_ligne_commande OWNER TO gmao_app_user;

--
-- TOC entry 1168 (class 1247 OID 19732)
-- Name: statut_prestation_enum; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.statut_prestation_enum AS ENUM (
    'DEMANDE_INITIALE',
    'EN_DEVIS',
    'OFFRE_ANALYSE',
    'COMMANDE_A_EMETTRE',
    'COMMANDE_EMISE',
    'PRESTATION_EN_COURS',
    'PRESTATION_TERMINEE',
    'FACTURE_RECUE',
    'ATTENTE_REGULARISATION',
    'REGULARISATION_EMISE',
    'CLOS',
    'ANNULEE'
);


ALTER TYPE public.statut_prestation_enum OWNER TO gmao_app_user;

--
-- TOC entry 1165 (class 1247 OID 19717)
-- Name: type_prestation_enum; Type: TYPE; Schema: public; Owner: gmao_app_user
--

CREATE TYPE public.type_prestation_enum AS ENUM (
    'SERVICE_MAINTENANCE',
    'PIECE_HORS_CATALOGUE',
    'CONSULTATION_EXTERNE',
    'FORMATION',
    'SOUS_TRAITANCE_FORFAIT',
    'FRAIS_DEPLACEMENT',
    'AUTRE_SERVICE'
);


ALTER TYPE public.type_prestation_enum OWNER TO gmao_app_user;

--
-- TOC entry 382 (class 1255 OID 17524)
-- Name: annuler_mouvement_en_attente(integer, integer, text); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.annuler_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer DEFAULT NULL::integer, p_raison_annulation text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_mouvement RECORD;
    v_nouveau_commentaire TEXT;
BEGIN
    -- Récupérer le mouvement
    SELECT * INTO v_mouvement 
    FROM mouvement_stock 
    WHERE id = p_mouvement_id AND statut_mouvement = 'EN_ATTENTE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mouvement % non trouvé ou déjà traité', p_mouvement_id;
    END IF;
    
    -- Préparer le nouveau commentaire
    v_nouveau_commentaire := v_mouvement.commentaire;
    IF p_raison_annulation IS NOT NULL THEN
        v_nouveau_commentaire := COALESCE(v_nouveau_commentaire, '') || 
                                ' [ANNULÉ: ' || p_raison_annulation || ']';
    END IF;
    
    -- Annuler le mouvement
    UPDATE mouvement_stock 
    SET statut_mouvement = 'ANNULE',
        commentaire = v_nouveau_commentaire,
        valide = FALSE,
        updated_at = NOW()
    WHERE id = p_mouvement_id;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de l''annulation du mouvement: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.annuler_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer, p_raison_annulation text) OWNER TO gmao_app_user;

--
-- TOC entry 4420 (class 0 OID 0)
-- Dependencies: 382
-- Name: FUNCTION annuler_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer, p_raison_annulation text); Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON FUNCTION public.annuler_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer, p_raison_annulation text) IS 'Annule un mouvement en attente sans impact sur le stock';


--
-- TOC entry 384 (class 1255 OID 20141)
-- Name: archive_ot(integer, integer); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.archive_ot(ot_id_param integer, user_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_status TEXT;
BEGIN
    SELECT statut INTO current_status
    FROM ordre_travail
    WHERE id_ot = ot_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'OT ID % non trouvé', ot_id_param;
    END IF;
    
    IF current_status != 'Terminé' THEN
        RAISE EXCEPTION 'Impossible d''archiver un OT avec le statut "%". Seuls les OT "Terminé" peuvent être archivés.', current_status;
    END IF;
    
    UPDATE ordre_travail 
    SET 
        statut = 'Archivé',
        updated_at = CURRENT_TIMESTAMP
    WHERE id_ot = ot_id_param;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.archive_ot(ot_id_param integer, user_id integer) OWNER TO gmao_app_user;

--
-- TOC entry 383 (class 1255 OID 20129)
-- Name: auto_archive_completed_ots(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.auto_archive_completed_ots() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    archive_count INTEGER := 0;
    cutoff_date DATE;
BEGIN
    cutoff_date := CURRENT_DATE - INTERVAL '6 months';
    
    UPDATE ordre_travail 
    SET 
        statut = 'Archivé',
        updated_at = CURRENT_TIMESTAMP
    WHERE 
        statut = 'Terminé' 
        AND date_creation::timestamp < cutoff_date
        AND updated_at::timestamp < cutoff_date;
    
    GET DIAGNOSTICS archive_count = ROW_COUNT;
    
    RETURN archive_count;
EXCEPTION
    WHEN OTHERS THEN
        RETURN archive_count;
END;
$$;


ALTER FUNCTION public.auto_archive_completed_ots() OWNER TO gmao_app_user;

--
-- TOC entry 359 (class 1255 OID 17062)
-- Name: calculate_cout_total(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.calculate_cout_total() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.cout_unitaire IS NOT NULL AND NEW.quantite IS NOT NULL THEN
        NEW.cout_total = NEW.cout_unitaire * NEW.quantite;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.calculate_cout_total() OWNER TO gmao_app_user;

--
-- TOC entry 364 (class 1255 OID 17232)
-- Name: check_stock_coherence(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.check_stock_coherence() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_emplacement INTEGER;
    stock_piece INTEGER;
    piece_id_check INTEGER;
BEGIN
    -- Déterminer l'ID de la pièce à vérifier
    piece_id_check := COALESCE(NEW.piece_id, OLD.piece_id);
    
    -- Calculer le total dans les emplacements pour cette pièce
    SELECT COALESCE(SUM(quantite), 0) INTO total_emplacement
    FROM emplacement_stock 
    WHERE piece_id = piece_id_check;
    
    -- Récupérer le stock actuel de la pièce
    SELECT stock_actuel INTO stock_piece
    FROM piece 
    WHERE id_piece = piece_id_check;
    
    -- Vérifier la cohérence (avec tolérance pour les opérations en cours)
    IF total_emplacement != COALESCE(stock_piece, 0) THEN
        RAISE WARNING 'Incohérence stock détectée pour pièce %: Total emplacements (%) != Stock pièce (%)', 
                     piece_id_check, total_emplacement, COALESCE(stock_piece, 0);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION public.check_stock_coherence() OWNER TO gmao_app_user;

--
-- TOC entry 355 (class 1255 OID 16880)
-- Name: commande_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.commande_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $$;


ALTER FUNCTION public.commande_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 356 (class 1255 OID 16882)
-- Name: compteur_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.compteur_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $$;


ALTER FUNCTION public.compteur_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 381 (class 1255 OID 17523)
-- Name: confirmer_mouvement_en_attente(integer, integer, text); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.confirmer_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer DEFAULT NULL::integer, p_commentaire_confirmation text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_mouvement RECORD;
    v_nouveau_commentaire TEXT;
BEGIN
    -- Récupérer le mouvement
    SELECT * INTO v_mouvement 
    FROM mouvement_stock 
    WHERE id = p_mouvement_id AND statut_mouvement = 'EN_ATTENTE';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mouvement % non trouvé ou déjà confirmé', p_mouvement_id;
    END IF;
    
    -- Préparer le nouveau commentaire
    v_nouveau_commentaire := v_mouvement.commentaire;
    IF p_commentaire_confirmation IS NOT NULL THEN
        v_nouveau_commentaire := COALESCE(v_nouveau_commentaire, '') || 
                                ' [CONFIRMÉ: ' || p_commentaire_confirmation || ']';
    END IF;
    
    -- Confirmer le mouvement
    UPDATE mouvement_stock 
    SET statut_mouvement = 'CONFIRME',
        commentaire = v_nouveau_commentaire,
        updated_at = NOW()
    WHERE id = p_mouvement_id;
    
    -- Pour les mouvements de réception (impact_stock = 0), on doit quand même mettre à jour le stock
    -- car la confirmation transforme la réception en entrée effective
    IF v_mouvement.type_mouvement_id IN (
        SELECT id FROM type_mouvement WHERE nom = 'RECEPTION_ACHAT'
    ) THEN
        -- Pour une réception, on ajoute la quantité au stock actuel
        UPDATE piece 
        SET stock_actuel = stock_actuel + v_mouvement.quantite,
            updated_at = NOW()
        WHERE id_piece = v_mouvement.piece_id;
        
        -- Mettre à jour le stock_apres du mouvement pour refléter le nouveau stock
        UPDATE mouvement_stock
        SET stock_apres = (SELECT stock_actuel FROM piece WHERE id_piece = v_mouvement.piece_id)
        WHERE id = p_mouvement_id;
        
    ELSIF v_mouvement.type_mouvement_id IN (
        SELECT id FROM type_mouvement WHERE impact_stock != 0
    ) THEN
        -- Pour les autres mouvements, utiliser le stock_apres calculé
        UPDATE piece 
        SET stock_actuel = v_mouvement.stock_apres,
            updated_at = NOW()
        WHERE id_piece = v_mouvement.piece_id;
    END IF;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erreur lors de la confirmation du mouvement: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.confirmer_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer, p_commentaire_confirmation text) OWNER TO gmao_app_user;

--
-- TOC entry 4421 (class 0 OID 0)
-- Dependencies: 381
-- Name: FUNCTION confirmer_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer, p_commentaire_confirmation text); Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON FUNCTION public.confirmer_mouvement_en_attente(p_mouvement_id integer, p_utilisateur_id integer, p_commentaire_confirmation text) IS 'Confirme un mouvement en attente et applique l''impact sur le stock';


--
-- TOC entry 380 (class 1255 OID 17250)
-- Name: deplacer_stock(integer, integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.deplacer_stock(p_piece_id integer, p_emplacement_source_id integer, p_emplacement_destination_id integer, p_quantite integer, p_commentaire text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    stock_source INTEGER;
BEGIN
    -- Vérifier le stock source
    SELECT quantite INTO stock_source
    FROM emplacement_stock
    WHERE emplacement_id = p_emplacement_source_id AND piece_id = p_piece_id;
    
    IF stock_source IS NULL OR stock_source < p_quantite THEN
        RAISE EXCEPTION 'Stock insuffisant dans l''emplacement source (disponible: %, demandé: %)', 
                       COALESCE(stock_source, 0), p_quantite;
    END IF;
    
    -- Décrémenter le stock source
    UPDATE emplacement_stock 
    SET quantite = quantite - p_quantite,
        commentaire = COALESCE(p_commentaire, commentaire)
    WHERE emplacement_id = p_emplacement_source_id AND piece_id = p_piece_id;
    
    -- Incrémenter le stock destination (ou créer l'enregistrement)
    INSERT INTO emplacement_stock (emplacement_id, piece_id, quantite, commentaire)
    VALUES (p_emplacement_destination_id, p_piece_id, p_quantite, p_commentaire)
    ON CONFLICT (emplacement_id, piece_id)
    DO UPDATE SET 
        quantite = emplacement_stock.quantite + p_quantite,
        commentaire = COALESCE(p_commentaire, emplacement_stock.commentaire);
    
    -- Nettoyer les stocks à zéro
    DELETE FROM emplacement_stock 
    WHERE emplacement_id = p_emplacement_source_id 
      AND piece_id = p_piece_id 
      AND quantite = 0;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.deplacer_stock(p_piece_id integer, p_emplacement_source_id integer, p_emplacement_destination_id integer, p_quantite integer, p_commentaire text) OWNER TO gmao_app_user;

--
-- TOC entry 4422 (class 0 OID 0)
-- Dependencies: 380
-- Name: FUNCTION deplacer_stock(p_piece_id integer, p_emplacement_source_id integer, p_emplacement_destination_id integer, p_quantite integer, p_commentaire text); Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON FUNCTION public.deplacer_stock(p_piece_id integer, p_emplacement_source_id integer, p_emplacement_destination_id integer, p_quantite integer, p_commentaire text) IS 'Fonction pour déplacer du stock entre emplacements de manière atomique';


--
-- TOC entry 352 (class 1255 OID 16874)
-- Name: fournisseur_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.fournisseur_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fournisseur_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 354 (class 1255 OID 16878)
-- Name: gamme_entretien_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.gamme_entretien_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $$;


ALTER FUNCTION public.gamme_entretien_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 366 (class 1255 OID 17508)
-- Name: generer_numero_lot(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.generer_numero_lot() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN 'LOT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('lot_reception_id_seq')::TEXT, 6, '0');
END;
$$;


ALTER FUNCTION public.generer_numero_lot() OWNER TO gmao_app_user;

--
-- TOC entry 367 (class 1255 OID 17509)
-- Name: get_emplacement_reception_defaut(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.get_emplacement_reception_defaut() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    emplacement_id INTEGER;
BEGIN
    SELECT id INTO emplacement_id
    FROM emplacement
    WHERE nom = 'RECEPTION'
    LIMIT 1;
    
    RETURN emplacement_id;
END;
$$;


ALTER FUNCTION public.get_emplacement_reception_defaut() OWNER TO gmao_app_user;

--
-- TOC entry 362 (class 1255 OID 17230)
-- Name: init_emplacement_stock_dates(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.init_emplacement_stock_dates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_derniere_maj = NOW();
    IF NEW.quantite > 0 THEN
        NEW.date_derniere_entree = NOW();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.init_emplacement_stock_dates() OWNER TO gmao_app_user;

--
-- TOC entry 350 (class 1255 OID 16870)
-- Name: machine_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.machine_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.machine_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 379 (class 1255 OID 17249)
-- Name: nettoyer_stocks_zero(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.nettoyer_stocks_zero() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    nb_supprime INTEGER;
BEGIN
    DELETE FROM emplacement_stock WHERE quantite = 0;
    GET DIAGNOSTICS nb_supprime = ROW_COUNT;
    RETURN nb_supprime;
END;
$$;


ALTER FUNCTION public.nettoyer_stocks_zero() OWNER TO gmao_app_user;

--
-- TOC entry 351 (class 1255 OID 16872)
-- Name: ot_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.ot_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.ot_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 353 (class 1255 OID 16876)
-- Name: piece_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.piece_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.piece_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 385 (class 1255 OID 20142)
-- Name: unarchive_ot(integer, integer); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.unarchive_ot(ot_id_param integer, user_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE ordre_travail 
    SET 
        statut = 'Terminé',
        updated_at = CURRENT_TIMESTAMP
    WHERE id_ot = ot_id_param AND statut = 'Archivé';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'OT ID % non trouvé ou pas archivé', ot_id_param;
    END IF;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.unarchive_ot(ot_id_param integer, user_id integer) OWNER TO gmao_app_user;

--
-- TOC entry 360 (class 1255 OID 17226)
-- Name: update_emplacement_ext_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.update_emplacement_ext_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_emplacement_ext_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 361 (class 1255 OID 17228)
-- Name: update_emplacement_stock_maj(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.update_emplacement_stock_maj() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.date_derniere_maj = NOW();
    
    -- Mettre à jour les dates d'entrée/sortie selon le contexte
    IF NEW.quantite > COALESCE(OLD.quantite, 0) THEN
        NEW.date_derniere_entree = NOW();
    ELSIF NEW.quantite < COALESCE(OLD.quantite, 0) THEN
        NEW.date_derniere_sortie = NOW();
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_emplacement_stock_maj() OWNER TO gmao_app_user;

--
-- TOC entry 357 (class 1255 OID 17489)
-- Name: update_lot_reception_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.update_lot_reception_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_lot_reception_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 365 (class 1255 OID 17491)
-- Name: update_lot_statut_after_stockage(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.update_lot_statut_after_stockage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_stocke INTEGER;
    quantite_lot INTEGER;
BEGIN
    -- Calculer le total stocké pour ce lot
    SELECT COALESCE(SUM(quantite_stockee), 0) INTO total_stocke
    FROM mise_en_stock_detail
    WHERE lot_reception_id = NEW.lot_reception_id;
    
    -- Récupérer la quantité du lot
    SELECT quantite_recue INTO quantite_lot
    FROM lot_reception
    WHERE id = NEW.lot_reception_id;
    
    -- Mettre à jour le statut et les quantités
    UPDATE lot_reception 
    SET quantite_mise_en_stock = total_stocke,
        statut_lot = CASE 
            WHEN total_stocke >= quantite_lot THEN 'STOCKE'
            WHEN total_stocke > 0 THEN 'PRET_STOCKAGE'
            ELSE statut_lot
        END,
        date_mise_en_stock = CASE 
            WHEN total_stocke >= quantite_lot THEN NOW()
            ELSE date_mise_en_stock
        END
    WHERE id = NEW.lot_reception_id;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_lot_statut_after_stockage() OWNER TO gmao_app_user;

--
-- TOC entry 358 (class 1255 OID 17060)
-- Name: update_mouvement_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.update_mouvement_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_mouvement_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 349 (class 1255 OID 16868)
-- Name: utilisateur_updated_at(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.utilisateur_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.utilisateur_updated_at() OWNER TO gmao_app_user;

--
-- TOC entry 363 (class 1255 OID 17530)
-- Name: verifier_statut_avant_impact_stock(); Type: FUNCTION; Schema: public; Owner: gmao_app_user
--

CREATE FUNCTION public.verifier_statut_avant_impact_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si le mouvement a un impact sur le stock et n'est pas confirmé, ne pas modifier le stock
    IF NEW.statut_mouvement != 'CONFIRME' AND EXISTS (
        SELECT 1 FROM type_mouvement 
        WHERE id = NEW.type_mouvement_id AND impact_stock != 0
    ) THEN
        -- Pour les mouvements en attente, on garde le stock_avant = stock_apres
        NEW.stock_apres := NEW.stock_avant;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verifier_statut_avant_impact_stock() OWNER TO gmao_app_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 311 (class 1259 OID 19083)
-- Name: ao_fournisseur_consulte; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.ao_fournisseur_consulte (
    id integer NOT NULL,
    ao_id integer NOT NULL,
    fournisseur_id integer NOT NULL,
    date_envoi timestamp with time zone,
    a_repondu boolean DEFAULT false
);


ALTER TABLE public.ao_fournisseur_consulte OWNER TO gmao_app_user;

--
-- TOC entry 4423 (class 0 OID 0)
-- Dependencies: 311
-- Name: TABLE ao_fournisseur_consulte; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.ao_fournisseur_consulte IS 'Liste des fournisseurs contactés pour un AO.';


--
-- TOC entry 310 (class 1259 OID 19082)
-- Name: ao_fournisseur_consulte_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.ao_fournisseur_consulte_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ao_fournisseur_consulte_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4424 (class 0 OID 0)
-- Dependencies: 310
-- Name: ao_fournisseur_consulte_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.ao_fournisseur_consulte_id_seq OWNED BY public.ao_fournisseur_consulte.id;


--
-- TOC entry 309 (class 1259 OID 19060)
-- Name: appel_offre; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.appel_offre (
    id_ao integer NOT NULL,
    commande_id integer NOT NULL,
    reference_ao character varying(50) NOT NULL,
    titre character varying(255),
    createur_id integer,
    date_creation timestamp with time zone DEFAULT now(),
    date_cloture_prevue timestamp with time zone,
    statut public.statut_ao DEFAULT 'Ouvert'::public.statut_ao NOT NULL
);


ALTER TABLE public.appel_offre OWNER TO gmao_app_user;

--
-- TOC entry 4425 (class 0 OID 0)
-- Dependencies: 309
-- Name: TABLE appel_offre; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.appel_offre IS 'Dossier central pour un appel d''offres.';


--
-- TOC entry 4426 (class 0 OID 0)
-- Dependencies: 309
-- Name: COLUMN appel_offre.commande_id; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.appel_offre.commande_id IS 'ID de la commande (brouillon) qui est à l''origine de cet AO.';


--
-- TOC entry 308 (class 1259 OID 19059)
-- Name: appel_offre_id_ao_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.appel_offre_id_ao_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.appel_offre_id_ao_seq OWNER TO gmao_app_user;

--
-- TOC entry 4427 (class 0 OID 0)
-- Dependencies: 308
-- Name: appel_offre_id_ao_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.appel_offre_id_ao_seq OWNED BY public.appel_offre.id_ao;


--
-- TOC entry 333 (class 1259 OID 19928)
-- Name: auth_group; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO gmao_app_user;

--
-- TOC entry 332 (class 1259 OID 19927)
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 335 (class 1259 OID 19936)
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO gmao_app_user;

--
-- TOC entry 334 (class 1259 OID 19935)
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 331 (class 1259 OID 19922)
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO gmao_app_user;

--
-- TOC entry 330 (class 1259 OID 19921)
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 337 (class 1259 OID 19942)
-- Name: auth_user; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE public.auth_user OWNER TO gmao_app_user;

--
-- TOC entry 339 (class 1259 OID 19950)
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.auth_user_groups (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.auth_user_groups OWNER TO gmao_app_user;

--
-- TOC entry 338 (class 1259 OID 19949)
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.auth_user_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 336 (class 1259 OID 19941)
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.auth_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 341 (class 1259 OID 19956)
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.auth_user_user_permissions (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_user_user_permissions OWNER TO gmao_app_user;

--
-- TOC entry 340 (class 1259 OID 19955)
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.auth_user_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 248 (class 1259 OID 16707)
-- Name: commande; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.commande (
    id_commande integer NOT NULL,
    numero_commande text,
    fournisseur_id integer NOT NULL,
    createur_id integer NOT NULL,
    date_commande text NOT NULL,
    date_livraison_prevue text,
    date_livraison_reelle text,
    statut text DEFAULT 'Brouillon'::text NOT NULL,
    total_ht double precision DEFAULT 0.0,
    frais_port double precision DEFAULT 0.0,
    reference_fournisseur text,
    mode_paiement text,
    notes_commande text,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    updated_at text DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT commande_statut_check CHECK ((statut = ANY (ARRAY['Brouillon'::text, 'Validee'::text, 'Envoyee'::text, 'Partielle'::text, 'Livree'::text, 'Annulee'::text])))
);


ALTER TABLE public.commande OWNER TO gmao_app_user;

--
-- TOC entry 247 (class 1259 OID 16706)
-- Name: commande_id_commande_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.commande_id_commande_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.commande_id_commande_seq OWNER TO gmao_app_user;

--
-- TOC entry 4428 (class 0 OID 0)
-- Dependencies: 247
-- Name: commande_id_commande_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.commande_id_commande_seq OWNED BY public.commande.id_commande;


--
-- TOC entry 252 (class 1259 OID 16759)
-- Name: compteur; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.compteur (
    id_compteur integer NOT NULL,
    machine_id integer NOT NULL,
    nom text NOT NULL,
    unite text NOT NULL,
    valeur_actuelle double precision DEFAULT 0.0,
    date_dernier_releve text,
    seuil_alerte double precision,
    seuil_prev_ot double precision,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    updated_at text DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.compteur OWNER TO gmao_app_user;

--
-- TOC entry 251 (class 1259 OID 16758)
-- Name: compteur_id_compteur_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.compteur_id_compteur_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.compteur_id_compteur_seq OWNER TO gmao_app_user;

--
-- TOC entry 4429 (class 0 OID 0)
-- Dependencies: 251
-- Name: compteur_id_compteur_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.compteur_id_compteur_seq OWNED BY public.compteur.id_compteur;


--
-- TOC entry 323 (class 1259 OID 19824)
-- Name: contrat_achat; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.contrat_achat (
    id_contrat_achat integer NOT NULL,
    reference_interne_contrat character varying(50) NOT NULL,
    objet_contrat text NOT NULL,
    fournisseur_id integer NOT NULL,
    numero_contrat_fournisseur character varying(100),
    date_signature date,
    date_debut_validite date NOT NULL,
    date_fin_validite date NOT NULL,
    date_prochain_renouvellement date,
    montant_total_engage numeric(14,2),
    devise_contrat character(3) DEFAULT 'EUR'::bpchar,
    type_contrat text,
    statut_contrat public.statut_contrat_enum DEFAULT 'Actif'::public.statut_contrat_enum NOT NULL,
    contact_principal_achat_id integer,
    contact_fournisseur_specifique text,
    chemin_document_pdf text,
    notes_contrat text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.contrat_achat OWNER TO gmao_app_user;

--
-- TOC entry 4430 (class 0 OID 0)
-- Dependencies: 323
-- Name: TABLE contrat_achat; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.contrat_achat IS 'Stocke les informations essentielles des contrats d''achat passés avec les fournisseurs.';


--
-- TOC entry 4431 (class 0 OID 0)
-- Dependencies: 323
-- Name: COLUMN contrat_achat.reference_interne_contrat; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.contrat_achat.reference_interne_contrat IS 'Référence unique interne pour identifier facilement le contrat.';


--
-- TOC entry 4432 (class 0 OID 0)
-- Dependencies: 323
-- Name: COLUMN contrat_achat.objet_contrat; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.contrat_achat.objet_contrat IS 'Description de ce que couvre le contrat.';


--
-- TOC entry 4433 (class 0 OID 0)
-- Dependencies: 323
-- Name: COLUMN contrat_achat.chemin_document_pdf; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.contrat_achat.chemin_document_pdf IS 'Chemin réseau ou URL vers le document contractuel numérisé.';


--
-- TOC entry 322 (class 1259 OID 19823)
-- Name: contrat_achat_id_contrat_achat_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.contrat_achat_id_contrat_achat_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contrat_achat_id_contrat_achat_seq OWNER TO gmao_app_user;

--
-- TOC entry 4434 (class 0 OID 0)
-- Dependencies: 322
-- Name: contrat_achat_id_contrat_achat_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.contrat_achat_id_contrat_achat_seq OWNED BY public.contrat_achat.id_contrat_achat;


--
-- TOC entry 305 (class 1259 OID 19018)
-- Name: demandes_achat; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.demandes_achat (
    id integer NOT NULL,
    reference character varying(50) NOT NULL,
    demandeur_id integer,
    date_creation timestamp with time zone DEFAULT now(),
    statut public.statut_da DEFAULT 'En attente'::public.statut_da NOT NULL,
    source_type public.source_type,
    source_id integer
);


ALTER TABLE public.demandes_achat OWNER TO gmao_app_user;

--
-- TOC entry 304 (class 1259 OID 19017)
-- Name: demandes_achat_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.demandes_achat_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.demandes_achat_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4435 (class 0 OID 0)
-- Dependencies: 304
-- Name: demandes_achat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.demandes_achat_id_seq OWNED BY public.demandes_achat.id;


--
-- TOC entry 307 (class 1259 OID 19034)
-- Name: demandes_achat_lignes; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.demandes_achat_lignes (
    id integer NOT NULL,
    demande_achat_id integer NOT NULL,
    article_id integer,
    quantite_demandee numeric(10,2) NOT NULL,
    date_besoin timestamp with time zone,
    description character varying(255)
);


ALTER TABLE public.demandes_achat_lignes OWNER TO gmao_app_user;

--
-- TOC entry 306 (class 1259 OID 19033)
-- Name: demandes_achat_lignes_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.demandes_achat_lignes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.demandes_achat_lignes_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4436 (class 0 OID 0)
-- Dependencies: 306
-- Name: demandes_achat_lignes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.demandes_achat_lignes_id_seq OWNED BY public.demandes_achat_lignes.id;


--
-- TOC entry 343 (class 1259 OID 20014)
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO gmao_app_user;

--
-- TOC entry 342 (class 1259 OID 20013)
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 329 (class 1259 OID 19914)
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO gmao_app_user;

--
-- TOC entry 328 (class 1259 OID 19913)
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 327 (class 1259 OID 19906)
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE public.django_migrations OWNER TO gmao_app_user;

--
-- TOC entry 326 (class 1259 OID 19905)
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 344 (class 1259 OID 20042)
-- Name: django_session; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO gmao_app_user;

--
-- TOC entry 266 (class 1259 OID 16926)
-- Name: emplacement; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.emplacement (
    id integer NOT NULL,
    magasin_id integer,
    nom character varying(100) NOT NULL,
    type character varying(50),
    allee character varying(50),
    etagere character varying(50),
    niveau character varying(50)
);


ALTER TABLE public.emplacement OWNER TO gmao_app_user;

--
-- TOC entry 279 (class 1259 OID 17175)
-- Name: emplacement_ext; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.emplacement_ext (
    emplacement_id integer NOT NULL,
    longueur_cm numeric(8,2),
    hauteur_cm numeric(8,2),
    profondeur_cm numeric(8,2),
    volume_cm3 numeric(15,2) GENERATED ALWAYS AS (((longueur_cm * hauteur_cm) * profondeur_cm)) STORED,
    capacite_max_kg numeric(10,2),
    temperature_min_c numeric(5,2),
    temperature_max_c numeric(5,2),
    humidite_max_pct numeric(5,2),
    conditions_speciales text,
    actif boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_temperature CHECK (((temperature_max_c IS NULL) OR (temperature_min_c IS NULL) OR (temperature_max_c >= temperature_min_c))),
    CONSTRAINT emplacement_ext_capacite_max_kg_check CHECK ((capacite_max_kg >= (0)::numeric)),
    CONSTRAINT emplacement_ext_hauteur_cm_check CHECK ((hauteur_cm > (0)::numeric)),
    CONSTRAINT emplacement_ext_humidite_max_pct_check CHECK (((humidite_max_pct >= (0)::numeric) AND (humidite_max_pct <= (100)::numeric))),
    CONSTRAINT emplacement_ext_longueur_cm_check CHECK ((longueur_cm > (0)::numeric)),
    CONSTRAINT emplacement_ext_profondeur_cm_check CHECK ((profondeur_cm > (0)::numeric))
);


ALTER TABLE public.emplacement_ext OWNER TO gmao_app_user;

--
-- TOC entry 4437 (class 0 OID 0)
-- Dependencies: 279
-- Name: TABLE emplacement_ext; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.emplacement_ext IS 'Extension des emplacements avec dimensions et propriétés physiques';


--
-- TOC entry 4438 (class 0 OID 0)
-- Dependencies: 279
-- Name: COLUMN emplacement_ext.volume_cm3; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.emplacement_ext.volume_cm3 IS 'Volume calculé automatiquement (L×H×P)';


--
-- TOC entry 4439 (class 0 OID 0)
-- Dependencies: 279
-- Name: COLUMN emplacement_ext.capacite_max_kg; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.emplacement_ext.capacite_max_kg IS 'Capacité maximale en poids';


--
-- TOC entry 265 (class 1259 OID 16925)
-- Name: emplacement_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.emplacement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emplacement_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4440 (class 0 OID 0)
-- Dependencies: 265
-- Name: emplacement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.emplacement_id_seq OWNED BY public.emplacement.id;


--
-- TOC entry 281 (class 1259 OID 17198)
-- Name: emplacement_stock; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.emplacement_stock (
    id integer NOT NULL,
    emplacement_id integer NOT NULL,
    piece_id integer NOT NULL,
    quantite integer DEFAULT 0 NOT NULL,
    date_derniere_entree timestamp without time zone,
    date_derniere_sortie timestamp without time zone,
    date_derniere_maj timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    commentaire text,
    CONSTRAINT emplacement_stock_quantite_check CHECK ((quantite >= 0))
);


ALTER TABLE public.emplacement_stock OWNER TO gmao_app_user;

--
-- TOC entry 4441 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE emplacement_stock; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.emplacement_stock IS 'Stock détaillé par emplacement et par pièce';


--
-- TOC entry 4442 (class 0 OID 0)
-- Dependencies: 281
-- Name: COLUMN emplacement_stock.quantite; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.emplacement_stock.quantite IS 'Quantité de la pièce dans cet emplacement';


--
-- TOC entry 280 (class 1259 OID 17197)
-- Name: emplacement_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.emplacement_stock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emplacement_stock_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4443 (class 0 OID 0)
-- Dependencies: 280
-- Name: emplacement_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.emplacement_stock_id_seq OWNED BY public.emplacement_stock.id;


--
-- TOC entry 226 (class 1259 OID 16437)
-- Name: equipe; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.equipe (
    id_equipe integer NOT NULL,
    nom text NOT NULL,
    domaine_expertise text,
    responsable_id integer
);


ALTER TABLE public.equipe OWNER TO gmao_app_user;

--
-- TOC entry 225 (class 1259 OID 16436)
-- Name: equipe_id_equipe_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.equipe_id_equipe_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.equipe_id_equipe_seq OWNER TO gmao_app_user;

--
-- TOC entry 4444 (class 0 OID 0)
-- Dependencies: 225
-- Name: equipe_id_equipe_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.equipe_id_equipe_seq OWNED BY public.equipe.id_equipe;


--
-- TOC entry 220 (class 1259 OID 16404)
-- Name: fabricant; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.fabricant (
    id_fabricant integer NOT NULL,
    nom text NOT NULL,
    contact text,
    site_web text,
    support_technique text
);


ALTER TABLE public.fabricant OWNER TO gmao_app_user;

--
-- TOC entry 219 (class 1259 OID 16403)
-- Name: fabricant_id_fabricant_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.fabricant_id_fabricant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fabricant_id_fabricant_seq OWNER TO gmao_app_user;

--
-- TOC entry 4445 (class 0 OID 0)
-- Dependencies: 219
-- Name: fabricant_id_fabricant_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.fabricant_id_fabricant_seq OWNED BY public.fabricant.id_fabricant;


--
-- TOC entry 232 (class 1259 OID 16503)
-- Name: fournisseur; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.fournisseur (
    id_fournisseur integer NOT NULL,
    nom text NOT NULL,
    contact text,
    adresse text,
    telephone text,
    email text,
    delai_livraison_moyen_j integer,
    devise text DEFAULT 'EUR'::text,
    note_qualite double precision,
    updated_at text
);


ALTER TABLE public.fournisseur OWNER TO gmao_app_user;

--
-- TOC entry 231 (class 1259 OID 16502)
-- Name: fournisseur_id_fournisseur_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.fournisseur_id_fournisseur_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fournisseur_id_fournisseur_seq OWNER TO gmao_app_user;

--
-- TOC entry 4446 (class 0 OID 0)
-- Dependencies: 231
-- Name: fournisseur_id_fournisseur_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.fournisseur_id_fournisseur_seq OWNED BY public.fournisseur.id_fournisseur;


--
-- TOC entry 242 (class 1259 OID 16648)
-- Name: gamme_entretien; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.gamme_entretien (
    id_gamme integer NOT NULL,
    description text NOT NULL,
    type_entretien text,
    periodicite_valeur integer,
    periodicite_unite text,
    instructions text,
    date_derniere_realisation text,
    prochaine_date_calculee text,
    active integer DEFAULT 1,
    type_machine_id integer,
    createur_id integer,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    updated_at text DEFAULT CURRENT_TIMESTAMP,
    duree_estimee_min integer,
    qualification_requise text,
    priorite text
);


ALTER TABLE public.gamme_entretien OWNER TO gmao_app_user;

--
-- TOC entry 241 (class 1259 OID 16647)
-- Name: gamme_entretien_id_gamme_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.gamme_entretien_id_gamme_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gamme_entretien_id_gamme_seq OWNER TO gmao_app_user;

--
-- TOC entry 4447 (class 0 OID 0)
-- Dependencies: 241
-- Name: gamme_entretien_id_gamme_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.gamme_entretien_id_gamme_seq OWNED BY public.gamme_entretien.id_gamme;


--
-- TOC entry 244 (class 1259 OID 16672)
-- Name: gamme_etape; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.gamme_etape (
    id_etape integer NOT NULL,
    gamme_id integer NOT NULL,
    description text NOT NULL,
    ordre integer NOT NULL,
    instructions_detaillees text,
    duree_estimee_min integer
);


ALTER TABLE public.gamme_etape OWNER TO gmao_app_user;

--
-- TOC entry 243 (class 1259 OID 16671)
-- Name: gamme_etape_id_etape_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.gamme_etape_id_etape_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gamme_etape_id_etape_seq OWNER TO gmao_app_user;

--
-- TOC entry 4448 (class 0 OID 0)
-- Dependencies: 243
-- Name: gamme_etape_id_etape_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.gamme_etape_id_etape_seq OWNED BY public.gamme_etape.id_etape;


--
-- TOC entry 246 (class 1259 OID 16686)
-- Name: gamme_piece_type; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.gamme_piece_type (
    id integer NOT NULL,
    gamme_id integer NOT NULL,
    piece_id integer NOT NULL,
    quantite_theorique integer DEFAULT 1,
    CONSTRAINT gamme_piece_type_quantite_theorique_check CHECK ((quantite_theorique >= 0))
);


ALTER TABLE public.gamme_piece_type OWNER TO gmao_app_user;

--
-- TOC entry 245 (class 1259 OID 16685)
-- Name: gamme_piece_type_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.gamme_piece_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gamme_piece_type_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4449 (class 0 OID 0)
-- Dependencies: 245
-- Name: gamme_piece_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.gamme_piece_type_id_seq OWNED BY public.gamme_piece_type.id;


--
-- TOC entry 254 (class 1259 OID 16778)
-- Name: historique_compteur; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.historique_compteur (
    id_historique integer NOT NULL,
    compteur_id integer NOT NULL,
    date_releve text DEFAULT CURRENT_TIMESTAMP,
    valeur double precision NOT NULL,
    utilisateur_id integer,
    maintenance_id integer
);


ALTER TABLE public.historique_compteur OWNER TO gmao_app_user;

--
-- TOC entry 253 (class 1259 OID 16777)
-- Name: historique_compteur_id_historique_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.historique_compteur_id_historique_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.historique_compteur_id_historique_seq OWNER TO gmao_app_user;

--
-- TOC entry 4450 (class 0 OID 0)
-- Dependencies: 253
-- Name: historique_compteur_id_historique_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.historique_compteur_id_historique_seq OWNED BY public.historique_compteur.id_historique;


--
-- TOC entry 240 (class 1259 OID 16602)
-- Name: intervention_piece; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.intervention_piece (
    id integer NOT NULL,
    maintenance_id integer NOT NULL,
    piece_id integer NOT NULL,
    quantite integer NOT NULL,
    lot text,
    CONSTRAINT intervention_piece_quantite_check CHECK ((quantite > 0))
);


ALTER TABLE public.intervention_piece OWNER TO gmao_app_user;

--
-- TOC entry 239 (class 1259 OID 16601)
-- Name: intervention_piece_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.intervention_piece_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.intervention_piece_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4451 (class 0 OID 0)
-- Dependencies: 239
-- Name: intervention_piece_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.intervention_piece_id_seq OWNED BY public.intervention_piece.id;


--
-- TOC entry 286 (class 1259 OID 17253)
-- Name: inventory_users; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.inventory_users (
    id integer NOT NULL,
    username text NOT NULL,
    password text NOT NULL,
    is_admin boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.inventory_users OWNER TO gmao_app_user;

--
-- TOC entry 285 (class 1259 OID 17252)
-- Name: inventory_users_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.inventory_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventory_users_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4452 (class 0 OID 0)
-- Dependencies: 285
-- Name: inventory_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.inventory_users_id_seq OWNED BY public.inventory_users.id;


--
-- TOC entry 269 (class 1259 OID 16979)
-- Name: inventory_warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_warehouse (
    id integer NOT NULL,
    nom character varying(100) NOT NULL,
    description text,
    adresse text,
    ville character varying(100),
    pays character varying(100),
    code_postal character varying(20),
    responsable_id integer,
    actif boolean DEFAULT true,
    max_aisles integer DEFAULT 10,
    max_shelves integer DEFAULT 5,
    max_levels integer DEFAULT 4,
    CONSTRAINT inventory_warehouse_max_aisles_check CHECK ((max_aisles > 0)),
    CONSTRAINT inventory_warehouse_max_levels_check CHECK ((max_levels > 0)),
    CONSTRAINT inventory_warehouse_max_shelves_check CHECK ((max_shelves > 0))
);


ALTER TABLE public.inventory_warehouse OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 16978)
-- Name: inventory_warehouse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventory_warehouse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventory_warehouse_id_seq OWNER TO postgres;

--
-- TOC entry 4453 (class 0 OID 0)
-- Dependencies: 268
-- Name: inventory_warehouse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventory_warehouse_id_seq OWNED BY public.inventory_warehouse.id;


--
-- TOC entry 289 (class 1259 OID 17307)
-- Name: inventory_warehouses; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.inventory_warehouses (
    id integer NOT NULL,
    nom text NOT NULL,
    adresse text,
    ville text,
    code_postal text,
    pays text,
    contact_principal text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    max_aisles integer DEFAULT 10,
    max_shelves integer DEFAULT 5,
    max_levels integer DEFAULT 4,
    actif boolean DEFAULT true,
    CONSTRAINT inventory_warehouses_max_aisles_check CHECK ((max_aisles > 0)),
    CONSTRAINT inventory_warehouses_max_levels_check CHECK ((max_levels > 0)),
    CONSTRAINT inventory_warehouses_max_shelves_check CHECK ((max_shelves > 0))
);


ALTER TABLE public.inventory_warehouses OWNER TO gmao_app_user;

--
-- TOC entry 288 (class 1259 OID 17306)
-- Name: inventory_warehouses_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.inventory_warehouses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventory_warehouses_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4454 (class 0 OID 0)
-- Dependencies: 288
-- Name: inventory_warehouses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.inventory_warehouses_id_seq OWNED BY public.inventory_warehouses.id;


--
-- TOC entry 250 (class 1259 OID 16734)
-- Name: ligne_commande; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.ligne_commande (
    id_ligne integer NOT NULL,
    commande_id integer NOT NULL,
    piece_id integer NOT NULL,
    description_libre text,
    quantite_commandee integer NOT NULL,
    prix_unitaire_ht double precision NOT NULL,
    quantite_recue integer DEFAULT 0,
    date_reception text,
    statut_ligne text DEFAULT 'Attente'::text NOT NULL,
    quantite_defectueuse integer DEFAULT 0,
    date_derniere_reception timestamp without time zone,
    commentaire_reception text,
    CONSTRAINT ligne_commande_prix_unitaire_ht_check CHECK ((prix_unitaire_ht >= (0)::double precision)),
    CONSTRAINT ligne_commande_quantite_commandee_check CHECK ((quantite_commandee > 0)),
    CONSTRAINT ligne_commande_quantite_recue_check CHECK ((quantite_recue >= 0)),
    CONSTRAINT ligne_commande_statut_ligne_check CHECK ((statut_ligne = ANY (ARRAY['Attente'::text, 'Partielle'::text, 'Complete'::text, 'Annulee'::text])))
);


ALTER TABLE public.ligne_commande OWNER TO gmao_app_user;

--
-- TOC entry 249 (class 1259 OID 16733)
-- Name: ligne_commande_id_ligne_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.ligne_commande_id_ligne_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ligne_commande_id_ligne_seq OWNER TO gmao_app_user;

--
-- TOC entry 4455 (class 0 OID 0)
-- Dependencies: 249
-- Name: ligne_commande_id_ligne_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.ligne_commande_id_ligne_seq OWNED BY public.ligne_commande.id_ligne;


--
-- TOC entry 295 (class 1259 OID 17400)
-- Name: lot_reception; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.lot_reception (
    id integer NOT NULL,
    numero_lot character varying(50) NOT NULL,
    commande_id integer,
    ligne_commande_id integer,
    piece_id integer NOT NULL,
    quantite_recue integer NOT NULL,
    quantite_mise_en_stock integer DEFAULT 0,
    quantite_restante integer GENERATED ALWAYS AS ((quantite_recue - quantite_mise_en_stock)) STORED,
    emplacement_reception_id integer,
    date_reception timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    date_mise_en_stock timestamp without time zone,
    statut_lot character varying(20) DEFAULT 'EN_RECEPTION'::character varying,
    utilisateur_reception_id integer,
    utilisateur_stockage_id integer,
    commentaire_reception text,
    commentaire_stockage text,
    bon_etat boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT lot_reception_quantite_mise_en_stock_check CHECK ((quantite_mise_en_stock >= 0)),
    CONSTRAINT lot_reception_quantite_recue_check CHECK ((quantite_recue > 0)),
    CONSTRAINT lot_reception_statut_lot_check CHECK (((statut_lot)::text = ANY ((ARRAY['EN_RECEPTION'::character varying, 'EN_CONTROLE'::character varying, 'PRET_STOCKAGE'::character varying, 'STOCKE'::character varying, 'QUARANTAINE'::character varying])::text[])))
);


ALTER TABLE public.lot_reception OWNER TO gmao_app_user;

--
-- TOC entry 4456 (class 0 OID 0)
-- Dependencies: 295
-- Name: TABLE lot_reception; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.lot_reception IS 'Gestion des lots de réception avant mise en stock';


--
-- TOC entry 4457 (class 0 OID 0)
-- Dependencies: 295
-- Name: COLUMN lot_reception.quantite_restante; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.lot_reception.quantite_restante IS 'Quantité restant à mettre en stock (calculée automatiquement)';


--
-- TOC entry 4458 (class 0 OID 0)
-- Dependencies: 295
-- Name: COLUMN lot_reception.statut_lot; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.lot_reception.statut_lot IS 'EN_RECEPTION, EN_CONTROLE, PRET_STOCKAGE, STOCKE, QUARANTAINE';


--
-- TOC entry 294 (class 1259 OID 17399)
-- Name: lot_reception_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.lot_reception_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lot_reception_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4459 (class 0 OID 0)
-- Dependencies: 294
-- Name: lot_reception_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.lot_reception_id_seq OWNED BY public.lot_reception.id;


--
-- TOC entry 291 (class 1259 OID 17318)
-- Name: lot_serie; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.lot_serie (
    id integer NOT NULL,
    article_id integer NOT NULL,
    numero text NOT NULL,
    date_peremption date,
    cout_unitaire_reception numeric
);


ALTER TABLE public.lot_serie OWNER TO gmao_app_user;

--
-- TOC entry 290 (class 1259 OID 17317)
-- Name: lot_serie_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.lot_serie_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lot_serie_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4460 (class 0 OID 0)
-- Dependencies: 290
-- Name: lot_serie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.lot_serie_id_seq OWNED BY public.lot_serie.id;


--
-- TOC entry 230 (class 1259 OID 16469)
-- Name: machine; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.machine (
    id_machine integer NOT NULL,
    nom text NOT NULL,
    serial text,
    modele text,
    date_installation text,
    localisation text,
    etat text DEFAULT 'Inconnu'::text,
    informations_techniques text,
    type_machine_id integer NOT NULL,
    site_id integer NOT NULL,
    fabricant_id integer NOT NULL,
    parent_machine_id integer,
    criticite text,
    garantie_fin text,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    updated_at text DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.machine OWNER TO gmao_app_user;

--
-- TOC entry 229 (class 1259 OID 16468)
-- Name: machine_id_machine_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.machine_id_machine_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.machine_id_machine_seq OWNER TO gmao_app_user;

--
-- TOC entry 4461 (class 0 OID 0)
-- Dependencies: 229
-- Name: machine_id_machine_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.machine_id_machine_seq OWNED BY public.machine.id_machine;


--
-- TOC entry 238 (class 1259 OID 16570)
-- Name: maintenance; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.maintenance (
    id_maintenance integer NOT NULL,
    ot_id integer NOT NULL,
    machine_id integer,
    technicien_id integer NOT NULL,
    date_debut_reelle text NOT NULL,
    date_fin_reelle text NOT NULL,
    duree_intervention_h double precision,
    type_reel text NOT NULL,
    description_travaux text NOT NULL,
    resultat text NOT NULL,
    cout_manuel_v1 double precision,
    cout_main_oeuvre double precision DEFAULT 0.0,
    cout_pieces_internes double precision DEFAULT 0.0,
    cout_pieces_externes double precision DEFAULT 0.0,
    cout_autres_frais double precision DEFAULT 0.0,
    cout_total double precision DEFAULT 0.0,
    evaluation_qualite integer,
    impact_production text,
    notes_technicien text,
    created_at text DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.maintenance OWNER TO gmao_app_user;

--
-- TOC entry 258 (class 1259 OID 16826)
-- Name: maintenance_frais_externe; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.maintenance_frais_externe (
    id_frais integer NOT NULL,
    maintenance_id integer NOT NULL,
    type_frais text NOT NULL,
    description text NOT NULL,
    montant double precision NOT NULL,
    quantite integer DEFAULT 1,
    reference_piece text,
    fournisseur text,
    facture_reference text,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT maintenance_frais_externe_montant_check CHECK ((montant >= (0)::double precision)),
    CONSTRAINT maintenance_frais_externe_quantite_check CHECK ((quantite > 0)),
    CONSTRAINT maintenance_frais_externe_type_frais_check CHECK ((type_frais = ANY (ARRAY['PIECE_EXTERNE'::text, 'DEPLACEMENT'::text, 'SOUS_TRAITANCE'::text, 'AUTRE'::text])))
);


ALTER TABLE public.maintenance_frais_externe OWNER TO gmao_app_user;

--
-- TOC entry 257 (class 1259 OID 16825)
-- Name: maintenance_frais_externe_id_frais_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.maintenance_frais_externe_id_frais_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maintenance_frais_externe_id_frais_seq OWNER TO gmao_app_user;

--
-- TOC entry 4462 (class 0 OID 0)
-- Dependencies: 257
-- Name: maintenance_frais_externe_id_frais_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.maintenance_frais_externe_id_frais_seq OWNED BY public.maintenance_frais_externe.id_frais;


--
-- TOC entry 237 (class 1259 OID 16569)
-- Name: maintenance_id_maintenance_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.maintenance_id_maintenance_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maintenance_id_maintenance_seq OWNER TO gmao_app_user;

--
-- TOC entry 4463 (class 0 OID 0)
-- Dependencies: 237
-- Name: maintenance_id_maintenance_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.maintenance_id_maintenance_seq OWNED BY public.maintenance.id_maintenance;


--
-- TOC entry 256 (class 1259 OID 16803)
-- Name: maintenance_intervenant; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.maintenance_intervenant (
    id_intervenant integer NOT NULL,
    maintenance_id integer NOT NULL,
    technicien_id integer,
    nom_intervenant_externe text,
    heures_travaillees double precision NOT NULL,
    cout_horaire double precision NOT NULL,
    notes text,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT maintenance_intervenant_check CHECK (((technicien_id IS NOT NULL) OR (nom_intervenant_externe IS NOT NULL))),
    CONSTRAINT maintenance_intervenant_cout_horaire_check CHECK ((cout_horaire >= (0)::double precision)),
    CONSTRAINT maintenance_intervenant_heures_travaillees_check CHECK ((heures_travaillees > (0)::double precision))
);


ALTER TABLE public.maintenance_intervenant OWNER TO gmao_app_user;

--
-- TOC entry 255 (class 1259 OID 16802)
-- Name: maintenance_intervenant_id_intervenant_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.maintenance_intervenant_id_intervenant_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.maintenance_intervenant_id_intervenant_seq OWNER TO gmao_app_user;

--
-- TOC entry 4464 (class 0 OID 0)
-- Dependencies: 255
-- Name: maintenance_intervenant_id_intervenant_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.maintenance_intervenant_id_intervenant_seq OWNED BY public.maintenance_intervenant.id_intervenant;


--
-- TOC entry 297 (class 1259 OID 17455)
-- Name: mise_en_stock_detail; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.mise_en_stock_detail (
    id integer NOT NULL,
    lot_reception_id integer NOT NULL,
    emplacement_destination_id integer NOT NULL,
    quantite_stockee integer NOT NULL,
    date_stockage timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    utilisateur_id integer,
    mouvement_stock_id integer,
    commentaire text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT mise_en_stock_detail_quantite_stockee_check CHECK ((quantite_stockee > 0))
);


ALTER TABLE public.mise_en_stock_detail OWNER TO gmao_app_user;

--
-- TOC entry 4465 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE mise_en_stock_detail; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.mise_en_stock_detail IS 'Détail des mises en stock depuis la réception';


--
-- TOC entry 296 (class 1259 OID 17454)
-- Name: mise_en_stock_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.mise_en_stock_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mise_en_stock_detail_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4466 (class 0 OID 0)
-- Dependencies: 296
-- Name: mise_en_stock_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.mise_en_stock_detail_id_seq OWNED BY public.mise_en_stock_detail.id;


--
-- TOC entry 273 (class 1259 OID 17075)
-- Name: mouvement_stock; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.mouvement_stock (
    id integer NOT NULL,
    piece_id integer NOT NULL,
    type_mouvement_id integer NOT NULL,
    quantite integer NOT NULL,
    emplacement_source_id integer,
    emplacement_destination_id integer,
    utilisateur_id integer,
    date_mouvement timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    reference_document character varying(100),
    commentaire text,
    cout_unitaire numeric(10,2),
    cout_total numeric(10,2),
    stock_avant integer NOT NULL,
    stock_apres integer NOT NULL,
    valide boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    statut_mouvement character varying(20) DEFAULT 'CONFIRME'::character varying,
    CONSTRAINT mouvement_stock_statut_mouvement_check CHECK (((statut_mouvement)::text = ANY ((ARRAY['EN_ATTENTE'::character varying, 'CONFIRME'::character varying, 'ANNULE'::character varying])::text[])))
);


ALTER TABLE public.mouvement_stock OWNER TO gmao_app_user;

--
-- TOC entry 4467 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN mouvement_stock.statut_mouvement; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.mouvement_stock.statut_mouvement IS 'EN_ATTENTE: mouvement créé mais pas encore confirmé, CONFIRME: mouvement validé et impact sur stock, ANNULE: mouvement annulé';


--
-- TOC entry 272 (class 1259 OID 17074)
-- Name: mouvement_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.mouvement_stock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mouvement_stock_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4468 (class 0 OID 0)
-- Dependencies: 272
-- Name: mouvement_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.mouvement_stock_id_seq OWNED BY public.mouvement_stock.id;


--
-- TOC entry 313 (class 1259 OID 19103)
-- Name: offre_recue; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.offre_recue (
    id_offre integer NOT NULL,
    ao_id integer NOT NULL,
    fournisseur_id integer NOT NULL,
    date_reception timestamp with time zone DEFAULT now(),
    reference_offre_fournisseur character varying(100),
    delai_livraison_propose_j integer,
    validite_offre_jours integer,
    conditions_commerciales text
);


ALTER TABLE public.offre_recue OWNER TO gmao_app_user;

--
-- TOC entry 4469 (class 0 OID 0)
-- Dependencies: 313
-- Name: TABLE offre_recue; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.offre_recue IS 'Réponse globale d''un fournisseur à un AO.';


--
-- TOC entry 312 (class 1259 OID 19102)
-- Name: offre_recue_id_offre_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.offre_recue_id_offre_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offre_recue_id_offre_seq OWNER TO gmao_app_user;

--
-- TOC entry 4470 (class 0 OID 0)
-- Dependencies: 312
-- Name: offre_recue_id_offre_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.offre_recue_id_offre_seq OWNED BY public.offre_recue.id_offre;


--
-- TOC entry 315 (class 1259 OID 19125)
-- Name: offre_recue_ligne; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.offre_recue_ligne (
    id_offre_ligne integer NOT NULL,
    offre_id integer NOT NULL,
    piece_id integer NOT NULL,
    prix_unitaire_ht_propose numeric(10,4) NOT NULL,
    remise_percent numeric(5,2) DEFAULT 0.00,
    commentaire text
);


ALTER TABLE public.offre_recue_ligne OWNER TO gmao_app_user;

--
-- TOC entry 4471 (class 0 OID 0)
-- Dependencies: 315
-- Name: TABLE offre_recue_ligne; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.offre_recue_ligne IS 'Détail des prix par pièce pour une offre fournisseur.';


--
-- TOC entry 314 (class 1259 OID 19124)
-- Name: offre_recue_ligne_id_offre_ligne_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.offre_recue_ligne_id_offre_ligne_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offre_recue_ligne_id_offre_ligne_seq OWNER TO gmao_app_user;

--
-- TOC entry 4472 (class 0 OID 0)
-- Dependencies: 314
-- Name: offre_recue_ligne_id_offre_ligne_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.offre_recue_ligne_id_offre_ligne_seq OWNED BY public.offre_recue_ligne.id_offre_ligne;


--
-- TOC entry 319 (class 1259 OID 19692)
-- Name: orders; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.orders (
    id integer NOT NULL,
    supplier character varying NOT NULL,
    date character varying NOT NULL
);


ALTER TABLE public.orders OWNER TO gmao_app_user;

--
-- TOC entry 318 (class 1259 OID 19691)
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4473 (class 0 OID 0)
-- Dependencies: 318
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- TOC entry 236 (class 1259 OID 16540)
-- Name: ordre_travail; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.ordre_travail (
    id_ot integer NOT NULL,
    numero_ot text,
    machine_id integer NOT NULL,
    gamme_id integer,
    type text NOT NULL,
    description text NOT NULL,
    date_creation text DEFAULT CURRENT_TIMESTAMP,
    date_prevue text,
    duree_prevue_min integer,
    priorite text,
    urgence integer DEFAULT 0,
    statut text NOT NULL,
    technicien_assigne_id integer,
    utilisateur_createur_id integer NOT NULL,
    notes_planification text,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    updated_at text DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.ordre_travail OWNER TO gmao_app_user;

--
-- TOC entry 235 (class 1259 OID 16539)
-- Name: ordre_travail_id_ot_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.ordre_travail_id_ot_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ordre_travail_id_ot_seq OWNER TO gmao_app_user;

--
-- TOC entry 4474 (class 0 OID 0)
-- Dependencies: 235
-- Name: ordre_travail_id_ot_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.ordre_travail_id_ot_seq OWNED BY public.ordre_travail.id_ot;


--
-- TOC entry 345 (class 1259 OID 20130)
-- Name: ot_actifs; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.ot_actifs AS
 SELECT id_ot,
    numero_ot,
    machine_id,
    gamme_id,
    type,
    description,
    date_creation,
    date_prevue,
    duree_prevue_min,
    priorite,
    urgence,
    statut,
    technicien_assigne_id,
    utilisateur_createur_id,
    notes_planification,
    created_at,
    updated_at
   FROM public.ordre_travail
  WHERE (statut <> 'Archivé'::text)
  ORDER BY date_creation DESC;


ALTER VIEW public.ot_actifs OWNER TO gmao_app_user;

--
-- TOC entry 346 (class 1259 OID 20134)
-- Name: ot_complets; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.ot_complets AS
 SELECT id_ot,
    numero_ot,
    machine_id,
    gamme_id,
    type,
    description,
    date_creation,
    date_prevue,
    duree_prevue_min,
    priorite,
    urgence,
    statut,
    technicien_assigne_id,
    utilisateur_createur_id,
    notes_planification,
    created_at,
    updated_at,
        CASE
            WHEN (statut = 'Archivé'::text) THEN true
            ELSE false
        END AS est_archive
   FROM public.ordre_travail
  ORDER BY date_creation DESC;


ALTER VIEW public.ot_complets OWNER TO gmao_app_user;

--
-- TOC entry 234 (class 1259 OID 16515)
-- Name: piece; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.piece (
    id_piece integer NOT NULL,
    reference text NOT NULL,
    nom text NOT NULL,
    fournisseur_pref_id integer,
    prix_unitaire double precision DEFAULT 0.0,
    stock_alerte integer DEFAULT 0,
    stock_actuel integer DEFAULT 0,
    stock_reserve integer DEFAULT 0,
    unite text NOT NULL,
    categorie text,
    emplacement_stockage text,
    statut text DEFAULT 'Actif'::text,
    updated_at text,
    CONSTRAINT piece_prix_unitaire_check CHECK ((prix_unitaire >= (0)::double precision)),
    CONSTRAINT piece_stock_actuel_check CHECK ((stock_actuel >= 0)),
    CONSTRAINT piece_stock_alerte_check CHECK ((stock_alerte >= 0)),
    CONSTRAINT piece_stock_reserve_check CHECK ((stock_reserve >= 0))
);


ALTER TABLE public.piece OWNER TO gmao_app_user;

--
-- TOC entry 260 (class 1259 OID 16896)
-- Name: piece_category; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.piece_category (
    id integer NOT NULL,
    nom character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.piece_category OWNER TO gmao_app_user;

--
-- TOC entry 259 (class 1259 OID 16895)
-- Name: piece_category_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.piece_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.piece_category_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4475 (class 0 OID 0)
-- Dependencies: 259
-- Name: piece_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.piece_category_id_seq OWNED BY public.piece_category.id;


--
-- TOC entry 267 (class 1259 OID 16936)
-- Name: piece_extension; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.piece_extension (
    id_piece integer NOT NULL,
    unite_id integer,
    categorie_id integer,
    emplacement_id integer,
    statut_id integer,
    machine_id integer
);


ALTER TABLE public.piece_extension OWNER TO gmao_app_user;

--
-- TOC entry 317 (class 1259 OID 19147)
-- Name: piece_fournisseur_info; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.piece_fournisseur_info (
    id_piece_fournisseur_info integer NOT NULL,
    piece_id integer NOT NULL,
    fournisseur_id integer NOT NULL,
    reference_fournisseur character varying(100),
    prix_catalogue_fournisseur numeric(12,4),
    devise_prix_catalogue character varying(10) DEFAULT 'EUR'::character varying,
    delai_livraison_standard_j integer,
    unite_achat_fournisseur character varying(50),
    quantite_min_commande integer,
    dernier_prix_negocie numeric(12,4),
    date_dernier_prix_negocie date,
    commentaire text,
    actif boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.piece_fournisseur_info OWNER TO gmao_app_user;

--
-- TOC entry 4476 (class 0 OID 0)
-- Dependencies: 317
-- Name: TABLE piece_fournisseur_info; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.piece_fournisseur_info IS 'Informations spécifiques d''une pièce pour un fournisseur donné (réf. fournisseur, prix catalogue, etc.).';


--
-- TOC entry 4477 (class 0 OID 0)
-- Dependencies: 317
-- Name: COLUMN piece_fournisseur_info.reference_fournisseur; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.piece_fournisseur_info.reference_fournisseur IS 'Référence de l''article telle que connue par ce fournisseur.';


--
-- TOC entry 4478 (class 0 OID 0)
-- Dependencies: 317
-- Name: COLUMN piece_fournisseur_info.prix_catalogue_fournisseur; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.piece_fournisseur_info.prix_catalogue_fournisseur IS 'Prix catalogue HT de la pièce chez ce fournisseur, avant négociation.';


--
-- TOC entry 4479 (class 0 OID 0)
-- Dependencies: 317
-- Name: COLUMN piece_fournisseur_info.devise_prix_catalogue; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.piece_fournisseur_info.devise_prix_catalogue IS 'Devise du prix catalogue.';


--
-- TOC entry 316 (class 1259 OID 19146)
-- Name: piece_fournisseur_info_id_piece_fournisseur_info_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.piece_fournisseur_info_id_piece_fournisseur_info_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.piece_fournisseur_info_id_piece_fournisseur_info_seq OWNER TO gmao_app_user;

--
-- TOC entry 4480 (class 0 OID 0)
-- Dependencies: 316
-- Name: piece_fournisseur_info_id_piece_fournisseur_info_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.piece_fournisseur_info_id_piece_fournisseur_info_seq OWNED BY public.piece_fournisseur_info.id_piece_fournisseur_info;


--
-- TOC entry 233 (class 1259 OID 16514)
-- Name: piece_id_piece_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.piece_id_piece_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.piece_id_piece_seq OWNER TO gmao_app_user;

--
-- TOC entry 4481 (class 0 OID 0)
-- Dependencies: 233
-- Name: piece_id_piece_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.piece_id_piece_seq OWNED BY public.piece.id_piece;


--
-- TOC entry 264 (class 1259 OID 16916)
-- Name: piece_statut; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.piece_statut (
    id integer NOT NULL,
    nom character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.piece_statut OWNER TO gmao_app_user;

--
-- TOC entry 263 (class 1259 OID 16915)
-- Name: piece_statut_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.piece_statut_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.piece_statut_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4482 (class 0 OID 0)
-- Dependencies: 263
-- Name: piece_statut_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.piece_statut_id_seq OWNED BY public.piece_statut.id;


--
-- TOC entry 262 (class 1259 OID 16906)
-- Name: piece_unit; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.piece_unit (
    id integer NOT NULL,
    nom character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.piece_unit OWNER TO gmao_app_user;

--
-- TOC entry 261 (class 1259 OID 16905)
-- Name: piece_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.piece_unit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.piece_unit_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4483 (class 0 OID 0)
-- Dependencies: 261
-- Name: piece_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.piece_unit_id_seq OWNED BY public.piece_unit.id;


--
-- TOC entry 325 (class 1259 OID 19852)
-- Name: prestation_achat; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.prestation_achat (
    id_prestation_achat integer NOT NULL,
    reference_prestation character varying(50),
    maintenance_id integer,
    description_besoin text NOT NULL,
    type_prestation public.type_prestation_enum NOT NULL,
    statut_prestation public.statut_prestation_enum DEFAULT 'DEMANDE_INITIALE'::public.statut_prestation_enum NOT NULL,
    urgence boolean DEFAULT false,
    demandeur_maintenance_id integer,
    date_demande timestamp with time zone DEFAULT now(),
    acheteur_responsable_id integer,
    sous_contrat boolean DEFAULT false,
    contrat_achat_id integer,
    reference_contrat_fournisseur text,
    fournisseur_id integer,
    contact_fournisseur_prestation text,
    montant_estime_demande numeric(12,2),
    devise_estimation character(3) DEFAULT 'EUR'::bpchar,
    commande_initiale_id integer,
    description_travaux_reels text,
    montant_facture_final numeric(12,2),
    devise_facture character(3),
    reference_facture_fournisseur text,
    date_reception_facture date,
    notes_facturation text,
    necessite_regularisation boolean DEFAULT false,
    commande_regularisation_id integer,
    montant_regularisation_calcule numeric(12,2),
    notes_generales text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.prestation_achat OWNER TO gmao_app_user;

--
-- TOC entry 324 (class 1259 OID 19851)
-- Name: prestation_achat_id_prestation_achat_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.prestation_achat_id_prestation_achat_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.prestation_achat_id_prestation_achat_seq OWNER TO gmao_app_user;

--
-- TOC entry 4484 (class 0 OID 0)
-- Dependencies: 324
-- Name: prestation_achat_id_prestation_achat_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.prestation_achat_id_prestation_achat_seq OWNED BY public.prestation_achat.id_prestation_achat;


--
-- TOC entry 321 (class 1259 OID 19702)
-- Name: purchased_items; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.purchased_items (
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying,
    purchase_order_price double precision NOT NULL,
    actual_price double precision NOT NULL,
    order_id integer
);


ALTER TABLE public.purchased_items OWNER TO gmao_app_user;

--
-- TOC entry 320 (class 1259 OID 19701)
-- Name: purchased_items_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.purchased_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.purchased_items_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4485 (class 0 OID 0)
-- Dependencies: 320
-- Name: purchased_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.purchased_items_id_seq OWNED BY public.purchased_items.id;


--
-- TOC entry 276 (class 1259 OID 17139)
-- Name: reception_detail; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.reception_detail (
    id_reception integer NOT NULL,
    ligne_commande_id integer NOT NULL,
    date_reception timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    quantite_recue integer NOT NULL,
    quantite_defectueuse integer DEFAULT 0,
    utilisateur_id integer,
    commentaire text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reception_detail_quantite_defectueuse_check CHECK ((quantite_defectueuse >= 0)),
    CONSTRAINT reception_detail_quantite_recue_check CHECK ((quantite_recue >= 0))
);


ALTER TABLE public.reception_detail OWNER TO gmao_app_user;

--
-- TOC entry 4486 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE reception_detail; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON TABLE public.reception_detail IS 'Historique détaillé des réceptions pour chaque ligne de commande';


--
-- TOC entry 4487 (class 0 OID 0)
-- Dependencies: 276
-- Name: COLUMN reception_detail.quantite_recue; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.reception_detail.quantite_recue IS 'Quantité reçue en bon état lors de cette réception';


--
-- TOC entry 4488 (class 0 OID 0)
-- Dependencies: 276
-- Name: COLUMN reception_detail.quantite_defectueuse; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON COLUMN public.reception_detail.quantite_defectueuse IS 'Quantité reçue défectueuse lors de cette réception';


--
-- TOC entry 275 (class 1259 OID 17138)
-- Name: reception_detail_id_reception_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.reception_detail_id_reception_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reception_detail_id_reception_seq OWNER TO gmao_app_user;

--
-- TOC entry 4489 (class 0 OID 0)
-- Dependencies: 275
-- Name: reception_detail_id_reception_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.reception_detail_id_reception_seq OWNED BY public.reception_detail.id_reception;


--
-- TOC entry 218 (class 1259 OID 16393)
-- Name: site; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.site (
    id_site integer NOT NULL,
    nom text NOT NULL,
    adresse text,
    ville text,
    pays text,
    contact_principal text
);


ALTER TABLE public.site OWNER TO gmao_app_user;

--
-- TOC entry 217 (class 1259 OID 16392)
-- Name: site_id_site_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.site_id_site_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.site_id_site_seq OWNER TO gmao_app_user;

--
-- TOC entry 4490 (class 0 OID 0)
-- Dependencies: 217
-- Name: site_id_site_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.site_id_site_seq OWNED BY public.site.id_site;


--
-- TOC entry 293 (class 1259 OID 17334)
-- Name: stock_level; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.stock_level (
    id integer NOT NULL,
    article_id integer NOT NULL,
    magasin_id integer NOT NULL,
    emplacement_id integer,
    lot_serie_id integer,
    quantite numeric NOT NULL,
    CONSTRAINT stock_level_quantite_check CHECK ((quantite >= (0)::numeric))
);


ALTER TABLE public.stock_level OWNER TO gmao_app_user;

--
-- TOC entry 292 (class 1259 OID 17333)
-- Name: stock_level_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.stock_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stock_level_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4491 (class 0 OID 0)
-- Dependencies: 292
-- Name: stock_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.stock_level_id_seq OWNED BY public.stock_level.id;


--
-- TOC entry 287 (class 1259 OID 17265)
-- Name: stock_piece_extra; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.stock_piece_extra (
    id_piece integer NOT NULL,
    description text,
    is_batch_managed boolean DEFAULT false,
    is_serial_managed boolean DEFAULT false,
    machine_or_general_part text,
    machine_id integer,
    fabricant integer,
    site integer,
    alternative1 integer,
    alternative2 integer,
    alternative3 integer,
    rating smallint DEFAULT 3,
    CONSTRAINT stock_piece_extra_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.stock_piece_extra OWNER TO gmao_app_user;

--
-- TOC entry 224 (class 1259 OID 16426)
-- Name: technicien; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.technicien (
    id_technicien integer NOT NULL,
    nom text NOT NULL,
    prenom text,
    qualification text,
    contact text,
    cout_horaire double precision DEFAULT 0.0,
    equipe_id integer,
    actif integer DEFAULT 1
);


ALTER TABLE public.technicien OWNER TO gmao_app_user;

--
-- TOC entry 223 (class 1259 OID 16425)
-- Name: technicien_id_technicien_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.technicien_id_technicien_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.technicien_id_technicien_seq OWNER TO gmao_app_user;

--
-- TOC entry 4492 (class 0 OID 0)
-- Dependencies: 223
-- Name: technicien_id_technicien_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.technicien_id_technicien_seq OWNED BY public.technicien.id_technicien;


--
-- TOC entry 222 (class 1259 OID 16415)
-- Name: type_machine; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.type_machine (
    id_type_machine integer NOT NULL,
    nom text NOT NULL,
    description text,
    categorie text
);


ALTER TABLE public.type_machine OWNER TO gmao_app_user;

--
-- TOC entry 221 (class 1259 OID 16414)
-- Name: type_machine_id_type_machine_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.type_machine_id_type_machine_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.type_machine_id_type_machine_seq OWNER TO gmao_app_user;

--
-- TOC entry 4493 (class 0 OID 0)
-- Dependencies: 221
-- Name: type_machine_id_type_machine_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.type_machine_id_type_machine_seq OWNED BY public.type_machine.id_type_machine;


--
-- TOC entry 271 (class 1259 OID 17003)
-- Name: type_mouvement; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.type_mouvement (
    id integer NOT NULL,
    nom character varying(50) NOT NULL,
    description text,
    impact_stock integer NOT NULL,
    actif boolean DEFAULT true,
    CONSTRAINT type_mouvement_impact_stock_check CHECK ((impact_stock = ANY (ARRAY['-1'::integer, 0, 1])))
);


ALTER TABLE public.type_mouvement OWNER TO gmao_app_user;

--
-- TOC entry 270 (class 1259 OID 17002)
-- Name: type_mouvement_id_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.type_mouvement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.type_mouvement_id_seq OWNER TO gmao_app_user;

--
-- TOC entry 4494 (class 0 OID 0)
-- Dependencies: 270
-- Name: type_mouvement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.type_mouvement_id_seq OWNED BY public.type_mouvement.id;


--
-- TOC entry 228 (class 1259 OID 16448)
-- Name: utilisateur; Type: TABLE; Schema: public; Owner: gmao_app_user
--

CREATE TABLE public.utilisateur (
    id_utilisateur integer NOT NULL,
    login text NOT NULL,
    mot_de_passe_hash text NOT NULL,
    nom_complet text,
    role text NOT NULL,
    email text,
    actif integer DEFAULT 1,
    derniere_connexion text,
    technicien_id integer,
    created_at text DEFAULT CURRENT_TIMESTAMP,
    updated_at text DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.utilisateur OWNER TO gmao_app_user;

--
-- TOC entry 227 (class 1259 OID 16447)
-- Name: utilisateur_id_utilisateur_seq; Type: SEQUENCE; Schema: public; Owner: gmao_app_user
--

CREATE SEQUENCE public.utilisateur_id_utilisateur_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.utilisateur_id_utilisateur_seq OWNER TO gmao_app_user;

--
-- TOC entry 4495 (class 0 OID 0)
-- Dependencies: 227
-- Name: utilisateur_id_utilisateur_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: gmao_app_user
--

ALTER SEQUENCE public.utilisateur_id_utilisateur_seq OWNED BY public.utilisateur.id_utilisateur;


--
-- TOC entry 302 (class 1259 OID 17525)
-- Name: v_dashboard_reception; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_dashboard_reception AS
 SELECT 'LOTS_EN_RECEPTION'::text AS indicateur,
    count(*) AS valeur,
    'Lots en cours de réception'::text AS description
   FROM public.lot_reception
  WHERE ((lot_reception.statut_lot)::text = 'EN_RECEPTION'::text)
UNION ALL
 SELECT 'LOTS_PRET_STOCKAGE'::text AS indicateur,
    count(*) AS valeur,
    'Lots prêts pour stockage'::text AS description
   FROM public.lot_reception
  WHERE ((lot_reception.statut_lot)::text = 'PRET_STOCKAGE'::text)
UNION ALL
 SELECT 'MOUVEMENTS_EN_ATTENTE'::text AS indicateur,
    count(*) AS valeur,
    'Mouvements en attente de confirmation'::text AS description
   FROM public.mouvement_stock
  WHERE (((mouvement_stock.statut_mouvement)::text = 'EN_ATTENTE'::text) AND (mouvement_stock.valide = true))
UNION ALL
 SELECT 'QUANTITE_EN_RECEPTION'::text AS indicateur,
    COALESCE(sum(lot_reception.quantite_restante), (0)::bigint) AS valeur,
    'Quantité totale en attente de stockage'::text AS description
   FROM public.lot_reception
  WHERE (lot_reception.quantite_restante > 0);


ALTER VIEW public.v_dashboard_reception OWNER TO gmao_app_user;

--
-- TOC entry 284 (class 1259 OID 17244)
-- Name: v_emplacement_capacite; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_emplacement_capacite AS
 SELECT e.id,
    e.nom,
    e.type,
    ext.volume_cm3,
    ext.capacite_max_kg,
    COALESCE(sum(es.quantite), (0)::bigint) AS stock_actuel,
        CASE
            WHEN ((ext.capacite_max_kg IS NOT NULL) AND (ext.capacite_max_kg > (0)::numeric)) THEN round((((COALESCE(sum(es.quantite), (0)::bigint))::numeric / ext.capacite_max_kg) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS taux_remplissage_pct,
        CASE
            WHEN (ext.capacite_max_kg IS NOT NULL) THEN (ext.capacite_max_kg - (COALESCE(sum(es.quantite), (0)::bigint))::numeric)
            ELSE NULL::numeric
        END AS capacite_restante
   FROM ((public.emplacement e
     LEFT JOIN public.emplacement_ext ext ON ((e.id = ext.emplacement_id)))
     LEFT JOIN public.emplacement_stock es ON (((e.id = es.emplacement_id) AND (es.quantite > 0))))
  GROUP BY e.id, e.nom, e.type, ext.volume_cm3, ext.capacite_max_kg
  ORDER BY e.nom;


ALTER VIEW public.v_emplacement_capacite OWNER TO gmao_app_user;

--
-- TOC entry 282 (class 1259 OID 17234)
-- Name: v_emplacement_detail; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_emplacement_detail AS
 SELECT e.id,
    e.nom,
    e.type,
    e.allee,
    e.etagere,
    e.niveau,
    ext.longueur_cm,
    ext.hauteur_cm,
    ext.profondeur_cm,
    ext.volume_cm3,
    ext.capacite_max_kg,
    ext.temperature_min_c,
    ext.temperature_max_c,
    ext.humidite_max_pct,
    ext.conditions_speciales,
    COALESCE(stock_info.nb_pieces_differentes, (0)::bigint) AS nb_pieces_differentes,
    COALESCE(stock_info.quantite_totale, (0)::bigint) AS quantite_totale,
        CASE
            WHEN ((ext.capacite_max_kg IS NOT NULL) AND (stock_info.quantite_totale > 0)) THEN round((((stock_info.quantite_totale)::numeric / ext.capacite_max_kg) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS taux_occupation_pct
   FROM ((public.emplacement e
     LEFT JOIN public.emplacement_ext ext ON ((e.id = ext.emplacement_id)))
     LEFT JOIN ( SELECT emplacement_stock.emplacement_id,
            count(*) AS nb_pieces_differentes,
            sum(emplacement_stock.quantite) AS quantite_totale
           FROM public.emplacement_stock
          WHERE (emplacement_stock.quantite > 0)
          GROUP BY emplacement_stock.emplacement_id) stock_info ON ((e.id = stock_info.emplacement_id)));


ALTER VIEW public.v_emplacement_detail OWNER TO gmao_app_user;

--
-- TOC entry 303 (class 1259 OID 17556)
-- Name: v_historique_mouvements; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_historique_mouvements AS
 SELECT ms.id,
    ms.date_mouvement,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    tm.nom AS type_mouvement,
    tm.impact_stock,
    ms.quantite,
    ms.stock_avant,
    ms.stock_apres,
    ms.statut_mouvement,
    es.nom AS emplacement_source,
    ed.nom AS emplacement_destination,
    u.nom_complet AS utilisateur,
    ms.reference_document,
    ms.commentaire,
    ms.cout_unitaire,
    ms.cout_total
   FROM (((((public.mouvement_stock ms
     JOIN public.piece p ON ((ms.piece_id = p.id_piece)))
     JOIN public.type_mouvement tm ON ((ms.type_mouvement_id = tm.id)))
     LEFT JOIN public.emplacement es ON ((ms.emplacement_source_id = es.id)))
     LEFT JOIN public.emplacement ed ON ((ms.emplacement_destination_id = ed.id)))
     LEFT JOIN public.utilisateur u ON ((ms.utilisateur_id = u.id_utilisateur)))
  WHERE (ms.valide = true)
  ORDER BY ms.date_mouvement DESC;


ALTER VIEW public.v_historique_mouvements OWNER TO gmao_app_user;

--
-- TOC entry 278 (class 1259 OID 17170)
-- Name: v_historique_receptions; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_historique_receptions AS
 SELECT rd.id_reception,
    rd.date_reception,
    lc.commande_id,
    c.numero_commande,
    lc.piece_id,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    rd.quantite_recue,
    rd.quantite_defectueuse,
    rd.commentaire,
    u.nom_complet AS receptionnaire
   FROM ((((public.reception_detail rd
     JOIN public.ligne_commande lc ON ((rd.ligne_commande_id = lc.id_ligne)))
     JOIN public.commande c ON ((lc.commande_id = c.id_commande)))
     LEFT JOIN public.piece p ON ((lc.piece_id = p.id_piece)))
     LEFT JOIN public.utilisateur u ON ((rd.utilisateur_id = u.id_utilisateur)))
  ORDER BY rd.date_reception DESC;


ALTER VIEW public.v_historique_receptions OWNER TO gmao_app_user;

--
-- TOC entry 4496 (class 0 OID 0)
-- Dependencies: 278
-- Name: VIEW v_historique_receptions; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON VIEW public.v_historique_receptions IS 'Historique complet de toutes les réceptions';


--
-- TOC entry 347 (class 1259 OID 20144)
-- Name: v_maintenance_couts_detaille; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_maintenance_couts_detaille AS
 SELECT m.id_maintenance,
    m.ot_id,
    m.date_debut_reelle,
    m.date_fin_reelle,
    m.duree_intervention_h,
    m.type_reel,
    m.description_travaux,
    m.resultat,
    COALESCE(m.cout_main_oeuvre, (0)::double precision) AS cout_main_oeuvre,
    COALESCE(m.cout_pieces_internes, (0)::double precision) AS cout_pieces_internes,
    COALESCE(m.cout_pieces_externes, (0)::double precision) AS cout_pieces_externes,
    COALESCE(m.cout_autres_frais, (0)::double precision) AS cout_autres_frais,
    COALESCE(m.cout_total, (0)::double precision) AS cout_total,
    mach.id_machine,
    mach.nom AS machine_nom,
    mach.serial AS machine_serial,
    mach.etat AS machine_etat,
    mach.criticite AS machine_criticite,
    mach.localisation AS machine_localisation,
    mach.date_installation,
    s.id_site,
    s.nom AS site_nom,
    s.ville AS site_ville,
    s.pays AS site_pays,
    tm.id_type_machine,
    tm.categorie AS type_categorie,
    tm.nom AS type_nom,
    tm.description AS type_description,
    f.id_fabricant,
    f.nom AS fabricant_nom,
    t.id_technicien,
    t.nom AS technicien_nom,
    t.prenom AS technicien_prenom,
    concat(COALESCE(t.prenom, ''::text), ' ', t.nom) AS technicien_nom_complet,
    t.qualification AS technicien_qualification,
    t.cout_horaire AS technicien_cout_horaire,
    e.id_equipe,
    e.nom AS equipe_nom,
    e.domaine_expertise AS equipe_domaine,
    EXTRACT(year FROM (m.date_fin_reelle)::date) AS annee,
    EXTRACT(month FROM (m.date_fin_reelle)::date) AS mois,
    to_char(((m.date_fin_reelle)::date)::timestamp with time zone, 'YYYY-MM'::text) AS periode_mois,
    to_char(((m.date_fin_reelle)::date)::timestamp with time zone, 'YYYY-Q'::text) AS periode_trimestre,
    to_char(((m.date_fin_reelle)::date)::timestamp with time zone, 'YYYY-MM-DD'::text) AS jour,
        CASE
            WHEN (m.duree_intervention_h > (0)::double precision) THEN (m.cout_total / m.duree_intervention_h)
            ELSE (0)::double precision
        END AS cout_par_heure,
        CASE
            WHEN (m.cout_total > (0)::double precision) THEN ((m.cout_main_oeuvre / m.cout_total) * (100)::double precision)
            ELSE (0)::double precision
        END AS pourcentage_mod,
        CASE
            WHEN (m.cout_total > (0)::double precision) THEN ((m.cout_pieces_internes / m.cout_total) * (100)::double precision)
            ELSE (0)::double precision
        END AS pourcentage_pieces,
        CASE
            WHEN (m.cout_total > (0)::double precision) THEN (((m.cout_pieces_externes + m.cout_autres_frais) / m.cout_total) * (100)::double precision)
            ELSE (0)::double precision
        END AS pourcentage_frais_externes
   FROM ((((((public.maintenance m
     LEFT JOIN public.machine mach ON ((m.machine_id = mach.id_machine)))
     LEFT JOIN public.site s ON ((mach.site_id = s.id_site)))
     LEFT JOIN public.type_machine tm ON ((mach.type_machine_id = tm.id_type_machine)))
     LEFT JOIN public.fabricant f ON ((mach.fabricant_id = f.id_fabricant)))
     LEFT JOIN public.technicien t ON ((m.technicien_id = t.id_technicien)))
     LEFT JOIN public.equipe e ON ((t.equipe_id = e.id_equipe)))
  WHERE ((m.date_fin_reelle IS NOT NULL) AND (m.cout_total IS NOT NULL));


ALTER VIEW public.v_maintenance_couts_detaille OWNER TO gmao_app_user;

--
-- TOC entry 348 (class 1259 OID 20161)
-- Name: v_kpi_machine_jour; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_kpi_machine_jour AS
 SELECT id_machine,
    machine_nom,
    machine_serial,
    machine_criticite,
    site_nom,
    type_nom,
    type_categorie,
    equipe_nom,
    jour,
    EXTRACT(year FROM (jour)::date) AS annee,
    EXTRACT(month FROM (jour)::date) AS mois,
    count(*) AS nb_interventions,
    count(
        CASE
            WHEN (type_reel = 'Preventif'::text) THEN 1
            ELSE NULL::integer
        END) AS nb_preventif,
    count(
        CASE
            WHEN (type_reel = 'Correctif'::text) THEN 1
            ELSE NULL::integer
        END) AS nb_correctif,
    count(
        CASE
            WHEN (type_reel = 'Urgence'::text) THEN 1
            ELSE NULL::integer
        END) AS nb_urgence,
    sum(cout_total) AS cout_total_jour,
    sum(cout_main_oeuvre) AS cout_mod_jour,
    sum(cout_pieces_internes) AS cout_pieces_jour,
    sum((cout_pieces_externes + cout_autres_frais)) AS cout_frais_externes_jour,
    avg(cout_total) AS cout_moyen_intervention,
    sum(duree_intervention_h) AS duree_totale,
    avg(duree_intervention_h) AS duree_moyenne_h,
    avg(cout_par_heure) AS cout_moyen_par_heure,
    min(cout_total) AS cout_min,
    max(cout_total) AS cout_max,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY cout_total) AS cout_median,
    avg(pourcentage_mod) AS pourcentage_moyen_mod,
    avg(pourcentage_pieces) AS pourcentage_moyen_pieces,
    avg(pourcentage_frais_externes) AS pourcentage_moyen_frais_externes,
        CASE
            WHEN (count(
            CASE
                WHEN (type_reel = ANY (ARRAY['Correctif'::text, 'Urgence'::text])) THEN 1
                ELSE NULL::integer
            END) > 0) THEN ((count(
            CASE
                WHEN (type_reel = 'Preventif'::text) THEN 1
                ELSE NULL::integer
            END))::double precision / (count(
            CASE
                WHEN (type_reel = ANY (ARRAY['Correctif'::text, 'Urgence'::text])) THEN 1
                ELSE NULL::integer
            END))::double precision)
            ELSE (0)::double precision
        END AS ratio_preventif_curatif
   FROM public.v_maintenance_couts_detaille
  GROUP BY id_machine, machine_nom, machine_serial, machine_criticite, site_nom, type_nom, type_categorie, equipe_nom, jour
  ORDER BY jour DESC, (sum(cout_total)) DESC;


ALTER VIEW public.v_kpi_machine_jour OWNER TO gmao_app_user;

--
-- TOC entry 298 (class 1259 OID 17493)
-- Name: v_lots_reception; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_lots_reception AS
 SELECT lr.id,
    lr.numero_lot,
    lr.commande_id,
    c.numero_commande,
    lr.piece_id,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    lr.quantite_recue,
    lr.quantite_mise_en_stock,
    lr.quantite_restante,
    lr.statut_lot,
    lr.date_reception,
    lr.date_mise_en_stock,
    er.nom AS emplacement_reception,
    lr.bon_etat,
    lr.commentaire_reception,
    ur.login AS utilisateur_reception,
    us.login AS utilisateur_stockage
   FROM (((((public.lot_reception lr
     JOIN public.piece p ON ((lr.piece_id = p.id_piece)))
     LEFT JOIN public.commande c ON ((lr.commande_id = c.id_commande)))
     LEFT JOIN public.emplacement er ON ((lr.emplacement_reception_id = er.id)))
     LEFT JOIN public.utilisateur ur ON ((lr.utilisateur_reception_id = ur.id_utilisateur)))
     LEFT JOIN public.utilisateur us ON ((lr.utilisateur_stockage_id = us.id_utilisateur)))
  ORDER BY lr.date_reception DESC;


ALTER VIEW public.v_lots_reception OWNER TO gmao_app_user;

--
-- TOC entry 300 (class 1259 OID 17503)
-- Name: v_mise_en_stock_detail; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_mise_en_stock_detail AS
 SELECT msd.id,
    lr.numero_lot,
    lr.piece_id,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    msd.quantite_stockee,
    ed.nom AS emplacement_destination,
    msd.date_stockage,
    u.login AS utilisateur,
    msd.commentaire,
    ms.id AS mouvement_stock_id
   FROM (((((public.mise_en_stock_detail msd
     JOIN public.lot_reception lr ON ((msd.lot_reception_id = lr.id)))
     JOIN public.piece p ON ((lr.piece_id = p.id_piece)))
     JOIN public.emplacement ed ON ((msd.emplacement_destination_id = ed.id)))
     LEFT JOIN public.utilisateur u ON ((msd.utilisateur_id = u.id_utilisateur)))
     LEFT JOIN public.mouvement_stock ms ON ((msd.mouvement_stock_id = ms.id)))
  ORDER BY msd.date_stockage DESC;


ALTER VIEW public.v_mise_en_stock_detail OWNER TO gmao_app_user;

--
-- TOC entry 274 (class 1259 OID 17121)
-- Name: v_mouvement_stats; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_mouvement_stats AS
 SELECT p.id_piece,
    p.reference,
    p.nom AS piece_nom,
    tm.nom AS type_mouvement,
    count(*) AS nb_mouvements,
    sum(ms.quantite) AS quantite_totale,
    sum(ms.cout_total) AS cout_total,
    min(ms.date_mouvement) AS premier_mouvement,
    max(ms.date_mouvement) AS dernier_mouvement
   FROM ((public.mouvement_stock ms
     JOIN public.piece p ON ((ms.piece_id = p.id_piece)))
     JOIN public.type_mouvement tm ON ((ms.type_mouvement_id = tm.id)))
  WHERE (ms.valide = true)
  GROUP BY p.id_piece, p.reference, p.nom, tm.id, tm.nom;


ALTER VIEW public.v_mouvement_stats OWNER TO gmao_app_user;

--
-- TOC entry 301 (class 1259 OID 17518)
-- Name: v_mouvements_en_attente; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_mouvements_en_attente AS
 SELECT ms.id,
    ms.date_mouvement,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    tm.nom AS type_mouvement,
    tm.impact_stock,
    ms.quantite,
    ms.statut_mouvement,
    es.nom AS emplacement_source,
    ed.nom AS emplacement_destination,
    u.nom_complet AS utilisateur,
    ms.reference_document,
    ms.commentaire,
    (EXTRACT(epoch FROM (now() - (ms.date_mouvement)::timestamp with time zone)) / (3600)::numeric) AS heures_en_attente
   FROM (((((public.mouvement_stock ms
     JOIN public.piece p ON ((ms.piece_id = p.id_piece)))
     JOIN public.type_mouvement tm ON ((ms.type_mouvement_id = tm.id)))
     LEFT JOIN public.emplacement es ON ((ms.emplacement_source_id = es.id)))
     LEFT JOIN public.emplacement ed ON ((ms.emplacement_destination_id = ed.id)))
     LEFT JOIN public.utilisateur u ON ((ms.utilisateur_id = u.id_utilisateur)))
  WHERE ((ms.valide = true) AND ((ms.statut_mouvement)::text = 'EN_ATTENTE'::text))
  ORDER BY ms.date_mouvement;


ALTER VIEW public.v_mouvements_en_attente OWNER TO gmao_app_user;

--
-- TOC entry 4497 (class 0 OID 0)
-- Dependencies: 301
-- Name: VIEW v_mouvements_en_attente; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON VIEW public.v_mouvements_en_attente IS 'Vue des mouvements en attente de confirmation avec calcul du temps d''attente';


--
-- TOC entry 277 (class 1259 OID 17165)
-- Name: v_reception_lignes; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_reception_lignes AS
 SELECT lc.id_ligne,
    lc.commande_id,
    c.numero_commande,
    lc.piece_id,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    lc.description_libre,
    lc.quantite_commandee,
    lc.quantite_recue,
    lc.quantite_defectueuse,
    lc.prix_unitaire_ht,
    lc.statut_ligne,
    lc.date_derniere_reception,
    lc.commentaire_reception,
    ((lc.quantite_commandee - lc.quantite_recue) - lc.quantite_defectueuse) AS quantite_restante,
        CASE
            WHEN ((lc.quantite_recue + lc.quantite_defectueuse) >= lc.quantite_commandee) THEN 'Complete'::text
            WHEN ((lc.quantite_recue + lc.quantite_defectueuse) > 0) THEN 'Partielle'::text
            ELSE 'Attente'::text
        END AS statut_calcule
   FROM ((public.ligne_commande lc
     JOIN public.commande c ON ((lc.commande_id = c.id_commande)))
     LEFT JOIN public.piece p ON ((lc.piece_id = p.id_piece)));


ALTER VIEW public.v_reception_lignes OWNER TO gmao_app_user;

--
-- TOC entry 4498 (class 0 OID 0)
-- Dependencies: 277
-- Name: VIEW v_reception_lignes; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON VIEW public.v_reception_lignes IS 'Vue consolidée des lignes de commande avec statut de réception';


--
-- TOC entry 283 (class 1259 OID 17239)
-- Name: v_stock_par_emplacement; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_stock_par_emplacement AS
 SELECT e.id AS emplacement_id,
    e.nom AS emplacement_nom,
    e.type AS emplacement_type,
    e.allee,
    e.etagere,
    e.niveau,
    p.id_piece,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    p.categorie AS piece_categorie,
    es.quantite,
    es.date_derniere_entree,
    es.date_derniere_sortie,
    es.date_derniere_maj,
    es.commentaire,
    p.stock_actuel AS stock_total_piece,
        CASE
            WHEN (p.stock_actuel > 0) THEN round((((es.quantite)::numeric / (p.stock_actuel)::numeric) * (100)::numeric), 2)
            ELSE (0)::numeric
        END AS pourcentage_piece_dans_emplacement
   FROM ((public.emplacement e
     JOIN public.emplacement_stock es ON ((e.id = es.emplacement_id)))
     JOIN public.piece p ON ((es.piece_id = p.id_piece)))
  WHERE (es.quantite > 0)
  ORDER BY e.nom, p.reference;


ALTER VIEW public.v_stock_par_emplacement OWNER TO gmao_app_user;

--
-- TOC entry 299 (class 1259 OID 17498)
-- Name: v_stock_reception; Type: VIEW; Schema: public; Owner: gmao_app_user
--

CREATE VIEW public.v_stock_reception AS
 SELECT lr.piece_id,
    p.reference AS piece_reference,
    p.nom AS piece_nom,
    sum(lr.quantite_restante) AS quantite_en_reception,
    count(*) AS nb_lots,
    min(lr.date_reception) AS plus_ancienne_reception,
    max(lr.date_reception) AS plus_recente_reception
   FROM (public.lot_reception lr
     JOIN public.piece p ON ((lr.piece_id = p.id_piece)))
  WHERE (lr.quantite_restante > 0)
  GROUP BY lr.piece_id, p.reference, p.nom
  ORDER BY (min(lr.date_reception));


ALTER VIEW public.v_stock_reception OWNER TO gmao_app_user;

--
-- TOC entry 4499 (class 0 OID 0)
-- Dependencies: 299
-- Name: VIEW v_stock_reception; Type: COMMENT; Schema: public; Owner: gmao_app_user
--

COMMENT ON VIEW public.v_stock_reception IS 'Vue du stock en attente de mise en stock dans la zone de réception';


--
-- TOC entry 3786 (class 2604 OID 19086)
-- Name: ao_fournisseur_consulte id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ao_fournisseur_consulte ALTER COLUMN id SET DEFAULT nextval('public.ao_fournisseur_consulte_id_seq'::regclass);


--
-- TOC entry 3783 (class 2604 OID 19063)
-- Name: appel_offre id_ao; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.appel_offre ALTER COLUMN id_ao SET DEFAULT nextval('public.appel_offre_id_ao_seq'::regclass);


--
-- TOC entry 3704 (class 2604 OID 16710)
-- Name: commande id_commande; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.commande ALTER COLUMN id_commande SET DEFAULT nextval('public.commande_id_commande_seq'::regclass);


--
-- TOC entry 3714 (class 2604 OID 16762)
-- Name: compteur id_compteur; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.compteur ALTER COLUMN id_compteur SET DEFAULT nextval('public.compteur_id_compteur_seq'::regclass);


--
-- TOC entry 3798 (class 2604 OID 19827)
-- Name: contrat_achat id_contrat_achat; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.contrat_achat ALTER COLUMN id_contrat_achat SET DEFAULT nextval('public.contrat_achat_id_contrat_achat_seq'::regclass);


--
-- TOC entry 3779 (class 2604 OID 19021)
-- Name: demandes_achat id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat ALTER COLUMN id SET DEFAULT nextval('public.demandes_achat_id_seq'::regclass);


--
-- TOC entry 3782 (class 2604 OID 19037)
-- Name: demandes_achat_lignes id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat_lignes ALTER COLUMN id SET DEFAULT nextval('public.demandes_achat_lignes_id_seq'::regclass);


--
-- TOC entry 3728 (class 2604 OID 16929)
-- Name: emplacement id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement ALTER COLUMN id SET DEFAULT nextval('public.emplacement_id_seq'::regclass);


--
-- TOC entry 3750 (class 2604 OID 17201)
-- Name: emplacement_stock id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_stock ALTER COLUMN id SET DEFAULT nextval('public.emplacement_stock_id_seq'::regclass);


--
-- TOC entry 3667 (class 2604 OID 16440)
-- Name: equipe id_equipe; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.equipe ALTER COLUMN id_equipe SET DEFAULT nextval('public.equipe_id_equipe_seq'::regclass);


--
-- TOC entry 3662 (class 2604 OID 16407)
-- Name: fabricant id_fabricant; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.fabricant ALTER COLUMN id_fabricant SET DEFAULT nextval('public.fabricant_id_fabricant_seq'::regclass);


--
-- TOC entry 3676 (class 2604 OID 16506)
-- Name: fournisseur id_fournisseur; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.fournisseur ALTER COLUMN id_fournisseur SET DEFAULT nextval('public.fournisseur_id_fournisseur_seq'::regclass);


--
-- TOC entry 3697 (class 2604 OID 16651)
-- Name: gamme_entretien id_gamme; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_entretien ALTER COLUMN id_gamme SET DEFAULT nextval('public.gamme_entretien_id_gamme_seq'::regclass);


--
-- TOC entry 3701 (class 2604 OID 16675)
-- Name: gamme_etape id_etape; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_etape ALTER COLUMN id_etape SET DEFAULT nextval('public.gamme_etape_id_etape_seq'::regclass);


--
-- TOC entry 3702 (class 2604 OID 16689)
-- Name: gamme_piece_type id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_piece_type ALTER COLUMN id SET DEFAULT nextval('public.gamme_piece_type_id_seq'::regclass);


--
-- TOC entry 3718 (class 2604 OID 16781)
-- Name: historique_compteur id_historique; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.historique_compteur ALTER COLUMN id_historique SET DEFAULT nextval('public.historique_compteur_id_historique_seq'::regclass);


--
-- TOC entry 3696 (class 2604 OID 16605)
-- Name: intervention_piece id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.intervention_piece ALTER COLUMN id SET DEFAULT nextval('public.intervention_piece_id_seq'::regclass);


--
-- TOC entry 3753 (class 2604 OID 17256)
-- Name: inventory_users id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.inventory_users ALTER COLUMN id SET DEFAULT nextval('public.inventory_users_id_seq'::regclass);


--
-- TOC entry 3729 (class 2604 OID 16982)
-- Name: inventory_warehouse id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_warehouse ALTER COLUMN id SET DEFAULT nextval('public.inventory_warehouse_id_seq'::regclass);


--
-- TOC entry 3759 (class 2604 OID 17310)
-- Name: inventory_warehouses id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.inventory_warehouses ALTER COLUMN id SET DEFAULT nextval('public.inventory_warehouses_id_seq'::regclass);


--
-- TOC entry 3710 (class 2604 OID 16737)
-- Name: ligne_commande id_ligne; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ligne_commande ALTER COLUMN id_ligne SET DEFAULT nextval('public.ligne_commande_id_ligne_seq'::regclass);


--
-- TOC entry 3768 (class 2604 OID 17403)
-- Name: lot_reception id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception ALTER COLUMN id SET DEFAULT nextval('public.lot_reception_id_seq'::regclass);


--
-- TOC entry 3766 (class 2604 OID 17321)
-- Name: lot_serie id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_serie ALTER COLUMN id SET DEFAULT nextval('public.lot_serie_id_seq'::regclass);


--
-- TOC entry 3672 (class 2604 OID 16472)
-- Name: machine id_machine; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine ALTER COLUMN id_machine SET DEFAULT nextval('public.machine_id_machine_seq'::regclass);


--
-- TOC entry 3689 (class 2604 OID 16573)
-- Name: maintenance id_maintenance; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance ALTER COLUMN id_maintenance SET DEFAULT nextval('public.maintenance_id_maintenance_seq'::regclass);


--
-- TOC entry 3722 (class 2604 OID 16829)
-- Name: maintenance_frais_externe id_frais; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_frais_externe ALTER COLUMN id_frais SET DEFAULT nextval('public.maintenance_frais_externe_id_frais_seq'::regclass);


--
-- TOC entry 3720 (class 2604 OID 16806)
-- Name: maintenance_intervenant id_intervenant; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_intervenant ALTER COLUMN id_intervenant SET DEFAULT nextval('public.maintenance_intervenant_id_intervenant_seq'::regclass);


--
-- TOC entry 3776 (class 2604 OID 17458)
-- Name: mise_en_stock_detail id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mise_en_stock_detail ALTER COLUMN id SET DEFAULT nextval('public.mise_en_stock_detail_id_seq'::regclass);


--
-- TOC entry 3736 (class 2604 OID 17078)
-- Name: mouvement_stock id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock ALTER COLUMN id SET DEFAULT nextval('public.mouvement_stock_id_seq'::regclass);


--
-- TOC entry 3788 (class 2604 OID 19106)
-- Name: offre_recue id_offre; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue ALTER COLUMN id_offre SET DEFAULT nextval('public.offre_recue_id_offre_seq'::regclass);


--
-- TOC entry 3790 (class 2604 OID 19128)
-- Name: offre_recue_ligne id_offre_ligne; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue_ligne ALTER COLUMN id_offre_ligne SET DEFAULT nextval('public.offre_recue_ligne_id_offre_ligne_seq'::regclass);


--
-- TOC entry 3796 (class 2604 OID 19695)
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- TOC entry 3684 (class 2604 OID 16543)
-- Name: ordre_travail id_ot; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ordre_travail ALTER COLUMN id_ot SET DEFAULT nextval('public.ordre_travail_id_ot_seq'::regclass);


--
-- TOC entry 3678 (class 2604 OID 16518)
-- Name: piece id_piece; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece ALTER COLUMN id_piece SET DEFAULT nextval('public.piece_id_piece_seq'::regclass);


--
-- TOC entry 3725 (class 2604 OID 16899)
-- Name: piece_category id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_category ALTER COLUMN id SET DEFAULT nextval('public.piece_category_id_seq'::regclass);


--
-- TOC entry 3792 (class 2604 OID 19150)
-- Name: piece_fournisseur_info id_piece_fournisseur_info; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_fournisseur_info ALTER COLUMN id_piece_fournisseur_info SET DEFAULT nextval('public.piece_fournisseur_info_id_piece_fournisseur_info_seq'::regclass);


--
-- TOC entry 3727 (class 2604 OID 16919)
-- Name: piece_statut id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_statut ALTER COLUMN id SET DEFAULT nextval('public.piece_statut_id_seq'::regclass);


--
-- TOC entry 3726 (class 2604 OID 16909)
-- Name: piece_unit id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_unit ALTER COLUMN id SET DEFAULT nextval('public.piece_unit_id_seq'::regclass);


--
-- TOC entry 3803 (class 2604 OID 19855)
-- Name: prestation_achat id_prestation_achat; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat ALTER COLUMN id_prestation_achat SET DEFAULT nextval('public.prestation_achat_id_prestation_achat_seq'::regclass);


--
-- TOC entry 3797 (class 2604 OID 19705)
-- Name: purchased_items id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.purchased_items ALTER COLUMN id SET DEFAULT nextval('public.purchased_items_id_seq'::regclass);


--
-- TOC entry 3742 (class 2604 OID 17142)
-- Name: reception_detail id_reception; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.reception_detail ALTER COLUMN id_reception SET DEFAULT nextval('public.reception_detail_id_reception_seq'::regclass);


--
-- TOC entry 3661 (class 2604 OID 16396)
-- Name: site id_site; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.site ALTER COLUMN id_site SET DEFAULT nextval('public.site_id_site_seq'::regclass);


--
-- TOC entry 3767 (class 2604 OID 17337)
-- Name: stock_level id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level ALTER COLUMN id SET DEFAULT nextval('public.stock_level_id_seq'::regclass);


--
-- TOC entry 3664 (class 2604 OID 16429)
-- Name: technicien id_technicien; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.technicien ALTER COLUMN id_technicien SET DEFAULT nextval('public.technicien_id_technicien_seq'::regclass);


--
-- TOC entry 3663 (class 2604 OID 16418)
-- Name: type_machine id_type_machine; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.type_machine ALTER COLUMN id_type_machine SET DEFAULT nextval('public.type_machine_id_type_machine_seq'::regclass);


--
-- TOC entry 3734 (class 2604 OID 17006)
-- Name: type_mouvement id; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.type_mouvement ALTER COLUMN id SET DEFAULT nextval('public.type_mouvement_id_seq'::regclass);


--
-- TOC entry 3668 (class 2604 OID 16451)
-- Name: utilisateur id_utilisateur; Type: DEFAULT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.utilisateur ALTER COLUMN id_utilisateur SET DEFAULT nextval('public.utilisateur_id_utilisateur_seq'::regclass);


--
-- TOC entry 4052 (class 2606 OID 19091)
-- Name: ao_fournisseur_consulte ao_fournisseur_consulte_ao_id_fournisseur_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ao_fournisseur_consulte
    ADD CONSTRAINT ao_fournisseur_consulte_ao_id_fournisseur_id_key UNIQUE (ao_id, fournisseur_id);


--
-- TOC entry 4054 (class 2606 OID 19089)
-- Name: ao_fournisseur_consulte ao_fournisseur_consulte_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ao_fournisseur_consulte
    ADD CONSTRAINT ao_fournisseur_consulte_pkey PRIMARY KEY (id);


--
-- TOC entry 4046 (class 2606 OID 19069)
-- Name: appel_offre appel_offre_commande_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.appel_offre
    ADD CONSTRAINT appel_offre_commande_id_key UNIQUE (commande_id);


--
-- TOC entry 4048 (class 2606 OID 19067)
-- Name: appel_offre appel_offre_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.appel_offre
    ADD CONSTRAINT appel_offre_pkey PRIMARY KEY (id_ao);


--
-- TOC entry 4050 (class 2606 OID 19071)
-- Name: appel_offre appel_offre_reference_ao_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.appel_offre
    ADD CONSTRAINT appel_offre_reference_ao_key UNIQUE (reference_ao);


--
-- TOC entry 4100 (class 2606 OID 20040)
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- TOC entry 4105 (class 2606 OID 19971)
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- TOC entry 4108 (class 2606 OID 19940)
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4102 (class 2606 OID 19932)
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- TOC entry 4095 (class 2606 OID 19962)
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- TOC entry 4097 (class 2606 OID 19926)
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- TOC entry 4116 (class 2606 OID 19954)
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 4119 (class 2606 OID 19986)
-- Name: auth_user_groups auth_user_groups_user_id_group_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- TOC entry 4110 (class 2606 OID 19946)
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- TOC entry 4122 (class 2606 OID 19960)
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4125 (class 2606 OID 20000)
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_permission_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- TOC entry 4113 (class 2606 OID 20035)
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- TOC entry 3937 (class 2606 OID 16722)
-- Name: commande commande_numero_commande_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.commande
    ADD CONSTRAINT commande_numero_commande_key UNIQUE (numero_commande);


--
-- TOC entry 3939 (class 2606 OID 16720)
-- Name: commande commande_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.commande
    ADD CONSTRAINT commande_pkey PRIMARY KEY (id_commande);


--
-- TOC entry 3943 (class 2606 OID 16771)
-- Name: compteur compteur_machine_id_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.compteur
    ADD CONSTRAINT compteur_machine_id_nom_key UNIQUE (machine_id, nom);


--
-- TOC entry 3945 (class 2606 OID 16769)
-- Name: compteur compteur_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.compteur
    ADD CONSTRAINT compteur_pkey PRIMARY KEY (id_compteur);


--
-- TOC entry 4077 (class 2606 OID 19835)
-- Name: contrat_achat contrat_achat_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.contrat_achat
    ADD CONSTRAINT contrat_achat_pkey PRIMARY KEY (id_contrat_achat);


--
-- TOC entry 4079 (class 2606 OID 19837)
-- Name: contrat_achat contrat_achat_reference_interne_contrat_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.contrat_achat
    ADD CONSTRAINT contrat_achat_reference_interne_contrat_key UNIQUE (reference_interne_contrat);


--
-- TOC entry 4044 (class 2606 OID 19039)
-- Name: demandes_achat_lignes demandes_achat_lignes_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat_lignes
    ADD CONSTRAINT demandes_achat_lignes_pkey PRIMARY KEY (id);


--
-- TOC entry 4040 (class 2606 OID 19025)
-- Name: demandes_achat demandes_achat_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat
    ADD CONSTRAINT demandes_achat_pkey PRIMARY KEY (id);


--
-- TOC entry 4042 (class 2606 OID 19027)
-- Name: demandes_achat demandes_achat_reference_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat
    ADD CONSTRAINT demandes_achat_reference_key UNIQUE (reference);


--
-- TOC entry 4128 (class 2606 OID 20021)
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- TOC entry 4090 (class 2606 OID 19920)
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- TOC entry 4092 (class 2606 OID 19918)
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- TOC entry 4088 (class 2606 OID 19912)
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 4132 (class 2606 OID 20048)
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- TOC entry 4000 (class 2606 OID 17191)
-- Name: emplacement_ext emplacement_ext_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_ext
    ADD CONSTRAINT emplacement_ext_pkey PRIMARY KEY (emplacement_id);


--
-- TOC entry 3970 (class 2606 OID 16931)
-- Name: emplacement emplacement_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement
    ADD CONSTRAINT emplacement_pkey PRIMARY KEY (id);


--
-- TOC entry 4004 (class 2606 OID 17210)
-- Name: emplacement_stock emplacement_stock_emplacement_id_piece_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_stock
    ADD CONSTRAINT emplacement_stock_emplacement_id_piece_id_key UNIQUE (emplacement_id, piece_id);


--
-- TOC entry 4006 (class 2606 OID 17208)
-- Name: emplacement_stock emplacement_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_stock
    ADD CONSTRAINT emplacement_stock_pkey PRIMARY KEY (id);


--
-- TOC entry 3872 (class 2606 OID 16446)
-- Name: equipe equipe_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT equipe_nom_key UNIQUE (nom);


--
-- TOC entry 3874 (class 2606 OID 16444)
-- Name: equipe equipe_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT equipe_pkey PRIMARY KEY (id_equipe);


--
-- TOC entry 3859 (class 2606 OID 16413)
-- Name: fabricant fabricant_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.fabricant
    ADD CONSTRAINT fabricant_nom_key UNIQUE (nom);


--
-- TOC entry 3861 (class 2606 OID 16411)
-- Name: fabricant fabricant_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.fabricant
    ADD CONSTRAINT fabricant_pkey PRIMARY KEY (id_fabricant);


--
-- TOC entry 3893 (class 2606 OID 16513)
-- Name: fournisseur fournisseur_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.fournisseur
    ADD CONSTRAINT fournisseur_nom_key UNIQUE (nom);


--
-- TOC entry 3895 (class 2606 OID 16511)
-- Name: fournisseur fournisseur_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.fournisseur
    ADD CONSTRAINT fournisseur_pkey PRIMARY KEY (id_fournisseur);


--
-- TOC entry 3923 (class 2606 OID 16660)
-- Name: gamme_entretien gamme_entretien_description_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_entretien
    ADD CONSTRAINT gamme_entretien_description_key UNIQUE (description);


--
-- TOC entry 3925 (class 2606 OID 16658)
-- Name: gamme_entretien gamme_entretien_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_entretien
    ADD CONSTRAINT gamme_entretien_pkey PRIMARY KEY (id_gamme);


--
-- TOC entry 3928 (class 2606 OID 16679)
-- Name: gamme_etape gamme_etape_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_etape
    ADD CONSTRAINT gamme_etape_pkey PRIMARY KEY (id_etape);


--
-- TOC entry 3931 (class 2606 OID 16695)
-- Name: gamme_piece_type gamme_piece_type_gamme_id_piece_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_piece_type
    ADD CONSTRAINT gamme_piece_type_gamme_id_piece_id_key UNIQUE (gamme_id, piece_id);


--
-- TOC entry 3933 (class 2606 OID 16693)
-- Name: gamme_piece_type gamme_piece_type_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_piece_type
    ADD CONSTRAINT gamme_piece_type_pkey PRIMARY KEY (id);


--
-- TOC entry 3948 (class 2606 OID 16786)
-- Name: historique_compteur historique_compteur_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.historique_compteur
    ADD CONSTRAINT historique_compteur_pkey PRIMARY KEY (id_historique);


--
-- TOC entry 3921 (class 2606 OID 16610)
-- Name: intervention_piece intervention_piece_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.intervention_piece
    ADD CONSTRAINT intervention_piece_pkey PRIMARY KEY (id);


--
-- TOC entry 4011 (class 2606 OID 17262)
-- Name: inventory_users inventory_users_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.inventory_users
    ADD CONSTRAINT inventory_users_pkey PRIMARY KEY (id);


--
-- TOC entry 4013 (class 2606 OID 17264)
-- Name: inventory_users inventory_users_username_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.inventory_users
    ADD CONSTRAINT inventory_users_username_key UNIQUE (username);


--
-- TOC entry 3980 (class 2606 OID 16987)
-- Name: inventory_warehouse inventory_warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_warehouse
    ADD CONSTRAINT inventory_warehouse_pkey PRIMARY KEY (id);


--
-- TOC entry 4017 (class 2606 OID 17316)
-- Name: inventory_warehouses inventory_warehouses_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.inventory_warehouses
    ADD CONSTRAINT inventory_warehouses_pkey PRIMARY KEY (id);


--
-- TOC entry 3941 (class 2606 OID 16747)
-- Name: ligne_commande ligne_commande_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ligne_commande
    ADD CONSTRAINT ligne_commande_pkey PRIMARY KEY (id_ligne);


--
-- TOC entry 4031 (class 2606 OID 17419)
-- Name: lot_reception lot_reception_numero_lot_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_numero_lot_key UNIQUE (numero_lot);


--
-- TOC entry 4033 (class 2606 OID 17417)
-- Name: lot_reception lot_reception_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_pkey PRIMARY KEY (id);


--
-- TOC entry 4019 (class 2606 OID 17327)
-- Name: lot_serie lot_serie_article_id_numero_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_serie
    ADD CONSTRAINT lot_serie_article_id_numero_key UNIQUE (article_id, numero);


--
-- TOC entry 4021 (class 2606 OID 17325)
-- Name: lot_serie lot_serie_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_serie
    ADD CONSTRAINT lot_serie_pkey PRIMARY KEY (id);


--
-- TOC entry 3889 (class 2606 OID 16479)
-- Name: machine machine_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine
    ADD CONSTRAINT machine_pkey PRIMARY KEY (id_machine);


--
-- TOC entry 3891 (class 2606 OID 16481)
-- Name: machine machine_serial_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine
    ADD CONSTRAINT machine_serial_key UNIQUE (serial);


--
-- TOC entry 3959 (class 2606 OID 16838)
-- Name: maintenance_frais_externe maintenance_frais_externe_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_frais_externe
    ADD CONSTRAINT maintenance_frais_externe_pkey PRIMARY KEY (id_frais);


--
-- TOC entry 3955 (class 2606 OID 16814)
-- Name: maintenance_intervenant maintenance_intervenant_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_intervenant
    ADD CONSTRAINT maintenance_intervenant_pkey PRIMARY KEY (id_intervenant);


--
-- TOC entry 3915 (class 2606 OID 16585)
-- Name: maintenance maintenance_ot_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance
    ADD CONSTRAINT maintenance_ot_id_key UNIQUE (ot_id);


--
-- TOC entry 3917 (class 2606 OID 16583)
-- Name: maintenance maintenance_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance
    ADD CONSTRAINT maintenance_pkey PRIMARY KEY (id_maintenance);


--
-- TOC entry 4038 (class 2606 OID 17465)
-- Name: mise_en_stock_detail mise_en_stock_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mise_en_stock_detail
    ADD CONSTRAINT mise_en_stock_detail_pkey PRIMARY KEY (id);


--
-- TOC entry 3993 (class 2606 OID 17087)
-- Name: mouvement_stock mouvement_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock
    ADD CONSTRAINT mouvement_stock_pkey PRIMARY KEY (id);


--
-- TOC entry 4056 (class 2606 OID 19113)
-- Name: offre_recue offre_recue_ao_id_fournisseur_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue
    ADD CONSTRAINT offre_recue_ao_id_fournisseur_id_key UNIQUE (ao_id, fournisseur_id);


--
-- TOC entry 4060 (class 2606 OID 19135)
-- Name: offre_recue_ligne offre_recue_ligne_offre_id_piece_id_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue_ligne
    ADD CONSTRAINT offre_recue_ligne_offre_id_piece_id_key UNIQUE (offre_id, piece_id);


--
-- TOC entry 4062 (class 2606 OID 19133)
-- Name: offre_recue_ligne offre_recue_ligne_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue_ligne
    ADD CONSTRAINT offre_recue_ligne_pkey PRIMARY KEY (id_offre_ligne);


--
-- TOC entry 4058 (class 2606 OID 19111)
-- Name: offre_recue offre_recue_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue
    ADD CONSTRAINT offre_recue_pkey PRIMARY KEY (id_offre);


--
-- TOC entry 4072 (class 2606 OID 19699)
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- TOC entry 3908 (class 2606 OID 16553)
-- Name: ordre_travail ordre_travail_numero_ot_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ordre_travail
    ADD CONSTRAINT ordre_travail_numero_ot_key UNIQUE (numero_ot);


--
-- TOC entry 3910 (class 2606 OID 16551)
-- Name: ordre_travail ordre_travail_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ordre_travail
    ADD CONSTRAINT ordre_travail_pkey PRIMARY KEY (id_ot);


--
-- TOC entry 3962 (class 2606 OID 16903)
-- Name: piece_category piece_category_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_category
    ADD CONSTRAINT piece_category_pkey PRIMARY KEY (id);


--
-- TOC entry 3978 (class 2606 OID 16940)
-- Name: piece_extension piece_extension_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_pkey PRIMARY KEY (id_piece);


--
-- TOC entry 4067 (class 2606 OID 19157)
-- Name: piece_fournisseur_info piece_fournisseur_info_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_fournisseur_info
    ADD CONSTRAINT piece_fournisseur_info_pkey PRIMARY KEY (id_piece_fournisseur_info);


--
-- TOC entry 3902 (class 2606 OID 16531)
-- Name: piece piece_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece
    ADD CONSTRAINT piece_pkey PRIMARY KEY (id_piece);


--
-- TOC entry 3904 (class 2606 OID 16533)
-- Name: piece piece_reference_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece
    ADD CONSTRAINT piece_reference_key UNIQUE (reference);


--
-- TOC entry 3968 (class 2606 OID 16923)
-- Name: piece_statut piece_statut_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_statut
    ADD CONSTRAINT piece_statut_pkey PRIMARY KEY (id);


--
-- TOC entry 3965 (class 2606 OID 16913)
-- Name: piece_unit piece_unit_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_unit
    ADD CONSTRAINT piece_unit_pkey PRIMARY KEY (id);


--
-- TOC entry 4084 (class 2606 OID 19867)
-- Name: prestation_achat prestation_achat_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_pkey PRIMARY KEY (id_prestation_achat);


--
-- TOC entry 4086 (class 2606 OID 19869)
-- Name: prestation_achat prestation_achat_reference_prestation_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_reference_prestation_key UNIQUE (reference_prestation);


--
-- TOC entry 4075 (class 2606 OID 19709)
-- Name: purchased_items purchased_items_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.purchased_items
    ADD CONSTRAINT purchased_items_pkey PRIMARY KEY (id);


--
-- TOC entry 3998 (class 2606 OID 17151)
-- Name: reception_detail reception_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.reception_detail
    ADD CONSTRAINT reception_detail_pkey PRIMARY KEY (id_reception);


--
-- TOC entry 3855 (class 2606 OID 16402)
-- Name: site site_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.site
    ADD CONSTRAINT site_nom_key UNIQUE (nom);


--
-- TOC entry 3857 (class 2606 OID 16400)
-- Name: site site_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (id_site);


--
-- TOC entry 4023 (class 2606 OID 17344)
-- Name: stock_level stock_level_article_id_magasin_id_emplacement_id_lot_serie__key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level
    ADD CONSTRAINT stock_level_article_id_magasin_id_emplacement_id_lot_serie__key UNIQUE (article_id, magasin_id, emplacement_id, lot_serie_id);


--
-- TOC entry 4025 (class 2606 OID 17342)
-- Name: stock_level stock_level_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level
    ADD CONSTRAINT stock_level_pkey PRIMARY KEY (id);


--
-- TOC entry 4015 (class 2606 OID 17275)
-- Name: stock_piece_extra stock_piece_extra_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_pkey PRIMARY KEY (id_piece);


--
-- TOC entry 3870 (class 2606 OID 16435)
-- Name: technicien technicien_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.technicien
    ADD CONSTRAINT technicien_pkey PRIMARY KEY (id_technicien);


--
-- TOC entry 3865 (class 2606 OID 16424)
-- Name: type_machine type_machine_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.type_machine
    ADD CONSTRAINT type_machine_nom_key UNIQUE (nom);


--
-- TOC entry 3867 (class 2606 OID 16422)
-- Name: type_machine type_machine_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.type_machine
    ADD CONSTRAINT type_machine_pkey PRIMARY KEY (id_type_machine);


--
-- TOC entry 3982 (class 2606 OID 17014)
-- Name: type_mouvement type_mouvement_nom_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.type_mouvement
    ADD CONSTRAINT type_mouvement_nom_key UNIQUE (nom);


--
-- TOC entry 3984 (class 2606 OID 17012)
-- Name: type_mouvement type_mouvement_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.type_mouvement
    ADD CONSTRAINT type_mouvement_pkey PRIMARY KEY (id);


--
-- TOC entry 4069 (class 2606 OID 19159)
-- Name: piece_fournisseur_info uq_piece_fournisseur; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_fournisseur_info
    ADD CONSTRAINT uq_piece_fournisseur UNIQUE (piece_id, fournisseur_id);


--
-- TOC entry 3878 (class 2606 OID 16462)
-- Name: utilisateur utilisateur_email_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_email_key UNIQUE (email);


--
-- TOC entry 3880 (class 2606 OID 16460)
-- Name: utilisateur utilisateur_login_key; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_login_key UNIQUE (login);


--
-- TOC entry 3882 (class 2606 OID 16458)
-- Name: utilisateur utilisateur_pkey; Type: CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_pkey PRIMARY KEY (id_utilisateur);


--
-- TOC entry 4098 (class 1259 OID 20041)
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- TOC entry 4103 (class 1259 OID 19982)
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- TOC entry 4106 (class 1259 OID 19983)
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- TOC entry 4093 (class 1259 OID 19968)
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- TOC entry 4114 (class 1259 OID 19998)
-- Name: auth_user_groups_group_id_97559544; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_user_groups_group_id_97559544 ON public.auth_user_groups USING btree (group_id);


--
-- TOC entry 4117 (class 1259 OID 19997)
-- Name: auth_user_groups_user_id_6a12ed8b; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_user_groups_user_id_6a12ed8b ON public.auth_user_groups USING btree (user_id);


--
-- TOC entry 4120 (class 1259 OID 20012)
-- Name: auth_user_user_permissions_permission_id_1fbb5f2c; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_user_user_permissions_permission_id_1fbb5f2c ON public.auth_user_user_permissions USING btree (permission_id);


--
-- TOC entry 4123 (class 1259 OID 20011)
-- Name: auth_user_user_permissions_user_id_a95ead1b; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_user_user_permissions_user_id_a95ead1b ON public.auth_user_user_permissions USING btree (user_id);


--
-- TOC entry 4111 (class 1259 OID 20036)
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX auth_user_username_6821ab7c_like ON public.auth_user USING btree (username varchar_pattern_ops);


--
-- TOC entry 4126 (class 1259 OID 20032)
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- TOC entry 4129 (class 1259 OID 20033)
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- TOC entry 4130 (class 1259 OID 20050)
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- TOC entry 4133 (class 1259 OID 20049)
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- TOC entry 4080 (class 1259 OID 19850)
-- Name: idx_ca_date_fin_validite; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_ca_date_fin_validite ON public.contrat_achat USING btree (date_fin_validite);


--
-- TOC entry 4081 (class 1259 OID 19848)
-- Name: idx_ca_fournisseur_id; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_ca_fournisseur_id ON public.contrat_achat USING btree (fournisseur_id);


--
-- TOC entry 4082 (class 1259 OID 19849)
-- Name: idx_ca_statut; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_ca_statut ON public.contrat_achat USING btree (statut_contrat);


--
-- TOC entry 3946 (class 1259 OID 16850)
-- Name: idx_compteur_machine; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_compteur_machine ON public.compteur USING btree (machine_id);


--
-- TOC entry 4001 (class 1259 OID 17222)
-- Name: idx_emplacement_ext_capacite; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_emplacement_ext_capacite ON public.emplacement_ext USING btree (capacite_max_kg);


--
-- TOC entry 4002 (class 1259 OID 17221)
-- Name: idx_emplacement_ext_volume; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_emplacement_ext_volume ON public.emplacement_ext USING btree (volume_cm3);


--
-- TOC entry 3971 (class 1259 OID 16932)
-- Name: idx_emplacement_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_emplacement_nom ON public.emplacement USING btree (nom);


--
-- TOC entry 4007 (class 1259 OID 17223)
-- Name: idx_emplacement_stock_emplacement; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_emplacement_stock_emplacement ON public.emplacement_stock USING btree (emplacement_id);


--
-- TOC entry 4008 (class 1259 OID 17224)
-- Name: idx_emplacement_stock_piece; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_emplacement_stock_piece ON public.emplacement_stock USING btree (piece_id);


--
-- TOC entry 4009 (class 1259 OID 17225)
-- Name: idx_emplacement_stock_quantite; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_emplacement_stock_quantite ON public.emplacement_stock USING btree (quantite) WHERE (quantite > 0);


--
-- TOC entry 3862 (class 1259 OID 16886)
-- Name: idx_fabricant_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_fabricant_nom ON public.fabricant USING btree (nom);


--
-- TOC entry 3896 (class 1259 OID 16888)
-- Name: idx_fournisseur_email; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_fournisseur_email ON public.fournisseur USING btree (email);


--
-- TOC entry 3897 (class 1259 OID 16887)
-- Name: idx_fournisseur_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_fournisseur_nom ON public.fournisseur USING btree (nom);


--
-- TOC entry 3929 (class 1259 OID 16845)
-- Name: idx_gamme_etape_gamme; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_gamme_etape_gamme ON public.gamme_etape USING btree (gamme_id);


--
-- TOC entry 3934 (class 1259 OID 16846)
-- Name: idx_gamme_piece_gamme; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_gamme_piece_gamme ON public.gamme_piece_type USING btree (gamme_id);


--
-- TOC entry 3935 (class 1259 OID 16847)
-- Name: idx_gamme_piece_piece; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_gamme_piece_piece ON public.gamme_piece_type USING btree (piece_id);


--
-- TOC entry 3926 (class 1259 OID 16844)
-- Name: idx_gamme_type_machine; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_gamme_type_machine ON public.gamme_entretien USING btree (type_machine_id);


--
-- TOC entry 3949 (class 1259 OID 16851)
-- Name: idx_historique_compteur; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_historique_compteur ON public.historique_compteur USING btree (compteur_id);


--
-- TOC entry 3950 (class 1259 OID 16853)
-- Name: idx_historique_maintenance; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_historique_maintenance ON public.historique_compteur USING btree (maintenance_id);


--
-- TOC entry 3951 (class 1259 OID 16852)
-- Name: idx_historique_utilisateur; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_historique_utilisateur ON public.historique_compteur USING btree (utilisateur_id);


--
-- TOC entry 3918 (class 1259 OID 16848)
-- Name: idx_intervention_piece_maint; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_intervention_piece_maint ON public.intervention_piece USING btree (maintenance_id);


--
-- TOC entry 3919 (class 1259 OID 16849)
-- Name: idx_intervention_piece_piece; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_intervention_piece_piece ON public.intervention_piece USING btree (piece_id);


--
-- TOC entry 4026 (class 1259 OID 17451)
-- Name: idx_lot_reception_commande; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_lot_reception_commande ON public.lot_reception USING btree (commande_id);


--
-- TOC entry 4027 (class 1259 OID 17453)
-- Name: idx_lot_reception_date; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_lot_reception_date ON public.lot_reception USING btree (date_reception);


--
-- TOC entry 4028 (class 1259 OID 17450)
-- Name: idx_lot_reception_piece; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_lot_reception_piece ON public.lot_reception USING btree (piece_id);


--
-- TOC entry 4029 (class 1259 OID 17452)
-- Name: idx_lot_reception_statut; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_lot_reception_statut ON public.lot_reception USING btree (statut_lot);


--
-- TOC entry 3883 (class 1259 OID 16893)
-- Name: idx_machine_fabricant; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_machine_fabricant ON public.machine USING btree (fabricant_id);


--
-- TOC entry 3884 (class 1259 OID 16894)
-- Name: idx_machine_parent; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_machine_parent ON public.machine USING btree (parent_machine_id);


--
-- TOC entry 3885 (class 1259 OID 16892)
-- Name: idx_machine_site; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_machine_site ON public.machine USING btree (site_id);


--
-- TOC entry 3886 (class 1259 OID 20120)
-- Name: idx_machine_site_type; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_machine_site_type ON public.machine USING btree (site_id, type_machine_id);


--
-- TOC entry 3887 (class 1259 OID 16891)
-- Name: idx_machine_type; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_machine_type ON public.machine USING btree (type_machine_id);


--
-- TOC entry 3911 (class 1259 OID 20119)
-- Name: idx_maintenance_cout_date; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_cout_date ON public.maintenance USING btree (cout_total, date_fin_reelle) WHERE (cout_total IS NOT NULL);


--
-- TOC entry 3912 (class 1259 OID 20117)
-- Name: idx_maintenance_date_machine; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_date_machine ON public.maintenance USING btree (date_fin_reelle, machine_id) WHERE (cout_total IS NOT NULL);


--
-- TOC entry 3913 (class 1259 OID 20118)
-- Name: idx_maintenance_date_type; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_date_type ON public.maintenance USING btree (date_fin_reelle, type_reel) WHERE (cout_total IS NOT NULL);


--
-- TOC entry 3956 (class 1259 OID 16856)
-- Name: idx_maintenance_frais_maint; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_frais_maint ON public.maintenance_frais_externe USING btree (maintenance_id);


--
-- TOC entry 3957 (class 1259 OID 16857)
-- Name: idx_maintenance_frais_type; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_frais_type ON public.maintenance_frais_externe USING btree (type_frais);


--
-- TOC entry 3952 (class 1259 OID 16854)
-- Name: idx_maintenance_intervenant_maint; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_intervenant_maint ON public.maintenance_intervenant USING btree (maintenance_id);


--
-- TOC entry 3953 (class 1259 OID 16855)
-- Name: idx_maintenance_intervenant_tech; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_maintenance_intervenant_tech ON public.maintenance_intervenant USING btree (technicien_id);


--
-- TOC entry 4034 (class 1259 OID 17488)
-- Name: idx_mise_en_stock_date; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mise_en_stock_date ON public.mise_en_stock_detail USING btree (date_stockage);


--
-- TOC entry 4035 (class 1259 OID 17487)
-- Name: idx_mise_en_stock_emplacement; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mise_en_stock_emplacement ON public.mise_en_stock_detail USING btree (emplacement_destination_id);


--
-- TOC entry 4036 (class 1259 OID 17486)
-- Name: idx_mise_en_stock_lot; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mise_en_stock_lot ON public.mise_en_stock_detail USING btree (lot_reception_id);


--
-- TOC entry 3985 (class 1259 OID 17115)
-- Name: idx_mouvement_stock_date; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_date ON public.mouvement_stock USING btree (date_mouvement);


--
-- TOC entry 3986 (class 1259 OID 17118)
-- Name: idx_mouvement_stock_emplacement_dest; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_emplacement_dest ON public.mouvement_stock USING btree (emplacement_destination_id);


--
-- TOC entry 3987 (class 1259 OID 17117)
-- Name: idx_mouvement_stock_emplacement_source; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_emplacement_source ON public.mouvement_stock USING btree (emplacement_source_id);


--
-- TOC entry 3988 (class 1259 OID 17113)
-- Name: idx_mouvement_stock_piece; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_piece ON public.mouvement_stock USING btree (piece_id);


--
-- TOC entry 3989 (class 1259 OID 17512)
-- Name: idx_mouvement_stock_statut; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_statut ON public.mouvement_stock USING btree (statut_mouvement);


--
-- TOC entry 3990 (class 1259 OID 17114)
-- Name: idx_mouvement_stock_type; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_type ON public.mouvement_stock USING btree (type_mouvement_id);


--
-- TOC entry 3991 (class 1259 OID 17116)
-- Name: idx_mouvement_stock_utilisateur; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_mouvement_stock_utilisateur ON public.mouvement_stock USING btree (utilisateur_id);


--
-- TOC entry 3905 (class 1259 OID 20140)
-- Name: idx_ot_archives; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_ot_archives ON public.ordre_travail USING btree (date_creation DESC) WHERE (statut = 'ArchivÃ©'::text);


--
-- TOC entry 3906 (class 1259 OID 20139)
-- Name: idx_ot_statut_non_archive; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_ot_statut_non_archive ON public.ordre_travail USING btree (statut, date_creation DESC) WHERE (statut <> 'ArchivÃ©'::text);


--
-- TOC entry 4063 (class 1259 OID 19171)
-- Name: idx_pfi_fournisseur_id; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_pfi_fournisseur_id ON public.piece_fournisseur_info USING btree (fournisseur_id);


--
-- TOC entry 4064 (class 1259 OID 19170)
-- Name: idx_pfi_piece_id; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_pfi_piece_id ON public.piece_fournisseur_info USING btree (piece_id);


--
-- TOC entry 4065 (class 1259 OID 19172)
-- Name: idx_pfi_reference_fournisseur; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_pfi_reference_fournisseur ON public.piece_fournisseur_info USING btree (reference_fournisseur);


--
-- TOC entry 3960 (class 1259 OID 16904)
-- Name: idx_piece_category_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_piece_category_nom ON public.piece_category USING btree (nom);


--
-- TOC entry 3972 (class 1259 OID 16972)
-- Name: idx_piece_extension_categorie; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_extension_categorie ON public.piece_extension USING btree (categorie_id);


--
-- TOC entry 3973 (class 1259 OID 16973)
-- Name: idx_piece_extension_emplacement; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_extension_emplacement ON public.piece_extension USING btree (emplacement_id);


--
-- TOC entry 3974 (class 1259 OID 16975)
-- Name: idx_piece_extension_machine; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_extension_machine ON public.piece_extension USING btree (machine_id);


--
-- TOC entry 3975 (class 1259 OID 16974)
-- Name: idx_piece_extension_statut; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_extension_statut ON public.piece_extension USING btree (statut_id);


--
-- TOC entry 3976 (class 1259 OID 16971)
-- Name: idx_piece_extension_unite; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_extension_unite ON public.piece_extension USING btree (unite_id);


--
-- TOC entry 3898 (class 1259 OID 16935)
-- Name: idx_piece_fournisseur; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_fournisseur ON public.piece USING btree (fournisseur_pref_id);


--
-- TOC entry 3899 (class 1259 OID 16934)
-- Name: idx_piece_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_piece_nom ON public.piece USING btree (nom);


--
-- TOC entry 3900 (class 1259 OID 16933)
-- Name: idx_piece_reference; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_piece_reference ON public.piece USING btree (reference);


--
-- TOC entry 3966 (class 1259 OID 16924)
-- Name: idx_piece_statut_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_piece_statut_nom ON public.piece_statut USING btree (nom);


--
-- TOC entry 3963 (class 1259 OID 16914)
-- Name: idx_piece_unit_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_piece_unit_nom ON public.piece_unit USING btree (nom);


--
-- TOC entry 3994 (class 1259 OID 17163)
-- Name: idx_reception_detail_date; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_reception_detail_date ON public.reception_detail USING btree (date_reception);


--
-- TOC entry 3995 (class 1259 OID 17162)
-- Name: idx_reception_detail_ligne_commande; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_reception_detail_ligne_commande ON public.reception_detail USING btree (ligne_commande_id);


--
-- TOC entry 3996 (class 1259 OID 17164)
-- Name: idx_reception_detail_utilisateur; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_reception_detail_utilisateur ON public.reception_detail USING btree (utilisateur_id);


--
-- TOC entry 3853 (class 1259 OID 16889)
-- Name: idx_site_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_site_nom ON public.site USING btree (nom);


--
-- TOC entry 3868 (class 1259 OID 20121)
-- Name: idx_technicien_equipe_actif; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_technicien_equipe_actif ON public.technicien USING btree (equipe_id, actif) WHERE (actif = 1);


--
-- TOC entry 3863 (class 1259 OID 16890)
-- Name: idx_type_machine_nom; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_type_machine_nom ON public.type_machine USING btree (nom);


--
-- TOC entry 3875 (class 1259 OID 16977)
-- Name: idx_utilisateur_email; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX idx_utilisateur_email ON public.utilisateur USING btree (email);


--
-- TOC entry 3876 (class 1259 OID 16976)
-- Name: idx_utilisateur_login; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE UNIQUE INDEX idx_utilisateur_login ON public.utilisateur USING btree (login);


--
-- TOC entry 4070 (class 1259 OID 19700)
-- Name: ix_orders_id; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX ix_orders_id ON public.orders USING btree (id);


--
-- TOC entry 4073 (class 1259 OID 19715)
-- Name: ix_purchased_items_id; Type: INDEX; Schema: public; Owner: gmao_app_user
--

CREATE INDEX ix_purchased_items_id ON public.purchased_items USING btree (id);


--
-- TOC entry 4244 (class 2620 OID 17120)
-- Name: mouvement_stock calculate_cout_total_trigger; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER calculate_cout_total_trigger BEFORE INSERT OR UPDATE ON public.mouvement_stock FOR EACH ROW EXECUTE FUNCTION public.calculate_cout_total();


--
-- TOC entry 4248 (class 2620 OID 17233)
-- Name: emplacement_stock check_coherence_emplacement_stock; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER check_coherence_emplacement_stock AFTER INSERT OR DELETE OR UPDATE ON public.emplacement_stock FOR EACH ROW EXECUTE FUNCTION public.check_stock_coherence();


--
-- TOC entry 4242 (class 2620 OID 16881)
-- Name: commande commande_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER commande_updated_at AFTER UPDATE ON public.commande FOR EACH ROW EXECUTE FUNCTION public.commande_updated_at();


--
-- TOC entry 4243 (class 2620 OID 16883)
-- Name: compteur compteur_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER compteur_updated_at AFTER UPDATE ON public.compteur FOR EACH ROW EXECUTE FUNCTION public.compteur_updated_at();


--
-- TOC entry 4238 (class 2620 OID 16875)
-- Name: fournisseur fournisseur_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER fournisseur_updated_at AFTER UPDATE ON public.fournisseur FOR EACH ROW EXECUTE FUNCTION public.fournisseur_updated_at();


--
-- TOC entry 4241 (class 2620 OID 16879)
-- Name: gamme_entretien gamme_entretien_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER gamme_entretien_updated_at AFTER UPDATE ON public.gamme_entretien FOR EACH ROW EXECUTE FUNCTION public.gamme_entretien_updated_at();


--
-- TOC entry 4249 (class 2620 OID 17231)
-- Name: emplacement_stock init_dates_emplacement_stock; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER init_dates_emplacement_stock BEFORE INSERT ON public.emplacement_stock FOR EACH ROW EXECUTE FUNCTION public.init_emplacement_stock_dates();


--
-- TOC entry 4237 (class 2620 OID 16871)
-- Name: machine machine_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER machine_updated_at AFTER UPDATE ON public.machine FOR EACH ROW EXECUTE FUNCTION public.machine_updated_at();


--
-- TOC entry 4240 (class 2620 OID 16873)
-- Name: ordre_travail ot_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER ot_updated_at AFTER UPDATE ON public.ordre_travail FOR EACH ROW EXECUTE FUNCTION public.ot_updated_at();


--
-- TOC entry 4239 (class 2620 OID 16877)
-- Name: piece piece_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER piece_updated_at AFTER UPDATE ON public.piece FOR EACH ROW EXECUTE FUNCTION public.piece_updated_at();


--
-- TOC entry 4247 (class 2620 OID 17227)
-- Name: emplacement_ext set_updated_at_emplacement_ext; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER set_updated_at_emplacement_ext BEFORE UPDATE ON public.emplacement_ext FOR EACH ROW EXECUTE FUNCTION public.update_emplacement_ext_updated_at();


--
-- TOC entry 4250 (class 2620 OID 17229)
-- Name: emplacement_stock set_updated_at_emplacement_stock; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER set_updated_at_emplacement_stock BEFORE UPDATE ON public.emplacement_stock FOR EACH ROW EXECUTE FUNCTION public.update_emplacement_stock_maj();


--
-- TOC entry 4251 (class 2620 OID 17490)
-- Name: lot_reception set_updated_at_lot_reception; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER set_updated_at_lot_reception BEFORE UPDATE ON public.lot_reception FOR EACH ROW EXECUTE FUNCTION public.update_lot_reception_updated_at();


--
-- TOC entry 4245 (class 2620 OID 17119)
-- Name: mouvement_stock set_updated_at_mouvement_stock; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER set_updated_at_mouvement_stock BEFORE UPDATE ON public.mouvement_stock FOR EACH ROW EXECUTE FUNCTION public.update_mouvement_updated_at();


--
-- TOC entry 4252 (class 2620 OID 17492)
-- Name: mise_en_stock_detail update_lot_after_stockage; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER update_lot_after_stockage AFTER INSERT OR DELETE OR UPDATE ON public.mise_en_stock_detail FOR EACH ROW EXECUTE FUNCTION public.update_lot_statut_after_stockage();


--
-- TOC entry 4236 (class 2620 OID 16869)
-- Name: utilisateur utilisateur_updated_at; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER utilisateur_updated_at AFTER UPDATE ON public.utilisateur FOR EACH ROW EXECUTE FUNCTION public.utilisateur_updated_at();


--
-- TOC entry 4246 (class 2620 OID 17563)
-- Name: mouvement_stock verifier_statut_mouvement_avant_stock; Type: TRIGGER; Schema: public; Owner: gmao_app_user
--

CREATE TRIGGER verifier_statut_mouvement_avant_stock BEFORE INSERT OR UPDATE ON public.mouvement_stock FOR EACH ROW EXECUTE FUNCTION public.verifier_statut_avant_impact_stock();


--
-- TOC entry 4209 (class 2606 OID 19092)
-- Name: ao_fournisseur_consulte ao_fournisseur_consulte_ao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ao_fournisseur_consulte
    ADD CONSTRAINT ao_fournisseur_consulte_ao_id_fkey FOREIGN KEY (ao_id) REFERENCES public.appel_offre(id_ao) ON DELETE CASCADE;


--
-- TOC entry 4210 (class 2606 OID 19097)
-- Name: ao_fournisseur_consulte ao_fournisseur_consulte_fournisseur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ao_fournisseur_consulte
    ADD CONSTRAINT ao_fournisseur_consulte_fournisseur_id_fkey FOREIGN KEY (fournisseur_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE CASCADE;


--
-- TOC entry 4207 (class 2606 OID 19072)
-- Name: appel_offre appel_offre_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.appel_offre
    ADD CONSTRAINT appel_offre_commande_id_fkey FOREIGN KEY (commande_id) REFERENCES public.commande(id_commande);


--
-- TOC entry 4208 (class 2606 OID 19077)
-- Name: appel_offre appel_offre_createur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.appel_offre
    ADD CONSTRAINT appel_offre_createur_id_fkey FOREIGN KEY (createur_id) REFERENCES public.utilisateur(id_utilisateur);


--
-- TOC entry 4228 (class 2606 OID 19977)
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4229 (class 2606 OID 19972)
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4227 (class 2606 OID 19963)
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4230 (class 2606 OID 19992)
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4231 (class 2606 OID 19987)
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4232 (class 2606 OID 20006)
-- Name: auth_user_user_permissions auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4233 (class 2606 OID 20001)
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4155 (class 2606 OID 16728)
-- Name: commande commande_createur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.commande
    ADD CONSTRAINT commande_createur_id_fkey FOREIGN KEY (createur_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE RESTRICT;


--
-- TOC entry 4156 (class 2606 OID 16723)
-- Name: commande commande_fournisseur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.commande
    ADD CONSTRAINT commande_fournisseur_id_fkey FOREIGN KEY (fournisseur_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE RESTRICT;


--
-- TOC entry 4159 (class 2606 OID 16772)
-- Name: compteur compteur_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.compteur
    ADD CONSTRAINT compteur_machine_id_fkey FOREIGN KEY (machine_id) REFERENCES public.machine(id_machine) ON DELETE CASCADE;


--
-- TOC entry 4218 (class 2606 OID 19843)
-- Name: contrat_achat contrat_achat_contact_principal_achat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.contrat_achat
    ADD CONSTRAINT contrat_achat_contact_principal_achat_id_fkey FOREIGN KEY (contact_principal_achat_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE SET NULL;


--
-- TOC entry 4219 (class 2606 OID 19838)
-- Name: contrat_achat contrat_achat_fournisseur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.contrat_achat
    ADD CONSTRAINT contrat_achat_fournisseur_id_fkey FOREIGN KEY (fournisseur_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE RESTRICT;


--
-- TOC entry 4204 (class 2606 OID 19028)
-- Name: demandes_achat demandes_achat_demandeur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat
    ADD CONSTRAINT demandes_achat_demandeur_id_fkey FOREIGN KEY (demandeur_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE SET NULL;


--
-- TOC entry 4205 (class 2606 OID 19045)
-- Name: demandes_achat_lignes demandes_achat_lignes_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat_lignes
    ADD CONSTRAINT demandes_achat_lignes_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.piece(id_piece) ON DELETE SET NULL;


--
-- TOC entry 4206 (class 2606 OID 19040)
-- Name: demandes_achat_lignes demandes_achat_lignes_demande_achat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.demandes_achat_lignes
    ADD CONSTRAINT demandes_achat_lignes_demande_achat_id_fkey FOREIGN KEY (demande_achat_id) REFERENCES public.demandes_achat(id) ON DELETE CASCADE;


--
-- TOC entry 4234 (class 2606 OID 20022)
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4235 (class 2606 OID 20027)
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4180 (class 2606 OID 17192)
-- Name: emplacement_ext emplacement_ext_emplacement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_ext
    ADD CONSTRAINT emplacement_ext_emplacement_id_fkey FOREIGN KEY (emplacement_id) REFERENCES public.emplacement(id) ON DELETE CASCADE;


--
-- TOC entry 4181 (class 2606 OID 17211)
-- Name: emplacement_stock emplacement_stock_emplacement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_stock
    ADD CONSTRAINT emplacement_stock_emplacement_id_fkey FOREIGN KEY (emplacement_id) REFERENCES public.emplacement(id) ON DELETE CASCADE;


--
-- TOC entry 4182 (class 2606 OID 17216)
-- Name: emplacement_stock emplacement_stock_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement_stock
    ADD CONSTRAINT emplacement_stock_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece) ON DELETE CASCADE;


--
-- TOC entry 4166 (class 2606 OID 17577)
-- Name: emplacement fk_emplacement_magasin_id_inventory_warehouses; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.emplacement
    ADD CONSTRAINT fk_emplacement_magasin_id_inventory_warehouses FOREIGN KEY (magasin_id) REFERENCES public.inventory_warehouses(id);


--
-- TOC entry 4135 (class 2606 OID 16863)
-- Name: equipe fk_equipe_responsable; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT fk_equipe_responsable FOREIGN KEY (responsable_id) REFERENCES public.technicien(id_technicien) ON DELETE SET NULL;


--
-- TOC entry 4134 (class 2606 OID 16858)
-- Name: technicien fk_technicien_equipe; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.technicien
    ADD CONSTRAINT fk_technicien_equipe FOREIGN KEY (equipe_id) REFERENCES public.equipe(id_equipe) ON DELETE SET NULL;


--
-- TOC entry 4150 (class 2606 OID 16666)
-- Name: gamme_entretien gamme_entretien_createur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_entretien
    ADD CONSTRAINT gamme_entretien_createur_id_fkey FOREIGN KEY (createur_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE SET NULL;


--
-- TOC entry 4151 (class 2606 OID 16661)
-- Name: gamme_entretien gamme_entretien_type_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_entretien
    ADD CONSTRAINT gamme_entretien_type_machine_id_fkey FOREIGN KEY (type_machine_id) REFERENCES public.type_machine(id_type_machine) ON DELETE SET NULL;


--
-- TOC entry 4152 (class 2606 OID 16680)
-- Name: gamme_etape gamme_etape_gamme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_etape
    ADD CONSTRAINT gamme_etape_gamme_id_fkey FOREIGN KEY (gamme_id) REFERENCES public.gamme_entretien(id_gamme) ON DELETE CASCADE;


--
-- TOC entry 4153 (class 2606 OID 16696)
-- Name: gamme_piece_type gamme_piece_type_gamme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_piece_type
    ADD CONSTRAINT gamme_piece_type_gamme_id_fkey FOREIGN KEY (gamme_id) REFERENCES public.gamme_entretien(id_gamme) ON DELETE CASCADE;


--
-- TOC entry 4154 (class 2606 OID 16701)
-- Name: gamme_piece_type gamme_piece_type_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.gamme_piece_type
    ADD CONSTRAINT gamme_piece_type_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece) ON DELETE CASCADE;


--
-- TOC entry 4160 (class 2606 OID 16787)
-- Name: historique_compteur historique_compteur_compteur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.historique_compteur
    ADD CONSTRAINT historique_compteur_compteur_id_fkey FOREIGN KEY (compteur_id) REFERENCES public.compteur(id_compteur) ON DELETE CASCADE;


--
-- TOC entry 4161 (class 2606 OID 16797)
-- Name: historique_compteur historique_compteur_maintenance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.historique_compteur
    ADD CONSTRAINT historique_compteur_maintenance_id_fkey FOREIGN KEY (maintenance_id) REFERENCES public.maintenance(id_maintenance) ON DELETE SET NULL;


--
-- TOC entry 4162 (class 2606 OID 16792)
-- Name: historique_compteur historique_compteur_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.historique_compteur
    ADD CONSTRAINT historique_compteur_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE SET NULL;


--
-- TOC entry 4148 (class 2606 OID 16611)
-- Name: intervention_piece intervention_piece_maintenance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.intervention_piece
    ADD CONSTRAINT intervention_piece_maintenance_id_fkey FOREIGN KEY (maintenance_id) REFERENCES public.maintenance(id_maintenance) ON DELETE CASCADE;


--
-- TOC entry 4149 (class 2606 OID 16616)
-- Name: intervention_piece intervention_piece_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.intervention_piece
    ADD CONSTRAINT intervention_piece_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece) ON DELETE RESTRICT;


--
-- TOC entry 4157 (class 2606 OID 16748)
-- Name: ligne_commande ligne_commande_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ligne_commande
    ADD CONSTRAINT ligne_commande_commande_id_fkey FOREIGN KEY (commande_id) REFERENCES public.commande(id_commande) ON DELETE CASCADE;


--
-- TOC entry 4158 (class 2606 OID 16753)
-- Name: ligne_commande ligne_commande_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ligne_commande
    ADD CONSTRAINT ligne_commande_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece) ON DELETE RESTRICT;


--
-- TOC entry 4194 (class 2606 OID 17420)
-- Name: lot_reception lot_reception_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_commande_id_fkey FOREIGN KEY (commande_id) REFERENCES public.commande(id_commande);


--
-- TOC entry 4195 (class 2606 OID 17435)
-- Name: lot_reception lot_reception_emplacement_reception_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_emplacement_reception_id_fkey FOREIGN KEY (emplacement_reception_id) REFERENCES public.emplacement(id);


--
-- TOC entry 4196 (class 2606 OID 17425)
-- Name: lot_reception lot_reception_ligne_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_ligne_commande_id_fkey FOREIGN KEY (ligne_commande_id) REFERENCES public.ligne_commande(id_ligne);


--
-- TOC entry 4197 (class 2606 OID 17430)
-- Name: lot_reception lot_reception_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece);


--
-- TOC entry 4198 (class 2606 OID 17440)
-- Name: lot_reception lot_reception_utilisateur_reception_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_utilisateur_reception_id_fkey FOREIGN KEY (utilisateur_reception_id) REFERENCES public.utilisateur(id_utilisateur);


--
-- TOC entry 4199 (class 2606 OID 17445)
-- Name: lot_reception lot_reception_utilisateur_stockage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_reception
    ADD CONSTRAINT lot_reception_utilisateur_stockage_id_fkey FOREIGN KEY (utilisateur_stockage_id) REFERENCES public.utilisateur(id_utilisateur);


--
-- TOC entry 4189 (class 2606 OID 17328)
-- Name: lot_serie lot_serie_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.lot_serie
    ADD CONSTRAINT lot_serie_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.piece(id_piece);


--
-- TOC entry 4137 (class 2606 OID 16492)
-- Name: machine machine_fabricant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine
    ADD CONSTRAINT machine_fabricant_id_fkey FOREIGN KEY (fabricant_id) REFERENCES public.fabricant(id_fabricant) ON DELETE RESTRICT;


--
-- TOC entry 4138 (class 2606 OID 16497)
-- Name: machine machine_parent_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine
    ADD CONSTRAINT machine_parent_machine_id_fkey FOREIGN KEY (parent_machine_id) REFERENCES public.machine(id_machine) ON DELETE SET NULL;


--
-- TOC entry 4139 (class 2606 OID 16487)
-- Name: machine machine_site_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine
    ADD CONSTRAINT machine_site_id_fkey FOREIGN KEY (site_id) REFERENCES public.site(id_site) ON DELETE RESTRICT;


--
-- TOC entry 4140 (class 2606 OID 16482)
-- Name: machine machine_type_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.machine
    ADD CONSTRAINT machine_type_machine_id_fkey FOREIGN KEY (type_machine_id) REFERENCES public.type_machine(id_type_machine) ON DELETE RESTRICT;


--
-- TOC entry 4165 (class 2606 OID 16839)
-- Name: maintenance_frais_externe maintenance_frais_externe_maintenance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_frais_externe
    ADD CONSTRAINT maintenance_frais_externe_maintenance_id_fkey FOREIGN KEY (maintenance_id) REFERENCES public.maintenance(id_maintenance) ON DELETE CASCADE;


--
-- TOC entry 4163 (class 2606 OID 16815)
-- Name: maintenance_intervenant maintenance_intervenant_maintenance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_intervenant
    ADD CONSTRAINT maintenance_intervenant_maintenance_id_fkey FOREIGN KEY (maintenance_id) REFERENCES public.maintenance(id_maintenance) ON DELETE CASCADE;


--
-- TOC entry 4164 (class 2606 OID 16820)
-- Name: maintenance_intervenant maintenance_intervenant_technicien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance_intervenant
    ADD CONSTRAINT maintenance_intervenant_technicien_id_fkey FOREIGN KEY (technicien_id) REFERENCES public.technicien(id_technicien) ON DELETE RESTRICT;


--
-- TOC entry 4145 (class 2606 OID 16591)
-- Name: maintenance maintenance_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance
    ADD CONSTRAINT maintenance_machine_id_fkey FOREIGN KEY (machine_id) REFERENCES public.machine(id_machine) ON DELETE SET NULL;


--
-- TOC entry 4146 (class 2606 OID 16586)
-- Name: maintenance maintenance_ot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance
    ADD CONSTRAINT maintenance_ot_id_fkey FOREIGN KEY (ot_id) REFERENCES public.ordre_travail(id_ot) ON DELETE CASCADE;


--
-- TOC entry 4147 (class 2606 OID 16596)
-- Name: maintenance maintenance_technicien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.maintenance
    ADD CONSTRAINT maintenance_technicien_id_fkey FOREIGN KEY (technicien_id) REFERENCES public.technicien(id_technicien) ON DELETE RESTRICT;


--
-- TOC entry 4200 (class 2606 OID 17471)
-- Name: mise_en_stock_detail mise_en_stock_detail_emplacement_destination_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mise_en_stock_detail
    ADD CONSTRAINT mise_en_stock_detail_emplacement_destination_id_fkey FOREIGN KEY (emplacement_destination_id) REFERENCES public.emplacement(id);


--
-- TOC entry 4201 (class 2606 OID 17466)
-- Name: mise_en_stock_detail mise_en_stock_detail_lot_reception_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mise_en_stock_detail
    ADD CONSTRAINT mise_en_stock_detail_lot_reception_id_fkey FOREIGN KEY (lot_reception_id) REFERENCES public.lot_reception(id);


--
-- TOC entry 4202 (class 2606 OID 17481)
-- Name: mise_en_stock_detail mise_en_stock_detail_mouvement_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mise_en_stock_detail
    ADD CONSTRAINT mise_en_stock_detail_mouvement_stock_id_fkey FOREIGN KEY (mouvement_stock_id) REFERENCES public.mouvement_stock(id);


--
-- TOC entry 4203 (class 2606 OID 17476)
-- Name: mise_en_stock_detail mise_en_stock_detail_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mise_en_stock_detail
    ADD CONSTRAINT mise_en_stock_detail_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateur(id_utilisateur);


--
-- TOC entry 4173 (class 2606 OID 17103)
-- Name: mouvement_stock mouvement_stock_emplacement_destination_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock
    ADD CONSTRAINT mouvement_stock_emplacement_destination_id_fkey FOREIGN KEY (emplacement_destination_id) REFERENCES public.emplacement(id);


--
-- TOC entry 4174 (class 2606 OID 17098)
-- Name: mouvement_stock mouvement_stock_emplacement_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock
    ADD CONSTRAINT mouvement_stock_emplacement_source_id_fkey FOREIGN KEY (emplacement_source_id) REFERENCES public.emplacement(id);


--
-- TOC entry 4175 (class 2606 OID 17088)
-- Name: mouvement_stock mouvement_stock_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock
    ADD CONSTRAINT mouvement_stock_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece);


--
-- TOC entry 4176 (class 2606 OID 17093)
-- Name: mouvement_stock mouvement_stock_type_mouvement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock
    ADD CONSTRAINT mouvement_stock_type_mouvement_id_fkey FOREIGN KEY (type_mouvement_id) REFERENCES public.type_mouvement(id);


--
-- TOC entry 4177 (class 2606 OID 17108)
-- Name: mouvement_stock mouvement_stock_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.mouvement_stock
    ADD CONSTRAINT mouvement_stock_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateur(id_utilisateur);


--
-- TOC entry 4211 (class 2606 OID 19114)
-- Name: offre_recue offre_recue_ao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue
    ADD CONSTRAINT offre_recue_ao_id_fkey FOREIGN KEY (ao_id) REFERENCES public.appel_offre(id_ao) ON DELETE CASCADE;


--
-- TOC entry 4212 (class 2606 OID 19119)
-- Name: offre_recue offre_recue_fournisseur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue
    ADD CONSTRAINT offre_recue_fournisseur_id_fkey FOREIGN KEY (fournisseur_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE CASCADE;


--
-- TOC entry 4213 (class 2606 OID 19136)
-- Name: offre_recue_ligne offre_recue_ligne_offre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue_ligne
    ADD CONSTRAINT offre_recue_ligne_offre_id_fkey FOREIGN KEY (offre_id) REFERENCES public.offre_recue(id_offre) ON DELETE CASCADE;


--
-- TOC entry 4214 (class 2606 OID 19141)
-- Name: offre_recue_ligne offre_recue_ligne_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.offre_recue_ligne
    ADD CONSTRAINT offre_recue_ligne_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece);


--
-- TOC entry 4142 (class 2606 OID 16554)
-- Name: ordre_travail ordre_travail_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ordre_travail
    ADD CONSTRAINT ordre_travail_machine_id_fkey FOREIGN KEY (machine_id) REFERENCES public.machine(id_machine) ON DELETE CASCADE;


--
-- TOC entry 4143 (class 2606 OID 16559)
-- Name: ordre_travail ordre_travail_technicien_assigne_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ordre_travail
    ADD CONSTRAINT ordre_travail_technicien_assigne_id_fkey FOREIGN KEY (technicien_assigne_id) REFERENCES public.technicien(id_technicien) ON DELETE SET NULL;


--
-- TOC entry 4144 (class 2606 OID 16564)
-- Name: ordre_travail ordre_travail_utilisateur_createur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.ordre_travail
    ADD CONSTRAINT ordre_travail_utilisateur_createur_id_fkey FOREIGN KEY (utilisateur_createur_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE RESTRICT;


--
-- TOC entry 4167 (class 2606 OID 16951)
-- Name: piece_extension piece_extension_categorie_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_categorie_id_fkey FOREIGN KEY (categorie_id) REFERENCES public.piece_category(id);


--
-- TOC entry 4168 (class 2606 OID 16956)
-- Name: piece_extension piece_extension_emplacement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_emplacement_id_fkey FOREIGN KEY (emplacement_id) REFERENCES public.emplacement(id);


--
-- TOC entry 4169 (class 2606 OID 16941)
-- Name: piece_extension piece_extension_id_piece_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_id_piece_fkey FOREIGN KEY (id_piece) REFERENCES public.piece(id_piece);


--
-- TOC entry 4170 (class 2606 OID 16966)
-- Name: piece_extension piece_extension_machine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_machine_id_fkey FOREIGN KEY (machine_id) REFERENCES public.machine(id_machine);


--
-- TOC entry 4171 (class 2606 OID 16961)
-- Name: piece_extension piece_extension_statut_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_statut_id_fkey FOREIGN KEY (statut_id) REFERENCES public.piece_statut(id);


--
-- TOC entry 4172 (class 2606 OID 16946)
-- Name: piece_extension piece_extension_unite_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_extension
    ADD CONSTRAINT piece_extension_unite_id_fkey FOREIGN KEY (unite_id) REFERENCES public.piece_unit(id);


--
-- TOC entry 4215 (class 2606 OID 19165)
-- Name: piece_fournisseur_info piece_fournisseur_info_fournisseur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_fournisseur_info
    ADD CONSTRAINT piece_fournisseur_info_fournisseur_id_fkey FOREIGN KEY (fournisseur_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE CASCADE;


--
-- TOC entry 4216 (class 2606 OID 19160)
-- Name: piece_fournisseur_info piece_fournisseur_info_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece_fournisseur_info
    ADD CONSTRAINT piece_fournisseur_info_piece_id_fkey FOREIGN KEY (piece_id) REFERENCES public.piece(id_piece) ON DELETE CASCADE;


--
-- TOC entry 4141 (class 2606 OID 16534)
-- Name: piece piece_fournisseur_pref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.piece
    ADD CONSTRAINT piece_fournisseur_pref_id_fkey FOREIGN KEY (fournisseur_pref_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE SET NULL;


--
-- TOC entry 4220 (class 2606 OID 19880)
-- Name: prestation_achat prestation_achat_acheteur_responsable_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_acheteur_responsable_id_fkey FOREIGN KEY (acheteur_responsable_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE SET NULL;


--
-- TOC entry 4221 (class 2606 OID 19895)
-- Name: prestation_achat prestation_achat_commande_initiale_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_commande_initiale_id_fkey FOREIGN KEY (commande_initiale_id) REFERENCES public.commande(id_commande) ON DELETE SET NULL;


--
-- TOC entry 4222 (class 2606 OID 19900)
-- Name: prestation_achat prestation_achat_commande_regularisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_commande_regularisation_id_fkey FOREIGN KEY (commande_regularisation_id) REFERENCES public.commande(id_commande) ON DELETE SET NULL;


--
-- TOC entry 4223 (class 2606 OID 19885)
-- Name: prestation_achat prestation_achat_contrat_achat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_contrat_achat_id_fkey FOREIGN KEY (contrat_achat_id) REFERENCES public.contrat_achat(id_contrat_achat) ON DELETE SET NULL;


--
-- TOC entry 4224 (class 2606 OID 19875)
-- Name: prestation_achat prestation_achat_demandeur_maintenance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_demandeur_maintenance_id_fkey FOREIGN KEY (demandeur_maintenance_id) REFERENCES public.utilisateur(id_utilisateur) ON DELETE SET NULL;


--
-- TOC entry 4225 (class 2606 OID 19890)
-- Name: prestation_achat prestation_achat_fournisseur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_fournisseur_id_fkey FOREIGN KEY (fournisseur_id) REFERENCES public.fournisseur(id_fournisseur) ON DELETE SET NULL;


--
-- TOC entry 4226 (class 2606 OID 19870)
-- Name: prestation_achat prestation_achat_maintenance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.prestation_achat
    ADD CONSTRAINT prestation_achat_maintenance_id_fkey FOREIGN KEY (maintenance_id) REFERENCES public.maintenance(id_maintenance) ON DELETE SET NULL;


--
-- TOC entry 4217 (class 2606 OID 19710)
-- Name: purchased_items purchased_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.purchased_items
    ADD CONSTRAINT purchased_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- TOC entry 4178 (class 2606 OID 17152)
-- Name: reception_detail reception_detail_ligne_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.reception_detail
    ADD CONSTRAINT reception_detail_ligne_commande_id_fkey FOREIGN KEY (ligne_commande_id) REFERENCES public.ligne_commande(id_ligne) ON DELETE CASCADE;


--
-- TOC entry 4179 (class 2606 OID 17157)
-- Name: reception_detail reception_detail_utilisateur_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.reception_detail
    ADD CONSTRAINT reception_detail_utilisateur_id_fkey FOREIGN KEY (utilisateur_id) REFERENCES public.utilisateur(id_utilisateur);


--
-- TOC entry 4190 (class 2606 OID 17345)
-- Name: stock_level stock_level_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level
    ADD CONSTRAINT stock_level_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.piece(id_piece);


--
-- TOC entry 4191 (class 2606 OID 17355)
-- Name: stock_level stock_level_emplacement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level
    ADD CONSTRAINT stock_level_emplacement_id_fkey FOREIGN KEY (emplacement_id) REFERENCES public.emplacement(id);


--
-- TOC entry 4192 (class 2606 OID 17360)
-- Name: stock_level stock_level_lot_serie_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level
    ADD CONSTRAINT stock_level_lot_serie_id_fkey FOREIGN KEY (lot_serie_id) REFERENCES public.lot_serie(id);


--
-- TOC entry 4193 (class 2606 OID 17350)
-- Name: stock_level stock_level_magasin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_level
    ADD CONSTRAINT stock_level_magasin_id_fkey FOREIGN KEY (magasin_id) REFERENCES public.inventory_warehouses(id);


--
-- TOC entry 4183 (class 2606 OID 17291)
-- Name: stock_piece_extra stock_piece_extra_alternative1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_alternative1_fkey FOREIGN KEY (alternative1) REFERENCES public.fournisseur(id_fournisseur);


--
-- TOC entry 4184 (class 2606 OID 17296)
-- Name: stock_piece_extra stock_piece_extra_alternative2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_alternative2_fkey FOREIGN KEY (alternative2) REFERENCES public.fournisseur(id_fournisseur);


--
-- TOC entry 4185 (class 2606 OID 17301)
-- Name: stock_piece_extra stock_piece_extra_alternative3_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_alternative3_fkey FOREIGN KEY (alternative3) REFERENCES public.fournisseur(id_fournisseur);


--
-- TOC entry 4186 (class 2606 OID 17281)
-- Name: stock_piece_extra stock_piece_extra_fabricant_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_fabricant_fkey FOREIGN KEY (fabricant) REFERENCES public.fabricant(id_fabricant);


--
-- TOC entry 4187 (class 2606 OID 17276)
-- Name: stock_piece_extra stock_piece_extra_id_piece_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_id_piece_fkey FOREIGN KEY (id_piece) REFERENCES public.piece(id_piece);


--
-- TOC entry 4188 (class 2606 OID 17286)
-- Name: stock_piece_extra stock_piece_extra_site_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.stock_piece_extra
    ADD CONSTRAINT stock_piece_extra_site_fkey FOREIGN KEY (site) REFERENCES public.site(id_site);


--
-- TOC entry 4136 (class 2606 OID 16463)
-- Name: utilisateur utilisateur_technicien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gmao_app_user
--

ALTER TABLE ONLY public.utilisateur
    ADD CONSTRAINT utilisateur_technicien_id_fkey FOREIGN KEY (technicien_id) REFERENCES public.technicien(id_technicien) ON DELETE SET NULL;


-- Completed on 2025-07-15 20:31:16

--
-- PostgreSQL database dump complete
--

