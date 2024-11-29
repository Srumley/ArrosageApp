import asyncio
from bleak import BleakScanner
from collections import defaultdict
import time
import matplotlib.pyplot as plt

async def scan_devices():
    # Créer des dictionnaires pour stocker les périphériques et leurs RSSI au fil du temps
    devices_rssi = defaultdict(list)
    timestamps = defaultdict(list)  # Dictionnaire pour stocker les horodatages
    start_time = time.time()  # Enregistrer le temps de début

    fig, ax = plt.subplots()  # Créer un graphique
    plt.ion()  # Mode interactif pour mise à jour en temps réel

    while True:
        print("Scanning for Bluetooth devices...")

        # Scanner les périphériques
        devices = await BleakScanner.discover()

        # Parcourir les périphériques trouvés
        for device in devices:
            if device.name and "CP28" in device.name:
                # Mettre à jour les RSSI et les horodatages dans les dictionnaires
                devices_rssi[device.address].append(device.rssi)
                timestamps[device.address].append(time.time() - start_time)
                print(f"Device found: {device.name}")
                print(f"Address: {device.address}")
                print(f"RSSI: {device.rssi} dBm\n")

        # Mettre à jour le graphique
        ax.clear()  # Effacer l'ancienne figure
        for address, rssi_values in devices_rssi.items():
            ax.plot(timestamps[address], rssi_values, label=f'Device {address}')

        ax.set_title('RSSI values over time')
        ax.set_xlabel('Time (s)')
        ax.set_ylabel('RSSI (dBm)')
        ax.legend()  # Ajouter une légende pour chaque dispositif
        plt.draw()
        plt.pause(0.1)  # Pause pour mise à jour du graphique

        # Attendre avant de refaire le scan (par exemple 1 seconde)
        await asyncio.sleep(1)

if __name__ == "__main__":
    try:
        asyncio.run(scan_devices())
    except KeyboardInterrupt:
        print("Scanning stopped by user.")
    finally:
        plt.ioff()  # Désactiver le mode interactif pour la fermeture propre du graphique
        plt.show()  # Afficher le graphique final si nécessaire
