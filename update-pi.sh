#!/bin/sh
sudo apt-get update && sudo apt-get upgrade -y
sudo rpi-update -y
sudo apt-get autoremove -y
sudo apt-get autoclean -y

# Ajout des libs
sudo apt-get install libgtk-3-dev libpigpio-dev libbcm2835-dev html-xml-utils
mkdir -p bcm2835 && wget -qO - http://www.open.com.au/mikem/bcm2835/bcm2835-1.73.tar.gz | tar xz --strip-components=1 -C bcm2835
cd bcm2835
./configure
make
sudo make install

# Lire la version actuelle
current_version=$(cat "/home/neoffice/neoffice_version.txt")

# Obtenir les informations sur la dernière release
release_json=$(curl -s https://api.github.com/repos/bvisible/neoffice_linux_app_rc522_build/releases/latest)

# Extraire le tag de la release
version_tag=$(echo $release_json | grep "tag_name" | cut -d '"' -f 4)

# Comparer les versions
if [ "$version_tag" != "$current_version" ]; then
    # Mise à jour disponible

    # URL directe du tarball
    tarball_url="https://api.github.com/repos/bvisible/neoffice_linux_app_rc522_build/tarball/release"

    # Télécharger le tarball de la release
    sudo -u neoffice wget -O "/home/neoffice/neoffice_linux_app_rc522_build.tar.gz" "$tarball_url"
    
    # Extraire le tarball
    sudo -u neoffice tar -xzvf "/home/neoffice/neoffice_linux_app_rc522_build.tar.gz" -C "/home/neoffice/"
    
    # Trouver le dossier extrait
    extracted_folder=$(find /home/neoffice -maxdepth 1 -type d -name "bvisible-neoffice_linux_app_rc522_build-*")

    # Supprimer l'ancien dossier
    sudo rm -rf "/home/neoffice/neoffice_linux_app_rc522"
    
    # Renommer le dossier
    sudo mv "$extracted_folder" "/home/neoffice/neoffice_linux_app_rc522"
    
    # Supprimer le fichier tar.gz téléchargé
    sudo rm "/home/neoffice/neoffice_linux_app_rc522_build.tar.gz"
    
    # Stocker la version actuelle
    echo $version_tag > "/home/neoffice/neoffice_version.txt"
    
    # Changer les droits d'excution des fichiers
    chmod +x /home/neoffice/neoffice_linux_app_rc522/neoffice_linux_app_rc522
    chmod +x /home/neoffice/neoffice_linux_app_rc522/update-pi.sh

else
    echo "L'application est déjà à jour."
fi

# Rebouter le Raspberry Pi
sudo reboot
