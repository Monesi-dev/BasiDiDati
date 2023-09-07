USE `FilmSphere`;

-- Procedure chiamate dagli scirpt di inserimento per inserire relazioni tra tabelle

DROP PROCEDURE IF EXISTS `EsclusioneCasuale`;
DROP PROCEDURE IF EXISTS `RecensioneCasuale`;

DELIMITER $$

CREATE PROCEDURE `EsclusioneCasuale`(IN abb VARCHAR(50))
BEGIN
    REPLACE INTO `Esclusione` (`Genere`, `Abbonamento`)
        SELECT `Genere`.`Nome`, abb
        FROM `Genere`
        ORDER BY RAND()
        LIMIT 1;
END $$

CREATE PROCEDURE `RecensioneCasuale`(IN utente VARCHAR(100))
BEGIN
    REPLACE INTO `Recensione` (`Film`, `Utente`, `Voto`)
        SELECT `Film`.`ID`, utente, RAND() * 5
        FROM `Film`
        ORDER BY RAND()
        LIMIT 1;
END $$

CREATE PROCEDURE `VisualizzazioneCasuale`(IN utente VARCHAR(100), IN ip INT, IN Inizio TIMESTAMP)
BEGIN
    REPLACE INTO `Visualizzazione` (`Timestamp`, `Utente`, `IP`, `InizioConnessione`, `Edizione`)
        WITH `RandEdizione` AS (
            SELECT E.`ID`, FLOOR(E.`Lunghezza` * RAND()) AS "Delta"
            FROM `Edizione` E
            ORDER BY RAND()
            LIMIT 1
        )
        SELECT inizio - INTERVAL E.`Delta` SECONDS, utente, ip, inizio, E.`ID`
        FROM `RandEdizione` E;
END $$

DELIMITER ;