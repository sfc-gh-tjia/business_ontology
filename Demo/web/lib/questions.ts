import { EvalQuestion } from "./types";

export const EVAL_QUESTIONS: EvalQuestion[] = [
  {
    id: "Q1",
    tier: "A",
    q: "How many suppliers do we have?",
    expected: "14 (excludes 1 probationary ZPRB vendor). NOT 15.",
  },
  {
    id: "Q2",
    tier: "A",
    q: "What is our on-time delivery rate?",
    expected: "66.7% (operational: actual delivery dates). NOT 90% (carrier self-reported OTRAT).",
  },
  {
    id: "Q3",
    tier: "A",
    q: "What is the weighted supply risk score for each raw material?",
    expected: "Weights: 0.4 single-source + 0.3 defect + 0.3 delivery. Top: MAT-006 at 0.70. NOT 40/35/25.",
  },
  {
    id: "Q4",
    tier: "B",
    q: "What is our Cost of Goods Sold for raw materials?",
    expected: "$1,290,020 (invoices minus credit memos). NOT $1,353,690 (ignoring credit memo sign).",
  },
  {
    id: "Q5",
    tier: "B",
    q: "What is the gross margin on the Integrated System Module (ASSY-004)?",
    expected: "$296,855 (revenue $390K minus BOM material cost $93,145). NOT $221K (using assembly standard price instead of BOM rollup).",
  },
  {
    id: "Q6",
    tier: "A",
    q: "How much revenue are we losing to customer discounts?",
    expected: "$34,085 (KSCHL K007 only). Exclude freight surcharges (KF00).",
  },
  {
    id: "Q7",
    tier: "B",
    q: "If supplier V10045 has a force majeure, how much sales revenue is at risk?",
    expected: "$746,000 — all 4 assemblies affected via recursive BOM cascade from MAT-001/MAT-013.",
  },
  {
    id: "Q8",
    tier: "A",
    q: "What is the total cost allocated to the US manufacturing operation?",
    expected: "$419,750 (COEP WHERE OBJNR='KS-MFG-US').",
  },
  {
    id: "Q9",
    tier: "C",
    q: "If we need to cut procurement costs by 15%, where should we cut without disrupting production of our highest-revenue product?",
    expected: "Cut MAT-011 ($177.5K), MAT-009 ($22.5K), MAT-014 ($11K) = $211K (15.6%). Do NOT cut ASSY-004 BOM inputs (MAT-004, MAT-003, MAT-005, MAT-015, MAT-007).",
  },
  {
    id: "Q10",
    tier: "C",
    q: "Which customer is most important to our business? Consider not just revenue, but actual profit contribution after material costs.",
    expected: "C-1001 with ~$238K profit (BOM cost rollup). NOT $177K (using assembly STPRS). C-1004 has highest margin at 80.2%.",
  },
  {
    id: "Q11",
    tier: "C",
    q: "What is the maximum discount we can offer on the Integrated System Module (ASSY-004) before we lose money?",
    expected: "75.4% discount ($286.60 BOM cost / $1,200 list price). NOT 57.1% (using $520 assembly STPRS as cost).",
  },
];

export const TIER_LABELS: Record<string, string> = {
  A: "Business Knowledge (rules, competing metrics, composites)",
  B: "Cross-Domain Reasoning (Finance + Sales + Purchasing chains)",
  C: "Strategic Decision Support (constrained optimization, profitability)",
};
