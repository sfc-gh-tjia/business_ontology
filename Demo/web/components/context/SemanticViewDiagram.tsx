"use client";

const SVS = [
  {
    name: "PURCHASING_ENRICHED_SV", team: "Procurement team",
    tables: "vendors, materials, purchase orders, shipments, carriers, inspections, bom (flattened)",
    metrics: ["vendor_record_count (\"supplier count\") = 15", "carrier_otd_rate (\"on-time delivery\") = 90%",
              "operational_otd_rate = 66.7%", "bom_material_cost (ASSY-004) = 286.60", "avg_standard_price (\"unit cost\")", "procurement_spend"],
  },
  {
    name: "FINANCE_ENRICHED_SV", team: "Finance team",
    tables: "ap_lines (BSEG), cost_postings (COEP), vendors, account groups",
    metrics: ["active_supplier_count (\"supplier count\") = 14", "cogs_raw_materials (signed)", "cogs_freight (signed)", "total_posted_cost"],
  },
  {
    name: "SALES_ENRICHED_SV", team: "Sales team",
    tables: "sales_items (VBAP), pricing (KONV), products, customers",
    metrics: ["gross_bookings (\"revenue\") = 746,000", "net_revenue = 711,915", "customer_discounts (K007)", "list_price (PR00)", "units_sold"],
  },
];

const CONFLICTS = [
  { q: "How many suppliers?", a: "Purchasing 15 vs Finance 14", governed: "Supplier Count = 14" },
  { q: "What is our revenue?", a: "gross_bookings 746,000 vs net_revenue 711,915", governed: "Revenue = 711,915" },
  { q: "On-time delivery rate?", a: "carrier_otd_rate 90% vs operational_otd_rate 66.7%", governed: "On-Time Delivery Rate = 66.7%" },
  { q: "Cost to make ASSY-004?", a: "avg_standard_price 520 vs bom_material_cost 286.60", governed: "BOM Cost Rollup = 286.60" },
];

export default function SemanticViewDiagram() {
  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6 mt-6">
      <h3 className="text-lg font-semibold mb-2">Semantic Views: one per team, built well</h3>
      <p className="text-sm text-[var(--text-muted)] mb-4">
        Each team owns an <strong>enriched</strong> semantic view with metrics, synonyms, code values, custom instructions and
        verified queries. Each is correct for its own team. The views can&apos;t join across teams, and their names overlap:
        several metrics answer to the same business word.
      </p>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-5">
        {SVS.map((sv) => (
          <div key={sv.name} className="rounded-lg border border-[var(--border)] bg-[var(--bg)] p-4 text-sm">
            <div className="font-mono font-semibold text-xs">{sv.name}</div>
            <div className="text-xs text-[var(--text-muted)] mb-2">{sv.team}</div>
            <div className="text-xs mb-2"><span className="text-[var(--text-muted)]">Tables:</span> {sv.tables}</div>
            <ul className="text-xs font-mono space-y-0.5">
              {sv.metrics.map((m) => <li key={m}>{m}</li>)}
            </ul>
          </div>
        ))}
      </div>
      <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2">
        Where the views disagree (each answer is defensible)
      </h4>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs text-[var(--text-muted)]">
              <th className="py-1.5 pr-4">Question</th><th className="py-1.5 pr-4">Semantic views say</th><th className="py-1.5">Business Ontology governs</th>
            </tr>
          </thead>
          <tbody>
            {CONFLICTS.map((c) => (
              <tr key={c.q} className="border-t border-[var(--border)]">
                <td className="py-1.5 pr-4">{c.q}</td>
                <td className="py-1.5 pr-4 font-mono text-xs">{c.a}</td>
                <td className="py-1.5 font-semibold text-[var(--bon)]">{c.governed}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-[var(--text-muted)] mt-3">
       
      </p>
    </div>
  );
}
