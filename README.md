# Blague croissant

![version](https://img.shields.io/badge/version-1.0-blue) ![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE)

Trois blagues inoffensives pour le collègue qui n'a pas verrouillé son PC avant la pause. Chacune est un script PowerShell autonome (WPF, sans installation) qui s'affiche sur tous les écrans et rappelle, avec humour, qu'il faut faire **Windows + L**.

| Blague | Script | Ce qui se passe |
|---|---|---|
| NIAH! NIAH! NIAH! | `nia.ps1` | Un gros texte 3D rebondit d'un écran à l'autre. Ses lettres ondulent en profondeur et changent de matière en boucle : bois clair, bois foncé, or, alu, cuivre, feuilles, eau. |
| Vélos | `velo.ps1` | Trois vélos de route aux couleurs réalistes se baladent, roues et pédalier qui tournent. Un clic sur un vélo en fait arriver un autre (25 au maximum). |
| Croissants | `croissant.ps1` | Des croissants (photo détourée intégrée au script) sortent du centre de l'écran en grossissant jusqu'à 10 cm réels et s'empilent jusqu'à remplir l'écran. Une croix en haut à droite permet de quitter. |

Chaque blague affiche aussi un bandeau en haut de chaque écran avec un rappel comique de verrouiller sa session.

## Utilisation

Double-cliquer sur le `lancer-*.cmd` de la blague voulue. Il lance le script sans fenêtre de console. Les fichiers `.cmd` doivent rester dans le même dossier que les `.ps1`.

Pour arrêter :

- double-cliquer sur le `stop-*.cmd` correspondant ;
- ou ouvrir le Gestionnaire des tâches (Ctrl+Maj+Échap) et terminer `powershell.exe` ;
- chaque script s'arrête de lui-même après 15 minutes (`-Minutes`).

Les fenêtres de `nia.ps1` laissent passer la souris. Les vélos et les croissants captent les clics, mais les croissants passent en arrière-plan dès que le Gestionnaire des tâches est ouvert.

## Paramètres

Les scripts peuvent être lancés à la main pour régler l'effet, par exemple :

```powershell
powershell -ExecutionPolicy Bypass -File .\nia.ps1 -Speed 3 -Size 190 -Wave 40 -MatSeconds 5 -Font "Jokerman"
powershell -ExecutionPolicy Bypass -File .\velo.ps1 -Bikes 5 -Speed 4 -Size 2.2 -MaxBikes 25
powershell -ExecutionPolicy Bypass -File .\croissant.ps1 -Cm 10 -Duration 1.6 -Gap 0.35
```

Tous acceptent `-Minutes`. `nia.ps1` et `velo.ps1` acceptent `-Messages` (liste de phrases), `croissant.ps1` accepte `-Message`. Le texte placé entre `*étoiles*` est mis en valeur en jaune.

## Notes techniques

- PowerShell 5.1 de Windows, avec du code C# compilé à la volée (`Add-Type`) pour WPF. Le premier lancement prend 2 à 4 secondes.
- Les scripts sont enregistrés en **UTF-8 avec BOM** pour que PowerShell 5.1 affiche correctement les accents. Garder cet encodage si on les modifie.
- La taille réelle des croissants est calculée à partir de la taille physique annoncée par chaque écran (EDID). À défaut, une densité de 96 dpi est supposée.

## À faire avant de rendre le dépôt public

Ce dépôt est prévu **privé**. Avant de le passer en public, il faut vérifier les droits sur la photo de croissant intégrée en base64 dans `croissant.ps1`, ou la remplacer.

## Licence

MIT, voir `LICENSE`.
# Blagues-screen
