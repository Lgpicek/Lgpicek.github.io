-- ============================================================
--  Esquema de indexación on-chain TRON   ·   Oracle 19c+
--  Autor: Leandro Picek
-- ============================================================

CREATE TABLE tron_block (
    block_num   NUMBER(12)   NOT NULL,
    block_hash  VARCHAR2(64) NOT NULL,
    block_ts    TIMESTAMP    NOT NULL,
    tx_count    NUMBER(6)    DEFAULT 0 NOT NULL,
    indexed_at  TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_tron_block PRIMARY KEY (block_num)
);

CREATE TABLE tron_tx (
    tx_id       VARCHAR2(64) NOT NULL,
    block_num   NUMBER(12)   NOT NULL,
    from_addr   VARCHAR2(34) NOT NULL,
    to_addr     VARCHAR2(34),
    tx_type     VARCHAR2(30) NOT NULL,
    amount_trx  NUMBER(20,6) DEFAULT 0,
    fee_trx     NUMBER(20,6) DEFAULT 0,
    tx_ts       TIMESTAMP    NOT NULL,
    CONSTRAINT pk_tron_tx       PRIMARY KEY (tx_id),
    CONSTRAINT fk_tron_tx_block FOREIGN KEY (block_num)
        REFERENCES tron_block (block_num)
);

CREATE TABLE tron_trc20_transfer (
    transfer_id   NUMBER       GENERATED ALWAYS AS IDENTITY,
    tx_id         VARCHAR2(64) NOT NULL,
    contract_addr VARCHAR2(34) NOT NULL,   -- USDT: TR7NHqjeKQ...
    token_symbol  VARCHAR2(16),
    from_addr     VARCHAR2(34) NOT NULL,
    to_addr       VARCHAR2(34) NOT NULL,
    amount        NUMBER(38,6) NOT NULL,
    CONSTRAINT pk_trc20    PRIMARY KEY (transfer_id),
    CONSTRAINT fk_trc20_tx FOREIGN KEY (tx_id) REFERENCES tron_tx (tx_id)
);

CREATE TABLE tron_wallet (
    address     VARCHAR2(34) NOT NULL,
    first_seen  TIMESTAMP,
    last_seen   TIMESTAMP,
    tx_total    NUMBER       DEFAULT 0,
    aml_score   NUMBER(3)    DEFAULT 0,
    risk_level  VARCHAR2(10) DEFAULT 'BAJO',
    CONSTRAINT pk_tron_wallet PRIMARY KEY (address)
);

CREATE TABLE aml_flag (
    flag_id     NUMBER        GENERATED ALWAYS AS IDENTITY,
    address     VARCHAR2(34)  NOT NULL,
    rule_code   VARCHAR2(30)  NOT NULL,
    score_delta NUMBER(3)     NOT NULL,
    detail      VARCHAR2(200),
    flagged_at  TIMESTAMP     DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_aml_flag PRIMARY KEY (flag_id)
);

-- Índices para consultas analíticas de alta cardinalidad
CREATE INDEX ix_tx_from   ON tron_tx (from_addr, tx_ts);
CREATE INDEX ix_tx_to     ON tron_tx (to_addr, tx_ts);
CREATE INDEX ix_trc20_to  ON tron_trc20_transfer (to_addr);
CREATE INDEX ix_trc20_sym ON tron_trc20_transfer (token_symbol, amount);
