"""
================================================================================
SIMULAZIONE QUARTIERE IBRIDO: pyLPG + RAMP
================================================================================
Questo script genera profili di carico elettrico per un quartiere misto
composto da utenze residenziali (via LPG) e PMI (via RAMP).

PREREQUISITI (eseguire una volta):
    pip install pyloadprofilegenerator rampdemand pandas matplotlib numpy

NOTE:
- pyLPG scarica automaticamente i binari LPG (~500MB) al primo avvio
- Richiede .NET 6 runtime (su Linux: sudo apt install dotnet-runtime-6.0)
- Su Windows funziona out-of-the-box
================================================================================
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import os

# ==============================================================================
# PASSO 1: CONFIGURAZIONE DEL QUARTIERE
# ==============================================================================
# Qui definisci la composizione del tuo quartiere.
# Modifica questi dizionari per adattarli al tuo scenario.

ANNO = 2023
RISOLUZIONE_MINUTI = 15  # 15 min è un buon compromesso velocità/dettaglio
DATA_INIZIO = f"{ANNO}-01-01"
DATA_FINE = f"{ANNO}-12-31"

# --- Utenze residenziali (simulate con LPG) ---
# I nomi dei template vengono dal catalogo LPG.
# Esempi di template disponibili (nomi indicativi, verifica con lpgdata):
#   - CHR01: Coppia pensionati
#   - CHR02: Coppia 30-64, entrambi lavoratori
#   - CHR03: Famiglia con 1 figlio
#   - CHR04: Famiglia con 2 figli
#   - CHR05: Single lavoratore
#   - CHR06: Single pensionato
#   ...e molti altri (60 totali)

RESIDENZIALI = [
    {
        "label": "Pensionati",
        "template_name": "CHR01",  # Coppia pensionati
        "quantita": 8,
    },
    {
        "label": "Coppie lavoratori",
        "template_name": "CHR02",  # Coppia entrambi lavorano
        "quantita": 12,
    },
    {
        "label": "Famiglie con figli",
        "template_name": "CHR04",  # Famiglia 2 figli
        "quantita": 10,
    },
]

# --- PMI e uffici (simulate con RAMP) ---
# Qui definisci da zero gli elettrodomestici e le finestre d'uso.
# power in Watt, func_time in minuti, windows in minuti dall'inizio del giorno
# (es. 480 = 8:00, 1080 = 18:00)

PMI_CONFIG = [
    {
        "label": "Piccolo ufficio",
        "num_users": 5,  # 5 uffici di questo tipo
        "appliances": [
            {
                "name": "Illuminazione",
                "number": 20,       # 20 punti luce per ufficio
                "power": 40,        # Watt ciascuno
                "func_time": 540,   # 9 ore di funzionamento
                "num_windows": 1,
                "windows": [[480, 1080]],  # 8:00 - 18:00
                "random_var_w": 0.15,
                "time_fraction_random_variability": 0.1,
            },
            {
                "name": "Postazione PC + monitor",
                "number": 8,
                "power": 200,
                "func_time": 480,
                "num_windows": 1,
                "windows": [[510, 1050]],  # 8:30 - 17:30
                "random_var_w": 0.1,
                "time_fraction_random_variability": 0.15,
            },
            {
                "name": "Climatizzazione",
                "number": 2,
                "power": 2500,
                "func_time": 480,
                "num_windows": 1,
                "windows": [[480, 1080]],
                "random_var_w": 0.2,
                "time_fraction_random_variability": 0.25,
            },
            {
                "name": "Stampante/Fotocopiatrice",
                "number": 2,
                "power": 300,
                "func_time": 60,
                "num_windows": 2,
                "windows": [[540, 780], [840, 1020]],  # mattina e pomeriggio
                "random_var_w": 0.3,
                "time_fraction_random_variability": 0.5,
            },
        ],
    },
    {
        "label": "Negozio/Bottega",
        "num_users": 3,
        "appliances": [
            {
                "name": "Illuminazione vetrina + interno",
                "number": 30,
                "power": 50,
                "func_time": 600,
                "num_windows": 1,
                "windows": [[480, 1200]],  # 8:00 - 20:00
                "random_var_w": 0.1,
                "time_fraction_random_variability": 0.05,
            },
            {
                "name": "Registratore di cassa + POS",
                "number": 2,
                "power": 100,
                "func_time": 600,
                "num_windows": 1,
                "windows": [[480, 1200]],
                "random_var_w": 0.05,
                "time_fraction_random_variability": 0.1,
            },
            {
                "name": "Frigorifero espositore",
                "number": 2,
                "power": 350,
                "func_time": 1440,   # sempre acceso
                "num_windows": 1,
                "windows": [[0, 1440]],
                "random_var_w": 0.0,
                "time_fraction_random_variability": 0.0,
            },
        ],
    },
]


# ==============================================================================
# PASSO 2: GENERAZIONE PROFILI RESIDENZIALI (pyLPG)
# ==============================================================================

def genera_profili_lpg(config_residenziali, anno, risoluzione_min):
    """
    Genera profili di carico per le utenze residenziali usando pyLPG.
    Ogni nucleo familiare viene simulato con un seed diverso per avere
    variabilità realistica.
    """
    try:
        from pyloadprofilegenerator import lpgdata, lpgexecute
    except ImportError:
        try:
            from pylpg import lpgdata, lpgexecute
        except ImportError:
            print("=" * 60)
            print("ERRORE: pyLPG non installato!")
            print("Esegui: pip install pyloadprofilegenerator")
            print("=" * 60)
            return None

    tutti_profili = []
    risoluzione_str = f"00:{risoluzione_min:02d}:00"

    for gruppo in config_residenziali:
        print(f"\n--- Generando {gruppo['quantita']}x {gruppo['label']} ---")

        # Trova il template corretto dal catalogo LPG
        # NOTA: i nomi esatti dipendono dalla versione di LPG.
        # Usa lpgdata.HouseholdTemplates per vedere quelli disponibili.
        template_name = gruppo["template_name"]

        for i in range(gruppo["quantita"]):
            print(f"  Nucleo {i+1}/{gruppo['quantita']}...", end=" ")

            try:
                risultato = lpgexecute.execute_household(
                    year=anno,
                    resolution=risoluzione_str,
                    random_seed=i * 100 + hash(template_name) % 1000,
                    # Il template specifico dipende dalla versione di pyLPG.
                    # Potrebbe essere necessario adattare questa riga:
                    # household=getattr(lpgdata.HouseholdTemplates, template_name),
                )

                # Estrai il profilo elettrico dal risultato
                # Il formato esatto dipende dalla versione di pyLPG
                df = pd.DataFrame({
                    "timestamp": risultato.index if hasattr(risultato, 'index') else range(len(risultato)),
                    "potenza_W": risultato.values if hasattr(risultato, 'values') else risultato,
                })
                df["gruppo"] = gruppo["label"]
                df["unita_id"] = f"{gruppo['label']}_{i}"

                tutti_profili.append(df)
                print("OK")

            except Exception as e:
                print(f"ERRORE: {e}")
                print(f"  Generando profilo sintetico di fallback...")
                df = genera_profilo_sintetico_residenziale(
                    gruppo["label"], i, anno, risoluzione_min
                )
                tutti_profili.append(df)

    if tutti_profili:
        return pd.concat(tutti_profili, ignore_index=True)
    return None


def genera_profilo_sintetico_residenziale(label, idx, anno, risoluzione_min):
    """
    Profilo di fallback se pyLPG non è installato o ha errori.
    Genera un profilo sintetico basato su pattern tipici.
    Utile per testare il pipeline senza LPG installato.
    """
    n_steps = int(365 * 24 * 60 / risoluzione_min)
    timestamps = pd.date_range(
        start=f"{anno}-01-01",
        periods=n_steps,
        freq=f"{risoluzione_min}min"
    )

    np.random.seed(idx * 100 + hash(label) % 1000)

    # Profilo base diverso per tipo
    potenza = np.zeros(n_steps)
    ore = np.array([t.hour + t.minute / 60 for t in timestamps])
    giorno_settimana = np.array([t.weekday() for t in timestamps])
    is_weekend = giorno_settimana >= 5

    if "Pensionat" in label:
        # Profilo più piatto, picco pranzo, base più alta di giorno
        base = 200 + np.random.normal(0, 30, n_steps)
        for i in range(n_steps):
            h = ore[i]
            if 7 <= h < 9:
                potenza[i] = base[i] + 800 * np.random.uniform(0.5, 1.2)
            elif 11 <= h < 14:
                potenza[i] = base[i] + 1200 * np.random.uniform(0.6, 1.3)
            elif 17 <= h < 21:
                potenza[i] = base[i] + 900 * np.random.uniform(0.5, 1.1)
            elif 23 <= h or h < 6:
                potenza[i] = 100 + np.random.normal(0, 20)
            else:
                potenza[i] = base[i] + 400 * np.random.uniform(0.3, 0.8)

    elif "Lavorator" in label or "Coppi" in label:
        # Picchi mattina presto e sera, basso di giorno nei feriali
        base = 150 + np.random.normal(0, 25, n_steps)
        for i in range(n_steps):
            h = ore[i]
            if is_weekend[i]:
                # Weekend: profilo simile ai pensionati
                if 9 <= h < 12:
                    potenza[i] = base[i] + 900 * np.random.uniform(0.5, 1.2)
                elif 12 <= h < 15:
                    potenza[i] = base[i] + 1100 * np.random.uniform(0.6, 1.2)
                elif 18 <= h < 22:
                    potenza[i] = base[i] + 1000 * np.random.uniform(0.5, 1.1)
                else:
                    potenza[i] = base[i] + 200 * np.random.uniform(0.2, 0.6)
            else:
                # Feriale: picco mattina e sera
                if 6 <= h < 8:
                    potenza[i] = base[i] + 1500 * np.random.uniform(0.6, 1.3)
                elif 8 <= h < 17:
                    potenza[i] = 120 + np.random.normal(0, 30)  # casa vuota
                elif 18 <= h < 22:
                    potenza[i] = base[i] + 1800 * np.random.uniform(0.5, 1.3)
                else:
                    potenza[i] = 100 + np.random.normal(0, 20)

    else:  # Famiglie con figli
        base = 250 + np.random.normal(0, 40, n_steps)
        for i in range(n_steps):
            h = ore[i]
            if 6 <= h < 8:
                potenza[i] = base[i] + 1200 * np.random.uniform(0.6, 1.4)
            elif 12 <= h < 14:
                potenza[i] = base[i] + 800 * np.random.uniform(0.4, 1.0)
            elif 17 <= h < 22:
                potenza[i] = base[i] + 2000 * np.random.uniform(0.5, 1.3)
            elif 23 <= h or h < 6:
                potenza[i] = 130 + np.random.normal(0, 25)
            else:
                potenza[i] = base[i] + 300 * np.random.uniform(0.2, 0.7)

    potenza = np.maximum(potenza, 50)  # minimo 50W (standby)

    return pd.DataFrame({
        "timestamp": timestamps,
        "potenza_W": potenza,
        "gruppo": label,
        "unita_id": f"{label}_{idx}",
    })


# ==============================================================================
# PASSO 3: GENERAZIONE PROFILI PMI (RAMP)
# ==============================================================================

def genera_profili_ramp(config_pmi, data_inizio, data_fine):
    """
    Genera profili di carico per le PMI usando RAMP.
    Ogni PMI viene definita con i suoi elettrodomestici e finestre d'uso.
    """
    try:
        from ramp import User, UseCase
    except ImportError:
        print("=" * 60)
        print("ERRORE: RAMP non installato!")
        print("Esegui: pip install rampdemand")
        print("=" * 60)
        return None

    tutti_profili = []

    for pmi in config_pmi:
        print(f"\n--- Generando {pmi['num_users']}x {pmi['label']} (RAMP) ---")

        # Crea l'utente RAMP
        user = User(
            user_name=pmi["label"],
            num_users=pmi["num_users"],
        )

        # Aggiungi ogni elettrodomestico
        for app_config in pmi["appliances"]:
            # Crea l'appliance con i parametri base
            appliance = user.add_appliance(
                name=app_config["name"],
                number=app_config["number"],
                power=app_config["power"],
                func_time=app_config["func_time"],
                time_fraction_random_variability=app_config.get(
                    "time_fraction_random_variability", 0.1
                ),
                num_windows=app_config["num_windows"],
            )

            # Aggiungi le finestre separatamente
            windows = app_config["windows"]
            win_kwargs = {}
            for w_idx, window in enumerate(windows):
                win_kwargs[f"window_{w_idx + 1}"] = window
            win_kwargs["random_var_w"] = app_config.get("random_var_w", 0.1)

            appliance.windows(**win_kwargs)

        # Esegui la simulazione
        use_case = UseCase(
            users=[user],
            date_start=data_inizio,
            date_end=data_fine,
        )

        print(f"  Simulazione in corso...")
        profilo = use_case.generate_daily_load_profiles()

        # Converti in DataFrame
        n_steps = len(profilo)
        timestamps = pd.date_range(
            start=data_inizio,
            periods=n_steps,
            freq="1min",  # RAMP genera a 1 minuto
        )

        df = pd.DataFrame({
            "timestamp": timestamps[:n_steps],
            "potenza_W": profilo[:n_steps],
            "gruppo": pmi["label"],
            "unita_id": pmi["label"],
        })

        tutti_profili.append(df)
        print(f"  OK - {n_steps} campioni generati")

    if tutti_profili:
        return pd.concat(tutti_profili, ignore_index=True)
    return None


# ==============================================================================
# PASSO 4: UNIONE E POST-PROCESSING
# ==============================================================================

def unisci_profili(df_residenziali, df_pmi, risoluzione_min):
    """
    Combina i profili LPG (residenziali) e RAMP (PMI) in un unico DataFrame
    con risoluzione temporale uniforme.
    """
    dfs_da_unire = []

    if df_residenziali is not None:
        dfs_da_unire.append(df_residenziali)
        print(f"  Profili residenziali: {df_residenziali['unita_id'].nunique()} unità")

    if df_pmi is not None:
        # RAMP genera a 1 minuto, riallinea alla risoluzione desiderata
        if risoluzione_min > 1:
            df_pmi = df_pmi.copy()
            df_pmi["timestamp"] = df_pmi["timestamp"].dt.floor(f"{risoluzione_min}min")
            df_pmi = df_pmi.groupby(
                ["timestamp", "gruppo", "unita_id"]
            )["potenza_W"].mean().reset_index()

        dfs_da_unire.append(df_pmi)
        print(f"  Profili PMI: {df_pmi['unita_id'].nunique()} unità")

    if not dfs_da_unire:
        print("ERRORE: Nessun profilo generato!")
        return None

    df_totale = pd.concat(dfs_da_unire, ignore_index=True)

    # Calcola profilo aggregato del quartiere
    df_aggregato = df_totale.groupby("timestamp")["potenza_W"].sum().reset_index()
    df_aggregato.columns = ["timestamp", "potenza_totale_W"]

    # Aggiungi colonne utili
    df_aggregato["potenza_totale_kW"] = df_aggregato["potenza_totale_W"] / 1000
    df_aggregato["ora"] = df_aggregato["timestamp"].dt.hour
    df_aggregato["giorno_settimana"] = df_aggregato["timestamp"].dt.day_name()
    df_aggregato["mese"] = df_aggregato["timestamp"].dt.month

    return df_totale, df_aggregato


# ==============================================================================
# PASSO 5: VISUALIZZAZIONE
# ==============================================================================

def visualizza_risultati(df_totale, df_aggregato, output_dir="output"):
    """Genera grafici per analizzare i profili."""
    os.makedirs(output_dir, exist_ok=True)

    # --- Grafico 1: Profilo giornaliero medio per gruppo ---
    fig, ax = plt.subplots(figsize=(14, 6))

    df_totale["ora"] = df_totale["timestamp"].dt.hour

    for gruppo in df_totale["gruppo"].unique():
        df_g = df_totale[df_totale["gruppo"] == gruppo]
        profilo_medio = df_g.groupby("ora")["potenza_W"].mean() / 1000
        ax.plot(profilo_medio.index, profilo_medio.values, label=gruppo, linewidth=2)

    ax.set_xlabel("Ora del giorno")
    ax.set_ylabel("Potenza media [kW]")
    ax.set_title("Profilo giornaliero medio per tipologia")
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_xticks(range(0, 24))
    plt.tight_layout()
    plt.savefig(f"{output_dir}/profilo_medio_per_gruppo.png", dpi=150)
    plt.close()
    print(f"  Salvato: {output_dir}/profilo_medio_per_gruppo.png")

    # --- Grafico 2: Profilo aggregato del quartiere (settimana tipo) ---
    fig, ax = plt.subplots(figsize=(14, 6))

    # Prendi una settimana tipo (es. seconda settimana di gennaio)
    settimana = df_aggregato[
        (df_aggregato["timestamp"] >= f"{ANNO}-01-09") &
        (df_aggregato["timestamp"] < f"{ANNO}-01-16")
    ]

    if not settimana.empty:
        ax.fill_between(
            settimana["timestamp"],
            settimana["potenza_totale_kW"],
            alpha=0.3, color="steelblue"
        )
        ax.plot(
            settimana["timestamp"],
            settimana["potenza_totale_kW"],
            color="steelblue", linewidth=0.8
        )

    ax.set_xlabel("Giorno")
    ax.set_ylabel("Potenza totale quartiere [kW]")
    ax.set_title("Profilo aggregato del quartiere - Settimana tipo")
    ax.grid(True, alpha=0.3)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(f"{output_dir}/profilo_settimanale_quartiere.png", dpi=150)
    plt.close()
    print(f"  Salvato: {output_dir}/profilo_settimanale_quartiere.png")

    # --- Grafico 3: Heatmap giorno-ora ---
    fig, ax = plt.subplots(figsize=(14, 6))

    pivot = df_aggregato.pivot_table(
        values="potenza_totale_kW",
        index=df_aggregato["timestamp"].dt.date,
        columns="ora",
        aggfunc="mean"
    )

    # Mostra solo i primi 30 giorni per leggibilità
    pivot_30 = pivot.iloc[:30]
    im = ax.imshow(pivot_30.values, aspect="auto", cmap="YlOrRd")
    ax.set_xlabel("Ora del giorno")
    ax.set_ylabel("Giorno")
    ax.set_title("Heatmap consumi quartiere (primi 30 giorni)")
    ax.set_xticks(range(0, 24))
    plt.colorbar(im, label="Potenza [kW]")
    plt.tight_layout()
    plt.savefig(f"{output_dir}/heatmap_consumi.png", dpi=150)
    plt.close()
    print(f"  Salvato: {output_dir}/heatmap_consumi.png")


# ==============================================================================
# PASSO 6: EXPORT
# ==============================================================================

def esporta_risultati(df_totale, df_aggregato, output_dir="output"):
    """Salva i risultati in CSV per uso in altri software."""
    os.makedirs(output_dir, exist_ok=True)

    # Profilo aggregato del quartiere
    df_aggregato.to_csv(
        f"{output_dir}/profilo_quartiere_aggregato.csv",
        index=False
    )
    print(f"  Salvato: {output_dir}/profilo_quartiere_aggregato.csv")

    # Profili per singola unità
    df_totale.to_csv(
        f"{output_dir}/profili_singole_unita.csv",
        index=False
    )
    print(f"  Salvato: {output_dir}/profili_singole_unita.csv")

    # Riepilogo statistico
    stats = df_totale.groupby("gruppo").agg(
        n_unita=("unita_id", "nunique"),
        potenza_media_W=("potenza_W", "mean"),
        potenza_max_W=("potenza_W", "max"),
        energia_annua_kWh=("potenza_W", lambda x: x.sum() * RISOLUZIONE_MINUTI / 60 / 1000),
    ).round(1)

    stats.to_csv(f"{output_dir}/riepilogo_statistico.csv")
    print(f"  Salvato: {output_dir}/riepilogo_statistico.csv")
    print(f"\n{stats}")


# ==============================================================================
# MAIN: ESECUZIONE COMPLETA
# ==============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("SIMULAZIONE QUARTIERE IBRIDO LPG + RAMP")
    print("=" * 60)

    # PASSO 2: Profili residenziali
    print("\n[PASSO 1/4] Generazione profili residenziali (LPG)...")
    df_residenziali = genera_profili_lpg(
        RESIDENZIALI, ANNO, RISOLUZIONE_MINUTI
    )

    # Se LPG non è disponibile, usa profili sintetici di fallback
    if df_residenziali is None:
        print("\nLPG non disponibile, uso profili sintetici di fallback...")
        profili_fallback = []
        for gruppo in RESIDENZIALI:
            for i in range(gruppo["quantita"]):
                df = genera_profilo_sintetico_residenziale(
                    gruppo["label"], i, ANNO, RISOLUZIONE_MINUTI
                )
                profili_fallback.append(df)
        df_residenziali = pd.concat(profili_fallback, ignore_index=True)

    # PASSO 3: Profili PMI
    print("\n[PASSO 2/4] Generazione profili PMI (RAMP)...")
    df_pmi = genera_profili_ramp(PMI_CONFIG, DATA_INIZIO, DATA_FINE)

    # Se RAMP non è disponibile, salta le PMI
    if df_pmi is None:
        print("RAMP non disponibile, procedo solo con i residenziali...")

    # PASSO 4: Unione
    print("\n[PASSO 3/4] Unione profili...")
    df_totale, df_aggregato = unisci_profili(
        df_residenziali, df_pmi, RISOLUZIONE_MINUTI
    )

    # PASSO 5-6: Visualizzazione e export
    print("\n[PASSO 4/4] Visualizzazione e salvataggio...")
    visualizza_risultati(df_totale, df_aggregato)
    esporta_risultati(df_totale, df_aggregato)

    print("\n" + "=" * 60)
    print("SIMULAZIONE COMPLETATA!")
    print(f"Totale unità simulate: {df_totale['unita_id'].nunique()}")
    print(f"Periodo: {DATA_INIZIO} → {DATA_FINE}")
    print(f"Risoluzione: {RISOLUZIONE_MINUTI} minuti")
    print(f"Campioni totali: {len(df_aggregato):,}")
    print("=" * 60)