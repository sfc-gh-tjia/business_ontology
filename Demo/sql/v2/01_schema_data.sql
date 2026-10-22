-- =====================================================================
-- BON Demo V2 — 01: Schema, cloned data, reference (code) tables
-- Isolated from SAP_PRODUCTION (which also hosts the Cortex Sense demo).
-- =====================================================================
USE DATABASE DB_ONTOLOGY_CONTROL_PLANE;

CREATE SCHEMA IF NOT EXISTS SAP_BON_V2
  COMMENT = 'BON demo v2: domain SVs (bare/enriched), governed BON, fair 3-agent benchmark';
USE SCHEMA SAP_BON_V2;

-- Zero-copy clone of the SAP source tables (identical data to V1)
EXECUTE IMMEDIATE $$
DECLARE
  t ARRAY DEFAULT ARRAY_CONSTRUCT('LFA1','LFA2','LFB1','MARA','EKPO','LIKP','T001W','T320',
                                  'STPO','QALS','BSEG','COEP','VBAP','KONV','QUAL_MATRIX');
  i INTEGER DEFAULT 0;
  n VARCHAR;
BEGIN
  FOR i IN 0 TO ARRAY_SIZE(t)-1 DO
    n := t[i];
    EXECUTE IMMEDIATE 'CREATE OR REPLACE TABLE DB_ONTOLOGY_CONTROL_PLANE.SAP_BON_V2.' || n ||
                      ' CLONE DB_ONTOLOGY_CONTROL_PLANE.SAP_PRODUCTION.' || n;
  END FOR;
  RETURN 'cloned ' || ARRAY_SIZE(t);
END;
$$;

-- Reference (code) tables: BON holds one term per code field that points here.
-- New codes arrive via normal ETL into these tables; BON only changes when a rule changes.
CREATE OR REPLACE TABLE T077K (
  KTOKK VARCHAR(10) PRIMARY KEY COMMENT 'Vendor account group code',
  TXT30 VARCHAR(60) COMMENT 'Account group description',
  EXCLUDE_FROM_ACTIVE_COUNT BOOLEAN COMMENT 'TRUE if vendors in this group are excluded from the active supplier count'
) COMMENT = 'Vendor account group reference (code table)' AS
SELECT * FROM VALUES ('ZSTR','Strategic partner',FALSE),('ZSTD','Standard vendor',FALSE),('ZPRB','Probationary vendor',TRUE);

CREATE OR REPLACE TABLE T023T (
  MATKL VARCHAR(5) PRIMARY KEY COMMENT 'Material group code',
  WGBEZ VARCHAR(60) COMMENT 'Material group description'
) COMMENT = 'Material group texts (code table)' AS
SELECT * FROM VALUES ('043','Electronics'),('044','Chemicals'),('045','Metals'),('046','Packaging'),('047','Raw Materials'),('048','Assembly');
