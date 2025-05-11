import pandas as pd
import json
import math

# Charger le fichier Excel
excel_path = "../data/DataTombesTestFirebase.xlsx"  # Remplacez par le chemin de votre fichier Excel
df = pd.read_excel(excel_path)

# Fonction pour convertir NaN ou None en null
def convert_to_null(value):
    if pd.isna(value) or value is None:
        return None
    return value

# Structure de la base de données
firebase_data = {}

# Parcourir les données
for _, row in df.iterrows():
    cimetery = convert_to_null(row['Cimetière'])
    nom_defunt = convert_to_null(row['Nom'])
    client = convert_to_null(row['Client'])  # Ajouter la colonne "Client"
    tombe_id = convert_to_null(row.get('ID_Tombe', None))  # Mettre None si ID manquant
    position_x = convert_to_null(row['Position_X'])
    position_y = convert_to_null(row['Position_Y'])
    carré = convert_to_null(row['Carré'])  # Numéro du secteur
    active = bool(row['Active']) if not pd.isna(row['Active']) else None  # Si le client est toujours abonné
    longueur = convert_to_null(row['Longueur'])  # Longueur du rectangle
    largeur = convert_to_null(row['Largeur'])  # Largeur du rectangle
    rotation = convert_to_null(row['Rotation'])  # Rotation du rectangle
    arrose = 1

    # Ajouter le cimetière s'il n'existe pas encore
    if cimetery not in firebase_data:
        firebase_data[cimetery] = {
            "tombes": {}
        }

    # Créer une clé unique pour chaque tombe
    nom_unique = f"{nom_defunt}_{int(tombe_id) if tombe_id else math.floor(position_x * 10000)}"

    firebase_data[cimetery]["tombes"][nom_unique] = {
        "nom_defunt": nom_defunt,  # Conserver le nom original du défunt
        "client": client,
        "carré": carré,
        "active": active,
        "position": {
            "x": position_x,
            "y": position_y
        },
        "dimensions": {
            "longueur": longueur,
            "largeur": largeur,
            "rotation": rotation
        },
        "id_tombe": tombe_id,
        "arrosages": {
            # Exemple d'historique d'arrosages
            "2025-01-01": {"arrosé": arrose},
        }
    }


# Enregistrer en fichier JSON
output_path = "../data/DataTombesTestFirebase.json"  # Remplacez par le chemin désiré
with open(output_path, 'w', encoding='utf-8') as json_file:
    json.dump(firebase_data, json_file, ensure_ascii=False, indent=4)

print(f"Fichier JSON généré : {output_path}")
