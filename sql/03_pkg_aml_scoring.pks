CREATE OR REPLACE PACKAGE pkg_aml_scoring AS

    -- Recalcula el score de las wallets tocadas por un bloque
    PROCEDURE refresh_wallets (p_block_num IN NUMBER);

    -- Score puntual de una address (0 = limpio, 100 = riesgo máximo)
    FUNCTION score_wallet (p_address IN VARCHAR2) RETURN NUMBER;

    -- Nivel de riesgo a partir del score
    FUNCTION risk_level (p_score IN NUMBER) RETURN VARCHAR2;

END pkg_aml_scoring;
/
