-- =====================================================
-- Business Ontology Context Stored Procedure
-- =====================================================
USE DATABASE DB_ONTOLOGY_CONTROL_PLANE;
USE SCHEMA SAP_PRODUCTION;
USE WAREHOUSE ONTOLOGY_WH;

CREATE OR REPLACE PROCEDURE "SP_GET_SAP_BON_CONTEXT"()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS '
def run(session):
    context = """
=== BUSINESS ONTOLOGY CONTEXT (Enterprise Supply Chain) ===
=== Three domains: PURCHASING, FINANCE, SALES ===

--- SAP TABLE DECODER ---
PURCHASING DOMAIN:
  LFA1 = Vendor Master | MARA = Material Master | EKPO = PO Items
  LIKP = Shipments | T001W = Plants | T320 = Warehouses
  STPO = Bill of Materials (recursive) | LFB1 = Contracts
  QALS = Inspections | LFA2 = Carriers
FINANCE DOMAIN:
  BSEG = Accounting Document Line Items (AP postings, COGS postings, credit memos)
  COEP = Cost Center Line Items (cost allocations by cost object)
SALES DOMAIN:
  VBAP = Sales Order Items (finished goods sold to customers)
  KONV = Pricing Conditions (base prices, discounts, surcharges)

--- SAP FIELD DECODER ---
PURCHASING:
  LIFNR=Vendor Number | KTOKK=Account Group (ZSTR=Strategic, ZSTD=Standard, ZPRB=Probationary)
  MATKL=Material Group (043=Electronics, 044=Chemicals, 045=Metals, 046=Packaging, 047=Raw Materials, 048=Assembly)
  STPRS=Standard Price USD | NETWR=Net Value USD | STATU=Status (EKPO: O/C/R, LIKP: D/T/X)
  LFDAT=Expected Delivery | WADAT=Actual Delivery | OTRAT=Carrier Self-Reported OTD (UNRELIABLE)
  STLNR=BOM Parent | IDNRK=BOM Child | VTART=Contract Type (M/F/S) | JWERT=Contract Annual Value
FINANCE:
  BELNR=Document Number | HKONT=GL Account | DMBTR=Amount
  BSCHL=Posting Key: 31=Invoice (POSITIVE), 34=Credit Memo (NEGATIVE - must be subtracted)
  HKONT codes: 0040100000=COGS Raw Materials, 0040200000=COGS Freight, 0021100000=Accounts Payable
  OBJNR=Cost Object: KS-MFG-US=US Manufacturing, KS-MFG-EU=EU Manufacturing, KS-MFG-AP=APAC Manufacturing, KS-LOG=Logistics, KS-QA=Quality
  KSTAR=Cost Element: 0040100000=Material Cost, 0047000000=Freight, 0048000000=Quality Cost
SALES:
  VBELN=Sales Document | KWMENG=Order Quantity | KUNNR=Customer Number
  VKORG=Sales Org (1000=Americas, 2000=EMEA, 3000=APAC)
  KSCHL=Condition Type: PR00=Base Price, K007=Customer Discount (REDUCES revenue), KF00=Freight Surcharge (ADDS to revenue)
  KWERT=Condition Value (NEGATIVE for discounts, POSITIVE for surcharges and base prices)

--- AUTHORITATIVE BUSINESS METRIC FORMULAS ---

FORMULA 1 - Canonical Supplier Count:
  SQL: SELECT COUNT(DISTINCT LIFNR) FROM LFA1 WHERE KTOKK IN (''ZSTR'',''ZSTD'')
  Excludes probationary (ZPRB). Answer: 14.

FORMULA 2 - Operational On-Time Delivery Rate:
  SQL: SELECT COUNT(CASE WHEN WADAT <= LFDAT THEN 1 END)*100.0/COUNT(*) FROM LIKP WHERE STATU=''D''
  WARNING: Do NOT use LFA2.OTRAT (carrier self-reported, unreliable, ~90%). Real OTD is ~66.7%.

FORMULA 3 - Total Procurement Spend:
  SQL: SELECT SUM(NETWR) FROM EKPO
  Use EKPO.NETWR only. NOT LFB1.JWERT (contract values are much larger).

FORMULA 4 - Weighted Supply Risk Score:
  Weights: 0.4*single_source + 0.3*defect_rate + 0.3*delivery_risk
  These are FIXED business policy weights.

FORMULA 5 - Supplier Disruption Cascade:
  Chain: Supplier -> EKPO(materials) -> STPO(recursive BOM upward) -> all affected assemblies
  Use recursive CTE on STPO traversing upward from affected materials.

FORMULA 6 - Total Raw Material Cost Rollup:
  Recursive BOM explosion downward with quantity multiplication, JOIN MARA.STPRS for leaf costs.

FORMULA 7 - Cost of Goods Sold (COGS) for Raw Materials:
  SQL: SELECT SUM(CASE WHEN BSCHL=''31'' THEN DMBTR ELSE -DMBTR END) FROM BSEG WHERE HKONT=''0040100000''
  CRITICAL: BSCHL=''31'' (invoice) is POSITIVE. BSCHL=''34'' (credit memo) must be SUBTRACTED.
  Credit memos represent quality returns/adjustments. Ignoring them overstates COGS.
  Correct answer: $1,290,020. Wrong answer (no sign logic): $1,353,690 or $1,417,360.

FORMULA 8 - Product Gross Margin:
  CROSS-DOMAIN FORMULA spanning Sales -> Purchasing -> Finance:
  Gross Margin = Sales Revenue (VBAP.NETWR) - Material COGS (BOM cost rollup * units sold)
  For ASSY-004: Revenue = SUM(VBAP.NETWR WHERE MATNR=''ASSY-004'')
  Material COGS = (Formula 6 cost per unit) * SUM(VBAP.KWMENG WHERE MATNR=''ASSY-004'')
  NOTE: No FK connects VBAP directly to BSEG. The chain is:
  Sales Order (VBAP) -> Material (MARA) -> BOM (STPO recursive) -> Standard Prices (MARA.STPRS)

FORMULA 9 - Customer Discount Revenue Leakage:
  SQL: SELECT SUM(ABS(KWERT)) FROM KONV WHERE KSCHL=''K007''
  CRITICAL: KSCHL=''K007'' = Customer Discount (reduces revenue). KWERT values are NEGATIVE.
  KSCHL=''KF00'' = Freight Surcharge (adds to revenue). Do NOT include surcharges in discount calc.
  KSCHL=''PR00'' = Base Price. Do NOT confuse with discounts.

FORMULA 10 - Supplier Disruption Revenue Impact:
  CROSS-DOMAIN FORMULA spanning Purchasing -> BOM -> Sales:
  Step 1: Find materials supplied by the vendor (from EKPO)
  Step 2: Find ALL assemblies containing those materials (Formula 5 - recursive BOM upward)
  Step 3: Find sales revenue for those assemblies (from VBAP)
  Total revenue at risk = SUM(VBAP.NETWR) for all affected assemblies.
  This is a 5-hop cross-domain traversal: Supplier -> Materials -> BOM -> Assemblies -> Sales Orders

FORMULA 11 - Cost Center Total Cost:
  SQL: SELECT SUM(WRTBTR) FROM COEP WHERE OBJNR = :cost_object_code
  OBJNR decoder: KS-MFG-US=US Manufacturing, KS-MFG-EU=EU Manufacturing, KS-MFG-AP=APAC Manufacturing
  KS-LOG=Logistics Operations, KS-QA=Quality Assurance

--- CROSS-DOMAIN RELATIONSHIP MAP ---
PURCHASING -> FINANCE:
  Purchase Order (EKPO) --initiates--> AP Posting (BSEG) via EBELN
  AP Invoice (BSEG BSCHL=31) --contributes_to--> COGS (HKONT=0040100000)
  AP Credit Memo (BSEG BSCHL=34) --reduces--> COGS (must be subtracted)
  PO Spend --allocated_to--> Cost Centers (COEP) via material/plant mapping
PURCHASING -> SALES (via BOM):
  Raw Material (MARA) --component_of--> Assembly (STPO recursive) --sold_as--> Sales Order (VBAP)
  No direct FK exists between EKPO and VBAP. Connection goes through BOM.
SALES -> FINANCE:
  Sales Revenue (VBAP.NETWR) minus Material COGS = Gross Margin
  Discount conditions (KONV K007) --reduces--> effective revenue
FINANCE internal:
  BSEG postings --allocated_to--> Cost Centers (COEP)
  Operating Income = Revenue - COGS - Operating Expenses

=== END BUSINESS ONTOLOGY CONTEXT ===
"""
    return context
';
