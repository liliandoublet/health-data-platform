with encounters as (
    select * from {{ ref('stg_encounters') }}
),
patients as (
    select * from {{ ref('stg_patients') }}
),
joined as (
    select
        e.encounter_id,
        e.patient_id,
        e.organization_id,
        e.provider_id,
        e.payer_id,
        e.encounter_class,
        e.encounter_code,
        e.encounter_description,
        e.started_at,
        e.stopped_at,
        e.base_cost,
        e.total_claim_cost,
        e.payer_coverage,
        e.total_claim_cost - e.payer_coverage as patient_out_of_pocket,
        e.reason_code,
        e.reason_description,

        -- Anomalie source : certains encounters ont un stop antérieur au start.
        -- On neutralise la durée plutôt que de propager une valeur aberrante,
        -- et on trace le cas via has_invalid_timestamps.
        case
            when e.stopped_at >= e.started_at
                then {{ dbt.datediff('e.started_at', 'e.stopped_at', 'minute') }}
        end as duration_minutes,

        e.stopped_at < e.started_at as has_invalid_timestamps,

        {{ dbt.datediff('p.birth_date', 'cast(e.started_at as date)', 'year') }} as age_at_encounter,

        p.gender,
        p.race,
        p.ethnicity,
        p.state as patient_state

    from encounters e
    inner join patients p on e.patient_id = p.patient_id
)
select * from joined
