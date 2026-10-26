"use client";
import { useEffect, useState } from "react";
import { DEMO_QUESTIONS, EVAL_QUESTIONS, TIER_LABELS, TIER_PILLARS } from "@/lib/questions";

type Cell = { QID: string; ARM: string; N: number; OK: number; HEDGED: number; P50: number };
type Cons = { ARM: string; QID: string; AGREE: number; BOTH_RIGHT: number };
type Results = { runId: string | null; perQuestion?: Cell[]; consistency?: Cons[] };

const ARMS = [
  { id: "B", label: "B: Enriched SVs" },
  { id: "C", label: "C: Enriched SVs + BON" },
];

function pct(ok: number, n: number) {
  return n ? Math.round((100 * ok) / n) : 0;
}

export default function AnalysisView() {
  const [res, setRes] = useState<Results | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    fetch("http://localhost:5001/api/results")
      .then((r) => r.json())
      .then(setRes)
      .catch((e) => setErr(e.message));
  }, []);

  const cell = (qid: string, arm: string) => res?.perQuestion?.find((c) => c.QID === qid && c.ARM === arm);
  const tierScore = (tier: string, arm: string) => {
    const qids = EVAL_QUESTIONS.filter((q) => q.tier === tier).map((q) => q.id);
    const cells = (res?.perQuestion || []).filter((c) => c.ARM === arm && qids.includes(c.QID));
    return pct(cells.reduce((s, c) => s + c.OK, 0), cells.reduce((s, c) => s + c.N, 0));
  };

  return (
    <div className="space-y-6">
      <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6">
        <h3 className="text-lg font-semibold mb-2">How we measure BON uplift</h3>
        <p className="text-sm text-[var(--text-muted)] mb-3">
          Two agents with the same model, semantic views, budget and instructions: <strong>B = Enriched SVs only</strong> (ENRICHED_AGENT)
          and <strong>C = the same Enriched SVs + Business Ontology</strong> (BON_AGENT). <strong>BON uplift = C − B</strong>: the only difference
          between B and C is the Business Ontology tool. Each question runs 5 times per agent in Tiers 2–3 (where uplift is expected)
          and 3 times in Tiers 1 and 4; answers that offer competing
          numbers without committing to one are graded wrong. Tier 1 is a control: well-built SVs should already get it right.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 text-sm">
          {Object.entries(TIER_LABELS).map(([t, l]) => (
            <div key={t} className="rounded-lg border border-[var(--border)] bg-[var(--bg)] px-3 py-2">
              <div className="font-semibold">{TIER_PILLARS[t]}</div>
              <div className="text-xs text-[var(--text-muted)]">{l}</div>
            </div>
          ))}
        </div>
      </div>

      {err && <div className="text-sm text-red-600">Could not load results: {err}. Is the API server running on :5001?</div>}

      {res && !res.runId && (
        <div className="rounded-xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950 p-5 text-sm">
          <strong>Benchmark results pending.</strong> The full run starts once the Business Ontology search index has refreshed
          (up to 6 hours after ontology edits). Run <code>python benchmark/run_benchmark.py</code>; results appear here automatically.
          Meanwhile, use the Comparison tab to run any question live.
        </div>
      )}

      {res?.runId && (
        <>
          <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6">
            <div className="flex justify-between mb-3">
              <h3 className="text-lg font-semibold">Accuracy by value pillar</h3>
              <span className="text-xs text-[var(--text-muted)] font-mono">run {res.runId}</span>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="text-left text-xs text-[var(--text-muted)]">
                  <th className="py-1.5 pr-4">Pillar</th>
                  {ARMS.map((a) => <th key={a.id} className="py-1.5 pr-4">{a.label}</th>)}
                  <th className="py-1.5">BON uplift (C − B)</th>
                </tr></thead>
                <tbody>
                  {Object.keys(TIER_LABELS).map((t) => {
                    const b = tierScore(t, "B"), c = tierScore(t, "C");
                    return (
                      <tr key={t} className="border-t border-[var(--border)]">
                        <td className="py-1.5 pr-4">{TIER_PILLARS[t]}</td>
                        {ARMS.map((a) => <td key={a.id} className="py-1.5 pr-4 font-mono">{tierScore(t, a.id)}%</td>)}
                        <td className={`py-1.5 font-mono font-semibold ${c - b > 0 ? "text-[var(--bon)]" : ""}`}>{c - b > 0 ? "+" : ""}{c - b} pts</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>

          <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6">
            <h3 className="text-lg font-semibold mb-1">Demo questions (correct runs / total)</h3>
            <p className="text-xs text-[var(--text-muted)] mb-3">
              Tier 1: three controls. Tiers 2–4: the questions where the Business Ontology was right and the SV-only agent was not.
              Tier scores above use all 20 benchmark questions.
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="text-left text-xs text-[var(--text-muted)]">
                  <th className="py-1.5 pr-3">Q</th><th className="py-1.5 pr-3">Question</th>
                  {ARMS.map((a) => <th key={a.id} className="py-1.5 pr-3">{a.id}</th>)}
                  <th className="py-1.5">Governed by</th>
                </tr></thead>
                <tbody>
                  {DEMO_QUESTIONS.map((q) => (
                    <tr key={q.id} className="border-t border-[var(--border)]">
                      <td className="py-1.5 pr-3 font-mono">{q.id}</td>
                      <td className="py-1.5 pr-3">{q.q}</td>
                      {ARMS.map((a) => {
                        const c = cell(q.id, a.id);
                        return (
                          <td key={a.id} className="py-1.5 pr-3 font-mono whitespace-nowrap">
                            {c ? `${c.OK}/${c.N}` : "–"}{c && c.HEDGED > 0 ? <span className="text-amber-600"> ({c.HEDGED} hedged)</span> : null}
                          </td>
                        );
                      })}
                      <td className="py-1.5 text-xs text-[var(--text-muted)]">{q.governed}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {res.consistency && res.consistency.length > 0 && (
            <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6">
              <h3 className="text-lg font-semibold mb-2">Do two teams get the same answer?</h3>
              <p className="text-sm text-[var(--text-muted)] mb-3">
                Finance agent (Finance + Purchasing SVs) vs Sales agent (Sales + Purchasing SVs), same question, same run.
              </p>
              <table className="w-full text-sm">
                <thead><tr className="text-left text-xs text-[var(--text-muted)]">
                  <th className="py-1.5 pr-4">Setup</th><th className="py-1.5 pr-4">Question</th><th className="py-1.5 pr-4">Agree</th><th className="py-1.5">Both right</th>
                </tr></thead>
                <tbody>
                  {res.consistency.map((c) => (
                    <tr key={c.ARM + c.QID} className="border-t border-[var(--border)]">
                      <td className="py-1.5 pr-4">{c.ARM === "bon" ? "With BON" : "Without BON"}</td>
                      <td className="py-1.5 pr-4 font-mono">{c.QID}</td>
                      <td className="py-1.5 pr-4 font-mono">{c.AGREE}%</td>
                      <td className="py-1.5 font-mono">{c.BOTH_RIGHT}%</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </div>
  );
}
