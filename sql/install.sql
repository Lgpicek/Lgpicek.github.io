-- ============================================================
--  TRON On-Chain Indexer & AML Scoring  ·  Oracle PL/SQL
--  Script de instalación completo (orden de dependencias)
--  Autor: Leandro Picek
--
--  Uso (SQL*Plus / SQLcl, desde esta carpeta):
--      sqlplus usuario/clave@//host:1521/servicio @install.sql
--
--  Probado contra Oracle Database 19c (compatible 12c+ por IDENTITY,
--  JSON_TABLE y JSON_VALUE ... RETURNING).
--
--  Los specs de ambos packages se crean ANTES que los bodies para
--  resolver la referencia cruzada (el body del indexer llama a
--  PKG_AML_SCORING.refresh_wallets).
-- ============================================================

SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

PROMPT === 1/5  Esquema (tablas e índices) ===========================
@@01_tron_schema.sql

PROMPT === 2/5  Spec  PKG_TRON_INDEXER =============================
@@02_pkg_tron_indexer.pks

PROMPT === 3/5  Spec  PKG_AML_SCORING ==============================
@@03_pkg_aml_scoring.pks

PROMPT === 4/5  Body  PKG_TRON_INDEXER =============================
@@04_pkg_tron_indexer.pkb

PROMPT === 5/5  Body  PKG_AML_SCORING ==============================
@@05_pkg_aml_scoring.pkb

PROMPT === Verificación de objetos inválidos =======================
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name IN ('TRON_BLOCK','TRON_TX','TRON_TRC20_TRANSFER',
                       'TRON_WALLET','AML_FLAG',
                       'PKG_TRON_INDEXER','PKG_AML_SCORING')
ORDER  BY object_type, object_name;

PROMPT === Instalación finalizada ==================================
