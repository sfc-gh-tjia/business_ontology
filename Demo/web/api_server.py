"""
Backend API server for the BON vs Baseline React app.
Uses Flask + snowflake.connector (which supports config.toml connections).

Run: python api_server.py
Then: npm run dev (in the web/ directory)
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import snowflake.connector
import json
import re
import time
from concurrent.futures import ThreadPoolExecutor

app = Flask(__name__)
CORS(app)

SCHEMA = "DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2"
# Left panel: the same enriched SVs without BON, so the only difference between panels is the BON tool.
BASELINE_AGENT = f"{SCHEMA}.ENRICHED_AGENT"
BON_AGENT = f"{SCHEMA}.BON_AGENT"


def get_connection():
    return snowflake.connector.connect(
        connection_name="tjia_demo_aws2",
        database="DB_ONTOLOGY_CONTROL_PLANE",
        schema="SAP_BON_V2",
    )


def parse_agent_response(raw):
    html_artifacts = []
    text_parts = []
    tools = []
    raw_str = str(raw) if raw else ""

    try:
        resp = json.loads(raw) if isinstance(raw, str) else raw
        if isinstance(resp, dict):
            for item in resp.get("content", []):
                if not isinstance(item, dict):
                    continue
                if item.get("type") == "tool_use":
                    tools.append(item.get("tool_use", {}).get("name", ""))
                if item.get("type") == "text" and item.get("text", "").strip():
                    text_parts.append(item["text"].strip())
                elif item.get("type") == "tool_result":
                    for tc in item.get("tool_result", {}).get("content", []):
                        if isinstance(tc, dict) and tc.get("type") == "json":
                            result_str = tc.get("json", {}).get("result", "")
                            if isinstance(result_str, str) and "<!DOCTYPE html>" in result_str:
                                html_artifacts.append(result_str)
    except (json.JSONDecodeError, TypeError):
        pass

    if not html_artifacts and "<!DOCTYPE html>" in raw_str:
        match = re.search(r'"result"\s*:\s*"(<!DOCTYPE html>.*?</html>)"', raw_str, re.DOTALL)
        if match:
            html = match.group(1).replace('\\"', '"').replace('\\n', '\n').replace('\\t', '\t')
            html_artifacts.append(html)

    if not text_parts:
        for m in re.finditer(r'"type"\s*:\s*"text"\s*,\s*"text"\s*:\s*"([^"]+(?:\\.[^"]*)*)"', raw_str):
            t = m.group(1).replace('\\n', '\n').replace('\\"', '"')
            if t.strip() and len(t.strip()) > 5:
                text_parts.append(t.strip())

    return {"text": "\n".join(text_parts), "htmlArtifacts": html_artifacts, "tools": [t for t in tools if t]}


def call_single_agent(question, agent_fqn):
    req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": question}]}]})
    sql = f"SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('{agent_fqn}', $${req}$$) AS response"
    start = time.time()
    try:
        conn = get_connection()
        cur = conn.cursor()
        print(f"[{agent_fqn.split('.')[-1]}] Executing DATA_AGENT_RUN...", flush=True)
        cur.execute(sql)
        row = cur.fetchone()
        elapsed = round(time.time() - start, 1)
        print(f"[{agent_fqn.split('.')[-1]}] Done in {elapsed}s, row={'yes' if row else 'no'}", flush=True)
        cur.close()
        conn.close()
        if row:
            parsed = parse_agent_response(row[0])
            parsed["elapsed"] = elapsed
            return parsed
    except Exception as e:
        elapsed = round(time.time() - start, 1)
        print(f"[{agent_fqn.split('.')[-1]}] ERROR: {type(e).__name__}: {e}", flush=True)
        return {"text": f"Error: {str(e)}", "htmlArtifacts": [], "elapsed": elapsed}
    return {"text": "No response.", "htmlArtifacts": [], "elapsed": 0}


@app.route("/api/agent", methods=["POST"])
def agent_endpoint():
    data = request.json
    question = data.get("question", "")
    if not question:
        return jsonify({"error": "Missing question"}), 400
    baseline_agent = BASELINE_AGENT

    with ThreadPoolExecutor(max_workers=2) as executor:
        f_baseline = executor.submit(call_single_agent, question, baseline_agent)
        f_bon = executor.submit(call_single_agent, question, BON_AGENT)
        try:
            baseline = f_baseline.result(timeout=180)
        except Exception as e:
            baseline = {"text": f"Error: {e}", "htmlArtifacts": [], "elapsed": 0}
        try:
            bon = f_bon.result(timeout=180)
        except Exception as e:
            bon = {"text": f"Error: {e}", "htmlArtifacts": [], "elapsed": 0}

    baseline = baseline or {"text": "No response.", "htmlArtifacts": [], "elapsed": 0}
    bon = bon or {"text": "No response.", "htmlArtifacts": [], "elapsed": 0}

    return jsonify({"baseline": baseline, "bon": bon})


@app.route("/api/results", methods=["GET"])
def results_endpoint():
    """Latest V2 benchmark run: per-question, per-arm accuracy plus summary metrics."""
    conn = get_connection()
    cur = conn.cursor(snowflake.connector.DictCursor)
    try:
        cur.execute(f"SHOW TABLES LIKE 'BENCHMARK_RESULTS' IN SCHEMA {SCHEMA}")
        if not cur.fetchall():
            return jsonify({"runId": None})
        cur.execute(f"""SELECT RUN_ID FROM {SCHEMA}.BENCHMARK_RESULTS WHERE EXPERIMENT = 'main'
                        GROUP BY RUN_ID HAVING COUNT(*) >= 100 ORDER BY MAX(RUN_TS) DESC LIMIT 1""")
        row = cur.fetchone()
        if not row:
            return jsonify({"runId": None})
        run_id = row["RUN_ID"]
        cur.execute(f"""SELECT QID, ARM, COUNT(*) N, SUM(IFF(CORRECT,1,0)) OK, SUM(IFF(HEDGED,1,0)) HEDGED,
                               ROUND(MEDIAN(LATENCY_S),1) P50
                        FROM {SCHEMA}.BENCHMARK_RESULTS WHERE RUN_ID = %s AND EXPERIMENT = 'main'
                        GROUP BY 1,2 ORDER BY 1,2""", (run_id,))
        per_q = cur.fetchall()
        cur.execute(f"""WITH p AS (SELECT ARM, QID, RUN_NO, AGENT, HEADLINE_VALUE, CORRECT FROM {SCHEMA}.BENCHMARK_RESULTS
                                  WHERE RUN_ID = %s AND EXPERIMENT = 'consistency')
                        SELECT f.ARM, f.QID, ROUND(100*AVG(IFF(ROUND(f.HEADLINE_VALUE,1) = ROUND(s.HEADLINE_VALUE,1),1,0)),0) AGREE,
                               ROUND(100*AVG(IFF(f.CORRECT AND s.CORRECT,1,0)),0) BOTH_RIGHT
                        FROM p f JOIN p s ON f.ARM = s.ARM AND f.QID = s.QID AND f.RUN_NO = s.RUN_NO
                         AND f.AGENT LIKE 'FINANCE%%' AND s.AGENT LIKE 'SALES%%' GROUP BY 1,2 ORDER BY 1,2""", (run_id,))
        consistency = cur.fetchall()
        return jsonify({"runId": run_id, "perQuestion": per_q, "consistency": consistency})
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    print("Starting BON eval API server on http://localhost:5001")
    app.run(port=5001, debug=False)
