import sys
import subprocess
import os
from datetime import datetime

# Auto-installation du module si manquant
try:
    import qrcode
except ImportError:
    print("Installation de qrcode...")
    subprocess.run([sys.executable, '-m', 'pip', 'install', '--user', 'qrcode[pil]'], check=True)
    import qrcode

def generate_qr(text, output_path=None):
    """Génère un QR code à partir d'un texte/URL"""
    
    # Si pas de chemin spécifié, utiliser le dossier QR_Code avec timestamp
    if output_path is None:
        qr_folder = r'C:\Users\jbcde\OneDrive\Documents\QR_Code'
        # Créer le dossier QR_Code s'il n'existe pas
        os.makedirs(qr_folder, exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_path = os.path.join(qr_folder, f'qrcode_{timestamp}.png')
    
    try:
        # Générer le QR code
        img = qrcode.make(text)
        img.save(output_path)
        print(f"SUCCESS:{output_path}")
        return output_path
    except Exception as e:
        print(f"ERROR:{e}")
        return None

if __name__ == "__main__":
    # Récupérer le texte depuis les arguments
    if len(sys.argv) < 2:
        print("ERROR:Aucun texte fourni")
        sys.exit(1)
    
    text = sys.argv[1]
    
    # Chemin optionnel en 2ème argument
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    generate_qr(text, output_path)
