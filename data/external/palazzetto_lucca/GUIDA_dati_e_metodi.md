# Palazzetto dello Sport di Lucca: fonti, consumi e produzione FV

Ultimo aggiornamento: 16 ottobre 2026 (CSV FV con colonna `origine`, ore a zero riempite, serie riscalata alla tabella mensile del progetto).
Scopo: documentare da dove vengono i dati e come sono state costruite le curve orarie 2024 di **consumo** e di **produzione fotovoltaica**, con affidabilità e limiti.

**Perimetro:** si usano solo i dati del palazzetto di Lucca. I dati ENEA della palestra "Volley" e il relativo input RAMP sono stati scartati.

Due oggetti diversi:
- **consumo** = edificio **esistente** (dati misurati 2024, letti dai grafici della diagnosi);
- **produzione FV** = impianto del **nuovo** palazzetto (progetto, non esiste oggi).

Il loro confronto (autoconsumo) è quindi indicativo.

---

## 1. Fonti dei dati

| # | Fonte | Cosa ne è stato preso |
|---|---|---|
| 1 | **Diagnosi energetica – Palazzetto dello Sport, Via delle Tagliate, Lucca**, codice 047.24.01.R.01, nov. 2025 (file `2706_F_00_SF_IM00_D_17_000-0_01_02 - Diagnosi energetica - Edificio esistente.pdf`, 249 pagine) | Un solo POD in MT (448 kW, 15 kV). Consumo 2024: **290,136 MWh**, cioè 290.136 kWh in notazione italiana (punto come separatore delle migliaia). 350 giorni di apertura, 3.378 m² climatizzati e 7.894 m² non climatizzati, circa 1.500 posti. Nessuna sottomisura. Riscaldamento a gas, nessun raffrescamento. Illuminazione: 18,56 kW interni + 8 kW esterni. Fig. 2 (energia mensile), Fig. 3 (massimo e minimo giornalieri), Fig. 4 (settimana tipo 22–28 gennaio 2024). Cap. 12.1: progetto del nuovo palazzetto con FV da 310,5 kWp. Tabella di producibilità a pag. 246 del PDF (numerata 245/249). |
| 2 | Comune di Lucca, *IE FV – Relazione tecnica impianto fotovoltaico*, progetto esecutivo PE Silver 1 (approvato 2026): https://allegatiatti.comune.lucca.it/Anno%202026/PALALUCCA/PE%20SILVER%201-APPROVATO/PDF/05_Impianti/ELT/IE_FV_RELAZIONE_TECNICA_IMPIANTO_FOTOVOLTAICO.pdf | 134,4 kWp (224 moduli da 600 Wp), 2 inverter da 80 kW, 144.337,03 kWh/anno. **Letto tramite un riassunto automatico della pagina, non il PDF intero**: da ricontrollare sul documento. |
| 3 | **PVGIS** (Commissione Europea, JRC), file forniti dall'utente: `tmy_43.844_10.489_2005_2023.csv` (anno tipico orario), `PVdata_43.844_10.489_SA3_crystSi_310kWp_14_15deg_0deg.csv` (medie mensili, PVGIS-SARAH3) e il relativo PDF `PVGIS-5_GridConnectedPV_...310kWp_14_15deg_0deg.pdf` | Meteo orario a Lucca (43,844 N, 10,489 E, 16 m). Produzione mensile media per 310 kWp, 15° di inclinazione, azimut 0 (sud), perdite 14%: **391.231,88 kWh/anno**. |
| 4 | Libreria **pvlib** 0.16.1 | Posizione solare, trasposizione sul piano dei moduli, temperatura di cella, perdite per angolo di incidenza. |

PVGIS online non era raggiungibile dalla sessione di lavoro: i dati PVGIS sono quelli scaricati dall'utente.

Una tabella mensile in immagine (totale 393.508,71 kWh) fornita dall'utente senza indicazione della fonte è stata **scartata**: non se ne conosce la provenienza.

---

## 2. Costruzione del carico (consumo 2024)

La diagnosi non contiene tabelle orarie, ma **grafici** del consumo misurato. Li ho letti come immagini.

1. **Estrazione.** Le immagini sono state estratte dal PDF con `pdfimages`; gli assi sono stati calibrati sulle linee della griglia e i pixel blu convertiti in kW.
2. **Energia mensile (Fig. 2).** Altezze delle 12 barre lette in pixel e convertite in MWh, poi scalate in modo che la somma sia esattamente **290,136 MWh**.
3. **Inviluppo giornaliero (Fig. 3).** Massimo e minimo di ogni giorno dell'anno, letti dal grafico. Il minimo di 1 kW indica un'interruzione del grafico ed è stato sostituito con la mediana mobile a 7 giorni. I picchi serali risultavano assegnati al giorno dopo, quindi ho applicato uno **sfasamento di +0,2 giorni**, tarato sulla settimana nota.
4. **Forma giornaliera (Fig. 4).** Dalla settimana 22–28 gennaio 2024 ho ricavato tre profili normalizzati tra 0 e 1: feriale (media lun–ven), sabato, domenica.
5. **Ricostruzione.** Per ogni giorno: `P(h) = min + (max − min) · s(h)^γ`, con `s(h)` il profilo del tipo di giorno. L'esponente γ è scelto **mese per mese** in modo che l'energia mensile coincida con quella di Fig. 2. Una prima versione scalava l'ampiezza ma dava un picco di 123 kW (oltre i 117 letti), ed è stata scartata.
6. **Uscita.** 8.784 righe orarie (2024 è bisestile): `lucca_anno_2024_ricostruito_kW.csv`.

**Verifica (settimana 22–28 gennaio, l'unica con dati orari noti):**
- Scarto quadratico medio 8,6 kW, circa il 20% del carico medio di 42 kW; correlazione 0,94.
- Energia della settimana: 7,54 MWh ricostruiti contro 7,13 letti (+5,8%); errori giornalieri da −35 a +117 kWh.
- La verifica è **ottimistica**: la stessa settimana fornisce forma e sfasamento.
- Prima della calibrazione la ricostruzione grezza è entro circa il 6% da settembre ad aprile e **sopra dell'8–13% da maggio ad agosto**.
- Picco ricostruito 114 kW contro circa 117 letti.
- Fermo estivo visibile dal 21 luglio al 19 agosto.

| Aspetto | Affidabilità |
|---|---|
| Energia mensile e annua | Alta |
| Massimo e minimo di ogni giorno | Buona (precisione di pixel; ±1 giorno di rischio fuori dalla settimana tarata) |
| Forma oraria dentro il giorno | Media (una sola settimana di gennaio ripetuta tutto l'anno) |
| Mesi estivi | Più bassa |

Non è adatta a dimensionare FV, accumuli o CER. Per quello servono i **dati orari o quartorari veri del POD**, richiedibili al distributore tramite il Comune.

---

## 3. Costruzione della produzione fotovoltaica

### 3.1 Impianto di riferimento
- **Impianto da 310 kWp**, confermato dall'utente. La diagnosi (nov. 2025) indica 690 moduli da 450 W = 310,5 kWp, inverter 2×110 kW + 1×50 kW (270 kW AC); il calcolo PVGIS usa 310 kWp.
- Inclinazione e orientamento non sono nella diagnosi: ho usato quelli dei file PVGIS dell'utente, **15° verso sud**.
- Il progetto esecutivo del Comune (fonte 2) riporta 134,4 kWp: è un impianto diverso e **non è stato usato**.

### Scelta della tabella mensile
Tre tabelle disponibili per 310 kWp:

| Tabella | Energia annua | Giudizio |
|---|---|---|
| **Diagnosi, pag. 246 (stima del progetto)** | 398,9 MWh | **Scelta (versione finale del 16 ottobre).** È la stima del progetto: riscalare la serie a questa tabella rende la produzione direttamente paragonabile al progetto. Non dichiara inclinazione, orientamento né software, quindi non è riproducibile da noi. |
| PVGIS-SARAH3 (file dell'utente) | 391,2 MWh | Usata nella prima versione. Banca dati documentata, parametri noti (15° sud, perdite 14%), riproducibile. Il calcolo fisico dal TMY la riproduce entro −0,7% sull'anno. Ora è solo termine di confronto: rispetto alla diagnosi ha gennaio +14%, febbraio +16%, luglio −10%, totale −1,9%. |
| Immagine dell'utente | 393,5 MWh | Fonte sconosciuta: scartata. |

Tabella mensile della diagnosi (usata), kWh: 14.981 / 18.123 / 30.637 / 39.105 / 48.531 / 50.630 / 57.040 / 47.291 / 37.519 / 25.850 / 16.199 / 12.996.
Tabella PVGIS-SARAH3 (confronto), kWh: 17.055 / 21.095 / 31.853 / 38.530 / 44.377 / 47.441 / 51.569 / 45.980 / 35.984 / 26.275 / 16.736 / 14.336.

### 3.2 Metodo (script `scripts/lucca_pv_tmy.py`)
1. **Meteo.** TMY orario PVGIS: irraggiamento globale orizzontale G(h), diretto normale Gb(n), diffuso Gd(h), temperatura, vento. Ogni mese del TMY proviene da un anno diverso (gen 2021, feb 2006, mar 2006, apr 2017, mag 2021, giu 2011, lug 2015, ago 2014, set 2012, ott 2012, nov 2017, dic 2014).
2. **Istante di riferimento.** Lo scarto temporale che chiude meglio G = Gb·cos(zenit) + Gd è **0,2 h** (errore medio 1 W/m²), in accordo con l'offset dichiarato dal file (0,1747 h).
3. **Piano dei moduli.** Modello Hay-Davies, 15° di tilt, azimut sud, albedo 0,2.
4. **Potenza.** Perdite per angolo di incidenza (IAM ASHRAE b = 0,05), temperatura di cella con modello Faiman (u0 = 25, u1 = 6,84; vento a 10 m × 0,75), coefficiente −0,4%/K, perdite di sistema 14%.
5. **Controllo contro PVGIS.** Il mio calcolo dà **388.464 kWh/anno** contro 391.232 di PVGIS (−0,7%). Rapporto mensile da 0,84 (marzo) a 1,09 (luglio): normale, perché ogni mese del TMY è un anno specifico e non la media di lungo periodo.
6. **Calendario 2024.** Ogni ora di orologio italiano del 2024 (con ora legale, ultima domenica di marzo e di ottobre) è riportata all'istante UTC e presa dalla riga TMY con lo stesso mese, giorno e ora. Il 29 febbraio usa i dati del 28.
7. **Riscalatura mensile.** Ogni mese è moltiplicato per un fattore costante in modo che la sua energia coincida con la tabella mensile della diagnosi (stima del progetto). Verificato sul file: le somme mensili coincidono con la tabella entro l'arrotondamento al kWh. La prima versione era riscalata a PVGIS-SARAH3 (fattori da 0,92 a 1,19).
8. **Limite degli inverter.** Il picco arriva a 280,2 kW contro 270 kW di inverter. Le ore sopra 270 kW sono 4 e l'energia oltre il limite è circa 15 kWh/anno: **non ho applicato il taglio**.
9. **Ore diurne a zero e colonna `origine`.** Nella prima versione 21 ore diurne risultavano a 0 kW per un buco nel TMY (tra cui quasi tutto il 2 dicembre dalle 10 alle 15). Sono state riempite e marcate `tmy_riempito`; ogni mese è stato poi riscalato alla tabella della diagnosi (le somme mensili coincidono con essa). Il 29 febbraio, copia del 28, è marcato `copia_28feb` (24 righe, dalle 01:00 del 29 febbraio alle 00:00 del 1° marzo). Le altre 8.739 righe sono `tmy`. *Il criterio esatto di riempimento delle 21 ore non è nella guida: da confermare dall'autore.*

**Uscita:** `lucca_pv_2024_kW.csv`, 8.784 righe, colonne `datetime` (ora di orologio italiana, 2024), `pv_kW` e `origine` (`tmy` / `tmy_riempito` / `copia_28feb`). Energia annua 398.902 kWh (come la tabella del progetto), picco 280,2 kW, 4.320 ore con produzione sopra 0,5 kW. Grafico: `lucca_pv_2024.png` (non nel repository).

### 3.3 Limiti
- Il TMY è un **anno tipico**, non il 2024: i giorni nuvolosi non cadono nelle date reali.
- Non ho modellato l'ombreggiamento da orizzonte (PVGIS lo calcola nel suo report).
- 21 ore (0,2% delle ore) sono riempite e non calcolate: pesano meno dello 0,1% dell'energia annua ma vanno escluse da analisi che guardano la singola ora.
- La serie è riscalata mese per mese alla stima del progetto, quindi ne eredita totali mensili e forma stagionale. Dentro ogni mese la forma oraria viene dal TMY: lo scarto con la serie PVGIS della prima versione si vede solo nei totali mensili, non nella forma del giorno. Il riscalamento mensile può spingere singole ore oltre la potenza degli inverter (280 kW contro 270).

---

## 4. Autoconsumo (primo risultato)

Confronto ora per ora tra consumo ricostruito e produzione FV:
- circa il **30%** dell'energia FV sarebbe consumata in sito;
- il FV coprirebbe circa il **40%** del consumo annuo;
- il carico sta tra circa 10 e 60 kW, il FV arriva fino a circa 280 kW: l'eccedenza in rete è grande.

Indicativo: il carico è ricostruito e riguarda l'edificio esistente, mentre l'impianto è per il nuovo.

---

## 5. Punti aperti

1. **Dati veri:** chiedere al Comune di Lucca la curva oraria o quartoraria del POD (anno 2024) sostituirebbe la ricostruzione dei consumi.
2. **Inclinazione e orientamento reali dei moduli** (non sono nella diagnosi): verificarli nel progetto cambierebbe poco il totale, ma può cambiare la forma oraria.
3. Errori trovati e corretti lungo il percorso: avevo scambiato "290.136" per un errore di unità, ma è notazione italiana (290,136 MWh = 290.136 kWh); una prima sintesi automatica dell'illuminazione era sbagliata (valori corretti: 18,56 kW interni + 8 kW esterni).

---

## 6. File

| File | Contenuto |
|---|---|
| `lucca_settimana_22_28_gen_2024_kW.csv` | Settimana tipo letta dalla Fig. 4 |
| `originali_2024/lucca_anno_2024_ricostruito_kW.csv` | **Consumo orario 2024 ricostruito** (8.784 righe, kW). La versione allineata alla pipeline è `palazzetto_lucca_carico.csv` (8.760 righe, griglia 2025, ora standard) |
| `lucca_anno_2024_ricostruito.png` | Mappa giorno × ora e verifica sulla settimana (non nel repository) |
| `originali_2024/lucca_pv_2024_kW.csv` | **Produzione FV oraria 2024** (8.784 righe, kW, con colonna `origine`). La versione allineata alla pipeline è `palazzetto_lucca_FV.CSV` (8.760 righe, ora standard, senza 29 febbraio) |
| `lucca_pv_2024.png` | Produzione FV e confronto con il carico (non nel repository) |
| `scripts/` | Script Python usati (nel repository decompressi; la guida originale li dava in `scripts_lucca.zip`) |

| Script | Funzione |
|---|---|
| `lucca_year.py` | Ricostruzione annua del carico |
| `plot_lucca_year.py` | Grafico del carico |
| `lucca_pv_tmy.py` | Produzione FV da TMY |
| `plot_lucca_pv_tmy.py` | Grafico della produzione FV |

Gli script del carico leggono file intermedi estratti dal PDF (inviluppo giornaliero, settimana tipo) che non sono nello zip: per rifare il carico da zero servono i grafici originali.

Esempio per rifare la curva FV:
```
pip install pvlib pandas numpy matplotlib
python lucca_pv_tmy.py tmy_43.844_10.489_2005_2023.csv <cartella_output>
python plot_lucca_pv_tmy.py <cartella_con_i_file> grafico.png <cartella_output>/lucca_pv_2024.npy
```
Il grafico richiede anche `lucca_year_P.npy` (carico), prodotto da `lucca_year.py`, nella cartella indicata.

---

## 7. Riferimenti

- Comune di Lucca, Diagnosi energetica del Palazzetto dello Sport (cod. 047.24.01.R.01, nov. 2025): Fig. 2, 3, 4, cap. 7.3, cap. 12.1, tabella FV a pag. 246.
- Comune di Lucca, progetto esecutivo PE Silver 1, relazione tecnica FV (link nella fonte 2).
- PVGIS, Commissione Europea, JRC: https://re.jrc.ec.europa.eu/pvg_tools/en/ (PVGIS-SARAH3, TMY 2005–2023).
- pvlib python (Hay-Davies, Faiman, IAM ASHRAE, posizione solare).
