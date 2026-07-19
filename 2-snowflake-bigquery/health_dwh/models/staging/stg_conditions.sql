with source as (
    select * from {{ source('synthea', 'conditions') }}
),
renamed as (
    select
        patient                 as patient_id,
        encounter               as encounter_id,
        code                    as condition_code,
        description             as condition_description,
        cast("START" as date)   as onset_date,
        cast("STOP" as date)    as resolved_date,
        "STOP" is null          as is_active
    from source
)
select * from renamed