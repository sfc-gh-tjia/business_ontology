"use client";

const TABLE_GROUPS = [
  {
    label: "Master Data",
    desc: "SAP vendor and material master tables with coded field names",
    tables: [
      { name: "LFA1", rows: 15, desc: "Vendor master — LIFNR, KTOKK (ZSTR/ZSTD/ZPRB), KRAUS (DUNS)" },
      { name: "MARA", rows: 24, desc: "Material master — MATNR, MATKL (043=Electronics...), STPRS" },
      { name: "LFA2", rows: 6, desc: "Forwarding agents (carriers) — VSART, LZEIT, OTRAT" },
    ],
  },
  {
    label: "Transactions",
    tables: [
      { name: "EKPO", rows: 25, desc: "PO items — NETWR (net value), BEDAT, STATU (O/C/R)" },
      { name: "LIKP", rows: 20, desc: "Shipments — LFDAT vs WADAT (expected vs actual), FRTCO" },
      { name: "LFB1", rows: 15, desc: "Vendor contracts — VTART (M/F/S), JWERT (annual value)" },
      { name: "QALS", rows: 10, desc: "Inspection lots — QAESSION (defect rate), VCODE (A/R/C)" },
    ],
  },
  {
    label: "Structure",
    tables: [
      { name: "STPO", rows: 15, desc: "BOM items — STLNR/IDNRK (parent/child), 4-level hierarchy" },
      { name: "T001W", rows: 5, desc: "Plants — manufacturing/distribution sites" },
      { name: "T320", rows: 8, desc: "Storage locations (warehouses) — LKAPA utilization" },
      { name: "QUAL_MATRIX", rows: 28, desc: "Vendor-material qualifications — CERT_TYPE, STATUS, EXPIRY_DATE" },
    ],
  },
  {
    label: "Finance (FI/CO)",
    tables: [
      { name: "BSEG", rows: 38, desc: "AP line items — HKONT (GL acct), BSCHL (31=invoice, 34=credit memo)" },
      { name: "COEP", rows: 19, desc: "Cost postings — OBJNR (cost object), KSTAR (cost element)" },
    ],
  },
  {
    label: "Sales (SD)",
    tables: [
      { name: "VBAP", rows: 13, desc: "Sales order items — finished assemblies sold to customers" },
      { name: "KONV", rows: 25, desc: "Pricing conditions — KSCHL (PR00/K007/KF00)" },
    ],
  },
];

export default function SourceTables() {
  const totalRows = TABLE_GROUPS.flatMap((g) => g.tables).reduce((s, t) => s + t.rows, 0);
  const totalTables = TABLE_GROUPS.flatMap((g) => g.tables).length;

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--bg-card)] p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">SAP Production Data</h3>
        <div className="flex gap-4 text-sm text-[var(--text-muted)]">
          <span><strong className="text-[var(--text)]">{totalTables}</strong> tables</span>
          <span><strong className="text-[var(--text)]">{totalRows}</strong> rows</span>
          <span><strong className="text-[var(--text)]">3</strong> domains (Purchasing, Finance, Sales)</span>
        </div>
      </div>

      <div className="bg-amber-50 dark:bg-amber-950 border border-amber-200 dark:border-amber-800 rounded-lg px-4 py-3 mb-5 text-sm">
        <strong>Key challenge:</strong> Three SAP domains (MM, FI/CO, SD) with coded field names.
        Cross-domain connections are implicit — no FK links Sales Orders to Purchase Orders (the chain goes through BOM).
        Finance posting keys encode sign logic (BSCHL=31 positive, 34 negative).
        Multiple plausible metrics exist (OTD: OTRAT vs WADAT/LFDAT; Spend: EKPO.NETWR vs LFB1.JWERT).
        Without business ontology, the agent cannot decode these or traverse cross-domain chains.
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        {TABLE_GROUPS.map((group) => (
          <div key={group.label}>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)] mb-2">
              {group.label}
            </h4>
            <div className="space-y-1">
              {group.tables.map((t) => (
                <div
                  key={t.name}
                  className="flex items-center justify-between px-3 py-2 rounded-lg bg-[var(--bg)] border border-[var(--border)] text-sm"
                >
                  <div>
                    <code className="font-mono text-xs">{t.name}</code>
                    <p className="text-xs text-[var(--text-muted)] mt-0.5">{t.desc}</p>
                  </div>
                  <span className="text-xs font-semibold ml-3 shrink-0">{t.rows}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
