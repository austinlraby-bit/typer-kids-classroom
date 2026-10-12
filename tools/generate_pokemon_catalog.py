#!/usr/bin/env python3
"""Generate the data-only classroom catalog; artwork stays upstream."""

import csv
import io
import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv"
SPRITES = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
REGIONS = {
    1: "Kanto",
    2: "Johto",
    3: "Hoenn",
    4: "Sinnoh",
    5: "Unova",
    6: "Kalos",
    7: "Alola",
    8: "Galar",
    9: "Paldea",
}


def rows(name):
    with urllib.request.urlopen(f"{BASE}/{name}") as response:
        return list(csv.DictReader(io.StringIO(response.read().decode("utf-8"))))


species = rows("pokemon_species.csv")
names = {
    int(row["pokemon_species_id"]): row["name"]
    for row in rows("pokemon_species_names.csv")
    if row["local_language_id"] == "9"
}

catalog = []
for row in species:
    dex = int(row["id"])
    generation = int(row["generation_id"])
    if dex > 1025 or generation not in REGIONS:
        continue
    evolves_from = row["evolves_from_species_id"]
    catalog.append(
        {
            "id": dex,
            "name": names.get(dex, row["identifier"].replace("-", " ").title()),
            "generation": generation,
            "region": REGIONS[generation],
            "spriteUrl": f"{SPRITES}/{dex}.png",
            "legendary": row["is_legendary"] == "1",
            "mythical": row["is_mythical"] == "1",
            "evolvesFrom": int(evolves_from) if evolves_from else None,
            "evolutionChain": int(row["evolution_chain_id"]),
        }
    )

target = ROOT / "assets" / "data" / "pokemon_catalog.json"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")))
print(f"Wrote {len(catalog)} species to {target}")
