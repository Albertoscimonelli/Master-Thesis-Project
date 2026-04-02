"""
Definizioni delle famiglie residenziali per la simulazione pyLPG.

I template disponibili sono elencati in pylpg.lpgdata.HouseholdTemplates.
Il campo 'household_ref' deve corrispondere al nome dell'attributo nella classe
pylpg.lpgdata.Households (usato per ottenere il JsonReference con GUID).

Esempi di template disponibili:
  - CHR01 Couple both at Work
  - CHR02 Couple, 30 - 64 age, with work
  - CHR03 Family, 1 child, both at work
  - CHR05 Family, 3 children, both with work
  - CHR07 Single with work
  - CHR09 Couple, 30 - 64 age, 1 at work, 1 at home
  - CHR10 Single, Retired
  - CHR15 Couple under 30 years, without children, both at work
  - CHR38 Couple over 65 years, both retired
"""

HOUSEHOLD_DEFINITIONS: list[dict] = [
    {
        "label": "pensionati",
        "template": "CHR54 Retired Couple, no work",
        "household_ref": "CHR54_Retired_Couple_no_work",
        "count": 2,
    },
    {
        "label": "coppia_lavoratori",
        "template": "CHR02 Couple, 30 - 64 age, with work",
        "household_ref": "CHR02_Couple_30_64_age_with_work",
        "count": 2,
    },
    {
        "label": "famiglia_1figlio",
        "template": "CHR03 Family, 1 child, both at work",
        "household_ref": "CHR03_Family_1_child_both_at_work",
        "count": 1,
    },
]
