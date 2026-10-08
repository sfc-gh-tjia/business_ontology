import { executeQuery } from "./snowflake";
import { AgentResponse } from "./types";

const BASELINE_AGENT = "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.SAP_BASELINE_AGENT";
const BON_AGENT = "DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BON_SV_NATIVE_AGENT";

function parseAgentResponse(raw: string): AgentResponse {
  const htmlArtifacts: string[] = [];
  const textParts: string[] = [];

  try {
    const json = JSON.parse(raw);
    const content = json?.content || [];
    for (const item of content) {
      if (item?.type === "text" && item.text?.trim()) {
        textParts.push(item.text.trim());
      } else if (item?.type === "tool_result") {
        const trContent = item.tool_result?.content || [];
        for (const tc of trContent) {
          if (tc?.type === "json") {
            const result = tc.json?.result || "";
            if (typeof result === "string" && result.includes("<!DOCTYPE html>")) {
              htmlArtifacts.push(result);
            }
          }
        }
      }
    }
  } catch {}

  // Fallback regex for HTML
  if (htmlArtifacts.length === 0 && raw.includes("<!DOCTYPE html>")) {
    const match = raw.match(/"result"\s*:\s*"(<!DOCTYPE html>.*?<\/html>)"/s);
    if (match) {
      htmlArtifacts.push(
        match[1].replace(/\\"/g, '"').replace(/\\n/g, "\n").replace(/\\t/g, "\t")
      );
    }
  }

  // Fallback text extraction
  if (textParts.length === 0) {
    const matches = raw.matchAll(/"type"\s*:\s*"text"\s*,\s*"text"\s*:\s*"([^"]+(?:\\.[^"]*)*)"/g);
    for (const m of matches) {
      const t = m[1].replace(/\\n/g, "\n").replace(/\\"/g, '"');
      if (t.trim().length > 5) textParts.push(t.trim());
    }
  }

  return { text: textParts.join("\n"), htmlArtifacts, elapsed: 0 };
}

async function callSingleAgent(question: string, agentFqn: string): Promise<AgentResponse> {
  const request = JSON.stringify({
    messages: [{ role: "user", content: [{ type: "text", text: question }] }],
  });

  const sql = `SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('${agentFqn}', $$${request}$$) AS response`;
  const start = Date.now();
  try {
    const rows = await executeQuery(sql);
    const elapsed = (Date.now() - start) / 1000;
    if (rows.length > 0) {
      const resp = parseAgentResponse(rows[0].RESPONSE || rows[0].response || "");
      return { ...resp, elapsed: Math.round(elapsed * 10) / 10 };
    }
  } catch (err: any) {
    const elapsed = (Date.now() - start) / 1000;
    return { text: `Error: ${err.message}`, htmlArtifacts: [], elapsed: Math.round(elapsed * 10) / 10 };
  }
  return { text: "No response.", htmlArtifacts: [], elapsed: 0 };
}

export async function callBothAgents(question: string) {
  const [baseline, bon] = await Promise.all([
    callSingleAgent(question, BASELINE_AGENT),
    callSingleAgent(question, BON_AGENT),
  ]);
  return { baseline, bon };
}
