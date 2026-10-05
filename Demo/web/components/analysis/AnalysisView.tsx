"use client";

const ANALYSIS = [
  {
    id: "Q1",
    question: "How many suppliers do we have?",
    baseline: { answer: "15", wrong: true },
    bon: { answer: "14", wrong: false },
    category: "Business Rule",
    whyBaselineFails: [
      "Counts all rows in LFA1: SELECT COUNT(DISTINCT LIFNR) = 15",
      "Cannot know KTOKK='ZPRB' means Probationary and should be excluded",
      "SV description says 'Account group' — not enough to infer the exclusion rule",
    ],
    whyBonWorks: [
      "Formula 1 defines: WHERE KTOKK IN ('ZSTR','ZSTD') — excludes ZPRB",
      "Encodes institutional policy: probationary vendors are not active suppliers",
    ],
    insight: "Business exclusion rules exist in people's heads, not in column names.",
  },
  {
    id: "Q2",
    question: "What is our on-time delivery rate?",
    baseline: { answer: "90%", wrong: true },
    bon: { answer: "66.7%", wrong: false },
    category: "Competing Metric",
    whyBaselineFails: [
      "Two OTD numbers exist: LFA2.OTRAT (~90%) and LIKP WADAT vs LFDAT (66.7%)",
      "Baseline picks OTRAT — a pre-computed column, easier to query",
      "Carrier self-reported rates are systematically higher than reality",
    ],
    whyBonWorks: [
      "Formula 2: WADAT <= LFDAT WHERE STATU='D' — operational OTD",
      "Explicitly warns: 'OTRAT is carrier self-reported, NEVER use for operational OTD'",
    ],
    insight: "When two numbers answer the same question, BON picks the canonical one.",
  },
  {
    id: "Q3",
    question: "Weighted supply risk score per material?",
    baseline: { answer: "Weights: 40/35/25", wrong: true },
    bon: { answer: "Weights: 40/30/30", wrong: false },
    category: "Composite Formula",
    whyBaselineFails: [
      "Must guess the weighting scheme — chose 40/35/25",
      "Different weights produce different material rankings",
      "Different rankings drive different procurement decisions",
    ],
    whyBonWorks: [
      "Formula 4: 0.4*single_source + 0.3*defect + 0.3*delivery_risk",
      "States: 'These weights are FIXED business policy. Do not change them.'",
    ],
    insight: "Composite metrics with business-defined parameters are impossible to guess correctly.",
  },
  {
    id: "Q4",
    question: "What is our COGS for raw materials?",
    baseline: { answer: "Used COEP instead of BSEG", wrong: true },
    bon: { answer: "$1,290,020", wrong: false },
    category: "Sign Convention",
    whyBaselineFails: [
      "Doesn't know HKONT='0040100000' = COGS Raw Materials in BSEG",
      "Looked at COEP cost postings instead — different table, different numbers",
      "Even if it found BSEG, wouldn't know BSCHL=34 (credit memos) must be subtracted",
    ],
    whyBonWorks: [
      "Formula 7: SUM(CASE WHEN BSCHL='31' THEN DMBTR ELSE -DMBTR END) WHERE HKONT='0040100000'",
      "Decodes HKONT as COGS Raw Materials and BSCHL as invoice vs credit memo",
      "Credit memos are quality returns — ignoring them overstates COGS by ~$63K",
    ],
    insight: "Finance sign conventions (posting keys) are domain-specific accounting rules.",
  },
  {
    id: "Q5",
    question: "Gross margin on Integrated System Module (ASSY-004)?",
    baseline: { answer: "$221,000", wrong: true },
    bon: { answer: "$296,855", wrong: false },
    category: "Cross-Domain Chain",
    whyBaselineFails: [
      "Used MARA.STPRS ($520) as unit cost — the assembly's standard price",
      "$520 is the SELLING cost, not the material cost to BUILD it",
      "No FK connects VBAP (sales) to BSEG (costs) or STPO (BOM)",
      "Didn't know to chain: Sales -> BOM (recursive) -> leaf material prices",
    ],
    whyBonWorks: [
      "Formula 8 defines: Revenue (VBAP) - BOM cost rollup (STPO recursive -> MARA.STPRS)",
      "Cross-domain chain: Sales -> Material -> BOM -> Standard Prices",
      "Correctly computes: $286.60/unit * 325 units = $93,145 material cost",
      "$390,000 revenue - $93,145 = $296,855 gross margin",
    ],
    insight: "The strongest differentiator: cross-domain chains where no FK exists between Sales and Purchasing. The connection goes through BOM — only BON maps this path.",
  },
];

const TIER_C = [
  {
    id: "Q9",
    question: "Cut procurement costs 15% without disrupting highest-revenue product?",
    baseline: { answer: "Timed out / incomplete", wrong: true },
    bon: { answer: "Cut MAT-011, MAT-009, MAT-014 = $211K (15.6%)", wrong: false },
    category: "Constrained Optimization",
    whyBaselineFails: [
      "Must identify highest-revenue product (ASSY-004) from VBAP, then trace its BOM",
      "Must know which materials are 'protected' (BOM inputs) vs cuttable",
      "Without the BOM-to-revenue chain, cannot determine constraint boundaries",
      "Timed out trying to discover join paths through trial and error",
    ],
    whyBonWorks: [
      "Ontology maps: VBAP (revenue) -> STPO (BOM recursive) -> EKPO (spend)",
      "Identifies ASSY-004 as highest revenue, explodes its BOM to find protected materials",
      "Ranks non-protected spend: MAT-011 ($177.5K), MAT-009 ($22.5K), MAT-014 ($11K)",
      "Provides a 'do NOT cut' list: MAT-004, MAT-003, MAT-005, MAT-015, MAT-007",
    ],
    insight: "Constraint satisfaction ('cut X without breaking Y') requires knowing the dependency chain from revenue products back through BOMs to procurement spend.",
  },
  {
    id: "Q10",
    question: "Which customer is most important (profit after material costs)?",
    baseline: { answer: "C-1001 with $177K profit (wrong cost basis)", wrong: true },
    bon: { answer: "C-1001 with $238K profit + C-1004 highest margin", wrong: false },
    category: "Strategic Profitability",
    whyBaselineFails: [
      "Used assembly STPRS ($520) as unit cost — this is the standard price, not material cost",
      "Computed $177K profit: a $60K understatement of actual profit",
      "Wrong cost basis cascades into wrong margin rankings and strategic decisions",
    ],
    whyBonWorks: [
      "Formula 8: Revenue (VBAP) - BOM cost rollup (STPO recursive -> leaf STPRS)",
      "Correct profit: ~$238K for C-1001 using $286.60/unit BOM cost",
      "Also identified C-1004 as highest-margin customer (80.2%) — a growth opportunity",
    ],
    insight: "Wrong cost basis ($520 vs $286.60) produces a $60K error on one customer alone. A CFO making decisions on this data would misallocate resources.",
  },
  {
    id: "Q11",
    question: "Maximum discount on ASSY-004 before losing money?",
    baseline: { answer: "57.1% (wrong cost floor)", wrong: true },
    bon: { answer: "75.4% (correct BOM cost floor)", wrong: false },
    category: "Pricing Constraint",
    whyBaselineFails: [
      "Used STPRS ($520) as cost floor: max discount = 1 - 520/1200 = 56.7%",
      "The $520 standard price includes overhead/markup — it's not material cost",
      "Would leave $680/unit of margin 'on the table' in negotiation",
    ],
    whyBonWorks: [
      "BOM cost rollup: $286.60/unit is the true material floor",
      "Max discount = 1 - 286.60/1200 = 75.4%",
      "The 18-point difference ($520 vs $286.60) is actionable in sales negotiations",
    ],
    insight: "A sales team using the baseline's 57% floor would refuse deals that are actually profitable. The 18pp gap between wrong and right cost basis directly impacts revenue.",
  },
];

const TIES = [
  {
    id: "Q6",
    question: "Customer discount revenue leakage?",
    result: "Both: $34,085",
    why: "LLM correctly identified KSCHL K007 as discounts from the negative KWERT values and excluded KF00 surcharges.",
  },
  {
    id: "Q7",
    question: "V10045 revenue at risk?",
    result: "Both: $746,000",
    why: "LLM traced the full cross-domain chain (Supplier->Materials->BOM recursive->Assemblies->Sales). Impressive but took nearly the full budget.",
  },
  {
    id: "Q8",
    question: "US Manufacturing total cost?",
    result: "Both: $419,750",
    why: "LLM queried COEP WHERE OBJNR='KS-MFG-US' correctly — the cost object code was discoverable from data.",
  },
];

export default function AnalysisView() {
  return (
    <div>
      <p className="text-[var(--text-muted)] mb-6">
        Why does the BON agent answer correctly where the baseline fails? Each case shows the
        specific business knowledge the ontology provides — and why the LLM cannot infer it from schema alone.
      </p>

      <div className="grid grid-cols-2 gap-4 mb-8">
        <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-5 text-center">
          <div className="text-3xl font-bold" style={{ color: "var(--baseline)" }}>27.3%</div>
          <div className="text-sm text-[var(--text-muted)] mt-1">Baseline (SV Only)</div>
          <div className="text-xs text-[var(--text-muted)]">3 correct / 11 questions</div>
        </div>
        <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-5 text-center">
          <div className="text-3xl font-bold" style={{ color: "var(--bon)" }}>100%</div>
          <div className="text-sm text-[var(--text-muted)] mt-1">BON Agent</div>
          <div className="text-xs text-[var(--text-muted)]">11 correct / 11 questions</div>
        </div>
      </div>

      <h2 className="text-lg font-semibold mb-4">Tier A+B: Where BON Wins (5 questions)</h2>
      <p className="text-xs text-[var(--text-muted)] mb-4">Business knowledge and cross-domain reasoning</p>
      <div className="space-y-6 mb-10">
        {ANALYSIS.map((a) => (
          <div key={a.id} className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] overflow-hidden">
            <div className="px-5 py-3 border-b border-[var(--border)] bg-[var(--bg)] flex items-center justify-between">
              <div>
                <span className="text-xs font-semibold text-[var(--text-muted)]">{a.id}</span>
                <span className="ml-2 text-xs px-2 py-0.5 rounded-full bg-sky-100 dark:bg-sky-900 text-sky-700 dark:text-sky-300">
                  {a.category}
                </span>
              </div>
            </div>
            <div className="px-5 py-4">
              <p className="font-medium mb-4">{a.question}</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <div className="rounded-lg border border-red-200 dark:border-red-900 bg-red-50 dark:bg-red-950 p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-red-600 dark:text-red-400 text-lg">&#x2717;</span>
                    <span className="font-semibold text-sm">Baseline: {a.baseline.answer}</span>
                  </div>
                  <ul className="text-xs text-[var(--text-muted)] space-y-1">
                    {a.whyBaselineFails.map((line, i) => (
                      <li key={i}>{line}</li>
                    ))}
                  </ul>
                </div>
                <div className="rounded-lg border border-emerald-200 dark:border-emerald-900 bg-emerald-50 dark:bg-emerald-950 p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-emerald-600 dark:text-emerald-400 text-lg">&#x2713;</span>
                    <span className="font-semibold text-sm">BON: {a.bon.answer}</span>
                  </div>
                  <ul className="text-xs text-[var(--text-muted)] space-y-1">
                    {a.whyBonWorks.map((line, i) => (
                      <li key={i}>{line}</li>
                    ))}
                  </ul>
                </div>
              </div>
              <div className="text-sm bg-[var(--bg)] rounded-lg px-4 py-3 border border-[var(--border)]">
                <strong>Key insight:</strong> {a.insight}
              </div>
            </div>
          </div>
        ))}
      </div>

      <h2 className="text-lg font-semibold mb-4 mt-4">Tier C: Strategic Decision Support (3 questions)</h2>
      <p className="text-xs text-[var(--text-muted)] mb-4">Multi-step reasoning with constraints, profitability analysis, and pricing optimization</p>
      <div className="space-y-6 mb-10">
        {TIER_C.map((a) => (
          <div key={a.id} className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] overflow-hidden">
            <div className="px-5 py-3 border-b border-[var(--border)] bg-[var(--bg)] flex items-center justify-between">
              <div>
                <span className="text-xs font-semibold text-[var(--text-muted)]">{a.id}</span>
                <span className="ml-2 text-xs px-2 py-0.5 rounded-full bg-violet-100 dark:bg-violet-900 text-violet-700 dark:text-violet-300">
                  {a.category}
                </span>
              </div>
            </div>
            <div className="px-5 py-4">
              <p className="font-medium mb-4">{a.question}</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <div className="rounded-lg border border-red-200 dark:border-red-900 bg-red-50 dark:bg-red-950 p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-red-600 dark:text-red-400 text-lg">&#x2717;</span>
                    <span className="font-semibold text-sm">Baseline: {a.baseline.answer}</span>
                  </div>
                  <ul className="text-xs text-[var(--text-muted)] space-y-1">
                    {a.whyBaselineFails.map((line, i) => (
                      <li key={i}>{line}</li>
                    ))}
                  </ul>
                </div>
                <div className="rounded-lg border border-emerald-200 dark:border-emerald-900 bg-emerald-50 dark:bg-emerald-950 p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-emerald-600 dark:text-emerald-400 text-lg">&#x2713;</span>
                    <span className="font-semibold text-sm">BON: {a.bon.answer}</span>
                  </div>
                  <ul className="text-xs text-[var(--text-muted)] space-y-1">
                    {a.whyBonWorks.map((line, i) => (
                      <li key={i}>{line}</li>
                    ))}
                  </ul>
                </div>
              </div>
              <div className="text-sm bg-[var(--bg)] rounded-lg px-4 py-3 border border-[var(--border)]">
                <strong>Key insight:</strong> {a.insight}
              </div>
            </div>
          </div>
        ))}
      </div>

      <h2 className="text-lg font-semibold mb-4">Where Both Agents Tie (3 questions)</h2>
      <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] overflow-hidden mb-8">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--border)] bg-[var(--bg)]">
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-[var(--text-muted)]">Question</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-[var(--text-muted)]">Result</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-[var(--text-muted)]">Why the LLM handles it alone</th>
            </tr>
          </thead>
          <tbody>
            {TIES.map((t) => (
              <tr key={t.id} className="border-b border-[var(--border)] last:border-0">
                <td className="px-4 py-3 font-medium">
                  <span className="text-xs text-[var(--text-muted)]">{t.id}:</span> {t.question}
                </td>
                <td className="px-4 py-3 text-[var(--text-muted)]">{t.result}</td>
                <td className="px-4 py-3 text-[var(--text-muted)]">{t.why}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="rounded-xl border border-sky-200 dark:border-sky-800 bg-sky-50 dark:bg-sky-950 px-6 py-5">
        <h3 className="font-semibold mb-2">The BON Value Proposition</h3>
        <p className="text-sm text-[var(--text-muted)] leading-relaxed">
          The ontology does not help the AI query data — the AI is already good at SQL.
          What the ontology provides is <strong>the right answer when multiple plausible
          answers exist</strong>, and <strong>cross-domain reasoning paths</strong> that no single semantic view can express.
        </p>
        <ol className="text-sm text-[var(--text-muted)] mt-3 space-y-2 list-decimal list-inside">
          <li><strong>Business rules</strong> — which records to include/exclude per policy (Q1: exclude probationary)</li>
          <li><strong>Metric disambiguation</strong> — which competing number is canonical (Q2: operational vs self-reported OTD)</li>
          <li><strong>Composite parameters</strong> — formula weights reflecting business priorities (Q3: risk score weighting)</li>
          <li><strong>Domain-specific conventions</strong> — finance sign logic, GL account codes (Q4: credit memo subtraction)</li>
          <li><strong>Cross-domain chains</strong> — paths connecting Sales, Purchasing, and Finance where no FK exists (Q5: gross margin via BOM rollup)</li>
          <li><strong>Constrained optimization</strong> — multi-step decisions requiring dependency awareness (Q9: cut costs without breaking revenue)</li>
          <li><strong>Correct cost basis</strong> — BOM rollup vs assembly standard price cascades into every profitability and pricing decision (Q10, Q11)</li>
        </ol>
      </div>
    </div>
  );
}
