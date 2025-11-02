# Gestion des Vaults AWS Glacier

Scripts pour automatiser la suppression complète des vaults AWS Glacier et de leurs archives.

## 📁 Fichiers du projet

- **glacier.json** : Liste des vaults Glacier à traiter (6 vaults)
- **init_glacier_inventory.sh** : Lance les jobs d'inventaire pour tous les vaults
- **check_glacier_jobs.sh** : Vérifie l'état d'avancement des jobs
- **delete_glacier_auto.sh** : Supprime les archives et les vaults

## 🚀 Workflow complet

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
├── glacier.json                    # Configuration des vaults
├── init_glacier_inventory.sh       # Script 1
├── check_glacier_jobs.sh           # Script 2
├── delete_glacier_auto.sh          # Script 3
├── job_my_vault_*.json          # Job IDs (créés par script 1)
└── glacier_inventory/              # Inventaires téléchargés
    └── inventory_my_vault_*.json
```

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

- AWS CLI installé et configuré
- `jq` installé (pour le parsing JSON)
- Bash 4.0+
- Credentials AWS configurées (`~/.aws/credentials` ou variables d'environnement)

## 🚀 Fonctionnalités avancées

### Vérification automatique des jobs

Le script `delete_glacier_auto.sh` vérifie automatiquement que les jobs d'inventaire sont terminés avant de télécharger les données. Si un job n'est pas prêt, il passe au suivant.

### Système de retry

En cas d'erreur de suppression (throttling AWS, erreurs réseau), le script réessaie automatiquement jusqu'à 3 fois avec une pause de 2 secondes entre chaque tentative.

### Protection contre le rate limiting

Le script ajoute une pause de 0.5 seconde entre chaque suppression d'archive pour éviter d'être throttled par AWS. Ce délai est particulièrement important pour le vault avec 10,000 archives.

### Progression en temps réel

Pour les vaults contenant de nombreuses archives, le script affiche la progression tous les 100 archives :
```
Progression: 100/10000 archives traitées...
Progression: 200/10000 archives traitées...
```

### Statistiques détaillées

À la fin de l'exécution, le script affiche :
- Nombre total de vaults traités
- Nombre de vaults supprimés avec succès
- Nombre d'échecs
- Pour chaque vault : nombre d'archives réussies vs échouées

### Validation JSON

Le script valide la structure JSON des inventaires avant de les traiter, évitant ainsi les erreurs silencieuses.

## 📝 Notes

- Les vaults doivent être complètement vides avant de pouvoir être supprimés
- Un vault ne peut être supprimé que 24h après la dernière opération d'écriture
- Les inventaires Glacier sont mis à jour toutes les 24h environ
- La suppression de ~355k archives peut prendre plusieurs heures (environ 1-2h avec les pauses anti-throttling)
- Les inventaires téléchargés sont conservés dans `./glacier_inventory/` et réutilisés lors de l'exécution de `--vaults-only`
