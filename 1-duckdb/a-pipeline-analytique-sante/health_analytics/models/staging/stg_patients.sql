with source as (

    select * from {{ source('synthea', 'patients') }}

),

renamed as (

    select
        id                                  as patient_id,
        cast(birthdate as date)             as birth_date,
        cast(deathdate as date)             as death_date,
        deathdate is not null               as is_deceased,
        gender,
        race,
        ethnicity,
        marital                             as marital_status,
        city,
        state,
        county,
        zip,
        cast(healthcare_expenses as double) as healthcare_expenses,
        cast(healthcare_coverage as double) as healthcare_coverage

    from source

)

select * from renamed
