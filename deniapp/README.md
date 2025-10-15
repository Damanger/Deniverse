# DeniVerse — Vista principal (SwiftUI)

Este directorio contiene un esqueleto de la vista principal para una app iOS en SwiftUI llamada "DeniVerse". Incluye:

- `DeniApp.swift`: punto de entrada `@main` que muestra `ContentView`.
- `ContentView.swift`: vista principal con alternancia (toggle) entre la vista base e "Finanzas" (gastos e ingresos). Incluye cabecera, búsqueda, acciones rápidas y secciones de recientes/transacciones.

## Cómo usarlo en Xcode

1. Abre Xcode y crea un nuevo proyecto (iOS App).
   - Interface: SwiftUI
   - Life Cycle: SwiftUI App
   - Language: Swift
2. Asigna el nombre del proyecto (por ejemplo, "Deni").
3. En el navegador del proyecto, reemplaza los archivos generados por Xcode:
   - Sustituye `AppNameApp.swift` por el contenido de `DeniApp.swift` (o simplemente arrastra `DeniApp.swift` al proyecto y elimina el antiguo).
   - Sustituye `ContentView.swift` por el de este directorio.
4. Selecciona un simulador y ejecuta (`⌘R`).

## Personalización rápida

- Títulos y textos: edita los textos de `header`, `quickActions`, `recentSection` y la sección de finanzas en `ContentView.swift`.
- Acciones: conecta los `ActionButton` a la lógica deseada en los closures.
- Estilos: ajusta colores, tipografías y separadores con los modificadores de SwiftUI.

## Logo de la app

Se habilitó soporte para colocar un logo propio dentro de la cabecera de la app.

- Dónde ponerlo: agrega las imágenes en `Assets.xcassets/AppLogo.imageset`.
- Nombres esperados: `AppLogo.png`, `AppLogo@2x.png`, `AppLogo@3x.png` (tamaños 1x/2x/3x).
- Cómo se usa: `ContentView` mostrará automáticamente el `AppLogo` si existe; si no, se muestra el ícono genérico actual.
- Vista responsable: `ContentView.swift` (componente `AppLogoView`).

Sugerencias de tamaño para el logo:
- Proporción cuadrada (1:1) para verse bien a 56×56 pt con esquinas redondeadas.
- Usa PNG con fondo transparente si corresponde.

Icono de la app (App Icon):
- El catálogo `Assets.xcassets/AppIcon.appiconset` ya existe. Puedes arrastrar allí los tamaños generados por Xcode o por una herramienta de exportación de íconos.
- Esto controla el ícono en SpringBoard/App Store, mientras que `AppLogo` es el logo mostrado dentro de la UI.

## Modo Finanzas

- Usa el toggle "Modo Finanzas" para alternar entre la pantalla base y la pantalla de gastos/ingresos.
- La sección de finanzas muestra un resumen (ingresos, gastos y balance), acciones rápidas y una lista de transacciones de ejemplo.

Si quieres, puedo generar el proyecto completo de Xcode y estructurarlo (targets, assets, etc.) para que simplemente abras y ejecutes.
