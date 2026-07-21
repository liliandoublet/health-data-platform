with encounters as (

    select * from {{ ref('int_encounters_enriched') }}

),

final as (

    select
        encounter_id,

        patient_id,
        organization_id,
        provider_id,
        payer_id,

        cast(started_at as date)      as encounter_date,
        year(started_at)              as encounter_year,
        month(started_at)             as encounter_month,
        started_at,
        stopped_at,

        encounter_class,
        encounter_code,
        encounter_description,
        reason_code,
        reason_description,

        age_at_encounter,
        duration_minutes,
        has_invalid_timestamps,
        base_cost,
        total_claim_cost,
        payer_coverage,
        patient_out_of_pocket,

        case when encounter_class = 'emergency' then 1 else 0 end as is_emergency

    from encounters

)

select * from final
