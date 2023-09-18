-- ----------------------------
-- CREAZIONE DB
-- ----------------------------

DROP DATABASE IF EXISTS `FilmSphere`;

CREATE DATABASE `FilmSphere`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;          -- UNICODE UTF-8 USED (https://dev.mysql.com/doc/refman/8.0/en/charset.html)

USE `FilmSphere`;

-- ----------------------------
-- AREA CONTENUTI
-- ----------------------------

CREATE TABLE IF NOT EXISTS `Paese` (
  `Codice` CHAR(2) NOT NULL PRIMARY KEY,
  `Nome` VARCHAR(50) NOT NULL,
  `Posizione` POINT DEFAULT NULL,

  CHECK (ST_X(`Posizione`) BETWEEN -180.00 AND 180.00), -- Contollo longitudine
  CHECK (ST_Y(`Posizione`) BETWEEN -90.00 AND 90.00) -- Controllo latitudine
) Engine=InnoDB;

-- Riga automatica necessaria per alcune funzionalita'
INSERT INTO `Paese` (`Codice`, `Nome`) VALUES ('??', 'Mondo');

CREATE TABLE IF NOT EXISTS `Artista` (
  `Nome` VARCHAR(50) NOT NULL,
  `Cognome` VARCHAR(50) NOT NULL,
  `Popolarita` FLOAT NOT NULL,    

  PRIMARY KEY(`Nome`, `Cognome`),
  CHECK(Popolarita BETWEEN 0.0 AND 10.0)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `CasaProduzione` (
  `Nome` VARCHAR(50) NOT NULL PRIMARY KEY,
  `Paese` CHAR(2) NOT NULL,
  FOREIGN KEY (`Paese`) REFERENCES `Paese` (`Codice`)
    ON DELETE CASCADE ON UPDATE CASCADE
) Engine=InnoDB;


CREATE TABLE IF NOT EXISTS `Film` (
  `ID` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `Titolo` VARCHAR(100) NOT NULL,
  `Descrizione` VARCHAR(500) NOT NULL,
  `Anno` YEAR NOT NULL,
  `CasaProduzione` VARCHAR(50) NOT NULL,  
  `NomeRegista` VARCHAR(50) NOT NULL, 
  `CognomeRegista` VARCHAR(50) NOT NULL,  

  `MediaRecensioni` FLOAT DEFAULT NULL,
  `NumeroRecensioni` INT NOT NULL DEFAULT 0,
  
  
  FOREIGN KEY (`CasaProduzione`) REFERENCES `CasaProduzione` (`Nome`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (`NomeRegista`, `CognomeRegista`) REFERENCES `Artista` (`Nome`, `Cognome`)
    ON DELETE CASCADE ON UPDATE CASCADE,

  CHECK(`MediaRecensioni` BETWEEN 0.0 AND 5.0),
  CHECK(`NumeroRecensioni` >= 0)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `VincitaPremio` (
  `Macrotipo` VARCHAR(50) NOT NULL,
  `Microtipo` VARCHAR(50) NOT NULL,
  `Data` YEAR NOT NULL,
  `Film` INT NOT NULL,
  `NomeArtista` VARCHAR(50),
  `CognomeArtista` VARCHAR(50),

  PRIMARY KEY(`Macrotipo`, `Microtipo`, `Data`),
  FOREIGN KEY(`Film`) REFERENCES `Film` (`ID`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY(`NomeArtista`, `CognomeArtista`) REFERENCES `Artista` (`Nome`, `Cognome`)
    ON UPDATE CASCADE ON DELETE CASCADE 
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Recitazione` (
  `Film` INT NOT NULL,
  `NomeAttore` VARCHAR(50) NOT NULL,
  `CognomeAttore` VARCHAR(50) NOT NULL,

  PRIMARY KEY(`Film`, `NomeAttore`, `CognomeAttore`),
  FOREIGN KEY(`Film`) REFERENCES `Film` (`ID`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY(`NomeAttore`, `CognomeAttore`) REFERENCES `Artista` (`Nome`, `Cognome`)
    ON UPDATE CASCADE ON DELETE CASCADE 
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Critico` (
  `Codice` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `Nome` VARCHAR(50) NOT NULL,
  `Cognome` VARCHAR(50) NOT NULL
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Critica` (
  `Film` INT NOT NULL,
  `Critico` INT NOT NULL,

  `Testo` VARCHAR(512) NOT NULL,
  `Data` DATE NOT NULL,
  `Voto` FLOAT NOT NULL,

  PRIMARY KEY(`Film`, `Critico`),
  FOREIGN KEY(`Film`) REFERENCES `Film` (`ID`)
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY(`Critico`) REFERENCES `Critico` (`Codice`)
    ON UPDATE CASCADE ON DELETE CASCADE, 

  CHECK(`Voto` BETWEEN 0.0 AND 5.0)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `FilmSphere`.`Genere` (
  `Nome` VARCHAR(50) NOT NULL PRIMARY KEY
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `GenereFilm` (
  `Film` INT NOT NULL,
  `Genere` VARCHAR(50) NOT NULL,

  PRIMARY KEY(`Film`, `Genere`),
  FOREIGN KEY(`Film`) REFERENCES `Film` (`ID`)
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY(`Genere`) REFERENCES `Genere` (`Nome`)
    ON UPDATE CASCADE ON DELETE CASCADE 
) Engine = InnoDB;


-- ----------------------------
-- AREA FORMATO
-- ----------------------------

CREATE TABLE IF NOT EXISTS `Edizione` (
    -- Chiavi
    `ID` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `Film` INT NOT NULL,
    
    -- Anno di pubblicazione
    `Anno` YEAR NOT NULL DEFAULT 2023,
    
    -- Commento associato: Prima Edizone, Edizione Blu-Ray, ...
    `Tipo` VARCHAR(128),

    -- Durata in [s] del contenuto
    `Lunghezza` INT UNSIGNED NOT NULL DEFAULT 0,

    -- Rapporto d'aspetto, 16/9, 4/3, 1/1
    `RapportoAspetto` FLOAT NOT NULL DEFAULT 1.778,

    -- Vincolo referenziale
    FOREIGN KEY (`Film`) REFERENCES `Film`(`ID`) ON DELETE CASCADE ON UPDATE CASCADE,

    -- Vincolo di dominio
    CHECK (`RapportoAspetto` > 0.0)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `FormatoCodifica` (
    -- Chiave primaria
    `Famiglia` VARCHAR(10) NOT NULL,
    `Versione` VARCHAR(5) NOT NULL,

    -- Il metodo perde qualita' o no durante la compressione
    `Lossy` BOOLEAN NOT NULL DEFAULT TRUE,

    -- Massimo bitrate upportato dal metodo
    `MaxBitRate` FLOAT DEFAULT NULL,

    PRIMARY KEY (`Famiglia`, `Versione`),

    CHECK (INSTR(`Famiglia`, ',') = 0) -- Non puo' contenere virgole: saranno usate per concatenare i valori dal client
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `File` (
    `ID` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `Edizione` INT NOT NULL,

    -- Relativi allo streaming
    `Dimensione` BIGINT UNSIGNED NOT NULL,
    `BitRate` FLOAT NOT NULL,

    -- Formato Contentitore (MP4, MKV, ...)
    `FormatoContenitore` VARCHAR(16),

    -- Formato Codifica Video
    `FamigliaAudio` VARCHAR(10) NOT NULL,
    `VersioneAudio` VARCHAR(5) NOT NULL,

    -- Formato Codifica Audio
    `FamigliaVideo` VARCHAR(10) NOT NULL,
    `VersioneVideo` VARCHAR(5) NOT NULL,

    -- Segnale Video
    `Risoluzione` BIGINT UNSIGNED NOT NULL,
    `FPS` FLOAT NOT NULL DEFAULT 30.0,

    -- Campionamento segnale Audio
    `BitDepth` BIGINT UNSIGNED NOT NULL,
    `Frequenza` FLOAT NOT NULL,

    -- Chiavi esterne
    FOREIGN KEY (`Edizione`) REFERENCES `Edizione`(`ID`) ON DELETE CASCADE ON UPDATE CASCADE,

    -- Vincoli di dominio
    CHECK (`BitRate` > 0.0),
    CHECK (`FPS` > 0.0)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS Lingua (
    Nome VARCHAR(32) NOT NULL PRIMARY KEY
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS Doppiaggio (
    -- File e Lingua da associare
    `File` INT NOT NULL,
    `Lingua` VARCHAR(32) NOT NULL,

    -- Chiavi
    PRIMARY KEY (`File`, `Lingua`),
    FOREIGN KEY (`File`) REFERENCES `File`(`ID`),
    FOREIGN KEY (`Lingua`) REFERENCES `Lingua`(`Nome`)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS Sottotitolaggio (
    -- File e Lingua da associare
    `File` INT NOT NULL,
    `Lingua` VARCHAR(32) NOT NULL,

    -- Chiavi
    PRIMARY KEY (`File`, `Lingua`),
    FOREIGN KEY (`File`) REFERENCES `File`(`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Lingua`) REFERENCES `Lingua`(`Nome`) ON DELETE CASCADE ON UPDATE CASCADE
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS Restrizione (
    -- Edizione e Paese da associare
    `Edizione` INT NOT NULL,
    `Paese` CHAR(2) NOT NULL,

    -- Chiavi
    PRIMARY KEY (`Edizione`, `Paese`),
    FOREIGN KEY (`Edizione`) REFERENCES `Edizione`(`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Paese`) REFERENCES `Paese`(`Codice`) ON DELETE CASCADE ON UPDATE CASCADE
) Engine=InnoDB;

DROP TRIGGER IF EXISTS `InserimentoFile`;
DROP TRIGGER IF EXISTS `ModificaFile`;
DELIMITER $$

CREATE TRIGGER `InserimentoFile`
BEFORE INSERT ON `File`
FOR EACH ROW
BEGIN
    DECLARE valido INT;
    SET valido = (
        SELECT COUNT(*)
        FROM `FormatoCodifica` AS `Audio`, `FormatoCodifica` AS `Video`
        WHERE
            `Audio`.`Famiglia` = NEW.`FamigliaAudio` AND
            `Audio`.`Versione` = NEW.`VersioneAudio` AND
            `Video`.`Famiglia` = NEW.`FamigliaVideo` AND
            `Video`.`Versione` = NEW.`VersioneVideo` AND
            `Audio`.`MaxBitRate` + `Video`.`MaxBitRate` <= NEW.`BitRate`
    );

    IF valido > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'BitRate non valido!';
    END IF;
END ; $$

CREATE TRIGGER `ModificaFile`
BEFORE UPDATE ON `File`
FOR EACH ROW
BEGIN

    DECLARE valido INT;
    SET valido = (
        SELECT COUNT(*)
        FROM `FormatoCodifica` AS `Audio`, `FormatoCodifica` AS `Video`
        WHERE
            `Audio`.`Famiglia` = NEW.`FamigliaAudio` AND
            `Audio`.`Versione` = NEW.`VersioneAudio` AND
            `Video`.`Famiglia` = NEW.`FamigliaVideo` AND
            `Video`.`Versione` = NEW.`VersioneVideo` AND
            `Audio`.`MaxBitRate` + `Video`.`MaxBitRate` <= NEW.`BitRate`
    );

    IF valido > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'BitRate non valido!';
    END IF;
END ; $$

DELIMITER ;

-- ----------------------------
-- AREA UTENTI
-- ----------------------------

CREATE TABLE IF NOT EXISTS `Utente` (
	`Codice` VARCHAR(100) NOT NULL PRIMARY KEY,
	`Nome` VARCHAR(50),
	`Cognome` VARCHAR(50),
	`Email` VARCHAR(100) NOT NULL,
	`Password` VARCHAR(100) NOT NULL,
	`Abbonamento` VARCHAR(50),
	`DataInizioAbbonamento` DATE,

	CHECK(`Email` REGEXP '[A-Za-z0-9]{1,}[\.\-A-Za-z0-9]{0,}[a-zA-Z0-9]@[a-z]{1}[\.\-\_a-z0-9]{0,}\.[a-z]{1,10}')
) Engine=InnoDB;


CREATE TABLE IF NOT EXISTS `Recensione` (
	`Film` INT NOT NULL,
	`Utente` VARCHAR(100) NOT NULL, 
	`Voto` FLOAT,

	PRIMARY KEY(`Film`, `Utente`),
	FOREIGN KEY(`Film`) REFERENCES `Film` (`ID`)
		ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY(`Utente`) REFERENCES `Utente` (`Codice`)
		ON UPDATE CASCADE ON DELETE CASCADE,

	CHECK(`Voto` BETWEEN 0.0 AND 5.0)
) Engine=InnoDB;

DROP TRIGGER IF EXISTS `InserimentoRecensione`;
DROP TRIGGER IF EXISTS `CancellazioneRecensione`;
DROP TRIGGER IF EXISTS `ModificaRecensione`;

DROP PROCEDURE IF EXISTS `AggiungiRecensione`;
DROP PROCEDURE IF EXISTS `RimuoviRecensione`;

DELIMITER $$

CREATE TRIGGER `InserimentoRecensione`
AFTER INSERT ON `Recensione`
FOR EACH ROW
BEGIN
	CALL AggiungiRecensione(NEW.`Film`, NEW.`Voto`);
END ; $$

CREATE TRIGGER `CancellazioneRecensione`
AFTER DELETE ON `Recensione`
FOR EACH ROW
BEGIN
	CALL RimuoviRecensione(OLD.`Film`, OLD.`Voto`);
END ; $$

CREATE TRIGGER `ModificaRecensione`
AFTER UPDATE ON `Recensione`
FOR EACH ROW
BEGIN
	CALL AggiungiRecensione(NEW.`Film`, NEW.`Voto`);
	CALL RimuoviRecensione(OLD.`Film`, OLD.`Voto`);
END ; $$

CREATE PROCEDURE `AggiungiRecensione`(IN Film_ID INT, IN ValoreVoto FLOAT)
BEGIN
	UPDATE `Film`
	SET 
		`Film`.`NumeroRecensioni` = `Film`.`NumeroRecensioni` + 1,
		`Film`.`MediaRecensioni` = IF (
			`Film`.`MediaRecensioni` IS NULL,
			ValoreVoto,
			(`Film`.`MediaRecensioni` * `Film`.`NumeroRecensioni` + ValoreVoto) / (`Film`.`NumeroRecensioni` + 1))
	WHERE `Film`.`ID` = Film_ID;
END ; $$

CREATE PROCEDURE `RimuoviRecensione`(IN Film_ID INT, IN ValoreVoto FLOAT)
BEGIN
	UPDATE `Film`
	SET 
		`Film`.`NumeroRecensioni` = `Film`.`NumeroRecensioni` - 1,
		`Film`.`MediaRecensioni` = IF (
			`Film`.`NumeroRecensioni` = 1,
			NULL,
			(`Film`.`MediaRecensioni` * `Film`.`NumeroRecensioni` - ValoreVoto) / (`Film`.`NumeroRecensioni` - 1))
	WHERE `Film`.`ID` = Film_ID AND `Film`.`NumeroRecensioni` > 0;
END ; $$

DELIMITER ;

CREATE TABLE IF NOT EXISTS `Connessione` (
	`IP` INT UNSIGNED NOT NULL,
	`Inizio` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	`Utente` VARCHAR(100) NOT NULL,
	`Fine` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	`Hardware` VARCHAR(256) NOT NULL DEFAULT 'Dispositivo sconosciuto',

	-- Chiavi
	PRIMARY KEY (`IP`, `Inizio`, `Utente`),
	FOREIGN KEY (`Utente`) REFERENCES `Utente` (`Codice`) ON UPDATE CASCADE ON DELETE CASCADE,

	-- Vincoli di dominio
	-- CHECK (`IP` >= 16777216), -- Un IP non puo' assumere tutti i valori di un intero
	CHECK (`Fine` >= `Inizio`)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Visualizzazione` (
    `IP` INT UNSIGNED NOT NULL,
    `InizioConnessione` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `Utente` VARCHAR(100) NOT NULL,
    `Edizione` INT NOT NULL,
    `Timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY(`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`),
    FOREIGN KEY (`Utente`, `IP`, `InizioConnessione`) REFERENCES `Connessione` (`Utente`, `IP`, `Inizio`)
      ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Edizione`) REFERENCES `Edizione` (`ID`)
      ON DELETE CASCADE ON UPDATE CASCADE

	-- CHECK (`Timestamp` >= `InizioConnessione`)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Abbonamento` (
    `Tipo` VARCHAR(50) NOT NULL PRIMARY KEY,
    `Tariffa` FLOAT NOT NULL,
    `Durata` INT NOT NULL,
    `Definizione` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `Offline` BOOLEAN DEFAULT FALSE,
    `MaxOre` INT DEFAULT 28,
    `GBMensili` INT,
    CHECK (`Tariffa` >= 0),
    CHECK (`Durata` >= 0),
    CHECK (`Definizione` >= 0),
    CHECK (`GBMensili` >= 0)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Esclusione` (
    `Abbonamento` VARCHAR(50) NOT NULL,
    `Genere` VARCHAR(50) NOT NULL,

    PRIMARY KEY(`Abbonamento`, `Genere`),
    FOREIGN KEY (`Abbonamento`) REFERENCES `Abbonamento` (`Tipo`)
      ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Genere`) REFERENCES `Genere` (`Nome`)
      ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS `CartaDiCredito` (
    `PAN` BIGINT NOT NULL PRIMARY KEY,
    `Scadenza` DATE,
    `CVV` SMALLINT NOT NULL
);

CREATE TABLE IF NOT EXISTS `Fattura` (
    `ID` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `Utente` VARCHAR(100) NOT NULL,
    `DataEmissione` DATE NOT NULL,
    `DataPagamento` DATE,
    `CartaDiCredito` BIGINT DEFAULT NULL,

	FOREIGN KEY (`Utente`) REFERENCES `Utente`(`Codice`) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (`CartaDiCredito`) REFERENCES `CartaDiCredito`(`PAN`) ON UPDATE CASCADE ON DELETE CASCADE,

    CHECK (`DataPagamento` >= `DataEmissione`)
);

CREATE TABLE IF NOT EXISTS `VisualizzazioniGiornaliere` (
    `Film` INT NOT NULL,
	`Paese` CHAR(2) NOT NULL DEFAULT '??',
    `Data` DATE NOT NULL,

    `NumeroVisualizzazioni` INT DEFAULT 0,
    
	-- Chiavi
	PRIMARY KEY (`Film`, `Paese`, `Data`),
    FOREIGN KEY (`Film`) REFERENCES `Film` (`ID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Paese`) REFERENCES `Paese` (`Codice`)
        ON DELETE CASCADE ON UPDATE CASCADE,

	-- Vincoli di dominio
    CHECK (`NumeroVisualizzazioni` >= 0)
);

DROP PROCEDURE IF EXISTS `VisualizzazoniGiornaliereBuild`;
DROP PROCEDURE IF EXISTS `VisualizzazoniGiornaliereFullReBuild`;
DROP EVENT IF EXISTS `VisualizzazioniGiornaliereEvent`;

DELIMITER $$

CREATE PROCEDURE `VisualizzazoniGiornaliereBuild` ()
proc_body:BEGIN

	DECLARE `data_target` DATE DEFAULT SUBDATE(CURRENT_DATE, 1);

	IF EXISTS (
		SELECT v.*
		FROM `VisualizzazioniGiornaliere` v
		WHERE v.`Data` = `data_target`
	) THEN

		SIGNAL SQLSTATE '01000'
			SET MESSAGE_TEXT = 'Procedura già lanciata oggi!';
		LEAVE proc_body;
	END IF;

	INSERT INTO `VisualizzazioniGiornaliere` (`Film`, `Paese`, `Data`, `NumeroVisualizzazioni`)
		WITH `VisFilmData` AS (
			SELECT V.`IP`, E.`Film`, DATE(V.`Timestamp`) AS "Data", V.`InizioConnessione`
			FROM `Visualizzazione` V
				INNER JOIN `Edizione` E ON E.`ID` = V.`Edizione`
		)
		SELECT V.`Film`, IFNULL(r.`Paese`, '??') AS "Paese", V.`Data`, COUNT(*)
		FROM `VisFilmData` V
			LEFT OUTER JOIN `IPRange` r ON     	
				(V.`IP` BETWEEN r.`Inizio` AND r.`Fine`) AND 
        		(V.`InizioConnessione` BETWEEN r.`DataInizio` AND IFNULL(r.`DataFine`, CURRENT_TIMESTAMP))
		WHERE V.`Data` = `data_target`
		GROUP BY V.`Film`, "Paese", V.`Data`;
END ; $$

CREATE PROCEDURE `VisualizzazoniGiornaliereFullReBuild` ()
BEGIN
	DECLARE `min_date` DATE DEFAULT SUBDATE(CURRENT_DATE, 32);

	REPLACE INTO `VisualizzazioniGiornaliere` (`Film`, `Paese`, `Data`, `NumeroVisualizzazioni`)
		WITH `VisFilmData` AS (
			SELECT V.`IP`, E.`Film`, DATE(V.`Timestamp`) AS "Data", V.`InizioConnessione`
			FROM `Visualizzazione` V
				INNER JOIN `Edizione` E ON E.`ID` = V.`Edizione`
		)
		SELECT V.`Film`, IFNULL(r.`Paese`, '??') AS "Paese", V.`Data`, COUNT(*)
		FROM `VisFilmData` V
			LEFT OUTER JOIN `IPRange` r ON     	
				(V.`IP` BETWEEN r.`Inizio` AND r.`Fine`) AND 
        		(V.`InizioConnessione` BETWEEN r.`DataInizio` AND IFNULL(r.`DataFine`, CURRENT_TIMESTAMP))
		WHERE `min_date` <= V.`Data`
		GROUP BY V.`Film`, "Paese", V.`Data`;
END ; $$

CREATE EVENT `VisualizzazioniGiornaliereEvent`
ON SCHEDULE EVERY 1 DAY
DO
	CALL `VisualizzazoniGiornaliereBuild`();
$$

DELIMITER ;

-- ----------------------------
-- AREA STREAMING
-- ----------------------------

CREATE TABLE IF NOT EXISTS `Server` (
    -- Chiave
    `ID` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    
    `CaricoAttuale` INT NOT NULL DEFAULT 0,

    `MaxConnessioni` INT NOT NULL DEFAULT 10000,
    
    -- Lunghezza massima della banda
    `LunghezzaBanda` FLOAT NOT NULL,
    
    -- Maxinum Transfer Unit
    `MTU` FLOAT NOT NULL,

    -- Posizione del Server
    `Posizione` POINT,

    -- Vincoli di dominio
    CHECK (`MaxConnessioni` > 0),
    CHECK (`LunghezzaBanda` > 0.0),
    CHECK (`MTU` > 0.0),
    CHECK (ST_X(`Posizione`) BETWEEN -180.00 AND 180.00), -- Contollo longitudine
    CHECK (ST_Y(`Posizione`) BETWEEN -90.00 AND 90.00) -- Controllo latitudine
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `PoP` (
    -- Associazione tra File e Server
    `File` INT NOT NULL,
    `Server` INT NOT NULL,
    
    -- Chiavi
    PRIMARY KEY (`File`, `Server`),
    FOREIGN KEY (`File`) REFERENCES `File`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (`Server`) REFERENCES `Server`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `DistanzaPrecalcolata` (
    -- Associazione tra Paese e Server
    `Paese` CHAR(2) NOT NULL,
    `Server` INT NOT NULL,

    `ValoreDistanza` FLOAT DEFAULT 0.0,

    -- Chiavi
    PRIMARY KEY (`Paese`, `Server`),
    FOREIGN KEY (`Paese`) REFERENCES `Paese`(`Codice`) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (`Server`) REFERENCES `Server`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE,

    -- Vincoli di dominio: controllo che una distanza sia non negativa e minore di un giro del mondo
    CHECK (`ValoreDistanza` BETWEEN 0.0 AND 40075.0)
) Engine=InnoDB;

DROP PROCEDURE IF EXISTS `CalcolaDistanzaPaese`;
DROP PROCEDURE IF EXISTS `CalcolaDistanzaServer`;

DROP TRIGGER IF EXISTS `InserimentoPaese`;
DROP TRIGGER IF EXISTS `ModificaPaese`;
DROP TRIGGER IF EXISTS `InserimentoServer`;
DROP TRIGGER IF EXISTS `ModificaServer`;
DELIMITER $$

CREATE PROCEDURE `CalcolaDistanzaPaese` (IN CodPaese CHAR(2))
BEGIN
    REPLACE INTO `DistanzaPrecalcolata` 
    (`Paese`, `Server`, `ValoreDistanza`)
        SELECT 
            `Paese`.`Codice`, `Server`.`ID`, 
            IF (
                `Paese`.`Codice` <> '??', 
                ST_DISTANCE_SPHERE(`Paese`.`Posizione`, `Server`.`Posizione`) / 1000,
                0)      
        FROM `Paese` CROSS JOIN `Server`
        WHERE `Paese`.`Codice` = CodPaese;
END ; $$

CREATE PROCEDURE `CalcolaDistanzaServer` (IN IDServer INT)
BEGIN
    REPLACE INTO `DistanzaPrecalcolata` (`Paese`, `Server`, `ValoreDistanza`)
        SELECT 
            `Paese`.`Codice`, `Server`.`ID`,
            IF (
                `Paese`.`Codice` <> '??', 
                ST_DISTANCE_SPHERE(`Paese`.`Posizione`, `Server`.`Posizione`) / 1000,
                0)            
        FROM `Server` CROSS JOIN `Paese`
        WHERE `Server`.`ID` = IDServer;
END ; $$

CREATE TRIGGER `InserimentoPaese`
AFTER INSERT ON `Paese`
FOR EACH ROW
BEGIN
    CALL CalcolaDistanzaPaese(NEW.`Codice`);
END ; $$

CREATE TRIGGER `ModificaPaese`
AFTER UPDATE ON `Paese`
FOR EACH ROW
BEGIN
    IF NEW.Posizione <> OLD.Posizione THEN
        CALL CalcolaDistanzaPaese(NEW.`Codice`);
    END IF;
END ; $$

CREATE TRIGGER `InserimentoServer`
AFTER INSERT ON `Server`
FOR EACH ROW
BEGIN
    CALL CalcolaDistanzaServer(NEW.`ID`);
END ; $$

CREATE TRIGGER `ModificaServer`
AFTER UPDATE ON `Server`
FOR EACH ROW
BEGIN
    IF NEW.Posizione <> OLD.Posizione THEN
        CALL CalcolaDistanzaServer(NEW.`ID`);
    END IF;
END ; $$

DELIMITER ;

CREATE TABLE IF NOT EXISTS `Erogazione` (
    -- Uguali a Visualizzazione
    `IP` INT UNSIGNED NOT NULL,
    `InizioConnessione` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `Utente` VARCHAR(100) NOT NULL,
    `Edizione` INT NOT NULL,
    `Timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Quando il Server ha iniziato a essere usato
    `InizioErogazione` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Il Server in uso
    `Server` INT NOT NULL,

    -- Chiavi
    PRIMARY KEY (`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`),
    FOREIGN KEY (`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`)
        REFERENCES `Visualizzazione`(`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`) 
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (`Server`) REFERENCES `Server`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE

    -- Vincoli di dominio
    -- CHECK (`Timestamp` BETWEEN `InizioConnessione` AND `InizioErogazione`)
) Engine=InnoDB;

DROP PROCEDURE IF EXISTS AggiungiErogazioneServer;
DROP PROCEDURE IF EXISTS RimuoviErogazioneServer;

DROP TRIGGER IF EXISTS ModificaErogazione;
DROP TRIGGER IF EXISTS AggiungiErogazione;
DROP TRIGGER IF EXISTS RimuoviErogazione;

DELIMITER $$ 

CREATE PROCEDURE AggiungiErogazioneServer(IN ServerID INT)
BEGIN
    UPDATE `Server`
    SET `Server`.`CaricoAttuale` = `Server`.`CaricoAttuale` + 1
    WHERE `Server`.`ID` = ServerID;
END ; $$

CREATE PROCEDURE RimuoviErogazioneServer(IN ServerID INT)
BEGIN
    UPDATE `Server`
    SET `Server`.`CaricoAttuale` = GREATEST(`Server`.`CaricoAttuale` - 1, 0)
    WHERE `Server`.`ID` = ServerID;
END ; $$

CREATE TRIGGER `ModificaErogazione`
BEFORE UPDATE ON Erogazione
FOR EACH ROW     
BEGIN
    -- SET NEW.InizioErogazione = CURRENT_TIMESTAMP;
    IF NEW.`Server` <> OLD.`Server` THEN
        CALL AggiungiErogazioneServer(NEW.`Server`);
        CALL RimuoviErogazioneServer(OLD.`Server`);
    END IF;
END ; $$

CREATE TRIGGER `AggiungiErogazione` 
AFTER INSERT ON Erogazione
FOR EACH ROW     
BEGIN
    CALL AggiungiErogazioneServer(NEW.`Server`);
END ; $$

CREATE TRIGGER `RimuoviErogazione`
AFTER DELETE ON Erogazione
FOR EACH ROW     
BEGIN
    CALL RimuoviErogazioneServer(OLD.`Server`);
END ; $$

DELIMITER ;

CREATE TABLE IF NOT EXISTS `IPRange` (

    -- Range di IP4
    `Inizio` INT UNSIGNED NOT NULL,
    `Fine` INT UNSIGNED NOT NULL,

    -- Inizio e fine validita'
    `DataInizio` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `DataFine` TIMESTAMP NULL DEFAULT NULL,

    -- Paese che possiede
    `Paese` CHAR(2) NOT NULL DEFAULT '??',
        
    -- Chiavi
    PRIMARY KEY (`Inizio`, `Fine`, `DataInizio`),
    FOREIGN KEY (`Paese`) REFERENCES `Paese`(`Codice`) ON UPDATE CASCADE ON DELETE CASCADE,

    -- Vincoli di dominio
    CHECK (`Fine` >= `Inizio`),
    CHECK (`DataFine` >= `DataInizio`)
) Engine=InnoDB;


-- Rimuovo funzioni, trigger e schedule prima di riaggiungerli

DROP FUNCTION IF EXISTS `IpRangeCollidono`;
DROP FUNCTION IF EXISTS `IpRangeValidoInData`;
DROP FUNCTION IF EXISTS `IpAppartieneRangeInData`;

DROP FUNCTION IF EXISTS `Ip2Paese`;
DROP FUNCTION IF EXISTS `Ip2PaeseStorico`;

DROP FUNCTION IF EXISTS `IpRangePossoInserire`;

DROP PROCEDURE IF EXISTS `IpRangeInserisciFidato`;
DROP PROCEDURE IF EXISTS `IpRangeInserisciAdessoFidato`;

DROP PROCEDURE IF EXISTS `IpRangeProvaInserire`;
DROP PROCEDURE IF EXISTS `IpRangeProvaInserireAdesso`;

DROP TRIGGER IF EXISTS `IpRangeControlloAggiornamento`;

DELIMITER $$

-- ----------------------------------------------------
--
--         Funzioni di utilita' sui Range IP4
--
-- ----------------------------------------------------

CREATE FUNCTION `IpRangeCollidono`(
    Inizio1 INT UNSIGNED, Fine1 INT UNSIGNED, 
    Inizio2 INT UNSIGNED, Fine2 INT UNSIGNED)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    -- Si assume che Fine1 >= Inizio1
    -- Si assume che Fine2 >= Inizio2

    IF Inizio1 > Inizio2 THEN
        RETURN Fine2 >= Inizio1;
    END IF;
    -- Dobbiamo controllare se Inizio1 <= Inizio2 <= Fine2
    -- Sappiamo gia' pero' che Inizio1 <= Inizio2
    -- Quindi dobbiamo solo controllare Inizio2 <= Fine1
    RETURN Inizio2 <= Fine1;
END ; $$

CREATE FUNCTION `IpRangeValidoInData`(
    InizioValidita TIMESTAMP, 
    FineValidita TIMESTAMP, 
    IstanteDaControllare TIMESTAMP)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    IF IstanteDaControllare IS NULL THEN
        RETURN FineValidita IS NULL;
    END IF;

    RETURN IstanteDaControllare BETWEEN InizioValidita AND IFNULL(FineValidita, CURRENT_TIMESTAMP);
END ; $$

CREATE FUNCTION `IpAppartieneRangeInData`(
    Inizio INT UNSIGNED,
    Fine INT UNSIGNED,
    DataInizio TIMESTAMP,
    DataFine TIMESTAMP,
    IP INT UNSIGNED,
    DataDaControllare TIMESTAMP)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    RETURN 
        (IP BETWEEN Inizio AND Fine) AND IpRangeValidoInData(DataInizio, DataFine, DataDaControllare);
END ; $$

CREATE FUNCTION `Ip2PaeseStorico`(ip INT UNSIGNED, DataDaControllare TIMESTAMP)
RETURNS CHAR(2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE Codice CHAR(2) DEFAULT '??';

    IF ip IS NULL THEN
        RETURN Codice;
    END IF;

    SELECT r.Paese INTO Codice
    FROM `IPRange` r
    WHERE IpAppartieneRangeInData(
        r.`Inizio`, r.`Fine`, 
        r.`DataInizio`, r.`DataFine`, 
        ip, DataDaControllare)
    LIMIT 1;

    IF Codice IS NULL THEN
        SET Codice = '??';
    END IF;

    RETURN Codice;
END ; $$

CREATE FUNCTION `Ip2Paese`(ip INT UNSIGNED)
RETURNS CHAR(2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    RETURN Ip2PaeseStorico(ip, CURRENT_TIMESTAMP);
END ; $$


-- -----------------------------------------------------------------
--
--  Procedure di inserimento per mantenere IPRanges consistenti
--
-- -----------------------------------------------------------------

CREATE FUNCTION `IpRangePossoInserire` (
    `NewInizio` INT UNSIGNED , `NewFine` INT UNSIGNED, 
    `NewDataInizio` TIMESTAMP, `NewPaese` CHAR(2))
RETURNS BOOLEAN
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    -- Controlliamo se il record esiste gia' (ma con data diversa)
    IF EXISTS (
        SELECT * 
        FROM `IPRange` r
        WHERE 
            r.`Inizio` = `NewInizio` AND 
            r.`Fine` = `NewFine` AND 
            IpRangeValidoInData(r.`DataInizio`, r.`DataFine`, `NewDataInizio`) AND 
            -- Se puntano allo stesso paese vuol dire che e' il solito range non ancora scaduto
            r.`Paese` = `NewPaese`
        ) THEN
        
        RETURN FALSE;
    END IF;

    -- Un record gia' presente, con priorita' maggiori, "rompe" quello appena inserito
    IF EXISTS (
        SELECT * 
        FROM `IPRange` r
        WHERE 
            IpRangeCollidono(`NewInizio`, `NewFine`, r.`Inizio`, r.`Fine`) AND
            IpRangeValidoInData(r.`DataInizio`, r.`DataFine`, `NewDataInizio`) AND
            r.`Paese` <> '??'
        ) THEN
        
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END ; $$

-- Inserimento di range senza effettuare controlli

CREATE PROCEDURE `IpRangeInserisciFidato` (
    IN `NewInizio` INT UNSIGNED, IN `NewFine` INT UNSIGNED, 
    IN `NewDataInizio` TIMESTAMP, IN `NewDataFine` TIMESTAMP, 
    IN `NewPaese` CHAR(2), IN `InvalidaCollisioni` BOOLEAN
)
BEGIN
    IF `InvalidaCollisioni` THEN
        -- Se il record inserito "rompe" uno gia' presente, con meno piorita' si fa scadere quello gia' presente
        UPDATE `IPRange`
        SET `IPRange`.`DataFine` = `NewDataInizio` - INTERVAL 1 SECOND -- I timestamp vengono tenuti leggermente differenti
        WHERE
            IpRangeCollidono(`NewInizio`, `NewFine`, `IPRange`.`Inizio`, `IPRange`.`Fine`)  AND
            IpRangeValidoInData(`NewDataInizio`, `NewDataFine`, `IPRange`.`DataInizio`);
    END IF;
    
    -- Inserisco essendo sicuro di aver mantenuto coerenza tra gli ip
    INSERT INTO `IPRange` (`Inizio`, `Fine`, `DataInizio`, `DataFine`, `Paese`) VALUES
    (`NewInizio`, `NewFine`, `NewDataInizio`, `NewDataFine`, `NewPaese`);
END ; $$

-- Inserisce solo se passa controlli

CREATE PROCEDURE `IpRangeProvaInserire` (
    IN `NewInizio` INT UNSIGNED, IN `NewFine` INT UNSIGNED, 
    IN `NewDataInizio` TIMESTAMP, IN `NewDataFine` TIMESTAMP, 
    `NewPaese` CHAR(2)
)
insert_body:BEGIN

    -- Controllo sulla consistenza del range temporale
    IF `NewDataFine` IS NOT NULL AND `NewDataFine` < `NewDataInizio` THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'Range di date invertito: DataInizio > DataFine';
        LEAVE insert_body;
    END IF;

    -- Controllo sulla consistenza del range
    IF `NewFine` < `NewInizio` THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'Range invertito: Inizio > Fine';
        LEAVE insert_body;
    END IF;

    -- Controllo sull'esistenza del paese
    IF `NewPaese` = '??' OR NOT EXISTS (
        SELECT *
        FROM `Paese` P
        WHERE P.`Codice` = `NewPaese`
    ) THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'Paese non trovato!';
        LEAVE insert_body;
    END IF;

    CALL `IpRangeInserisciFidato`(`NewInizio`, `NewFine`, `NewDataInizio`, `NewDataFine`, `NewPaese`, TRUE);
END ; $$

-- Inserimenti di range validi dal momento stesso

CREATE PROCEDURE `IpRangeInserisciAdessoFidato` (
    IN `NewInizio` INT UNSIGNED, IN `NewFine` INT UNSIGNED, IN `NewPaese` CHAR(2), IN `InvalidaCollisioni` BOOLEAN)
BEGIN
    CALL `IpRangeInserisciFidato`(`NewInizio`, `NewFine`, CURRENT_TIMESTAMP, NULL, `NewPaese`, `InvalidaCollisioni`);
END ; $$

CREATE PROCEDURE `IpRangeProvaInserireAdesso` (
    IN `NewInizio` INT UNSIGNED, IN `NewFine` INT UNSIGNED, `NewPaese` CHAR(2))
BEGIN
    CALL `IpRangeProvaInserire`(`NewInizio`, `NewFine`, CURRENT_TIMESTAMP, NULL, `NewPaese`);
END ; $$


CREATE TRIGGER `IpRangeControlloAggiornamento`
BEFORE UPDATE ON `IPRange`
FOR EACH ROW
BEGIN

    IF NEW.`Inizio` <> OLD.`Inizio` OR NEW.`Fine` <> OLD.`Fine` THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Non si possono modificare i range! Cancellare il range e inserirne uno nuovo.';
    END IF;
    
END ; $$

DELIMITER ;

DROP TRIGGER IF EXISTS CriticaDataValida;
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS CriticaDataValida
BEFORE INSERT ON Critica FOR EACH ROW
BEGIN

    DECLARE anno_film INT;

    SET anno_film = (
        SELECT Anno
        FROM Film
        WHERE ID = NEW.Film
    );

    IF anno_film > YEAR(NEW.Data) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data della Critica non Valida';
    END IF;

END $$
DELIMITER ;


DROP TRIGGER IF EXISTS AnnoEdizioneValido;
DELIMITER $$
CREATE TRIGGER IF NOT EXISTS AnnoEdizioneValido
BEFORE INSERT ON Edizione FOR EACH ROW
BEGIN

    DECLARE anno_film INT;

    SET anno_film = (
        SELECT Film.Anno
        FROM Film
        WHERE ID = NEW.Film
    );

    IF anno_film > NEW.Anno THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Anno dell\'Edizione non Valido';
    END IF;

END $$
DELIMITER ;
