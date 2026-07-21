with patients as (

    select * from {{ ref('stg_patients') }}

),

conditions as (

    select * from {{ ref('int_patient_condition_summary') }}

),

with_age as (

    select
        p.*,
        date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) as age_years,
        c.total_conditions,
        c.distinct_conditions,
        c.active_conditions

    from patients p
    left join conditions c on p.patient_id = c.patient_id

),

final as (

    select
        patient_id,
        gender,
        race,
        ethnicity,
        marital_status,
        birth_date,
        death_date,
        is_deceased,
        city,
        state,
        county,

        age_years,
        {{ age_band('age_years') }} as age_band,

        healthcare_expenses,
        healthcare_coverage,

        coalesce(total_conditions, 0)    as total_conditions,
        coalesce(distinct_conditions, 0) as distinct_conditions,
        coalesce(active_conditions, 0)   as active_conditions,
        coalesce(active_conditions, 0) >= 3 as is_polypathologic

    from with_age

)

select * from final
