#!/bin/bash
#
# Description: script d'installation de Bookstack et de tous ses requierements
#
#
# Auteur : Rémy DIONISIO
# Contact : remydionisio@outlook.fr
# Version 1.0


echo "Ce script installe une nouvelle instance de BookStack sur un serveur Debian 11."
echo ""

# Génère un chemin pour un fichier journal de sortie pour le débogage
LOGPATH=$(realpath "bookstack_install_$(date +%s).log")

# Récupère l'utilisateur exécutant le script
SCRIPT_USER="${SUDO_USER:-$USER}"

# Récupère l'adresse IP de la machine actuelle
CURRENT_IP=$(ip addr | grep 'state UP' -A4 | grep 'inet ' | awk '{print $2}' | cut -f1  -d'/')

DB_NAME="bookstack"
DB_USER="jooker"

# Génère un mot de passe pour la base de données
DB_PASS="password"

# Répertoire où installer BookStack
BOOKSTACK_DIR="/var/www/bookstack"

# Récupère le domaine à partir des arguments (demandé ultérieurement s'il n'est pas défini)
DOMAIN=$1

# Désactive les invites interactives dans les applications
export DEBIAN_FRONTEND=noninteractive

# Affiche un message d'erreur dans la ligne de commande et quitte le programme
# Enregistre également le message dans le fichier journal
function error_out() {
  echo "ERREUR : $1" | tee -a "$LOGPATH" 1>&2
  exit 1
}

# Affiche un message d'information à la fois dans la ligne de commande et le fichier journal
function info_msg() {
  echo "$1" | tee -a "$LOGPATH"
}

# Exécute quelques vérifications avant l'installation pour éviter de perturber une configuration existante
# du serveur web.
function run_pre_install_checks() {
  # Vérifie que le script est exécuté en tant que root et quitte si ce n'est pas le cas
  if [[ $EUID -gt 0 ]]
  then
    error_out "Ce script doit être exécuté avec les privilèges root/sudo."
  fi
}

# Récupère le domaine à utiliser à partir du premier paramètre fourni,
# sinon demande à l'utilisateur de saisir son domaine
function run_prompt_for_domain_if_required() {
  if [ -z "$DOMAIN" ]
  then
    info_msg ""
    info_msg "Entrez le domaine (ou l'adresse IP si vous n'utilisez pas de domaine) sur lequel vous souhaitez héberger BookStack, puis appuyez sur [ENTRÉE]."
    info_msg "Exemples : mon-site.com ou docs.mon-site.com ou ${CURRENT_IP}"
    read -r DOMAIN
    info_msg ""
  fi

  if [ -z "$DOMAIN" ]
  then
    error_out "Domaine invalide, installation annulée."
  fi
}

# Met à jour le système et installe les dépendances requises
function run_system_update_and_dependency_install() {
  info_msg "Mise à jour du système en cours..."
  apt update >> "$LOGPATH" 2>&1 || error_out "La mise à jour du système a échoué, consultez le fichier journal pour plus d'informations."
  
  info_msg "Installation des dépendances système..."
  apt install -y curl unzip software-properties-common dirmngr apt-transport-https lsb-release ca-certificates >> "$LOGPATH" 2>&1 || error_out "L'installation des dépendances système a échoué, consultez le fichier journal pour plus d'informations."
}

# Installe Apache
function run_apache() {
  info_msg "Installation d'Apache..."
  apt install -y apache2 >> "$LOGPATH" 2>&1 || error_out "L'installation d'Apache a échoué, consultez le fichier journal pour plus d'informations."

}

# Configure Apache pour BookStack
function configure_apache() {
  info_msg "Configuration d'Apache..."

  # Désactive la configuration par défaut d'Apache
  a2dissite 000-default >> "$LOGPATH" 2>&1 || true

  # Crée un fichier de configuration pour BookStack
  cat <<EOF > "/etc/apache2/sites-available/bookstack.conf"
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${BOOKSTACK_DIR}/public

    <Directory ${BOOKSTACK_DIR}/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/bookstack_error.log
    CustomLog \${APACHE_LOG_DIR}/bookstack_access.log combined
</VirtualHost>
EOF

  # Active la configuration de BookStack
  a2ensite bookstack >> "$LOGPATH" 2>&1 || error_out "La configuration d'Apache pour BookStack a échoué, consultez le fichier journal pour plus d'informations."

  # Active les modules Apache nécessaires
  a2enmod rewrite >> "$LOGPATH" 2>&1 || error_out "L'activation du module Apache 'rewrite' a échoué, consultez le fichier journal pour plus d'informations."
  systemctl restart apache2 >> "$LOGPATH" 2>&1 || error_out "Le redémarrage d'Apache a échoué, consultez le fichier journal pour plus d'informations."
}

# Installe MariaDB
function run_mariadb_installation() {
  info_msg "Installation de MariaDB..."

  # Ajoute le référentiel MariaDB
  wget -qO- https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash >> "$LOGPATH" 2>&1 || error_out "L'ajout du référentiel MariaDB a échoué, consultez le fichier journal pour plus d'informations."

  # Installe MariaDB Server
  apt install -y mariadb-server >> "$LOGPATH" 2>&1 || error_out "L'installation de MariaDB Server a échoué, consultez le fichier journal pour plus d'informations."

  # Configure MariaDB pour BookStack
  mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> "$LOGPATH" 2>&1 || error_out "La création de la base de données BookStack a échoué, consultez le fichier journal pour plus d'informations."
  mysql -e "CREATE USER ${DB_USER}@'localhost' IDENTIFIED BY '${DB_PASS}';" >> "$LOGPATH" 2>&1 || error_out "La création de l'utilisateur MariaDB pour BookStack a échoué, consultez le fichier journal pour plus d'informations."
  mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_USER}@'localhost';" >> "$LOGPATH" 2>&1 || error_out "L'attribution des privilèges MariaDB pour BookStack a échoué, consultez le fichier journal pour plus d'informations."
  mysql -e "FLUSH PRIVILEGES;" >> "$LOGPATH" 2>&1 || error_out "Le vidage des privilèges MariaDB a échoué, consultez le fichier journal pour plus d'informations."
}

function run_php_installation(){
	info_msg "Installation de PHP..."
	sudo apt install apt-transport-https lsb-release ca-certificates wget -y
	sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
	sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
	sudo apt update
	sudo apt install php8.2 php8.2-{curl,dom,gd,xml,mysql,ldap,zip} -y
}

# Installe BookStack en utilisant Git
function run_bookstack_installation() {
  info_msg "Installation de BookStack..."

  # Clone le référentiel BookStack depuis GitHub (branche release, un seul branch)
  git clone https://github.com/BookStackApp/BookStack.git --branch release --single-branch ${BOOKSTACK_DIR} >> "$LOGPATH" 2>&1 || error_out "Le clonage de BookStack depuis GitHub a échoué, consultez le fichier journal pour plus d'informations."

  # Change le répertoire de travail vers le répertoire de BookStack
  cd ${BOOKSTACK_DIR}

  # Installe les dépendances PHP de BookStack (sans les dépendances de développement)
  sudo apt install composer -y
  sudo composer update
  composer install --no-dev --no-interaction --quiet >> "$LOGPATH" 2>&1 || error_out "L'installation des dépendances PHP de BookStack a échoué, consultez le fichier journal pour plus d'informations."

  # Copie le fichier .env.example en .env
  cp .env.example .env >> "$LOGPATH" 2>&1 || error_out "La création du fichier .env pour BookStack a échoué, consultez le fichier journal pour plus d'informations."

  # Configure le fichier .env pour BookStack avec les informations de base de données et de messagerie
  
  sed -i "s~^APP_URL=.*~APP_URL=http://${CURRENT_IP}~" .env >> "$LOGPATH" 2>&1 || error_out "Config .env échoué à l'url"
  sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" .env >> "$LOGPATH" 2>&1 || error_out "La configuration du fichier .env pour BookStack a échoué, consultez le fichier journal pour plus d'informations."
  sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" .env >> "$LOGPATH" 2>&1 || error_out "La configuration du fichier .env pour BookStack a échoué, consultez le fichier journal pour plus d'informations."
  sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" .env >> "$LOGPATH" 2>&1 || error_out "La configuration du fichier .env pour BookStack a échoué, consultez le fichier journal pour plus d'informations."

  # les dossiers storage, bootstrap/cache et public/uploads sont accessibles en écriture par le serveur web
  sudo chown -R www-data:www-data bootstrap/cache public/uploads/ storage/ >> "$LOGPATH" 2>&1 || error_out "La configuration des permissions des dossiers de BookStack a échoué, consultez le fichier journal pour plus d'informations."
    
  # Génère une clé d'application unique pour BookStack
  sudo php artisan key:generate

  # Exécute la migration de la base de données pour mettre à jour la structure de la base de données
  sudo php artisan migrate
}

# Affiche les informations de connexion à BookStack
function display_bookstack_info() {
  info_msg ""
  info_msg "L'installation de BookStack est terminée ! Voici les informations de connexion :"
  info_msg ""
  info_msg "URL : http://${CURRENT_IP}"
  info_msg "Nom d'utilisateur : admin@admin.com"
  info_msg "Mot de passe : password"
  info_msg ""
  info_msg "Assurez-vous de changer le mot de passe de l'administrateur après la première connexion."
  info_msg ""
}

# Exécute les différentes étapes de l'installation de BookStack
function main() {
  run_pre_install_checks
  run_prompt_for_domain_if_required
  run_system_update_and_dependency_install
  run_php_installation
  run_apache
  configure_apache
  run_mariadb_installation
  run_bookstack_installation
  display_bookstack_info
}

# Exécute le script principal
main

