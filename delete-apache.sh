#!/bin/bash

# Arrêter et désactiver Apache
sudo systemctl stop apache2
sudo systemctl disable apache2

# Supprimer les fichiers d'Apache
sudo apt purge apache2 -y
sudo apt autoremove -y
sudo apt autoclean

echo "Apache a été supprimé avec succès."

