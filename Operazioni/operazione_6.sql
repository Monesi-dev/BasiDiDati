USE `FilmSphere`;

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