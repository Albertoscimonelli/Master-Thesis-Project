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

## Palazzetto dello sport di Lucca (consumo e produzione FV 2024)

Cartella: [`data/external/palazzetto_lucca/`](data/external/palazzetto_lucca/). Metodo completo,
affidabilità e limiti: [`GUIDA_dati_e_metodi.md`](data/external/palazzetto_lucca/GUIDA_dati_e_metodi.md).
Script: [`scripts/`](data/external/palazzetto_lucca/scripts/). **Non sono ancora letti da
`MAIN2.m`**: sono dati archiviati con la loro documentazione.

Perimetro: solo il palazzetto di Lucca. I dati ENEA della palestra "Volley" e il relativo
input RAMP sono stati scartati.

[LUCCA-DIAGNOSI] Comune di Lucca, *Diagnosi energetica – Palazzetto dello Sport, Via delle
Tagliate, Lucca*, cod. 047.24.01.R.01, novembre 2025 (edificio esistente). Un solo POD in MT
(448 kW, 15 kV); consumo 2024 di 290,136 MWh (290.136 kWh, notazione italiana); Fig. 2
(energia mensile), Fig. 3 (massimo e minimo giornalieri), Fig. 4 (settimana tipo
22-28 gennaio 2024); cap. 12.1 (nuovo palazzetto, FV da 310,5 kWp; tabella di producibilità
a pag. 246 del PDF: **usata** come bersaglio mensile della produzione FV).

[LUCCA-PE] Comune di Lucca, *IE FV – Relazione tecnica impianto fotovoltaico*, progetto
esecutivo PE Silver 1 (approvato 2026):
https://allegatiatti.comune.lucca.it/Anno%202026/PALALUCCA/PE%20SILVER%201-APPROVATO/PDF/05_Impianti/ELT/IE_FV_RELAZIONE_TECNICA_IMPIANTO_FOTOVOLTAICO.pdf
134,4 kWp: impianto diverso da quello a 310 kWp, **non usato**. Letto tramite un riassunto
automatico della pagina e non sul PDF intero: da ricontrollare prima di citarlo.

[PVGIS] Commissione Europea, JRC, PVGIS 5 (banca dati PVGIS-SARAH3; TMY 2005-2023, Lucca
43,844 N 10,489 E): https://re.jrc.ec.europa.eu/pvg_tools/en/. File scaricati dall'autore;
tabella mensile per 310 kWp, 15° di inclinazione, azimut sud, perdite 14%: 391.231,88 kWh/anno
(termine di confronto: la serie finale è riscalata alla tabella della diagnosi).

[PVLIB] pvlib python 0.16.1 (posizione solare, Hay-Davies, Faiman, IAM ASHRAE).

Elaborazione nostra:
- **Consumo** (`lucca_anno_2024_ricostruito_kW.csv`, 8.784 righe orarie, kW). Non è una
  misura: è ricostruito leggendo come immagini i grafici della diagnosi (barre mensili,
  massimo e minimo giornalieri, settimana tipo), con `P(h) = min + (max − min)·s(h)^γ` e γ
  scelto mese per mese per riprodurre l'energia mensile. Energia annua 290.131 kWh, minimo
  9,9 kW, massimo 114,0 kW (circa 117 letti). Affidabilità: alta su energia mensile e
  annua, media sulla forma oraria (una sola settimana di gennaio ripetuta tutto l'anno),
  più bassa d'estate. Scarto quadratico medio sulla settimana nota 8,6 kW, correlazione
  0,94, verifica ottimistica perché la stessa settimana fornisce la forma.
- **Produzione FV** (`lucca_pv_2024_kW.csv`, 8.784 righe orarie, kW, colonna `origine`).
  TMY orario PVGIS portato sul piano dei moduli (310 kWp, 15° sud) con pvlib, mappato sul
  calendario 2024 con ora legale, ogni mese riscalato alla tabella mensile della diagnosi
  ([LUCCA-DIAGNOSI], pag. 246: 398.902 kWh/anno, stima del progetto, senza inclinazione né
  orientamento dichiarati). Energia annua 398.902 kWh, picco 280,2 kW. Scartata una tabella in
  immagine di fonte ignota (393,5 MWh). Rispetto a PVGIS-SARAH3 (391.232 kWh) la serie ha più
  inverno e meno estate: gennaio +14%, febbraio +16%, luglio −10%.
- Il FV è del **nuovo** palazzetto, il carico dell'edificio **esistente**: il confronto
  (circa 30% di autoconsumo, circa 40% di copertura) è indicativo.

Limiti noti:
1. Il carico non è adatto a dimensionare FV, accumuli o CER: servirebbero le curve orarie o
   quartorarie vere del POD, richiedibili al distributore tramite il Comune.
2. Il FV è un anno tipico, non il 2024: i giorni nuvolosi non cadono nelle date reali.
3. Inclinazione e orientamento reali dei moduli non sono nella diagnosi: si è usato 15° sud.
4. 21 ore diurne (colonna `origine` = `tmy_riempito`) sono riempite perché a zero nel TMY,
   24 righe del 29 febbraio sono la copia del 28 (`copia_28feb`). Il criterio di
   riempimento va confermato dall'autore.
5. I file in `data/external/palazzetto_lucca/` sono le serie **allineate alla pipeline** (8.760 ore,
   ora standard, FV senza 29 febbraio, carico su griglia 2025 a parità di giorno della settimana);
   gli originali 2024 sono in `originali_2024/`. Il passaggio è in
   `scripts/allinea_alla_pipeline.py`. Energie: FV 398.112 kWh (originale 398.902), carico 289.706
   kWh (originale 290.131).
6. Picco FV di 280,2 kW contro 270 kW di inverter, taglio non applicato (4 ore, circa 15 kWh/anno).

## CER italiane reali: composizione, taglia, imprese (Koltunov et al. 2026)

Cartella: [`data/external/koltunov2026/`](data/external/koltunov2026/README.md), con lo script
`analisi_database_cer.py` che stampa tutti i numeri citati. **Non sono dati delle schede**: servono a
scegliere quali composizioni simulare (README §7.11), in particolare i livelli 1-3 imprese di
`CER_configuration_IND/`.

[K26] Koltunov, M., Beltrami, F., Grossi, L., Blasuttigh, N. (2026). *Impact of renewable energy
communities on the Italian day-ahead electricity market: A scenario analysis*. Energy Policy, 218,
115518. doi:10.1016/j.enpol.2026.115518. Preprint arXiv:2510.13517v3 (citato per pagine e figure).

[DB] Database del paper: https://github.com/maksym-koltunov/energy-communities-Italy, file
`CER database 2025 PUBLIC.xlsm`, foglio `Main CERs`, dati a gennaio 2025, letto al commit `7560715`.
Il repository non dichiara licenza: il file **non è copiato** nel progetto, va clonato a parte.

Limiti noti:
1. Metà delle CER è in progetto (177 su 384 righe): i dati vengono spesso dai business plan.
2. Le quote di potenza FV per categoria della zona Nord (pubblico 41,5%, residenziale 11,2%,
   PMI 16,6%, NPO 9,1%, standalone 21,5%) sono medie su tutte le CER, zeri compresi, non sulle
   sole CER dove la categoria c'è come dice l'Eq. 7 del paper.
3. I numeri medi di edifici per CER (4,4 pubblici, 17,7 residenziali, 2,3 PMI, 2,3 NPO) contano
   solo i prosumer e solo dove la categoria c'è: non sono quote di membri. Il paper è incoerente
   sul residenziale (17,7 × 36 ≈ 637 contro 949 edifici in Fig. 8).
4. L'autoconsumo del 49,1% è quasi sempre un 50% dichiarato nei business plan (quartili 50/50/50):
   non è una misura.
5. Il rapporto prosumer/membri (83% delle CER del Nord ≤ 50%) è **calcolato da noi** su 64 CER,
   contando i tetti e non i POD.
