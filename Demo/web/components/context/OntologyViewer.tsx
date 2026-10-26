"use client";
import { useEffect, useRef } from "react";

// Typed relationships from SAP_BON_V2 (05_bon.sql). Edge labels are BON relationship types.
const BON_GRAPH = `graph LR
    subgraph proc [Procurement]
        Supplier
        Material
        Assembly
        BOM[Bill of Materials]
        PO[Purchase Order]
        SC[Supplier Count]:::metric
        VRC[Vendor Record Count]:::metric
        TIA[Tier A Supplier]
        BCR[BOM Cost Rollup]:::metric
        PVE[Probationary Vendor Exclusion]:::policy
        BIP[BOM Input Protection]:::policy
        PS[Procurement Spend]:::metric
    end
    subgraph fin [Finance and Controlling]
        AP[AP Line Item]
        PGM[Product Gross Margin]:::metric
        CP[Customer Profit]:::metric
        BED[Break-even Discount]:::metric
        CMR[Credit Memo Sign Rule]:::policy
        COGS[COGS Raw Materials]:::metric
    end
    subgraph sales [Sales and Distribution]
        SO[Sales Order]
        Customer
        REV[Revenue]:::metric
        GB[Gross Bookings]:::metric
        CD[Customer Discounts]:::metric
        RAR[Revenue at Risk]:::metric
    end
    Assembly -->|HAS_PART| BOM
    BOM -->|HAS_PART| Material
    PO -->|DERIVES| AP
    SO -->|RELATED_TO| Assembly
    SC -->|HAS_VARIANT| VRC
    SC -->|MEASURES| Supplier
    TIA -->|IS_A| Supplier
    PVE -->|APPLIES_TO| SC
    REV -->|HAS_VARIANT| GB
    CD -->|DERIVES| REV
    BOM -->|DERIVES| BCR
    REV -->|DERIVES| PGM
    BCR -->|DERIVES| PGM
    REV -->|DERIVES| CP
    BCR -->|DERIVES| CP
    CP -->|MEASURES| Customer
    BCR -->|DERIVES| BED
    REV -->|DERIVES| RAR
    BOM -->|DERIVES| RAR
    RAR -->|MEASURES| Supplier
    CMR -->|APPLIES_TO| COGS
    BIP -->|APPLIES_TO| PS
    classDef metric fill:#e0f2fe,stroke:#0284c7
    classDef policy fill:#fef3c7,stroke:#d97706
`;

const CANONICAL = [
  { term: "Supplier Count", impl: "FINANCE_ENRICHED_SV · vendors.active_supplier_count", variant: "Vendor Record Count (scope: Procurement operations)", value: "14" },
  { term: "Revenue", impl: "SALES_ENRICHED_SV · net_revenue (derived)", variant: "Gross Bookings (scope: Sales pipeline)", value: "711,915" },
  { term: "On-Time Delivery Rate", impl: "PURCHASING_ENRICHED_SV · shipments.operational_otd_rate", variant: "Carrier Reported On-Time Rate (scope: Carrier scorecard)", value: "66.7%" },
  { term: "BOM Cost Rollup", impl: "PURCHASING_ENRICHED_SV · bom.bom_material_cost", variant: "not the assembly standard price STPRS", value: "286.60 (ASSY-004)" },
];

const CROSS = [
  { term: "Product Gross Margin", formula: "Revenue − BOM Cost Rollup × units", from: "Sales + Procurement" },
  { term: "Customer Profit", formula: "Σ (Revenue − BOM Cost Rollup × units) per customer", from: "Sales + Procurement" },
  { term: "Break-even Discount", formula: "1 − BOM Cost Rollup / list price", from: "Sales + Procurement" },
  { term: "Revenue at Risk", formula: "Revenue of assemblies whose BOM contains the supplier's materials", from: "Procurement → Sales" },
];

const POLICIES = [
  { term: "Probationary Vendor Exclusion", text: "ZPRB vendors are not active suppliers." },
  { term: "Credit Memo Sign Rule", text: "BSCHL 34 credit memos are subtracted from every cost total." },
  { term: "BOM Input Protection", text: "Never cut a material that is in the BOM of anything we sell." },
];

const CODE_TERMS = [
  { code: "KTOKK", term: "Vendor Account Group", ref: "T077K", col: "LFA1.KTOKK" },  // also defines company term "Tier A Supplier" = ZSTR
  { code: "MATKL", term: "Material Group", ref: "T023T", col: "MARA.MATKL" },
  { code: "BSCHL", term: "Posting Key", ref: "", col: "BSEG.BSCHL" },
  { code: "HKONT", term: "GL Account", ref: "", col: "BSEG.HKONT" },
  { code: "OBJNR", term: "Cost Object", ref: "", col: "COEP.OBJNR" },
  { code: "KSCHL", term: "Condition Type", ref: "", col: "KONV.KSCHL" },
  { code: "VKORG", term: "Sales Organization", ref: "", col: "VBAP.VKORG" },
];

const card = "px-3 py-2 rounded bg-[var(--bg)] border border-[var(--border)] text-xs";
const heading = "text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2";

export default function OntologyViewer() {
  const graphRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let cancelled = false;
    import("mermaid").then((m) => {
      m.default.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "strict" });
      // Unique id per render: React dev mode runs effects twice, and two renders sharing an id leave an empty SVG.
      const id = `bon-graph-${Math.random().toString(36).slice(2)}`;
      m.default.render(id, BON_GRAPH).then(({ svg }) => {
        if (!cancelled && graphRef.current) graphRef.current.innerHTML = svg;
      }).catch((e: unknown) => {
        console.error("BON graph render failed", e);
        if (!cancelled && graphRef.current) graphRef.current.textContent = `Graph failed to render: ${String(e)}`;
      });
    });
    return () => { cancelled = true; };
  }, []);

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6 mt-6">
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
        <h3 className="text-lg font-semibold">Business Ontology: what the numbers mean</h3>
        <div className="flex flex-wrap gap-4 text-sm text-[var(--text-muted)]">
          <span><strong className="text-[var(--text)]">40</strong> approved nodes</span>
          <span><strong className="text-[var(--text)]">51</strong> typed relationships</span>
          <span><strong className="text-[var(--text)]">43</strong> representations</span>
          <span className="text-[var(--bon)]">Procurement · Finance &amp; Controlling · Sales &amp; Distribution</span>
        </div>
      </div>

      <div className="bg-sky-50 dark:bg-sky-950 border border-sky-200 dark:border-sky-800 rounded-lg px-4 py-3 mb-5 text-sm">
        <strong>Ontology governs, semantic views execute.</strong> The BON agent has the <em>same</em> three enriched semantic views as
        the baseline, plus native <code className="text-xs">snowscope_search</code> over the <code className="text-xs">businessOntology</code> corpus.
        It looks up which metric is canonical, which policy applies, and how concepts connect across teams, then lets each
        semantic view compute its part.
      </div>

      <h4 className={heading}>One definition, many implementations: canonical metric → implementing SV metric</h4>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-2 mb-5">
        {CANONICAL.map((c) => (
          <div key={c.term} className={card}>
            <div className="flex justify-between"><span className="font-semibold text-[var(--bon)] text-sm">{c.term}</span><span className="font-mono">{c.value}</span></div>
            <div className="mt-1"><span className="text-[var(--text-muted)]">IMPLEMENTS:</span> <span className="font-mono">{c.impl}</span></div>
            <div><span className="text-[var(--text-muted)]">HAS_VARIANT:</span> {c.variant}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-5">
        <div>
          <h4 className={heading}>Cross-domain metrics ({CROSS.length})</h4>
          <div className="space-y-1">
            {CROSS.map((c) => (
              <div key={c.term} className={card}>
                <span className="font-semibold">{c.term}</span>
                <p className="font-mono text-[var(--text-muted)] mt-0.5">{c.formula}</p>
                <p className="text-[var(--text-muted)]">{c.from}</p>
              </div>
            ))}
          </div>
        </div>
        <div>
          <h4 className={heading}>Policies ({POLICIES.length})</h4>
          <div className="space-y-1">
            {POLICIES.map((p) => (
              <div key={p.term} className={card}><span className="font-semibold">{p.term}</span><p className="text-[var(--text-muted)] mt-0.5">{p.text}</p></div>
            ))}
          </div>
        </div>
        <div>
          <h4 className={heading}>Code-mapping terms ({CODE_TERMS.length}): one per code field</h4>
          <div className="space-y-1">
            {CODE_TERMS.map((d) => (
              <div key={d.code} className={card}>
                <span className="font-mono font-semibold">{d.code}</span> <span>{d.term}</span>
                <span className="text-[var(--text-muted)] ml-1">→ {d.col}{d.ref ? ` · codes in ${d.ref}` : ""}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <h4 className={heading}>Ontology graph (edges are BON relationship types · blue = metric · amber = policy)</h4>
      <div ref={graphRef} className="overflow-x-auto" />
    </div>
  );
}
