CREATE OR REPLACE PACKAGE pkg_tron_indexer AS

    -- Tipos para carga masiva (bulk binding)
    TYPE t_transfer_rec IS RECORD (
        tx_id         tron_trc20_transfer.tx_id%TYPE,
        contract_addr tron_trc20_transfer.contract_addr%TYPE,
        token_symbol  tron_trc20_transfer.token_symbol%TYPE,
        from_addr     tron_trc20_transfer.from_addr%TYPE,
        to_addr       tron_trc20_transfer.to_addr%TYPE,
        amount        tron_trc20_transfer.amount%TYPE
    );
    TYPE t_transfer_tab IS TABLE OF t_transfer_rec;

    -- Ingesta de un bloque ya obtenido vía TronWeb (JSON crudo)
    PROCEDURE ingest_block (p_block_json IN CLOB);

    -- Resumen de una wallet para el Explorer
    FUNCTION get_wallet_summary (p_address IN VARCHAR2)
        RETURN SYS_REFCURSOR;

    -- Volumen TRC-20 de un token en una ventana temporal
    FUNCTION token_volume (
        p_symbol IN VARCHAR2,
        p_hours  IN NUMBER DEFAULT 24
    ) RETURN NUMBER;

END pkg_tron_indexer;
/
