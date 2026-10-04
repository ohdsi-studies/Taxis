# OHDSI Sovereign Research Infrastructure: Engineering Requirements & Architecture Specification

> **Document Type**: Production Engineering Work Order & Architectural Requirements Specification  
> **Target Audience**: DevOps Engineers, Infrastructure Architects, Database Administrators, OHDSI Research Leads  
> **Status**: Approved for Execution  
> **Author**: Research & Analytics Team (`ohdsi-studies/Taxis`)  
> **Platform Target**: Sovereign Dedicated Root Server (Hetzner / OVH) or Cloud VPC (AWS / GCP / Azure)  

---

## 1. Executive Summary & Strategic Objective

The research team requires an enterprise-grade, publicly accessible, sovereign OHDSI (Observational Health Data Sciences and Informatics) server environment. This infrastructure will serve as the core development, testing, and benchmark execution platform for:
1. **The TAXIS Association Mining Engine** (`ohdsi-studies/Taxis`), including Pipeline v57, clinical knowledge graph taxonomy v6.0 (112 relation codes), and phenotype evaluation study packages across massive cohorts.
2. **OHDSI HADES Study Packages** (e.g., `CohortDiagnostics`, `PheValuator`, `CohortGenerator`, `FeatureExtraction`, `CohortMethod`, `PatientLevelPrediction`).
3. **Next-Generation Phenotyping & Generative AI Tools**, specifically unreleased **Atlas 3.0 / Next-Gen** (Vue 3 / TypeScript) and its conversational AI assistant **Pythia**.
4. **Public Evidence Dissemination**, enabling publishing of interactive R Shiny study applications and characterization dashboards directly to external collaborators and the scientific community (mirroring `data.ohdsi.org`).

---

## 2. High-Level Architecture Topology

```
                                  PUBLIC INTERNET / CLIENT WORKSTATIONS
                                                   │
                   ┌───────────────────────────────┴───────────────────────────────┐
                   │                                                               │
          [HTTPS : 443]                                                  [TLS Encrypted SQL : 5432]
     (Web Apps & Ingress)                                                (Firewall IP Allowlist Only)
                   │                                                               │
                   ▼                                                               ▼
┌─────────────────────────────────────────────────────────────┐        ┌───────────────────────────────┐
│        REVERSE PROXY & INGRESS CONTROLLER (Nginx/Traefik)   │        │     DIRECT DATABASE INGRESS   │
│         Let's Encrypt Automated SSL / Rate Limiting         │        │    TLS v1.3 / Strict IP Filter│
└──────────────┬──────────────────┬──────────────────┬────────┘        └───────────────┬───────────────┘
               │                  │                  │                                 │
     /atlas1/* │        /atlas3/* │         /shiny/* │                                 │
               ▼                  ▼                  ▼                                 │
┌──────────────────────┐ ┌──────────────────┐ ┌─────────────────────┐                  │
│    Atlas 1.x Classic │ │  Atlas 3.0 Next  │ │  OHDSI Shiny Server │                  │
│    (v2.14+ Knockout) │ │  (Vue 3 / TS)    │ │  (Public & Private) │                  │
└──────────┬───────────┘ └────────┬─────────┘ └──────────┬──────────┘                  │
           │                      │                      │                             │
           │            ┌─────────┴─────────┐            │                             │
           │            │  Pythia AI Plugin │            │                             │
           │            │ (Hybrid Cloud/Loc)│            │                             │
           │            └─────────┬─────────┘            │                             │
           ▼                      ▼                      │                             │
┌───────────────────────────────────────────┐            │                             │
│     WebAPI Tier (WebAPI 2.14 / 3.0)       │            │                             │
│     Native OHDSI Security (DB, LDAP, OIDC)│            │                             │
│     REST Endpoints & Source Daimons       │            │                             │
└──────────────────────┬────────────────────┘            │                             │
                       │                                 │                             │
                       ▼                                 ▼                             ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                    SOVEREIGN RELATIONAL DATABASE ENGINE (PostgreSQL 16+)                     │
├──────────────────────────────┬───────────────────────────────┬───────────────────────────────┤
│    SYNTHETIC CDM SCHEMAS     │      VOCABULARY SCHEMAS       │   RESULTS & WORK SCHEMAS      │
├──────────────────────────────┼───────────────────────────────┼───────────────────────────────┤
│ • cdm_synthea_10k            │ • vocab_v5_latest             │ • results_synthea_10k         │
│ • cdm_synthea_100k           │ • vocab_v5_prev1              │ • results_synthea_1m          │
│ • cdm_synthea_28m (Full US)  │ • vocab_v5_prev2              │ • results_synpuf_2m           │
│ • cdm_synpuf_110k (5%)       │   (Full PKs, FKs, B-Trees,    │ • results_taxis               │
│ • cdm_synpuf_2m (100% / 2.3M)│    GIN / Trigram indexes;     │ • scratch (Read/Write)        │
│ • cdm_eunomia_gibleed        │    CDMs linked via search_path│ • cohort (HADES temp/work)    │
│ • cdm_taxis_synthetic        │    and schema views)          │                               │
└──────────────────────────────┴───────────────────────────────┴───────────────────────────────┘
```

---

## 3. Core Functional & Technical Requirements

### 3.1. Sovereign Server Infrastructure & Host Environment

| Requirement ID | Specification Item | Approved Engineering Mandate |
|---|---|---|
| **INF-001** | **Host Architecture** | Dedicated root hosting provider (e.g., Hetzner EX/PX line, OVHcloud Enterprise) OR Dedicated Cloud VPC (AWS EC2 / GCP Compute Engine / Azure). Operating system: **Ubuntu Server 24.04 LTS x86_64**. |
| **INF-002** | **Compute & RAM Tier** | **High-Throughput Cluster: 64 vCPUs / 256 GB RAM**. Mandatory to sustain concurrent HADES multi-database network simulations, 40-batch association mining in TAXIS, and rapid parallel index builds on 2.33M patient SynPUF. |
| **INF-003** | **Storage Architecture** | **4 TB NVMe Enterprise SSD** (PCIe Gen4). Partitioning plan:<br>• `/` (OS & Docker): 200 GB<br>• `/var/lib/postgresql/data` (Databases & Vocabularies): 3.2 TB<br>• `/srv/shiny-server` & `/data/staging`: 600 GB |
| **INF-004** | **Container Engine** | **Docker Engine (v26+)** and **Docker Compose (v2.24+)** with Broadsea 3.x microservice architecture. |
| **INF-005** | **Public Networking & DNS** | Static public IPv4 address with configured DNS wildcards: `*.ohdsi.<domain>.org` or dedicated subdomains: `atlas.<domain>`, `atlas3.<domain>`, `shiny.<domain>`, `db.<domain>`. |

---

### 3.2. Relational Database Engine & HADES Naming Standards

The relational database is the central execution engine. It must follow strict HADES and OHDSI Common Data Model standards.

| Requirement ID | Component | Technical Specification |
|---|---|---|
| **DB-001** | **RDBMS Engine** | **PostgreSQL 16.x** tuned for high-concurrency OLAP & association mining:<br>`shared_buffers = 64GB`<br>`work_mem = 512MB`<br>`maintenance_work_mem = 16GB`<br>`effective_cache_size = 192GB`<br>`max_parallel_workers_per_gather = 8`<br>`max_parallel_maintenance_workers = 8`<br>`random_page_cost = 1.1` (NVMe optimized) |
| **DB-002** | **Database Naming** | Primary database cluster named **`ohdsi`**. |
| **DB-003** | **Schema Segregation** | Strict separation into dedicated schemas:<br>• **CDMs**: `cdm_synthea_10k`, `cdm_synthea_100k`, `cdm_synthea_28m`, `cdm_synpuf_110k`, `cdm_synpuf_2m`, `cdm_eunomia_gibleed`, `cdm_taxis_synthetic`<br>• **Vocabularies**: `vocab_v5_latest`, `vocab_v5_prev1`, `vocab_v5_prev2`<br>• **Results**: `results_synthea_10k`, `results_synthea_1m`, `results_synpuf_2m`, `results_taxis`<br>• **Scratch / Temp**: `scratch`, `cohort` (full DDL/DML for study packages) |
| **DB-004** | **HADES Conventions** | All schema and table names strictly lower-case, adhering to HADES `SqlRender` parameter defaults: `@cdm_database_schema`, `@vocabulary_database_schema`, `@cohort_database_schema`, `@results_database_schema`. |

---

### 3.3. Multi-Version OMOP Standard Vocabularies

Researchers require simultaneous access to multiple vocabulary versions to verify backwards compatibility and study transitions.

1. **Schema Layout & Persistence**:
   - Host **three (3) distinct OMOP vocabulary releases** simultaneously:
     - `vocab_v5_latest`: Latest available Athena release (2026/current).
     - `vocab_v5_prev1`: Prior intermediate release (2025-Q3/Q4).
     - `vocab_v5_prev2`: Baseline prior release (2025-Q1/Q2).
   - Link CDM schemas to `vocab_v5_latest` via database `search_path` and cross-schema standard views (`CREATE VIEW cdm_xxx.concept AS SELECT * FROM vocab_v5_latest.concept;`), avoiding redundant 50+ GB disk duplication per CDM while maintaining full autonomy.
2. **Tables Required**:
   - `CONCEPT`, `CONCEPT_RELATIONSHIP`, `CONCEPT_ANCESTOR`, `CONCEPT_SYNONYM`, `VOCABULARY`, `RELATIONSHIP`, `CONCEPT_CLASS`, `DOMAIN`, `DRUG_STRENGTH`.
3. **Indexes & Constraints Mandate**:
   - **Primary Keys**: Explicit PKs on `concept(concept_id)`, `vocabulary(vocabulary_id)`, etc.
   - **Performance B-Trees**:
     - `concept(concept_code, vocabulary_id)`
     - `concept(domain_id)`
     - `concept(concept_class_id)`
     - `concept_relationship(concept_id_1, concept_id_2, relationship_id)`
     - `concept_relationship(concept_id_2, concept_id_1, relationship_id)`
     - `concept_ancestor(ancestor_concept_id, descendant_concept_id)`
     - `concept_ancestor(descendant_concept_id, ancestor_concept_id)`
   - **GIN / Trigram Text Indexes** (`pg_trgm` extension):
     - `CREATE INDEX idx_concept_name_trgm ON vocab_v5_latest.concept USING gin (concept_name gin_trgm_ops);`
     - `CREATE INDEX idx_synonym_name_trgm ON vocab_v5_latest.concept_synonym USING gin (concept_synonym_name gin_trgm_ops);`
     - *Mandatory for sub-second autocomplete during Atlas cohort authoring and Pythia prompt parsing.*

---

### 3.4. Full Mega-Load Synthetic OMOP CDM Datasets Catalog

The engineering team must ingest the **Full Mega-Load** suite of synthetic patient databases:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                FULL MEGA-LOAD SYNTHETIC OMOP CDM CATALOG                                        │
├──────────────────────┬─────────────┬──────────────┬──────────────┬──────────────────────────────────────────────┤
│ Dataset Name         │ Patient N   │ Format       │ Target Schema│ Source / Download Location                   │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ Synthea 10k Sample   │ 10,000      │ OMOP CDM 5.4 │ cdm_synthea  │ AWS Open Data (s3://synthea-omop/)           │
│                      │             │ CSV          │ _10k         │ `aws s3 cp --no-sign-request ...`            │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ Synthea 100k         │ 100,000     │ OMOP CDM 5.4 │ cdm_synthea  │ AWS Open Data (s3://synthea-omop/)           │
│                      │             │ CSV          │ _100k        │ Intermediate benchmark testbed               │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ Synthea Full US      │ 2,800,000   │ OMOP CDM 5.4 │ cdm_synthea  │ AWS Open Data (Registry of Open Data)        │
│                      │             │ Parquet/CSV  │ _28m         │ `s3://synthea-omop/synthea28m/`              │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ CMS DE-SynPUF (5%)   │ 116,352     │ OMOP CDM 5.3 │ cdm_synpuf   │ OHDSI ETL-CMS / OHDSI FTP                    │
│                      │             │ CSV          │ _110k        │ Standard longitudinal Medicare sample        │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ CMS DE-SynPUF (100%) │ 2,330,000   │ OMOP CDM 5.3 │ cdm_synpuf   │ OHDSI SynPUF Full Release (20 Slices)        │
│                      │             │ CSV          │ _2m          │ Large-scale claims mining benchmark          │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ OHDSI Eunomia GiBleed│ 2,694       │ OMOP CDM 5.3 │ cdm_eunomia  │ OHDSI/Eunomia GitHub                         │
│                      │             │ DuckDB/CSV   │ _gibleed     │ Standard HADES baseline test suite           │
├──────────────────────┼─────────────┼──────────────┼──────────────┼──────────────────────────────────────────────┤
│ TAXIS Synthetic      │ 2,160,000   │ Concept AB   │ cdm_taxis    │ Local Repository Asset (`ohdsi-studies/Taxis`│
│ Benchmark Fixture    │ (Aggregate) │ SQL Pipeline │ _synthetic   │ docs/mining/sql/ + Pipeline v57 fixtures)    │
└──────────────────────┴─────────────┴──────────────┴──────────────┴──────────────────────────────────────────────┘
```

---

### 3.5. Direct Client Connectivity (SQL, R HADES, Python) with Strict IP Filtering

Client workstations must connect directly to PostgreSQL on port 5432 over the public internet, secured by TLS encryption and firewall IP allowlisting:

1. **Firewall & Ingress Security**:
   - Port 5432 exposed to the public internet, but protected by **UFW / Cloud Security Group IP allowlisting**.
   - Only authorized researcher / institution CIDRs permitted.
   - Enforce TLS v1.3 encryption: `ssl = on` in `postgresql.conf`, `hostssl all all <allowed_ip>/32 scram-sha-256` in `pg_hba.conf`.
2. **R / HADES Connectivity**:
   - Verified via `DatabaseConnector::connect()`:
     ```r
     connectionDetails <- DatabaseConnector::createConnectionDetails(
       dbms = "postgresql",
       server = "db.<domain>.org/ohdsi",
       port = 5432,
       user = "ohdsi_researcher",
       password = Sys.getenv("OHDSI_DB_PASSWORD"),
       ssl = TRUE
     )
     conn <- DatabaseConnector::connect(connectionDetails)
     ```
   - Verified compatibility with `SqlRender`, `CohortGenerator`, `FeatureExtraction`, and [`Taxis`](file:///c:/files/git/github/ohdsi-studies/Taxis/DESCRIPTION#L1).
3. **Direct SQL Clients**:
   - DBeaver / DataGrip / PgAdmin / psql tested with SSL mode set to `require` or `verify-full`.
4. **Python Connectivity**:
   - Verified via `SQLAlchemy >= 2.0` and `psycopg2-binary`:
     ```python
     engine = create_engine("postgresql+psycopg2://user:pass@db.<domain>.org:5432/ohdsi?sslmode=require")
     ```

---

### 3.6. Dual-Atlas Platform & Pythia AI Architecture

The environment must support side-by-side execution of stable Atlas 1.x and next-generation Atlas 3.0:

#### A. Continuous CI/CD Release Tracking
- The engineering team must configure an automated CI/CD build tracking the active OHDSI GitHub branches:
  - Frontend: `https://github.com/OHDSI/Atlas3.git` (`main` branch, Vue 3 / Vite)
  - Backend: `https://github.com/OHDSI/WebAPI.git` (`webapi-3.0` branch, Spring Security)
- Re-build and stage images whenever new upstream release candidates are tagged.

#### B. Atlas 1.x Classic
- Deploy official stable **Atlas v2.14.x** with WebAPI 2.14.
- Accessible via: `https://atlas.<domain>.org/` (or `/atlas/`).

#### C. Atlas 3.0 Next-Gen
- Deploy modern Vue 3 / TypeScript **Atlas 3.0**.
- Accessible via: `https://atlas3.<domain>.org/` (or `/atlas3/`).

#### D. Pythia Generative AI Plugin (Dual-Hybrid Engine)
- Deploy and configure **OHDSI Pythia** (`@ohdsi/pythia-agent`).
- **Dual-Hybrid Model Gateway**:
  - **Primary**: Cloud API (OpenAI GPT-4o / Anthropic Claude 3.7 Sonnet) via institutional API keys for complex clinical phenotype reasoning.
  - **Fallback / Sovereign**: Local self-hosted model running on the sovereign server via **vLLM / Ollama** (e.g., `Llama-3.3-70B-Instruct` or `Mistral-Small`) for high-volume concept expansions or offline operation.
- Capabilities enabled:
  - Interactive proposal cards for cohort primary criteria and inclusion rules.
  - Concept set drafting and automated semantic expansion.
  - Pre-generation attrition warning detection.
  - Dynamic integration with TAXIS empirical association scores.

#### E. Native OHDSI WebAPI Authentication Governance
- Implement **only native out-of-the-box OHDSI WebAPI authentication modules**:
  - WebAPI Internal Database Authentication (built-in username/password managed via WebAPI admin UI).
  - Native OAuth2 / OIDC (Google Workspace / GitHub / Microsoft Entra ID).
  - Native LDAP / Active Directory.
- **Rule**: Absolutely zero custom authentication wrappers or modifications to OHDSI core code.

#### F. OHDSI Phenotype Library Seeding
- Seed all ~1,100+ vetted OHDSI Phenotype Library cohorts into both Atlas instances using the automated R script (`ROhdsiWebApi` + `PhenotypeLibrary`).

---

### 3.7. Public & Private R Shiny Server Infrastructure

The server must host a dedicated analytical application portal mirroring `data.ohdsi.org`:

1. **Subdomain with Hybrid Access Architecture**:
   - Server URL: `https://shiny.<domain>.org/`
   - **Public Directory (`/public/`)**: Completely open to the scientific community and peer reviewers without credentials.
     - `https://shiny.<domain>.org/public/taxis/` (Pipeline v57 interactive association viewer).
     - `https://shiny.<domain>.org/public/diagnostics/` (Public study cohort diagnostics).
   - **Private Directory (`/private/`)**: Protected by HTTP Basic Auth / OAuth2 reverse proxy for pre-publication and confidential study evaluations.
     - `https://shiny.<domain>.org/private/phenotype-eval/`
2. **Containerized Engine**:
   - Rocker Shiny container (R >= 4.3.0) pre-loaded with `CohortDiagnostics`, `PheValuator`, `Characterization`, `shinyWidgets`, `DT`, `plotly`, `reactable`.
3. **Researcher Deployment Pipeline**:
   - Researchers can publish new Shiny apps via authenticated SFTP or Git push directly into `/srv/shiny-server/public/<app_name>` or `/srv/shiny-server/private/<app_name>`.

---

### 3.8. TAXIS Association Engine & Results Schema Architecture

To support the TAXIS study pipeline:
1. **Schema Partitioning**:
   - `cdm_taxis_synthetic`: Hosting the input patient-level OMOP CDM test data.
   - `results_taxis`: Persistent schema dedicated to the 40-batch Concept AB Mining Engine v57.
2. **Tables Pre-Provisioned in `results_taxis`**:
   - `taxis_concept_pairs`: Co-occurrence and temporal precedence pairs.
   - `taxis_stratified_lift`: Decile-stratified Mantel-Haenszel lift metrics ($Lift_{strat}$).
   - `taxis_directionality`: Continuity-corrected Directionality Ratios ($DR$).
   - `taxis_ckg_taxonomy`: Clinical Knowledge Graph v6.0 (112 relation codes).
   - `taxis_grain_guide`: First-mention vs. all-mentions longitudinal grain benchmarks.

---

## 4. Production Docker Compose Stack Blueprint

```yaml
# /opt/ohdsi/docker-compose.yml
version: '3.8'

services:
  # 1. Reverse Proxy & Automated SSL
  reverse-proxy:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./certs:/etc/letsencrypt:ro
    restart: always

  # 2. Sovereign OMOP Database Cluster (Tuned for 256 GB RAM)
  ohdsi-postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ohdsi
      POSTGRES_USER: ${DB_ADMIN_USER}
      POSTGRES_PASSWORD: ${DB_ADMIN_PASS}
    ports:
      - "5432:5432"
    volumes:
      - /var/lib/postgresql/data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d:ro
    command: >
      postgres
        -c ssl=on
        -c ssl_cert_file=/etc/ssl/certs/server.crt
        -c ssl_key_file=/etc/ssl/private/server.key
        -c shared_buffers=64GB
        -c work_mem=512MB
        -c maintenance_work_mem=16GB
        -c effective_cache_size=192GB
        -c max_parallel_workers_per_gather=8
        -c max_parallel_maintenance_workers=8
        -c random_page_cost=1.1
    restart: always

  # 3. WebAPI 2.14 Backend (Serving Atlas Classic)
  webapi-classic:
    image: ohdsi/webapi:2.14.0
    environment:
      DATASOURCE_URL: jdbc:postgresql://ohdsi-postgres:5432/ohdsi
      DATASOURCE_USERNAME: ${DB_APP_USER}
      DATASOURCE_PASSWORD: ${DB_APP_PASS}
      SECURITY_ENABLED: "true"
    restart: always

  # 4. Atlas 1.x Classic Web Application
  atlas-classic:
    image: ohdsi/atlas:2.14.0
    environment:
      WEBAPI_URL: https://atlas.${DOMAIN}/WebAPI/
    restart: always

  # 5. WebAPI 3.0 Backend (Serving Atlas 3.0 & Pythia)
  webapi-v3:
    image: ohdsi/webapi:3.0.0-rc # Built via CI/CD from branch webapi-3.0
    environment:
      DATASOURCE_URL: jdbc:postgresql://ohdsi-postgres:5432/ohdsi
      SECURITY_ENABLED: "true"
    restart: always

  # 6. Atlas 3.0 Next-Gen Web Application
  atlas-nextgen:
    image: ohdsi/atlas3:latest # Built via CI/CD from Atlas3:main
    environment:
      VITE_WEBAPI_URL: https://atlas3.${DOMAIN}/WebAPI3/
      VITE_ENABLE_PYTHIA: "true"
    restart: always

  # 7. Pythia AI Agent Gateway (Dual-Hybrid Cloud / Local Fallback)
  pythia-agent:
    image: ohdsi/pythia:latest
    environment:
      WEBAPI_URL: http://webapi-v3:8080/WebAPI
      PRIMARY_LLM_PROVIDER: "openai"
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      FALLBACK_LLM_PROVIDER: "ollama"
      OLLAMA_ENDPOINT: "http://ollama-service:11434"
    restart: always

  # 8. Local Sovereign Fallback LLM Service
  ollama-service:
    image: ollama/ollama:latest
    volumes:
      - /opt/ollama:/root/.ollama
    restart: always

  # 9. Public & Private OHDSI R Shiny Server
  ohdsi-shiny:
    image: rocker/shiny:4.3.3
    volumes:
      - /srv/shiny-server:/srv/shiny-server
      - /var/log/shiny-server:/var/log/shiny-server
    restart: always
```

---

## 5. Engineering Acceptance Checklist & Handoff Sign-Off

The engineering team must verify each step before production handoff:

- [ ] **Infrastructure Provisioning**: 64 vCPU / 256 GB RAM host live on Ubuntu 24.04 LTS with 4 TB NVMe mounted.
- [ ] **Database Engine**: PostgreSQL 16 active with tuned OLAP parameters; SSL active on port 5432.
- [ ] **Firewall Ingress**: Port 5432 reachable only by approved researcher IPs; verified via external DBeaver test.
- [ ] **Vocabularies Loaded**: Athena releases loaded into `vocab_v5_latest`, `vocab_v5_prev1`, `vocab_v5_prev2`; GIN trigram indexes created; search latency `< 50ms`.
- [ ] **Mega-Load CDM Ingestion**: Synthea 10k, 100k, 2.8M; CMS SynPUF 5% and 100% (2.33M); Eunomia GiBleed; and TAXIS synthetic fixtures loaded into distinct schemas.
- [ ] **R / HADES Connectivity**: External client connected via `DatabaseConnector`; successfully queried `cdm_synpuf_2m.person`; executed dry-run of [`Taxis`](file:///c:/files/git/github/ohdsi-studies/Taxis/DESCRIPTION#L1).
- [ ] **Atlas Dual Deployment**:
  - Classic Atlas 1.x accessible at `https://atlas.<domain>/`.
  - Next-Gen Atlas 3.0 accessible at `https://atlas3.<domain>/`.
  - OHDSI WebAPI native authentication active.
- [ ] **Pythia AI Operational**: Pythia conversational card assistant responding in Atlas 3.0 with hybrid cloud / local fallback.
- [ ] **Phenotype Library Seeding**: All ~1,100+ OHDSI Phenotype Library cohorts uploaded and viewable in Atlas.
- [ ] **R Shiny Server**: `https://shiny.<domain>/public/` accessible without auth; `https://shiny.<domain>/private/` protected; sample `CohortDiagnostics` and TAXIS mining app operational.
- [ ] **Credential Handoff**: Initial admin and researcher credentials securely transmitted.
