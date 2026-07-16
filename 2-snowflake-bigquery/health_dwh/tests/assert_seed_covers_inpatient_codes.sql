-- Tout code d'admission inpatient doit exister dans le référentiel de
-- classification. Sinon il bascule silencieusement en "non programmé"
-- par le coalesce, et le taux est faussé sans qu'aucun test ne réagisse.
-- Ce test protège contre l'apparition de nouveaux codes en amont.

select distinct
    e.encounter_code,
    e.encounter_description,
    count(*) over (partition by e.encounter_code) as occurrences

from {{ ref('fct_encounters') }} e
left join {{ ref('seed_encounter_planned_classification') }} s
    on e.encounter_code = s.encounter_code

where e.encounter_class = 'inpatient'
  and s.encounter_code is null
