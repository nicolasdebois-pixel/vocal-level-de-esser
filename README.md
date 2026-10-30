# Vocal level & de-esser pour REAPER

Rend une voix — parlée ou chantée — plus propre en un clic, sans connaissances en mixage.
L'outil écoute tout l'item, puis corrige :

- **Niveau régulier** : remonte les passages trop faibles, baisse les trop forts (les silences ne sont jamais remontés) ;
- **Sifflantes** : adoucit les « s », « ch », « z » qui sifflent ;
- **Plosives et graves** : atténue les « p » et « b » qui soufflent dans le micro (bouffées de sub), les graves qui gonflent quand on s'en approche, et coupe l'infra-grave inutile ;
- **Équilibre de la voix** : corrige une voix trop sourde, trop nasale ou trop brillante, avec une égalisation calculée pour *cette* voix.

Tout est écrit sous forme de courbes d'automation et d'une égalisation sur un petit plugin placé sur la **prise**
(avant les effets de la piste). Rien n'est figé : on peut réécouter, changer un réglage, ou tout retirer.

## Installation (ReaPack)
1. ReaPack installé (https://reapack.com).
2. *Extensions › ReaPack › Import repositories…*, collez :
   ```
   https://github.com/nicolasdebois-pixel/vocal-level-de-esser/raw/main/index.xml
   ```
3. *Extensions › ReaPack › Browse packages…*, cherchez **Vocal level**, *Install*, puis *Apply*.

## Utilisation
1. Sélectionnez un ou plusieurs items de voix.
2. Lancez l'action **Vocal level & de-esser**.
3. Choisissez **Parole** ou **Chant**, puis cliquez sur **Analyser et appliquer**.
4. Écoutez. Si un traitement en fait trop ou pas assez, passez-le en **Léger** ou **Fort** : le résultat se met à jour aussitôt.
   Décochez un traitement pour le couper.
5. **Retirer** enlève tout des items sélectionnés.

**Réglages avancés** donne accès à tous les curseurs (fréquences, quantités, couleur de l'égalisation…)
et montre la courbe d'égalisation calculée.

Avec PodSuite : appliquez-le **après** le dérushage, sur des items qui ne bougeront plus.

Licence : MIT.
