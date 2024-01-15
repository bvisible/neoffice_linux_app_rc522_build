#!/bin/sh
sudo apt-get update && sudo apt-get upgrade -y
sudo rpi-update -y
sudo apt-get autoremove -y
sudo apt-get autoclean -y

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
    
    # Renommer le dossier
    sudo mv "$extracted_folder" "/home/neoffice/neoffice_linux_app_rc522"
    
    # Supprimer le fichier tar.gz téléchargé
    sudo rm "/home/neoffice/neoffice_linux_app_rc522_build.tar.gz"
    
    # Stocker la version actuelle
    echo $version_tag > "/home/neoffice/neoffice_version.txt"
    
    # Changer le droit d'excution du fichier 
    chmod +x /home/neoffice/neoffice_linux_app_rc522/neoffice_linux_app_rc522

else
    echo "L'application est déjà à jour."
fi

# Rebouter le Raspberry Pi
sudo reboot
