{#
    Tranche d'âge standardisée.
    Centralisé en macro pour garantir que dim_patients (âge courant)
    et fct_readmissions (âge au séjour) utilisent le même découpage.
#}
{% macro age_band(age_expression) %}
    case
        when {{ age_expression }} < 18 then '00-17'
        when {{ age_expression }} < 35 then '18-34'
        when {{ age_expression }} < 50 then '35-49'
        when {{ age_expression }} < 65 then '50-64'
        when {{ age_expression }} < 80 then '65-79'
        else '80+'
    end
{% endmacro %}
