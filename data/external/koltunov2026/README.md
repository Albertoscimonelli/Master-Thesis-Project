# Database delle CER italiane (Koltunov et al. 2026)

Serve a costruire l'asse "imprese" (`CER_configuration_IND/`) su numeri di CER reali, non a
occhio. Il database **non è nel progetto**: il repository non dichiara una licenza, quindi qui
c'è solo lo script che lo legge.

## Fonte

- **[K26]** Koltunov, M., Beltrami, F., Grossi, L., Blasuttigh, N. (2026). *Impact of renewable
  energy communities on the Italian day-ahead electricity market: A scenario analysis*. Energy
  Policy, 218, 115518. doi:10.1016/j.enpol.2026.115518. Preprint: arXiv:2510.13517v3.
- **[DB]** https://github.com/maksym-koltunov/energy-communities-Italy, file
  `CER database 2025 PUBLIC.xlsm`, foglio `Main CERs`. Dati aggiornati a gennaio 2025; versione
  letta: commit `7560715` (27/08/2026).

## Come riprodurre

```
git clone https://github.com/maksym-koltunov/energy-communities-Italy.git
python -I data/external/koltunov2026/analisi_database_cer.py "energy-communities-Italy/CER database 2025 PUBLIC.xlsm"
```

Il file si apre in sola lettura e senza eseguire la macro. I numeri numerati qui sotto sono quelli
stampati dallo script (stessa numerazione).

## Cosa dice, e come va letto

| # | Dato | Valore | Lettura |
|---|---|---|---|
| 1 | CER nel database | 384 righe (362 nel paper), 231 nella zona Nord | 177 sono in progetto, non operative; molti dati vengono dai business plan |
| 2 | Membri per CER, Nord | n=181: mediana 17, quartili 6 / 17 / 128; 76 sotto 15, 17 tra 15 e 18, 10 tra 19 e 25, 78 oltre 25 | le nostre schede da 15-25 membri sono attorno alla mediana |
| 3 | Tetti prosumer ÷ membri, Nord (calcolato da noi) | n=64: mediana 0,28; quartili 0,10 / 0,28 / 0,50; 9° decile 0,85; **83% delle CER ≤ 0,50** | nella grande maggioranza delle CER i prosumer non superano metà dei membri, ma non sempre (circa 1 su 6 sì). Un tetto non è un POD: un comune prosumer può avere più punti di prelievo |
| 4 | Imprese prosumer (PMI + NPO) per CER, Nord, dove presenti | 1: 18 CER, 2: 10, 3: 2, 4: 3, 5: 2, 6 o più: 3 | 1-2 imprese nel 74% dei casi: da qui i livelli ND1-ND3 |
| 5 | PA prosumer per CER, Nord, dove presenti | 1: 19, 2: 8, 3: 6, 4: 5, 5: 1, 6 o più: 10 | PA1-PA3 coprono il 67% dei casi |
| 6 | CER Nord con PA e imprese prosumer insieme | 14; PA 1-3 in 12, imprese 1-2 in 11 | le comunità miste esistono ma sono meno frequenti di quelle con una sola categoria di enti |
| 7 | Quota della potenza FV per categoria, Nord (n=103) | pubblico 41,5 / residenziale 11,2 / PMI 16,6 / NPO 9,1 / standalone 21,5% | sono medie su **tutte** le CER, zeri compresi (nota 38 di [K26]). Dove una categoria c'è, in media vale il 52-76%; 67 CER su 103 hanno una sola categoria. Il paper (Eq. 7) la descrive invece come media sulle sole CER dove la categoria è presente: incoerenza |
| 8 | kWp FV per membro, CER Nord da 15-25 membri | n=24: quartili 1,95 / 5,84 / 22,3 | scala per confrontare le nostre schede (vedi `CER_configuration_IND/README.md`) |
| 9 | Potenza media di un impianto, Nord ([K26] Fig. 7) | pubblico 122,4; residenziale 5,3; PMI 107; NPO 46,1; standalone 466,5 kW | conferma l'ordine di grandezza dei kWp stimati per famiglie e imprese |
| 10 | Edifici prosumer medi per CER (Italia) | pubblico 4,4; residenziale 17,7; PMI 2,3; NPO 2,3; standalone 1,7 | medie sulle sole CER che hanno la categoria; contano solo i prosumer, **non** i consumatori: non sono quote di membri. Incoerenza del paper: 17,7 × 36 CER ≈ 637 case, contro 949 in Fig. 8 |
| 11 | Autoconsumo dichiarato | n=82, media 49,1%, quartili 50 / 50 / 50 | quasi sempre un 50% fissato nei business plan: **non è una misura** e non va usato come riferimento |

Altre informazioni del paper usate nel progetto:

- **Tipi di CER** (lettura della colonna di testo sui membri, CER del Nord da 8 a 60 membri):
  ricorrono (a) CER di soli enti (comuni, parrocchie, associazioni), (b) 1-2 enti o imprese
  prosumer con 8-44 famiglie consumatrici, (c) famiglie con pochi prosumer domestici. Il tipo (a)
  non si costruisce con le nostre schede, che partono sempre da famiglie.
- **Regole CACER** ([K26] App. B, p. 44): tariffa premio fissa 80 / 70 / 60 €/MWh per impianti
  fino a 200 kW, tra 200 e 600 kW e oltre 600 kW, più max(0; 180 − Pz), con tetti 120 / 110 /
  100 €/MWh. Lo scaglione unico del progetto (riferimento 100 kW) sovrastima quindi di circa
  10 €/MWh l'energia condivisa degli impianti tra 200 e 600 kW (palazzetto, 310,5 kWp).
- **Imprese** ([K26] p. 41 e nota 39): premio dimezzato per le PMI che hanno anche il contributo in
  conto capitale (coerente con il fattore F del progetto); grandi imprese e imprese del settore
  energia non possono essere membri.

## Limiti

Campioni piccoli (64 CER per il punto 3, 24 per il punto 8), metà delle CER solo in progetto, dati
dichiarati dai promotori, categorie assegnate dagli autori del database, celle vuote che possono
voler dire "assente" o "non noto".
