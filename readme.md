Tracy Server est un serveur HTTP qui expose une API complète pour piloter des modèles Ollama, des collections vectorielles Qdrant et des agents RAG/extracteurs. Il se déploie via Docker et fournit sa propre documentation web intégrée.

***

## Présentation

Tracy Server fournit :

- une API REST pour gérer les modèles Ollama, les collections Qdrant, les fichiers indexés, les agents, les conversations et les messages  
- un endpoint de **chat en streaming SSE** pour le dialogue avec un agent  
- un endpoint d’**extraction structurée** pour retourner du JSON typé à partir d’un texte  
- une **documentation HTTP intégrée** disponible après compilation et lancement du serveur

Tracy Server est conçu comme un backend RAG générique : vous configurez vos modèles, collections et agents, puis vous consommez l’API depuis vos applications (front, backend, no-code, etc.).

***

## Architecture & services

Le projet est prévu pour tourner dans un stack Docker Compose avec trois services :

- **ollama**  
  - image : `ollama/ollama:latest`  
  - port : `11434`  
  - volume : `ollama_data:/root/.ollama`  
  - healthcheck TCP sur le port 11434  

- **qdrant**  
  - image : `qdrant/qdrant:latest`  
  - ports : `6333` (HTTP) et `6334` (gRPC)  
  - volume : `qdrant_data:/qdrant/storage`  
  - healthcheck TCP sur le port 6333  

- **tracy**  
  - build local via `Dockerfile`  
  - port exposé : `${PORT:-9090}`  
  - variables d’environnement :  
    - `PORT` : port d’écoute HTTP du serveur  
    - `BASE_URL` : URL publique du serveur (par défaut `http://localhost:9090`)  
  - volume : `tracy_database:/data/database` (base SQLite)  
  - dépendances : attend que `ollama` et `qdrant` soient *healthy* avant de démarrer  

Le `Dockerfile` copie les binaires, la configuration, les assets statiques et les scripts SQL, puis expose le port configuré et lance le binaire `TracyServer` comme `ENTRYPOINT`.

***

## Authentification

L’API est protégée par un middleware d’authentification par **token Bearer**.

- Les routes **publiques** sont uniquement :
  - `GET /` (ping/santé)
  - `GET /docs/` (documentation web)
- Toutes les autres routes nécessitent un header HTTP :

```http
Authorization: Bearer <token>
```

Le token est lu dans le fichier `config/config.json` :

```json
{
  "token": "token d’authentification API",
  "admin_token": "token de licence obtenu à la création du compte"
}
```

Le middleware vérifie :

- présence du header `Authorization`  
- préfixe `Bearer `  
- token non vide  
- égalité stricte entre le token fourni et `config.token`  

En cas d’erreur :

- `401 Unauthorized` : header manquant ou mal formé  
- `403 Forbidden` : token invalide  
- `500 Internal Server Error` : serveur mal configuré (token non défini)

***

## Déploiement & configuration

### Pré-requis

- Docker & Docker Compose  
- (Optionnel) GPU NVIDIA pour accélérer Ollama  
- PowerShell (si vous utilisez le script `Deploy.ps1` sous Windows)

### Configuration du token

Le fichier `config/config.json` contient au minimum :

```json
{
  "token": "sera généré ou mis à jour",
  "admin_token": "votre_token_de_licence"
}
```

Le script `Deploy.ps1` :

1. génère un token aléatoire de 32 octets en Base64  
2. charge ou crée `config/config.json`  
3. ajoute ou met à jour la propriété `token` en conservant `admin_token` et le reste  
4. réécrit le JSON sur disque  
5. reconstruit l’image `tracy` sans cache  
6. redémarre le stack Docker (`docker compose down`, `build`, puis `up -d`)  
7. affiche le token généré dans la console

Exécution :

```powershell
./Deploy.ps1
```

Une fois le stack démarré, l’API est disponible par défaut sur :

```text
http://localhost:9090
```

***

## Documentation

La documentation HTTP (OpenAPI / Scalar) est servie en statique par le serveur lui‑même.

Le routeur Go enregistre :

```go
mux.Handle("GET /docs/", http.StripPrefix("/docs/", http.FileServer(http.Dir("static"))))
```

Cela signifie que :

- le contenu de la documentation front doit être présent dans le dossier `static/` à côté du binaire  
- toutes les ressources (HTML, JS, CSS) sont servies sous le préfixe `/docs/`  

Une fois le serveur compilé et lancé, la doc est donc accessible à l’adresse :

```text
http://localhost:9090/docs/
```

***

## Endpoints HTTP

Le routeur utilise `http.ServeMux` avec la nouvelle syntaxe de patterns `METHOD /path`.  
Ci‑dessous la liste des routes exposées par `Setup`.

### Santé & documentation

- `GET /`  
  Retourne `Tracy is running` (permet de vérifier que le serveur est en ligne).

- `GET /docs/`  
  Sert la documentation statique (Scalar / OpenAPI) depuis le répertoire `static/`.

***

### Models (Ollama)

Gestion des modèles installés sur le service Ollama.

- `GET /model`  
  Liste les modèles actuellement téléchargés sur le serveur.

- `POST /model/download`  
  Lance le téléchargement d’un modèle Ollama, avec progression en **Server‑Sent Events** (SSE).  
  Corps JSON attendu :
  ```json
  { "model": "nom_du_modele" }
  ```

- `DELETE /model`  
  Supprime un modèle Ollama local à partir de son nom.  
  Corps JSON :
  ```json
  { "model": "nom_du_modele" }
  ```

***

### Collections (Qdrant)

Gestion des collections vectorielles Qdrant.

- `GET /collection`  
  Retourne la liste des collections existantes.

- `POST /collection`  
  Crée une nouvelle collection Qdrant.  
  Corps JSON typique :
  ```json
  {
    "name": "documents",
    "size": 768
  }
  ```
  `size` doit correspondre à la dimension du modèle d’embedding.

- `DELETE /collection`  
  Supprime une collection et tous les points associés.  
  Corps JSON :
  ```json
  { "name": "documents" }
  ```

***

### Fichiers de collection

Gestion des fichiers indexés dans une collection Qdrant.

- `GET /collection/file`  
  Liste les fichiers associés à une collection.

- `POST /collection/file`  
  Upload un fichier, en extrait le texte, le découpe en chunks et indexe les vecteurs dans la collection cible.  
  Requête `multipart/form-data` avec :
  - `collection` : nom de la collection  
  - `model` : nom du modèle d’embedding  
  - `file` : fichier à indexer  

- `DELETE /collection/file`  
  Supprime tous les points Qdrant associés à un fichier dans une collection.  
  Corps JSON :
  ```json
  {
    "collection": "documents",
    "name": "rapport_q3.pdf"
  }
  ```

***

### Agents

Gestion des agents RAG et des agents extracteurs.

- `GET /agent`  
  Liste tous les agents enregistrés.

- `GET /agent/name`  
  Récupère un agent par son nom exact.  
  Corps JSON :
  ```json
  { "name": "Assistant RH" }
  ```

- `POST /agent/agent`  
  Crée un agent RAG conversationnel.  
  Corps JSON typique :
  ```json
  {
    "name": "Assistant RH",
    "role": "Tu es un assistant spécialisé en ressources humaines.",
    "folder": "documents",
    "model": "llama3.2",
    "embedding_model": "nomic-embed-text"
  }
  ```

- `POST /agent/extractor`  
  Crée un agent extracteur spécialisé dans l’extraction structurée.  
  Corps JSON typique :
  ```json
  {
    "name": "Extracteur contrats",
    "role": "Tu extrais les informations clés des contrats juridiques.",
    "model": "llama3.2",
    "format": "{ ... schéma JSON ... }"
  }
  ```

- `DELETE /agent`  
  Supprime un agent par son identifiant.  
  Corps JSON :
  ```json
  { "id": 1 }
  ```

***

### Conversations

Gestion des conversations associées à un agent.

- `GET /conversation`  
  Liste les conversations d’un agent.  
  Corps JSON :
  ```json
  { "agent_id": 1 }
  ```

- `POST /conversation`  
  Crée une nouvelle conversation pour un agent existant et injecte le `role` de l’agent comme message système initial.  
  Corps JSON :
  ```json
  { "agent_id": 1 }
  ```

- `DELETE /conversation`  
  Supprime une conversation et tous les messages associés.  
  Corps JSON :
  ```json
  { "conversation_id": 1 }
  ```

***

### Messages

Consultation de l’historique des messages d’une conversation.

- `GET /message`  
  Liste les messages (user + assistant) d’une conversation.  
  Corps JSON :
  ```json
  { "conversation_id": 1 }
  ```

***

### Inférence

#### Chat (SSE)

- `POST /chat`  
  Envoie un prompt à un agent dans le contexte d’une conversation existante.  
  Pipeline :
  1. lecture de l’agent et de la conversation  
  2. si `folder` est défini sur l’agent : recherche RAG des meilleurs chunks (via `embedding_model`)  
  3. construction du prompt complet (system + historique + contexte RAG)  
  4. appel streaming au LLM via Ollama  
  5. persistance du message user et de la réponse complète assistant  

  Corps JSON typique :
  ```json
  {
    "agent_id": 1,
    "conversation_id": 1,
    "prompt": "Ma question...",
    "limit": 5
  }
  ```

  Réponse : flux SSE envoyant la réponse token par token jusqu’à la fin du message.

#### Extraction structurée

- `POST /extract`  
  Soumet un texte à un agent extracteur et retourne un objet JSON structuré conforme au schéma `format` de l’agent.  
  Corps JSON typique :
  ```json
  {
    "agent_id": 1,
    "text": "Texte brut à analyser...",
    "nb": 3
  }
  ```

  Particularités :
  - ne persiste pas de messages  
  - ne tient pas compte d’historique de conversation  
  - renvoie des erreurs spécifiques en cas d’échec de parsing JSON ou d’agent non extracteur

***

## Démarrage rapide

1. **Cloner le dépôt** et se placer à la racine (là où se trouvent `Dockerfile` et `docker-compose.yaml`).  
2. **Configurer `config/config.json`** (au moins `admin_token`).  
3. **Lancer le script de déploiement** (Windows) :
   ```powershell
   ./Deploy.ps1
   ```
   ou, manuellement :
   ```bash
   docker compose down
   docker compose build --no-cache tracy
   docker compose up -d
   ```
4. **Vérifier le serveur** :
   ```bash
   curl http://localhost:9090/
   # Tracy is running
   ```
5. **Ouvrir la documentation** dans un navigateur :
   ```text
   http://localhost:9090/docs/
   ```
6. **Consommer l’API** en ajoutant l’en‑tête `Authorization: Bearer <token>` sur les routes protégées.

***

## Exemple de requêtes

### Lister les modèles

```bash
curl http://localhost:9090/model \
  --header "Authorization: Bearer $TRACY_TOKEN"
```

### Télécharger un modèle

```bash
curl http://localhost:9090/model/download \
  --request POST \
  --header "Authorization: Bearer $TRACY_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{ "model": "llama3.2" }'
```

### Créer une collection

```bash
curl http://localhost:9090/collection \
  --request POST \
  --header "Authorization: Bearer $TRACY_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{ "name": "documents", "size": 768 }'
```

***

Ce README peut être copié tel quel dans `README.md` à la racine du projet Tracy Server.