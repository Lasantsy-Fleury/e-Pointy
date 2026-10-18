# Brief projet — Application mobile de pointage des distributions alimentaires

## 1. Présentation du projet

### 1.1. Contexte

Lors d’un voyage d’étude, l’organisation doit distribuer plusieurs types de ravitaillement aux étudiants : petit-déjeuner, déjeuner, dîner, eau et, éventuellement, d’autres articles ou collations. Il est important de savoir rapidement qui a reçu quoi, à quel moment et pour quelle distribution.

Un pointage manuel sur papier peut être lent, difficile à consolider et sujet aux erreurs : doublons, oublis, listes qui ne sont pas à jour ou difficulté à transmettre les informations lorsqu’une équipe de pointeurs prend le relais.

### 1.2. Objectif général

Créer une application mobile développée avec Flutter permettant de gérer et de suivre les distributions destinées aux étudiants pendant un voyage d’étude, en privilégiant le fonctionnement **hors ligne** et la continuité du pointage entre plusieurs appareils.

L’application doit rester utilisable sans connexion Internet. La connexion pourra être utilisée lorsqu’elle est disponible pour échanger les données entre appareils, effectuer une sauvegarde ou exporter les résultats, mais elle ne doit pas être indispensable au pointage quotidien.

### 1.3. Objectifs spécifiques

- Importer une liste d’étudiants depuis un fichier Excel `.xlsx`.
- Configurer les jours, les repas et les autres éléments à distribuer.
- Identifier un étudiant à partir d’un QR code et enregistrer la réception d’une distribution.
- Empêcher ou signaler les doubles pointages pour une même distribution.
- Consulter rapidement les étudiants déjà servis et ceux qui ne le sont pas encore.
- Permettre à plusieurs pointeurs de se relayer, y compris avec des appareils différents.
- Synchroniser les données sans perdre les pointages enregistrés hors ligne.
- Fournir des statistiques et des exports utiles à l’équipe organisatrice.

## 2. Principes et contraintes

### 2.1. Fonctionnement hors ligne en priorité

Les fonctions essentielles doivent fonctionner sans Internet : consultation de la liste, recherche d’un étudiant, lecture d’un QR code, enregistrement d’un pointage, consultation des statuts, configuration d’une distribution déjà chargée et consultation des statistiques locales.

Les données enregistrées localement doivent survivre à la fermeture ou au redémarrage de l’application. L’interface doit indiquer clairement si les données sont locales, synchronisées ou en attente de synchronisation.

### 2.2. Synchronisation adaptée au relais entre pointeurs

Le relais entre appareils doit être prévu dès la conception fonctionnelle. Le simple fait de stocker les données localement sur chaque téléphone ne suffit pas : deux appareils déconnectés peuvent enregistrer des informations différentes.

Le projet doit permettre de transférer et de fusionner les données de pointage de façon contrôlée, sans écraser les enregistrements existants. Les mécanismes possibles pourront être étudiés librement : synchronisation directe entre appareils sur un réseau local, échange par fichier ou support amovible, synchronisation via un service distant lorsque disponible, ou combinaison de plusieurs méthodes. **Aucune architecture technique particulière n’est imposée par ce brief.**

La méthode retenue devra préciser :
- comment les appareils se découvrent ou échangent leurs données ;
- comment le transfert est initié et confirmé ;
- comment les modifications concurrentes sont traitées ;
- comment les doublons sont détectés ;
- comment l’utilisateur sait que le transfert est terminé et fiable ;
- comment reprendre un transfert interrompu.

### 2.3. Simplicité d’utilisation

L’application sera utilisée dans un contexte de distribution où la rapidité est importante. Les actions courantes doivent être réalisables en peu de manipulations, avec des messages lisibles et un retour visuel immédiat après chaque scan.

### 2.4. Intégrité des données

Un pointage ne doit pas être considéré comme réussi si son enregistrement local a échoué. Les données doivent rester consultables après redémarrage et les erreurs de synchronisation doivent être explicites. Toute correction manuelle doit être traçable.

## 3. Utilisateurs et rôles fonctionnels

Les rôles ci-dessous sont des propositions fonctionnelles, à adapter aux besoins réels.

### 3.1. Responsable du voyage ou administrateur

Peut :
- créer et configurer une session de voyage d’étude ;
- importer, vérifier et mettre à jour la liste des étudiants ;
- créer les jours et les distributions ;
- générer ou exporter les QR codes si cette fonction est retenue ;
- consulter les statistiques globales ;
- effectuer ou autoriser les corrections de pointage ;
- gérer les transferts et les exports de données.

### 3.2. Pointeur

Peut :
- sélectionner la session et la distribution active ;
- scanner les QR codes ;
- rechercher un étudiant manuellement si le scan est impossible ;
- voir le résultat du pointage et les alertes de doublon ;
- consulter, selon les permissions accordées, l’avancement de la distribution ;
- envoyer ou recevoir les données nécessaires au relais.

### 3.3. Consultation seule (optionnel)

Peut consulter les listes et les statistiques sans modifier les pointages. Ce rôle peut être utile pour les responsables qui supervisent la distribution.

L’application peut fonctionner sans compte en ligne. Si une authentification est ajoutée, elle ne doit pas empêcher le fonctionnement hors ligne après la préparation de la session.

## 4. Gestion de la session de voyage

L’application doit permettre de créer une session correspondant à un voyage d’étude.

Informations possibles :
- nom ou intitulé du voyage ;
- établissement ou groupe concerné, si utile ;
- date de début et date de fin ;
- nombre estimé d’étudiants ;
- responsable et notes facultatives ;
- statut : préparation, en cours, clôturée ou archivée.

Chaque session doit isoler ses étudiants, ses distributions et ses pointages afin d’éviter de mélanger les données de deux voyages.

Une session clôturée doit rester consultable et exportable. La réouverture d’une session clôturée doit être une action volontaire.

## 5. Importation et gestion des étudiants

### 5.1. Importation Excel

L’application doit permettre d’importer un fichier `.xlsx` contenant exactement les deux colonnes fonctionnelles suivantes :

| Colonne | Description |
|---|---|
| `Matricule` | Identifiant de l’étudiant, unique au sein de la session |
| `Nom et Prénoms` | Nom complet affiché dans l’application |

L’ordre des colonnes peut être reconnu automatiquement si les en-têtes sont présents. Si le format n’est pas reconnu, l’application doit expliquer le problème plutôt que d’importer silencieusement des données incorrectes.

### 5.2. Prévisualisation et validation avant import

Avant de confirmer l’importation, afficher un résumé comprenant :
- nombre de lignes détectées ;
- nombre de lignes valides ;
- matricules manquants ;
- noms manquants ;
- matricules en double ;
- lignes ignorées ou comportant des erreurs ;
- nombre d’étudiants qui seront ajoutés ou mis à jour.

Le responsable doit pouvoir annuler l’importation ou confirmer après vérification. Les erreurs doivent être associées aux lignes concernées, avec un moyen pratique de les corriger dans le fichier source.

### 5.3. Règles de validation

- Le matricule est traité comme du texte afin de préserver les zéros initiaux.
- Le matricule est obligatoire et doit être unique dans la session.
- Le nom et les prénoms sont obligatoires.
- Les espaces superflus peuvent être supprimés sans altérer le nom affiché.
- Une ligne invalide ne doit pas créer un étudiant incomplet.
- Un nouvel import ne doit pas effacer les pointages existants par accident.
- Si un matricule déjà connu apparaît avec un nom différent, demander une confirmation ou présenter un avertissement.
- Définir explicitement si l’import met à jour la liste existante, ajoute uniquement les nouveaux étudiants ou remplace la liste. Le remplacement complet doit être protégé par une confirmation.

### 5.4. Gestion manuelle

Prévoir la possibilité, si nécessaire, d’ajouter un étudiant manuellement, de modifier son nom, de le désactiver ou de corriger son matricule. Les modifications importantes doivent être tracées. La suppression définitive d’un étudiant ayant déjà des pointages doit être évitée ; une désactivation est généralement préférable.

### 5.5. Recherche et consultation

La liste doit pouvoir être recherchée par matricule ou par nom. Elle doit afficher le statut de l’étudiant pour la distribution sélectionnée : reçu, non reçu ou statut nécessitant une vérification.

## 6. Configuration des distributions

### 6.1. Types de distribution configurables

Ne pas limiter l’application aux trois repas classiques. Le responsable doit pouvoir créer librement des éléments distribués, par exemple :
- petit-déjeuner ;
- déjeuner ;
- dîner ;
- bouteille d’eau ou ration d’eau ;
- collation ;
- panier ou kit ;
- autre article défini par l’organisateur.

Chaque élément doit posséder au minimum un nom et un statut actif/inactif. Des informations facultatives peuvent être ajoutées : description, unité, quantité prévue, consigne de distribution ou catégorie.

### 6.2. Organisation par jour et par créneau

Le responsable doit pouvoir préparer les distributions pour chaque journée du voyage. Exemple :
- Jour 1 — Petit-déjeuner ;
- Jour 1 — Eau du matin ;
- Jour 1 — Déjeuner ;
- Jour 1 — Eau de l’après-midi ;
- Jour 1 — Dîner ;
- Jour 2 — mêmes distributions, avec la possibilité de modifier le programme.

Une distribution peut être définie par :
- date ou journée du voyage ;
- nom de la distribution ;
- heure indicative de début et de fin ;
- quantité ou unité, si nécessaire ;
- statut : à venir, ouverte, suspendue ou clôturée ;
- consignes destinées aux pointeurs.

Les horaires sont indicatifs et ne doivent pas empêcher un pointage légitime si la distribution est en retard. Le responsable peut ouvrir ou clôturer manuellement une distribution.

### 6.3. Modèles réutilisables

Permettre de créer un modèle de journée, par exemple « 3 repas + 2 distributions d’eau », puis de le réutiliser sur plusieurs jours. Le modèle doit rester modifiable pour une journée précise sans changer automatiquement toutes les autres journées déjà préparées.

### 6.4. Quantités et unités (option à confirmer)

Pour les distributions en plusieurs unités, prévoir la possibilité de préciser une quantité : par exemple deux bouteilles par étudiant. Il faut distinguer :
- un pointage simple indiquant que l’étudiant a reçu sa dotation ;
- un pointage avec quantité réellement remise.

La règle doit être définie par distribution. Par défaut, une distribution simple ne doit autoriser qu’un seul pointage validé par étudiant et par distribution.

## 7. QR codes et identification des étudiants

### 7.1. Association d’un QR code à un étudiant

Chaque étudiant doit pouvoir être identifié par un QR code unique ou par un QR code contenant un identifiant vérifiable. Le QR code ne devrait pas exposer inutilement des informations personnelles. Un matricule ou un identifiant de session peut suffire.

Le brief ne présume pas que les QR codes existent déjà : l’application peut proposer de les générer, les afficher ou les exporter pour impression si cette fonctionnalité est retenue.

### 7.2. Écran de scan

L’écran de scan doit :
- ouvrir rapidement la caméra ;
- fournir une indication claire lorsque le code est détecté ;
- identifier l’étudiant et la distribution active ;
- enregistrer le pointage localement ;
- afficher immédiatement le résultat ;
- permettre de reprendre le scan suivant sans revenir à plusieurs écrans ;
- proposer une saisie ou une recherche manuelle en cas de QR code illisible, de caméra indisponible ou de badge oublié.

### 7.3. Résultats possibles après un scan

Afficher un message distinct selon le résultat :
- **Pointage enregistré** : l’étudiant a été marqué comme servi pour cette distribution ;
- **Déjà servi** : un pointage existe déjà pour cette distribution ;
- **Étudiant inconnu** : le matricule ou l’identifiant du QR code ne correspond pas à la liste chargée ;
- **Mauvaise session** : le code correspond à une autre session ou n’est pas valide pour celle-ci ;
- **Distribution clôturée** : la distribution n’accepte plus de nouveaux pointages, sauf autorisation particulière ;
- **Erreur d’enregistrement** : le pointage n’a pas été confirmé comme enregistré.

Le nom, le matricule et le statut doivent être lisibles. Utiliser des couleurs comme indication secondaire, et non comme unique moyen de compréhension.

### 7.4. Prévention des doubles pointages

La règle par défaut est : **un étudiant ne peut recevoir qu’un pointage validé par distribution**. Si le même QR code est scanné une deuxième fois, l’application affiche le pointage existant sans créer une seconde réception.

Si une distribution autorise exceptionnellement plusieurs unités ou passages, cette règle doit être explicitement configurée et l’interface doit afficher la quantité ou les passages restants. Une correction de doublon doit nécessiter une action autorisée et laisser une trace.

### 7.5. Pointage manuel de secours

En cas de badge perdu, de QR code endommagé ou de problème de caméra, le pointeur doit pouvoir rechercher l’étudiant et enregistrer le pointage manuellement si ses permissions le permettent. Le pointage doit être marqué comme manuel pour faciliter les vérifications.

## 8. Historique des pointages

Chaque réception enregistrée doit conserver les informations utiles à l’audit :
- session ;
- étudiant ;
- distribution ;
- date et heure enregistrées par l’appareil ;
- appareil ou identifiant local de l’appareil, si disponible ;
- pointeur ou profil utilisé, si disponible ;
- mode de saisie : QR code ou manuel ;
- état de synchronisation ;
- éventuelle correction, annulation ou justification.

L’application doit présenter l’historique d’un étudiant et l’historique d’une distribution. Une correction ne doit pas supprimer silencieusement la trace initiale : conserver l’événement initial et enregistrer la correction avec sa raison et son auteur, dans la mesure des informations disponibles.

Comme les horloges des téléphones peuvent être différentes ou incorrectes, l’heure locale doit être interprétée avec prudence lors de la synchronisation. Un identifiant unique d’événement et des règles de fusion fiables sont plus importants que l’ordre des heures seul.

## 9. Synchronisation et relais entre appareils

### 9.1. Objectif

Permettre à un pointeur de commencer le pointage sur un appareil, puis à un autre pointeur de continuer sur un autre appareil, sans perdre les pointages déjà effectués et sans recommencer la liste depuis zéro.

### 9.2. Scénarios à prendre en charge

- Un seul téléphone utilisé pendant toute la journée, sans Internet.
- Deux téléphones utilisés successivement, avec transfert de données au moment du relais.
- Plusieurs téléphones utilisés pendant la même distribution, éventuellement hors ligne.
- Un appareil qui reste hors ligne puis rejoint le groupe plus tard.
- Un transfert interrompu ou répété.
- Deux appareils qui ont enregistré le même étudiant avant d’avoir échangé leurs données.
- Une session préparée sur un appareil puis transférée vers un ou plusieurs autres appareils.

### 9.3. Données à transférer

Le transfert doit pouvoir inclure, selon le besoin :
- les informations de la session ;
- la liste des étudiants ;
- la configuration des journées et distributions ;
- les pointages et leur historique ;
- les paramètres nécessaires à l’interprétation des données ;
- la version du jeu de données ou un marqueur de synchronisation.

Les données personnelles doivent être limitées au nécessaire. Le transfert doit éviter d’exporter des informations étrangères à la session.

### 9.4. Règles de fusion et conflits

- Un même événement reçu plusieurs fois ne doit être appliqué qu’une seule fois.
- Les pointages valides ne doivent pas être supprimés par une synchronisation ultérieure.
- Si deux appareils ont pointé le même étudiant pour la même distribution, le résultat doit être signalé comme doublon potentiel ou fusionné selon la règle métier ; il ne doit pas augmenter artificiellement le nombre d’étudiants servis.
- Les modifications de configuration doivent être identifiables afin d’éviter de fusionner des sessions incompatibles.
- Une session ou une distribution doit posséder un identifiant stable commun sur tous les appareils.
- En cas de conflit non résoluble automatiquement, l’application doit présenter une explication et une action de résolution explicite.

### 9.5. Interface de synchronisation

Prévoir un écran ou un panneau permettant de :
- voir l’état de l’appareil : hors ligne, prêt à transférer, transfert en cours, synchronisé ou erreur ;
- lancer l’envoi ou la réception ;
- identifier la session concernée ;
- visualiser le nombre d’étudiants, de distributions et de pointages échangés ;
- confirmer la fin du transfert ;
- relancer un transfert échoué ;
- afficher les éventuels conflits ou doublons à vérifier.

Ne pas afficher « Synchronisé » avant que le transfert et la vérification des données aient effectivement abouti.

### 9.6. Sécurité des transferts

Si un transfert direct ou par fichier est utilisé, prévoir des contrôles afin d’éviter l’import accidentel de données d’une autre session. Les exports contenant des données d’étudiants devraient être identifiés clairement et, si pertinent, protégés contre l’accès non autorisé.

## 10. Tableau de bord et suivi de la distribution

Pour la distribution sélectionnée, afficher au minimum :
- nombre total d’étudiants inscrits ;
- nombre d’étudiants servis ;
- nombre d’étudiants non encore servis ;
- taux de couverture ;
- nombre de doublons ou de pointages à vérifier ;
- nombre de pointages effectués manuellement ;
- état de synchronisation des données.

Exemple : « Petit-déjeuner — 126 servis sur 150 — 84 % — 24 restants ».

Permettre de consulter :
- l’avancement par distribution ;
- le récapitulatif de la journée ;
- les étudiants servis ou non servis ;
- le récapitulatif de l’ensemble du voyage ;
- les distributions clôturées et leur bilan.

Les chiffres doivent être calculés à partir des pointages uniques validés, et non du nombre brut d’événements reçus après synchronisation.

## 11. Listes et outils de contrôle

Prévoir les vues suivantes :
- liste complète des étudiants ;
- liste des étudiants servis pour la distribution active ;
- liste des étudiants qui restent à servir ;
- fiche d’un étudiant avec ses distributions reçues et manquantes ;
- liste des pointages manuels ;
- liste des doublons potentiels et anomalies ;
- liste des données en attente de synchronisation.

Des filtres par nom, matricule, journée, distribution et statut doivent faciliter le contrôle. Une liste « restants à servir » doit se mettre à jour immédiatement après un pointage.

## 12. Exportation et sauvegarde

Prévoir l’export des résultats dans un format exploitable, idéalement `.xlsx` et/ou `.csv`, avec des colonnes clairement nommées. Les exports possibles comprennent :
- liste des étudiants ;
- récapitulatif par distribution ;
- détail des pointages ;
- étudiants n’ayant pas reçu une distribution ;
- bilan global du voyage ;
- anomalies et corrections.

Les exports doivent préciser la session, la date de génération et les distributions concernées. Les matricules doivent rester au format texte pour conserver les zéros initiaux.

Prévoir également un moyen de sauvegarder et de restaurer les données d’une session sans dépendre d’Internet. La restauration doit être validée avant de remplacer ou fusionner les données présentes sur l’appareil.

## 13. Paramètres et règles opérationnelles

Prévoir des paramètres pour :
- le nom de la session ;
- les informations d’identification de l’équipe ou de l’organisateur ;
- la règle de pointage unique ou multiple par distribution ;
- les permissions de correction ;
- l’ouverture et la clôture d’une distribution ;
- la méthode de transfert/synchronisation retenue ;
- la politique d’export et de sauvegarde.

Les paramètres essentiels d’une session doivent être transférés avec celle-ci. Une modification importante en cours de voyage doit être signalée aux autres appareils lors de la prochaine synchronisation.

## 14. Ergonomie et expérience utilisateur

- Interface en français par défaut, avec possibilité d’ajouter d’autres langues si nécessaire.
- Utilisation confortable sur les tailles d’écran Android courantes.
- Boutons et textes assez grands pour être utilisés rapidement sur le terrain.
- Contraste suffisant et statuts compréhensibles sans dépendre uniquement des couleurs.
- Accès rapide au scan depuis l’écran principal de la distribution.
- Retour visuel et sonore facultatif après un scan réussi, configurable pour ne pas gêner l’environnement.
- Confirmation pour les actions risquées : clôture, remplacement de liste, restauration, correction ou suppression.
- Indication claire du jour, du repas et de la session actifs afin de réduire les erreurs de pointage.
- Gestion des refus de permission caméra, des interruptions et des erreurs de lecture.
- Écrans de chargement et d’erreur compréhensibles, sans bloquer inutilement le pointage hors ligne.

## 15. Sécurité, confidentialité et fiabilité

- Ne collecter que les données nécessaires à l’identification et au suivi des étudiants.
- Éviter d’inscrire le nom complet dans le QR code si un identifiant suffit.
- Protéger l’accès aux fonctions d’administration et de correction selon le niveau de risque.
- Limiter l’exposition des fichiers exportés et des sauvegardes.
- Prévenir les suppressions accidentelles et conserver une trace des corrections.
- Afficher clairement les erreurs d’écriture, d’import et de synchronisation.
- Ne pas dépendre de la connexion Internet pour vérifier l’identité d’un étudiant déjà importé dans la session.
- Prévoir une stratégie de récupération en cas de fermeture inattendue, batterie vide ou redémarrage.
- Définir une règle de conservation et de suppression des données après le voyage.

## 16. Exigences non fonctionnelles

### Performance
- Le scan et la validation d’un étudiant doivent être suffisamment rapides pour maintenir un flux de distribution.
- La recherche doit rester réactive avec une liste de plusieurs centaines ou milliers d’étudiants.
- L’ouverture d’une distribution et l’affichage des compteurs ne doivent pas nécessiter une connexion Internet.

### Fiabilité
- Un pointage confirmé doit rester enregistré après fermeture et réouverture de l’application.
- Une interruption pendant un transfert ne doit pas laisser croire que les données sont synchronisées.
- La répétition d’une opération de transfert ne doit pas créer de doublons.
- Les données doivent pouvoir être sauvegardées et restaurées.

### Compatibilité
- Application mobile Flutter, avec Android comme plateforme prioritaire si aucune autre plateforme n’est spécifiée.
- Les exigences de version minimale Android, les modèles de téléphones et les capacités caméra devront être confirmés.
- Le fonctionnement sur iOS peut être évalué si le parc d’appareils le nécessite.

### Maintenabilité
Le projet doit rester simple à faire évoluer. Ce brief décrit les besoins fonctionnels et les critères attendus ; il n’impose ni framework complémentaire, ni base de données, ni backend, ni protocole de synchronisation, ni organisation des dossiers. Les choix techniques devront être justifiés par les contraintes réelles, en particulier le fonctionnement hors ligne et les échanges entre appareils.

## 17. Parcours utilisateur principaux

### Parcours A — Préparer le voyage
1. Le responsable crée une session.
2. Il importe le fichier Excel.
3. Il vérifie les erreurs et confirme la liste.
4. Il configure les journées et les distributions.
5. Il génère ou importe les QR codes, si nécessaire.
6. Il prépare les données pour les appareils qui participeront au pointage.

### Parcours B — Pointer un repas hors ligne
1. Le pointeur ouvre la session et choisit la distribution active.
2. Il lance le scanner.
3. Il scanne le QR code d’un étudiant.
4. L’application identifie l’étudiant et vérifie son statut.
5. Le pointage est enregistré localement et un résultat explicite est affiché.
6. Le pointeur passe directement à l’étudiant suivant.
7. Le compteur de progression est mis à jour.

### Parcours C — Détecter un doublon
1. Un QR code déjà pointé est scanné à nouveau.
2. L’application retrouve le pointage existant.
3. Elle affiche « Déjà servi » et ne crée pas de deuxième réception validée.
4. Si une correction est nécessaire, un utilisateur autorisé suit la procédure de correction.

### Parcours D — Relais entre deux pointeurs
1. Le premier pointeur termine ou suspend son travail.
2. Les deux appareils établissent un moyen de transfert disponible ou utilisent le mécanisme d’échange prévu.
3. Le second appareil reçoit la session, les étudiants, la configuration et les nouveaux pointages.
4. L’application vérifie et fusionne les données.
5. Le second pointeur contrôle le bilan de synchronisation.
6. Il poursuit le pointage hors ligne avec les données actualisées.

### Parcours E — Clôturer et exporter
1. Le responsable clôture la distribution ou la session.
2. L’application présente les chiffres finaux et les anomalies.
3. Le responsable vérifie les pointages manuels et les doublons potentiels.
4. Il exporte le bilan et crée une sauvegarde.
5. La session reste consultable pour un contrôle ultérieur.

## 18. Règles métier à valider

Les règles suivantes doivent être confirmées avec l’organisateur avant ou pendant la réalisation :

1. **Unicité du matricule :** le matricule est-il unique uniquement dans un voyage ou également à l’échelle de l’établissement ?
2. **QR codes :** les étudiants possèdent-ils déjà un QR code, ou l’application doit-elle les générer et permettre leur impression ?
3. **Distribution multiple :** chaque étudiant reçoit-il une seule unité de chaque élément, ou certaines distributions autorisent-elles plusieurs quantités ?
4. **Pointages manuels :** quels rôles peuvent valider un étudiant sans QR code ?
5. **Corrections :** qui peut annuler ou modifier un pointage et quelle justification doit être fournie ?
6. **Relais :** les appareils se relaient-ils généralement l’un après l’autre, ou plusieurs pointeurs travaillent-ils simultanément ?
7. **Moyens de transfert disponibles :** les téléphones pourront-ils utiliser le Wi-Fi local, le Bluetooth, un partage de fichier ou une connexion Internet ponctuelle ?
8. **Nombre d’appareils :** combien de téléphones devront partager les mêmes données ?
9. **Mise à jour de la liste :** peut-on ajouter ou modifier des étudiants une fois le voyage commencé ?
10. **Clôture :** un pointage tardif est-il interdit, autorisé ou soumis à une permission ?
11. **Langues :** l’application doit-elle être disponible uniquement en français ou également en malgache ?
12. **Plateformes :** Android uniquement ou Android et iOS ?
13. **Rapports :** quels formats et indicateurs sont indispensables pour le responsable ?
14. **Sauvegarde :** où les sauvegardes doivent-elles être conservées et combien de temps ?
15. **Confidentialité :** qui est autorisé à consulter la liste complète des étudiants et leur historique ?

## 19. Périmètre suggéré pour une première version (MVP)

La première version devrait privilégier un flux complet, fiable et testable plutôt qu’une multitude d’options.

### Indispensable
- Création et sélection d’une session de voyage.
- Importation `.xlsx` avec les colonnes `Matricule` et `Nom et Prénoms`.
- Validation, aperçu et signalement des erreurs d’import.
- Configuration des journées et des distributions personnalisées.
- Génération ou association d’un QR code à chaque étudiant, selon le besoin confirmé.
- Scan et pointage hors ligne.
- Prévention des doubles pointages par étudiant et distribution.
- Recherche manuelle d’un étudiant comme solution de secours.
- Compteurs des étudiants servis et restants.
- Stockage local persistant.
- Transfert et fusion des données entre appareils sans Internet selon une méthode validée.
- Export du bilan et sauvegarde/restauration hors ligne.

### Améliorations ultérieures possibles
- Gestion avancée des rôles et des autorisations.
- Historique d’audit plus détaillé.
- Modèles de journées réutilisables.
- Gestion de quantités distribuées.
- Tableau de bord global multi-jours.
- Synchronisation Internet facultative ou sauvegarde distante.
- Rapports personnalisés et impression.
- Prise en charge multilingue.
- Détection et résolution assistées des conflits.
- Import de QR codes déjà existants.

## 20. Critères d’acceptation

Le projet pourra être considéré comme fonctionnel lorsque les scénarios suivants seront démontrés :

1. Un fichier Excel valide avec les deux colonnes attendues peut être importé sans Internet.
2. Un fichier comportant des matricules dupliqués ou des cellules obligatoires vides produit un rapport d’erreurs compréhensible.
3. Le responsable peut configurer au moins trois repas par jour ainsi qu’une ou plusieurs distributions d’eau, sans que ces catégories soient codées en dur.
4. Un étudiant connu peut être pointé par QR code sans connexion Internet.
5. Le pointage reste présent après fermeture et redémarrage de l’application.
6. Le scan répété du même étudiant pour la même distribution affiche un doublon et ne compte pas une seconde réception.
7. Un QR code inconnu ou invalide ne crée aucun pointage étudiant.
8. Le pointeur peut retrouver un étudiant par matricule ou nom si le scan est impossible.
9. Les compteurs « servis » et « restants » correspondent aux étudiants uniques effectivement pointés.
10. Les données d’une session peuvent être transférées à un second appareil sans Internet par le mécanisme retenu.
11. La répétition du transfert ne duplique pas les pointages.
12. Les pointages créés sur deux appareils peuvent être fusionnés sans perdre les événements valides.
13. L’application indique clairement les transferts échoués, incomplets ou nécessitant une vérification.
14. Un bilan peut être exporté dans un format exploitable, et une sauvegarde peut être restaurée sans Internet.
15. Une correction de pointage autorisée laisse une trace consultable.

## 21. Livrables attendus

Les livrables sont à préciser selon le cadre du projet, mais peuvent comprendre :
- application Flutter installable ;
- code source et instructions de lancement ;
- exemple de fichier Excel conforme au format attendu ;
- exemple de session avec étudiants et distributions fictifs ;
- méthode documentée de génération ou d’association des QR codes ;
- documentation utilisateur courte pour le responsable et les pointeurs ;
- documentation du processus de synchronisation et de récupération ;
- rapport de tests couvrant le fonctionnement hors ligne, les doublons, le relais entre appareils et les exports.

## 22. Résultat attendu

À la fin du projet, l’équipe organisatrice doit disposer d’un outil pratique pour préparer les distributions, pointer rapidement chaque étudiant, connaître à tout moment les personnes déjà servies et celles qui restent à servir, puis transmettre le suivi à un autre pointeur sans perdre de données — même en l’absence totale de connexion Internet.

**Principe directeur :** la connexion Internet est facultative ; la fiabilité du pointage, la conservation locale des données et la synchronisation contrôlée entre appareils sont des exigences centrales du projet.
