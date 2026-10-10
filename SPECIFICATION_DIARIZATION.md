# SPECIFICATION_DIARIZATION.md

**Projet :** DeepEcho Faster-Whisper  
**Document :** Spécifications fonctionnelles et techniques — diarisation des locuteurs  
**Version du document :** 0.1 — brouillon de spécifications, non implémenté  
**Date :** 2026-10-10  
**Base applicative :** DeepEcho Faster-Whisper V2.0.0  
**Statut :** décisions consignées ; implémentation non autorisée par ce document seul  

> **IMPORTANT :** Document temporaire autonome destiné à éviter toute perte des décisions. Il sera intégré ultérieurement dans `SPECIFICATIONS.md`, puis pourra être supprimé après validation explicite. Ne pas générer ni modifier `SPECIFICATIONS.pdf` avant demande expresse.

## 1. Objet et périmètre

1.1. Ajouter à DeepEcho une fonction **facultative** de diarisation : distinguer les voix et attribuer à chaque passage transcrit une étiquette stable **`PERSONNE 1`**, **`PERSONNE 2`**, etc., pour chaque vidéo.

1.2. Conserver **Faster-Whisper** comme moteur de transcription. La diarisation est une étape complémentaire ; elle ne remplace pas Faster-Whisper.

1.3. Permettre une exploitation fiable des transcriptions dans des workflows ultérieurs (notamment création musicale), où l'utilisateur indiquera lui-même quelle personne correspond à quel locuteur réel. **Ne pas tenter d'identifier automatiquement les personnes par leur nom.**

1.4. Aucun traitement audio supplémentaire (normalisation de volume, amplification, filtrage, optimisation avant transcription) dans cette évolution : ces idées sont **reportées à une autre version**.

1.5. Travail séquentiel conservé pour la transcription récursive. Ne pas lancer plusieurs traitements lourds en parallèle par défaut.

## 2. Moteurs de diarisation

2.1. Deux moteurs envisagés, gratuits et exécutables localement :

- **`pyannote` :** bibliothèque `pyannote.audio`, modèle `pyannote/speaker-diarization-community-1`.
- **`nvidia` :** modèle `Nemotron-3-Diarization` (référence exacte, licence, prérequis CPU/RAM et procédure de téléchargement à confirmer avant implémentation).

2.2. L'utilisateur peut installer **pyannote seul, NVIDIA seul ou les deux**.

2.3. Ne pas supposer que NVIDIA est intrinsèquement plus précis que pyannote ou forcément plus gourmand : cela reste à **mesurer sur la machine et les enregistrements concernés**.

2.4. Aucun modèle ou service payant imposé. Vérifier les licences, les conditions de téléchargement et l'exécution entièrement locale avant intégration.

## 3. Assistant d'installation — questions conditionnelles

3.1. **Question initiale**, dans le workflow des installateurs concernés (`install.sh`, `install_pip.sh`, et toute entrée réelle d'installation utilisée par le projet) :

```text
Voulez-vous installer la fonctionnalité de diarisation ? [Y/N]
```

3.2. **Réponse `N` / `n` :** conserver le comportement d'installation actuel de la V2.0.0 ; ne pas installer les dépendances spécifiques à la diarisation et ne pas télécharger les modèles correspondants.

3.3. **Réponse `Y` / `y` :** demander immédiatement un choix **numéroté** :

```text
Quel(s) moteur(s) de diarisation souhaitez-vous installer ?
  1. Pyannote (Community-1)
  2. NVIDIA (Nemotron-3-Diarization)
  3. Les deux
Choix [1/2/3] :
```

3.4. **Choix `1` :** installer uniquement pyannote et son modèle.

3.5. **Choix `2` :** installer uniquement NVIDIA et son modèle.

3.6. **Choix `3` :** installer les deux moteurs et leurs deux modèles.

3.7. **Immédiatement après le choix 1/2/3**, présenter, pour le ou les modèles concernés, les prérequis exacts d'accès et de téléchargement. Si un compte, une acceptation de licence ou un token est réellement indispensable, fournir l'URL officielle et les étapes. **Ne pas inventer un besoin de token NVIDIA s'il n'existe pas.**

3.8. Si un token indispensable n'est pas disponible, expliquer clairement pourquoi la branche choisie ne peut pas continuer ; proposer de revenir au menu, d'installer l'autre moteur accessible ou de poursuivre sans diarisation. Le comportement exact des retours et des réponses invalides sera spécifié et testé au moment du développement.

3.9. Un token éventuel doit être saisi sans affichage inutile, ne jamais être inscrit en clair dans les scripts, les logs, les documents publics, le dépôt Git ou les livrables. Ne pas exiger d'inscription lorsque le téléchargement public sans compte est possible.

3.10. **L'installation des modèles a lieu pendant l'installation**, et non lors du premier traitement vidéo, pour tous les moteurs sélectionnés. Ne pas re-télécharger inutilement un modèle déjà présent et vérifié.

## 4. Dépendances, compatibilité et stockage des modèles

4.1. Ajouter les composants requis aux scripts d'installation et à la gestion des dépendances (`requirements.txt` ou mécanisme conditionnel équivalent). Attention : **ne pas forcer l'installation des deux moteurs** si l'utilisateur a choisi `N`, `1` ou `2`.

4.2. Respecter la compatibilité Python / PyTorch et les contraintes CPU de Kali Linux ; isoler les environnements si nécessaire pour ne pas casser Faster-Whisper. Les versions de dépendances restent **à vérifier**.

4.3. Stockage local des poids, en conservant la structure des modèles existants :

```text
models/
├── [modèles Faster-Whisper existants — inchangés]
└── diarization/
    ├── pyannote/
    │   └── speaker-diarization-community-1/
    └── nvidia/
        └── nemotron-3-diarization/
```

4.4. Les poids téléchargés ne doivent pas être inclus dans les ZIP de publication ni poussés vers GitHub. Préserver toutes les règles `.gitignore` existantes, sans les écraser ; compléter uniquement si nécessaire et autorisé.

4.5. Exécution locale des modèles après téléchargement. Aucune vidéo ni transcription personnelle transmise à une API externe de diarisation.

## 5. Interface des transcriptions

5.1. **Par défaut : aucune diarisation.** L'absence de l'option `--diarization` maintient le fonctionnement actuel de DeepEcho V2.0.0.

5.2. **`--diarization`** (option sans valeur) active la diarisation.

5.3. **`--diarization-model pyannote|nvidia`** sélectionne explicitement un moteur lorsqu'une diarisation est demandée.

5.4. **Si un seul moteur est installé**, la commande avec `--diarization` seul utilise automatiquement le moteur disponible : pyannote ou NVIDIA.

5.5. **Si les deux moteurs sont installés**, `--diarization` exige la précision supplémentaire `--diarization-model pyannote` ou `--diarization-model nvidia` ; ne pas choisir silencieusement un moteur arbitraire.

5.6. **Si aucun moteur n'est installé**, `--diarization` produit une erreur explicite et actionnable, sans tenter de téléchargement implicite.

5.7. **Sans `--diarization`**, l'argument `--diarization-model` seul ne déclenche pas de diarisation : signaler une combinaison invalide plutôt que l'ignorer silencieusement.

5.8. Conserver les autres options existantes, notamment `--exec`, `--source`, `--recursive`, `--model`, leurs comportements et leurs conventions documentées. Conserver `--model` comme dernier argument **dans les exemples**, conformément aux habitudes du projet.

5.9. Intégrer les nouvelles options dans les aides `--help` de `transcribe.sh` et `transcribe.py`.

### 5.10. Tableau des comportements

| Installation | Invocation | Résultat attendu |
|---|---|---|
| N'importe laquelle | sans `--diarization` | Transcription V2.0.0, sans diarisation |
| Pyannote seul | `--diarization` | Diarisation pyannote |
| NVIDIA seul | `--diarization` | Diarisation NVIDIA |
| Les deux | `--diarization` | Demander explicitement `--diarization-model` / erreur CLI claire |
| Les deux | `--diarization --diarization-model pyannote` | Diarisation pyannote |
| Les deux | `--diarization --diarization-model nvidia` | Diarisation NVIDIA |
| Aucun | `--diarization` | Erreur : aucun moteur installé |
| N'importe laquelle | `--diarization-model nvidia` sans `--diarization` | Erreur de combinaison d'options |

## 6. Attribution des locuteurs

6.1. Identifier le **premier locuteur distinct détecté** comme `PERSONNE 1`, le deuxième comme `PERSONNE 2`, puis poursuivre si plus de deux voix sont détectées.

6.2. La même voix conserve le même identifiant **dans une même vidéo**, dans la limite de fiabilité du modèle.

6.3. Les numéros repartent à zéro pour **chaque nouvelle vidéo**. `PERSONNE 1` n'est pas garanti être la même personne d'un fichier à l'autre.

6.4. Maintenir les timestamps et la transcription verbatim ; ne pas modifier les paroles pour déduire le rôle ou l'identité des personnes.

6.5. Si une attribution est incertaine ou si plusieurs personnes se chevauchent, ne pas inventer une certitude : prévoir une représentation explicite des zones indéterminées ou de chevauchement (convention exacte à finaliser lors de l'implémentation).

## 7. Fichiers Markdown et conservation des résultats

7.1. **Quand la diarisation est activée**, le Markdown **principal situé à côté du MP4** doit contenir les **timestamps + texte + `PERSONNE 1` / `PERSONNE 2` / ...**. Ce fichier devient la sortie maître exploitable par ChatGPT et les workflows musicaux.

7.2. Le Markdown horodaté **classique** qui se trouvait auparavant à côté du MP4 doit, dans ce cas, être **conservé et placé sous le sous-répertoire `.transcription/`** avec les autres sorties de transcription. Ne pas le perdre et ne pas supprimer les formats déjà produits.

7.3. **Quand la diarisation est désactivée**, conserver à l'identique l'organisation et les noms de sortie actuels de la V2.0.0 : le Markdown horodaté classique reste à côté du MP4.

7.4. Les logs et rapports `Processing-Time` sont conservés. Ajouter des temps dédiés à la diarisation dans le rapport de performance lors de l'implémentation, en préservant les champs existants et le format comparable entre moteurs.

7.5. La convention exacte des **noms de fichiers**, des collisions, des erreurs en cours de traitement et du déplacement/écriture sécurisée des fichiers devra être vérifiée sur les sources V2.0.0 avant codage. Aucun écrasement destructif ne doit être introduit sans validation.

7.6. Aucun MP4 ni document personnel (transcription, log, cache de traitement, fichiers temporaires) ne doit être copié dans le **répertoire du dépôt du projet**, même dans une zone ignorée par Git. Les sorties autorisées restent dans les emplacements du workflow vidéo existant.

## 8. Installation conditionnelle et cas d'erreur

8.1. Toute sélection doit être reflétée fidèlement par l'état réel de l'installation : moteur installé, modèle présent, chemin accessible et version vérifiable.

8.2. En cas de modèle absent au moment de l'exécution, indiquer explicitement quel installateur ou téléchargement est nécessaire ; ne pas télécharger automatiquement en arrière-plan.

8.3. Si deux moteurs sont installés, le moteur choisi à l'exécution est celui indiqué par la CLI et non un défaut caché.

8.4. Prévoir des tests pour : `N`, `Y+1`, `Y+2`, `Y+3`, mauvais choix, token manquant si obligatoire, installation partielle, environnement CPU, absence de modèle, commandes récursives, chemins avec espaces et interruption `Ctrl+C`.

## 9. Documentation et statut du projet

9.1. À l'implémentation, mettre à jour au minimum : `transcribe.sh`, `transcribe.py`, `install.sh`, `install_pip.sh`, mécanismes de téléchargement/gestion des modèles concernés, dépendances, `README.md`, `INSTALL.md`, `EXAMPLES.md`, `CHANGELOG.md` et `SPECIFICATIONS.md`.

9.2. Ne pas produire le PDF des spécifications à chaque étape. **`SPECIFICATIONS.pdf` uniquement sur ordre explicite**, en fin de stabilisation.

9.3. **V2.0.0 : inchangée pour l'instant.** Ce document ne constitue ni une implémentation, ni une release, ni un GO de modification du code.

9.4. **GitHub : jamais de push par l'assistant.** L'utilisateur garde seul la décision et l'action de publication. Aucun accès GitHub ne doit être utilisé pour écrire ou pousser sans demande explicite ; la consigne actuelle interdit tout push par l'assistant.

9.5. Ce fichier est **temporaire** ; après l'intégration validée dans les spécifications générales et la release correspondante, sa suppression éventuelle sera décidée par l'utilisateur.

## 10. Points techniques restant à confirmer, sans bloquer la consignation

10.1. Dépôt exact, licences et modalités d'accès actuelles aux poids des deux modèles, notamment nécessité réelle d'un compte/token pour chacun.

10.2. Tailles des modèles, coûts CPU/RAM, compatibilité Python et possibilité de fonctionnement sur Kali sans GPU NVIDIA.

10.3. API et méthode d'association temporelle entre segments Faster-Whisper et locuteurs détectés ; comportement sur locuteurs simultanés.

10.4. Conventions de noms précises des fichiers maître et archivés, et traitement robuste des erreurs.

10.5. Numéro de la future version applicative à fixer lors de l'autorisation d'implémentation.

---

**FIN DU DOCUMENT — SPÉCIFICATIONS CONSIGNÉES, AUCUN CODE MODIFIÉ.**
