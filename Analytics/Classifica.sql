USE `FilmSphere`;

DROP PROCEDURE IF EXISTS `Classifica`;
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `Classifica`(
    N INT,
    codice_paese CHAR(2),
    tipo_abbonamento VARCHAR(50),
    P INT -- 1 -> Film   2 -> Edizioni
)
BEGIN

    IF p = 1 THEN

        WITH
            FilmVisualizzazioni AS (
                SELECT
                    E.Film,
                    COUNT(*) AS Visualizzazioni
                FROM Visualizzazione V
                INNER JOIN Utente U
                    ON V.Utente = U.Codice
                INNER JOIN Edizione E
                    ON E.ID = V.Edizione
                INNER JOIN IPRange IP
                    ON IP.Inizio <= V.IP AND IP.Fine >= V.IP AND IP.DataInizio <= V.InizioConnessione AND (IP.DataFine IS NULL OR IP.DataFine >= V.InizioConnessione)
                WHERE U.Abbonamento = tipo_abbonamento
                AND IP.Paese = codice_paese
                GROUP BY E.Film
            )
        SELECT
            Film
        FROM FilmVisualizzazioni
        ORDER BY Visualizzazioni DESC
        LIMIT N;

    ELSEIF p = 2 THEN

        WITH
            FilmVisualizzazioni AS (
                SELECT
                    V.Edizione,
                    COUNT(*) AS Visualizzazioni
                FROM Visualizzazione V
                INNER JOIN Utente U
                    ON V.Utente = U.Codice
                INNER JOIN IPRange IP
                    ON IP.Inizio <= V.IP AND IP.Fine >= V.IP AND IP.DataInizio <= V.InizioConnessione AND (IP.DataFine IS NULL OR IP.DataFine >= V.InizioConnessione)
                WHERE U.Abbonamento = tipo_abbonamento
                AND IP.Paese = codice_paese
                GROUP BY V.Edizione
            )
        SELECT
            Edizione
        FROM FilmVisualizzazioni
        ORDER BY Visualizzazioni DESC
        LIMIT N;

    ELSE

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Parametro P non Valido';

    END IF;

END
//
DELIMITER ;