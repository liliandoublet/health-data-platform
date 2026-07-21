with source as (

    select * from {{ source('synthea', 'medications') }}

),

renamed as (

    select
        patient                        as patient_id,
        encounter                      as encounter_id,
        payer                          as payer_id,
        code                           as medication_code,
        description                    as medication_description,
        cast("start" as timestamp)     as started_at,
        cast("stop" as timestamp)      as stopped_at,
        cast(base_cost as double)      as base_cost,
        cast(payer_coverage as double) as payer_coverage,
        cast(dispenses as integer)     as dispenses,
        cast(totalcost as double)      as total_cost,
        reasoncode                     as reason_code,
        reasondescription              as reason_description

    from source

)

select * from renamed
