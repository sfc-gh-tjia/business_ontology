-- =====================================================================
-- BON Demo V2 — 04: ENRICHED domain semantic views
-- ENRICHED = what a strong customer builds for each team: metrics, code
-- values in comments, synonyms, custom instructions, verified queries.
--
-- Deliberate, realistic conflicts across teams (each defensible locally):
--   Supplier count : Purchasing vendor_record_count = 15  vs  Finance active_supplier_count = 14
--   On-time rate   : Purchasing carrier_otd_rate = 90%    vs  operational_otd_rate = 66.7%
--   Revenue        : Sales gross_bookings = 746,000       vs  net_revenue = 711,915
--   Unit cost      : Purchasing avg_standard_price (STPRS) vs bom_material_cost
-- Enriched SVs document each team's rules but NOT the cross-team canonical
-- decision. That decision is what Business Ontology governs.
-- =====================================================================
USE SCHEMA DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2;

CREATE OR REPLACE SEMANTIC VIEW PURCHASING_ENRICHED_SV
TABLES (
  vendors AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFA1 PRIMARY KEY (LIFNR) WITH SYNONYMS ('suppliers','vendor master') COMMENT = 'Vendor master (LFA1). One row per vendor record, including probationary vendors.',
  account_groups AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.T077K PRIMARY KEY (KTOKK) COMMENT = 'Vendor account group code table (T077K).',
  contracts AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFB1 PRIMARY KEY (LIFNR, VKONT) COMMENT = 'Vendor contracts (LFB1).',
  materials AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.MARA PRIMARY KEY (MATNR) WITH SYNONYMS ('products','parts') COMMENT = 'Material master (MARA): raw materials and assemblies.',
  material_groups AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.T023T PRIMARY KEY (MATKL) COMMENT = 'Material group code table (T023T).',
  purchase_orders AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.EKPO PRIMARY KEY (EBELN, EBELP) WITH SYNONYMS ('PO lines','procurement') COMMENT = 'Purchase order line items (EKPO).',
  plants AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.T001W PRIMARY KEY (WERKS) COMMENT = 'Plants (T001W).',
  shipments AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LIKP PRIMARY KEY (TKNUM) WITH SYNONYMS ('deliveries') COMMENT = 'Inbound shipments (LIKP).',
  carriers AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFA2 PRIMARY KEY (TDLNR) WITH SYNONYMS ('forwarding agents','logistics providers') COMMENT = 'Carriers / forwarding agents (LFA2).',
  inspections AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.QALS PRIMARY KEY (PRUEFLOS) COMMENT = 'Quality inspection lots (QALS).',
  bom AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BOM_EXPLOSION PRIMARY KEY (ASSEMBLY, COMPONENT) WITH SYNONYMS ('bill of materials') COMMENT = 'Flattened multi-level bill of materials: every component of each assembly with extended quantity per one assembly unit.'
)
RELATIONSHIPS (
  vendors_to_groups AS vendors (KTOKK) REFERENCES account_groups,
  materials_to_groups AS materials (MATKL) REFERENCES material_groups,
  contracts_to_vendors AS contracts (LIFNR) REFERENCES vendors,
  po_to_vendors AS purchase_orders (LIFNR) REFERENCES vendors,
  po_to_materials AS purchase_orders (MATNR) REFERENCES materials,
  po_to_plants AS purchase_orders (WERKS) REFERENCES plants,
  shipments_to_carriers AS shipments (TDLNR) REFERENCES carriers,
  shipments_to_plants AS shipments (WERKS_DST) REFERENCES plants,
  inspections_to_materials AS inspections (MATNR) REFERENCES materials,
  bom_to_components AS bom (COMPONENT) REFERENCES materials
)
FACTS (
  materials.standard_price AS STPRS COMMENT = 'Standard price per unit (STPRS). For assemblies this is a planning price, not the material cost to build.',
  purchase_orders.order_value AS NETWR COMMENT = 'Net PO line value',
  purchase_orders.order_qty AS MENGE COMMENT = 'PO quantity',
  shipments.freight_cost AS FRTCO COMMENT = 'Freight cost per shipment',
  shipments.is_on_time AS IFF(WADAT <= LFDAT, 1, 0) COMMENT = '1 if goods issue date on or before planned delivery date',
  shipments.is_delivered AS IFF(STATU = 'D', 1, 0) COMMENT = '1 if shipment status is D (delivered)',
  carriers.carrier_on_time_ratio AS OTRAT COMMENT = 'Carrier self-reported on-time ratio (0-1)',
  inspections.defect_rate AS QAESSION COMMENT = 'Defect rate of the inspection lot',
  contracts.annual_contract_value AS JWERT COMMENT = 'Annual contract value',
  bom.extended_qty AS EXTENDED_QTY COMMENT = 'Component quantity needed for one unit of the assembly',
  bom.leaf_material_cost AS IFF(IS_LEAF, EXTENDED_QTY * materials.standard_price, 0) COMMENT = 'Material cost contributed by a leaf (purchased) component per assembly unit'
)
DIMENSIONS (
  vendors.vendor_id AS LIFNR WITH SYNONYMS ('supplier id','LIFNR') COMMENT = 'Vendor number',
  vendors.vendor_name AS NAME1 COMMENT = 'Vendor name',
  vendors.vendor_city AS ORT01 COMMENT = 'City',
  vendors.vendor_country AS LAND1 COMMENT = 'Country code',
  vendors.account_group AS KTOKK WITH SYNONYMS ('KTOKK','vendor type') COMMENT = 'Vendor account group: ZSTR = Strategic partner, ZSTD = Standard vendor, ZPRB = Probationary vendor',
  account_groups.account_group_name AS TXT30 COMMENT = 'Account group description',
  account_groups.excluded_from_active_count AS EXCLUDE_FROM_ACTIVE_COUNT COMMENT = 'TRUE for groups excluded from active supplier counts (ZPRB)',
  materials.material_id AS MATNR WITH SYNONYMS ('MATNR','part number') COMMENT = 'Material number. ASSY-* are assemblies we sell; MAT-* are purchased components.',
  materials.material_name AS MAKTX COMMENT = 'Material description',
  materials.material_group AS MATKL WITH SYNONYMS ('MATKL') COMMENT = 'Material group code: 043 Electronics, 044 Chemicals, 045 Metals, 046 Packaging, 047 Raw Materials, 048 Assembly',
  material_groups.material_group_name AS WGBEZ WITH SYNONYMS ('category') COMMENT = 'Material group description',
  purchase_orders.po_number AS EBELN COMMENT = 'Purchase order number',
  purchase_orders.po_status AS STATU COMMENT = 'PO status',
  purchase_orders.po_date AS BEDAT COMMENT = 'PO date',
  plants.plant_id AS WERKS COMMENT = 'Plant',
  plants.plant_name AS NAME1 COMMENT = 'Plant name',
  plants.region AS REGIO COMMENT = 'Region',
  shipments.shipment_id AS TKNUM COMMENT = 'Shipment number',
  shipments.shipment_status AS STATU COMMENT = 'Shipment status: D = Delivered, T = In transit, X = Cancelled',
  shipments.planned_delivery_date AS LFDAT COMMENT = 'Planned delivery date',
  shipments.goods_issue_date AS WADAT COMMENT = 'Actual goods issue date',
  carriers.carrier_id AS TDLNR COMMENT = 'Carrier id',
  carriers.carrier_name AS NAME1 COMMENT = 'Carrier name',
  carriers.shipping_type AS VSART COMMENT = 'Shipping type',
  inspections.usage_decision AS VCODE COMMENT = 'Inspection usage decision code',
  contracts.contract_type AS VTART COMMENT = 'Contract type',
  bom.assembly_id AS ASSEMBLY WITH SYNONYMS ('finished good','assembly') COMMENT = 'Assembly material number (ASSY-*)',
  bom.component_id AS COMPONENT COMMENT = 'Component material number',
  bom.is_leaf_component AS IS_LEAF COMMENT = 'TRUE if the component is purchased (not a sub-assembly)'
)
METRICS (
  vendors.vendor_record_count AS COUNT(DISTINCT vendors.LIFNR) WITH SYNONYMS ('supplier count','number of suppliers','vendor count') COMMENT = 'Count of vendor master records. Procurement operational view: includes every vendor on file, including probationary (ZPRB).',
  purchase_orders.procurement_spend AS SUM(purchase_orders.order_value) WITH SYNONYMS ('spend','purchase spend') COMMENT = 'Total net PO value',
  carriers.carrier_otd_rate AS AVG(carriers.carrier_on_time_ratio) * 100 WITH SYNONYMS ('on-time delivery rate','OTD','carrier on-time rate') COMMENT = 'Average carrier self-reported on-time rate, in percent',
  shipments.operational_otd_rate AS 100 * SUM(shipments.is_on_time * shipments.is_delivered) / NULLIF(SUM(shipments.is_delivered), 0) WITH SYNONYMS ('actual on-time delivery','measured OTD') COMMENT = 'Percent of delivered shipments with goods issue on or before planned date, in percent',
  shipments.total_freight_cost AS SUM(shipments.freight_cost) COMMENT = 'Total freight cost on shipments',
  bom.bom_material_cost AS SUM(bom.leaf_material_cost) WITH SYNONYMS ('BOM cost','material cost per unit','cost to build') COMMENT = 'Material cost to build one unit of an assembly: sum of extended quantity x standard price over purchased (leaf) components. Group by assembly_id.',
  materials.avg_standard_price AS AVG(materials.standard_price) WITH SYNONYMS ('unit cost','standard cost') COMMENT = 'Average standard price (STPRS)',
  inspections.avg_defect_rate AS AVG(inspections.defect_rate) COMMENT = 'Average defect rate'
)
COMMENT = 'Procurement domain (owned by the Purchasing team): vendors, materials, purchase orders, shipments, carriers, inspections, bill of materials.'
AI_SQL_GENERATION 'Material codes: MATKL 043 = Electronics, 047 = Raw Materials, 048 = Assembly. Join material_groups for group names. Assemblies (ASSY-*) are built from components listed in bom; bom already includes all levels, so never recurse. Shipment status D = delivered.'
AI_VERIFIED_QUERIES (
  spend_by_group AS (QUESTION 'Procurement spend by material group' SQL 'SELECT * FROM SEMANTIC_VIEW(DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV METRICS purchase_orders.procurement_spend DIMENSIONS material_groups.material_group_name)'),
  bom_cost_by_assembly AS (QUESTION 'Material cost to build each assembly' SQL 'SELECT * FROM SEMANTIC_VIEW(DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.PURCHASING_ENRICHED_SV METRICS bom.bom_material_cost DIMENSIONS bom.assembly_id)')
);

-- ---------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW FINANCE_ENRICHED_SV
TABLES (
  ap_lines AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.BSEG PRIMARY KEY (BELNR, BUZEI) WITH SYNONYMS ('accounts payable','AP postings','invoices') COMMENT = 'Accounting document line items (BSEG) for vendor invoices and credit memos.',
  cost_postings AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.COEP WITH SYNONYMS ('cost allocations','controlling postings') COMMENT = 'Controlling cost postings by cost object (COEP).',
  vendors AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.LFA1 PRIMARY KEY (LIFNR) WITH SYNONYMS ('suppliers') COMMENT = 'Vendor master (LFA1) as used by Finance.',
  account_groups AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.T077K PRIMARY KEY (KTOKK) COMMENT = 'Vendor account group code table (T077K).'
)
RELATIONSHIPS (
  ap_to_vendors AS ap_lines (LIFNR) REFERENCES vendors,
  vendors_to_groups AS vendors (KTOKK) REFERENCES account_groups
)
FACTS (
  ap_lines.amount AS DMBTR COMMENT = 'Posting amount in local currency (always positive; direction comes from posting_key)',
  ap_lines.signed_amount AS CASE WHEN BSCHL = '31' THEN DMBTR WHEN BSCHL = '34' THEN -DMBTR ELSE 0 END COMMENT = 'Amount with sign: invoice (31) positive, credit memo (34) negative',
  cost_postings.posted_cost AS WRTBTR COMMENT = 'Cost value in reporting currency'
)
DIMENSIONS (
  ap_lines.document_number AS BELNR COMMENT = 'Accounting document number',
  ap_lines.po_number AS EBELN COMMENT = 'Purchase order number',
  ap_lines.vendor_id AS LIFNR COMMENT = 'Vendor number',
  ap_lines.gl_account AS HKONT WITH SYNONYMS ('HKONT','GL account') COMMENT = 'GL account: 0040100000 = COGS Raw Materials, 0040200000 = COGS Freight, 0021100000 = Accounts Payable',
  ap_lines.posting_key AS BSCHL WITH SYNONYMS ('BSCHL') COMMENT = 'Posting key: 31 = vendor invoice (adds cost), 34 = vendor credit memo (reduces cost)',
  ap_lines.fiscal_year AS GJAHR COMMENT = 'Fiscal year',
  ap_lines.fiscal_period AS MONAT COMMENT = 'Fiscal period',
  ap_lines.posting_date AS BUDAT COMMENT = 'Posting date',
  cost_postings.cost_object AS OBJNR WITH SYNONYMS ('OBJNR','cost center') COMMENT = 'Cost object: KS-MFG-US = US Manufacturing, KS-MFG-EU = EU Manufacturing, KS-MFG-AP = APAC Manufacturing, KS-LOG = Logistics, KS-QA = Quality Assurance',
  cost_postings.cost_element AS KSTAR COMMENT = 'Cost element',
  cost_postings.material_id AS MATNR COMMENT = 'Material number',
  vendors.vendor_name AS NAME1 COMMENT = 'Vendor name',
  vendors.account_group AS KTOKK WITH SYNONYMS ('KTOKK') COMMENT = 'Vendor account group: ZSTR = Strategic, ZSTD = Standard, ZPRB = Probationary',
  account_groups.excluded_from_active_count AS EXCLUDE_FROM_ACTIVE_COUNT COMMENT = 'TRUE for probationary groups'
)
METRICS (
  ap_lines.cogs_raw_materials AS SUM(IFF(ap_lines.HKONT = '0040100000', ap_lines.signed_amount, 0)) WITH SYNONYMS ('COGS','cost of goods sold','raw material COGS') COMMENT = 'COGS for raw materials: GL 0040100000, invoices minus credit memos',
  ap_lines.cogs_freight AS SUM(IFF(ap_lines.HKONT = '0040200000', ap_lines.signed_amount, 0)) WITH SYNONYMS ('freight COGS') COMMENT = 'Freight COGS: GL 0040200000, invoices minus credit memos',
  ap_lines.net_ap_amount AS SUM(ap_lines.signed_amount) COMMENT = 'Net payable amount across all GL accounts, credit memos subtracted',
  cost_postings.total_posted_cost AS SUM(cost_postings.posted_cost) WITH SYNONYMS ('allocated cost','cost center total') COMMENT = 'Total cost posted; filter or group by cost_object',
  vendors.active_supplier_count AS COUNT(DISTINCT IFF(vendors.KTOKK IN ('ZSTR','ZSTD'), vendors.LIFNR, NULL)) WITH SYNONYMS ('supplier count','number of suppliers','active vendors') COMMENT = 'Active suppliers for Finance reporting: strategic (ZSTR) and standard (ZSTD) vendors; probationary (ZPRB) excluded'
)
COMMENT = 'Finance & Controlling domain (owned by the Finance team): AP postings, COGS, cost allocations.'
AI_SQL_GENERATION 'Always apply the posting-key sign: BSCHL 31 adds, BSCHL 34 subtracts. Use signed_amount, never raw amount, for any cost or COGS total. Cost object codes are in cost_object.'
AI_VERIFIED_QUERIES (
  cogs_raw AS (QUESTION 'What is COGS for raw materials?' SQL 'SELECT * FROM SEMANTIC_VIEW(DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV METRICS ap_lines.cogs_raw_materials)'),
  cost_by_object AS (QUESTION 'Total cost by cost object' SQL 'SELECT * FROM SEMANTIC_VIEW(DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.FINANCE_ENRICHED_SV METRICS cost_postings.total_posted_cost DIMENSIONS cost_postings.cost_object)')
);

-- ---------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SALES_ENRICHED_SV
TABLES (
  sales_items AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.VBAP PRIMARY KEY (VBELN, POSNR) WITH SYNONYMS ('sales orders','orders','bookings') COMMENT = 'Sales order line items (VBAP). NETWR is the order value before customer discounts.',
  pricing AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.KONV PRIMARY KEY (KNUMV, KPOSN, KSCHL) WITH SYNONYMS ('pricing conditions','conditions') COMMENT = 'Pricing condition records (KONV): list price, discounts, surcharges.',
  products AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.MARA PRIMARY KEY (MATNR) WITH SYNONYMS ('materials','assemblies') COMMENT = 'Material master (MARA): the assemblies we sell.',
  customers AS DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.KNA1 PRIMARY KEY (KUNNR) WITH SYNONYMS ('accounts','clients') COMMENT = 'Customers.'
)
RELATIONSHIPS (
  sales_to_products AS sales_items (MATNR) REFERENCES products,
  sales_to_customers AS sales_items (KUNNR) REFERENCES customers,
  pricing_to_products AS pricing (MATNR) REFERENCES products,
  pricing_to_customers AS pricing (KUNNR) REFERENCES customers
)
FACTS (
  sales_items.order_value AS NETWR COMMENT = 'Order line value before customer discounts',
  sales_items.order_qty AS KWMENG COMMENT = 'Units ordered',
  pricing.condition_value AS KWERT COMMENT = 'Condition value (discounts are negative)',
  pricing.condition_rate AS KBETR COMMENT = 'Condition rate; for PR00 this is the list price per unit',
  pricing.discount_amount AS IFF(KSCHL = 'K007', ABS(KWERT), 0) COMMENT = 'Customer discount amount (K007), positive',
  pricing.surcharge_amount AS IFF(KSCHL = 'KF00', ABS(KWERT), 0) COMMENT = 'Freight surcharge amount (KF00)'
)
DIMENSIONS (
  sales_items.sales_document AS VBELN COMMENT = 'Sales document number',
  sales_items.sales_org AS VKORG WITH SYNONYMS ('VKORG','sales organization','region') COMMENT = 'Sales organization: 1000 = Americas, 2000 = EMEA, 3000 = APAC',
  sales_items.order_date AS ERDAT COMMENT = 'Order created date',
  pricing.condition_type AS KSCHL WITH SYNONYMS ('KSCHL') COMMENT = 'Condition type: PR00 = list price, K007 = customer discount, KF00 = freight surcharge',
  products.product_id AS MATNR WITH SYNONYMS ('MATNR','assembly id') COMMENT = 'Material number (ASSY-* assemblies)',
  products.product_name AS MAKTX COMMENT = 'Product description',
  customers.customer_id AS KUNNR WITH SYNONYMS ('KUNNR','customer number') COMMENT = 'Customer number'
)
METRICS (
  sales_items.gross_bookings AS SUM(sales_items.order_value) WITH SYNONYMS ('revenue','sales','total sales','bookings') COMMENT = 'Gross bookings: total order value before customer discounts. Sales team pipeline and quota metric.',
  sales_items.units_sold AS SUM(sales_items.order_qty) WITH SYNONYMS ('quantity sold','volume') COMMENT = 'Units ordered',
  pricing.customer_discounts AS SUM(pricing.discount_amount) WITH SYNONYMS ('discounts','discount leakage','revenue lost to discounts') COMMENT = 'Customer discounts granted (K007 only; excludes freight surcharges)',
  pricing.freight_surcharges AS SUM(pricing.surcharge_amount) COMMENT = 'Freight surcharges billed (KF00)',
  pricing.list_price AS AVG(IFF(pricing.KSCHL = 'PR00', pricing.condition_rate, NULL)) WITH SYNONYMS ('price','unit price') COMMENT = 'List price per unit (PR00 condition rate)',
  net_revenue AS sales_items.gross_bookings - pricing.customer_discounts WITH SYNONYMS ('net sales','revenue after discounts') COMMENT = 'Order value net of K007 customer discounts'
)
COMMENT = 'Sales & Distribution domain (owned by the Sales team): orders, pricing conditions, customers.'
AI_SQL_GENERATION 'Discounts are condition type K007; freight surcharges KF00 are not discounts. List price is the PR00 condition rate.'
AI_VERIFIED_QUERIES (
  bookings_by_product AS (QUESTION 'Gross bookings by product' SQL 'SELECT * FROM SEMANTIC_VIEW(DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV METRICS sales_items.gross_bookings DIMENSIONS products.product_id)'),
  discounts_total AS (QUESTION 'How much do we give away in customer discounts?' SQL 'SELECT * FROM SEMANTIC_VIEW(DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.SALES_ENRICHED_SV METRICS pricing.customer_discounts)')
);

-- Verification (all match BENCHMARK_GROUND_TRUTH):
-- SELECT * FROM SEMANTIC_VIEW(PURCHASING_ENRICHED_SV METRICS bom.bom_material_cost DIMENSIONS bom.assembly_id);   -- ASSY-004 = 286.60
-- SELECT * FROM SEMANTIC_VIEW(PURCHASING_ENRICHED_SV METRICS shipments.operational_otd_rate, carriers.carrier_otd_rate); -- 66.7 / 90
-- SELECT * FROM SEMANTIC_VIEW(FINANCE_ENRICHED_SV METRICS ap_lines.cogs_raw_materials, ap_lines.cogs_freight, vendors.active_supplier_count); -- 1,290,020 / 39,800 / 14
-- SELECT * FROM SEMANTIC_VIEW(SALES_ENRICHED_SV METRICS sales_items.gross_bookings, pricing.customer_discounts, net_revenue);  -- 746,000 / 34,085 / 711,915
