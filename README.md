# Vocal level & de-esser pour REAPER

Rend une voix — parlée ou chantée — plus propre en un clic, sans connaissances en mixage.
L'outil écoute tout l'item, puis corrige :

- **Niveau régulier** : remonte les passages trop faibles, baisse les trop forts (les silences ne sont jamais remontés) ;
- **Sifflantes** : adoucit les « s », « ch », « z » qui sifflent ;
- **Plosives** : atténue les « p » et « b » qui soufflent dans le micro (bouffées de sub) et coupe l'infra-grave inutile ;
- **Voix trop proche** : baisse les graves qui gonflent quand on s'approche du micro ;
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

### Retoucher un endroit précis
Un « B » de « Bonjour » qui souffle encore, un « s » qui siffle toujours, un mot trop faible ?
1. Gardez l'item sélectionné et faites une **sélection temporelle** sur ce son (glisser dans la règle, ou sur l'item).
2. Dans **Retouche locale**, cliquez sur le réglage voulu : **Plosive** (−6 à −24 dB de sub), **Sifflante** (−3 à −12 dB d'aigus)
   ou **Niveau** (−3 à +3 dB).
3. Seule cette courbe change, et seulement dans la zone : tout le reste du traitement est intact.

Recliquez sur le même réglage pour l'enlever ; **Effacer la zone** supprime les retouches de la zone. Ctrl+Z (Cmd+Z) annule.
Les retouches sont mémorisées sur la prise : si vous changez ensuite un réglage général, elles sont réappliquées
par-dessus, et elles suivent le son si vous déplacez ou rognez l'item.

**Réglages avancés** donne accès à tous les curseurs (fréquences, quantités, couleur de l'égalisation…)
et montre la courbe d'égalisation calculée.

Avec PodSuite : appliquez-le **après** le dérushage, sur des items qui ne bougeront plus.

Licence : MIT.
