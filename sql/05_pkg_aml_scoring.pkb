CREATE OR REPLACE PACKAGE BODY pkg_aml_scoring AS

    -- Umbrales de las reglas (parametrizables vía Custom Settings)
    c_velocity_limit CONSTANT NUMBER := 100;   -- tx por hora
    c_structuring    CONSTANT NUMBER := 9999;  -- USDT, bajo el umbral de reporte

    FUNCTION risk_level (p_score IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE
                   WHEN p_score >= 70 THEN 'ALTO'
                   WHEN p_score >= 40 THEN 'MEDIO'
                   ELSE 'BAJO'
               END;
    END risk_level;

    -- Registra la regla disparada sin abortar la transacción principal
    PROCEDURE add_flag (p_addr   IN VARCHAR2, p_rule  IN VARCHAR2,
                        p_delta  IN NUMBER,   p_detail IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO aml_flag (address, rule_code, score_delta, detail)
        VALUES (p_addr, p_rule, p_delta, p_detail);
        COMMIT;
    END add_flag;

    FUNCTION score_wallet (p_address IN VARCHAR2) RETURN NUMBER IS
        l_score     NUMBER := 0;
        l_tx_per_h  NUMBER;
        l_smurf     NUMBER;
        l_blacklist NUMBER;
    BEGIN
        -- 1) Velocidad: ráfaga de transacciones por hora
        SELECT COUNT(*) / GREATEST(
                   EXTRACT(HOUR FROM (MAX(tx_ts) - MIN(tx_ts))) + 1, 1)
        INTO   l_tx_per_h
        FROM   tron_tx
        WHERE  from_addr = p_address
        AND    tx_ts >= SYSTIMESTAMP - INTERVAL '24' HOUR;

        IF l_tx_per_h > c_velocity_limit THEN
            l_score := l_score + 25;
            add_flag(p_address, 'HIGH_VELOCITY', 25,
                     'Velocidad ' || ROUND(l_tx_per_h) || ' tx/h');
        END IF;

        -- 2) Structuring: montos repetidos bajo el umbral de reporte
        SELECT COUNT(*)
        INTO   l_smurf
        FROM   tron_trc20_transfer
        WHERE  from_addr = p_address
        AND    amount BETWEEN c_structuring - 100 AND c_structuring;

        IF l_smurf >= 3 THEN
            l_score := l_score + 30;
            add_flag(p_address, 'STRUCTURING', 30,
                     l_smurf || ' transferencias en patron de structuring');
        END IF;

        -- 3) Exposición a wallets ya marcadas de alto riesgo
        SELECT COUNT(DISTINCT t.to_addr)
        INTO   l_blacklist
        FROM   tron_trc20_transfer t
        JOIN   tron_wallet w ON w.address = t.to_addr
        WHERE  t.from_addr = p_address
        AND    w.risk_level = 'ALTO';

        IF l_blacklist > 0 THEN
            l_score := l_score + 35;
            add_flag(p_address, 'BLACKLIST_EXPOSURE', 35,
                     'Interaccion con ' || l_blacklist || ' wallet(s) de alto riesgo');
        END IF;

        RETURN LEAST(l_score, 100);
    END score_wallet;

    PROCEDURE refresh_wallets (p_block_num IN NUMBER) IS
        CURSOR c_addr IS
            SELECT DISTINCT from_addr AS address
            FROM   tron_tx
            WHERE  block_num = p_block_num;
        l_score NUMBER;
    BEGIN
        FOR r IN c_addr LOOP
            l_score := score_wallet(r.address);
            MERGE INTO tron_wallet w
            USING (SELECT r.address AS address FROM dual) src
            ON (w.address = src.address)
            WHEN MATCHED THEN
                UPDATE SET w.aml_score  = l_score,
                           w.risk_level = risk_level(l_score),
                           w.last_seen  = SYSTIMESTAMP
            WHEN NOT MATCHED THEN
                INSERT (address, aml_score, risk_level, first_seen, last_seen)
                VALUES (src.address, l_score, risk_level(l_score),
                        SYSTIMESTAMP, SYSTIMESTAMP);
        END LOOP;
    END refresh_wallets;

END pkg_aml_scoring;
/
