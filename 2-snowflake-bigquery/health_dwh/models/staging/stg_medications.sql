with source as (
    select * from {{ source('synthea', 'medications') }}
),
renamed as (
    select
        patient                       as patient_id,
        encounter                     as encounter_id,
        payer                         as payer_id,
        code                          as medication_code,
        description                   as medication_description,
        cast(START as timestamp)      as started_at,
        cast(STOP as timestamp)       as stopped_at,
        cast(base_cost as float)      as base_cost,
        cast(payer_coverage as float) as payer_coverage,
        cast(dispenses as integer)    as dispenses,
        cast(totalcost as float)      as total_cost,
        reasoncode                    as reason_code,
        reasondescription             as reason_description
    from source
)
select * from renamed
