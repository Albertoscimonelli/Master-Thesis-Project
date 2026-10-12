# Mappatura household LPG → classe Istat

Questa tabella collega ogni archetipo LPG usato nelle schede `CER_configuration/CER_*.txt`
a una tipologia familiare del Prospetto 3 di Istat EU-SILC ([ISTAT-EUSILC] in
[DATA_SOURCES.md](../DATA_SOURCES.md)). Da quella classe dipende il **reddito base** che
`CER_LoadProfiles/arricchisci_schede.py` assegna a ogni membro domestico.
La versione letta dal codice è [`data/mapping_archetipo_istat.csv`](../data/mapping_archetipo_istat.csv).

## Da dove si legge la composizione di un household

La catena è in tre passi. Nessun campo è stato dedotto dal solo nome.

1. **Scheda CER**, sezione `[MEMBRI]`: per ogni `household_N_kWh` la colonna `archetipo`
   (es. `CHR44_famiglia_2figli_un_adulto_a_casa`) e la colonna `n_comp`. Il prefisso
   (`CHR44`) è il codice del template LPG.
2. **Configurazione LPG** `CER_LoadProfiles/config/simulation_config.lombardia100.yaml`:
   il codice rimanda al template completo (`CHR44 Family with 2 children, 1 at work, 1 at home`)
   e al house type (HT06/HT07).
3. **Catalogo LPG** `CER_LoadProfiles/lpg_db/profilegenerator.IT.db3`, tabelle
   `tblModularHouseholds` → `tblCHHPersons` → `tblPersons`: età e numero di ogni persona
   simulata. Sono le età riportate qui sotto. In tutti i 55 template il numero di persone
   coincide con `n_comp` delle schede.

LPG non ha un campo "numero di percettori di reddito". L'occupazione si legge solo dal
nome del template ("with work", "1 at work, 1 at home"). Le classi Istat non dipendono
dall'occupazione, quindi la mappatura si basa solo su **struttura del nucleo** ed **età
della persona di riferimento** (PR). In nessuna coppia del catalogo i due partner stanno
da parti diverse della soglia dei 65 anni, quindi l'età della PR non è mai ambigua.

## Tabella

| Classe Istat | Archetipi LPG (età dei componenti) | Motivazione |
|---|---|---|
| `persona_sola_under65` | CHR06 (30), CHR07 (23), CHR09 (34), CHR10 (40), CHR12 (22), CHR13 (22), CHR25 (28), CHR26 (27), CHR28 (24), CHR29 (26), CHR35 (42), CHR36 (51), CHR37 (48), OR01 (26) | una persona sotto i 65 anni |
| `persona_sola_65piu` | CHR23 (68), CHR24 (68), CHR30 (70), CHR31 (68) | una persona oltre i 65 anni. CHR30/CHR31 sono "Retired": l'età del catalogo conferma la classe |
| `coppia_senza_figli_PR_under65` | CHR01 (25, 23), CHR02 (38, 37), CHR04 (50, 45), CHR17 (31, 29), CHR32 (25, 23), CHR33 (28, 27), CHR34 (26, 25), CHR39 (44, 38), CHR40 (51, 48), CHR55 (45, 40), CHS12 (31, 29) | coppia senza figli, entrambi sotto i 65 |
| `coppia_senza_figli_PR_65piu` | CHR16 (80, 75), CHR51 (69, 67), CHR54 (71, 68), CHR58 (71, 68), CHS04 (71, 68) | coppia senza figli, entrambi oltre i 65 |
| `coppia_1_figlio` | CHR03 (43, 40, 10), CHR45 (48, 45, 16), CHR49 (45, 37, 13), CHR60 (32, 30, 2), CHR61 (43, 40, 10) | coppia con un figlio |
| `coppia_2_figli` | CHR18 (37, 35, 12, 8), CHR27 (43, 39, 13, 9), CHR44 (45, 43, 16, 14), CHR53 (45, 40, 15, 11), CHR56 (50, 45, 16, 14), CHR57 (45, 43, 20, 14), CHS01 (45, 40, 15, 11) | coppia con due figli. In CHR57 un figlio ha 20 anni: Istat conta i figli conviventi di qualunque età |
| `coppia_3piu_figli` | CHR05 (40, 35, 13, 6, 4), CHR20 (45, 40, 12, 8, 4) | coppia con tre figli. **Classe a campione piccolo**: la media Istat (72.138 €) è molto sopra la mediana (58.688 €) ed è la stima meno affidabile della tabella |
| `monogenitore` | CHR08 (30, 11, 7), CHR42 (42, 10, 7), CHR46 (38, 8), CHR47 (39, 10, 7) | un solo genitore con figli |
| `altra_tipologia` | CHR14 (46, 45, 80), CHR15 (40, 32, 15, 4, 70, 68), CHR19 (42, 38, 50) | nuclei che non sono "coppia con/senza figli" né "monogenitore". **Scelta dell'utente** (6/10/2026) per i nuclei multigenerazionali o con membri aggregati: vedi sotto |

Composizione risultante nella scheda da 100 (`CER_0_100_0.txt`, l'unica in cui archetipi e
profili coincidono, vedi l'ultima sezione): 22 / 17 / 17 / 9 / 10 / 12 / 3 / 5 / 5 nell'ordine
della tabella.

## Casi dubbi e come sono stati risolti

- **Nuclei multigenerazionali o con membri aggregati → `altra_tipologia`.** Il comando
  iniziale li indicava come NON MAPPATO. Su indicazione dell'utente vanno in
  `altra_tipologia`, che in Istat raccoglie proprio le famiglie con membri aggregati o con
  più nuclei.
  - CHR14: coppia di lavoratori più un'anziana di 80 anni a casa.
  - CHR15: coppia con due figli più due nonni (68 e 70 anni), cioè due nuclei.
  - CHR19: coppia più una collaboratrice domestica di 50 anni che LPG simula come
    componente (`n_comp = 3`). Se nella realtà fosse una colf non convivente, la classe
    giusta sarebbe `coppia_senza_figli_PR_under65`. Qui si segue `n_comp` della scheda.
- **Studenti CHR12 e CHR13 → `persona_sola_under65`.** Il template porta il tag LPG
  "Flatsharing", ma simula **una sola persona** (`n_comp = 1`): i coinquilini non esistono
  nel modello. Per Istat, coinquilini senza legami di parentela o affettivi formano famiglie
  distinte. Il reddito medio di "persona sola sotto i 65" è però verosimilmente alto per uno
  studente: è un limite noto.
- **Regola "1 solo lavoratore".** Il comando prevede `persona_sola_under65` come proxy per un
  household caratterizzato solo da "un lavoratore", e NON MAPPATO altrimenti. Nessun
  archetipo del catalogo è descritto solo dal numero di lavoratori: tutti hanno una
  struttura familiare esplicita, quindi la regola non è mai scattata.

## Household NON MAPPATI

**Nessuno.** Tutti i 55 archetipi presenti nelle 40 schede hanno una classe. Il codice
gestisce comunque il caso: un archetipo assente dalla tabella riceve `reddito_EUR = ?` e
`reddito_classe = NON_MAPPATO`, e il modello torna al proprio default dichiarandolo nel
registro delle ipotesi.

## Gas: nessun household escluso

Tutte le famiglie di `simulation_config.lombardia100.yaml` usano house type HT06 o HT07
("Continuous Flow **Gas Heating**"). Nessuna è "tutto elettrico" o con pompa di calore,
quindi nessuna è esclusa dall'assegnazione del gas. CHR58 ("no cooking") non cucina ma si
riscalda a gas, e resta incluso.

## Attenzione: archetipi delle schede e profili non coincidono sotto i 100 membri

Durante la mappatura è emersa un'incoerenza **preesistente** (non introdotta da questo lavoro).
I file `CER_LoadProfiles/outputs/csv_lombardia100/N_utenti.xlsx` contengono le **prime N
colonne** del file da 100: `household_k` ha lo stesso profilo in tutte le taglie. Le schede
da 5 a 75 membri dichiarano invece in `archetipo` una composizione diversa.

| Taglia | household con archetipo diverso dal profilo simulato |
|---|---|
| 5 / 8 / 10 | 5/5, 8/8, 10/10 |
| 15 / 18 / 20 / 25 | 14/15, 17/18, 19/20, 24/25 |
| 50 / 75 | 47/50, 68/75 |
| 100 | 0/100 |

Esempio: nelle schede da 10 membri `household_1` è dichiarato `CHR23_uomo_over65_solo`, ma
la sua curva è quella di `CHR06 Jak Jobless`.

Il reddito segue l'archetipo **dichiarato** nella scheda, come richiesto ("la classe nel file
di configurazione della CER"). Seed, fattori e categoria gas dipendono invece solo da
`household_k`, quindi sono identici in tutte le schede. Quando gli archetipi saranno
riallineati ai profili, basterà rilanciare lo script e anche il reddito di `household_k`
diventerà lo stesso ovunque.
