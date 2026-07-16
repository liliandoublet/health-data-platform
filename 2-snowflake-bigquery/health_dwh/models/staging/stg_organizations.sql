with source as (

    select * from {{ source('synthea', 'organizations') }}

),

renamed as (

    select
        id                          as organization_id,
        name                        as organization_name,
        city,
        state,
        zip,
        cast(revenue as double)     as revenue,
        cast(utilization as integer) as utilization

    from source

)

select * from renamed
