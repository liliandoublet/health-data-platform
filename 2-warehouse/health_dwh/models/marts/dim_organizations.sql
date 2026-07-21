select
    organization_id,
    organization_name,
    city,
    state,
    zip,
    revenue,
    utilization

from {{ ref('stg_organizations') }}
