-- ============================================================
-- load_01_stage.sql - Zone de depot + notice de lecture CSV
-- Execute par : SVC_LOADER (role LOADER)
-- ============================================================

USE ROLE LOADER;
USE WAREHOUSE WH_HEALTH_XS;
USE SCHEMA HEALTH_RAW.SYNTHEA;

-- Le sas : les fichiers y atterrissent avant d'entrer en table.
CREATE STAGE IF NOT EXISTS STG_SYNTHEA
  COMMENT = 'Depot des CSV Synthea bruts';

-- La notice de lecture.
--   PARSE_HEADER          : la 1re ligne = les noms de colonnes
--   FIELD_OPTIONALLY_...  : les champs peuvent etre entre guillemets
--   EMPTY_FIELD_AS_NULL   : une case vide devient NULL, pas ""
CREATE OR REPLACE FILE FORMAT FF_SYNTHEA_CSV
  TYPE = CSV
  PARSE_HEADER = TRUE
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  TRIM_SPACE = FALSE
  COMPRESSION = AUTO;
