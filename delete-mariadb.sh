#!/bin/bash

# Arrêter et désactiver MariaDB
sudo systemctl stop mariadb
sudo systemctl disable mariadb

# Supprimer les fichiers de MariaDB
sudo apt purge mariadb-server -y
sudo apt autoremove -y
sudo apt autoclean

# Supprimer le dossier 
sudo rm -rf /etc/mysql

echo "MariaDB a été supprimé avec succès."

