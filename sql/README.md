# TRON On-Chain Indexer & AML Scoring — Oracle PL/SQL

Código PL/SQL de la demo [`tron-demo.html`](../tron-demo.html), listo para abrir o
ejecutar en una instancia Oracle real. El objetivo es indexar transacciones de la
blockchain **TRON** (TRX y tokens TRC-20 como USDT) usando **TronWeb** como fuente
on-chain y **Oracle/PL/SQL** como motor de procesamiento, analítica y compliance (AML).

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `01_tron_schema.sql`        | DDL: tablas (`TRON_BLOCK`, `TRON_TX`, `TRON_TRC20_TRANSFER`, `TRON_WALLET`, `AML_FLAG`), constraints e índices. |
| `02_pkg_tron_indexer.pks`   | Spec de `PKG_TRON_INDEXER` (tipos RECORD/TABLE, `ingest_block`, `get_wallet_summary`, `token_volume`). |
| `03_pkg_aml_scoring.pks`    | Spec de `PKG_AML_SCORING` (`refresh_wallets`, `score_wallet`, `risk_level`). |
| `04_pkg_tron_indexer.pkb`   | Body del indexer: `JSON_TABLE` + `BULK COLLECT`/`FORALL` + `MERGE` idempotente + `SYS_REFCURSOR`. |
| `05_pkg_aml_scoring.pkb`    | Body del motor AML: reglas con `CONSTANT`, `PRAGMA AUTONOMOUS_TRANSACTION`, cursor explícito y `MERGE`. |
| `install.sql`               | Ejecuta todo en el orden correcto de dependencias. |

## Instalación

Desde esta carpeta, con SQL\*Plus o SQLcl:

```sql
sqlplus usuario/clave@//host:1521/servicio @install.sql
```

Los **specs** de ambos packages se compilan antes que los **bodies** para resolver la
referencia cruzada (el body de `PKG_TRON_INDEXER` invoca
`PKG_AML_SCORING.refresh_wallets`).

## Conceptos PL/SQL que muestra

- Carga masiva eficiente: `BULK COLLECT` + `FORALL` (un solo round-trip al motor SQL).
- Parsing de JSON nativo: `JSON_TABLE` y `JSON_VALUE ... RETURNING`.
- Idempotencia con `MERGE` (re-procesar un bloque no duplica datos).
- `SYS_REFCURSOR` para exponer resultados a la capa de aplicación / ORDS.
- Registro de auditoría sin abortar la transacción principal: `PRAGMA AUTONOMOUS_TRANSACTION`.
- Tipos `RECORD` / `TABLE OF ... %TYPE`, cursores explícitos, manejo de excepciones.
- Analítica con funciones window (`RANK () OVER`, `LISTAGG`) — ver la sección
  *Analítica SQL* de la demo.

## Compatibilidad

Probado contra **Oracle Database 19c**. Requiere 12c+ por `GENERATED ALWAYS AS IDENTITY`,
`JSON_TABLE` y `JSON_VALUE ... RETURNING`.

> Datos y volúmenes de la demo son ilustrativos. En producción, la ingesta se dispara
> desde TronWeb hacia un endpoint **ORDS** (handler PL/SQL) o un job `DBMS_SCHEDULER`
> de catch-up, como se describe en la sección *Arquitectura* de la demo.
