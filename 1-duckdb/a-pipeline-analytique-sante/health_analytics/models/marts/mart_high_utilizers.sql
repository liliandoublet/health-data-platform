with stays as (

    select * from {{ ref('fct_readmissions') }}
    where is_eligible_index_stay

),

patients as (

    select * from {{ ref('dim_patients') }}

),

per_patient as (

    select
        patient_id,
        count(*)                                            as inpatient_stays,
        sum(case when is_readmitted_30d then 1 else 0 end)  as readmissions_30d,
        round(avg(days_to_readmission), 1)                  as avg_days_between_stays,
        median(days_to_readmission)                         as median_days_between_stays,
        round(sum(total_claim_cost), 2)                     as total_inpatient_cost,
        min(admitted_date)                                  as first_admission,
        max(discharged_date)                                as last_discharge

    from stays
    group by patient_id

),

final as (

    select
        pp.patient_id,

        p.gender,
        p.age_band,
        p.state,
        p.is_deceased,
        p.total_conditions,
        p.active_conditions,
        p.is_polypathologic,

        pp.inpatient_stays,
        pp.readmissions_30d,
        pp.avg_days_between_stays,
        pp.median_days_between_stays,
        pp.total_inpatient_cost,
        pp.first_admission,
        pp.last_discharge,

        -- Seuil de 10 séjours : convention interne, pas un standard.
        -- Isole les patients dont la récurrence relève du suivi chronique
        -- plutôt que de l'épisode aigu.
        pp.inpatient_stays >= 10 as is_high_utilizer,

        round(
            100.0 * pp.readmissions_30d / nullif(pp.inpatient_stays, 0), 2
        ) as personal_readmission_rate_pct

    from per_patient pp
    inner join patients p on pp.patient_id = p.patient_id

)

select * from final
