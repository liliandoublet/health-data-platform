with conditions as (

    select * from {{ ref('stg_conditions') }}

),

aggregated as (

    select
        patient_id,
        count(*)                                          as total_conditions,
        count(distinct condition_code)                    as distinct_conditions,
        sum(case when is_active then 1 else 0 end)        as active_conditions,
        min(onset_date)                                   as first_condition_date,
        max(onset_date)                                   as latest_condition_date

    from conditions
    group by patient_id

)

select * from aggregated
