-- Le sous-ensemble non programmé ne peut pas excéder l'ensemble toutes causes.
-- Si ce test casse, la logique d'exclusion est inversée quelque part.

select
    organization_id,
    readmission_rate_30d_pct,
    readmission_rate_30d_unplanned_pct

from {{ ref('mart_organization_kpis') }}

where readmission_rate_30d_unplanned_pct > readmission_rate_30d_pct
