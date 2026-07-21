-- Séjours dont l'admission suivante précède la sortie courante :
-- anomalie du générateur Synthea, exclue des calculs de réadmission.
-- On ne bloque pas (severity: warn) mais on surveille le VOLUME :
-- une hausse brutale signalerait une régression amont, pas un cas isolé.
-- Le test renvoie des lignes -> échoue si le taux dépasse le seuil.
{{ config(severity = 'warn') }}

with stats as (
    select
        count(*)                                          as total_stays,
        count_if(overlaps_next_stay)                      as overlapping_stays,
        count_if(overlaps_next_stay) / nullif(count(*), 0) as overlap_rate
    from {{ ref('fct_readmissions') }}
)
select
    total_stays,
    overlapping_stays,
    round(overlap_rate * 100, 1) as overlap_pct
from stats
where overlap_rate > 0.10   -- seuil : 10 %
