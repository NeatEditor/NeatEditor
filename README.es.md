# NeatEditor

[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-1f6feb)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://www.swift.org/)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-0a7ea4)](https://developer.apple.com/xcode/swiftui/)
[![Project](https://img.shields.io/badge/Project-XcodeGen-6f42c1)](https://github.com/yonaskolb/XcodeGen)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)

> Un editor de texto plano minimalista y de arranque rápido para macOS, creado con SwiftUI y AppKit para escribir sin distracciones, mantener interacciones nativas de escritorio y editar con varias pestañas de forma eficiente.

**Idiomas:** [English](./README.md) | [简体中文](./README.zh-CN.md) | [日本語](./README.ja.md) | [한국어](./README.ko.md) | [Español](./README.es.md) | [Français](./README.fr.md) | [Deutsch](./README.de.md)

## Captura de pantalla

<p align="center">
  <img src="./docs/images/neateditor-main-window.png" alt="Captura de la ventana principal de NeatEditor" width="1201" />
</p>

## Por qué NeatEditor

NeatEditor se construyó con un objetivo simple: reducir el ruido de la interfaz y devolver la atención al texto.

- Arranque rápido: evita trabajo bloqueante innecesario en la ruta de inicio.
- UI centrada en el espacio: prioriza la superficie del editor sobre el chrome de la aplicación.
- Comportamiento nativo de macOS: conserva barra de título, menús, atajos y acciones de ventana familiares.
- Enfoque en texto plano: ideal para notas, borradores, escritura rápida y edición ligera.

## Características destacadas

- Edición de texto plano con varias pestañas y un documento listo al iniciar.
- Selección de pestañas, cierre y cambio de nombre en línea con baja latencia.
- Apertura de archivos locales desde Finder, arrastrar y soltar o pegando URLs de archivo.
- Números de línea, búsqueda nativa, deshacer, manejo de IME y zoom con `Command +/-`.
- Guardado automático con debounce de 2 segundos, más guardado al cambiar de pestaña o al desactivar la app.
- Soporte para ventana fijada arriba y zoom nativo al hacer doble clic en la barra de título.
- Renombrado en disco que conserva extensiones editables.
- El contenido en blanco no sobrescribe archivos existentes por diseño.

## Estado actual

NeatEditor ya está listo para usarse como un editor ligero de texto plano para macOS y se publica como `1.0.0`.

- Plataforma objetivo: macOS 15.0+
- Stack: Swift 6, SwiftUI, AppKit bridge, Observation, XcodeGen
- Validación actual: verificación de compilación y pruebas manuales
- Alcance actual: flujo de texto plano, sin texto enriquecido, plugins ni soporte multiplataforma

## Inicio rápido

### Requisitos

- macOS 15.0+
- Xcode 16.2+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44+

### Clonar y abrir

```bash
git clone <repo-url>
cd NeatEditor
xcodegen generate
open NeatEditor.xcodeproj
```

### Compilar desde la terminal

```bash
xcodebuild -project "NeatEditor.xcodeproj" \
  -scheme "NeatEditor" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  build
```

## Notas de desarrollo

- `project.yml` es la fuente de verdad de la estructura del proyecto.
- Ejecuta `xcodegen generate` después de añadir o eliminar archivos fuente.
- El repositorio todavía no incluye un target de pruebas, así que `xcodebuild ... test` no está configurado.
- Para cambios de comportamiento, conviene validar con la app compilada en lugar de depender solo de las previews.

## Releases

Este repositorio incluye un flujo de GitHub Releases basado en tags.

- Empuja un tag como `v1.0.0` y GitHub Actions construirá la release automáticamente.
- El flujo genera un zip universal para macOS.
- La release también incluye `SHA256SUMS.txt`.

El flujo más simple de publicación es:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Consulta [RELEASING.md](./RELEASING.md) para más detalles.

## Documentación del repositorio

- [README.md](./README.md): resumen en inglés
- [README.zh-CN.md](./README.zh-CN.md): resumen en chino simplificado
- [README.ja.md](./README.ja.md): resumen en japonés
- [README.ko.md](./README.ko.md): resumen en coreano
- [README.fr.md](./README.fr.md): resumen en francés
- [README.de.md](./README.de.md): resumen en alemán
- [CONTRIBUTING.md](./CONTRIBUTING.md): entorno de desarrollo y contribuciones
- [CHANGELOG.md](./CHANGELOG.md): historial de versiones
- [RELEASING.md](./RELEASING.md): flujo de GitHub Release
- [TabStripGestures.md](./TabStripGestures.md): notas de diseño sobre gestos de pestañas

## Próximos huecos

- Añadir un target de pruebas para guardado, renombrado y restauración de estado.
- Añadir firma de Apple, notarización y empaquetado DMG para mejorar la distribución.
- Añadir un flujo general de CI para pushes y pull requests.

## Contribuir

Las issues, sugerencias y pull requests son bienvenidas. Lee primero [CONTRIBUTING.md](./CONTRIBUTING.md).

## Licencia

NeatEditor se distribuye bajo la [MIT License](./LICENSE).
