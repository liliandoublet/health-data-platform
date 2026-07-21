#!/usr/bin/env bash
# ============================================================
# Charge les CSV Synthea depuis le stage vers HEALTH_RAW.SYNTHEA.
# Meme mecanique que load_02_patients.sql, repetee par fichier :
#   1. INFER_SCHEMA devine la structure a partir du fichier
#   2. CREATE TABLE la cree
#   3. COPY INTO la remplit
# Rejouable : CREATE OR REPLACE ecrase et recharge proprement.
#
# supplies.csv est volontairement exclu : le fichier ne contient
# que sa ligne d'en-tetes, zero donnee. Rien a charger.
# ============================================================
set -euo pipefail

CONN="health_loader"

TABLES=(
  allergies careplans conditions devices encounters
  imaging_studies immunizations medications observations
  organizations patients payer_transitions payers
  procedures providers
)

for t in "${TABLES[@]}"; do
  echo ">>> ${t}"
  snow sql -c "${CONN}" --silent -q "
    USE ROLE LOADER;
    USE WAREHOUSE WH_HEALTH_XS;
    USE SCHEMA HEALTH_RAW.SYNTHEA;

    CREATE OR REPLACE TABLE ${t}
      USING TEMPLATE (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*)) WITHIN GROUP (ORDER BY ORDER_ID)
        FROM TABLE(
          INFER_SCHEMA(
            LOCATION    => '@STG_SYNTHEA/${t}.csv.gz',
            FILE_FORMAT => 'FF_SYNTHEA_CSV'
          )
        )
      );

    COPY INTO ${t}
      FROM @STG_SYNTHEA/${t}.csv.gz
      FILE_FORMAT = (FORMAT_NAME = 'FF_SYNTHEA_CSV')
      MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
      ON_ERROR = ABORT_STATEMENT;
  "
done

echo ">>> Termine."
