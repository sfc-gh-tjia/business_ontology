"""BON Demo V2 benchmark harness.

Measures Business Ontology uplift as arm C (enriched SVs + BON) minus arm B
(enriched SVs alone). Same model, budget,
instructions, and SVs across B and C: the only difference is the BON tool.

Value scorecard (maps to Business Ontology positioning):
  V1 canonical choice    Tier 2: pick the governed metric among conflicting SV metrics
  V2 cross-domain        Tier 3: compose meaning across Sales/Finance/Procurement SVs
  V3 governed meaning    Tier 4: explain the business definition, policy, implementation
  V4 consistency         same question, two teams' agents, same answer?
  V5 baseline fairness   Tier 1: enriched SVs already handle single-SV rules (BON adds ~0)
  V6 accuracy stability  answers identical across repeated runs
  V7 cost                latency and tool calls per answer
  V8 traceability        answer names the governed term and its implementing SV metric

Usage:
  SNOWFLAKE_CONNECTION_NAME=tjia_demo_aws2 python run_benchmark.py            # full run
  SNOWFLAKE_CONNECTION_NAME=tjia_demo_aws2 python run_benchmark.py --runs 1 --qids Q06,Q07
  SNOWFLAKE_CONNECTION_NAME=tjia_demo_aws2 python run_benchmark.py --check-index
"""
import argparse
import json
import os
import re
import subprocess
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed

import snowflake.connector

SCHEMA = "DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2"
ARMS = {"B": "ENRICHED_AGENT", "C": "BON_AGENT"}
PAIRS = {  # V4: same question asked through two teams' agents
    "no_bon": ("FINANCE_AGENT", "SALES_AGENT"),
    "bon": ("FINANCE_BON_AGENT", "SALES_BON_AGENT"),
}
PAIR_QIDS = ["Q06", "Q07", "Q09"]
JUDGE_MODEL = "claude-sonnet-4-5"
# Index check: new V2 node that must be searchable, and retired V1 nodes that must not be.
INDEX_PROBES = [("supplier count active suppliers", "Procurement.Supplier Count"),
                ("revenue net of discounts", "Sales & Distribution.Revenue"),
                ("tier a suppliers", "Procurement.Tier A Supplier")]
RETIRED_DOMAINS = ("SAP Purchasing.", "SAP Finance.", "SAP Sales.")


def connect():
    return snowflake.connector.connect(connection_name=os.environ.get("SNOWFLAKE_CONNECTION_NAME", "tjia_demo_aws2"))


def check_index():
    """Return (ready, report). Ready when new nodes are found and retired V1 nodes are gone."""
    ready, lines = True, []
    for query, expected in INDEX_PROBES:
        out = subprocess.run(["cortex", "search", "object", query, "--types=business-ontology"],
                             capture_output=True, text=True, timeout=120).stdout
        hits = re.findall(r"\d+\. ([^\n(]+) \(", out)
        found = expected in [h.strip() for h in hits]
        stale = [h.strip() for h in hits if h.strip().startswith(RETIRED_DOMAINS)]
        ready &= found and not stale
        lines.append(f"  '{query}': expected={'found' if found else 'MISSING'}, retired V1 hits={stale or 'none'}")
    return ready, "\n".join(lines)


def run_agent(conn, agent, question):
    body = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": question}]}]})
    t0 = time.time()
    cur = conn.cursor()
    try:
        cur.execute("SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)", (f"{SCHEMA}.{agent}", body))
        resp = json.loads(cur.fetchone()[0])
        err = None
    except Exception as e:  # keep the run; a failure is a scored wrong answer
        resp, err = {"content": []}, str(e)[:500]
    finally:
        cur.close()
    latency = round(time.time() - t0, 1)
    content = resp.get("content", [])
    tools = [c["tool_use"]["name"] for c in content if c.get("type") == "tool_use"]
    texts = [c.get("text", "") for c in content if c.get("type") == "text"]
    answer = "\n".join(t for t in texts if t.strip())
    return {"answer": answer or (err or ""), "tools": tools, "latency_s": latency, "error": err}


JUDGE_PROMPT = """You grade an analytics agent's answer against ground truth.
Question: {q}
Expected: {expected}
Grading rule: {rule}
Plausible wrong answer to watch for: {wrong}
Agent answer:
<<<
{answer}
>>>
Return only JSON with keys:
  "headline_value": the single final number the agent gave as its answer (number, or null if none). If the agent mentions several numbers but clearly states which one is the official or recommended answer, use that one,
  "hedged": true only if the agent offers two or more competing answers AND never states which one is official or recommended, leaving the choice to the user. Mentioning an alternative after clearly committing to one answer is NOT hedging,
  "correct": true/false applying the grading rule (for numeric rules, compare the headline value, not side numbers). A hedged answer is NOT correct, even if one of its options matches,
  "fell_for_wrong": true if the agent's headline answer matches the plausible wrong answer,
  "names_governed_term": true if the answer names a governed business term AND the semantic view metric that implements it,
  "reason": one short sentence."""


def parse_judge(raw):
    """AI_COMPLETE may return the text JSON-encoded and wrapped in a ```json fence."""
    text = raw
    try:
        decoded = json.loads(raw)
        if isinstance(decoded, str):
            text = decoded
        elif isinstance(decoded, dict):
            return decoded
    except (TypeError, ValueError):
        pass
    m = re.search(r"\{.*\}", text or "", re.S)
    if m:
        try:
            return json.loads(m.group(0))
        except ValueError:
            pass
    return {"correct": False, "reason": "unparseable judge output: " + str(raw)[:200]}


def judge(conn, gt, answer):
    expected = gt["EXPECTED_VALUE"] if gt["EXPECTED_VALUE"] is not None else gt["GRADING_RULE"]
    prompt = JUDGE_PROMPT.format(q=gt["QUESTION"], expected=expected, rule=gt["GRADING_RULE"],
                                 wrong=gt["PLAUSIBLE_WRONG"], answer=answer[:6000])
    cur = conn.cursor()
    try:
        cur.execute("SELECT AI_COMPLETE(%s, %s)", (JUDGE_MODEL, prompt))
        raw = cur.fetchone()[0]
    finally:
        cur.close()
    v = parse_judge(raw)
    # Deterministic check for plain numeric questions: the judge only extracts the headline number.
    if gt["GRADING_RULE"] == "numeric" and gt["EXPECTED_VALUE"] is not None and v.get("headline_value") is not None:
        try:
            exp, got = float(gt["EXPECTED_VALUE"]), float(v["headline_value"])
            tol = float(gt["TOLERANCE_PCT"] or 0) / 100 * abs(exp)
            v["correct"] = abs(got - exp) <= max(tol, 0.051 if exp < 100 else 0.5) and not v.get("hedged")
        except (TypeError, ValueError):
            pass
    return v


def load_questions(conn, qids):
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute(f"""SELECT q.QID, q.TIER, q.TIER_NAME, q.VALUE_PILLAR, q.QUESTION, g.EXPECTED_VALUE,
                    g.TOLERANCE_PCT, g.CANONICAL_METRIC, g.PLAUSIBLE_WRONG, g.GRADING_RULE
                    FROM {SCHEMA}.BENCHMARK_QUESTIONS q JOIN {SCHEMA}.BENCHMARK_GROUND_TRUTH g USING (QID) ORDER BY QID""")
    rows = cur.fetchall()
    return [r for r in rows if not qids or r["QID"] in qids]


def ensure_results_table(conn):
    conn.cursor().execute(f"""CREATE TABLE IF NOT EXISTS {SCHEMA}.BENCHMARK_RESULTS (
        RUN_ID STRING, RUN_TS TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), EXPERIMENT STRING, ARM STRING,
        AGENT STRING, QID STRING, RUN_NO INT, CORRECT BOOLEAN, FELL_FOR_WRONG BOOLEAN,
        NAMES_GOVERNED_TERM BOOLEAN, HEADLINE_VALUE FLOAT, LATENCY_S FLOAT, TOOL_CALLS INT,
        USED_BON BOOLEAN, ANSWER STRING, JUDGE_REASON STRING, ERROR STRING)""")
    conn.cursor().execute(f"ALTER TABLE {SCHEMA}.BENCHMARK_RESULTS ADD COLUMN IF NOT EXISTS HEDGED BOOLEAN")


def save(conn, run_id, rows):
    cur = conn.cursor()
    cur.executemany(f"""INSERT INTO {SCHEMA}.BENCHMARK_RESULTS (RUN_ID, EXPERIMENT, ARM, AGENT, QID, RUN_NO, CORRECT,
        FELL_FOR_WRONG, NAMES_GOVERNED_TERM, HEADLINE_VALUE, LATENCY_S, TOOL_CALLS, USED_BON, ANSWER, JUDGE_REASON, ERROR, HEDGED)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
        [(run_id, r["experiment"], r["arm"], r["agent"], r["qid"], r["run_no"], bool(r["correct"]),
          bool(r.get("fell_for_wrong")), bool(r.get("names_governed_term")), r.get("headline_value"),
          r["latency_s"], len(r["tools"]), "business_ontology" in r["tools"], r["answer"][:16000],
          r.get("reason"), r.get("error"), bool(r.get("hedged"))) for r in rows])
    cur.close()


def task(experiment, arm, agent, gt, run_no, attempts=3):
    # Retry the whole call: transient connection errors (e.g. 390422 IP blocks) otherwise abort the run.
    for i in range(attempts):
        conn = None
        try:
            conn = connect()
            res = run_agent(conn, agent, gt["QUESTION"])
            v = judge(conn, gt, res["answer"])
            break
        except snowflake.connector.errors.Error as e:
            if i == attempts - 1:
                raise
            print(f"  retry {i + 1} {experiment} {arm} {gt['QID']} run{run_no}: {str(e)[:80]}")
            time.sleep(30 * (i + 1))
        finally:
            if conn:
                conn.close()
    try:
        hv = float(v.get("headline_value")) if v.get("headline_value") is not None else None
    except (TypeError, ValueError):
        hv = None
    return {"experiment": experiment, "arm": arm, "agent": agent, "qid": gt["QID"], "run_no": run_no,
            **res, **v, "headline_value": hv}


def scorecard(conn, run_id):
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute(f"""
      WITH r AS (SELECT r.*, q.VALUE_PILLAR FROM {SCHEMA}.BENCHMARK_RESULTS r
                 JOIN {SCHEMA}.BENCHMARK_QUESTIONS q USING (QID) WHERE RUN_ID = %s AND EXPERIMENT = 'main')
      SELECT VALUE_PILLAR, ARM, ROUND(100*AVG(IFF(CORRECT,1,0)),0) PCT, COUNT(*) N
      FROM r GROUP BY 1,2 ORDER BY 1,2""", (run_id,))
    acc = cur.fetchall()
    cur.execute(f"""
      WITH per_q AS (SELECT ARM, QID, COUNT(DISTINCT IFF(HEADLINE_VALUE IS NULL, 'x:'||CORRECT::STRING,
                            ROUND(HEADLINE_VALUE,1)::STRING)) DISTINCT_ANSWERS, MIN(IFF(CORRECT,1,0)) ALL_CORRECT
                     FROM {SCHEMA}.BENCHMARK_RESULTS WHERE RUN_ID = %s AND EXPERIMENT = 'main' GROUP BY 1,2)
      SELECT ARM, ROUND(100*AVG(IFF(DISTINCT_ANSWERS = 1,1,0)),0) STABLE_PCT,
             ROUND(100*AVG(ALL_CORRECT),0) ALWAYS_RIGHT_PCT FROM per_q GROUP BY 1 ORDER BY 1""", (run_id,))
    stab = cur.fetchall()
    cur.execute(f"""SELECT ARM, ROUND(MEDIAN(LATENCY_S),1) P50_S, ROUND(AVG(TOOL_CALLS),1) AVG_TOOLS,
             ROUND(100*AVG(IFF(NAMES_GOVERNED_TERM,1,0)),0) TRACE_PCT, ROUND(100*AVG(IFF(FELL_FOR_WRONG,1,0)),0) TRAP_PCT,
             ROUND(100*AVG(IFF(HEDGED,1,0)),0) HEDGE_PCT
             FROM {SCHEMA}.BENCHMARK_RESULTS WHERE RUN_ID = %s AND EXPERIMENT = 'main' GROUP BY 1 ORDER BY 1""", (run_id,))
    cost = cur.fetchall()
    cur.execute(f"""
      WITH p AS (SELECT ARM, QID, RUN_NO, AGENT, HEADLINE_VALUE, CORRECT FROM {SCHEMA}.BENCHMARK_RESULTS
                 WHERE RUN_ID = %s AND EXPERIMENT = 'consistency')
      SELECT f.ARM, f.QID, ROUND(100*AVG(IFF(ROUND(f.HEADLINE_VALUE,1) = ROUND(s.HEADLINE_VALUE,1),1,0)),0) AGREE_PCT,
             ROUND(100*AVG(IFF(f.CORRECT AND s.CORRECT,1,0)),0) BOTH_RIGHT_PCT
      FROM p f JOIN p s ON f.ARM = s.ARM AND f.QID = s.QID AND f.RUN_NO = s.RUN_NO
       AND f.AGENT LIKE 'FINANCE%%' AND s.AGENT LIKE 'SALES%%' GROUP BY 1,2 ORDER BY 1,2""", (run_id,))
    cons = cur.fetchall()
    cur.close()
    return {"accuracy": acc, "stability": stab, "cost_trace": cost, "consistency": cons}


def print_scorecard(sc):
    pillars = {}
    for r in sc["accuracy"]:
        pillars.setdefault(r["VALUE_PILLAR"], {})[r["ARM"]] = int(r["PCT"])
    print("\nACCURACY BY VALUE PILLAR (% correct)       B enriched  C +BON  BON uplift (C-B)")
    for p, a in sorted(pillars.items()):
        print(f"  {p:<28} {a.get('B',0):>10}% {a.get('C',0):>6}%   {a.get('C',0)-a.get('B',0):+d} pts")
    print("\nSTABILITY (V6)              same answer every run   always right")
    for r in sc["stability"]:
        print(f"  arm {r['ARM']}  {int(r['STABLE_PCT']):>28}% {int(r['ALWAYS_RIGHT_PCT']):>14}%")
    print("\nCOST & TRACEABILITY (V7, V8)   median s   avg tools   names term+SV metric   fell for trap   hedged")
    for r in sc["cost_trace"]:
        print(f"  arm {r['ARM']}  {r['P50_S']:>18} {r['AVG_TOOLS']:>11} {int(r['TRACE_PCT']):>21}% "
              f"{int(r['TRAP_PCT']):>14}% {int(r['HEDGE_PCT'] or 0):>7}%")
    print("\nCONSISTENCY ACROSS TEAMS (V4)  Finance agent vs Sales agent, same question")
    for r in sc["consistency"]:
        print(f"  {r['ARM']:<7} {r['QID']}  agree {int(r['AGREE_PCT'])}%  both right {int(r['BOTH_RIGHT_PCT'])}%")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=3, help="runs per question for tiers 1 and 4")
    ap.add_argument("--runs-hard", type=int, default=5, help="runs per question for tiers 2 and 3, where BON uplift is expected")
    ap.add_argument("--qids", default="")
    ap.add_argument("--arms", default="B,C")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--skip-consistency", action="store_true")
    ap.add_argument("--check-index", action="store_true", help="only report whether the BON search index is ready")
    ap.add_argument("--force", action="store_true", help="run even if the BON index is not ready")
    ap.add_argument("--resume", default="", help="existing RUN_ID: run only the calls not yet saved for it")
    a = ap.parse_args()

    ready, report = check_index()
    print("BON search index check:\n" + report + f"\n  ready={ready}")
    if a.check_index:
        return
    if not ready and not a.force:
        print("Index not ready (new V2 nodes missing or retired V1 nodes still served). "
              "Re-run later or pass --force. Propagation can take up to 6 hours.")
        return

    conn = connect()
    ensure_results_table(conn)
    qs = load_questions(conn, set(filter(None, a.qids.split(","))))
    run_id = a.resume or (time.strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:4])
    runs_for = lambda gt: a.runs_hard if int(gt["TIER"]) in (2, 3) else a.runs
    jobs = [("main", arm, ARMS[arm], gt, n) for gt in qs for arm in a.arms.split(",") for n in range(1, runs_for(gt) + 1)]
    if not a.skip_consistency:
        gts = {g["QID"]: g for g in load_questions(conn, set(PAIR_QIDS))}
        jobs += [("consistency", label, agent, gts[q], n) for label, agents in PAIRS.items()
                 for agent in agents for q in PAIR_QIDS for n in range(1, a.runs + 1)]
    if a.resume:
        cur = conn.cursor()
        cur.execute(f"SELECT EXPERIMENT, ARM, AGENT, QID, RUN_NO FROM {SCHEMA}.BENCHMARK_RESULTS WHERE RUN_ID = %s", (run_id,))
        saved = {tuple(r) for r in cur.fetchall()}
        cur.close()
        jobs = [j for j in jobs if (j[0], j[1], j[2], j[3]["QID"], j[4]) not in saved]
        print(f"resuming {run_id}: {len(saved)} calls already saved")
    print(f"run_id={run_id}: {len(jobs)} agent calls, {a.workers} parallel")

    rows, done = [], 0
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        futs = [ex.submit(task, *j) for j in jobs]
        for f in as_completed(futs):
            r = f.result()
            rows.append(r)
            done += 1
            print(f"  [{done}/{len(jobs)}] {r['experiment']:<11} {r['arm']:<6} {r['qid']} run{r['run_no']} "
                  f"{'OK ' if r['correct'] else 'BAD'} {r['latency_s']:>5}s tools={len(r['tools'])} "
                  f"val={r.get('headline_value')}")
            if len(rows) >= 12:
                save(conn, run_id, rows)
                rows = []
    if rows:
        save(conn, run_id, rows)

    sc = scorecard(conn, run_id)
    print_scorecard(sc)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"scorecard_{run_id}.json")
    with open(out, "w") as fh:
        json.dump({"run_id": run_id, **sc}, fh, indent=2, default=str)
    print(f"\nSaved {out}; raw rows in {SCHEMA}.BENCHMARK_RESULTS WHERE RUN_ID = '{run_id}'")
    conn.close()


if __name__ == "__main__":
    main()
