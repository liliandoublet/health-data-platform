with source as (
    select * from {{ source('synthea', 'encounters') }}
),
renamed as (
    select
        id                                 as encounter_id,
        patient                            as patient_id,
        organization                       as organization_id,
        provider                           as provider_id,
        payer                              as payer_id,
        encounterclass                     as encounter_class,
        code                               as encounter_code,
        description                        as encounter_description,
        cast("START" as timestamp)         as started_at,
        cast("STOP" as timestamp)          as stopped_at,
        cast(base_encounter_cost as float) as base_cost,
        cast(total_claim_cost as float)    as total_claim_cost,
        cast(payer_coverage as float)      as payer_coverage,
        reasoncode                         as reason_code,
        reasondescription                  as reason_description
    from source
)
select * from renamed
