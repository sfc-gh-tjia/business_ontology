import { EvalQuestion } from "./types";

// V2 benchmark questions (mirror SAP_BON_V2.BENCHMARK_QUESTIONS / BENCHMARK_GROUND_TRUTH).
export const EVAL_QUESTIONS: EvalQuestion[] = [
  { id: "Q01", tier: "1", q: "What is our cost of goods sold for raw materials?",
    expected: "$1,290,020: invoices minus credit memos on GL 0040100000.",
    trap: "$1,417,360 if credit memos are added instead of subtracted.", governed: "COGS Raw Materials" },
  { id: "Q02", tier: "1", q: "What is the total cost allocated to US manufacturing?",
    expected: "$419,750: cost object KS-MFG-US.", trap: "Other cost objects included.", governed: "Cost Center Total" },
  { id: "Q03", tier: "1", q: "How much revenue are we losing to customer discounts?",
    expected: "$34,085: condition type K007 only.", trap: "$36,687.50 if freight surcharges (KF00) are counted.",
    governed: "Customer Discounts" },
  { id: "Q04", tier: "1", q: "How much have we spent on electronics materials?",
    expected: "$505,400: material group 043.", trap: "Wrong material group code.", governed: "Procurement Spend" },
  { id: "Q05", tier: "1", q: "What is our net freight cost of goods sold?",
    expected: "$39,800: GL 0040200000, credit memos subtracted.", trap: "Sign not applied to credit memos.", governed: "COGS Freight" },

  { id: "Q06", tier: "2", q: "How many suppliers do we have?",
    expected: "14 active suppliers (ZSTR + ZSTD). Probationary ZPRB excluded by policy.",
    trap: "15: Purchasing's vendor_record_count, which also answers to \"supplier count\".", governed: "Supplier Count" },
  { id: "Q07", tier: "2", q: "What is our revenue?",
    expected: "$711,915: net of K007 customer discounts (net_revenue).",
    trap: "$746,000: Sales' gross_bookings, which carries the synonym \"revenue\".", governed: "Revenue" },
  { id: "Q08", tier: "2", q: "What is our on-time delivery rate?",
    expected: "66.7%: delivered shipments with goods issue on or before the planned date.",
    trap: "90%: carrier self-reported OTRAT (carrier_otd_rate).", governed: "On-Time Delivery Rate" },
  { id: "Q09", tier: "2", q: "What does it cost us to make one Integrated System Module (ASSY-004)?",
    expected: "$286.60: BOM cost rollup over every purchased component.",
    trap: "$520: the assembly's standard price STPRS (planning price, not cost).", governed: "BOM Cost Rollup" },
  { id: "Q19", tier: "2", q: "How much have we spent with our Tier A suppliers?",
    expected: "$251,690: \"Tier A\" is company vocabulary for strategic partners (account group ZSTR).",
    trap: "$1,331,190 (all active suppliers) or $1,353,690 (all suppliers): no semantic view knows the term.",
    governed: "Tier A Supplier" },

  { id: "Q10", tier: "3", q: "What is the gross margin on the Integrated System Module (ASSY-004)?",
    expected: "$277,355: Revenue (net) minus BOM cost x units.",
    trap: "$296,855 (gross bookings) or $221,000 (standard price as cost).", governed: "Product Gross Margin" },
  { id: "Q11", tier: "3", q: "If supplier V10089 (Advanced Silicon Solutions) has a force majeure, how much revenue is at risk?",
    expected: "$597,450: net revenue of ASSY-003 (direct) and ASSY-004 (contains ASSY-003, BOM level 2).",
    trap: "$226,950 (direct BOM only, misses ASSY-004) or $623,750 (gross bookings).", governed: "Revenue at Risk" },
  { id: "Q12", tier: "3", q: "What is our total revenue divided by our number of suppliers?",
    expected: "$50,851: governed Revenue ($711,915, Sales) / governed Supplier Count (14, Finance).",
    trap: "$49,733 (746,000/15), $47,461 (711,915/15) or $53,286 (746,000/14): one or both definitions wrong.",
    governed: "Revenue + Supplier Count" },
  { id: "Q13", tier: "3", q: "We need to cut procurement spend by 15%. Which materials should we cut without disrupting production of anything we sell?",
    expected: "Only non-BOM materials, totalling at least $203,054 (15% of $1,353,690).",
    trap: "Cutting any BOM input (MAT-001/003/004/007/008/013/015/016/018).", governed: "BOM Input Protection" },
  { id: "Q14", tier: "3", q: "Which customer contributes the most profit after material costs?",
    expected: "C-1001 at about $223,498.", trap: "C-1001 at $237,948 (gross bookings) or $177,600 (standard price).",
    governed: "Customer Profit" },

  { id: "Q15", tier: "4", q: "What counts as an active supplier, and why are some vendors excluded?",
    expected: "Active = account group ZSTR or ZSTD; probationary ZPRB excluded by procurement policy.",
    trap: "A vague answer without the probationary rule.", governed: "Probationary Vendor Exclusion" },
  { id: "Q16", tier: "4", q: "Should we report gross bookings or net revenue as our revenue, and why?",
    expected: "Net revenue ($711,915, net of K007 discounts); gross bookings is a Sales pipeline and quota measure.",
    trap: "Recommends gross bookings, or says either is fine.", governed: "Revenue" },
  { id: "Q17", tier: "4", q: "Why are credit memos subtracted when calculating COGS?",
    expected: "Credit memos (BSCHL 34) reverse vendor invoices (BSCHL 31), so they reduce cost.",
    trap: "No reason given.", governed: "Credit Memo Sign Rule" },
  { id: "Q18", tier: "4", q: "What is the difference between gross bookings and revenue?",
    expected: "Gross bookings = order value before discounts (Sales pipeline); revenue = net of K007 discounts (canonical).",
    trap: "Treats them as the same.", governed: "Revenue" },
  { id: "Q20", tier: "4", q: "What is our Supplier Resilience Score?",
    expected: "No governed definition exists, so the agent should say so (it may point to related governed metrics).",
    trap: "Invents a formula, or passes off another project's risk or quality score as this one.",
    governed: "(none: guardrail)" },
];

// Questions shown in the demo. Tier 1: three controls (both agents correct).
// Tiers 2-4: only questions where BON was right and the SV-only agent was not, in run 20261023_072322_9764.
export const DEMO_QIDS = ["Q01", "Q03", "Q04", "Q06", "Q07", "Q19", "Q12", "Q17", "Q18"];
export const DEMO_QUESTIONS: EvalQuestion[] = DEMO_QIDS.map((id) => EVAL_QUESTIONS.find((q) => q.id === id)!);

export const TIER_LABELS: Record<string, string> = {
  "1": "Tier 1: Business rules in one SV (control: enriched SVs already handle these)",
  "2": "Tier 2: Conflicting definitions & company vocabulary (which metric is official? what does our jargon mean?)",
  "3": "Tier 3: Cross-domain reasoning (Sales + Finance + Procurement)",
  "4": "Tier 4: Governed meaning (definitions, policies, and knowing what is not defined)",
};

export const TIER_PILLARS: Record<string, string> = {
  "1": "Baseline fairness",
  "2": "Canonical choice",
  "3": "Cross-domain meaning",
  "4": "Governed meaning",
};
