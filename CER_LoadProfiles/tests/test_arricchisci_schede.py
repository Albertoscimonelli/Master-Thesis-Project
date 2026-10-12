"""Test di arricchisci_schede.py.

Uso (dalla root del progetto):
    python -m unittest discover -s CER_LoadProfiles/tests -v
"""

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import arricchisci_schede as az  # noqa: E402

N_CAMPIONE = 10_000

SCHEDA_MINIMA = """\
# testata
[CER]
anno = 2025
[MEMBRI]
id | nome_csv | ruolo | categoria | archetipo | tariffa | P_prel_kW | n_comp | n_perc | \
reddito_EUR | gas_kWh | quota_inv_EUR | mutuo_EUR_anno | impianto
1 | household_1_kWh | C | domestico | CHR27_fam | MONORARIA | 3 | 4 | ? | ? | ? | 0 | 0 | -
2 | household_2_kWh | C | domestico | XYZ99_ignoto | MONORARIA | 3 | 2 | ? | ? | ? | 0 | 0 | -
3 | office_1_kWh | C | terziario | office | BIORARIA | 10 | - | - | - | - | 0 | 0 | -
[IMPIANTI]
id | proprietario | kWp
"""


class TestDati(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = az.contesto()

    def test_quote_base_sommano_a_uno(self):
        par = az.carica_parametri()
        for area in ("lombardia", "milano"):
            gas = az.carica_quote_gas(az.PARAMETRI.parent / par["gas"]["file"], area,
                                      par["gas"]["soglie_smc"])
            # Milano somma 100,1% nella fonte: la rinormalizzazione lo assorbe.
            self.assertAlmostEqual(gas["quote"].sum(), 1.0, delta=0.0015)

    def test_quote_perturbate_sommano_a_uno(self):
        par = self.ctx["par"]["gas"]
        for k in range(1000):
            g = az.assegna_gas(f"household_{k}_kWh", self.ctx["gas"], par, 42, 0.12)
            self.assertAlmostEqual(g["quote"].sum(), 1.0, places=12)
            self.assertTrue(np.all((g["fattori"] >= 0.95) & (g["fattori"] <= 1.05)))

    def test_soglie_diverse_dai_dati_fermano(self):
        par = az.carica_parametri()
        with self.assertRaises(ValueError):
            az.carica_quote_gas(az.PARAMETRI.parent / par["gas"]["file"], "lombardia",
                                [120, 480])

    def test_tutti_gli_archetipi_delle_schede_mappati(self):
        mapping, redditi = self.ctx["mapping"], self.ctx["redditi"]
        self.assertTrue(set(mapping.values()) <= set(redditi))


class TestFattoreReddito(unittest.TestCase):
    R, SF = 0.15, 0.5

    @classmethod
    def setUpClass(cls):
        rng = np.random.default_rng(123)
        cls.f = np.array([az.fattore_gaussiano_troncato(rng, cls.R, cls.SF)
                          for _ in range(N_CAMPIONE)])

    def test_fattori_nell_intervallo(self):
        self.assertTrue(np.all((self.f >= 0.85) & (self.f <= 1.15)))

    def test_media_vicina_a_uno(self):
        self.assertAlmostEqual(self.f.mean(), 1.0, delta=0.003)

    def test_circa_95_percento_entro_R_prima_del_troncamento(self):
        grezzi = np.random.default_rng(7).normal(1.0, self.SF * self.R, N_CAMPIONE)
        quota = np.mean(np.abs(grezzi - 1.0) <= self.R)
        self.assertGreater(quota, 0.94)
        self.assertLess(quota, 0.97)

    def test_nessun_accumulo_agli_estremi(self):
        self.assertEqual(np.sum((self.f == 0.85) | (self.f == 1.15)), 0)
        # Con il clipping finirebbe sui bordi ~4,6% del campione; con la
        # riestrazione la fascia di 0,005 accanto a ciascun bordo ne tiene ~0,8%.
        bordi = np.mean((self.f < 0.855) | (self.f > 1.145))
        self.assertLess(bordi, 0.02)


class TestAssegnazione(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = az.contesto()
        cls.par = cls.ctx["par"]

    def _reddito(self, nome, archetipo, seed=42):
        return az.assegna_reddito(nome, archetipo, self.ctx["redditi"], self.ctx["mapping"],
                                  self.par["reddito"], seed)

    def test_dieci_utenti_stessa_classe_redditi_diversi(self):
        redditi = [self._reddito(f"household_{k}_kWh", "CHR27_x")["reddito"]
                   for k in range(1, 11)]
        self.assertGreater(len(set(redditi)), 1)
        media = self.ctx["redditi"]["coppia_2_figli"]["media"]
        for r in redditi:
            self.assertTrue(0.85 * media - 1 <= r <= 1.15 * media + 1)

    def test_stesso_seed_stesso_output(self):
        a = self._reddito("household_5_kWh", "CHR16_x")
        b = self._reddito("household_5_kWh", "CHR16_x")
        self.assertEqual(a, b)
        self.assertNotEqual(a["f"], self._reddito("household_5_kWh", "CHR16_x", seed=43)["f"])
        g1 = az.assegna_gas("household_5_kWh", self.ctx["gas"], self.par["gas"], 42, 0.12)
        g2 = az.assegna_gas("household_5_kWh", self.ctx["gas"], self.par["gas"], 42, 0.12)
        self.assertEqual(g1["categoria"], g2["categoria"])
        self.assertTrue(np.array_equal(g1["fattori"], g2["fattori"]))

    def test_non_mappato_senza_errori(self):
        r = self._reddito("household_1_kWh", "XYZ99_ignoto")
        self.assertEqual(r["classe"], az.NON_MAPPATO)
        self.assertIsNone(r["reddito"])

    def test_categorie_seguono_le_quote(self):
        conta = {}
        for k in range(N_CAMPIONE):
            g = az.assegna_gas(f"h{k}", self.ctx["gas"], self.par["gas"], 42, 0.12)
            conta[g["categoria"]] = conta.get(g["categoria"], 0) + 1
        attese = dict(zip(self.ctx["gas"]["usi"], self.ctx["gas"]["quote"]))
        for uso, q in attese.items():
            self.assertAlmostEqual(conta[uso] / N_CAMPIONE, q, delta=0.015)


class TestScheda(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = az.contesto()
        cls.testo, cls.riep = az.arricchisci_testo(SCHEDA_MINIMA, cls.ctx)

    def _membri(self, testo):
        righe = testo.split("\n")
        i0 = righe.index("[MEMBRI]")
        tab = [az._celle(r) for r in righe[i0 + 1:] if r.strip() and not r.startswith("#")]
        tab = tab[:next(i for i, c in enumerate(tab) if c[0].startswith("["))]
        return [dict(zip(tab[0], c)) for c in tab[1:]], tab

    def test_colonne_coerenti_e_gas_rinominato(self):
        membri, tab = self._membri(self.testo)
        self.assertTrue(all(len(c) == len(tab[0]) for c in tab))
        self.assertIn("euro_gas", tab[0])
        self.assertNotIn("gas_kWh", tab[0])

    def test_valori_per_tipo_di_membro(self):
        membri, _ = self._membri(self.testo)
        dom, ignoto, ufficio = membri
        self.assertEqual(dom["reddito_classe"], "coppia_2_figli")
        self.assertEqual(int(dom["reddito_EUR"]),
                         round(int(dom["reddito_base_EUR"]) * float(dom["reddito_f"])))
        self.assertEqual(ignoto["reddito_EUR"], "?")
        self.assertEqual(ignoto["reddito_classe"], az.NON_MAPPATO)
        self.assertNotEqual(ignoto["euro_gas"], "?")
        self.assertEqual(ufficio["reddito_EUR"], "-")
        self.assertEqual(ufficio["gas_src"], "-")

    def test_idempotente(self):
        di_nuovo, _ = az.arricchisci_testo(self.testo, self.ctx)
        self.assertEqual(di_nuovo, self.testo)

    def test_gas_kwh_compilato_ferma(self):
        testo = SCHEDA_MINIMA.replace("| 4 | ? | ? | ? |", "| 4 | ? | ? | 15000 |")
        with self.assertRaises(ValueError):
            az.arricchisci_testo(testo, self.ctx)


if __name__ == "__main__":
    unittest.main()
