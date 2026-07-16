with encounters as (

    select * from {{ ref('int_encounters_enriched') }}
    where encounter_class = 'inpatient'

),

sequenced as (

    select
        encounter_id,
        patient_id,
        organization_id,
        encounter_code,
        started_at             as admitted_at,
        stopped_at             as discharged_at,
        duration_minutes,
        has_invalid_timestamps,
        age_at_encounter,
        total_claim_cost,

        row_number() over (
            partition by patient_id order by started_at
        ) as stay_sequence,

        lead(encounter_id) over (
            partition by patient_id order by started_at
        ) as next_stay_id,

        lead(started_at) over (
            partition by patient_id order by started_at
        ) as next_admitted_at,

        -- Le caractère programmé s'apprécie sur la réadmission,
        -- pas sur le séjour index : on remonte le code du séjour suivant.
        lead(encounter_code) over (
            partition by patient_id order by started_at
        ) as next_encounter_code

    from encounters

)

select * from sequenced
