# Vocal level & de-esser pour REAPER

Nivelle une voix — parlée ou chantée — et atténue ses sifflantes, sans compresseur.
Le script écoute tout l'item à l'avance, puis écrit deux courbes d'automation sur un petit plugin
placé sur la **prise** (avant les effets de la piste) :

- **Rider** : remonte les passages trop faibles et baisse les passages trop forts, en douceur.
  Les silences ne sont jamais remontés (le bruit de fond reste où il est).
- **De-esser** : creuse chaque sifflante, de préférence dans les aigus seulement.

Comme tout est calculé à l'avance, les corrections arrivent pile au bon moment : pas de pompage,
pas de latence, et les courbes restent modifiables à la main. Elles suivent l'item si on le déplace ou le coupe.

## Installation (ReaPack)
1. ReaPack installé (https://reapack.com).
2. *Extensions › ReaPack › Import repositories…* puis collez :
   ```
   https://github.com/nicolasdebois-pixel/vocal-level-de-esser/raw/main/index.xml
   ```
3. *Extensions › ReaPack › Browse packages…*, cherchez **Vocal level**, *Install*, puis *Apply*.

## Utilisation
1. Sélectionnez un ou plusieurs items de voix.
2. Lancez l'action **Vocal level & de-esser**. L'analyse démarre, puis les courbes s'écrivent.
3. Écoutez, ajustez les curseurs : les courbes se réécrivent à chaque réglage, instantanément.
4. **Retirer** enlève le plugin et ses courbes des items sélectionnés.

### Les réglages
- **Parole / Chant** : préréglages. Le chant est corrigé plus doucement, pour garder les nuances.
- **Cible** : *automatique* nivelle autour du niveau habituel de la voix ; *fixe* vise un niveau précis.
- **Quantité** : 100 % ramène tout au même niveau ; 50 % réduit les écarts de moitié.
- **Correction maximale** : limite les corrections, vers le haut comme vers le bas.
- **Douceur** : vitesse à laquelle le niveau suit la voix (rapide = au mot près, lent = à la phrase).
- **Atténuation maximale** du de-esser, **Sensibilité** (plus haut = plus de sifflantes traitées),
  **Fréquence** (où commencent les sifflantes de cette voix : souvent 5 à 7 kHz, plus haut pour une voix aiguë).
- **Aigus seulement** (recommandé) ou **Tout le signal** pour le de-esser.

Avec PodSuite : appliquez-le **après** le dérushage, sur des items qui ne bougeront plus.

Licence : MIT.
