
-- Operazione 1
CALL VinciteDiUnFilm(1); 
CALL VinciteDiUnFilm(2); 
CALL VinciteDiUnFilm(14); 
CALL VinciteDiUnFilm(10); 
CALL VinciteDiUnFilm(20); 
CALL VinciteDiUnFilm(30); 
CALL VinciteDiUnFilm(33); 
CALL VinciteDiUnFilm(61); 


-- Operazione 2 
CALL GeneriDiUnFilm(10, 'adiQ');
CALL GeneriDiUnFilm(11, 'adinaa7');
CALL GeneriDiUnFilm(12, 'adiey');
CALL GeneriDiUnFilm(13, 'adeyh');
CALL GeneriDiUnFilm(24, 'adenVA8p');
CALL GeneriDiUnFilm(32, 'adrianbz');
CALL GeneriDiUnFilm(43, 'adrisJFr6');
CALL GeneriDiUnFilm(56, 'adoreVd');
CALL GeneriDiUnFilm(61, 'adoreedx1');
CALL GeneriDiUnFilm(75, 'adon6');
CALL GeneriDiUnFilm(82, 'adonisX');
CALL GeneriDiUnFilm(91, 'adeTe9W');


-- Operazione 3
CALL FileMiglioreQualita(3, 'adiQ');
CALL FileMiglioreQualita(15, 'adinaa7');
CALL FileMiglioreQualita(24, 'adiQ');
CALL FileMiglioreQualita(39, 'adiQ');
CALL FileMiglioreQualita(41, 'adinaa7');
CALL FileMiglioreQualita(53, 'adonisX');
CALL FileMiglioreQualita(68, 'adonisX');
CALL FileMiglioreQualita(73, 'adon6');
CALL FileMiglioreQualita(84, 'adon6');
CALL FileMiglioreQualita(95, 'adiQ');


-- Operazione 4 
CALL FilmEsclusiAbbonamento('Basic', @n); SELECT @n;
CALL FilmEsclusiAbbonamento('Deluxe', @n); SELECT @n;
CALL FilmEsclusiAbbonamento('Premium', @n); SELECT @n;
CALL FilmEsclusiAbbonamento('Pro', @n); SELECT @n;
CALL FilmEsclusiAbbonamento('Ultimate', @n); SELECT @n;


-- Operazione 5 
CALL FilmDisponibiliInLinguaSpecifica('Italiano');
CALL FilmDisponibiliInLinguaSpecifica('Inglese');
CALL FilmDisponibiliInLinguaSpecifica('Tedesco');
CALL FilmDisponibiliInLinguaSpecifica('Francese');
CALL FilmDisponibiliInLinguaSpecifica('Polacco');


-- Operazione 6
CALL FilmPocoPopolari('adiQ', 3);
CALL FilmPocoPopolari('aarikap', 3.4);
CALL FilmPocoPopolari('aartjann', 4.3);
CALL FilmPocoPopolari('abbe8', 3);
CALL FilmPocoPopolari('abbey6T', 3);
CALL FilmPocoPopolari('abbin', 5);
CALL FilmPocoPopolari('abbyk', 4.3);
CALL FilmPocoPopolari('abdalla5e', 3.6);
CALL FilmPocoPopolari('abdulRNc', 4.5);
CALL FilmPocoPopolari('aarushiIw', 3.8);


-- Operazione 7 
CALL CambioAbbonamento('abbyk', 'Premium');
CALL CambioAbbonamento('abbyk', 'Deluxe');
CALL CambioAbbonamento('abbe8', 'Pro');
CALL CambioAbbonamento('abbe8', 'Basic');
CALL CambioAbbonamento('abraLH', 'Pro');
CALL CambioAbbonamento('abraLH', 'Basic');


-- Operazione 8 
SELECT * FROM FilmMiglioriRecensioni;





