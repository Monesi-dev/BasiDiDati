USE `FilmSphere`;

DROP PROCEDURE IF EXISTS `VinciteDiUnFilm`;
DELIMITER //
CREATE PROCEDURE `VinciteDiUnFilm`(IN film_id INT)
BEGIN

    SELECT
        GROUP_CONCAT(
            `Macrotipo`, ' ',
            `Microtipo`, ' ',
            `Data`
        ) AS ListaPremi,
        COUNT(*) AS NumeroPremiVinti
    FROM `VincitaPremio`
     WHERE `Film` = film_id
    GROUP BY `Film`;

END
//
DELIMITER ;

DROP PROCEDURE IF EXISTS `GeneriDiUnFilm`;
DELIMITER //
CREATE PROCEDURE `GeneriDiUnFilm`(IN film_id INT, IN codice_utente VARCHAR(100))
BEGIN

    DECLARE lista_generi VARCHAR(400);
    DECLARE generi_disabilitati INT;

    SET lista_generi := (
        SELECT
            GROUP_CONCAT(`Genere`)
        FROM `GenereFilm`
        WHERE `Film` = film_id
        GROUP BY `Film`
    );

    SET generi_disabilitati := (
        SELECT
            COUNT(*)
        FROM GenereFilm GF
        INNER JOIN Esclusione E
        USING(Genere)
        INNER JOIN Utente U
        USING (Abbonamento)
        WHERE U.Codice = codice_utente
        AND GF.Film = film_id
    );


    IF generi_disabilitati > 0 THEN
        SELECT lista_generi, 'Non Abilitato' AS Abilitazione;
    ELSE
        SELECT lista_generi, 'Abilitato' AS Abilitazione;
    END IF;
END
//
DELIMITER ;

DROP PROCEDURE IF EXISTS `FileMiglioreQualita`;

DELIMITER $$

CREATE PROCEDURE `FileMiglioreQualita`(IN film_id INT, IN codice_utente VARCHAR(100))
BEGIN

    DECLARE massima_risoluzione INT;
    SET massima_risoluzione := (
        SELECT
            A.Definizione
        FROM Abbonamento A
        INNER JOIN Utente U
        ON U.Abbonamento = A.Tipo
        WHERE U.Codice = codice_utente
    );

    WITH
        `FileRisoluzione` AS (
            SELECT `File`.`ID`, `Risoluzione`
            FROM `Edizione`
                INNER JOIN `File`
                ON `Edizione`.`ID` = `File`.`Edizione`
            WHERE `Film` = film_id
            AND `Risoluzione` <= massima_risoluzione
        )
    SELECT
        `ID`, `Risoluzione`
    FROM `FileRisoluzione`
    WHERE `Risoluzione` = (
        SELECT
            MAX(`Risoluzione`)
        FROM `FileRisoluzione`
    );

END ; $$

DELIMITER ;

DROP PROCEDURE IF EXISTS `FilmEsclusiAbbonamento`;

DELIMITER //

CREATE PROCEDURE `FilmEsclusiAbbonamento`(
    IN TipoAbbonamento VARCHAR(50),
    OUT NumeroFilm INT)
BEGIN

    -- Film esclusi perche' il genere e' escluso
    WITH `FilmEsclusiGenere` AS (
        SELECT DISTINCT GF.`Film`
        FROM `Esclusione` E
            INNER JOIN `GenereFilm` GF USING(`Genere`)
        WHERE E.`Abbonamento` = TipoAbbonamento
    ), 
    
    -- La minor qualita' fruibile di un Film
    `FilmMinimaRisoluzione` AS (
        SELECT `Film`.`ID`, MIN(F.Risoluzione) AS "Risoluzione"
        FROM `File` F
            INNER JOIN `Edizione` E ON F.`Edizione` = E.`ID`
            INNER JOIN `Film` ON E.`Film` = `Film`.`ID`
        GROUP BY `Film`.`ID`
    ), 
    
    -- Film esclusi perche' presenti solo in qualita' maggiore dalla massima disponibile con l'abbonamento
    `FilmEsclusiRisoluzione` AS (
        SELECT F.`ID` AS "Film"
        FROM `FilmMinimaRisoluzione` F
            INNER JOIN `Abbonamento` A ON A.`Definizione` < F.`Risoluzione`
        WHERE A.`Definizione` > 0 AND A.`Tipo` = TipoAbbonamento
    )
    -- UNION senza ALL rimuovera' in automatico gli ID duplicati
    SELECT COUNT(*) INTO NumeroFilm
    FROM (
        SELECT * FROM `FilmEsclusiGenere`

        UNION

        SELECT * FROM `FilmEsclusiRisoluzione`
    ) AS T;
END ; //

DELIMITER ;

DROP PROCEDURE IF EXISTS `FilmDisponibiliInLinguaSpecifica`;
DELIMITER //
CREATE PROCEDURE `FilmDisponibiliInLinguaSpecifica`(IN lingua VARCHAR(50))
BEGIN


    SELECT DISTINCT
        FI.ID, FI.Titolo
    FROM Doppiaggio D
    INNER JOIN File F
        ON D.File = F.ID
    INNER JOIN Edizione E
        ON E.ID = F.Edizione
    INNER JOIN Film FI
        ON FI.ID = E.Film
    WHERE D.Lingua = lingua;

END
//
DELIMITER ;

DROP PROCEDURE IF EXISTS `FilmPocoPopolari`;
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `FilmPocoPopolari`(
    IN codice_utente VARCHAR(100),
    IN popolarita_massima FLOAT
)
BEGIN

    WITH
        FilmEsclusi AS (
            SELECT
                GF.Film
            FROM Utente U
            INNER JOIN Esclusione E
                USING(Abbonamento)
            INNER JOIN GenereFilm GF
                USING(Genere)
            WHERE U.Codice = codice_utente
        ),
        FilmTroppoPopolari AS (
            SELECT DISTINCT
                F.ID AS Film
            FROM Film F
            INNER JOIN Recitazione R
                ON F.ID = R.Film
            INNER JOIN Artista At
                ON At.Nome = R.NomeAttore AND At.Cognome = R.CognomeAttore
            INNER JOIN Artista Di
                ON Di.Nome = F.NomeRegista AND Di.Cognome = F.CognomeRegista
            WHERE At.Popolarita > popolarita_massima OR Di.Popolarita > popolarita_massima
        )
    SELECT
        F.ID,
        F.Titolo
    FROM Film F
    WHERE F.ID NOT IN (
        SELECT * FROM FilmEsclusi
    )
    AND F.ID NOT IN (
        SELECT * FROM FilmTroppoPopolari
    );

END //
DELIMITER ;

DROP PROCEDURE IF EXISTS `CambioAbbonamento`;
DELIMITER //
CREATE PROCEDURE `CambioAbbonamento`(IN codice_utente VARCHAR(100), IN tipo_abbonamento VARCHAR(50))
BEGIN

    DECLARE fatture_non_pagate INT;
    SET fatture_non_pagate := (
        SELECT
            COUNT(*)
        FROM Fattura
        WHERE Utente = codice_utente
        AND CartaDiCredito IS NULL
    );

    IF fatture_non_pagate > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utente non in pari coi pagamenti';

    ELSE

        UPDATE Utente
        SET Abbonamento = tipo_abbonamento, DataInizioAbbonamento = CURRENT_DATE()
        WHERE Codice = codice_utente;

    END IF;

END
//
DELIMITER ;


CREATE OR REPLACE VIEW `FilmMiglioriRecensioni` AS
    SELECT f.`Titolo`, f.`ID`, f.`MediaRecensioni`
    FROM `Film` f
    WHERE f.`MediaRecensioni` > (
        SELECT AVG(f2.`MediaRecensioni`)
        FROM `Film` f2)
    ORDER BY f.`MediaRecensioni` DESC
    LIMIT 20;
    
-- SELECT * FROM `FilmMiglioriRecensioni`;
