-- ============================================================
-- load_02_patients.sql - Premiere table, en demonstration
-- ============================================================

USE ROLE LOADER;
USE WAREHOUSE WH_HEALTH_XS;
USE SCHEMA HEALTH_RAW.SYNTHEA;

-- La structure est deduite du fichier lui-meme (INFER_SCHEMA),
-- pas ecrite a la main. Zero colonne tapee, zero faute de frappe.
CREATE OR REPLACE TABLE PATIENTS
  USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*)) WITHIN GROUP (ORDER BY ORDER_ID)
    FROM TABLE(
      INFER_SCHEMA(
        LOCATION    => '@STG_SYNTHEA/patients.csv.gz',
        FILE_FORMAT => 'FF_SYNTHEA_CSV'
      )
    )
  );

-- MATCH_BY_COLUMN_NAME : les colonnes sont appariees par leur nom,
-- pas par leur position. Si Synthea change l'ordre des colonnes
-- un jour, le chargement continue de fonctionner.
COPY INTO PATIENTS
  FROM @STG_SYNTHEA/patients.csv.gz
  FILE_FORMAT = (FORMAT_NAME = 'FF_SYNTHEA_CSV')
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  ON_ERROR = ABORT_STATEMENT;
