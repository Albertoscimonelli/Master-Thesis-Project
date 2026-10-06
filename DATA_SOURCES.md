# Fonti dei dati

Registro delle fonti esterne usate per **compilare** le schede CER, con l'elaborazione
applicata a ciascuna. Le fonti usate per **generare o validare** i profili di carico
stanno in [CER_LoadProfiles/README.md](CER_LoadProfiles/README.md) e
[REPORT_VALIDAZIONE_LPG.md](REPORT_VALIDAZIONE_LPG.md).

Ogni riga dei file in [`data/external/`](data/external/) porta nella colonna `source_id`
l'identificativo della propria fonte. Lo stesso identificativo compare in ogni riga di
`[MEMBRI]` delle schede (`reddito_src`, `gas_src`).

## Reddito e spesa gas dei membri domestici

Script: [`CER_LoadProfiles/arricchisci_schede.py`](CER_LoadProfiles/arricchisci_schede.py).
Parametri: [`data/external/parametri_arricchimento.yaml`](data/external/parametri_arricchimento.yaml).
Mappatura archetipo → tipologia: [`docs/mapping_household_istat.md`](docs/mapping_household_istat.md).

[ISTAT-EUSILC] Istat, "Condizioni di vita e reddito delle famiglie - Anni 2024-2025"
(indagine EU-SILC), comunicato del 2 aprile 2026. Tavole: Eusilc-Tavole-e-Figure-
REPORT.xlsx, Prospetto 3 "Reddito netto familiare (esclusi gli affitti figurativi) per
caratteristiche della famiglia" (redditi 2024, ripartizione Nord-ovest, media e mediana).
https://www.istat.it/comunicato-stampa/condizioni-di-vita-e-reddito-delle-famiglie-anni-2024-2025/
Report: https://www.istat.it/wp-content/uploads/2026/03/REPORT-REDDITO-CONDIZIONI-DI-VITA.pdf
Tavole: https://www.istat.it/wp-content/uploads/2026/03/Eusilc-Tavole-e-Figure-REPORT.xlsx
Consultato il 06/10/2026.
Elaborazione nostra: perturbazione per singolo utente della media con gaussiana
troncata a ±15% (sigma 7,5%), scelta dell'autore per diversificare gli utenti, non
una statistica Istat.

- File: [`data/external/istat_eusilc_reddito_nordovest_2024.csv`](data/external/istat_eusilc_reddito_nordovest_2024.csv).
  Contiene media (usata) e mediana (solo riferimento, non entra nel calcolo).

[ARERA-CONSUMI-GAS] ARERA, "Analisi dei consumi dei clienti domestici" (gas naturale),
dataset dati_consumi_gas_2023-2024_zona_climatica.xlsx, anno termico ott 2023 - set 2024
(elaborazioni ARERA su dati SII). https://www.arera.it/dati-e-statistiche/dettaglio/analisi-dei-consumi-dei-clienti-domestici-gas
Elaborazione nostra: media su 12 mesi dei punti di prelievo domestici per classe di
consumo annuo, raggruppati in <=250, 250-500, >500 Smc/anno. Consultato il 06/10/2026.

- File: [`data/external/arera_quote_gas_2023_24.csv`](data/external/arera_quote_gas_2023_24.csv)
  (aree `lombardia` e `milano`; default `lombardia`).

[ARERA-PROFILI] ARERA, Comunicato operatori 4/9/2018, Delibera 366/2018/R/com
(profili "cottura e/o acqua calda sanitaria" a 120 e 480 Smc/anno; "riscaldamento" da
700 Smc/anno). https://www.arera.it/comunicati-operatore/dettaglio/it/comunicati/18/180904
Usato solo come riferimento per le soglie; la mappatura a 3 gruppi è un'assunzione
dell'autore.

## Come si calcolano i valori nella scheda

**Reddito** (`reddito_EUR`). Si legge l'archetipo LPG del membro e se ne ricava la classe
Istat. Poi `reddito_EUR = media_classe × f`, con `f` estratto da una gaussiana di media 1 e
σ = `SIGMA_FRACTION × INCOME_JITTER_PCT` = 0,5 × 0,15 = 0,075. La gaussiana è troncata a
[0,85; 1,15] **per riestrazione**, non per clipping, così che non si accumulino utenti
esattamente a ±15%. Il risultato è arrotondato all'euro.
Esempio: CHR16 (coppia over 65), media 45.366 €, f = 0,981774 → 44.539 €.

**Spesa gas** (`euro_gas`, sostituisce `gas_kWh`):
1. A ogni household vengono assegnate le tre quote ARERA dell'area (Lombardia: 32,0% /
   16,1% / 51,9%).
2. Ciascuna quota è moltiplicata per un fattore indipendente U(0,95; 1,05), e le tre quote
   sono riportate a somma 1.
3. Dalle quote così ottenute si estrae **una** categoria d'uso.
4. La spesa è il consumo rappresentativo della categoria × 10,70 kWh/Smc ×
   `prezzo_gas_EUR_kWh` di `CER_configuration/scenario_economico.txt` (0,120 €/kWh):
   - cottura: 120 Smc → 154 €
   - cottura + acqua calda: 480 Smc → 616 €
   - riscaldamento: 1.400 Smc → 1.798 €

**Riproducibilità.** Ogni estrazione ha un generatore proprio, con seed
`sha256(seed_base, nome_csv, campo)` e `campo` ∈ {`reddito`, `gas_quote`,
`gas_categoria`}. Lo stesso `household_k` riceve quindi gli stessi fattori e la stessa
categoria in tutte le schede, e rilanciare lo script riscrive le schede identiche al byte.
Nella scheda restano per ogni membro: valore base (`reddito_base_EUR`, `gas_quote_base`),
fattore (`reddito_f`, `gas_f`), risultato (`reddito_EUR`, `gas_quote`, `gas_categoria`,
`gas_Smc`, `euro_gas`) e fonte (`reddito_src`, `gas_src`).

**Le schede non sono versionate** (`.gitignore`, `CER_configuration/*`). Si rigenerano con:

    python CER_LoadProfiles/arricchisci_schede.py

Lo script compila solo le celle a `?` o quelle che aveva scritto lui stesso. Un dato vero
inserito a mano resta com'è, marcato `scheda`. Se il prezzo del gas in
`scenario_economico.txt` cambia, `euro_gas` va rigenerato.

## Assunzioni introdotte

Tutte modificabili in `parametri_arricchimento.yaml` o nella mappatura, senza toccare il
codice.

| # | ASSUNZIONE | Valore | Perché |
|---|---|---|---|
| A1 | Perturbazione del reddito | gaussiana σ = 7,5%, troncata a ±15% | diversificare gli utenti della stessa classe |
| A2 | Perturbazione delle quote gas | U(0,95; 1,05) per quota | idem |
| A3 | Soglie fra i tre usi del gas | 250 e 500 Smc/anno | euristica dell'autore: ARERA non definisce gli usi per classe di consumo |
| A4 | Consumo rappresentativo per uso | 120 / 480 / 1.400 Smc/anno | 120 e 480 sono i profili [ARERA-PROFILI]. 1.400 è la famiglia tipo per riscaldamento dei comunicati ARERA e coincide con i 15.000 kWh (~1.402 Smc) del house type LPG HT06/HT07, default precedente del modello |
| A5 | Conversione Smc → kWh | 10,70 kWh/Smc | potere calorifico superiore convenzionale 0,03852 GJ/Smc |
| A6 | Quote gas uguali per tutte le tipologie | stesse quote per ogni household | la fonte non distingue per tipologia; **nessuna** differenziazione per tipologia è stata introdotta |
| A7 | Archetipo LPG → classe Istat | vedi `docs/mapping_household_istat.md` | età e componenti dal catalogo LPG. CHR14, CHR15 e CHR19 in `altra_tipologia` su indicazione dell'utente; studenti CHR12 e CHR13 come persone sole |

## Limiti noti

1. Il reddito è quello della ripartizione **Nord-ovest** (Piemonte, Valle d'Aosta,
   Lombardia, Liguria), non della sola Lombardia.
2. La media Istat è più alta della mediana (Nord-ovest: 43.457 € contro 35.020 €), quindi i
   redditi assegnati sono mediamente superiori a quelli della famiglia "tipica" della
   classe.
3. La perturbazione gaussiana ±15% sul reddito e quella uniforme ±5% sulle quote gas sono
   sintetiche, non dispersione misurata.
4. Le quote gas sono indipendenti dalla tipologia di utente.
5. Le soglie 250/500 Smc sono euristiche.
6. A Milano la classe 1000-1250 Smc ha un'anomalia nei dati sorgente (non incide sul gruppo
   >500).

Limiti aggiuntivi emersi durante l'implementazione:

7. **Netto contro lordo.** Istat dà il reddito **netto**. La guida `CER_input.txt`
   descriveva `reddito_EUR` come "lordo", e la soglia di povertà y* = 10.052 €/percettore
   del Tri-level EP viene dal paper di riferimento. Il confronto con y* va letto sapendo
   che il reddito ora è netto.
8. **Gas e house type LPG non coincidono.** Tutti i profili LPG sono simulati con house
   type a riscaldamento a gas (HT06/HT07), ma con le quote ARERA circa metà delle famiglie
   risulta "solo cottura" o "cottura + acqua calda". La spesa gas segue ARERA, non il
   profilo simulato. Lo stesso vale per CHR58 ("no cooking"), che può ricevere la categoria
   "cottura" (oggi non la riceve).
9. **Tre soli livelli di spesa gas** (154 / 616 / 1.798 €): dentro una categoria tutte le
   famiglie spendono uguale. La perturbazione agisce sulla probabilità della categoria, non
   sul consumo.
10. **Sotto i 100 membri l'archetipo dichiarato nelle schede non è quello del profilo
    simulato** (dettagli in `docs/mapping_household_istat.md`). Il reddito segue
    l'archetipo dichiarato.
11. **Classe `coppia_3piu_figli`**: campione Istat piccolo e media molto sopra la mediana
    (72.138 € contro 58.688 €). È la stima meno affidabile.
