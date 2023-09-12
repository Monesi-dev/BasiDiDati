USE `FilmSphere`;

DROP PROCEDURE IF EXISTS `BilanciamentoDelCarico`;
DELIMITER //
CREATE PROCEDURE `BilanciamentoDelCarico`(
    M INT,
    N INT
)
BEGIN

    -- 1) Ottieni Tabella Visualizzazione + Colonna Paese
    -- 2) Ottieni Tabella T(Edizione, Paese, Visualizzazioni)
    -- 3) Per ogni Paese prendi le N Edizioni piu' visualizzate
    --      3.1) Fai un Ranking ordinato per Visualizzazioni e partizionato per Paese
    --      3.2) Seleziona solo i primi N per ogni Partizione
    -- 4) Per ogni Paese si individuano gli M server piu' vicini
    --      4.1) Fai un ranking di Server, Paese ordinato per distanza e partizionato per Paese
    --      4.2) Selezioni i primi M per ogni Paese
    -- 5) Creare una Tabella, senza duplicati, T(Edizione, Server) facendo il JOIN tra la 3 e la 4
    -- 6) Si crea una Tabella, partendo dalla precedente, T(File, Server) contenente ogni File di Edizione ma tale per cui non vi sia un P.o.P tra File e Server
    --      6.1) Fai il JOIN con File e ottieni T(File, Server)
    --      6.2) Imponi che non debba esistere un occorrenza di P.o.P avente stesso File e Server


    WITH
        -- 1) Ottieni Tabella Visualizzazione + Colonna Paese
        VisualizzazionePaese AS (
            SELECT
                V.*,
                Ip2PaeseStorico(V.IP, V.InizioConnessione) AS Paese
            FROM Visualizzazione V
        ),

        -- 2) Ottieni Tabella T(Edizione, Paese, Visualizzazioni)
        EdizionePaeseVisualizzazioni AS (
            SELECT
                Edizione,
                Paese,
                COUNT(*) AS Visualizzazioni
            FROM VisualizzazionePaese
            GROUP BY Edizione, Paese
        ),

        -- 3) Per ogni Paese prendi le N Edizioni piu' visualizzate
        RankingVisualizzazioniPerPaese AS (
            SELECT
                Edizione,
                Paese,
                RANK() OVER (PARTITION BY Paese ORDER BY Visualizzazioni DESC, Edizione) AS rk
            FROM EdizionePaeseVisualizzazioni
        ),
        EdizioniTargetPerPaese AS (
            SELECT
                Edizione,
                Paese
            FROM RankingVisualizzazioniPerPaese
            WHERE rk <= N
        ),

        -- 4) Per ogni Paese si individuano gli M server piu' vicini
        RankingPaeseServer AS (
            SELECT
                Server,
                Paese,
                RANK() OVER(PARTITION BY Paese ORDER BY ValoreDistanza, Paese) AS rk
            FROM DistanzaPrecalcolata
        ),
        ServerTargetPerPaese AS (
            SELECT
                Server,
                Paese
            FROM RankingPaeseServer
            WHERE rk <= M
        ),

        -- 5) Creare una Tabella, senza duplicati, T(Edizione, Server) facendo il JOIN tra la 3 e la 4
        EdizionePaese AS (
            SELECT DISTINCT
                Edizione,
                Server
            FROM ServerTargetPerPaese SP
            INNER JOIN EdizioniTargetPerPaese EP
                USING(Paese)
        )

    -- 6)  Si crea una Tabella, partendo dalla precedente, T(File, Server) contenente ogni File di Edizione ma tale per cui non vi sia un P.o.P tra File e Server
    SELECT
        F.ID AS File,
        EP.Server
    FROM EdizionePaese EP
    INNER JOIN File F
        ON F.Edizione = EP.Edizione
    WHERE NOT EXISTS (
        SELECT *
        FROM PoP
        WHERE PoP.File = F.ID
        AND PoP.Server = EP.Server
    );


END
//
DELIMITER ;

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

DROP FUNCTION IF EXISTS `ValutazioneAttore`;

DELIMITER //
CREATE FUNCTION `ValutazioneAttore`(
    Nome VARCHAR(50),
    Cognome VARCHAR(50)
    )
RETURNS FLOAT 
NOT DETERMINISTIC
READS SQL DATA
BEGIN

    DECLARE sum_v FLOAT;
    DECLARE sum_p FLOAT;
    DECLARE n INT;

    SET sum_v := (
        SELECT
            SUM(F.MediaRecensioni)
        FROM Artista A
        INNER JOIN Recitazione R
            ON R.NomeAttore = A.Nome AND R.CognomeAttore = A.Cognome
        INNER JOIN Film F
            ON F.ID = R.Film
        WHERE A.Nome = Nome AND A.Cognome = Cognome
    );

    SET sum_p := (
        SELECT
            COUNT(DISTINCT VP.Film)
        FROM Artista A
        INNER JOIN Recitazione R
            ON R.NomeAttore = A.Nome AND R.CognomeAttore = A.Cognome
        INNER JOIN VincitaPremio VP
            ON VP.Film = R.Film
        WHERE A.Nome = Nome AND A.Cognome = Cognome
    );

    SET n := (
        SELECT
            COUNT(*)
        FROM VincitaPremio
        WHERE NomeArtista = Nome AND CognomeArtista = CognomeArtista
    );

    RETURN sum_v + sum_p * 5 + n * 50.0;

END //
DELIMITER ;


DROP PROCEDURE IF EXISTS `MiglioreAttore`;
DELIMITER //
CREATE PROCEDURE `MiglioreAttore`()
BEGIN

    WITH
        AttoreValutazione AS (
            SELECT
                Nome, Cognome,
                ValutazioneAttore(Nome, Cognome) AS Valutazione
            FROM Artista
            WHERE Popolarita <= 2.5
        )
    SELECT
        Nome, Cognome
    FROM AttoreValutazione
    WHERE Valutazione = (
        SELECT MAX(Valutazione)
        FROM AttoreValutazione
    );

END //
DELIMITER ;







DROP FUNCTION IF EXISTS `ValutazioneRegista`;
DELIMITER //
CREATE FUNCTION `ValutazioneRegista`(
    Nome VARCHAR(50),
    Cognome VARCHAR(50)
    )
RETURNS FLOAT 
NOT DETERMINISTIC
READS SQL DATA
BEGIN

    DECLARE sum_v FLOAT;
    DECLARE sum_p FLOAT;
    DECLARE n INT;

    SET sum_v := (
        SELECT
            SUM(MediaRecensioni)
        FROM Film
        WHERE NomeRegista = Nome AND CognomeRegista = Cognome
    );

    SET sum_p := (
        SELECT
            COUNT(DISTINCT VP.Film)
        FROM Film F
        INNER JOIN VincitaPremio VP
            ON VP.Film = F.ID
        WHERE F.NomeRegista = Nome AND F.CognomeRegista = Cognome
    );

    SET n := (
        SELECT
            COUNT(*)
        FROM VincitaPremio
        WHERE NomeArtista = Nome AND CognomeArtista = CognomeArtista
    );

    RETURN sum_v + sum_p * 5 + n * 50.0;

END
//
DELIMITER ;

DROP PROCEDURE IF EXISTS `MiglioreRegista`;
DELIMITER //
CREATE PROCEDURE `MiglioreRegista`()
BEGIN

    WITH
        RegistaValutazione AS (
            SELECT
                Nome, Cognome,
                ValutazioneRegista(Nome, Cognome) AS Valutazione
            FROM Artista
            WHERE Popolarita <= 2.5
        )
    SELECT
        Nome, Cognome
    FROM RegistaValutazione
    WHERE Valutazione = (
        SELECT MAX(Valutazione)
        FROM RegistaValutazione
    );

END //
DELIMITER ;

DROP PROCEDURE IF EXISTS `RaccomandazioneContenuti`;
DELIMITER //
CREATE PROCEDURE `RaccomandazioneContenuti`(
    IN codice_utente VARCHAR(100),
    IN numero_film INT
)
BEGIN

    WITH
        FilmRatingUtente AS (
            SELECT
                ID,
                RatingUtente(ID, codice_utente) AS Rating
            FROM Film
        )
    SELECT ID
    FROM FilmRatingUtente
    ORDER BY Rating DESC, ID
    LIMIT numero_film;


END
//
DELIMITER ;

DROP FUNCTION IF EXISTS `RatingFilm`;
DELIMITER //
CREATE FUNCTION IF NOT EXISTS `RatingFilm`(
    `id_film` INT
)
RETURNS FLOAT NOT DETERMINISTIC
    READS SQL DATA
BEGIN

    DECLARE RU FLOAT;
    DECLARE RC FLOAT;
    DECLARE PA FLOAT;
    DECLARE PR FLOAT;
    DECLARE PV FLOAT;
    DECLARE RMU FLOAT;

    SET RU := (
        SELECT
            IFNULL(MediaRecensioni, 0)
        FROM Film
        WHERE ID = id_film
    );

    SET RC := (
        SELECT
            IFNULL(AVG(Voto), 0)
        FROM Critica
        WHERE Film = id_film
    );

    SET PA := (
        SELECT
            IFNULL(AVG(Popolarita), 0)
        FROM Artista A
        INNER JOIN Recitazione R
        ON A.Nome = R.NomeAttore AND A.Cognome = R.CognomeAttore
        WHERE Film = id_film
    );

    SET PR := (
        SELECT
            IFNULL(Popolarita, 0)
        FROM Artista A
        INNER JOIN Film F
        ON F.NomeRegista = A.Nome AND F.CognomeRegista = A.Cognome
        WHERE ID = id_film
    );

    SET PV := (
        SELECT
            COUNT(*)
        FROM VincitaPremio
        WHERE Film = id_film
    );

    SET RMU := (
        SELECT
            IFNULL(MAX(F2.MediaRecensioni), 0)
        FROM Film F1
        INNER JOIN GenereFilm GF1
        ON GF1.Film = F1.ID
        INNER JOIN GenereFilm GF2
        ON GF2.Genere = GF1.Genere
        INNER JOIN Film F2
        ON GF2.Film = F2.ID
        WHERE F1.ID = id_film
    );

    RETURN FLOOR(0.5 * (RU + RC) + 0.1 * (PA + PR) + 0.1 * PV + (RU/RMU)) / 2;

END
//
DELIMITER ;


DROP FUNCTION IF EXISTS `RatingUtente`;
DELIMITER //
CREATE FUNCTION `RatingUtente`(
    id_film INT,
    id_utente VARCHAR(100)
)
RETURNS FLOAT NOT DETERMINISTIC
    READS SQL DATA
BEGIN

    DECLARE G1 VARCHAR(50);
    DECLARE G2 VARCHAR(50);
    DECLARE A1_Nome VARCHAR(50);
    DECLARE A1_Cognome VARCHAR(50);
    DECLARE A2_Nome VARCHAR(50);
    DECLARE A2_Cognome VARCHAR(50);
    DECLARE A3_Nome VARCHAR(50);
    DECLARE A3_Cognome VARCHAR(50);
    DECLARE L1 VARCHAR(50);
    DECLARE L2 VARCHAR(50);
    DECLARE R_Nome VARCHAR(50);
    DECLARE R_Cognome VARCHAR(50);
    DECLARE RA INT;

    DECLARE G1_b TINYINT;
    DECLARE G2_b TINYINT;
    DECLARE A1_b TINYINT;
    DECLARE A2_b TINYINT;
    DECLARE A3_b TINYINT;
    DECLARE L1_b TINYINT;
    DECLARE L2_b TINYINT;
    DECLARE R_b TINYINT;
    DECLARE RA_b TINYINT;

    -- ------------------------
    -- Determino i Preferiti
    -- ------------------------

    -- L'idea e' di creare delle classifica come Temporary Table
    -- per poi andare a selezionare l'i-esimo preferito

    DROP TEMPORARY TABLE IF EXISTS GeneriClassifica;
    CREATE TEMPORARY TABLE IF NOT EXISTS GeneriClassifica
    WITH
        GenereVisualizzazioni AS (
            SELECT
                Genere,
                COUNT(*) AS N
            FROM Visualizzazione V
            INNER JOIN Edizione E
                ON E.ID = V.Edizione
            INNER JOIN GenereFilm GF
                ON GF.Film = E.Film
            WHERE V.Utente = id_utente
            GROUP BY Genere
        )
    SELECT
        Genere,
        RANK() OVER (ORDER BY N DESC, Genere) as Rk
    FROM GenereVisualizzazioni;

    SET G1 := (
        SELECT
            Genere
        FROM GeneriClassifica
        WHERE rk = 1
    );

    SET G2 := (
        SELECT
            Genere
        FROM GeneriClassifica
        WHERE rk = 2
    );


    DROP TEMPORARY TABLE IF EXISTS AttoriClassifica;
    CREATE TEMPORARY TABLE IF NOT EXISTS AttoriClassifica
        WITH
            AttoriVisualizzazioni AS (
                SELECT
                    R.NomeAttore,
                    R.CognomeAttore,
                    COUNT(*) AS N
                FROM Visualizzazione V
                INNER JOIN Edizione E
                    ON E.ID = V.Edizione
                INNER JOIN Recitazione R
                    ON R.Film = E.Film
                WHERE V.Utente = id_utente
                GROUP BY R.NomeAttore, R.CognomeAttore
            )
        SELECT
            NomeAttore, CognomeAttore,
            RANK() OVER(ORDER BY N DESC, NomeAttore, CognomeAttore) AS rk
        FROM AttoriVisualizzazioni;

    SET A1_Nome := (
        SELECT
            NomeAttore
        FROM AttoriClassifica
        WHERE rk = 1
    );

    SET A1_Cognome := (
        SELECT
            CognomeAttore
        FROM AttoriClassifica
        WHERE rk = 1
    );

    SET A2_Nome := (
        SELECT
            NomeAttore
        FROM AttoriClassifica
        WHERE rk = 2
    );

    SET A2_Cognome := (
        SELECT
            CognomeAttore
        FROM AttoriClassifica
        WHERE rk = 2
    );

    SET A3_Nome := (
        SELECT
            NomeAttore
        FROM AttoriClassifica
        WHERE rk = 3
    );

    SET A3_Cognome := (
        SELECT
            CognomeAttore
        FROM AttoriClassifica
        WHERE rk = 3
    );

    DROP TEMPORARY TABLE IF EXISTS LinguaClassifica;
    CREATE TEMPORARY TABLE IF NOT EXISTS LinguaClassifica
        WITH
            LinguaVisualizzazioni AS (
                SELECT
                    D.Lingua,
                    COUNT(*) AS N
                FROM Visualizzazione V
                INNER JOIN File F
                    ON F.Edizione = V.Edizione
                INNER JOIN Doppiaggio D
                    ON D.File = F.ID
                WHERE V.Utente = id_utente
                GROUP BY D.Lingua
            )
        SELECT
            Lingua,
            RANK() OVER(ORDER BY N DESC, Lingua) AS rk
        FROM LinguaVisualizzazioni;

    SET L1 := (
        SELECT
            Lingua
        FROM LinguaClassifica
        WHERE rk = 1
    );

    SET L2 := (
        SELECT
            Lingua
        FROM LinguaClassifica
        WHERE rk = 2
    );

    DROP TEMPORARY TABLE IF EXISTS RegistaUtente;
    CREATE TEMPORARY TABLE IF NOT EXISTS RegistaUtente
        WITH
            RegistaVisualizzazioni AS (
                SELECT
                    F.NomeRegista,
                    F.CognomeRegista,
                    COUNT(*) AS N
                FROM Visualizzazione V
                INNER JOIN Edizione E
                    ON V.Edizione = E.ID
                INNER JOIN Film F
                    ON F.ID = E.Film
                WHERE V.Utente = id_utente
                GROUP BY F.NomeRegista, F.CognomeRegista
            )
        SELECT
            NomeRegista,
            CognomeRegista
        FROM RegistaVisualizzazioni
        ORDER BY N DESC, CognomeRegista, NomeRegista
        LIMIT 1;

    SET R_Nome := (
        SELECT NomeRegista
        FROM RegistaUtente
    );

    SET R_Cognome := (
        SELECT NomeRegista
        FROM RegistaUtente
    );

    SET RA := (
        WITH
            RapportoAspettoVisualizzazioni AS (
                SELECT
                    E.RapportoAspetto,
                    COUNT(*) AS N
                FROM Visualizzazione V
                INNER JOIN Edizione E
                    ON E.ID = V.Edizione
                WHERE V.Utente = id_utente
                GROUP BY E.RapportoAspetto
            )
        SELECT
            RapportoAspetto
        FROM RapportoAspettoVisualizzazioni
        ORDER BY N DESC, RapportoAspetto
        LIMIT 1
    );


    -- -------------------------------
    -- Determino i Valori Booleani
    -- -------------------------------

    -- L'idea e' di creare delle Temporay Table contenente i vari parametri di interesse del
    -- film (e.g. Generi) per poi andare a determinare quali preferenze sono soddisfatte

    DROP TEMPORARY TABLE IF EXISTS GeneriFilm;
    CREATE TEMPORARY TABLE IF NOT EXISTS GeneriFilm
        SELECT Genere
        FROM GenereFilm
        WHERE Film = id_film;

    DROP TEMPORARY TABLE IF EXISTS AttoriFilm;
    CREATE TEMPORARY TABLE IF NOT EXISTS AttoriFilm
        SELECT
            NomeAttore,
            CognomeAttore
        FROM Recitazione
        WHERE Film = id_film;

    DROP TEMPORARY TABLE IF EXISTS LingueFilm;
    CREATE TEMPORARY TABLE IF NOT EXISTS LingueFilm
        SELECT DISTINCT
            D.Lingua
        FROM Edizione E
        INNER JOIN File F
            ON F.Edizione = E.ID
        INNER JOIN Doppiaggio D
            ON D.File = F.ID
        WHERE E.Film = id_film;

    SET G1_b = (
        SELECT COUNT(*)
        FROM GeneriFilm
        WHERE Genere = G1
    );

    SET G2_b = (
        SELECT COUNT(*)
        FROM GeneriFilm
        WHERE Genere = G2
    );

    SET A1_b = (
        SELECT COUNT(*)
        FROM AttoriFilm
        WHERE NomeAttore = A1_Nome
        AND CognomeAttore = A1_Cognome
    );

    SET A2_b = (
        SELECT COUNT(*)
        FROM AttoriFilm
        WHERE NomeAttore = A2_Nome
        AND CognomeAttore = A2_Cognome
    );

    SET A3_b = (
        SELECT COUNT(*)
        FROM AttoriFilm
        WHERE NomeAttore = A3_Nome
        AND CognomeAttore = A3_Cognome
    );

    SET L1_b = (
        SELECT COUNT(*)
        FROM LingueFilm
        WHERE Lingua = L1
    );

    SET L2_b = (
        SELECT COUNT(*)
        FROM LingueFilm
        WHERE Lingua = L2
    );

    SET R_b = (
        SELECT COUNT(*)
        FROM Film
        WHERE ID = id_film
        AND NomeRegista = R_Nome
        AND CognomeRegista = R_Cognome
    );

    SET RA_b = (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT
                RapportoAspetto
            FROM Edizione
            WHERE Film = id_film
            AND RapportoAspetto = RA
        ) AS T
    );

    RETURN FLOOR(2 * G1_b + G2_b + 1.5 * A1_b + A2_b + 0.5 * A3_b + L1_b + L2_b + R_b + RA_b) / 2;

END
//
DELIMITER ;
