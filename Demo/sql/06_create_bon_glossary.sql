-- =============================================================================
-- 06_create_bon_glossary.sql
-- Recreates the Business Ontology Glossary in Snowflake
-- =============================================================================
--
-- HOW TO USE THIS SCRIPT
-- ----------------------
-- This script uses SYSTEM$ API calls that return dynamic IDs. You CANNOT run
-- it as a single batch. Instead, execute each SELECT statement one at a time
-- and note the returned IDs. The APPROVE calls require the termId returned
-- by each DRAFT call, and the RELATIONSHIP calls require termIds from both
-- the source and target terms.
--
-- Execution order per domain:
--   1. CREATE the glossary domain
--   2. DRAFT each term (note the returned termId)
--   3. APPROVE each term using its termId
-- After ALL domains are created:
--   4. DRAFT each relationship (note the returned relationshipId)
--   5. APPROVE each relationship using its relationshipId
-- =============================================================================

USE DATABASE BUSINESS_ONTOLOGY;
USE SCHEMA PUBLIC;

-- =============================================================================
-- DOMAIN 1: SAP Purchasing (15 terms)
-- =============================================================================

SELECT SYSTEM$CREATE_GLOSSARY_DOMAIN('SAP Purchasing');

-- ---------------------------------------------------------------------------
-- 1.1  Entities
-- ---------------------------------------------------------------------------

-- Term 1: Supplier
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Supplier",
  "itemKind": "ENTITY",
  "description": "Vendor master entity (LFA1). KTOKK: ZSTR=Strategic, ZSTD=Standard, ZPRB=Probationary (exclude from counts)."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Supplier>');

-- Term 2: Material
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Material",
  "itemKind": "ENTITY",
  "description": "Material master entity (MARA). MATKL codes: 043=Electronics, 044=Chemicals, 045=Metals, 046=Polymers, 047=Substrates."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Material>');

-- Term 3: Purchase Order
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Purchase Order",
  "itemKind": "ENTITY",
  "description": "Purchasing document (EKPO). STATU: O=Open, C=Confirmed, R=Received. Use NETWR for value, MENGE for quantity."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Purchase_Order>');

-- Term 4: Shipment
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Shipment",
  "itemKind": "ENTITY",
  "description": "Delivery/shipment entity (LIKP). Compare WADAT vs LFDAT for operational OTD (NOT LFA2.OTRAT)."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Shipment>');

-- Term 5: Carrier
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Carrier",
  "itemKind": "ENTITY",
  "description": "Forwarding agent (LFA2). VSART: 01=Road, 02=Rail, 03=Sea, 04=Air. OTRAT is self-reported — use LIKP for real OTD."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Carrier>');

-- Term 6: Inspection
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Inspection",
  "itemKind": "ENTITY",
  "description": "Quality inspection lot (QALS). VCODE: A=Accepted, R=Rejected, C=Conditional. QAESSION = defect rate %."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Inspection>');

-- Term 7: BOM Item
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "BOM Item",
  "itemKind": "ENTITY",
  "description": "Bill of Materials component (STPO). STLNR=parent assembly, IDNRK=child component. 4-level hierarchy enables recursive cost rollup."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_BOM_Item>');

-- ---------------------------------------------------------------------------
-- 1.2  Metrics
-- ---------------------------------------------------------------------------

-- Term 8: Canonical Supplier Count
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Canonical Supplier Count",
  "itemKind": "METRIC",
  "description": "Excludes ZPRB probationary. Answer: 14 not 15.",
  "formula": "COUNT(DISTINCT LIFNR) FROM LFA1 WHERE KTOKK IN (''ZSTR'',''ZSTD'')"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Canonical_Supplier_Count>');

-- Term 9: Operational OTD Rate
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Operational OTD Rate",
  "itemKind": "METRIC",
  "description": "Real delivery OTD. NOT LFA2.OTRAT (carrier self-reported ~90%).",
  "formula": "COUNT(CASE WHEN WADAT_IST <= LFDAT THEN 1 END) / COUNT(*) FROM LIKP WHERE STATU=''D''"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Operational_OTD_Rate>');

-- Term 10: Total Procurement Spend
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Total Procurement Spend",
  "itemKind": "METRIC",
  "description": "Confirmed/received POs only. NOT LFB1.JWERT (annual contract values).",
  "formula": "SUM(NETWR) FROM EKPO WHERE STATU IN (''C'',''R'')"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Total_Procurement_Spend>');

-- Term 11: Weighted Supply Risk Score
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Weighted Supply Risk Score",
  "itemKind": "METRIC",
  "description": "Fixed policy weights. DO NOT change. Top risk: MAT-006 at 0.70.",
  "formula": "0.4 * single_source_flag + 0.3 * defect_rate + 0.3 * delivery_failure_rate"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Weighted_Supply_Risk_Score>');

-- Term 12: Supplier Disruption Cascade
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "Supplier Disruption Cascade",
  "itemKind": "METRIC",
  "description": "5-hop cross-domain chain from supplier to revenue impact.",
  "formula": "Supplier -> EKPO(materials) -> STPO(recursive upward) -> affected assemblies -> VBAP(revenue)"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Supplier_Disruption_Cascade>');

-- Term 13: BOM Cost Rollup
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "BOM Cost Rollup",
  "itemKind": "METRIC",
  "description": "True material cost. NOT assembly STPRS (includes overhead).",
  "formula": "Recursive STPO traversal: leaf MARA.STPRS * STPO.MENGE, summed up hierarchy"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_BOM_Cost_Rollup>');

-- ---------------------------------------------------------------------------
-- 1.3  SAP Decoders (TERM kind)
-- ---------------------------------------------------------------------------

-- Term 14: MATKL Material Group Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "MATKL Material Group Decoder",
  "itemKind": "TERM",
  "description": "SAP material group codes: 043=Electronics, 044=Chemicals, 045=Metals, 046=Polymers, 047=Substrates"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_MATKL_Material_Group_Decoder>');

-- Term 15: KTOKK Account Group Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Purchasing",
  "name": "KTOKK Account Group Decoder",
  "itemKind": "TERM",
  "description": "SAP vendor account groups: ZSTR=Strategic partner, ZSTD=Standard vendor, ZPRB=Probationary (exclude from active counts)"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_KTOKK_Account_Group_Decoder>');


-- =============================================================================
-- DOMAIN 2: SAP Finance (7 terms)
-- =============================================================================

SELECT SYSTEM$CREATE_GLOSSARY_DOMAIN('SAP Finance');

-- ---------------------------------------------------------------------------
-- 2.1  Entities
-- ---------------------------------------------------------------------------

-- Term 16: AP Line Item
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "AP Line Item",
  "itemKind": "ENTITY",
  "description": "Accounting document line (BSEG). BSCHL posting keys: 31=Invoice (add), 34=Credit memo (SUBTRACT). HKONT=GL account."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_AP_Line_Item>');

-- Term 17: Cost Posting
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "Cost Posting",
  "itemKind": "ENTITY",
  "description": "Cost element posting (COEP). OBJNR=cost object: KS-MFG-US/EU/AP=Manufacturing, KS-LOG=Logistics, KS-QA=Quality."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Cost_Posting>');

-- ---------------------------------------------------------------------------
-- 2.2  Metrics
-- ---------------------------------------------------------------------------

-- Term 18: COGS Raw Materials
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "COGS Raw Materials",
  "itemKind": "METRIC",
  "description": "Credit memos subtract. $1,290,020 not $1,353,690.",
  "formula": "SUM(CASE WHEN BSCHL=''31'' THEN DMBTR WHEN BSCHL=''34'' THEN -DMBTR END) FROM BSEG WHERE HKONT=''0040100000''"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_COGS_Raw_Materials>');

-- Term 19: Product Gross Margin
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "Product Gross Margin",
  "itemKind": "METRIC",
  "description": "Cross-domain: Sales revenue minus recursive BOM material cost. No direct FK.",
  "formula": "VBAP.NETWR - (BOM_Cost_Rollup * VBAP.KWMENG)"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Product_Gross_Margin>');

-- ---------------------------------------------------------------------------
-- 2.3  SAP Decoders (TERM kind)
-- ---------------------------------------------------------------------------

-- Term 20: BSCHL Posting Key Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "BSCHL Posting Key Decoder",
  "itemKind": "TERM",
  "description": "SAP posting keys: 31=Vendor invoice (positive/add), 34=Credit memo (negative/SUBTRACT from totals)"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_BSCHL_Posting_Key_Decoder>');

-- Term 21: HKONT GL Account Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "HKONT GL Account Decoder",
  "itemKind": "TERM",
  "description": "SAP GL accounts: 0040100000=COGS Raw Materials, 0040200000=COGS Freight"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_HKONT_GL_Account_Decoder>');

-- Term 22: OBJNR Cost Object Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Finance",
  "name": "OBJNR Cost Object Decoder",
  "itemKind": "TERM",
  "description": "SAP cost objects: KS-MFG-US=US Manufacturing, KS-MFG-EU=EU Manufacturing, KS-MFG-AP=AP Manufacturing, KS-LOG=Logistics, KS-QA=Quality Assurance"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_OBJNR_Cost_Object_Decoder>');


-- =============================================================================
-- DOMAIN 3: SAP Sales (7 terms)
-- =============================================================================

SELECT SYSTEM$CREATE_GLOSSARY_DOMAIN('SAP Sales');

-- ---------------------------------------------------------------------------
-- 3.1  Entities
-- ---------------------------------------------------------------------------

-- Term 23: Sales Order
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "Sales Order",
  "itemKind": "ENTITY",
  "description": "Sales document item (VBAP). VKORG sales org: 1000=Americas, 2000=EMEA, 3000=APAC. NETWR=net value, KWMENG=quantity."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Sales_Order>');

-- Term 24: Pricing Condition
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "Pricing Condition",
  "itemKind": "ENTITY",
  "description": "Pricing condition record (KONV). KSCHL: PR00=Base price, K007=Customer discount, KF00=Freight surcharge."
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Pricing_Condition>');

-- ---------------------------------------------------------------------------
-- 3.2  Metrics
-- ---------------------------------------------------------------------------

-- Term 25: Discount Leakage
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "Discount Leakage",
  "itemKind": "METRIC",
  "description": "Customer discounts only (K007). EXCLUDE KF00 freight surcharges.",
  "formula": "SUM(ABS(KWERT)) FROM KONV WHERE KSCHL=''K007''"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Discount_Leakage>');

-- Term 26: Disruption Revenue Impact
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "Disruption Revenue Impact",
  "itemKind": "METRIC",
  "description": "Revenue at risk from supplier disruption. Uses Formula 12 output.",
  "formula": "Disruption_Cascade assemblies -> VBAP.NETWR"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Disruption_Revenue_Impact>');

-- Term 27: Cost Center Total
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "Cost Center Total",
  "itemKind": "METRIC",
  "description": "Filter by OBJNR: KS-MFG-US for US Manufacturing = $419,750.",
  "formula": "SUM(WRTBTR) FROM COEP WHERE OBJNR = cost_object_code"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_Cost_Center_Total>');

-- ---------------------------------------------------------------------------
-- 3.3  SAP Decoders (TERM kind)
-- ---------------------------------------------------------------------------

-- Term 28: KSCHL Condition Type Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "KSCHL Condition Type Decoder",
  "itemKind": "TERM",
  "description": "SAP condition types: PR00=Base/list price, K007=Customer discount (include), KF00=Freight surcharge (EXCLUDE from discount calculations)"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_KSCHL_Condition_Type_Decoder>');

-- Term 29: VKORG Sales Org Decoder
SELECT SYSTEM$DRAFT_GLOSSARY_TERM('{
  "domainName": "SAP Sales",
  "name": "VKORG Sales Org Decoder",
  "itemKind": "TERM",
  "description": "SAP sales organizations: 1000=Americas, 2000=EMEA, 3000=APAC"
}');
-- >> Note the returned termId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_TERM('<termId_for_VKORG_Sales_Org_Decoder>');


-- =============================================================================
-- RELATIONSHIPS (8 total)
-- =============================================================================
-- IMPORTANT: Replace each <termId_for_...> placeholder below with the actual
-- termId returned by the corresponding SYSTEM$DRAFT_GLOSSARY_TERM call above.
-- Execute each DRAFT_GLOSSARY_RELATIONSHIP, note the returned relationshipId,
-- then APPROVE it.
-- =============================================================================

-- Relationship 1: Supplier -> Material (supplies)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Supplier>",
  "targetTermId": "<termId_for_Material>",
  "relationshipType": "RELATED_TO",
  "description": "supplies"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 2: Material -> BOM Item (component_of)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Material>",
  "targetTermId": "<termId_for_BOM_Item>",
  "relationshipType": "HAS_PART",
  "description": "component_of"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 3: Purchase Order -> Supplier (placed_with)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Purchase_Order>",
  "targetTermId": "<termId_for_Supplier>",
  "relationshipType": "RELATED_TO",
  "description": "placed_with"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 4: Carrier -> Shipment (fulfills)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Carrier>",
  "targetTermId": "<termId_for_Shipment>",
  "relationshipType": "RELATED_TO",
  "description": "fulfills"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 5: Inspection -> Material (inspects)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Inspection>",
  "targetTermId": "<termId_for_Material>",
  "relationshipType": "RELATED_TO",
  "description": "inspects"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 6: Purchase Order -> AP Line Item (initiates)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Purchase_Order>",
  "targetTermId": "<termId_for_AP_Line_Item>",
  "relationshipType": "RELATED_TO",
  "description": "initiates"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 7: AP Line Item -> Cost Posting (contributes_to)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_AP_Line_Item>",
  "targetTermId": "<termId_for_Cost_Posting>",
  "relationshipType": "RELATED_TO",
  "description": "contributes_to"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');

-- Relationship 8: Sales Order -> Material (sold_as)
SELECT SYSTEM$DRAFT_GLOSSARY_RELATIONSHIP('{
  "sourceTermId": "<termId_for_Sales_Order>",
  "targetTermId": "<termId_for_Material>",
  "relationshipType": "RELATED_TO",
  "description": "sold_as"
}');
-- >> Note the returned relationshipId. Then run:
-- SELECT SYSTEM$APPROVE_GLOSSARY_RELATIONSHIP('<relationshipId>');


-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
-- Summary:
--   3 domains created:  SAP Purchasing, SAP Finance, SAP Sales
--   29 terms drafted:   11 ENTITY, 10 METRIC, 8 TERM (decoders)
--   8 relationships drafted (cross-domain where applicable)
--
-- Remember: Each DRAFT call returns an ID. Use that ID in the corresponding
-- APPROVE call. Relationships can only be created after their source and
-- target terms exist and are approved.
-- =============================================================================
