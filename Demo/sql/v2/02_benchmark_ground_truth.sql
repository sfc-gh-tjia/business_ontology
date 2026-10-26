-- =====================================================================
-- BON Demo V2 — 02: Benchmark questions + SQL-verified ground truth
-- Canonical Revenue = order value net of K007 customer discounts.
-- Gross margin, revenue at risk, and customer profit all build on it.
-- =====================================================================
USE SCHEMA DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2;

CREATE OR REPLACE TABLE BENCHMARK_QUESTIONS (
  QID VARCHAR, TIER NUMBER, TIER_NAME VARCHAR, VALUE_PILLAR VARCHAR, QUESTION VARCHAR
) AS SELECT * FROM VALUES
('Q01',1,'Business rules (single SV)','baseline-fairness','What is our cost of goods sold for raw materials?'),
('Q02',1,'Business rules (single SV)','baseline-fairness','What is the total cost allocated to US manufacturing?'),
('Q03',1,'Business rules (single SV)','baseline-fairness','How much revenue are we losing to customer discounts?'),
('Q04',1,'Business rules (single SV)','baseline-fairness','How much have we spent on electronics materials?'),
('Q05',1,'Business rules (single SV)','baseline-fairness','What is our net freight cost of goods sold?'),
('Q06',2,'Conflicting definitions & business vocabulary','V1-canonical-choice','How many suppliers do we have?'),
('Q07',2,'Conflicting definitions & business vocabulary','V1-canonical-choice','What is our revenue?'),
('Q08',2,'Conflicting definitions & business vocabulary','V1-canonical-choice','What is our on-time delivery rate?'),
('Q09',2,'Conflicting definitions & business vocabulary','V1-canonical-choice','What does it cost us to make one Integrated System Module (ASSY-004)?'),
('Q19',2,'Conflicting definitions & business vocabulary','V1-canonical-choice','How much have we spent with our Tier A suppliers?'),
('Q10',3,'Cross-SV reasoning','V2-cross-domain','What is the gross margin on the Integrated System Module (ASSY-004)?'),
('Q11',3,'Cross-SV reasoning','V2-cross-domain','If supplier V10089 (Advanced Silicon Solutions) has a force majeure, how much revenue is at risk?'),
('Q12',3,'Cross-SV reasoning','V2-cross-domain','What is our total revenue divided by our number of suppliers?'),
('Q13',3,'Cross-SV reasoning','V2-cross-domain','We need to cut procurement spend by 15%. Which materials should we cut without disrupting production of anything we sell?'),
('Q14',3,'Cross-SV reasoning','V2-cross-domain','Which customer contributes the most profit after material costs?'),
('Q15',4,'Governed meaning','V3-governed-meaning','What counts as an active supplier, and why are some vendors excluded?'),
('Q16',4,'Governed meaning','V3-governed-meaning','Should we report gross bookings or net revenue as our revenue, and why?'),
('Q17',4,'Governed meaning','V3-governed-meaning','Why are credit memos subtracted when calculating COGS?'),
('Q18',4,'Governed meaning','V3-governed-meaning','What is the difference between gross bookings and revenue?'),
('Q20',4,'Governed meaning','V3-governed-meaning','What is our Supplier Resilience Score?');

-- Expected values were computed with the verification queries below.
CREATE OR REPLACE TABLE BENCHMARK_GROUND_TRUTH (
  QID VARCHAR, EXPECTED_VALUE FLOAT, TOLERANCE_PCT FLOAT, CANONICAL_METRIC VARCHAR, PLAUSIBLE_WRONG VARCHAR, GRADING_RULE VARCHAR
) AS SELECT * FROM VALUES
('Q01',1290020,0.5,'COGS Raw Materials','1,417,360 (credit memos added instead of subtracted)','numeric'),
('Q02',419750,0.5,'Cost Center Total','other cost objects included','numeric'),
('Q03',34085,0.5,'Customer Discounts','36,687.50 (freight surcharges KF00 included)','numeric'),
('Q04',505400,0.5,'Procurement Spend','wrong material group code','numeric'),
('Q05',39800,0.5,'COGS Freight','sign not applied to credit memos','numeric'),
('Q06',14,0,'Supplier Count','15 (all vendor master records incl. probationary ZPRB)','numeric'),
('Q07',711915,0.5,'Revenue','746,000 (gross bookings before K007 discounts)','numeric'),
('Q08',66.7,1,'On-Time Delivery Rate','90% (carrier self-reported OTRAT)','numeric'),
('Q09',286.60,0.5,'BOM Cost Rollup','520 (standard price STPRS of the assembly)','numeric'),
('Q10',277355,0.5,'Product Gross Margin','296,855 (gross bookings) or 221,000 (standard price)','numeric'),
('Q11',597450,0.5,'Revenue at Risk','226,950 (ASSY-003 only: direct BOM, missed ASSY-004 at level 2) or 623,750 (gross bookings)','numeric'),
('Q12',50851,0.5,'Revenue / Supplier Count','49,733 (746,000/15) or 47,461 (711,915/15) or 53,286 (746,000/14)','numeric'),
('Q13',203054,0,'Procurement Spend','cuts any BOM input (MAT-001/003/004/007/008/013/015/016/018)','set: all cut materials non-BOM AND total >= 203,054 (15% of 1,353,690)'),
('Q14',223498,0.5,'Customer Profit','C-1001 at 237,948 (gross) or 177,600 (standard price)','numeric: customer C-1001 with ~223,498'),
('Q15',NULL,NULL,'Supplier Count','vague answer without the ZPRB probationary rule','definition: active = KTOKK ZSTR or ZSTD; ZPRB probationary excluded by policy'),
('Q16',NULL,NULL,'Revenue','recommends gross bookings, or says either is fine','definition: report net revenue (order value net of K007 customer discounts, 711,915); gross bookings (746,000) is a Sales pipeline/quota measure, not official revenue'),
('Q17',NULL,NULL,'Credit Memo Sign Rule','no reason given','definition: BSCHL 34 credit memos reverse vendor invoices (BSCHL 31), so they reduce cost'),
('Q18',NULL,NULL,'Revenue','treats them as the same','definition: gross bookings = order value before discounts (Sales view); revenue = net of K007 discounts (canonical)'),
('Q19',251690,0.5,'Tier A Supplier','1,331,190 (strategic + standard, i.e. all active suppliers) or 1,353,690 (all suppliers)','numeric'),
('Q20',NULL,NULL,'(none: not defined)','invents a formula, or presents a different metric (e.g. a risk or quality score) as the Supplier Resilience Score','abstain: states that no governed or official definition of Supplier Resilience Score exists; may suggest related governed metrics or ask for a definition, but must not present an invented or substituted number as the score');

-- ---------------------------------------------------------------------
-- Verification queries (re-run to confirm ground truth)
-- ---------------------------------------------------------------------
-- Q01  SELECT SUM(CASE WHEN BSCHL='31' THEN DMBTR WHEN BSCHL='34' THEN -DMBTR END) FROM BSEG WHERE HKONT='0040100000';  -- 1,290,020
-- Q05  same with HKONT='0040200000';                                                                                  -- 39,800
-- Q06  SELECT COUNT(DISTINCT LIFNR) FROM LFA1 WHERE KTOKK IN ('ZSTR','ZSTD');                                         -- 14
-- Q07  SUM(VBAP.NETWR) - SUM(ABS(KONV.KWERT)) WHERE KSCHL='K007';                                                    -- 746,000 - 34,085 = 711,915
-- Q08  SELECT 100*COUNT_IF(WADAT<=LFDAT)/COUNT(*) FROM LIKP WHERE STATU='D';                                          -- 66.7
-- Q09-Q14 use the recursive BOM rollup below.
WITH RECURSIVE x AS (
  SELECT STLNR AS root, IDNRK AS comp, MENGE::FLOAT AS qty FROM STPO
  UNION ALL SELECT x.root, s.IDNRK, x.qty * s.MENGE FROM x JOIN STPO s ON s.STLNR = x.comp
), leaf AS (
  SELECT root, SUM(x.qty * m.STPRS) bom_cost FROM x JOIN MARA m ON m.MATNR = x.comp
  WHERE x.comp NOT IN (SELECT STLNR FROM STPO) GROUP BY root
), disc AS (
  SELECT MATNR, KUNNR, SUM(ABS(KWERT)) d FROM KONV WHERE KSCHL='K007' GROUP BY 1,2
), v AS (
  SELECT MATNR, KUNNR, SUM(NETWR) gross, SUM(KWMENG) qty FROM VBAP GROUP BY 1,2
)
SELECT v.MATNR, v.KUNNR, v.gross, COALESCE(d.d,0) AS discount, v.gross-COALESCE(d.d,0) AS net_revenue,
       l.bom_cost, v.gross-COALESCE(d.d,0) - l.bom_cost*v.qty AS profit
FROM v JOIN leaf l ON l.root=v.MATNR LEFT JOIN disc d ON d.MATNR=v.MATNR AND d.KUNNR=v.KUNNR
ORDER BY 1,2;
-- ASSY-004 bom_cost 286.60 | margin 370,500 - 93,145 = 277,355 | break-even discount 1 - 286.60/1200 = 76.1%
-- Q11 V10089 supplies MAT-003, MAT-015 (Metals) -> ASSY-003 directly, ASSY-004 only at BOM level 2 (via ASSY-003):
--     net 226,950 + 370,500 = 597,450 | gross 623,750 | direct-BOM-only 226,950
-- Q12 Revenue / Supplier Count = 711,915 / 14 = 50,851
-- Q19 Tier A = ZSTR. SELECT SUM(e.NETWR) FROM EKPO e JOIN LFA1 l USING (LIFNR) WHERE l.KTOKK='ZSTR';    -- 251,690
-- Q20 intentionally undefined everywhere (no SV metric, no BON term).
-- Top customer C-1001: 223,498
