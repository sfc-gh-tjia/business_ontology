-- =====================================================================
-- BON Demo V2 — 06: Representations (bind meaning to the assets that implement it)
-- 44 representations:
--   IMPLEMENTS            : metric -> the exact SV metric (field-level binding, verified working)
--   RELATED_SEMANTIC_VIEW : cross-SV metric -> every SV that supplies one of its inputs
--   REPRESENTS            : entity -> table/view
--   DESCRIBES             : code-mapping term -> column
--   REFERENCE_DATA        : code-mapping term -> code table (T077K, T023T)
-- Verified: owners/stewards cannot be set via API (patch schema rejects `owners`);
-- stewardship is recorded in domain descriptions.
-- =====================================================================
-- Helper: SV sub-component ref = {"refType":"SEMANTIC_VIEW","fqn":<sv>,"subObjectType":"METRIC","entityQualifier":<logical table>,"subObjectName":<metric>}

-- ------------------------------------------------ Canonical metrics -> implementing SV metric
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Supplier Count', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"VENDORS","subObjectName":"ACTIVE_SUPPLIER_COUNT"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Vendor Record Count', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"VENDORS","subObjectName":"VENDOR_RECORD_COUNT"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.On-Time Delivery Rate', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"SHIPMENTS","subObjectName":"OPERATIONAL_OTD_RATE"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Carrier Reported On-Time Rate', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"CARRIERS","subObjectName":"CARRIER_OTD_RATE"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.BOM Cost Rollup', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"BOM","subObjectName":"BOM_MATERIAL_COST"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Procurement Spend', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"PURCHASE_ORDERS","subObjectName":"PROCUREMENT_SPEND"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Revenue', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","subObjectType":"DERIVED_METRIC","subObjectName":"NET_REVENUE"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Gross Bookings', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"SALES_ITEMS","subObjectName":"GROSS_BOOKINGS"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Customer Discounts', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"PRICING","subObjectName":"CUSTOMER_DISCOUNTS"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.COGS Raw Materials', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"AP_LINES","subObjectName":"COGS_RAW_MATERIALS"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.COGS Freight', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"AP_LINES","subObjectName":"COGS_FREIGHT"}', 'IMPLEMENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Cost Center Total', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV","subObjectType":"METRIC","entityQualifier":"COST_POSTINGS","subObjectName":"TOTAL_POSTED_COST"}', 'IMPLEMENTS');

-- ------------------------------------------------ Cross-SV metrics -> each contributing SV
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Product Gross Margin', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","objectName":"SALES_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Product Gross Margin', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","objectName":"PURCHASING_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Customer Profit', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","objectName":"SALES_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Customer Profit', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","objectName":"PURCHASING_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Break-even Discount', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","objectName":"SALES_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Break-even Discount', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","objectName":"PURCHASING_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Revenue at Risk', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV","objectName":"SALES_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Revenue at Risk', '{"refType":"SEMANTIC_VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV","objectName":"PURCHASING_ENRICHED_SV"}', 'RELATED_SEMANTIC_VIEW');

-- ------------------------------------------------ Entities -> tables / views
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Supplier', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFA1","objectName":"LFA1"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Material', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.MARA","objectName":"MARA"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Assembly', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.MARA","objectName":"MARA"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Bill of Materials', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.STPO","objectName":"STPO"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Bill of Materials', '{"refType":"VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BOM_EXPLOSION","objectName":"BOM_EXPLOSION"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Purchase Order', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.EKPO","objectName":"EKPO"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Shipment', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LIKP","objectName":"LIKP"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Carrier', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFA2","objectName":"LFA2"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Inspection Lot', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.QALS","objectName":"QALS"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Sales Order', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.VBAP","objectName":"VBAP"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Customer', '{"refType":"VIEW","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.KNA1","objectName":"KNA1"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Pricing Condition', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.KONV","objectName":"KONV"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.AP Line Item', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BSEG","objectName":"BSEG"}', 'REPRESENTS');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Cost Posting', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.COEP","objectName":"COEP"}', 'REPRESENTS');

-- ------------------------------------------------ Code-mapping terms -> columns + code tables
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Vendor Account Group', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFA1","dimensionName":"KTOKK"}', 'DESCRIBES');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Vendor Account Group', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.T077K","objectName":"T077K"}', 'REFERENCE_DATA');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Material Group', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.MARA","dimensionName":"MATKL"}', 'DESCRIBES');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Procurement.Material Group', '{"refType":"TABLE","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.T023T","objectName":"T023T"}', 'REFERENCE_DATA');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Condition Type', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.KONV","dimensionName":"KSCHL"}', 'DESCRIBES');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Sales & Distribution.Sales Organization', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.VBAP","dimensionName":"VKORG"}', 'DESCRIBES');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Posting Key', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BSEG","dimensionName":"BSCHL"}', 'DESCRIBES');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.GL Account', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BSEG","dimensionName":"HKONT"}', 'DESCRIBES');
SELECT SYSTEM$CREATE_GLOSSARY_ASSOCIATION('Finance & Controlling.Cost Object', '{"refType":"COLUMN","fqn":"DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.COEP","dimensionName":"OBJNR"}', 'DESCRIBES');
