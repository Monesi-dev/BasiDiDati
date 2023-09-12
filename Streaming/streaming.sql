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


DROP FUNCTION IF EXISTS `MathMap`;
DROP FUNCTION IF EXISTS `StrListContains`;
DROP FUNCTION IF EXISTS `CalcolaDelta`;
DROP PROCEDURE IF EXISTS `MigliorServer`;
DROP PROCEDURE IF EXISTS `TrovaMigliorServer`;

DELIMITER $$

CREATE PROCEDURE `MigliorServer` (

    -- Dati sull'utente e la connessione
    IN id_utente VARCHAR(100), -- Codice di Utente
    IN id_edizione INT, -- ID di Edizione che si intende guardare
    IN ip_connessione INT UNSIGNED, -- Indirizzo IP4 della connessione

    -- Dati su capacita' dispositivo client e potenza della sua connessione
    IN MaxBitRate FLOAT,
    IN MaxRisoluz BIGINT,

    -- Liste di encoding video e audio supportati dal client, separati da ','
    IN ListaVideoEncodings VARCHAR(256), -- NULL significa qualunque encoding e' supportato
    IN ListaAudioEncodings VARCHAR(256), -- NULL significa qualunque encoding e' supportato

    -- Parametri restituiti
    OUT FileID INT, -- ID del File da guardare
    OUT ServerID INT -- Server dove tale File e' presente
) BEGIN
    DECLARE paese_utente CHAR(2) DEFAULT '??';
    DECLARE abbonamento_utente VARCHAR(50) DEFAULT NULL;
    DECLARE max_definizione BIGINT DEFAULT NULL;

    IF id_utente IS NULL OR id_edizione IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Parametri NULL non consentiti';
    END IF;


    SELECT A.`Tipo`, A.`Definizione`
        INTO abbonamento_utente, max_definizione
    FROM `Abbonamento` A
        INNER JOIN `Utente` U ON `U`.`Abbonamento` = A.`Tipo`
    WHERE U.`Codice` = id_utente;

    IF abbonamento_utente IS NULL THEN
         SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Utente non trovato';
    END IF;

    IF EXISTS (
        SELECT *
        FROM `Esclusione`
            INNER JOIN `GenereFilm` USING (`Genere`)
            INNER JOIN `Edizione` USING (`Film`)
        WHERE `ID` = id_edizione AND `Abbonamento` = abbonamento_utente) THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Contenuto non disponibile nel tuo piano di abbonamento!';
    END IF;

    -- Calcolo il Paese dai Range
    SET paese_utente = Ip2Paese(ip_connessione);

    IF EXISTS (
        SELECT *
        FROM `Restrizione` r
        WHERE r.`Edizione` = id_edizione AND r.`Paese` = paese_utente) THEN

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Contenuto non disponibile nella tua regione!';
    END IF;

    CALL `TrovaMigliorServer` (
        id_edizione, paese_utente,
        max_definizione, MaxBitRate, MaxRisoluz,
        ListaVideoEncodings, ListaAudioEncodings, NULL, @File, @Server, @Score);
    SET FileID = @File;
    SET ServerID = @Server;
    -- SELECT @File, @Server, @Score, paese_utente, max_definizione;
    -- @Score non viene restituito
END $$

CREATE PROCEDURE `TrovaMigliorServer` (

    -- Dati sulla connessione
    IN id_edizione INT, -- ID di Edizione che si intende guardare
    IN paese_utente CHAR(2), -- Paese dell'Utente
    IN MaxRisoluzAbbonamento BIGINT,

    -- Dati su capacita' dispositivo client e potenza della sua connessione
    IN MaxBitRate FLOAT, -- NULL significa ricercare il minor BitRate possibile
    IN MaxRisoluz BIGINT, -- NULL significa ricercare la minor Risoluzione possibile

    -- Liste di encoding video e audio supportati dal client, separati da ','
    IN ListaVideoEncodings VARCHAR(256), -- NULL significa qualunque encoding e' supportato
    IN ListaAudioEncodings VARCHAR(256), -- NULL significa qualunque encoding e' supportato

    IN ServerDaEscludere VARCHAR(32), -- Lista di ID di Server che per vari motivi vanno esclusi

    -- Parametri restituiti
    OUT FileID INT, -- ID del File da guardare
    OUT ServerID INT, -- Server dove tale File e' presente
    OUT Score INT -- Punteggio della scelta
) BEGIN
    DECLARE max_definizione BIGINT DEFAULT NULL;
    DECLARE wRis FLOAT DEFAULT 5.0;
    DECLARE wRate FLOAT DEFAULT 3.0;
    DECLARE wPos FLOAT DEFAULT 12.0;
    DECLARE wCarico FLOAT DEFAULT 10.0;


    -- Prima di calcolare il Server migliore individuo le caratteristiche che deve avere il File

    SET max_definizione = IFNULL(
        LEAST(MaxRisoluz, IFNULL(MaxRisoluzAbbonamento, MaxRisoluz)),
        0);

    -- SELECT max_definizione, MaxBitRate, ListaAudioEncodings, ListaVideoEncodings, ServerDaEscludere, paese_utente;

    WITH `FileDisponibili` AS (
        SELECT
            F.`ID`,
            CalcolaDelta(max_definizione, F.`Risoluzione`) AS "DeltaRis",
            CalcolaDelta(MaxBitRate, F.`BitRate`) AS "DeltaRate"
        FROM `File` F
            INNER JOIN Edizione E ON E.`ID` = F.`Edizione`
        WHERE
            E.`ID` = id_edizione AND
            (ListaAudioEncodings IS NULL OR StrListContains(ListaAudioEncodings, F.`FamigliaAudio`)) AND
            (ListaVideoEncodings IS NULL OR StrListContains(ListaVideoEncodings, F.`FamigliaVideo`))
    ), `ServerDisponibili` AS (
        SELECT S.`ID`, S.`CaricoAttuale`, S.`MaxConnessioni`
        FROM `Server` S
        WHERE S.`CaricoAttuale` < 1 AND NOT StrListContains(ServerDaEscludere, S.`ID`)
    ), `FileServerScore` AS (
        SELECT
            F.`ID`,
            P.`Server`,
            MathMap(F.`DeltaRis`, 0.0, 16384, 0, wRis) AS "ScoreRis",
            MathMap(F.`DeltaRate`, 0.0, 1.4 * 1024 * 1024 * 1024, 0, wRate) AS "ScoreRate",
            MathMap(D.`ValoreDistanza`, 0.0, 40000, 0, wPos) AS "ScoreDistanza",
            MathMap(S.`CaricoAttuale`, 0.0, S.`MaxConnessioni`, 0, wCarico) AS "ScoreCarico"
        FROM `FileDisponibili` F
            INNER JOIN `PoP` P ON P.`File` = F.`ID`
            INNER JOIN `DistanzaPrecalcolata` D USING(`Server`)
            INNER JOIN `ServerDisponibili` S ON S.`ID` = P.`Server`
        WHERE D.`Paese` = paese_utente
    ), `Scelta` AS (
        SELECT
            F.`ID`, F.`Server`,
            (F.ScoreRis + F.ScoreRate + F.ScoreDistanza + F.ScoreCarico) AS "Score"
        FROM `FileServerScore` F
        ORDER BY "Score" ASC -- Minore e' lo Score migliore e' la scelta
        LIMIT 1
    )
    SELECT S.`ID`, S.`Server`, S.`Score` INTO FileID, ServerID, Score
    FROM `Scelta` S;
END $$

CREATE FUNCTION `MathMap`(
    X FLOAT,
    inMin FLOAT,
    inMax FLOAT,
    outMin FLOAT,
    outMax FLOAT
)
RETURNS FLOAT
DETERMINISTIC
BEGIN
    RETURN outMin + (outMax - outMin) * (x - inMin) / (inMax - inMin);
END $$

CREATE FUNCTION `CalcolaDelta`(
    Max FLOAT,
    Valore FLOAT
)
RETURNS FLOAT
DETERMINISTIC
BEGIN
    IF Max IS NULL THEN
        RETURN IF (
            Valore < 0.0,
            Valore * (-1),
            2.0 * Valore
        );
    END IF;

    RETURN IF (
        Max > Valore,
        Max - Valore,
        2.0 * (Valore - Max)
    );
END $$

CREATE FUNCTION `StrListContains` (
    `Pagliaio` VARCHAR(256),
    `Ago` VARCHAR(10)
)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE PagliaioRidotto VARCHAR(256);
    SET PagliaioRidotto = Pagliaio;

    IF Pagliaio IS NULL OR LENGTH(Pagliaio) = 0 THEN
        RETURN FALSE;
    END IF;

    WHILE PagliaioRidotto <> '' DO

        IF TRIM(LOWER(SUBSTRING_INDEX(PagliaioRidotto, ',', 1))) = TRIM(LOWER(`Ago`)) THEN
            -- Ignoro gli spazi e il CASE della stringa: gli spazi creare dei falsi negativi,
            -- mentre la stringa Ago potrebbe venire inviata con case dipendenti dalla piattaforma del client
            RETURN TRUE;
        END IF;

        IF LOCATE(',', PagliaioRidotto) > 0 THEN
            SET PagliaioRidotto = SUBSTRING(PagliaioRidotto, LOCATE(',', PagliaioRidotto) + 1);
        ELSE
            SET PagliaioRidotto = '';
        END IF;

    END WHILE;

    RETURN FALSE;
END $$

DELIMITER ;


CREATE OR REPLACE VIEW `ServerConCarico` AS
    SELECT S.*, (S.`CaricoAttuale` / S.`MaxConnessioni`) AS "CaricoPercentuale"
    FROM `Server` S;

-- Materialized view che contiene i suggerimenti di Erogazioni da spostare e dove spostarle
-- Non è presente nell'ER perché i suoi volumi sono talmente piccoli da essere insignificante in confronto alle altre
-- La tabella è vista più come un sistema di comunicazione tra il DBMS che individua i client da spostare e i server (fisici)\
-- che devono sapere chi spostare
CREATE TABLE IF NOT EXISTS `ModificaErogazioni`
(
    -- Riferimenti a Erogazione
    `Server` INT NOT NULL,
    `IP` INT UNSIGNED NOT NULL,
    `InizioConnessione` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `Utente` VARCHAR(100) NOT NULL,
    `Edizione` INT NOT NULL,
    `Timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Alternativa
    `Alternativa` INT NOT NULL,
    `File` INT NOT NULL,
    `Punteggio` FLOAT NOT NULL,

    PRIMARY KEY(`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`),
    FOREIGN KEY (`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`)
        REFERENCES `Erogazione`(`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`)
            ON UPDATE CASCADE ON DELETE CASCADE,

    FOREIGN KEY(`Server`) REFERENCES `Server`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY(`Alternativa`) REFERENCES `Server`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY(`File`) REFERENCES `File`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE
) Engine=InnoDB;


DROP PROCEDURE IF EXISTS `RibilanciamentoCarico`;
DROP EVENT IF EXISTS `RibilanciamentoCaricoEvent`;

DELIMITER $$

CREATE PROCEDURE `RibilanciamentoCarico` ()
ribilancia_body:BEGIN
    -- Variables declaration
    DECLARE `MaxCarichi` FLOAT DEFAULT 0.0;
    DECLARE `MediaCarichi` FLOAT DEFAULT NULL;
    DECLARE fetching BOOLEAN DEFAULT TRUE;

    -- Utente, Server e Visualizzazione
    DECLARE server_id INT DEFAULT NULL;
    DECLARE edizione_id INT DEFAULT NULL;
    DECLARE ip_utente INT UNSIGNED DEFAULT NULL;
    DECLARE paese_utente CHAR(2) DEFAULT '??';
    DECLARE codice_utente VARCHAR(100) DEFAULT NULL;
    DECLARE max_definiz BIGINT DEFAULT 0;
    DECLARE timestamp_vis TIMESTAMP DEFAULT NULL;
    DECLARE timestamp_conn TIMESTAMP DEFAULT NULL;

    -- Server da escludere (perche' carichi)
    DECLARE server_da_escludere VARCHAR(32) DEFAULT NULL;

    -- Cursor declaration
    DECLARE cur CURSOR FOR
        WITH `ServerPiuCarichi` AS (
            SELECT S.`ID`
            FROM `ServerConCarico` S
            WHERE S.`CaricoPercentuale` >= (SELECT AVG(`CaricoPercentuale`) FROM `ServerConCarico`)
            ORDER BY S.`CaricoPercentuale` DESC
            LIMIT 3
        ), `ServerErogazioni` AS (
            SELECT E.*, TIMESTAMPDIFF(SECOND, CURRENT_TIMESTAMP, E.`TimeStamp`) AS "TempoTrascorso"
            FROM `ServerPiuCarichi` S
                INNER JOIN `Erogazione` E ON S.`ID` = E.`Server`
            WHERE TIMESTAMPDIFF(MINUTE, E.`InizioErogazione`, CURRENT_TIMESTAMP) > 29
        ), `ErogazioniNonAlTermine` AS (
            SELECT E.*, E.`InizioConnessione` AS "Inizio", (Ed.`Lunghezza` - E.TempoTrascorso) AS "TempoMancante"
            FROM `ServerErogazioni` E
                INNER JOIN `Edizione` Ed ON E.`Edizione` = Ed.`ID`
                -- Calcolo quanto dovrebbe mancare al termine della visione e controllo che sia sotto i 10 min
            HAVING "TempoMancante" <= 600
        )
        SELECT
            E.`Server`, E.`Edizione`, E.`IP`,
            E.`Utente`, A.`Definizione`,
            E.`TimeStamp`, E.`InizioConnessione`,
            GROUP_CONCAT(DISTINCT S.`ID` SEPARATOR ',') AS "ServerDaEscludere"
        FROM `ErogazioniNonAlTermine` E
            INNER JOIN `Utente` U ON U.`Codice` = E.`Utente`
            INNER JOIN `Abbonamento` A ON A.`Tipo` = U.`Abbonamento`
            CROSS JOIN `ServerPiuCarichi` S
        GROUP BY E.`Edizione`, E.`IP`, E.`Utente`, A.`Definizione`, E.`TimeStamp`, E.`InizioConnessione`;

    DECLARE CONTINUE HANDLER FOR NOT FOUND
        SET fetching = FALSE;

    CREATE TEMPORARY TABLE IF NOT EXISTS `AlternativaErogazioni`
    (
        -- Riferimenti a Erogazione
        `Server` INT NOT NULL,
        `IP` INT UNSIGNED NOT NULL,
        `InizioConnessione` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `Utente` VARCHAR(100) NOT NULL,
        `Edizione` INT NOT NULL,
        `Timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        -- Alternativa
        `Alternativa` INT NOT NULL,
        `File` INT NOT NULL,
        `Punteggio` FLOAT NOT NULL,

        PRIMARY KEY(`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`)
    ) Engine=InnoDB;

    -- Actual operations
    SELECT MAX(`CaricoPercentuale`), AVG(`CaricoPercentuale`) INTO `MaxCarichi`, `MediaCarichi`
    FROM `ServerConCarico`;

    IF `MediaCarichi` IS NULL OR `MaxCarichi` < 0.7 THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = "Non c'è bisogno di ribilanciare le Erogazioni";
        LEAVE ribilancia_body;
    END IF;

    TRUNCATE `AlternativaErogazioni`;

    OPEN cur;

    ciclo:LOOP
        FETCH cur INTO
            server_id, edizione_id,
            ip_utente, codice_utente, max_definiz,
            timestamp_vis, timestamp_conn,
            server_da_escludere;

        IF NOT fetching THEN
            LEAVE ciclo;
        END IF;

        SET paese_utente = Ip2PaeseStorico(ip_utente, timestamp_conn);

        CALL `TrovaMigliorServer`(
            edizione_id, paese_utente, max_definiz,
            0, 0,
            NULL, NULL,
            server_da_escludere,
            @FileID, @ServerID, @Punteggio);

        IF @FileID IS NOT NULL AND @ServerID IS NOT NULL THEN
            INSERT INTO `AlternativaErogazioni` (
                `Server`, `Utente`, `Edizione`,
                `Timestamp`, `InizioConnessione`, `IP`,
                `Alternativa`, `File`, `Punteggio`) VALUES (
                    server_id, codice_utente, edizione_id,
                    timestamp_vis, timestamp_conn, ip_utente,
                    @ServerID, @FileID, @Punteggio);
        END IF;

    END LOOP;

    CLOSE cur;

    -- Prepariamo la tabella per i nuovi suggerimenti
    DELETE
    FROM `ModificaErogazioni`;

    IF (SELECT COUNT(*) FROM `AlternativaErogazioni`) = 0 THEN
        -- Non ci sono opzioni, esco
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = "Non ci sono opzioni di ribilanciamento";
        LEAVE ribilancia_body;
    END IF;

    INSERT INTO `ModificaErogazioni`(
                `Server`, `Utente`, `Edizione`,
                `Timestamp`, `InizioConnessione`, `IP`,
                `Alternativa`, `File`, `Punteggio`)

        WITH `ConClassifica` AS (
            SELECT A.*, RANK() OVER (
                PARTITION BY A.`Server`
                ORDER BY A.`Punteggio` ASC
            ) Classifica
            FROM `AlternativaErogazioni` A
        )
        SELECT
            A.`Server`, A.`Utente`, A.`Edizione`,
            A.`Timestamp`, A.`InizioConnessione`, A.`IP`,
            A.`Alternativa`, A.`File`, A.`Punteggio`
        FROM `ConClassifica` A
            INNER JOIN `Server` S ON A.`Server` = S.`ID`
        WHERE A.`Classifica` <= FLOOR(S.`MaxConnessioni` / 20) + 1; -- Per ogni Server sposto al massimo il 5% del suo MaxConnessioni

END ; $$

CREATE EVENT `RibilanciamentoCaricoEvent`
ON SCHEDULE EVERY 10 MINUTE
DO
    CALL `RibilanciamentoCarico`();
$$

DELIMITER ;