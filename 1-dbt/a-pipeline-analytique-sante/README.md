# Pipeline analytique santé — dbt + DuckDB

Pipeline de transformation analytique sur données de santé synthétiques
(Synthea / MITRE), modélisé en couches staging → intermediate → marts,
avec 50 tests de qualité et une table de faits orientée réadmission
hospitalière à 30 jours.

![Lineage graph](docs/lineage-graph.png)

---

## Stack

| Composant | Rôle |
|---|---|
| dbt Core 1.11 | Transformation, tests, documentation |
| DuckDB 1.10 | Moteur analytique embarqué, lecture CSV directe |
| uv | Gestion des dépendances et de l'environnement Python |
| dbt_utils | Tests génériques additionnels |

Aucun entrepôt cloud requis : le pipeline tourne intégralement en local.

---

## Démarrage

```bash
# Environnement
uv sync

# Données sources (~1000 patients synthétiques)
mkdir -p ../../data/raw && cd ../../data/raw
curl -LO https://synthetichealth.github.io/synthea-sample-data/downloads/synthea_sample_data_csv_apr2020.zip
unzip synthea_sample_data_csv_apr2020.zip

# Pipeline
cd -/health_analytics
uv run dbt deps
uv run dbt build

# Documentation et lineage
uv run dbt docs generate && uv run dbt docs serve
```

---

## Architecture

**Sources** — Les CSV Synthea sont lus directement par DuckDB via
`external_location`, sans étape de chargement préalable.

**Staging** (5 vues) — Renommage, typage explicite, sélection.
Les colonnes directement identifiantes (SSN, nom, adresse, coordonnées
GPS) sont écartées dès cette couche : sur de la donnée de santé, la
minimisation s'applique au plus tôt, même sur du synthétique.

**Intermediate** (3 vues) — Enrichissement et calculs intermédiaires :
âge à la date du séjour, durée réelle, reste à charge patient,
séquencement des séjours hospitaliers par `lead()`.

**Marts** (5 tables) — Schéma en étoile.

| Modèle | Grain | Contenu |
|---|---|---|
| `dim_patients` | 1 patient | Démographie + charge pathologique |
| `dim_organizations` | 1 établissement | Référentiel établissements |
| `fct_encounters` | 1 consultation | Table de faits principale |
| `fct_readmissions` | 1 séjour hospitalier | Indicateur de réadmission 30j |
| `mart_organization_kpis` | 1 établissement | Indicateurs de pilotage |

---

## Points techniques

**Window functions** — `fct_readmissions` s'appuie sur `lead()` partitionné
par patient pour rattacher chaque séjour au suivant, sans self-join.

**Macro** — `age_band()` centralise le découpage des tranches d'âge, garantissant
que la dimension patient (âge courant) et la table de faits (âge au séjour)
utilisent le même référentiel.

**Seed** — `seed_encounter_planned_classification` versionne dans Git la
classification programmé / non programmé des types d'admission, avec la
justification métier de chaque décision en colonne.

**Test singulier** — `assert_seed_covers_inpatient_codes` vérifie que tout
code d'admission existe dans le référentiel. Sans lui, un nouveau code
basculerait silencieusement en « non programmé » par défaut.

---

## Qualité des données

50 tests, dont 2 anomalies sources tracées en `severity: warn` : elles
restent visibles à chaque run sans bloquer le pipeline.

| Anomalie | Traitement |
|---|---|
| Horodatages incohérents (`stop` < `start`) | Durée forcée à NULL, drapeau `has_invalid_timestamps` |
| Séjours qui se chevauchent (120 cas) | Exclus du dénominateur, drapeau `overlaps_next_stay` |

Les décès survenus pendant le séjour index sont également exclus du
dénominateur : un patient décédé ne peut pas être réadmis, et le compter
pénaliserait l'établissement à tort.

---

## Résultats

Sur 1 712 séjours hospitaliers éligibles :

| Tranche d'âge au séjour | Séjours | Réadmissions | Taux |
|---|---|---|---|
| 00-17 | 249 | 74 | 29,7 % |
| 18-34 | 220 | 11 | 5,0 % |
| 35-49 | 216 | 51 | 23,6 % |
| 50-64 | 585 | 278 | 47,5 % |
| 65-79 | 328 | 141 | 43,0 % |
| 80+ | 114 | 44 | 38,6 % |
| **Global** | **1 712** | **599** | **35,0 %** |

Le gradient par âge suit la direction attendue cliniquement : minimal
chez les jeunes adultes, maximal après 50 ans.

---

## Limites

**Le taux global de 35 % n'est pas cliniquement interprétable.** Le
benchmark réel du secteur se situe autour de 15 %. Trois raisons :

1. **Concentration extrême** — 29 patients produisent les 599 réadmissions,
   soit 20,7 chacun. L'indicateur agrégé mesure le comportement d'une
   poignée de patients en suivi chronique, pas celui de la population.

2. **Cadence, pas réadmission** — L'intervalle médian entre deux séjours
   du code dominant est de 28 jours. Une régularité mensuelle signale un
   protocole de suivi programmé, non une réadmission non planifiée.

3. **Générateur non discriminant** — 98,5 % des réadmissions portent le
   même code générique (`185347001`, « Encounter for problem »). Synthea
   ne modélise pas la distinction admission planifiée / non planifiée,
   la classification par type d'admission reste donc sans effet
   (34,99 % → 34,93 %).

**L'algorithme CMS n'est pas implémenté.** Le *Planned Readmission
Algorithm* officiel classe sur les procédures réalisées (catégories
AHRQ-CCS), non sur le type d'encounter. L'approche retenue ici est une
approximation, avec défaut conservateur : en cas de doute, le séjour est
compté comme non programmé.

Ces limites tiennent au générateur de données, non au pipeline. Sur des
données hospitalières réelles disposant du champ « admission planifiée »
et des codes de procédures, la même architecture produirait un
indicateur exploitable.

---

## Structure
a-pipeline-analytique-sante/
├── pyproject.toml, uv.lock       # Environnement reproductible
├── docs/                          # Captures
└── health_analytics/
├── dbt_project.yml
├── profiles.yml               # Profil DuckDB embarqué dans le repo
├── packages.yml
├── macros/age_band.sql
├── seeds/                     # Référentiel de classification
├── tests/                     # Tests singuliers
└── models/
├── sources.yml
├── staging/
├── intermediate/
└── marts/
