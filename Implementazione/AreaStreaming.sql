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
    `TimeStamp` TIMESTAMP NOT NULL,
    `Edizione` INT NOT NULL,
    `Utente` VARCHAR(100) NOT NULL,
    `IP` INT UNSIGNED NOT NULL,
    `InizioConnessione` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Quando il Server ha iniziato a essere usato
    `InizioErogazione` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Il Server in uso
    `Server` INT NOT NULL,

    -- Chiavi
    PRIMARY KEY (`TimeStamp`, `Edizione`, `Utente`, `IP`, `InizioConnessione`),
    FOREIGN KEY (`TimeStamp`, `Edizione`, `Utente`, `IP`, `InizioConnessione`)
        REFERENCES `Visualizzazione`(`TimeStamp`, `Edizione`, `Utente`, `IP`, `InizioConnessione`) 
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (`Server`) REFERENCES `Server`(`ID`) ON UPDATE CASCADE ON DELETE CASCADE

    -- Vincoli di dominio
    -- CHECK (`TimeStamp` BETWEEN `InizioConnessione` AND `InizioErogazione`)
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
    SET NEW.InizioErogazione = CURRENT_TIMESTAMP;

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

DROP FUNCTION IF EXISTS `Ip2Int`;
DROP FUNCTION IF EXISTS `LocalHostIpParse`;
DROP FUNCTION IF EXISTS `IpOk`;
DROP FUNCTION IF EXISTS `Int2Ip`;

DROP FUNCTION IF EXISTS `IpRangeCollidono`;
DROP FUNCTION IF EXISTS `IpRangeValidoInData`;
DROP FUNCTION IF EXISTS `IpAppartieneRangeInData`;

DROP FUNCTION IF EXISTS `Ip2Paese`;
DROP FUNCTION IF EXISTS `Ip2PaeseStorico`;

DROP FUNCTION IF EXISTS `IpRangePossoInserire`;
DROP PROCEDURE IF EXISTS `IpRangeProvaInserire`;
DROP PROCEDURE IF EXISTS `IpRangeProvaInserireAdesso`;

DROP TRIGGER IF EXISTS `IpRangeControlloAggiornamento`;

DELIMITER $$

-- ----------------------------------------------------
--
--           Funzioni di utilita' sugli IP4
--
-- ----------------------------------------------------


CREATE FUNCTION `LocalHostIpParse`(IP VARCHAR(15))
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN

    IF LOWER(IP) = 'localhost' OR IP = '0' OR IP = '0.0.0.0' THEN
        -- Localchost ip
        RETURN '127.0.0.1';
    END IF;

    RETURN IP;
END ; $$

CREATE FUNCTION `IpOk`(IP VARCHAR(15))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE IpParsed VARCHAR(15) DEFAULT NULL;
    DECLARE regex_base CHAR(38) DEFAULT '(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])';
    
    IF IP IS NULL THEN
        RETURN FALSE;
    END IF;

    SET IpParsed = LocalHostIpParse(IP);

    RETURN IpParsed REGEXP CONCAT(regex_base, '\.', regex_base, '\.', regex_base, '\.', regex_base);
END ; $$

CREATE FUNCTION `Ip2Int`(IP VARCHAR(15))
RETURNS INT UNSIGNED
DETERMINISTIC
BEGIN
    DECLARE Int2Return INT UNSIGNED DEFAULT 0;
    DECLARE IP_Str VARCHAR(15) DEFAULT NULL; 

    IF NOT IpOk(IP) THEN
        RETURN 0;
    END IF;

    SET IP_Str = IP;

    SET Int2Return = CAST(SUBSTRING_INDEX(IP_Str, '.', -1) AS UNSIGNED);
    SET IP_Str = SUBSTRING_INDEX(IP_Str, '.', 3);

    SET Int2Return = Int2Return + CAST(SUBSTRING_INDEX(IP_Str, '.', -1) AS UNSIGNED) * 256;
    SET IP_Str = SUBSTRING_INDEX(IP_Str, '.', 2);

    SET Int2Return = Int2Return + CAST(SUBSTRING_INDEX(IP_Str, '.', -1) AS UNSIGNED) * 65536;
    SET IP_Str = SUBSTRING_INDEX(IP_Str, '.', 1);

    SET Int2Return = Int2Return + CAST(SUBSTRING_INDEX(IP_Str, '.', -1) AS UNSIGNED) * 16777216;

    RETURN Int2Return;
END ; $$

CREATE FUNCTION `Int2Ip`(IP INT UNSIGNED)
RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
    DECLARE HexStr CHAR(15) DEFAULT NULL;

    SET HexStr = LPAD(HEX(IP), 8, 0);

    RETURN CONCAT(
        CONV(SUBSTR(HexStr, 1, 2), 16, 10), -- 1 and 2
        '.',
        CONV(SUBSTR(HexStr, 3, 2), 16, 10), -- 3 and 4
        '.',
        CONV(SUBSTR(HexStr, 5, 2), 16, 10), -- 5 and 6
        '.',
        CONV(SUBSTR(HexStr, 7, 2), 16, 10) -- 7 and 8
    );
END ; $$

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

    IF FineValidita IS NULL THEN
        RETURN InizioValidita <= IstanteDaControllare;
    END IF;

    RETURN IstanteDaControllare BETWEEN InizioValidita AND FineValidita;
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
        ip, DataDaControllare) AND
        r.Paese <> '??'
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

    -- Controllo sugli altri range
    IF NOT `IpRangePossoInserire` (`NewInizio`, `NewFine`, `NewDataInizio`, `NewPaese`) THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT = 'Ip Range collide con altri esistenti!';
        LEAVE insert_body;
    END IF;

    -- Se il record inserito "rompe" uno gia' presente, con meno piorita' si fa scadere quello gia' presente
    UPDATE `IPRange`
    SET `IPRange`.`DataFine` = `NewDataInizio` - INTERVAL 1 SECOND -- I timestamp vengono tenuti leggermente differenti
    WHERE
        IpRangeCollidono(`NewInizio`, `NewFine`, `IPRange`.`Inizio`, `IPRange`.`Fine`)  AND
        IpRangeValidoInData(`NewDataInizio`, `NewDataFine`, `IPRange`.`DataInizio`);

    -- Inserisco essendo sicuro di aver mantenuto coerenza tra gli ip
    INSERT INTO `IPRange` (`Inizio`, `Fine`, `DataInizio`, `DataFine`, `Paese`) VALUES
    (`NewInizio`, `NewFine`, `NewDataInizio`, `NewDataFine`, `NewPaese`);
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