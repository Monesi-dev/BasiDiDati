-- RatingFilm
SELECT RatingFilm(1);
SELECT RatingFilm(21);
SELECT RatingFilm(51);
SELECT RatingFilm(92);
SELECT RatingFilm(76);
SELECT RatingFilm(10);
SELECT RatingFilm(37);
SELECT RatingFilm(43);
SELECT RatingFilm(3);
SELECT RatingFilm(13);
SELECT RatingFilm(95);
SELECT RatingFilm(26);
SELECT RatingFilm(20);
SELECT RatingFilm(60);
SELECT RatingFilm(98);
SELECT RatingFilm(47);
SELECT RatingFilm(66);
SELECT RatingFilm(71);
SELECT RatingFilm(14);
SELECT RatingFilm(18);
SELECT RatingFilm(35);
SELECT RatingFilm(34);
SELECT RatingFilm(96);
SELECT RatingFilm(53);
SELECT RatingFilm(56);
SELECT RatingFilm(15);
SELECT RatingFilm(82);
SELECT RatingFilm(31);
SELECT RatingFilm(24);
SELECT RatingFilm(75);
SELECT RatingFilm(81);

-- RatingUtente
SELECT RatingUtente(10, 'abbey6T');
SELECT RatingUtente(16, 'aarushiIw');
SELECT RatingUtente(17, 'aarikap');
SELECT RatingUtente(16, 'aarushiIw');
SELECT RatingUtente(17, 'abdalla5e');
SELECT RatingUtente(15, 'abbyk');
SELECT RatingUtente(11, 'aarenDDCY');
SELECT RatingUtente(16, 'abbye16');
SELECT RatingUtente(12, 'abbey6T');
SELECT RatingUtente(19, 'aaliyah1PcW');
SELECT RatingUtente(16, 'aaliyah1PcW');
SELECT RatingUtente(11, 'abbyk');
SELECT RatingUtente(13, 'aarushiIw');
SELECT RatingUtente(14, 'aaliyah1PcW');
SELECT RatingUtente(13, 'abbas3LjF');
SELECT RatingUtente(14, 'aarond0V');
SELECT RatingUtente(18, 'abbey6T');
SELECT RatingUtente(14, 'aarenDDCY');
SELECT RatingUtente(15, 'aarond0V');
SELECT RatingUtente(10, 'abbin');
SELECT RatingUtente(13, 'abbyk');
SELECT RatingUtente(14, 'aartjann');
SELECT RatingUtente(11, 'aaliyah1PcW');
CALL RaccomandazioneContenuti('abdalla5e', 10);
CALL RaccomandazioneContenuti('abagaelEq7RF', 17);
CALL RaccomandazioneContenuti('aarikap', 17);
CALL RaccomandazioneContenuti('abagaelEq7RF', 14);
CALL RaccomandazioneContenuti('abbin', 13);
CALL RaccomandazioneContenuti('abbin', 13);
CALL RaccomandazioneContenuti('abbyk', 13);


-- Custom Analytics -- Non deve uscire lo stesso nome
CALL MiglioreAttore();
CALL MiglioreRegista();

-- Classifica
CALL Classifica(10, 'IT', 'Basic', 2);
CALL Classifica(10, 'IT', 'Deluxe', 2);
CALL Classifica(10, 'DE', 'Pro', 2);
CALL Classifica(10, 'DE', 'Deluxe', 1);
CALL Classifica(10, 'DE', 'Premium', 1);
CALL Classifica(10, 'DE', 'Ultimate', 1);
CALL Classifica(10, 'US', 'Basic', 1);
CALL Classifica(10, 'US', 'Pro', 1);
CALL Classifica(10, 'US', 'Deluxe', 2);
CALL Classifica(10, 'US', 'Premium', 1);
CALL Classifica(10, 'US', 'Ultimate', 1);

-- BilanciamentoCarico (1m, 30s)
CALL BilanciamentoDelCarico(5, 5);




