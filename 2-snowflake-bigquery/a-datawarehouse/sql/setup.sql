-- ============================================================
-- setup.sql — infrastructure Snowflake de health-data-platform
-- Rôle requis : ACCOUNTADMIN
-- Idempotent : rejouable sur un compte neuf sans modification.
-- Les clés publiques RSA sont injectées par make-setup-local.sh
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ------------------------------------------------------------
-- 1. Garde-fou crédits
--    Le trial n'est pas limité par l'argent mais par le temps.
--    Ce monitor protège surtout d'une erreur (warehouse oublié,
--    requête en boucle), pas du budget nominal.
-- ------------------------------------------------------------
CREATE OR REPLACE RESOURCE MONITOR RM_HEALTH
  WITH CREDIT_QUOTA = 50
       FREQUENCY = MONTHLY
       START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 50  PERCENT DO NOTIFY
    ON 80  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- ------------------------------------------------------------
-- 2. Compute
--    XSMALL = 1 crédit/heure. AUTO_SUSPEND à 60s : le warehouse
--    s'éteint une minute après la dernière requête.
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS WH_HEALTH_XS
  WITH WAREHOUSE_SIZE = 'XSMALL'
       AUTO_SUSPEND = 60
       AUTO_RESUME = TRUE
       INITIALLY_SUSPENDED = TRUE
       COMMENT = 'Compute unique du projet : chargement + dbt';

ALTER WAREHOUSE WH_HEALTH_XS SET RESOURCE_MONITOR = RM_HEALTH;
-- Filet de sécurité : aucune requête ne peut tourner plus de 10 min
ALTER WAREHOUSE WH_HEALTH_XS SET STATEMENT_TIMEOUT_IN_SECONDS = 600;

-- ------------------------------------------------------------
-- 3. Stockage
--    Séparation RAW / ANALYTICS : la donnée brute est immuable,
--    dbt ne peut pas la corrompre.
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS HEALTH_RAW
  COMMENT = 'Donnees brutes Synthea, chargees sans transformation';
CREATE SCHEMA IF NOT EXISTS HEALTH_RAW.SYNTHEA;

CREATE DATABASE IF NOT EXISTS HEALTH_ANALYTICS
  COMMENT = 'Modeles dbt : staging / intermediate / marts';

-- ------------------------------------------------------------
-- 4. Rôles fonctionnels
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS LOADER
  COMMENT = 'Ecrit dans RAW. Aucun acces a ANALYTICS.';
CREATE ROLE IF NOT EXISTS TRANSFORMER
  COMMENT = 'Lit RAW en seule lecture, ecrit dans ANALYTICS.';

GRANT ROLE LOADER      TO ROLE SYSADMIN;
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;

-- LOADER
GRANT USAGE ON WAREHOUSE WH_HEALTH_XS TO ROLE LOADER;
GRANT USAGE ON DATABASE HEALTH_RAW TO ROLE LOADER;
GRANT USAGE, CREATE TABLE, CREATE STAGE, CREATE FILE FORMAT
  ON SCHEMA HEALTH_RAW.SYNTHEA TO ROLE LOADER;

-- TRANSFORMER : lecture seule sur RAW ...
GRANT USAGE ON WAREHOUSE WH_HEALTH_XS TO ROLE TRANSFORMER;
GRANT USAGE ON DATABASE HEALTH_RAW TO ROLE TRANSFORMER;
GRANT USAGE ON SCHEMA HEALTH_RAW.SYNTHEA TO ROLE TRANSFORMER;
GRANT SELECT ON ALL TABLES    IN SCHEMA HEALTH_RAW.SYNTHEA TO ROLE TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_RAW.SYNTHEA TO ROLE TRANSFORMER;

-- ... et pleins pouvoirs sur ANALYTICS (dbt cree ses propres schemas)
GRANT USAGE, CREATE SCHEMA ON DATABASE HEALTH_ANALYTICS TO ROLE TRANSFORMER;

-- ------------------------------------------------------------
-- 5. Service users
--    TYPE = SERVICE : ces users NE PEUVENT PAS avoir de mot de
--    passe ni se connecter a l'UI. Auth key-pair uniquement.
--    C'est la reponse a la fin de l'auth mono-facteur (nov. 2025).
-- ------------------------------------------------------------
CREATE USER IF NOT EXISTS SVC_LOADER
  TYPE = SERVICE
  DEFAULT_ROLE = LOADER
  DEFAULT_WAREHOUSE = WH_HEALTH_XS
  COMMENT = 'Connexion depuis dbt platform';

ALTER USER SVC_LOADER SET RSA_PUBLIC_KEY='{{RSA_PUBLIC_KEY_LOADER}}';
ALTER USER SVC_DBT    SET RSA_PUBLIC_KEY='{{RSA_PUBLIC_KEY_DBT}}';

GRANT ROLE LOADER      TO USER SVC_LOADER;
GRANT ROLE TRANSFORMER TO USER SVC_DBT;

-- ------------------------------------------------------------
-- 6. Droits de TRANSFORMER a l'interieur d'ANALYTICS
--    USAGE sur la base ne suffit pas : il faut aussi les droits
--    sur les schemas. FUTURE SCHEMAS couvre ceux que dbt va
--    creer lui-meme plus tard, sans avoir a repasser ici.
-- ------------------------------------------------------------
GRANT ALL ON DATABASE HEALTH_ANALYTICS TO ROLE TRANSFORMER;
GRANT ALL ON ALL SCHEMAS    IN DATABASE HEALTH_ANALYTICS TO ROLE TRANSFORMER;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE HEALTH_ANALYTICS TO ROLE TRANSFORMER;
