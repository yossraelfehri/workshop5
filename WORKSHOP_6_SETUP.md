# Workshop 6 - Distributed Waiting Rooms - Guide de Configuration

## 📋 Prérequis

1. Flutter installé et configuré
2. Compte Supabase créé
3. Projet Supabase initialisé

## 🗄️ Configuration Supabase

### Étape 1 : Créer les tables dans Supabase

1. Connecte-toi à ton projet Supabase
2. Va dans **SQL Editor**
3. Copie et exécute le contenu du fichier `supabase/migrations/001_create_tables.sql`

Ce script va :
- ✅ Créer la table `waiting_rooms` avec les colonnes nécessaires
- ✅ Ajouter la colonne `waiting_room_id` à la table `clients`
- ✅ Créer la clé étrangère entre `clients` et `waiting_rooms`
- ✅ Insérer des données de test (3 salles d'attente)
- ✅ Créer les index pour améliorer les performances

### Étape 2 : Vérifier les tables

Après l'exécution, vérifie que :
- La table `waiting_rooms` existe avec 3 enregistrements
- La table `clients` a la colonne `waiting_room_id`
- La relation entre les tables est bien configurée

## 📱 Configuration de l'application

### Étape 1 : Variables d'environnement

Assure-toi que ton fichier `.env` contient :
```
SUPABASE_URL=ton_url_supabase
SUPABASE_ANON_KEY=ta_clé_anon
```

### Étape 2 : Installer les dépendances

```bash
flutter pub get
```

## 🚀 Utilisation

### Lancer l'application

```bash
flutter run
```

### Ce que tu verras

1. **Écran d'accueil** : Liste des salles d'attente (`RoomListScreen`)
   - Affiche toutes les salles disponibles
   - Clique sur une salle pour voir sa file d'attente

2. **Écran de file d'attente** : (`WaitingRoomScreen`)
   - Bannière de connectivité (rouge si hors ligne)
   - Formulaire pour ajouter un client
   - Liste des clients en attente
   - Bouton "Next Client" pour traiter le premier

## 🔧 Fonctionnalités implémentées

### ✅ Multi-Room Management
- Table `waiting_rooms` créée dans Supabase
- Table `clients` modifiée avec `waiting_room_id`
- Gestion des rooms en local (hors ligne)

### ✅ Auto-Assignment Logic
- Fonction `calculateDistance()` pour calculer la distance
- Fonction `_findNearestRoom()` pour trouver la salle la plus proche
- Attribution automatique lors de l'ajout d'un client

### ✅ Connectivity Awareness
- Package `connectivity_plus` intégré
- `ConnectivityService` pour détecter l'état de connexion
- Bannière visuelle quand hors ligne
- Synchronisation automatique quand la connexion revient

### ✅ Realtime Per Room
- Méthode `subscribeToRoom()` pour s'abonner à une salle spécifique
- Filtrage par `waiting_room_id`
- Annulation de l'ancienne souscription avant d'en créer une nouvelle

### ✅ Scalable UI
- `RoomListScreen` pour sélectionner une salle
- `ListView.builder` pour un rendu efficace
- Pagination implémentée (20 clients par page)

### ✅ Support Hors Ligne
- Base de données locale SQLite
- Sauvegarde automatique des rooms et clients
- Synchronisation automatique quand en ligne
- Fonctionne complètement sans connexion

## 🧪 Tests

Exécuter tous les tests :
```bash
flutter test
```

Tests disponibles :
- ✅ `location_utils_test.dart` - Test de calcul de distance
- ✅ `connectivity_widget_test.dart` - Test de la bannière offline
- ✅ `queue_provider_geolocation_test.dart` - Test de géolocalisation
- ✅ `waiting_room_widget_test.dart` - Tests widget complets

## 📝 Structure des fichiers

```
lib/
├── main.dart                    # Point d'entrée, configuration providers
├── room_list_screen.dart        # Écran de sélection des salles
├── queue_provider.dart          # Gestion de la file d'attente
├── connectivity_service.dart    # Détection de connectivité
├── location_utils.dart          # Calcul de distance
├── local_queue_service.dart     # Base de données locale
├── models/
│   └── client.dart              # Modèle Client avec waiting_room_id
└── geolocation_service.dart     # Service de géolocalisation

supabase/
└── migrations/
    └── 001_create_tables.sql    # Script SQL pour créer les tables

test/
├── location_utils_test.dart
├── connectivity_widget_test.dart
├── queue_provider_geolocation_test.dart
└── waiting_room_widget_test.dart
```

## 🔍 Dépannage

### Problème : "Location not captured"
- **Normal** si : GPS désactivé, permissions refusées, mode test
- **Anormal** si : GPS activé et permissions accordées → vérifier les logs

### Problème : Pas de rooms affichées
- Vérifier que le script SQL a bien été exécuté
- Vérifier la connexion Supabase
- Les rooms sont chargées depuis le local si hors ligne

### Problème : Synchronisation ne fonctionne pas
- Vérifier que `ConnectivityService` est bien fourni
- Vérifier les logs pour les erreurs de sync
- Les données restent en local et seront syncées plus tard

## 📚 Documentation supplémentaire

- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [Flutter Provider](https://pub.dev/packages/provider)
- [SQLite Flutter](https://pub.dev/packages/sqflite)

