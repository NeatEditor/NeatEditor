# NeatEditor

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-1f6feb)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0a7ea4)](https://developer.apple.com/xcode/swiftui/)
[![Project](https://img.shields.io/badge/Project-XcodeGen-6f42c1)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

> Un éditeur de texte brut minimaliste et très rapide au lancement pour macOS, conçu avec SwiftUI et AppKit pour une écriture sans distraction, des interactions bureautiques natives et une édition efficace à onglets multiples.

**Langues :** [English](./README.md) | [简体中文](./README.zh-CN.md) | [日本語](./README.ja.md) | [한국어](./README.ko.md) | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md)

## Capture d'écran

<p align="center">
  <img src="./docs/images/neateditor-main-window.png" alt="Capture de l’espace de travail principal de NeatEditor" width="1201" />
</p>

## Pourquoi NeatEditor

NeatEditor repose sur un objectif simple : réduire le bruit de l’interface et ramener l’attention sur le texte.

- Lancement rapide : évite les opérations bloquantes inutiles sur le chemin de démarrage.
- Interface centrée sur l’espace d’écriture : la zone d’édition reste au premier plan.
- Comportement natif macOS : conserve la barre de titre, les menus, les raccourcis et les interactions de fenêtre attendus.
- Priorité au texte brut : pratique pour les notes, brouillons, écrits temporaires et petites modifications.

## Points forts

- Édition de texte brut en multi-onglets avec un document prêt à l’emploi dès le lancement.
- Sélection d’onglets, fermeture et renommage intégré à faible latence.
- Ouverture de fichiers texte locaux via Finder, glisser-déposer ou collage d’URL de fichier.
- Numéros de ligne, recherche native, annulation, gestion IME et zoom avec `Command +/-`.
- Sauvegarde automatique avec debounce de 2 secondes, plus sauvegarde au changement d’onglet et à la désactivation de l’app.
- Fenêtre épinglée au premier plan et zoom natif via double-clic dans la barre de titre.
- Renommage sur disque qui conserve les extensions modifiables.
- Le contenu vide n’écrase jamais un fichier existant par conception.

## Raccourcis principaux

| Raccourci | Action |
| --- | --- |
| `Command + N` | Crée un nouveau document. |
| `Command + T` | Ouvre un nouvel onglet supplémentaire. |
| `Command + O` | Ouvre un ou plusieurs fichiers texte locaux. |
| `Command + S` | Sauvegarde immédiatement l’onglet actuel. |
| `Command + W` | Sauvegarde puis ferme l’onglet actuel. |
| `Shift + Command + T` | Rouvre l’onglet fermé le plus récemment. |
| `Command + F` | Affiche la barre de recherche intégrée de l’éditeur courant. |
| `Command + =` ou `Command + +` | Agrandit le texte dans l’éditeur. |
| `Command + -` | Réduit le texte dans l’éditeur. |
| `Command + ,` | Ouvre les réglages. |
| `Shift + Return` | Insère une nouvelle ligne à la fin de la ligne actuelle. |

Les raccourcis de texte natifs de macOS, comme `Command + Z`, `Command + X`, `Command + C` et `Command + V`, restent aussi disponibles via le système de texte natif.

## État actuel

NeatEditor est déjà prêt comme éditeur léger de texte brut pour macOS et est publié en `1.0.0`.

- Plateforme cible : macOS 15.0+
- Stack : Swift 6, SwiftUI, AppKit bridge, Observation, XcodeGen
- Validation actuelle : vérification de build et tests manuels
- Portée actuelle : flux de texte brut, sans texte enrichi, plugins ni prise en charge multiplateforme

## Démarrage rapide

### Prérequis

- macOS 15.0+
- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

### Cloner et ouvrir

```bash
git clone <repo-url>
cd NeatEditor
xcodegen generate
open NeatEditor.xcodeproj
```

### Compiler depuis le terminal

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

## Notes de développement

- `project.yml` est la source de vérité de la structure du projet.
- Exécutez `xcodegen generate` après avoir ajouté ou supprimé des fichiers source.
- Le dépôt n’inclut pas encore de target de tests, donc `xcodebuild ... test` n’est pas configuré.
- Pour les changements de comportement, validez de préférence avec l’application compilée plutôt qu’avec les previews seules.

## Releases

Ce dépôt inclut un workflow GitHub Releases piloté par tags.

- Poussez un tag comme `v1.0.0` et GitHub Actions construira automatiquement la release.
- Le workflow produit une archive zip universelle pour macOS.
- La release inclut aussi `SHA256SUMS.txt`.

Le flux de release le plus simple est :

```bash
git tag v1.0.0
git push origin v1.0.0
```

Voir [RELEASING.md](./RELEASING.md) pour les détails.

## Documentation du dépôt

- [README.md](./README.md) : présentation en anglais
- [README.zh-CN.md](./README.zh-CN.md) : présentation en chinois simplifié
- [README.ja.md](./README.ja.md) : présentation en japonais
- [README.ko.md](./README.ko.md) : présentation en coréen
- [README.es.md](./README.es.md) : présentation en espagnol
- [README.de.md](./README.de.md) : présentation en allemand
- [CONTRIBUTING.md](./CONTRIBUTING.md) : environnement de développement et contribution
- [CHANGELOG.md](./CHANGELOG.md) : historique des versions
- [RELEASING.md](./RELEASING.md) : workflow GitHub Release
- [TabStripGestures.md](./TabStripGestures.md) : notes de conception des gestes d’onglets

## Lacunes connues

- Ajouter un target de tests pour la sauvegarde, le renommage et la restauration d’état.
- Ajouter la signature Apple, la notarisation et le packaging DMG pour une meilleure distribution.
- Ajouter un workflow CI général pour les pushes et pull requests.

## Contribuer

Les issues, suggestions et pull requests sont bienvenues. Lisez d’abord [CONTRIBUTING.md](./CONTRIBUTING.md).

## Licence

NeatEditor est distribué sous [MIT License](./LICENSE).
