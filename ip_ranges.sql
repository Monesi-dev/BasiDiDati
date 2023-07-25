CREATE TABLE ip_range
(
    ip_start VARCHAR(15) NOT NULL,
    ip_end VARCHAR(15) NOT NULL,
    country CHAR(2) NOT NULL DEFAULT '??',
    creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expire_time TIMESTAMP DEFAULT NULL,
    PRIMARY KEY (ip_start, ip_end, country)
    -- FOREIGN KEY country REFERENCES countries(code)
) ENGINE=InnoDB;

-- Useful functions
DROP FUNCTION IF EXISTS ip_as_number;
DROP FUNCTION IF EXISTS ip_in_range;
DROP FUNCTION IF EXISTS ip_to_country;

-- Trigger to check data on insert
DROP TRIGGER IF EXISTS ip_range_insert_validity_check;
DROP TRIGGER IF EXISTS ip_range_update_validity_check;

-- Periodically removes invalid values
DROP EVENT IF EXISTS ip_range_cleanup;

DELIMITER $$

CREATE FUNCTION ip_as_number(ip VARCHAR(15))
RETURNS INT(4)
DETERMINISTIC
BEGIN
    DECLARE byte_1 INT(1) DEFAULT 0;
    DECLARE byte_2 INT(1) DEFAULT 0;
    DECLARE byte_3 INT(1) DEFAULT 0;
    DECLARE byte_4 INT(1) DEFAULT 0;
    DECLARE out_int AS INT(4);

    IF ip IS NULL THEN
        RETURN 0;
    END IF;

    SET byte_1 = CAST(SUBSTRING_INDEX(ip, '.', 1) AS UNSIGNED);
    SET byte_2 = CAST(SUBSTRING_INDEX(ip, '.', 2) AS UNSIGNED);
    SET byte_3 = CAST(SUBSTRING_INDEX(ip, '.', 3) AS UNSIGNED);
    SET byte_4 = CAST(SUBSTRING_INDEX(ip, '.', 4) AS UNSIGNED);

    SET out_int = 
        byte_4 + 
        byte_3 * 256 + 
        byte_2 * 65536 + 
        byte_1 * 16777216;

    RETURN out_int;
END ; $$

CREATE FUNCTION ip_in_range(ip VARCHAR(15), ip_start VARCHAR(15), ip_end VARCHAR(15))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE ip_int INT(4) DEFAULT 0;
    DECLARE ip_start_int INT(4) DEFAULT 0;
    DECLARE ip_end_int INT(4) DEFAULT 0;

    IF ip IS NULL OR ip_start IS NULL OR ip_end IS NULL THEN
        RETURN FALSE;
    END IF;

    SET ip_int = ip_as_number(ip);
    SET ip_start_int = ip_as_number(ip_start);
    SET ip_end_int = ip_as_number(ip_end);

    RETURN ip_int BETWEEN ip_start_int AND ip_end_int;
END ; $$

CREATE FUNCTION ip_to_country(ip VARCHAR(15))
RETURNS CHAR(2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE country_code CHAR(2) DEFAULT '??';

    IF ip IS NULL OR
        RETURN country_code;
    END IF;

    SELECT r.country INTO country_code
    FROM ip_range r
    WHERE r.expire_time IS NULL AND r.expire_time IS NOT NULL AND ip_in_range(ip, r.ip_start, r.ip_end)
    ORDER BY r.creation_time DESC
    LIMIT 1;

    RETURN country_code;
END ; $$

CREATE TRIGGER ip_range_insert_validity_check
BEFORE INSERT ON ip_range
FOR EACH ROW
trigger_body:BEGIN

    IF NEW.creation_time > NEW.expire_time THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT_TEXT  = 'Cannot set creation_time > expire_time, record will be ignored and cancelled';
        SET NEW.creation_time = NULL;
    END IF;

    IF ip_as_number(NEW.ip_start) > ip_as_number(NEW.ip_end) THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT_TEXT  = 'Cannot set ip_start > ip_end, record will be ignored and cancelled';
        SET NEW.creation_time = NULL;
    END IF;


    -- Checks if there have been warnings
    IF NEW.creation_time IS NULL THEN
        LEAVE trigger_body;
    END IF;

    -- Check if record already exists
    IF EXISTS (
        SELECT * 
        FROM ip_range r
        WHERE 
            r.ip_start = NEW.ip_start AND 
            r.ip_end = NEW.ip_end AND 
            r.country = NEW.country AND 
            r.expire_time IS NULL AND
            r.creation_time < NEW.creation_time) THEN
        
        -- Valid record already present, we leave it unaltered
        SET NEW.creation_time = NULL;
        LEAVE trigger_body;
    END IF;

    -- An old record "breaks" this one but the old one has higher priority
    IF NEW.expire_time IS NOT NULL AND EXISTS (
        SELECT * 
        FROM ip_range r
        WHERE 
            NEW.creation_time  < r.creation_time AND 
            (
                r.expire_time IS NULL OR NEW.expire_time < r.expire_time
            ) AND
            (
                ip_in_range(NEW.ip_start, r.ip_start, r.ip_end) OR
                ip_in_range(NEW.ip_end, r.ip_start, r.ip_end)
            )
        ) THEN
        
        -- Discard the new record has there is an existing one overlapping with more priority
        SET NEW.creation_time = NULL;
        LEAVE trigger_body;
    END IF;

    -- If new record "breaks" an old one (that has less importance) we set the old one to expired
    UPDATE ip_range
    SET expire_time = NEW.creation_time
    WHERE 
        (
            -- Collision on NEW.creation_time is between creation_time and expire_time
            -- expire_time = NULL means not yet expired
            expire_time IS NULL OR 
            expire_time > NEW.creation_time
        ) 
        AND creation_time < NEW.creation_time AND
        (
            ip_in_range(NEW.ip_start, ip_start, ip_end) OR
            ip_in_range(NEW.ip_end, ip_start, ip_end)
        );
    
END ; $$


CREATE TRIGGER ip_range_update_validity_check
BEFORE UPDATE ON ip_range
FOR EACH ROW
trigger_body:BEGIN
    DECLARE error_occured BOOLEAN DEFAULT FALSE;

    IF NEW.creation_time > NEW.expire_time THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT_TEXT  = 'Cannot set creation_time > expire_time, changes will be ignored';
        SET error_occured = TRUE;
    END IF;

    IF ip_as_number(NEW.ip_start) > ip_as_number(NEW.ip_end) THEN
        SIGNAL SQLSTATE '01000'
            SET MESSAGE_TEXT_TEXT  = 'Cannot set ip_start > ip_end, changes will be ignored';
        SET error_occured = TRUE;
    END IF;

    -- Checks if there have been warnings
    IF error_occured THEN
        -- Set the NEW record to be the same as the OLD one
        SET NEW.creation_time = OLD.creation_time;
        SET NEW.expire_time = OLD.expire_time;
        SET NEW.ip_start = OLD.ip_start;
        SET NEW.ip_end = OLD.ip_end;

        -- We can leave
        LEAVE trigger_body;
    END IF;

    -- Check if record already exists
    IF EXISTS (
        SELECT * 
        FROM ip_range r
        WHERE 
            r.ip_start = NEW.ip_end AND 
            r.ip_end = NEW.ip_end AND 
            r.country = NEW.country AND 
            r.expire_time IS NULL AND
            r.creation_time < NEW.creation_time) THEN
        
        -- Valid record already present, we leave it unaltered
        SET NEW.creation_time = NULL;
        LEAVE trigger_body;
    END IF;

    -- An old record "breaks" this one but the old one has higher priority
    IF NEW.expire_time IS NOT NULL AND EXISTS (
        SELECT * 
        FROM ip_range r
        WHERE 
            NEW.creation_time  < r.creation_time AND 
            (
                r.expire_time IS NULL OR NEW.expire_time < r.expire_time
            ) AND
            (
                ip_in_range(NEW.ip_start, r.ip_start, r.ip_end) OR
                ip_in_range(NEW.ip_end, r.ip_start, r.ip_end)
            )
        ) THEN
        
        -- Discard the new record has there is an existing one overlapping with more priority
        SET NEW.creation_time = NULL;
        LEAVE trigger_body;
    END IF;

    -- If new record "breaks" an old one (that has less importance) we set the old one to expired
    UPDATE ip_range
    SET expire_time = NEW.creation_time
    WHERE 
        (
            -- Collision on NEW.creation_time is between creation_time and expire_time
            -- expire_time = NULL means not yet expired
            expire_time IS NULL OR 
            expire_time > NEW.creation_time
        ) 
        AND creation_time < NEW.creation_time AND
        (
            ip_in_range(NEW.ip_start, ip_start, ip_end) OR
            ip_in_range(NEW.ip_end, ip_start, ip_end)
        );
    
END ; $$


CREATE EVENT ip_range_cleanup
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATETIME
DO
    DELETE 
    FROM ip_range
    WHERE 
        ip_range.creation_time IS NULL OR ip_range.country = '??';
END ; $$

DELIMITER ;