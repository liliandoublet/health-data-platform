# 2 — Snowflake Data Warehouse (`a-datawarehouse`)

Portage du pipeline analytique santé de la partie 1 (dbt Core + DuckDB, local)
vers un entrepôt cloud managé **Snowflake**, orchestré par **dbt platform**.

Même modèle métier, moteur différent. L'objet de cette partie est de montrer ce
que le passage au cloud change réellement : sécurité, séparation des rôles,
chargement, portage SQL, et coûts.

---

## 1. Architecture

```
CSV Synthea (local)
      │  snow CLI : PUT + COPY INTO   (service user SVC_LOADER, rôle LOADER)
      ▼
┌─────────────────────────┐
│ HEALTH_RAW.SYNTHEA      │  15 tables brutes, chargées sans transformation
│ (données immuables)     │  structure déduite par INFER_SCHEMA
└───────────┬─────────────┘
            │  dbt (service user SVC_DBT, rôle TRANSFORMER, lecture seule sur RAW)
            ▼
┌─────────────────────────┐
│ HEALTH_ANALYTICS        │
│  staging   (5 vues)     │  renommage, typage, sélection de colonnes
│  intermediate (3 vues)  │  enrichissement, jointures, calculs de durée
│  marts     (6 tables)   │  dimensions + faits + KPI
└─────────────────────────┘
```

Séparation volontaire **RAW / ANALYTICS** : la donnée brute est immuable et
`TRANSFORMER` n'y a qu'un accès en lecture. dbt ne peut pas corrompre la source ;
en cas de bug, on reconstruit les modèles sans recharger.

---

## 2. Sécurité — authentification par paire de clés

Depuis novembre 2025, Snowflake bloque l'authentification par simple mot de passe,
y compris pour les comptes de service. Toute l'automatisation repose donc sur
une **authentification RSA key-pair**.

Deux comptes de service distincts, selon le principe de moindre privilège :

| Service user | Rôle          | Droits                                   | Utilisé par        |
|--------------|---------------|------------------------------------------|--------------------|
| `SVC_LOADER` | `LOADER`      | écrit dans `HEALTH_RAW`, aucun accès ANALYTICS | Snowflake CLI (chargement) |
| `SVC_DBT`    | `TRANSFORMER` | lecture seule sur RAW, écrit dans ANALYTICS    | dbt platform       |

Deux identités plutôt qu'un compte passe-partout : une clé compromise côté SaaS
(dbt) ne peut pas altérer la donnée brute. Les clés privées vivent hors du dépôt
(`~/.snowflake/keys`, `.gitignore`) ; seules les clés publiques sont injectées
dans Snowflake via `ALTER USER ... SET RSA_PUBLIC_KEY`.

> **Note de rotation** — la paire initiale a été générée avec une passphrase
> faible en phase de mise au point. En usage réel, régénérer les clés avec une
> passphrase conforme PCI DSS et repasser la passphrase en variable
> d'environnement plutôt qu'en clair dans `connections.toml`.

---

## 3. Infrastructure as code

Tout l'entrepôt est reconstructible depuis le dépôt, sans clic dans l'interface
(hormis la toute première création des service users, contrainte œuf-et-poule).

| Fichier                    | Rôle                                                        |
|----------------------------|-------------------------------------------------------------|
| `sql/setup.sql`            | resource monitor, warehouse XS, bases, schémas, rôles, grants, service users. Idempotent. |
| `sql/make-setup-local.sh`  | injecte les clés publiques RSA dans une copie locale non versionnée (`setup.local.sql`). |
| `sql/load_01_stage.sql`    | stage interne + file format CSV Synthea.                    |
| `sql/load_03_all.sh`       | boucle INFER_SCHEMA → CREATE TABLE → COPY INTO sur 15 tables. |

Garde-fous coût : warehouse **XSMALL** (1 crédit/h), `AUTO_SUSPEND = 60s`,
`STATEMENT_TIMEOUT = 600s`, resource monitor qui suspend à 100 % du quota.

---

## 4. Chargement

Les CSV Synthea sont poussés vers un stage interne (`PUT` avec compression
automatique — ex. `observations.csv` : 43 Mo → 2,7 Mo), puis chargés par
`COPY INTO`. La structure des tables est **déduite du fichier**
(`INFER_SCHEMA`), pas écrite à la main.

`ON_ERROR = ABORT_STATEMENT` : sur données de santé, on préfère zéro donnée
à une donnée partielle silencieusement fausse.

15 tables chargées (`supplies.csv` exclu : en-tête seul, zéro ligne).

---

## 5. Portage SQL DuckDB → Snowflake

Le cœur technique de cette partie. Quatre familles de différences rencontrées :

| Problème DuckDB → Snowflake | Symptôme | Correction |
|------------------------------|----------|------------|
| **Casse des identifiants** | `invalid identifier 'ID'` | Snowflake met les identifiants non-quotés en MAJUSCULES ; la colonne source `Id` (casse mixte) devient `"Id"` avec guillemets. |
| **Mots réservés** | `unexpected 'START'` | `start` / `stop` sont réservés ; on les référence en `"START"` / `"STOP"` (guillemets + casse exacte de la colonne). |
| **Types** | `double` inconnu | `cast(... as double)` → `cast(... as float)`. |
| **Fonctions de date** | `Unknown function DATE_DIFF` | `date_diff('unit', a, b)` → `{{ dbt.datediff('a', 'b', 'unit') }}`, macro cross-database qui reste portable DuckDB **et** Snowflake. |

Le choix de `dbt.datediff()` plutôt que le `datediff` natif Snowflake préserve la
portabilité : le même code tourne sur les deux moteurs, ce qui est tout l'intérêt
de comparer partie 1 (DuckDB) et partie 2 (Snowflake).

> **Piège mono-repo** — les deux projets dbt (partie 1 et partie 2) partageaient
> le même `name:` dans `dbt_project.yml`. dbt platform, cherchant le projet, se
> rabattait sur la partie 1 et exécutait l'ancien SQL malgré des corrections
> correctes. Résolu en renommant le projet en `health_dwh`. **Deux projets dbt
> dans un mono-repo ne doivent jamais partager le même nom.**

---

## 6. Modèles

**Staging (5 vues)** — `stg_patients`, `stg_encounters`, `stg_conditions`,
`stg_medications`, `stg_organizations`. Renommage, typage, colonnes
identifiantes (SSN, nom, adresse, GPS) écartées dès cette couche.

**Intermediate (3 vues)** — `int_encounters_enriched` (durées, âge au contact),
`int_inpatient_stays` (séjours hospitaliers, séquençage), `int_patient_condition_summary`.

**Marts (6 tables)**

| Mart | Lignes | Contenu |
|------|-------:|---------|
| `dim_patients` | 1 171 | dimension patient, âge, tranche d'âge, polypathologie |
| `dim_organizations` | 1 119 | dimension établissement |
| `fct_encounters` | 53 346 | fait : contacts de soins |
| `fct_readmissions` | 1 838 | fait : réadmissions à 30 jours |
| `mart_organization_kpis` | 1 119 | KPI agrégés par établissement |
| `mart_high_utilizers` | 280 | patients à forte utilisation |

---

## 7. Tests

56 tests génériques + 3 tests singuliers, rejoués intégralement sur Snowflake.

Un test a été **repensé** lors du portage plutôt que copié : `overlaps_next_stay`
utilisait `accepted_values` détourné pour compter des anomalies, ce qui comptait
des *valeurs distinctes* (1) et non des *lignes* (120). Remplacé par un test
singulier `assert_overlap_rate_within_bounds` qui suit le **taux réel** de
chevauchement de séjours (6,5 %, seuil d'alerte à 10 %) — un chiffre métier
interprétable, avec `count_if()` natif Snowflake.

---

## 8. Limites connues

**Biais de l'indicateur de réadmission** (hérité de la partie 1) — le taux
observé (~35 %) dépasse largement le benchmark clinique (~15 %). Cause : le
générateur Synthea ne modélise pas la logique réelle de réadmission. L'indicateur
est correct *mécaniquement* mais non représentatif *cliniquement*. Il illustre la
méthodologie, pas une réalité épidémiologique.

**Chevauchements de séjours** — 6,5 % des séjours ont une admission suivante
antérieure à leur propre sortie (anomalie du générateur). Ces cas sont exclus des
calculs de réadmission et suivis par un test dédié.

**Région** — compte déployé sur AWS `eu-west-3` (Paris), cohérent avec un contexte
de données de santé et l'argumentaire RGPD, même si les données Synthea sont
synthétiques.

---

## 9. Coûts

<!-- À compléter une fois le job de déploiement exécuté. Relevé via ACCOUNTADMIN :
     SELECT warehouse_name, ROUND(SUM(credits_used), 4) AS credits
     FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
     WHERE warehouse_name = 'WH_HEALTH_XS'
     GROUP BY 1;
-->

Warehouse XSMALL, `AUTO_SUSPEND = 60s`. Un `dbt build` complet
(chargement + 14 modèles + 59 tests) consomme _[à relever]_ crédits, soit
~_[à relever]_ $. Le trial (30 jours / 400 $) est contraint par le **temps**,
pas par les crédits : un warehouse XS ne permet pas d'épuiser 400 $ en 30 jours.

---

## 10. Stack

- Snowflake Enterprise (trial), AWS eu-west-3
- dbt platform (plan Developer), dbt-snowflake 1.11
- Snowflake CLI (`snow`) 3.x, authentification RSA key-pair
- Source : échantillon Synthea (MITRE), ~1 000 patients synthétiques
