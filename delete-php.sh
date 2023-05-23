#!/bin/bash

# Supprimer les paquets PHP
sudo apt purge php\* -y
sudo apt autoremove -y
sudo apt autoclean

echo "PHP a été supprimé avec succès."

