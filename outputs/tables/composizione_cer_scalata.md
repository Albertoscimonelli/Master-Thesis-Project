# Composizione tipologica di una CER, per taglia (3-100 famiglie)

Allocazione di famiglie per **dimensione del nucleo × condizione occupazionale**,
su undici taglie di comunità energetica: 3, 5, 8, 10, 15, 18, 20, 25, 50, 75, 100.

## Fonti e metodo

- **ISTAT, Aspetti della vita quotidiana (AVQ) 2024**, microdati, Lombardia
  (`REGMf = '030'`): 1.831 famiglie, 4.139 individui, copertura del 100% dei
  componenti. Da' la composizione (eta', condizione professionale di ciascun
  membro).
- **ISTAT, Censimento permanente della popolazione 2021** (rilascio 2023), dati
  per sezione: marginali demografici (famiglie per numero di componenti, quota
  over-65) a livello di regione Lombardia e di comune di Milano.
- **Milano** e' l'AVQ ripesata (IPF, post-stratificazione) sui due marginali del
  censimento comunale; **Lombardia** usa i pesi AVQ originali, senza
  ripesatura. Il tasso di occupazione non e' vincolato ed e' un controllo
  indipendente della calibrazione, non un input.
- Allocazione **gerarchica a resto maggiore**: prima le classi di dimensione,
  poi le tipologie entro ciascuna classe. Conserva sempre il marginale
  censuario delle dimensioni familiari.
- Generato da `CER_LoadProfiles/lpg_db/tipologie_famiglie.py`
  (funzioni `famiglie_avq`, `marginali_censimento`, `calibra`, `allocazione`).
  Nessun numero e' scritto a mano.

Le quattro tipologie occupazionali:

| Etichetta qui | Definizione |
|---|---|
| Nessun occupato | Nessun adulto occupato, nucleo non composto solo da anziani |
| Pensionati (solo anziani) | Tutti gli adulti hanno 65+ anni e nessuno e' occupato |
| Un adulto in casa | Almeno un adulto occupato, ma meno adulti occupati che adulti totali (part-time, turni, un genitore a casa) |
| Tutti occupati | Tutti gli adulti del nucleo sono occupati |

## Limiti dichiarati

- **Con minori**: 21,7% delle famiglie lombarde (15,7% a Milano) ha almeno un
  minore, ma questa tabella non incrocia dimensione/tipologia con la presenza
  di figli — si concentrano verosimilmente nelle celle a 3-5 componenti con
  "un adulto in casa" o "tutti occupati".
- **Smart working**: 20,7% degli occupati del Nord-Ovest (2023) lavora da
  casa. Non e' nel modello di base (calibrato su HETUS 2010, che non
  conteneva il fenomeno) e non e' allocabile in questa tabella.
- A N piccoli (3-10) il resto maggiore lascia celle vuote anche dove il dato
  originale non e' zero: e' un effetto di arrotondamento dichiarato, non
  un'assenza strutturale di quel profilo nella popolazione.

---

# LOMBARDIA (pesi AVQ originali)

Famiglie per componenti (popolazione): 1: 38,6% · 2: 27,9% · 3: 16,9% · 4: 12,4% · 5+: 4,3%
Tipologie (popolazione): tutti occupati 36,8% · un adulto in casa 26,6% · pensionati 26,3% · nessun occupato 10,3%

### 3 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 0 | 1 | 0 | 0 | 1 |
| 2 | 0 | 1 | 0 | 0 | 1 |
| 3 | 0 | 0 | 1 | 0 | 1 |
| 4 | 0 | 0 | 0 | 0 | 0 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 0 | 2 | 1 | 0 | **3** |

### 5 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 0 | 1 | 0 | 1 | 2 |
| 2 | 0 | 1 | 0 | 0 | 1 |
| 3 | 0 | 0 | 1 | 0 | 1 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 0 | 2 | 2 | 1 | **5** |

### 8 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 0 | 2 | 0 | 1 | 3 |
| 2 | 0 | 1 | 0 | 1 | 2 |
| 3 | 0 | 0 | 1 | 1 | 2 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 0 | 3 | 2 | 3 | **8** |

### 10 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 0 | 2 | 0 | 2 | 4 |
| 2 | 0 | 1 | 1 | 1 | 3 |
| 3 | 0 | 0 | 1 | 1 | 2 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 0 | 3 | 3 | 4 | **10** |

### 15 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 3 | 0 | 2 | 6 |
| 2 | 1 | 1 | 1 | 1 | 4 |
| 3 | 0 | 0 | 1 | 1 | 2 |
| 4 | 0 | 0 | 1 | 1 | 2 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 2 | 4 | 4 | 5 | **15** |

### 18 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 3 | 0 | 3 | 7 |
| 2 | 1 | 2 | 1 | 1 | 5 |
| 3 | 0 | 0 | 2 | 1 | 3 |
| 4 | 0 | 0 | 1 | 1 | 2 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 2 | 5 | 5 | 6 | **18** |

### 20 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 4 | 0 | 3 | 8 |
| 2 | 1 | 2 | 1 | 2 | 6 |
| 3 | 0 | 0 | 2 | 1 | 3 |
| 4 | 0 | 0 | 1 | 1 | 2 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 2 | 6 | 5 | 7 | **20** |

### 25 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 5 | 0 | 4 | 10 |
| 2 | 1 | 2 | 2 | 2 | 7 |
| 3 | 0 | 0 | 2 | 2 | 4 |
| 4 | 0 | 0 | 2 | 1 | 3 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 2 | 7 | 7 | 9 | **25** |

### 50 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 2 | 9 | 0 | 8 | 19 |
| 2 | 2 | 4 | 4 | 4 | 14 |
| 3 | 1 | 0 | 5 | 3 | 9 |
| 4 | 0 | 0 | 3 | 3 | 6 |
| 5+ | 0 | 0 | 2 | 0 | 2 |
| **Totale** | 5 | 13 | 14 | 18 | **50** |

### 75 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 3 | 13 | 0 | 12 | 28 |
| 2 | 3 | 7 | 6 | 6 | 22 |
| 3 | 1 | 0 | 7 | 5 | 13 |
| 4 | 0 | 0 | 5 | 4 | 9 |
| 5+ | 0 | 0 | 2 | 1 | 3 |
| **Totale** | 7 | 20 | 20 | 28 | **75** |

### 100 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 4 | 17 | 0 | 17 | 38 |
| 2 | 4 | 9 | 8 | 8 | 29 |
| 3 | 2 | 0 | 9 | 6 | 17 |
| 4 | 1 | 0 | 6 | 5 | 12 |
| 5+ | 0 | 0 | 3 | 1 | 4 |
| **Totale** | 11 | 26 | 26 | 37 | **100** |

---

# MILANO (AVQ post-stratificata su censimento comunale)

Famiglie per componenti (popolazione): 1: 55,6% · 2: 21,3% · 3: 11,9% · 4: 8,4% · 5+: 2,9%
Tipologie (popolazione): tutti occupati 43,9% · un adulto in casa 18,5% · pensionati 25,9% · nessun occupato 11,6%

### 3 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 0 | 1 | 0 | 1 | 2 |
| 2 | 0 | 0 | 0 | 1 | 1 |
| 3 | 0 | 0 | 0 | 0 | 0 |
| 4 | 0 | 0 | 0 | 0 | 0 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 0 | 1 | 0 | 2 | **3** |

### 5 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 0 | 1 | 0 | 2 | 3 |
| 2 | 0 | 0 | 0 | 1 | 1 |
| 3 | 0 | 0 | 1 | 0 | 1 |
| 4 | 0 | 0 | 0 | 0 | 0 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 0 | 1 | 1 | 3 | **5** |

### 8 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 1 | 0 | 2 | 4 |
| 2 | 0 | 0 | 1 | 1 | 2 |
| 3 | 0 | 0 | 1 | 0 | 1 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 1 | 1 | 3 | 3 | **8** |

### 10 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 2 | 0 | 3 | 6 |
| 2 | 0 | 0 | 1 | 1 | 2 |
| 3 | 0 | 0 | 1 | 0 | 1 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 0 | 0 | 0 |
| **Totale** | 1 | 2 | 3 | 4 | **10** |

### 15 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 3 | 0 | 4 | 8 |
| 2 | 0 | 1 | 1 | 1 | 3 |
| 3 | 0 | 0 | 1 | 1 | 2 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 1 | 4 | 4 | 6 | **15** |

### 18 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 4 | 0 | 5 | 10 |
| 2 | 1 | 1 | 1 | 1 | 4 |
| 3 | 0 | 0 | 1 | 1 | 2 |
| 4 | 0 | 0 | 1 | 0 | 1 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 2 | 5 | 4 | 7 | **18** |

### 20 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 1 | 4 | 0 | 6 | 11 |
| 2 | 1 | 1 | 1 | 1 | 4 |
| 3 | 0 | 0 | 1 | 1 | 2 |
| 4 | 0 | 0 | 1 | 1 | 2 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 2 | 5 | 4 | 9 | **20** |

### 25 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 2 | 5 | 0 | 7 | 14 |
| 2 | 1 | 1 | 1 | 2 | 5 |
| 3 | 0 | 0 | 2 | 1 | 3 |
| 4 | 0 | 0 | 1 | 1 | 2 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 3 | 6 | 5 | 11 | **25** |

### 50 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 4 | 10 | 0 | 14 | 28 |
| 2 | 1 | 3 | 3 | 4 | 11 |
| 3 | 1 | 0 | 3 | 2 | 6 |
| 4 | 0 | 0 | 2 | 2 | 4 |
| 5+ | 0 | 0 | 1 | 0 | 1 |
| **Totale** | 6 | 13 | 9 | 22 | **50** |

### 75 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 6 | 15 | 0 | 21 | 42 |
| 2 | 2 | 4 | 4 | 6 | 16 |
| 3 | 1 | 0 | 5 | 3 | 9 |
| 4 | 0 | 0 | 3 | 3 | 6 |
| 5+ | 0 | 0 | 1 | 1 | 2 |
| **Totale** | 9 | 19 | 13 | 34 | **75** |

### 100 famiglie

| Componenti | Nessun occupato | Pensionati | Un adulto in casa | Tutti occupati | Totale |
|---|---|---|---|---|---|
| 1 | 8 | 20 | 0 | 28 | 56 |
| 2 | 2 | 6 | 6 | 7 | 21 |
| 3 | 1 | 0 | 6 | 5 | 12 |
| 4 | 1 | 0 | 4 | 3 | 8 |
| 5+ | 0 | 0 | 2 | 1 | 3 |
| **Totale** | 12 | 26 | 18 | 44 | **100** |

---

## Riproducibilita'

```
cd CER_LoadProfiles/lpg_db
python tipologie_famiglie.py --famiglie <N>          # Lombardia + Milano, un N alla volta
```

Per l'intera lista di N in un solo passaggio (evita di ricaricare i microdati
AVQ ad ogni chiamata): riusa `famiglie_avq()`, `marginali_censimento()` e
`calibra()` una sola volta, poi richiama `allocazione(fam, pesi, n)` per ogni
N — attenzione a copiare l'array dei pesi (`.to_numpy(dtype=float).copy()`)
prima di passarlo a `calibra()`, che lo modifica in place.
