-- ============================================================
-- fct_encounters_stream : log CDC des encounters captes en
-- near-real-time via un Snowflake Stream.
--
-- MECANIQUE (le 2e mecanisme near-real-time de la 2b, complementaire
-- de la Dynamic Table) :
--  - pre_hook cree un STREAM sur RAW.ENCOUNTERS (idempotent). Le
--    stream retient un offset et expose les lignes ajoutees depuis.
--  - materialized=incremental + append : chaque `dbt run` fait
--    insert-select DEPUIS le stream. La lecture en DML avance
--    l'offset dans la meme transaction -> consommation atomique,
--    zero perte si le run echoue.
--  - Pas de is_incremental() : le stream ne rend QUE le delta.
--
-- Colonnes METADATA$ du stream :
--  - METADATA$ACTION   : INSERT / DELETE
--  - METADATA$ISUPDATE : TRUE si la ligne fait partie d'un UPDATE
--    (represente en DELETE+INSERT). Ici on n'insere que -> INSERT.
--
-- Pattern reutilise tel quel en partie 3 pour consumer les vitals
-- Kafka atterris dans le meme RAW : batch -> near-real-time -> streaming.
-- ============================================================
{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        snowflake_warehouse='WH_HEALTH_XS',
        pre_hook="create stream if not exists {{ this.schema }}.strm_encounters_raw on table HEALTH_RAW.SYNTHEA.ENCOUNTERS"
    )
}}

select
    "Id"                as encounter_id,
    "PATIENT"           as patient_id,
    "ORGANIZATION"      as organization_id,
    "ENCOUNTERCLASS"    as encounter_class,
    "START"             as started_at,
    "TOTAL_CLAIM_COST"  as total_claim_cost,
    metadata$action     as cdc_action,
    metadata$isupdate   as cdc_is_update,
    current_timestamp() as _captured_at
from {{ this.schema }}.strm_encounters_raw
