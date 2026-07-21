with stays as (

    select * from {{ ref('int_inpatient_stays') }}

),

patients as (

    select patient_id, death_date, gender, state
    from {{ ref('dim_patients') }}

),

planned_codes as (

    select * from {{ ref('seed_encounter_planned_classification') }}

),

joined as (

    select
        s.encounter_id                    as index_stay_id,
        s.patient_id,
        s.organization_id,
        s.stay_sequence,

        cast(s.admitted_at as date)       as admitted_date,
        cast(s.discharged_at as date)     as discharged_date,

        s.age_at_encounter,
        {{ age_band('s.age_at_encounter') }} as age_band_at_stay,

        s.total_claim_cost,

        s.next_stay_id                    as readmission_stay_id,
        cast(s.next_admitted_at as date)  as readmitted_date,
        s.next_encounter_code             as readmission_encounter_code,

        -- Défaut non programmé si le code est absent du référentiel.
        coalesce(pc.is_planned, false)    as is_planned_readmission,

        coalesce(s.next_admitted_at < s.discharged_at, false)
            as overlaps_next_stay,

        case
            when s.next_admitted_at >= s.discharged_at
                then {{ dbt.datediff('s.discharged_at', 's.next_admitted_at', 'day') }}
        end as days_to_readmission,

        p.gender,
        p.state,
        p.death_date,

        coalesce(p.death_date <= cast(s.discharged_at as date), false)
            as died_during_index_stay,

        s.has_invalid_timestamps

    from stays s
    inner join patients p      on s.patient_id = p.patient_id
    left join planned_codes pc on s.next_encounter_code = pc.encounter_code

),

final as (

    select
        *,

        not died_during_index_stay
            and not has_invalid_timestamps
            and not overlaps_next_stay
            and discharged_date is not null
            as is_eligible_index_stay,

        -- Toutes causes : réadmission quelle qu'en soit la nature.
        coalesce(
            not died_during_index_stay
            and not has_invalid_timestamps
            and not overlaps_next_stay
            and days_to_readmission between 0 and 30,
            false
        ) as is_readmitted_30d,

        -- Non programmée : approximation de la logique CMS. Les réadmissions
        -- programmées sortent du numérateur, mais le séjour index reste au
        -- dénominateur — l'exclusion n'est volontairement pas symétrique.
        coalesce(
            not died_during_index_stay
            and not has_invalid_timestamps
            and not overlaps_next_stay
            and not coalesce(is_planned_readmission, false)
            and days_to_readmission between 0 and 30,
            false
        ) as is_readmitted_30d_unplanned

    from joined

)

select * from final
