"use client";
import { useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { EVAL_QUESTIONS, TIER_LABELS } from "@/lib/questions";
import { AgentResponse } from "@/lib/types";

function AgentPanel({ label, response, color }: { label: string; response: AgentResponse | null; color: string }) {
  if (!response) {
    return (
      <div className={`rounded-xl border-l-4 border-[var(--border)] bg-[var(--bg-card)] p-5 animate-pulse`}
           style={{ borderLeftColor: color }}>
        <div className="h-4 bg-[var(--border)] rounded w-1/3 mb-3" />
        <div className="h-3 bg-[var(--border)] rounded w-full mb-2" />
        <div className="h-3 bg-[var(--border)] rounded w-2/3" />
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] overflow-hidden"
         style={{ borderLeftWidth: "4px", borderLeftColor: color }}>
      <div className="flex items-center justify-between px-5 py-3 border-b border-[var(--border)] bg-[var(--bg)]">
        <span className="font-semibold text-sm">{label}</span>
        <span className="text-xs px-2 py-0.5 rounded-full bg-[var(--border)] text-[var(--text-muted)]">
          {response.elapsed}s
        </span>
      </div>
      <div className="p-5">
        {response.text ? (
          <div className="text-sm leading-relaxed prose prose-sm dark:prose-invert max-w-none">
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{response.text}</ReactMarkdown>
          </div>
        ) : (
          <p className="text-sm text-[var(--text-muted)] italic">No text response</p>
        )}
        {response.htmlArtifacts.map((html, i) => (
          <div key={i} className="mt-4 border border-[var(--border)] rounded-lg overflow-hidden">
            <div className="text-xs px-3 py-1.5 bg-[var(--bg)] text-[var(--text-muted)] border-b border-[var(--border)]">
              Interactive Graph (zoom, pan, drag)
            </div>
            <iframe
              srcDoc={html}
              className="w-full border-0"
              style={{ height: "450px" }}
              sandbox="allow-scripts"
            />
          </div>
        ))}
      </div>
    </div>
  );
}

export default function ComparisonView() {
  const [selectedIdx, setSelectedIdx] = useState<number>(0); // default to Q1
  const [customQ, setCustomQ] = useState("");
  const [loading, setLoading] = useState(false);
  const [baseline, setBaseline] = useState<AgentResponse | null>(null);
  const [bon, setBon] = useState<AgentResponse | null>(null);
  const [currentQ, setCurrentQ] = useState<{ q: string; id: string; expected: string } | null>(null);

  const runQuestion = async (question: string, qId: string, expected: string) => {
    setLoading(true);
    setBaseline(null);
    setBon(null);
    setCurrentQ({ q: question, id: qId, expected });

    try {
      const res = await fetch("http://localhost:5001/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ question }),
      });
      const data = await res.json();
      setBaseline(data.baseline);
      setBon(data.bon);
    } catch (err: any) {
      setBaseline({ text: `Error: ${err.message}`, htmlArtifacts: [], elapsed: 0 });
      setBon({ text: `Error: ${err.message}`, htmlArtifacts: [], elapsed: 0 });
    }
    setLoading(false);
  };

  const grouped = Object.entries(TIER_LABELS).map(([tier, label]) => ({
    label,
    questions: EVAL_QUESTIONS.filter((q) => q.tier === tier),
  }));

  return (
    <div>
      {/* Question selector */}
      <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-5 mb-6">
        <div className="flex flex-col lg:flex-row gap-4">
          <div className="flex-1">
            <label className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2 block">
              Select a question
            </label>
            <select
              value={selectedIdx}
              onChange={(e) => setSelectedIdx(parseInt(e.target.value))}
              className="w-full px-3 py-2 rounded-lg border border-[var(--border)] bg-[var(--bg)] text-sm"
            >
              {grouped.map((g) => (
                <optgroup key={g.label} label={g.label}>
                  {g.questions.map((q) => (
                    <option key={q.id} value={EVAL_QUESTIONS.indexOf(q)}>
                      {q.id}: {q.q.slice(0, 80)}
                    </option>
                  ))}
                </optgroup>
              ))}
            </select>
          </div>
          <div className="flex items-end">
            <button
              onClick={() => {
                const q = EVAL_QUESTIONS[selectedIdx];
                runQuestion(q.q, q.id, q.expected);
              }}
              disabled={loading}
              className="px-6 py-2 rounded-lg bg-[var(--bon)] text-white font-medium text-sm hover:opacity-90 disabled:opacity-50 transition-opacity"
            >
              {loading ? "Running..." : "Ask Both Agents"}
            </button>
          </div>
        </div>

        <div className="mt-4 pt-4 border-t border-[var(--border)]">
          <label className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2 block">
            Or type a custom question
          </label>
          <div className="flex gap-3">
            <input
              type="text"
              value={customQ}
              onChange={(e) => setCustomQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && customQ.trim()) {
                  runQuestion(customQ, "Custom", "");
                  setCustomQ("");
                }
              }}
              placeholder="Type any supply chain question..."
              className="flex-1 px-3 py-2 rounded-lg border border-[var(--border)] bg-[var(--bg)] text-sm"
            />
            <button
              onClick={() => {
                if (customQ.trim()) {
                  runQuestion(customQ, "Custom", "");
                  setCustomQ("");
                }
              }}
              disabled={loading || !customQ.trim()}
              className="px-5 py-2 rounded-lg border border-[var(--border)] text-sm font-medium hover:bg-[var(--bg)] disabled:opacity-50 transition-opacity"
            >
              Ask
            </button>
          </div>
        </div>
      </div>

      {/* Current question display */}
      {currentQ && (
        <div className="mb-6">
          <div className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-1">
            {currentQ.id}
          </div>
          <p className="text-lg font-medium">{currentQ.q}</p>
        </div>
      )}

      {/* Loading indicator */}
      {loading && (
        <div className="text-center py-12 text-[var(--text-muted)]">
          <div className="inline-block w-8 h-8 border-2 border-[var(--bon)] border-t-transparent rounded-full animate-spin mb-3" />
          <p className="text-sm">Running both agents in parallel...</p>
        </div>
      )}

      {/* Side-by-side results */}
      {(baseline || bon || loading) && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
          <AgentPanel label="Baseline (SV Only — no business context)" response={baseline} color="var(--baseline)" />
          <AgentPanel label="BON Agent (SV + Business Ontology)" response={bon} color="var(--bon)" />
        </div>
      )}

      {/* Expected answer */}
      {currentQ?.expected && !loading && (baseline || bon) && (
        <div className="mt-5 rounded-xl border border-emerald-200 dark:border-emerald-800 bg-emerald-50 dark:bg-emerald-950 px-5 py-4">
          <div className="text-xs font-semibold uppercase tracking-wider text-emerald-600 dark:text-emerald-400 mb-1">
            Expected Answer
          </div>
          <p className="text-sm">{currentQ.expected}</p>
        </div>
      )}
    </div>
  );
}
