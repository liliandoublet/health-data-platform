-- ============================================================
-- mart_organization_kpis_rt : version near-real-time (Dynamic Table)
-- du mart d'activite par organisation.
--
-- CONTRASTE avec le batch mart_organization_kpis :
--  - Source les VUES stg/int (int_encounters_enriched -> stg -> RAW),
--    pas les marts tables batch. La lignee traverse jusqu'a
--    HEALTH_RAW.SYNTHEA.ENCOUNTERS ou le change tracking est actif
--    -> la DT capte les nouvelles lignes en near-real-time.
--  - PERIMETRE : activite uniquement. Les readmissions 30j sont une
--    metrique retrospective (fenetre glissante) : aucun sens en
--    near-real-time -> elles restent dans le mart batch.
--  - dim_organizations (table batch, SCD) jointe telle quelle : la
--    fraicheur est pilotee par la source la plus vive (les encounters).
--
-- REFRESH_MODE = FULL : impose par count(distinct patient_id) et
-- current_timestamp() (non incrementalisables). Assume, pas subi :
-- 53k lignes, full refresh trivial.
--
-- COUT : target_lag 1 min, mais le warehouse ne reprend QUE si RAW
-- change (Cloud Services skip si aucun delta). Au repos = 0 credit.
-- Workflow demo : dbt run -> simuler des lignes -> observer les
-- refreshes dans Snowsight -> ALTER DYNAMIC TABLE ... SUSPEND.
-- ============================================================
{{
    config(
        materialized='dynamic_table',
        snowflake_warehouse='WH_HEALTH_XS',
        target_lag='1 minute',
        refresh_mode='FULL',
        on_configuration_change='apply'
    )
}}

with encounters as (
    select * from {{ ref('int_encounters_enriched') }}
),

organizations as (
    select * from {{ ref('dim_organizations') }}
),

activity_stats as (
    select
        organization_id,
        count(*)                                                       as total_encounters,
        count(distinct patient_id)                                     as distinct_patients,
        sum(case when encounter_class = 'emergency' then 1 else 0 end) as emergency_encounters,
        round(100.0 * sum(case when encounter_class = 'emergency' then 1 else 0 end)
              / nullif(count(*), 0), 2)                                as emergency_share_pct,
        round(avg(duration_minutes), 1)                                as avg_duration_minutes,
        round(sum(total_claim_cost), 2)                                as total_claim_cost,
        round(sum(patient_out_of_pocket), 2)                           as total_out_of_pocket
    from encounters
    group by organization_id
),

final as (
    select
        o.organization_id,
        o.organization_name,
        o.city,
        o.state,
        a.total_encounters,
        a.distinct_patients,
        a.emergency_encounters,
        a.emergency_share_pct,
        a.avg_duration_minutes,
        a.total_claim_cost,
        a.total_out_of_pocket,
        -- Rend la fraicheur visible : ce timestamp avance a chaque
        -- refresh declenche par un changement dans RAW. Preuve
        -- tangible du near-real-time dans les screenshots Snowsight.
        current_timestamp()                                            as _dt_refreshed_at
    from organizations o
    left join activity_stats a on o.organization_id = a.organization_id
)

select * from final
