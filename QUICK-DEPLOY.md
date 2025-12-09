# 🚀 Déploiement Automatique - 3 Étapes

## ✅ Étape 1 : Créer les Secrets GitHub

Dans **Azure Cloud Shell** (https://shell.azure.com) :

```bash
# Créer le Service Principal
az ad sp create-for-rbac \
  --name "github-actions-$(date +%s)" \
  --role contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv) \
  --json-auth
```

**Copiez TOUT le JSON qui s'affiche** ⬇️

## ✅ Étape 2 : Configurer GitHub

1. **Allez dans votre repo GitHub** → **Settings** → **Secrets and variables** → **Actions**

2. **Créez 2 secrets :**
   - Nom : `AZURE_CREDENTIALS`
   - Valeur : **Le JSON copié à l'étape 1**

   - Nom : `DB_ADMIN_PASSWORD`  
   - Valeur : `MySecurePassword123!`

## ✅ Étape 3 : Déclencher le Déploiement

```bash
# Dans votre dossier projet
git push origin main
```

**C'est tout !** 🎉

Le workflow GitHub Actions va :
- ✅ Tester le code
- ✅ Créer l'infrastructure Azure
- ✅ Déployer l'application
- ✅ Vérifier que ça fonctionne

## 🌐 Résultat

Une fois déployé, votre application sera disponible sur :
- **API :** `https://container-platform-api.azurewebsites.net`
- **Frontend :** `https://container-platform-web.azurewebsites.net`

---

## 🔧 Si ça ne marche pas

**Option Alternative :** Script de déploiement direct depuis Azure Cloud Shell

```bash
# Dans Azure Cloud Shell
git clone https://github.com/Sne3P/docker-manager-portal.git
cd docker-manager-portal
./deploy-direct.sh
```