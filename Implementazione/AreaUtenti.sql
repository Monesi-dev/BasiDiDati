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

DROP TRIGGER IF EXISTS InserimentoRecensione;
DROP TRIGGER IF EXISTS CancellazioneRecensione;
DROP TRIGGER IF EXISTS ModificaRecensione;

DROP PROCEDURE IF EXISTS AggiungiRecensione;
DROP PROCEDURE IF EXISTS RimuoviRecensione;

DELIMITER $$

CREATE TRIGGER InserimentoRecensione
AFTER INSERT ON Recensione
FOR EACH ROW
BEGIN
	CALL AggiungiRecensione(NEW.`Film`, NEW.`Voto`);
END ; $$

CREATE TRIGGER CancellazioneRecensione
AFTER DELETE ON Recensione
FOR EACH ROW
BEGIN
	CALL RimuoviRecensione(OLD.`Film`, OLD.`Voto`);
END ; $$

CREATE TRIGGER ModificaRecensione
AFTER UPDATE ON Recensione
FOR EACH ROW
BEGIN
	CALL AggiungiRecensione(NEW.`Film`, NEW.`Voto`);
	CALL RimuoviRecensione(OLD.`Film`, OLD.`Voto`);
END ; $$

CREATE PROCEDURE AggiungiRecensione(IN Film_ID INT, IN ValoreVoto FLOAT)
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

CREATE PROCEDURE RimuoviRecensione(IN Film_ID INT, IN ValoreVoto FLOAT)
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
	`Utente` VARCHAR(100) NOT NULL,
	`IP` INT UNSIGNED NOT NULL,
	`Inizio` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`Fine` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	`Hardware` VARCHAR(256),

	PRIMARY KEY (`IP`, `Inizio`, `Utente`),
	FOREIGN KEY (`Utente`) REFERENCES `Utente` (`Codice`)
	ON UPDATE CASCADE ON DELETE CASCADE,

	CHECK (`Fine` >= `Inizio`)
) Engine=InnoDB;

CREATE TABLE IF NOT EXISTS `Visualizzazione` (
    `Timestamp` TIMESTAMP NOT NULL,
    `Edizione` INT NOT NULL,
    `Utente` VARCHAR(100) NOT NULL,
    `IP` INT UNSIGNED NOT NULL,
    `InizioConnessione` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY(`IP`, `InizioConnessione`, `Timestamp`, `Edizione`, `Utente`),
    FOREIGN KEY (`Utente`, `IP`, `InizioConnessione`) REFERENCES `Connessione` (`Utente`, `IP`, `Inizio`)
      ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (`Edizione`) REFERENCES `Edizione` (`ID`)
      ON DELETE CASCADE ON UPDATE CASCADE,

	CHECK (`Timestamp` >= `InizioConnessione`)
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
    `Data` DATE NOT NULL,
    `NumeroVisualizzazioni` INT DEFAULT 0,
    PRIMARY KEY (`Film`, `Data`),
    FOREIGN KEY (`Film`) REFERENCES `Film` (`ID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CHECK (`NumeroVisualizzazioni` >= 0)
);

DROP PROCEDURE IF EXISTS `VisualizzazoniGiornaliereBuild`;
DROP EVENT IF EXISTS `VisualizzazioniGiornaliereEvent`;

DELIMITER $$

CREATE PROCEDURE `VisualizzazoniGiornaliereBuild` ()
proc_body:BEGIN

	DECLARE `date` DATE DEFAULT SUBDATE(CURRENT_DATE, 1);

	IF EXISTS (
		SELECT v.*
		FROM `VisualizzazioniGiornaliere` v
		WHERE v.`Data` = `date`
	) THEN

		SIGNAL SQLSTATE '01000'
			SET MESSAGE_TEXT = 'Procedura già lanciata oggi!';
		LEAVE proc_body;
	END IF;

	INSERT INTO `VisualizzazioniGiornaliere` (`Film`, `Data`, `NumeroVisualizzazioni`)
		SELECT E.`Film`, `date`, COUNT(*)
		FROM `Visualizzazioni` V
			INNER JOIN `Edizione` E ON E.`ID` = V.`Edizione`;
END ; $$

CREATE EVENT `VisualizzazioniGiornaliereEvent`
ON SCHEDULE EVERY 1 DAY
DO
	CALL `VisualizzazoniGiornaliereBuild`();
$$

DELIMITER ;