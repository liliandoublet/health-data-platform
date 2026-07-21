with readmissions as (

    select * from {{ ref('fct_readmissions') }}
    where is_eligible_index_stay

),

encounters as (

    select * from {{ ref('fct_encounters') }}

),

organizations as (

    select * from {{ ref('dim_organizations') }}

),

readmission_stats as (

    select
        organization_id,
        count(*)                                                        as eligible_stays,
        sum(case when is_readmitted_30d then 1 else 0 end)              as readmissions_30d,
        sum(case when is_readmitted_30d_unplanned then 1 else 0 end)    as readmissions_30d_unplanned,
        round(100.0 * sum(case when is_readmitted_30d then 1 else 0 end) / count(*), 2)
            as readmission_rate_30d_pct,
        round(100.0 * sum(case when is_readmitted_30d_unplanned then 1 else 0 end) / count(*), 2)
            as readmission_rate_30d_unplanned_pct,
        round(avg(days_to_readmission), 1)                              as avg_days_to_readmission,
        round(avg(total_claim_cost), 2)                                 as avg_stay_cost

    from readmissions
    group by organization_id

),

activity_stats as (

    select
        organization_id,
        count(*)                                            as total_encounters,
        count(distinct patient_id)                          as distinct_patients,
        sum(is_emergency)                                   as emergency_encounters,
        round(100.0 * sum(is_emergency) / count(*), 2)      as emergency_share_pct,
        round(avg(duration_minutes), 1)                     as avg_duration_minutes,
        round(sum(total_claim_cost), 2)                     as total_claim_cost,
        round(sum(patient_out_of_pocket), 2)                as total_out_of_pocket

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

        coalesce(r.eligible_stays, 0)              as eligible_inpatient_stays,
        coalesce(r.readmissions_30d, 0)            as readmissions_30d,
        coalesce(r.readmissions_30d_unplanned, 0)  as readmissions_30d_unplanned,
        r.readmission_rate_30d_pct,
        r.readmission_rate_30d_unplanned_pct,
        r.avg_days_to_readmission,
        r.avg_stay_cost

    from organizations o
    left join activity_stats a    on o.organization_id = a.organization_id
    left join readmission_stats r on o.organization_id = r.organization_id

)

select * from final
