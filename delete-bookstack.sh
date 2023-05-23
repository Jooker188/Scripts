#!/bin/bash

# Répertoire d'installation de BookStack
BOOKSTACK_DIR="/var/www/bookstack"

# Nom de la base de données
DB_NAME="bookstack"

# Supprime le répertoire d'installation de BookStack
if [ -d "$BOOKSTACK_DIR" ]; then
    sudo rm -rf "$BOOKSTACK_DIR"
    echo "Répertoire d'installation de BookStack supprimé."
fi

# Supprime la base de données de BookStack
sudo mariadb -e "DROP DATABASE IF EXISTS $DB_NAME;"
echo "Base de données de BookStack supprimée."

# Supprime l'utilisateur de la base de données
sudo mariadb -e "DROP USER IF EXISTS 'bookstack'@'localhost';"
echo "Utilisateur de la base de données de BookStack supprimé."


