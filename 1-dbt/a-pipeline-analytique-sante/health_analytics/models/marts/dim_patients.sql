with patients as (

    select * from {{ ref('stg_patients') }}

),

conditions as (

    select * from {{ ref('int_patient_condition_summary') }}

),

final as (

    select
        p.patient_id,
        p.gender,
        p.race,
        p.ethnicity,
        p.marital_status,
        p.birth_date,
        p.death_date,
        p.is_deceased,
        p.city,
        p.state,
        p.county,

        date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) as age_years,

        case
            when date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) < 18 then '00-17'
            when date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) < 35 then '18-34'
            when date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) < 50 then '35-49'
            when date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) < 65 then '50-64'
            when date_diff('year', p.birth_date, coalesce(p.death_date, current_date)) < 80 then '65-79'
            else '80+'
        end as age_band,

        p.healthcare_expenses,
        p.healthcare_coverage,

        coalesce(c.total_conditions, 0)    as total_conditions,
        coalesce(c.distinct_conditions, 0) as distinct_conditions,
        coalesce(c.active_conditions, 0)   as active_conditions,
        coalesce(c.active_conditions, 0) >= 3 as is_polypathologic

    from patients p
    left join conditions c on p.patient_id = c.patient_id

)

select * from final
