-- =====================================================
-- SAP Baseline Semantic View
-- =====================================================
USE DATABASE DB_ONTOLOGY_CONTROL_PLANE;
USE SCHEMA SAP_PRODUCTION;
USE WAREHOUSE ONTOLOGY_WH;

CREATE OR REPLACE SEMANTIC VIEW SAP_BASELINE_SV

  TABLES (
    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFA1
      PRIMARY KEY (LIFNR)
      COMMENT = 'Vendor master data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.MARA
      PRIMARY KEY (MATNR)
      COMMENT = 'Material master data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.EKPO
      PRIMARY KEY (EBELN, EBELP)
      COMMENT = 'Purchasing document items',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LIKP
      PRIMARY KEY (TKNUM)
      COMMENT = 'Shipment data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.T001W
      PRIMARY KEY (WERKS)
      COMMENT = 'Plant data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.T320
      PRIMARY KEY (LGORT)
      COMMENT = 'Storage location data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.STPO
      PRIMARY KEY (STLNR, IDNRK)
      COMMENT = 'BOM items',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFB1
      PRIMARY KEY (LIFNR, VKONT)
      COMMENT = 'Vendor contract data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.QALS
      PRIMARY KEY (PRUEFLOS)
      COMMENT = 'Inspection lot data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.LFA2
      PRIMARY KEY (TDLNR)
      COMMENT = 'Forwarding agent data',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.BSEG
      PRIMARY KEY (BELNR, BUZEI)
      COMMENT = 'Accounting document line items',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.COEP
      COMMENT = 'Cost element line items',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.VBAP
      PRIMARY KEY (VBELN, POSNR)
      COMMENT = 'Sales document items',

    DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.KONV
      COMMENT = 'Pricing condition records'
  )

  RELATIONSHIPS (
    EKPO_TO_LFA1  AS EKPO(LIFNR)     REFERENCES LFA1(LIFNR),
    EKPO_TO_MARA  AS EKPO(MATNR)     REFERENCES MARA(MATNR),
    EKPO_TO_T001W AS EKPO(WERKS)     REFERENCES T001W(WERKS),
    LIKP_TO_LFA2  AS LIKP(TDLNR)     REFERENCES LFA2(TDLNR),
    LIKP_TO_T001W AS LIKP(WERKS_DST) REFERENCES T001W(WERKS),
    LIKP_TO_T320  AS LIKP(LGORT_SRC) REFERENCES T320(LGORT),
    T320_TO_T001W AS T320(WERKS)     REFERENCES T001W(WERKS),
    LFB1_TO_LFA1  AS LFB1(LIFNR)     REFERENCES LFA1(LIFNR),
    QALS_TO_MARA  AS QALS(MATNR)     REFERENCES MARA(MATNR),
    BSEG_TO_EKPO  AS BSEG(EBELN)     REFERENCES EKPO(EBELN),
    BSEG_TO_LFA1  AS BSEG(LIFNR)     REFERENCES LFA1(LIFNR),
    VBAP_TO_MARA  AS VBAP(MATNR)     REFERENCES MARA(MATNR)
  )

  FACTS (
    MARA.STPRS   AS STPRS   COMMENT = 'Standard price',
    EKPO.MENGE   AS MENGE   COMMENT = 'Purchase order quantity',
    EKPO.NETWR   AS NETWR   COMMENT = 'Net order value',
    LIKP.MENGE   AS MENGE   COMMENT = 'Delivery quantity',
    LIKP.FRTCO   AS FRTCO   COMMENT = 'Freight cost',
    T320.LKAPA   AS LKAPA   COMMENT = 'Storage location capacity',
    STPO.MENGE   AS MENGE   COMMENT = 'Component quantity',
    STPO.STUFE   AS STUFE   COMMENT = 'BOM level',
    LFB1.JWERT   AS JWERT   COMMENT = 'Annual contract value',
    QALS.QAESSION AS QAESSION COMMENT = 'Defect rate',
    LFA2.LZEIT   AS LZEIT   COMMENT = 'Transit time',
    LFA2.OTRAT   AS OTRAT   COMMENT = 'On-time delivery rate',
    BSEG.DMBTR   AS DMBTR   COMMENT = 'Amount in local currency',
    COEP.WRTBTR  AS WRTBTR  COMMENT = 'Value in reporting currency',
    VBAP.KWMENG  AS KWMENG  COMMENT = 'Order quantity',
    VBAP.NETWR   AS NETWR   COMMENT = 'Net value',
    KONV.KBETR   AS KBETR   COMMENT = 'Rate',
    KONV.KWERT   AS KWERT   COMMENT = 'Condition value'
  )

  DIMENSIONS (
    -- LFA1 (Vendor Master)
    LFA1.LIFNR AS LIFNR COMMENT = 'Vendor number',
    LFA1.NAME1 AS NAME1 COMMENT = 'Vendor name',
    LFA1.ORT01 AS ORT01 COMMENT = 'City',
    LFA1.LAND1 AS LAND1 COMMENT = 'Country code',
    LFA1.KTOKK AS KTOKK COMMENT = 'Account group',
    LFA1.ZTERM AS ZTERM COMMENT = 'Payment terms key',

    -- MARA (Material Master)
    MARA.MATNR AS MATNR COMMENT = 'Material number',
    MARA.MAKTX AS MAKTX COMMENT = 'Material description',
    MARA.MATKL AS MATKL COMMENT = 'Material group',

    -- EKPO (Purchase Orders)
    EKPO.EBELN  AS EBELN  COMMENT = 'Purchasing document number',
    EKPO.EBELP  AS EBELP  COMMENT = 'Item number',
    EKPO.LIFNR  AS LIFNR  COMMENT = 'Vendor number',
    EKPO.MATNR  AS MATNR  COMMENT = 'Material number',
    EKPO.WERKS  AS WERKS  COMMENT = 'Plant',
    EKPO.STATU  AS STATU  COMMENT = 'Status',
    EKPO.BEDAT  AS BEDAT  COMMENT = 'Purchasing document date',

    -- LIKP (Shipments)
    LIKP.TKNUM    AS TKNUM    COMMENT = 'Shipment number',
    LIKP.TDLNR    AS TDLNR    COMMENT = 'Forwarding agent',
    LIKP.LGORT_SRC AS LGORT_SRC COMMENT = 'Source storage location',
    LIKP.WERKS_DST AS WERKS_DST COMMENT = 'Destination plant',
    LIKP.MATNR    AS MATNR    COMMENT = 'Material number',
    LIKP.STATU    AS STATU    COMMENT = 'Delivery status',
    LIKP.LFDAT    AS LFDAT    COMMENT = 'Delivery date',
    LIKP.WADAT    AS WADAT    COMMENT = 'Goods issue date',

    -- T001W (Plants)
    T001W.WERKS AS WERKS COMMENT = 'Plant',
    T001W.NAME1 AS NAME1 COMMENT = 'Name',
    T001W.REGIO AS REGIO COMMENT = 'Region',

    -- T320 (Storage Locations)
    T320.LGORT AS LGORT COMMENT = 'Storage location',
    T320.LGOBE AS LGOBE COMMENT = 'Storage location description',
    T320.WERKS AS WERKS COMMENT = 'Plant',

    -- STPO (BOM)
    STPO.STLNR AS STLNR COMMENT = 'Bill of material',
    STPO.IDNRK AS IDNRK COMMENT = 'BOM component',

    -- LFB1 (Contracts)
    LFB1.LIFNR AS LIFNR COMMENT = 'Vendor number',
    LFB1.VKONT AS VKONT COMMENT = 'Contract account',
    LFB1.VTART AS VTART COMMENT = 'Contract type',
    LFB1.DTEND AS DTEND COMMENT = 'Validity end date',

    -- QALS (Inspections)
    QALS.PRUEFLOS AS PRUEFLOS COMMENT = 'Inspection lot',
    QALS.MATNR    AS MATNR    COMMENT = 'Material number',
    QALS.VCODE    AS VCODE    COMMENT = 'Usage decision code',

    -- LFA2 (Carriers)
    LFA2.TDLNR AS TDLNR COMMENT = 'Forwarding agent',
    LFA2.NAME1 AS NAME1 COMMENT = 'Name',
    LFA2.VSART AS VSART COMMENT = 'Shipping type',

    -- BSEG (Accounting Documents)
    BSEG.BELNR AS BELNR COMMENT = 'Document number',
    BSEG.BUZEI AS BUZEI COMMENT = 'Line item',
    BSEG.EBELN AS EBELN COMMENT = 'Purchasing document number',
    BSEG.LIFNR AS LIFNR COMMENT = 'Vendor number',
    BSEG.HKONT AS HKONT COMMENT = 'GL account',
    BSEG.BSCHL AS BSCHL COMMENT = 'Posting key',
    BSEG.GJAHR AS GJAHR COMMENT = 'Fiscal year',
    BSEG.MONAT AS MONAT COMMENT = 'Fiscal period',
    BSEG.BUDAT AS BUDAT COMMENT = 'Posting date',

    -- COEP (Cost Elements)
    COEP.OBJNR AS OBJNR COMMENT = 'Cost object number',
    COEP.KSTAR AS KSTAR COMMENT = 'Cost element',
    COEP.GJAHR AS GJAHR COMMENT = 'Fiscal year',
    COEP.PERIO AS PERIO COMMENT = 'Period',
    COEP.MATNR AS MATNR COMMENT = 'Material number',

    -- VBAP (Sales Orders)
    VBAP.VBELN AS VBELN COMMENT = 'Sales document',
    VBAP.POSNR AS POSNR COMMENT = 'Item number',
    VBAP.MATNR AS MATNR COMMENT = 'Material number',
    VBAP.KUNNR AS KUNNR COMMENT = 'Customer number',
    VBAP.VKORG AS VKORG COMMENT = 'Sales organization',
    VBAP.ERDAT AS ERDAT COMMENT = 'Created on date',

    -- KONV (Pricing Conditions)
    KONV.KNUMV AS KNUMV COMMENT = 'Condition number',
    KONV.KPOSN AS KPOSN COMMENT = 'Condition item',
    KONV.KSCHL AS KSCHL COMMENT = 'Condition type',
    KONV.MATNR AS MATNR COMMENT = 'Material number',
    KONV.KUNNR AS KUNNR COMMENT = 'Customer number'
  )

  COMMENT = 'SAP production data covering procurement, logistics, finance, and sales'
;
