# NoxUI 0.2.5.5

Cette version rassemble les changements préparés depuis la version 0.2.5.0.

## Rappel de pause

Une option propose un rappel à intervalle réglable. Le compteur se suspend pendant une absence et l'alerte attend la fin du combat.

## Objets et journal de quêtes

Une option permet d'ouvrir la quête associée à un objet du sac par Ctrl clic, lorsqu'elle est présente dans le journal et hors combat.

## Ramassage rapide

Le ramassage rapide respecte le choix de ramassage automatique du client. Les actions en attente sont annulées à la fermeture de la fenêtre de butin ou à la désactivation du réglage.

## Parcours des quêtes suivies

Deux raccourcis configurables permettent de sélectionner la quête suivie suivante ou précédente hors combat. Aucune touche n'est attribuée automatiquement.

## Matériaux et objets combinables

Le compteur peut suivre jusqu'à six matériaux. Les objets combinables peuvent afficher leurs matériaux nécessaires lorsque le client fournit la recette et que l'option est activée.

## Objets de quête

L'infobulle des objets de quête peut indiquer si la quête est en cours ou prête à rendre lorsque le jeu fournit cette information.

## Rotation de la minicarte

Le raccourci du jeu synchronise la rotation avec le profil actif de NoxUI, afin de conserver le choix lors des prochains rafraîchissements.

## Exploration de la carte

Les zones explorées sont actualisées après la connexion et les changements de sous zone. Le calcul des contours est limité pour améliorer la stabilité, notamment à la fermeture de la carte. La restauration de la carte après le combat a également été revue.

## Affichage des recharges

L'emplacement d'une amélioration expirée est actualisé plus rapidement.

## Recherche de groupe

La recherche de groupe permet de sélectionner des langues supplémentaires. Une option affiche la zone des joueurs inscrits seuls.

## Placement des ressources

Les barres liées aux ressources conservent une référence de placement stable quand une barre suit le curseur. Les liens entre barres suivant le curseur restent coordonnés.

## Cadres de groupe et de raid

Le suivi du mana des soigneurs permet de choisir l'affichage des noms en groupe et en raid, en raid uniquement ou de le masquer.

## Rangs des sorts personnalisés

Les icônes de sorts personnalisés utilisent le rang connu pour leur affichage, leur recharge et leurs règles, tout en conservant leurs réglages.

## Rangs des améliorations

Les améliorations personnalisées reconnaissent les autres rangs recensés et actualisent leur suivi lorsque le livre de sorts change.

## Rappels de consommables

Des rappels par classe couvrent les parchemins et élixirs de caractéristiques et de santé. Chaque rappel permet de choisir un objet préféré, un délai avant expiration et la proposition d'un consommable plus puissant.

## Recettes et consommables

La couleur des recettes tient compte des prérequis et du statut connu sans confondre l'aperçu de l'objet fabriqué avec la recette. Les consommables sont également vérifiés.

## Syndicator

L'habillage des réglages Syndicator est recherché à nouveau lorsque leur fenêtre apparaît ou après le combat, si elle a été créée tardivement.

## Spécialisations

La copie et le retrait d'une amélioration hébergée entre spécialisations distinguent une recharge du même sort et conservent ses réglages.

## Temps de recharge

Une amélioration hébergée reste visible lorsqu'elle partage un sort avec une recharge remplacée. Les rangs équivalents sont reconnus.

## Incantations et interruptions

Le suivi d'interruption recherche le rang disponible du joueur et les rangs connus du familier présents dans le catalogue. Le bouclier des incantations non interruptibles peut apparaître sur les barres de cible et de focalisation.

## Noms flottants

Lorsqu'une plaque est réutilisée pour une autre unité, l'ancien nom et ses marqueurs sont détachés avant son nouvel affichage.

## Import des recharges

Les sorts d'une configuration importée restent en place pendant l'attente de leur suivi par le jeu. La protection s'efface lorsque le suivi est reconnu ou lors du retour à la disposition du jeu.

## Inventaire et banque

Les objets dont l'infobulle se complète sont réexaminés et leur couleur est actualisée dans les sacs et la banque. Apprendre une recette actualise l'inventaire et la banque.

## Profils et affichage

Les barres de recharge d’une nouvelle spécialisation conservent les choix du joueur au prochain chargement. Les alertes de discussion suivent le clignotement de l’onglet. Les couleurs sociales des noms sont réservées aux joueurs alliés. La police de combat personnalisée utilise la hauteur du client.

## Campement

Désactiver le compte à rebours du sac de couchage masque l’estimation et conserve le panneau de campement et l’état de repos pendant le sommeil. Le panneau reconnaît aussi la proximité du sac d’un autre joueur lorsque le client expose son aura de repos. Le compte à rebours reste lié au sommeil.

## Fiche de personnage

L’infobulle des caractéristiques précise comment masquer les bonus d’enchantement avec leur réglage dédié.

## Carte du monde

La carte continue dispose de sa propre vue en combat. Les lieux à explorer peuvent être affichés, la taille et la priorité de la flèche se règlent et les objectifs Questie passent devant les services de ville. Le clic droit peut être réservé aux autres addons.

## État des vérifications

Les fichiers Lua, les manifestes et les simulations disponibles ont été vérifiés. Les scénarios dans WoW Forever restent à contrôler en jeu.

Le portage complet des fonctions compatibles de Plumber reste en cours. Le module de conseil de butin reste suspendu et est exclu du paquet.
