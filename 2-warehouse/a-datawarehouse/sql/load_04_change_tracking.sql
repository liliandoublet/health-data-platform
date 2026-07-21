-- ============================================================
-- load_04_change_tracking.sql
-- Active le change tracking sur les tables RAW consommees en
-- near-real-time (Streams 2b + Dynamic Tables + vitals Kafka).
--
-- Role requis : LOADER. Seul le proprietaire d'une table peut y
-- activer le change tracking (OWNERSHIP) -> ce n'est donc PAS dans
-- setup.sql (qui tourne en ACCOUNTADMIN, avant que RAW existe sur
-- un compte neuf). Ici les tables existent : le load est passe.
--
-- Idempotent : SET CHANGE_TRACKING = TRUE sur une table deja
-- suivie est un no-op sans erreur. Rejouable a volonte.
--
-- Portee : les 9 sources declarees dans health_dwh/models/sources.yml.
-- Les 6 autres tables RAW chargees mais non modelisees sont
-- volontairement exclues (rien ne les lit).
-- ============================================================

USE ROLE LOADER;
USE DATABASE HEALTH_RAW;
USE SCHEMA SYNTHEA;

ALTER TABLE ENCOUNTERS     SET CHANGE_TRACKING = TRUE;
ALTER TABLE PATIENTS       SET CHANGE_TRACKING = TRUE;
ALTER TABLE CONDITIONS     SET CHANGE_TRACKING = TRUE;
ALTER TABLE MEDICATIONS    SET CHANGE_TRACKING = TRUE;
ALTER TABLE OBSERVATIONS   SET CHANGE_TRACKING = TRUE;
ALTER TABLE PROCEDURES     SET CHANGE_TRACKING = TRUE;
ALTER TABLE ORGANIZATIONS  SET CHANGE_TRACKING = TRUE;
ALTER TABLE PROVIDERS      SET CHANGE_TRACKING = TRUE;
ALTER TABLE PAYERS         SET CHANGE_TRACKING = TRUE;
