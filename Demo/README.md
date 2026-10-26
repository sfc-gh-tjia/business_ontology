# SAP Business Ontology Demo (V2)

A fair, repeatable test of what **Snowflake Business Ontology (BON)** adds on top of **well-built semantic views**. It uses a realistic SAP supply-chain dataset with three domains: Procurement, Finance & Controlling, and Sales & Distribution.

Two Cortex Agents are compared. They are identical except for one tool:

| Arm | Agent | Context |
|---|---|---|
| **B** | `ENRICHED_AGENT` | 3 enriched domain semantic views (metrics, synonyms, code values, instructions, verified queries) |
| **C** | `BON_AGENT` | the same 3 semantic views **+ native Business Ontology search** (`snowscope_search`, `businessOntology` corpus) |

The two agents share the model, budget (150 s / 40k tokens), response instructions and tool descriptions. **BON uplift = C − B.**

## Final result

Run `20261023_072322_9764`: 196 agent calls, 0 errors.

| Metric | B: Enriched SVs | C: + Business Ontology |
|---|---|---|
| **Accuracy (main set)** | 71/80 (89%) | **80/80 (100%)** |
| Tier 1: business rules in one SV (control) | 100% | 100% |
| Tier 2: conflicting definitions & company vocabulary | 84% | **100%** |
| Tier 3: cross-domain reasoning | 96% | **100%** |
| Tier 4: governed meaning | 73% | **100%** |
| Questions right on every run | 70% | **100%** |
| Hedged answers ("15 or 14") | 3% | **0%** |
| Answer names the governed term and its SV metric | 0% | **100%** |
| Median latency | 18.1 s | 19.4 s |

How to read it:
- **The control behaved as intended.** On Tier 1, the semantic views alone already get everything right, and they tie. That confirms the baseline is strong.
- **The gains are concentrated.** B's 9 misses fall on 6 questions:

  | Question | B's score |
  |---|---|
  | Q18: governed policy and where it is implemented | 0/3 |
  | Q19: "Tier A" company vocabulary | 3/5 |
  | Q17: governed definition | 2/3 |
  | Q06, Q07: canonical choice between two valid metrics | 4/5 each |
  | Q12: cross-domain ratio | 4/5 |

  The paired comparison is 9 wins for BON to 0 losses (McNemar p ≈ 0.004). The misses cluster in a few contested questions, so don't read 89% → 100% as a general accuracy figure.
- **BON's main value is consistency and traceability, not raw accuracy.** It removes run-to-run flips and hedging, and every answer cites the governed term. The extra cost is about 1.3 s of median latency.
- **Cross-team consistency:**
  - **Q06:** Finance and Sales team agents agreed 67% of the time without BON, and 100% with it.
  - **Q09:** agreed 100% in both arms.
  - **Q07:** excluded. The Finance agent has no Sales semantic view, so it can't answer, and the pair can never agree (a test-design flaw).

## How the comparison is made fair

- **Sense proposes, Ontology governs, SVs execute.** BON defines what a metric *means* and which implementation is canonical. Semantic views compute it.
- **BON does not replace a good semantic view.** Each team's view is correct on its own terms, and the teams deliberately disagree, as real teams do:

| Question | Purchasing SV | Finance / Sales SV | Governed answer (BON) |
|---|---|---|---|
| Supplier count | `vendor_record_count` = 15 | `active_supplier_count` = 14 | **Supplier Count = 14** (probationary vendors excluded by policy) |
| Revenue | — | `gross_bookings` = 746,000 (synonym "revenue") | **Revenue = net_revenue = 711,915** |
| On-time delivery | `carrier_otd_rate` = 90% | — | **On-Time Delivery Rate = 66.7%** |
| Cost of an assembly | `avg_standard_price` (STPRS 520) | — | **BOM Cost Rollup = 286.60** |

- **Repeat runs:** 5 for tiers 2–3, 3 for tiers 1 and 4. Agents vary from run to run, so a single run isn't enough.
- **Grading:** done by `AI_COMPLETE` against ground truth. Hedged answers count as wrong.
- **Questions were not tuned until BON won.** Duplicate traps were removed, and an abstain question (Q20, a metric that doesn't exist) checks that BON doesn't invent definitions.

## The 20 questions

| Tier | Questions | What it tests |
|---|---|---|
| 1 Business rules in one SV | Q01–Q05 | Control. Enriched SVs should already handle these. |
| 2 Conflicting definitions & company vocabulary | Q06–Q09, Q19 | Which of two valid SV metrics is official. What "Tier A supplier" means. |
| 3 Cross-domain reasoning | Q10–Q14 | Margin, customer profit, break-even, revenue per supplier, safe spend cuts |
| 4 Governed meaning | Q15–Q18, Q20 | Definitions, policies, where each is implemented, and refusing to define what isn't governed |

Ground truth, including the defensible-but-wrong trap answer for each question, is in `sql/v2/02_benchmark_ground_truth.sql`.

## What's in the ontology

- **3 domains:** Procurement (19 nodes), Finance & Controlling (12), Sales & Distribution (9).
- **40 nodes:** 13 ENTITY, 16 METRIC, 8 TERM, 3 policies.
  - Canonical metrics and their look-alikes: Supplier Count vs Vendor Record Count; Revenue vs Gross Bookings; On-Time Delivery Rate vs Carrier Reported On-Time Rate.
  - Cross-domain metrics: Product Gross Margin, Customer Profit, Break-even Discount, Revenue at Risk.
  - Company vocabulary: **Tier A Supplier** (IS_A Supplier; classified by Vendor Account Group).
  - One TERM per code field, each pointing at its reference table (T077K, T023T), never one node per code value.
- **51 typed relationships:** MEASURES 13, DERIVES 13, CLASSIFIES 8, RELATED_TO 6, APPLIES_TO 4, HAS_PART 3, HAS_VARIANT 3, IS_A 1.
- **43 representations:**
  - IMPLEMENTS: canonical metric → the exact SV metric.
  - RELATED_SEMANTIC_VIEW: cross-domain metric → each contributing SV.
  - REPRESENTS: entity → table.
  - DESCRIBES: code term → column.
  - REFERENCE_DATA: code term → code table.

> The 3 policies use `itemKind: POLICY_CONCEPT`, which isn't in the public docs (they list TERM / METRIC / ENTITY only) and may change in preview.

## Prerequisites

- A Snowflake account with Business Ontology enabled (Private Preview) and search indexing in your region.
- A role that can create databases, semantic views and agents, and has ontology privileges. The demo used ACCOUNTADMIN.
- Python 3.10+ and Node.js 18+ for the harness and web app.
- Optional: Cortex Code. The `$business-ontology` skill is bundled, so no install is needed.

## Build and run

### 1. Snowflake objects (`sql/v2/`, in order)

```
01_schema_data.sql             # SAP_BON_V2 schema, SAP tables and data
02_benchmark_ground_truth.sql  # BENCHMARK_QUESTIONS, BENCHMARK_GROUND_TRUTH (20 questions)
03_bare_svs.sql                # bare SVs (legacy arm; not used in the final comparison)
04_enriched_svs.sql            # PURCHASING / FINANCE / SALES _ENRICHED_SV
05_bon.sql                     # 3 domains, 40 nodes, 51 relationships (approve the drafts)
06_representations.sql         # 43 representations
07_agents.sql                  # ENRICHED_AGENT, BON_AGENT, plus Finance/Sales team agents
08_live_scenarios.sql          # optional change-management scenarios
```

### 2. Wait for the search index, then benchmark

Ontology edits can take **up to about 6 hours** to become searchable, and deleted terms can keep being served for longer.

```bash
cd Demo
SNOWFLAKE_CONNECTION_NAME=<conn> python -u benchmark/run_benchmark.py --check-index

# Full run: 20 questions, arms B and C, 3 runs (5 for tiers 2–3), plus consistency pairs
SNOWFLAKE_CONNECTION_NAME=<conn> python -u benchmark/run_benchmark.py --arms B,C --runs 3 --runs-hard 5

# Resume an interrupted run (already-saved calls are skipped)
SNOWFLAKE_CONNECTION_NAME=<conn> python -u benchmark/run_benchmark.py --resume <RUN_ID>
```

The harness refuses to run until the index serves the V2 nodes, including Tier A, unless you pass `--force`. Calls retry on transient connection errors. Results go to `SAP_BON_V2.BENCHMARK_RESULTS` and `benchmark/scorecard_<run_id>.json`.

### 3. Web app

```bash
cd Demo/web
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env.local        # fill in your own connection details; never commit .env.local
export SNOWFLAKE_CONNECTION_NAME=<conn>
python api_server.py              # Flask API on http://localhost:5001

npm install && npm run dev        # Next.js on http://localhost:3000
```

## Demo walkthrough

- **Context tab:**
  - **What semantic views can't settle on their own.** Three tables, each showing the risk with semantic views alone next to what BON adds:
    - which metric is canonical;
    - cross-domain metrics;
    - governed meaning.
  - **The rest of the tab:**
    - the semantic view diagram;
    - the ontology graph (40 nodes / 51 relationships / 43 representations);
    - the source tables.
- **Comparison tab:** ask a question and see the Enriched agent and the BON agent side by side. The 9 curated questions are 3 per tier, and for tiers 2–4 only questions where BON measurably beat the semantic views:
  - Tier 1: Q01, Q03, Q04
  - Tier 2: Q06, Q07, Q19
  - Tier 3: Q12
  - Tier 4: Q17, Q18
- **Analysis tab:** tier scores across all 20 questions from the latest run, plus a per-question table for the curated questions.

```
Next.js (:3000) ──▶ Flask API (:5001) ──▶ DATA_AGENT_RUN()
                                           ├─ ENRICHED_AGENT ─ 3 enriched SVs
                                           └─ BON_AGENT ────── 3 enriched SVs + business_ontology (snowscope_search)
```

## Live scenarios (change management)

`sql/v2/08_live_scenarios.sql` covers what a one-off benchmark can't:

- **S1 Change once:** a steward edits the Supplier Count definition. Every BON agent follows it, with no change to any semantic view or prompt.
- **S2 Drafts are never served:** an unapproved definition stays invisible to agents until it is approved.
- **S3 Semantic view rebuild:** renaming a semantic view metric breaks one IMPLEMENTS representation. The break is detectable and fixable in one place.

## Known limits (Private Preview)

- **Search results:**
  - Native BON search returns definitions, formulas and synonyms. It does **not** return relationships or representations.
  - Any link the agent must follow, such as the SV metric that implements a term or a cross-domain bridge, must also be written in the definition text.
- **Index freshness:** search reflects ontology edits and grants only after an index refresh. That can take up to about 6 hours, and deletions take longer to disappear.
- **Search scope:** search covers every domain your role can read across the account. Other projects' terms can appear, so the agent is told which domains to prefer.
- **Not yet available through the API:**
  - You can't set owners and stewards through the API, so stewardship is recorded in the domain descriptions.
  - Representations aren't revalidated when a semantic view changes.
- **The benchmark itself:**
  - It is small: 20 questions on one synthetic dataset.
  - Measure on your own contested questions before generalising.

## Legacy V1

`sql/01`–`05` are the original V1 build. V1 compared BON against a single *bare* semantic view and reported 27% vs 100%. That overstates the uplift, because a well-built semantic view would also supply much of the missing context. Use V2 for any claim about BON's value.
