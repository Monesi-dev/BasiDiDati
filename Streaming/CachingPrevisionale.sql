USE `FilmSphere`;

DROP PROCEDURE IF EXISTS `CachingPrevisionale`;
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `CachingPrevisionale`(
    X INT,
    M INT,
    N INT
)
BEGIN

    -- 1) Per ogni Utente si considera il Paese dal quale si connette di piu' e dal Paese gli N Server piu' vicini
    -- 2) Per ogni coppia Utente, Paese si considerano gli M File con probabilità maggiore di essere guardati, ciascuno con la probabilità di essere guardato
    -- 3) Si raggruppa in base al Server e ad ogni File, sommando, per ogni Server-File la probabilit`a che sia guardato dall’Utente moltiplicata
    --    per un numero che scala in maniera decrescente in base al ValoreDistanza tra Paese e Server
    -- 4) Si restituiscono le prime X coppie Server-File con somma maggiore per le quali non esiste gi`a un P.o.P.
    WITH
        UtentePaeseVolte AS (
            SELECT
                Utente,
                Paese,
                COUNT(*) AS Volte
            FROM (
                SELECT
                    Utente,
                    Paese
                FROM Visualizzazione V
                INNER JOIN IPRange IP
                    ON IP.Inizio <= V.IP AND IP.Fine >= V.IP AND IP.DataInizio <= V.InizioConnessione AND (IP.DataFine IS NULL OR IP.DataFine >= V.InizioConnessione)
            ) AS T
            GROUP BY Utente, Paese
        ),
        UtentePaesePiuFrequente AS (
            SELECT
                Utente,
                Paese
            FROM UtentePaeseVolte UPV
            WHERE UPV.Volte = (
                SELECT MAX(UPV2.Volte)
                FROM UtentePaeseVolte UPV2
                WHERE UPV2.Utente = UPV.Utente
            )
        ),
        RankingPaeseServer AS (
            SELECT
                Server,
                Paese,
                RANK() OVER(PARTITION BY Paese ORDER BY ValoreDistanza) AS rk
            FROM DistanzaPrecalcolata
        ),
        ServerTargetPerPaese AS (
            SELECT
                Server,
                Paese
            FROM RankingPaeseServer
            WHERE rk <= N
        ),
        UtentePaeseServer AS (
            SELECT
                UP.Utente,
                UP.Paese,
                SP.Server,
                DP.ValoreDistanza
            FROM UtentePaesePiuFrequente UP
            INNER JOIN ServerTargetPerPaese SP
                USING(Paese)
            INNER JOIN DistanzaPrecalcolata DP
                ON DP.Server = SP.Server AND DP.Paese = UP.Paese
        ),

        -- 2) Per ogni coppia Utente, Paese si considerano gli M File con probabilità maggiore di essere guardati, ciascuno con la probabilità di essere guardato
        FilmRatingUtente AS (
            SELECT
                F.ID,
                U.Codice,
                RatingUtente(F.ID, U.Codice) AS Rating
            FROM Film F
            NATURAL JOIN Utente U
        ),
        10FilmUtente AS (
            SELECT
                ID AS Film,
                Codice AS Utente,
                (CASE
                    WHEN rk = 1 THEN 30.0
                    WHEN rk = 2 THEN 22.0
                    WHEN rk = 3 THEN 11.0
                    WHEN rk = 4 THEN 9.0
                    WHEN rk = 5 THEN 8.0
                    WHEN rk = 6 THEN 6.0
                    WHEN rk = 7 THEN 5.0
                    WHEN rk = 8 THEN 4.0
                    WHEN rk = 9 THEN 3.0
                    WHEN rk = 10 THEN 2.0
                END) AS Probabilita
            FROM (
                SELECT
                    ID,
                    Codice,
                    RANK() OVER(PARTITION BY Codice ORDER BY Rating DESC ) AS rk
                FROM FilmRatingUtente
            ) AS T
            WHERE rk <= 10
        ),
        FilmFile AS (
            SELECT
                F.ID AS Film,
                FI.ID AS File,
                F2FI.N AS NumeroFile
            FROM Film AS F
            INNER JOIN Edizione E
                ON E.Film = F.ID
            INNER JOIN File FI
                ON FI.Edizione = E.ID
            INNER JOIN (
                -- Tabella avente Film e numero di File ad esso associati
                SELECT
                    F1.ID AS Film,
                    COUNT(*) AS N
                FROM Film AS F1
                INNER JOIN Edizione E1
                    ON E1.Film = F1.ID
                INNER JOIN File FI1
                    ON FI1.Edizione = E1.ID
                GROUP BY F1.ID
            ) AS F2FI
                ON F2FI.Film = F.ID

        ),
        FileUtente AS (
            SELECT
                Utente,
                File,
                Probabilita / NumeroFile AS Probabilita
            FROM 10FilmUtente
            NATURAL JOIN FilmFile
        ),
        MFilePerUtente AS (
            SELECT
                Utente,
                File,
                Probabilita
            FROM (
                SELECT
                    *,
                    RANK() OVER(PARTITION BY Utente ORDER BY Probabilita DESC) AS rk
                FROM FileUtente
            ) AS T
            WHERE rk <= M
        ),

        ServerFile AS (
            SELECT
                File,
                Server,
                SUM(Probabilita * (1 + 1 / ValoreDistanza)) AS Importanza   -- MODIFICA VALORI PER QUESTA ESPRESSIONE
            FROM MFilePerUtente FU
            INNER JOIN UtentePaeseServer SU
                USING(Utente)
            GROUP BY File, Server
        )
    SELECT
        File,
        Server
    FROM ServerFile SF
    WHERE NOT EXISTS (
        SELECT *
        FROM PoP
        WHERE PoP.Server = SF.Server AND PoP.File = SF.File
    )
    ORDER BY Importanza DESC
    LIMIT X;

END
//
DELIMITER ;
