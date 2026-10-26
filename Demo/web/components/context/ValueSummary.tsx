"use client";

// Top-of-page story for the Context tab: what well-built SVs already do, and the gaps only BON closes.
// "Without BON" values are what the named SV metric returns; "With BON" values are the governed answers
// (both verified against SAP_BON_V2.BENCHMARK_GROUND_TRUTH).

const GAPS = [
  {
    gap: "1. Two teams, two correct metrics, one business word (and company jargon)",
    why: "Each team's semantic view is right for that team. Nothing in a semantic view says which one is the company's official answer.",
    examples: [
      { q: "How many suppliers do we have?", without: "15 (Purchasing SV: vendor_record_count) or 14 (Finance SV)", with: "14: Supplier Count, probationary vendors excluded by policy" },
      { q: "What is our revenue?", without: "$746,000: gross_bookings, which carries the synonym \"revenue\"", with: "$711,915: Revenue = net of customer discounts (net_revenue)" },
      { q: "What is our on-time delivery rate?", without: "90%: carrier self-reported rate", with: "66.7%: On-Time Delivery Rate, measured from actual delivery dates" },
      { q: "How much have we spent with our Tier A suppliers?", without: "No semantic view knows \"Tier A\": the agent has to ask or guess which vendor group is meant", with: "$251,690: Tier A = strategic partners (account group ZSTR)" },
    ],
  },
  {
    gap: "2. Questions that cross team boundaries",
    why: "No single semantic view holds both revenue and cost to build. The agent must know which metric from each view to combine, and how.",
    examples: [
      { q: "Gross margin on ASSY-004?", without: "$296,855 (gross bookings) or $221,000 (standard price as cost)", with: "$277,355: Revenue − BOM Cost Rollup × units" },
      { q: "Which customer contributes the most profit after material costs?", without: "C-1001 at $237,948 (gross bookings) or $177,600 (standard price as cost)", with: "C-1001 at $223,498: Revenue − BOM Cost Rollup × units" },
    ],
  },
  {
    gap: "3. Policies and meaning, not just numbers",
    why: "A semantic view can encode a filter, but not the governed reason for it, who owns it, or where else it applies.",
    examples: [
      { q: "Cut spend 15% without disrupting anything we sell?", without: "Nothing marks production inputs (BOM materials) as off-limits", with: "Only non-BOM materials, per BOM Input Protection policy" },
      { q: "Should we report gross bookings or net revenue?", without: "Both metrics are documented, but neither is marked official", with: "Net revenue ($711,915); gross bookings is a Sales pipeline measure" },
    ],
  },
];

const SV_ALREADY = [
  "COGS with credit memos subtracted",
  "Discounts that exclude freight surcharges",
  "Spend by material group code",
  "Cost allocated to a cost center",
];

export default function ValueSummary() {
  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6">
      <h2 className="text-xl font-semibold mb-1">What semantic views can&apos;t answer on their own</h2>
      <p className="text-sm text-[var(--text-muted)] mb-5">
        Every agent in this demo gets the same three well-built semantic views, one per team.
        The only difference is whether it can consult the Business Ontology.
      </p>

      <div className="rounded-lg border border-emerald-200 dark:border-emerald-800 bg-emerald-50 dark:bg-emerald-950 px-4 py-3 mb-5 text-sm">
        <strong>Semantic views already handle single-team rules well</strong>, so BON is not needed for these (Tier 1, the control):{" "}
        {SV_ALREADY.join(" · ")}.
      </div>

      <div className="space-y-5">
        {GAPS.map((g) => (
          <div key={g.gap}>
            <h3 className="font-semibold">{g.gap}</h3>
            <p className="text-sm text-[var(--text-muted)] mb-2">{g.why}</p>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-xs text-[var(--text-muted)]">
                    <th className="py-1.5 pr-4 w-1/3">Question</th>
                    <th className="py-1.5 pr-4 w-1/3">Risk with semantic views alone</th>
                    <th className="py-1.5 w-1/3">With Business Ontology</th>
                  </tr>
                </thead>
                <tbody>
                  {g.examples.map((e) => (
                    <tr key={e.q} className="border-t border-[var(--border)] align-top">
                      <td className="py-2 pr-4">{e.q}</td>
                      <td className="py-2 pr-4 text-red-700 dark:text-red-400">{e.without}</td>
                      <td className="py-2 text-[var(--bon)] font-medium">{e.with}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-5 grid grid-cols-1 md:grid-cols-3 gap-3 text-sm">
        <div className="rounded-lg border border-[var(--border)] bg-[var(--bg)] px-3 py-2">
          <strong>Change once.</strong> A steward edits a definition; every BON-enabled agent follows, with no edits to SVs or prompts.
        </div>
        <div className="rounded-lg border border-[var(--border)] bg-[var(--bg)] px-3 py-2">
          <strong>Same answer across teams.</strong> Finance&apos;s and Sales&apos; agents answer the same question the same way.
        </div>
        <div className="rounded-lg border border-[var(--border)] bg-[var(--bg)] px-3 py-2">
          <strong>Only approved meaning is served.</strong> Draft definitions stay invisible to agents until reviewed.
        </div>
      </div>
      <p className="text-xs text-[var(--text-muted)] mt-3">
        The middle column shows the defensible-but-wrong answer each semantic view metric gives if the agent picks it; a well-built baseline agent often avoids or hedges these, so measured rates are what count.
        Measured rates are on the Analysis tab. Try any question live on the Comparison tab.
      </p>
    </div>
  );
}
