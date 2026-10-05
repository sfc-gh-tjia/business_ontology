"use client";
import { useEffect, useRef } from "react";

const SV_DIAGRAM = `erDiagram
    LFA1 ||--o{ EKPO : "EKPO_to_LFA1"
    MARA ||--o{ EKPO : "EKPO_to_MARA"
    T001W ||--o{ EKPO : "EKPO_to_T001W"
    LFA2 ||--o{ LIKP : "LIKP_to_LFA2"
    T320 ||--o{ LIKP : "LIKP_to_T320"
    T001W ||--o{ LIKP : "LIKP_to_T001W"
    T001W ||--o{ T320 : "T320_to_T001W"
    LFA1 ||--o{ LFB1 : "LFB1_to_LFA1"
    MARA ||--o{ QALS : "QALS_to_MARA"
    EKPO ||--o{ BSEG : "BSEG_to_EKPO"
    LFA1 ||--o{ BSEG : "BSEG_to_LFA1"
    MARA ||--o{ VBAP : "VBAP_to_MARA"
`;

export default function SemanticViewDiagram() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    import("mermaid").then((m) => {
      m.default.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "strict" });
      if (ref.current) {
        ref.current.innerHTML = "";
        m.default.render("sv-diagram", SV_DIAGRAM).then(({ svg }) => {
          if (ref.current) ref.current.innerHTML = svg;
        });
      }
    });
  }, []);

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6 mt-6">
      <h3 className="text-lg font-semibold mb-2">Semantic View (Baseline)</h3>
      <p className="text-sm text-[var(--text-muted)] mb-4">
        The baseline agent uses <code className="text-xs bg-[var(--bg)] px-1 py-0.5 rounded">SAP_BASELINE_SV</code> with
        14 of 15 tables (QUAL_MATRIX excluded) and 12 FK relationships across 3 SAP domains. Column descriptions only &mdash; no business rules, no formulas.
      </p>
      <div ref={ref} className="overflow-x-auto" />
      <div className="mt-4 grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm">
        <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-lg px-3 py-2">
          <strong>Cannot</strong> decode SAP field codes (KTOKK, BSCHL, MATKL, KSCHL)
        </div>
        <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-lg px-3 py-2">
          <strong>Cannot</strong> distinguish competing metrics (OTD: OTRAT vs WADAT/LFDAT)
        </div>
        <div className="bg-red-50 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-lg px-3 py-2">
          <strong>No cross-domain FK</strong> &mdash; Sales (VBAP) connects to Purchasing (EKPO) only through BOM
        </div>
      </div>
    </div>
  );
}
