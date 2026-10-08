"use client";
import { useEffect, useRef, useState } from "react";

const BON_GRAPH = `graph LR
    subgraph purchasing [PURCHASING]
        Supplier -->|supplies| Material
        Material -->|component_of| Assembly
        PurchaseOrder -->|placed_with| Supplier
        Carrier -->|fulfills| Shipment
        Inspection -->|inspects| Material
    end
    subgraph finance [FINANCE]
        APPosting[AP_Posting]
        CostCenter[Cost_Center]
    end
    subgraph sales [SALES]
        SalesOrder[Sales_Order]
        PricingCond[Pricing_Conditions]
    end
    PurchaseOrder -->|initiates| APPosting
    APPosting -->|contributes_to| CostCenter
    Assembly -->|sold_as| SalesOrder
    PricingCond -->|governs_pricing| SalesOrder
    SalesOrder -. gross margin .-> APPosting
`;

const FORMULAS = [
  { name: "1. Canonical Supplier Count", formula: "COUNT(LIFNR) WHERE KTOKK IN ('ZSTR','ZSTD')", desc: "Excludes ZPRB probationary. 14 not 15.", domain: "Purchasing" },
  { name: "2. Operational OTD", formula: "WADAT <= LFDAT WHERE STATU='D'", desc: "NOT carrier OTRAT (90%). Real: 66.7%.", domain: "Purchasing" },
  { name: "3. Total Procurement Spend", formula: "SUM(EKPO.NETWR)", desc: "Use EKPO only. NOT LFB1.JWERT (contract values).", domain: "Purchasing" },
  { name: "4. Weighted Supply Risk Score", formula: "0.4*single_src + 0.3*defect + 0.3*delivery", desc: "Fixed policy weights. LLM guesses wrong.", domain: "Purchasing" },
  { name: "5. Supplier Disruption Cascade", formula: "Supplier->EKPO->STPO(recursive up)->Assemblies", desc: "Recursive BOM upward from affected materials.", domain: "Cross-Domain" },
  { name: "6. BOM Cost Rollup", formula: "Recursive STPO downward, multiply qty, JOIN MARA.STPRS", desc: "Leaf material costs, not assembly STPRS.", domain: "Purchasing" },
  { name: "7. COGS Raw Materials", formula: "BSEG: BSCHL=31 add, 34=subtract, HKONT=0040100000", desc: "Credit memo sign logic. $1.29M not $1.35M.", domain: "Finance" },
  { name: "8. Product Gross Margin", formula: "VBAP revenue - (Formula 6 cost * units sold)", desc: "Cross-domain: Sales->BOM->Prices. No FK.", domain: "Cross-Domain" },
  { name: "9. Discount Leakage", formula: "KONV WHERE KSCHL='K007' (not KF00)", desc: "K007=discount, KF00=surcharge.", domain: "Sales" },
  { name: "10. Disruption Revenue Impact", formula: "Formula 5 assemblies -> VBAP.NETWR", desc: "5-hop cross-domain cascade to sales revenue.", domain: "Cross-Domain" },
  { name: "11. Cost Center Total", formula: "COEP WHERE OBJNR=cost_object_code", desc: "KS-MFG-US=US Mfg, KS-LOG=Logistics.", domain: "Finance" },
];

const SAP_DECODERS = [
  { code: "KTOKK", values: "ZSTR=Strategic, ZSTD=Standard, ZPRB=Probationary", domain: "Purchasing" },
  { code: "MATKL", values: "043=Electronics, 044=Chemicals, 045=Metals...", domain: "Purchasing" },
  { code: "BSCHL", values: "31=Invoice (positive), 34=Credit Memo (SUBTRACT)", domain: "Finance" },
  { code: "HKONT", values: "0040100000=COGS Raw Mat, 0040200000=COGS Freight", domain: "Finance" },
  { code: "KSCHL", values: "PR00=Base Price, K007=Discount, KF00=Surcharge", domain: "Sales" },
  { code: "OBJNR", values: "KS-MFG-US/EU/AP=Manufacturing, KS-LOG, KS-QA", domain: "Finance" },
  { code: "VKORG", values: "1000=Americas, 2000=EMEA, 3000=APAC", domain: "Sales" },
];

const RELATIONSHIPS = [
  { source: "Supplier (LFA1)", rel: "supplies", target: "Material (MARA)", via: "EKPO.LIFNR/MATNR", domain: "Purchasing" },
  { source: "Material", rel: "component_of", target: "Assembly", via: "STPO (recursive)", domain: "Purchasing" },
  { source: "Carrier (LFA2)", rel: "fulfills", target: "Shipment (LIKP)", via: "CARRIER_ID", domain: "Purchasing" },
  { source: "Inspection (QALS)", rel: "inspects", target: "Material (MARA)", via: "MATNR", domain: "Purchasing" },
  { source: "PO (EKPO)", rel: "initiates", target: "AP Posting (BSEG)", via: "EBELN", domain: "Cross-Domain" },
  { source: "AP Invoice (BSCHL=31)", rel: "contributes_to", target: "COGS (HKONT=0040100000)", via: "HKONT", domain: "Finance" },
  { source: "Credit Memo (BSCHL=34)", rel: "reduces", target: "COGS", via: "must subtract", domain: "Finance" },
  { source: "PO Spend", rel: "allocated_to", target: "Cost Center (COEP)", via: "material/plant", domain: "Cross-Domain" },
  { source: "Assembly (MARA)", rel: "sold_as", target: "Sales Order (VBAP)", via: "MATNR (no direct FK to EKPO)", domain: "Cross-Domain" },
  { source: "Discount (KONV K007)", rel: "reduces", target: "Revenue (VBAP)", via: "KSCHL=K007", domain: "Sales" },
  { source: "Sales Revenue", rel: "minus COGS equals", target: "Gross Margin", via: "Formula 8", domain: "Cross-Domain" },
];

export default function OntologyViewer() {
  const graphRef = useRef<HTMLDivElement>(null);
  const [showFormulas, setShowFormulas] = useState(true);

  useEffect(() => {
    import("mermaid").then((m) => {
      m.default.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "strict" });
      if (graphRef.current) {
        graphRef.current.innerHTML = "";
        m.default.render("bon-graph", BON_GRAPH).then(({ svg }) => {
          if (graphRef.current) graphRef.current.innerHTML = svg;
        });
      }
    });
  }, []);

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6 mt-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">Business Ontology (BON)</h3>
        <div className="flex gap-4 text-sm text-[var(--text-muted)]">
          <span><strong className="text-[var(--text)]">11</strong> formulas</span>
          <span><strong className="text-[var(--text)]">7</strong> code decoders</span>
          <span><strong className="text-[var(--text)]">11</strong> relationships</span>
          <span className="text-[var(--bon)]">3 domains (Purchasing, Finance, Sales)</span>
        </div>
      </div>

      <div className="bg-sky-50 dark:bg-sky-950 border border-sky-200 dark:border-sky-800 rounded-lg px-4 py-3 mb-5 text-sm">
        The BON agent uses Snowflake&apos;s native <code className="text-xs">snowscope_search</code> with the
        <code className="text-xs">businessOntology</code> corpus to find relevant SAP field decoders, authoritative metric formulas,
        and <strong>cross-domain relationship maps</strong> connecting Purchasing, Finance, and Sales.
        The baseline agent has none of this context.
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-5">
        {/* Relationships */}
        <div>
          <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2">
            Entity Relationships (11)
          </h4>
          <div className="space-y-1">
            {RELATIONSHIPS.map((r, i) => (
              <div key={i} className="px-3 py-1.5 rounded bg-[var(--bg)] border border-[var(--border)] text-xs">
                <span className="font-mono">{r.source}</span>
                <span className="mx-1 text-[var(--bon)]">--[{r.rel}]--&gt;</span>
                <span className="font-mono">{r.target}</span>
                <span className="text-[var(--text-muted)] ml-1">via {r.via}</span>
              </div>
            ))}
          </div>
        </div>

        {/* SAP Code Decoders */}
        <div>
          <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2">
            SAP Code Decoders (7)
          </h4>
          <div className="space-y-1">
            {SAP_DECODERS.map((d) => (
              <div key={d.code} className="px-3 py-1.5 rounded bg-[var(--bg)] border border-[var(--border)] text-xs">
                <span className="font-mono font-semibold">{d.code}</span>
                <span className="ml-2 text-[var(--text-muted)]">{d.values}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Formulas */}
        <div>
          <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2">
            Authoritative Formulas (11)
            <button onClick={() => setShowFormulas(!showFormulas)} className="ml-2 text-[var(--bon)] font-normal normal-case">
              {showFormulas ? "collapse" : "expand"}
            </button>
          </h4>
          {showFormulas ? (
            <div className="space-y-1">
              {FORMULAS.map((f) => (
                <div key={f.name} className="px-3 py-2 rounded bg-[var(--bg)] border border-[var(--border)] text-sm">
                  <span className="font-semibold text-[var(--bon)]">{f.name}</span>
                  <p className="text-xs font-mono text-[var(--text-muted)] mt-0.5">{f.formula}</p>
                  <p className="text-xs text-[var(--text-muted)] mt-0.5">{f.desc}</p>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-[var(--text-muted)]">
              Canonical Supplier Count, Operational OTD, Procurement Spend, Risk Score, Disruption Cascade, Cost Rollup
            </p>
          )}
        </div>
      </div>

      <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2">
        Entity Relationship Graph
      </h4>
      <div ref={graphRef} className="overflow-x-auto" />
    </div>
  );
}
