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
- Lit tous les fichiers `job_*.json`
- Télécharge l'inventaire de chaque vault
- Supprime toutes les archives trouvées
- Supprime le vault vide

**Sortie attendue :**
```
📄 Fichier : job_my_vault_1.json
➡️  Vault : my_vault_1
📥 Téléchargement de l'inventaire...
✅ Inventaire sauvegardé : ./glacier_inventory/inventory_my_vault_1.json
🧨 Archives trouvées :
  - abc123...
  - def456...
🧹 Suppression réelle des archives...
✅ Vault supprimé : my_vault_1
```

## ⚙️ Configuration

Les scripts utilisent les paramètres suivants (modifiables dans chaque script) :

- **ACCOUNT_ID** : `-` (utilise le compte AWS par défaut)
- **REGION** : `eu-west-1` (région de vos vaults)
- **GLACIER_JSON** : `glacier.json` (fichier source des vaults)

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

## 📝 Notes

- Les vaults doivent être complètement vides avant de pouvoir être supprimés
- Un vault ne peut être supprimé que 24h après la dernière opération d'écriture
- Les inventaires Glacier sont mis à jour toutes les 24h environ
