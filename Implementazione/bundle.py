files = [
    'AreaContenuti.sql',
    'AreaFormato.sql',
    'AreaUtenti.sql',
    'AreaStreaming.sql',

    '../Analytics/BilanciamentoCarico.sql',
    '../Analytics/Classifica.sql',
    '../Analytics/Custom.sql',
    '../Analytics/RaccomandazioneContenuti.sql',
    '../Analytics/Rating.sql',
    '../Analytics/RatingUtente.sql',

    '../Streaming/CachingPrevisionale.sql',
    '../Streaming/IndividuazioneServer.sql',
    '../Streaming/RibilanciamentoCarico.sql'
]

def bundle():
    with open('Bundle.sql', 'w') as out:
        for file in files:
            with open(file, 'r') as file:
                for line in file:
                    out.write(line)
            out.write('\n\n')

if __name__ == '__main__':
    bundle()