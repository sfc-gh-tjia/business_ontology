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

BASELINE_AGENT = "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_AGENT"
BON_AGENT = "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BON_SV_NATIVE_AGENT"


def get_connection():
    return snowflake.connector.connect(
        connection_name="tjia_demo_aws2",
        database="DB_ONTOLOGY_CONTROL_PLANE",
        schema="SAP_PRODUCTION",
    )


def parse_agent_response(raw):
    html_artifacts = []
    text_parts = []
    raw_str = str(raw) if raw else ""

    try:
        resp = json.loads(raw) if isinstance(raw, str) else raw
        if isinstance(resp, dict):
            for item in resp.get("content", []):
                if not isinstance(item, dict):
                    continue
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

    return {"text": "\n".join(text_parts), "htmlArtifacts": html_artifacts}


def call_single_agent(question, agent_fqn):
    req = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": question}]}]})
    sql = f"SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('{agent_fqn}', $${req}$$) AS response"
    start = time.time()
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(sql)
        row = cur.fetchone()
        elapsed = round(time.time() - start, 1)
        cur.close()
        conn.close()
        if row:
            parsed = parse_agent_response(row[0])
            parsed["elapsed"] = elapsed
            return parsed
    except Exception as e:
        elapsed = round(time.time() - start, 1)
        return {"text": f"Error: {str(e)}", "htmlArtifacts": [], "elapsed": elapsed}
    return {"text": "No response.", "htmlArtifacts": [], "elapsed": 0}


@app.route("/api/agent", methods=["POST"])
def agent_endpoint():
    data = request.json
    question = data.get("question", "")
    if not question:
        return jsonify({"error": "Missing question"}), 400

    with ThreadPoolExecutor(max_workers=2) as executor:
        f_baseline = executor.submit(call_single_agent, question, BASELINE_AGENT)
        f_bon = executor.submit(call_single_agent, question, BON_AGENT)
        baseline = f_baseline.result()
        bon = f_bon.result()

    return jsonify({"baseline": baseline, "bon": bon})


if __name__ == "__main__":
    print("Starting BON eval API server on http://localhost:5001")
    app.run(port=5001, debug=True)
