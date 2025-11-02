# Gestion des Vaults AWS Glacier

Scripts pour automatiser la suppression complète des vaults AWS Glacier et de leurs archives.

## 📁 Fichiers du projet

### Scripts principaux
- **glacier.json** : Liste des vaults Glacier à traiter (6 vaults)
- **init_glacier_inventory.sh** : Lance les jobs d'inventaire pour tous les vaults
- **check_glacier_jobs.sh** : Vérifie l'état d'avancement des jobs
- **delete_glacier_auto.sh** : Supprime les archives et les vaults

### 🎨 Dashboard web
- **dashboard_server.py** : Serveur web avec API REST
- **dashboard.html** : Interface graphique interactive
- **start_dashboard.sh** : Script de lancement du dashboard

### 🐳 Docker (NOUVEAU)
- **Dockerfile** : Image Docker avec tous les outils nécessaires
- **docker-compose.yml** : Configuration Docker Compose
- **docker-start.sh** : Script de démarrage Docker
- **docker-stop.sh** : Script d'arrêt Docker
- **docker-shell.sh** : Accès shell dans le container
- **Makefile** : Commandes simplifiées
- **.env.example** : Exemple de configuration

## 🐳 Déploiement Docker ⭐ NOUVEAU

**Solution conteneurisée complète - La méthode la plus simple pour démarrer !**

### Pourquoi Docker ?

✅ **Portable** : Fonctionne partout (macOS, Linux, Windows)
✅ **Isolé** : Pas de conflit avec votre système
✅ **Pré-configuré** : AWS CLI, jq, Python déjà installés
✅ **Persistant** : Vos données restent même après l'arrêt
✅ **Simple** : Une seule commande pour tout lancer

### Installation rapide

```bash
# 1. Vérifier que Docker est installé
docker --version

# 2. Lancer tout avec Docker Compose
./docker-start.sh

# 3. Ouvrir le dashboard
# http://localhost:8080
```

C'est tout ! 🎉

### Utilisation avec Docker

**Avec les scripts shell :**
```bash
# Démarrer
./docker-start.sh

# Arrêter
./docker-stop.sh

# Voir les logs
docker compose logs -f

# Ouvrir un shell dans le container
./docker-shell.sh
```

**Avec Make (encore plus simple) :**
```bash
# Voir toutes les commandes
make help

# Démarrer
make start

# Voir les logs
make logs

# Lancer les jobs d'inventaire
make init

# Vérifier l'état
make check

# Suppression en dry-run
make delete-dry

# Arrêter
make stop
```

**Avec Docker Compose directement :**
```bash
# Construire l'image
docker compose build

# Démarrer
docker compose up -d

# Logs en temps réel
docker compose logs -f

# Exécuter un script dans le container
docker compose exec glacier-dashboard ./init_glacier_inventory.sh
docker compose exec glacier-dashboard ./check_glacier_jobs.sh
docker compose exec glacier-dashboard ./delete_glacier_auto.sh --dry-run

# Arrêter
docker compose down
```

### Configuration Docker

**Volumes montés :**
- `~/.aws` → Credentials AWS (lecture seule)
- `./glacier_inventory` → Inventaires téléchargés
- `./glacier_logs` → Logs persistants
- `./job_data` → Fichiers de jobs

**Ports exposés :**
- `8080` → Dashboard web

**Variables d'environnement :**
Créez un fichier `.env` à partir de `.env.example` :
```bash
cp .env.example .env
# Éditez .env si nécessaire
```

### Workflow Docker complet

```bash
# 1. Première fois : construire et démarrer
make start

# 2. Ouvrir le navigateur
# http://localhost:8080

# 3. Utiliser le dashboard OU les commandes Make

# Option A : Via le dashboard web
# - Cliquez sur les boutons dans l'interface

# Option B : Via Make
make init           # Lancer les jobs d'inventaire
make check          # Vérifier l'état
make delete-dry     # Test en dry-run
make delete         # Suppression réelle (demande confirmation)

# 4. Suivre les logs en temps réel
make logs

# 5. Arrêter quand terminé
make stop
```

### Commandes Make disponibles

| Commande | Description |
|----------|-------------|
| `make help` | Afficher l'aide |
| `make build` | Construire l'image Docker |
| `make start` | Démarrer le container |
| `make stop` | Arrêter le container |
| `make restart` | Redémarrer le container |
| `make logs` | Voir les logs en temps réel |
| `make shell` | Ouvrir un shell dans le container |
| `make status` | Afficher l'état du container |
| `make clean` | Supprimer container et image |
| `make init` | Lancer les jobs d'inventaire |
| `make check` | Vérifier l'état des jobs |
| `make delete-dry` | Suppression en dry-run |
| `make delete` | Suppression réelle |
| `make vaults-only` | Supprimer uniquement les vaults |

### Avantages de la version Docker

| Local | Docker |
|-------|--------|
| Installer AWS CLI manuellement | ✅ Déjà inclus |
| Installer jq manuellement | ✅ Déjà inclus |
| Installer Python manuellement | ✅ Déjà inclus |
| Gérer les dépendances | ✅ Tout pré-configuré |
| Conflits de versions | ✅ Environnement isolé |
| Portabilité limitée | ✅ Fonctionne partout |

## 🌐 Dashboard Web Interactif

**Interface graphique moderne pour gérer vos vaults Glacier depuis votre navigateur !**

### Fonctionnalités du dashboard

✨ **Monitoring en temps réel**
- Visualisation de tous les vaults et leurs statistiques
- Suivi de l'état des jobs d'inventaire
- Barres de progression pour les suppressions en cours
- Logs en direct avec coloration syntaxique

🎮 **Contrôle interactif**
- Lancer les scripts directement depuis l'interface
- Boutons pour toutes les opérations (init, check, delete, etc.)
- Confirmations de sécurité pour les opérations critiques
- Suivi des processus en cours d'exécution

📊 **Statistiques détaillées**
- Nombre d'archives par vault
- Taille totale des données
- Progression en pourcentage avec compteurs
- Historique des logs

### Lancement du dashboard

```bash
# Lancer le serveur web
./start_dashboard.sh
```

Puis ouvrez votre navigateur à l'adresse : **http://localhost:8080**

**Sortie attendue :**
```
============================================================
🚀 Dashboard AWS Glacier
============================================================
Serveur démarré sur : http://localhost:8080
Répertoire de travail : /Users/remi/Desktop/Glacier

Ouvrez votre navigateur à l'adresse : http://localhost:8080

Appuyez sur Ctrl+C pour arrêter le serveur
============================================================
```

### Captures d'écran du dashboard

**Vue d'ensemble :**
- 📦 **Section Vaults** : Liste de tous les vaults avec statistiques
- ⏳ **Section Jobs** : État des jobs d'inventaire avec badges de statut
- 🔥 **Section Progression** : Barres de progression animées pour les suppressions
- 📋 **Section Logs** : Console avec logs en temps réel
- ⚙️ **Section Contrôles** : Boutons pour lancer les scripts

**Auto-refresh :**
Le dashboard se rafraîchit automatiquement toutes les 5 secondes pour afficher l'état le plus récent.

### Utilisation du dashboard

1. **Lancer le serveur**
   ```bash
   ./start_dashboard.sh
   ```

2. **Ouvrir le navigateur** à http://localhost:8080

3. **Utiliser les contrôles**
   - Cliquer sur "🚀 Lancer les jobs d'inventaire" pour démarrer
   - Surveiller l'état dans la section "Jobs"
   - Une fois prêt, lancer la suppression
   - Suivre la progression en temps réel

4. **Arrêter le serveur**
   - Revenir au terminal
   - Appuyer sur `Ctrl+C`

## 🚀 Workflow complet

### Option A : Avec le Dashboard Web (Recommandé)

1. Lancer le dashboard : `./start_dashboard.sh`
2. Ouvrir http://localhost:8080 dans votre navigateur
3. Utiliser les boutons pour contrôler les opérations
4. Surveiller la progression en temps réel

### Option B : En ligne de commande

### Étape 1 : Lancer les jobs d'inventaire

```bash
./init_glacier_inventory.sh
```

**Ce script :**
- Lit le fichier `glacier.json`
- Extrait tous les vaults (my_vault_1, _4, _5 et leurs mappings)
- Initie un job d'inventaire pour chaque vault
- Sauvegarde les job IDs dans des fichiers `job_<vault>.json`

**Sortie attendue :**
```
🚀 Initialisation des jobs d'inventaire Glacier
📋 Vaults trouvés :
  - my_vault_1
  - my_vault_1_mapping
  - my_vault_2
  - ...
✅ Job lancé avec succès
💾 Job sauvegardé dans : job_my_vault_1.json
```

### Étape 2 : Attendre et vérifier l'état des jobs

⏳ **Les jobs d'inventaire Glacier prennent généralement 3-5 heures**

Vérifier régulièrement l'état :

```bash
./check_glacier_jobs.sh
```

**Ce script :**
- Lit tous les fichiers `job_*.json`
- Interroge AWS pour connaître le statut de chaque job
- Affiche un résumé global

**Sortie attendue :**
```
📦 Vault : my_vault_1
   ✅ Statut : Terminé avec succès

📦 Vault : my_vault_2
   ⏳ Statut : En cours (InProgress)

📊 RÉSUMÉ
Total de jobs : 6
✅ Terminés : 1
⏳ En cours : 5
❌ Échoués : 0
```

### Étape 3 : Supprimer les archives et vaults

Une fois tous les jobs terminés :

```bash
# Mode dry-run (simulation, aucune suppression)
./delete_glacier_auto.sh --dry-run

# Suppression réelle
./delete_glacier_auto.sh
```

**Ce script :**
- Vérifie automatiquement que les jobs sont terminés
- Télécharge l'inventaire de chaque vault
- Supprime toutes les archives avec retry automatique
- Affiche la progression tous les 100 archives
- Tente de supprimer les vaults vides
- Affiche un résumé complet des opérations

**Sortie attendue :**
```
📄 Fichier : job_my_vault_1.json
➡️  Vault : my_vault_1
🔍 Vérification du statut du job...
✅ Job terminé avec succès
📥 Téléchargement de l'inventaire...
✅ Inventaire sauvegardé : ./glacier_inventory/inventory_my_vault_1.json
🧨 64 archives trouvées dans le vault
🧹 Suppression réelle des archives...
✅ Suppression terminée : 64 réussies, 0 échouées
🧹 Suppression du vault vide : my_vault_1
   ⚠️  Note : La suppression peut échouer si le vault a été modifié il y a moins de 24h
❌ Échec de suppression du vault my_vault_1
   Raisons possibles :
   - Le vault a été modifié il y a moins de 24h

📊 RÉSUMÉ FINAL
Total de vaults traités : 6
✅ Vaults supprimés : 0
❌ Échecs : 6

⚠️  Certains vaults n'ont pas pu être supprimés.
   Attendez 24h puis relancez : ./delete_glacier_auto.sh --vaults-only
```

### Étape 4 : Supprimer les vaults (24h après)

⏰ **Attendre 24 heures après la suppression des archives**

AWS Glacier impose une attente de ~24h après la dernière modification d'un vault avant de pouvoir le supprimer.

```bash
# Supprimer uniquement les vaults vides (sans retraiter les archives)
./delete_glacier_auto.sh --vaults-only
```

**Sortie attendue :**
```
🗑️  MODE VAULTS ONLY : suppression uniquement des vaults vides
📦 Vault : my_vault_1
✅ Vault supprimé : my_vault_1

📊 RÉSUMÉ FINAL
Total de vaults traités : 6
✅ Vaults supprimés : 6
❌ Échecs : 0
```

## ⚙️ Configuration

### Paramètres principaux

Les scripts utilisent les paramètres suivants (modifiables dans chaque script) :

- **ACCOUNT_ID** : `-` (utilise le compte AWS par défaut)
- **REGION** : `eu-west-1` (région de vos vaults)
- **GLACIER_JSON** : `glacier.json` (fichier source des vaults)

### Options avancées du script delete_glacier_auto.sh

Paramètres configurables dans le script :

- **DELAY_BETWEEN_DELETES** : `0.5` secondes (pause entre chaque suppression d'archive)
- **MAX_RETRIES** : `3` tentatives (nombre de retry en cas d'erreur AWS)

Options en ligne de commande :

```bash
# Simulation sans suppression
./delete_glacier_auto.sh --dry-run

# Suppression uniquement des vaults vides (après 24h)
./delete_glacier_auto.sh --vaults-only

# Combinaison des options
./delete_glacier_auto.sh --dry-run --vaults-only
```

## 📊 Informations des vaults

D'après `glacier.json`, voici les vaults à traiter :

| Vault | Archives | Taille | Dernière inventaire |
|-------|----------|--------|---------------------|
| my_vault_1 | 64 | 10 GB | 2025-10-24 |
| my_vault_1_mapping | 0 | 0 B | 2025-10-24 |
| my_vault_2 | 10,000 | 100 GB | 2025-10-24 |
| my_vault_2_mapping | 1 | 50 MB | 2023-12-21 |
| my_vault_3 | 5,000 | 50 GB | 2023-12-22 |
| my_vault_3_mapping | 1 | 20 MB | 2023-12-26 |

**Total : ~160 GB de données**

## 🗂️ Fichiers générés

Pendant l'exécution, les fichiers suivants seront créés :

```
.
├── glacier.json                             # Configuration des vaults
├── init_glacier_inventory.sh                # Script 1
├── check_glacier_jobs.sh                    # Script 2
├── delete_glacier_auto.sh                   # Script 3
├── job_my_vault_*.json                   # Job IDs (créés par script 1)
├── glacier_inventory/                       # Inventaires et progression
│   ├── inventory_my_vault_*.json         # Inventaires téléchargés (originaux)
│   ├── inventory_my_vault_*.working.json # Copies de travail (reprise)
│   └── .progress_my_vault_*              # Fichiers de progression
└── glacier_logs/                            # Logs persistants
    └── deletion_YYYYMMDD_HHMMSS.log         # Log horodaté de chaque exécution
```

**Note :** Les fichiers `.working.json` et `.progress_*` sont automatiquement nettoyés une fois le vault vidé.

## ⚠️ Avertissements

- La suppression des archives est **irréversible**
- Utilisez `--dry-run` pour tester avant la suppression réelle
- Les jobs d'inventaire prennent plusieurs heures (3-5h en moyenne)
- AWS Glacier facture les suppressions anticipées (< 90 jours de stockage)
- Assurez-vous d'avoir les permissions IAM nécessaires :
  - `glacier:InitiateJob`
  - `glacier:DescribeJob`
  - `glacier:GetJobOutput`
  - `glacier:DeleteArchive`
  - `glacier:DeleteVault`

## 🔧 Prérequis

### Pour les scripts CLI
- AWS CLI installé et configuré
- `jq` installé (pour le parsing JSON)
- Bash 4.0+
- Credentials AWS configurées (`~/.aws/credentials` ou variables d'environnement)

### Pour le dashboard web (optionnel)
- Python 3.6+ (généralement pré-installé sur macOS)
- Navigateur web moderne (Chrome, Firefox, Safari, Edge)

**Vérifier les prérequis :**
```bash
# Vérifier AWS CLI
aws --version

# Vérifier jq
jq --version

# Vérifier Python 3
python3 --version

# Vérifier les credentials AWS
aws sts get-caller-identity
```

## 🚀 Fonctionnalités avancées

### 🔄 Reprise après interruption ⭐ NOUVEAU

**Le script peut être interrompu et repris sans perdre de progression !**

Fonctionnement :
- Chaque archive supprimée est **immédiatement retirée** du fichier JSON de travail
- En cas d'interruption (Ctrl+C, crash, perte de connexion), l'état est sauvegardé
- Au redémarrage, le script **reprend exactement là où il s'est arrêté**
- Seules les archives restantes sont traitées

**Exemple :**
```bash
# Lancement initial
./delete_glacier_auto.sh

# Script interrompu après 10,000/10,000 archives
# [Ctrl+C ou crash]

# Reprise - seules les 8,766 archives restantes seront traitées
./delete_glacier_auto.sh
🔄 Reprise détectée : utilisation de l'inventaire de travail existant
🔄 Reprise : 10000/10000 archives déjà supprimées
🧨 8766 archives trouvées dans le vault
```

**Fichiers de reprise :**
- `glacier_inventory/inventory_<vault>.working.json` : inventaire mis à jour en temps réel
- `glacier_inventory/.progress_<vault>` : compteur de progression

Ces fichiers sont automatiquement nettoyés une fois le vault complètement vidé.

### 📋 Logs persistants ⭐ NOUVEAU

**Traçabilité complète de toutes les opérations**

Le script génère un fichier de log horodaté pour chaque exécution :
- Format : `glacier_logs/deletion_YYYYMMDD_HHMMSS.log`
- Tous les événements sont loggés : démarrages, suppressions, erreurs, fins
- Format structuré : `[timestamp] [level] message`
- Niveaux : INFO, WARN, ERROR

**Exemple de log :**
```
[2025-11-02 14:30:15] [INFO] === Démarrage du script de suppression Glacier ===
[2025-11-02 14:30:15] [INFO] Fichier de log : ./glacier_logs/deletion_20251102_143015.log
[2025-11-02 14:30:16] [INFO] Traitement du vault : my_vault_2
[2025-11-02 14:30:20] [INFO] 10000 archives restantes dans le vault my_vault_2
[2025-11-02 14:30:25] [INFO] Progression: 100/10000 archives traitées
[2025-11-02 15:45:30] [WARN] Script interrompu par l'utilisateur (Ctrl+C)
[2025-11-02 15:45:30] [INFO] La progression a été sauvegardée. Relancez le script pour reprendre.
```

**Gestion de Ctrl+C :**
Le script intercepte proprement les interruptions et sauvegarde l'état avant de quitter.

### ✅ Vérification automatique des jobs

Le script `delete_glacier_auto.sh` vérifie automatiquement que les jobs d'inventaire sont terminés avant de télécharger les données. Si un job n'est pas prêt, il passe au suivant.

### 🔁 Système de retry

En cas d'erreur de suppression (throttling AWS, erreurs réseau), le script réessaie automatiquement jusqu'à 3 fois avec une pause de 2 secondes entre chaque tentative.

### 🛡️ Protection contre le rate limiting

Le script ajoute une pause de 0.5 seconde entre chaque suppression d'archive pour éviter d'être throttled par AWS. Ce délai est particulièrement important pour le vault avec 10,000 archives.

### 📊 Progression en temps réel avec ETA

Pour les vaults contenant de nombreuses archives, le script affiche la progression tous les 100 archives avec estimation du temps restant :
```
Progression: 100/10000 archives (1.85/s, ETA: 89min)...
Progression: 200/10000 archives (1.92/s, ETA: 85min)...
```

### 📈 Statistiques détaillées

À la fin de l'exécution, le script affiche :
- Nombre total de vaults traités
- Nombre de vaults supprimés avec succès
- Nombre d'échecs
- Pour chaque vault : nombre d'archives réussies vs échouées
- Chemin vers le fichier de log complet

### 🧹 Nettoyage automatique

Une fois un vault complètement supprimé, tous les fichiers temporaires sont automatiquement nettoyés :
- `job_<vault>.json`
- `inventory_<vault>.json`
- `inventory_<vault>.working.json`
- `.progress_<vault>`

### ✔️ Validation JSON

Le script valide la structure JSON des inventaires avant de les traiter, évitant ainsi les erreurs silencieuses.

## 📝 Notes

- Les vaults doivent être complètement vides avant de pouvoir être supprimés
- Un vault ne peut être supprimé que 24h après la dernière opération d'écriture
- Les inventaires Glacier sont mis à jour toutes les 24h environ
- La suppression de ~355k archives peut prendre plusieurs heures (environ 1-2h avec les pauses anti-throttling)
- **Le script peut être interrompu à tout moment** : la progression est sauvegardée automatiquement
- Les logs sont conservés dans `./glacier_logs/` pour audit et debugging
- Les inventaires téléchargés sont conservés dans `./glacier_inventory/` et réutilisés lors de l'exécution de `--vaults-only`

## 🆘 Scénarios courants

### Le script plante ou je dois l'interrompre

**Pas de panique !** Relancez simplement le script :
```bash
./delete_glacier_auto.sh
```
Il reprendra automatiquement là où il s'est arrêté.

### Je veux voir ce qui s'est passé lors de l'exécution précédente

Consultez le dernier fichier de log :
```bash
ls -lt glacier_logs/
cat glacier_logs/deletion_*.log
```

### Le script est trop lent

Vous pouvez ajuster les paramètres dans le script :
- `DELAY_BETWEEN_DELETES=0.5` → réduire à `0.2` (attention au throttling AWS)
- `MAX_RETRIES=3` → réduire à `1` pour aller plus vite

### Je veux nettoyer manuellement après des tests

```bash
# Nettoyer les inventaires de travail
rm -f glacier_inventory/*.working.json glacier_inventory/.progress_*

# Nettoyer tous les logs
rm -rf glacier_logs/
```
