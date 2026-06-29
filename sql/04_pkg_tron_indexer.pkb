CREATE OR REPLACE PACKAGE BODY pkg_tron_indexer AS

    -- Inserta el bloque de forma idempotente y devuelve su número
    PROCEDURE upsert_block (p_block_json IN CLOB, p_block_num OUT NUMBER) IS
    BEGIN
        p_block_num := JSON_VALUE(p_block_json, '$.number' RETURNING NUMBER);

        MERGE INTO tron_block b
        USING (
            SELECT jt.block_num, jt.block_hash, jt.block_ts, jt.tx_count
            FROM   JSON_TABLE(
                       p_block_json, '$'
                       COLUMNS (
                           block_num  NUMBER       PATH '$.number',
                           block_hash VARCHAR2(64) PATH '$.hash',
                           block_ts   NUMBER       PATH '$.timestamp',
                           tx_count   NUMBER       PATH '$.txCount'
                       )
                   ) jt
        ) src
        ON (b.block_num = src.block_num)
        WHEN NOT MATCHED THEN
            INSERT (block_num, block_hash, block_ts, tx_count)
            VALUES (src.block_num, src.block_hash,
                    TIMESTAMP '1970-01-01 00:00:00'
                        + NUMTODSINTERVAL(src.block_ts/1000, 'SECOND'),
                    src.tx_count);
    END upsert_block;

    PROCEDURE ingest_block (p_block_json IN CLOB) IS
        l_block_num tron_block.block_num%TYPE;
        l_transfers t_transfer_tab;
    BEGIN
        upsert_block(p_block_json, l_block_num);

        -- Parseo de los transfers TRC-20 del bloque
        SELECT jt.tx_id, jt.contract_addr, jt.token_symbol,
               jt.from_addr, jt.to_addr, jt.amount
        BULK COLLECT INTO l_transfers
        FROM   JSON_TABLE(
                   p_block_json, '$.transfers[*]'
                   COLUMNS (
                       tx_id         VARCHAR2(64) PATH '$.txID',
                       contract_addr VARCHAR2(34) PATH '$.contract',
                       token_symbol  VARCHAR2(16) PATH '$.symbol',
                       from_addr     VARCHAR2(34) PATH '$.from',
                       to_addr       VARCHAR2(34) PATH '$.to',
                       amount        NUMBER       PATH '$.value'
                   )
               ) jt;

        -- Carga masiva: un solo viaje al motor SQL
        FORALL i IN 1 .. l_transfers.COUNT
            INSERT INTO tron_trc20_transfer
                (tx_id, contract_addr, token_symbol,
                 from_addr, to_addr, amount)
            VALUES
                (l_transfers(i).tx_id,        l_transfers(i).contract_addr,
                 l_transfers(i).token_symbol, l_transfers(i).from_addr,
                 l_transfers(i).to_addr,      l_transfers(i).amount);

        -- Refresca el scoring AML de las wallets del bloque
        pkg_aml_scoring.refresh_wallets(l_block_num);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END ingest_block;

    FUNCTION get_wallet_summary (p_address IN VARCHAR2)
        RETURN SYS_REFCURSOR IS
        l_cur SYS_REFCURSOR;
    BEGIN
        OPEN l_cur FOR
            SELECT w.address, w.tx_total, w.aml_score, w.risk_level,
                   NVL(SUM(CASE WHEN t.to_addr   = w.address
                                THEN t.amount END), 0) AS usdt_in,
                   NVL(SUM(CASE WHEN t.from_addr = w.address
                                THEN t.amount END), 0) AS usdt_out
            FROM   tron_wallet w
            LEFT   JOIN tron_trc20_transfer t
                   ON t.to_addr = w.address OR t.from_addr = w.address
            WHERE  w.address = p_address
            GROUP  BY w.address, w.tx_total, w.aml_score, w.risk_level;
        RETURN l_cur;
    END get_wallet_summary;

    FUNCTION token_volume (p_symbol IN VARCHAR2,
                           p_hours  IN NUMBER DEFAULT 24)
        RETURN NUMBER IS
        l_total NUMBER;
    BEGIN
        SELECT NVL(SUM(t.amount), 0)
        INTO   l_total
        FROM   tron_trc20_transfer t
        JOIN   tron_tx x ON x.tx_id = t.tx_id
        WHERE  t.token_symbol = p_symbol
        AND    x.tx_ts >= SYSTIMESTAMP - NUMTODSINTERVAL(p_hours, 'HOUR');
        RETURN l_total;
    END token_volume;

END pkg_tron_indexer;
/
