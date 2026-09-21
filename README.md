# Pomodoro Dynamic Island para macOS

Aplicación nativa de alta fidelidad para macOS desarrollada en **Swift**, **SwiftUI** y **AppKit**, estructurada en torno a una **Dynamic Island** ergonómica anclada al hardware notch de Apple Silicon (con soporte de pantallas externas) e integrada con los **Modos de Concentración** de macOS y la metodología Pomodoro canónica de **Francesco Cirillo**.

## Características Principales

1. **Dynamic Island Nativa sin Desgarros (Anti-Tearing)**:
   - Ventana `NSPanel` con `level = .mainMenu + 1` y estilo `.borderless`, `.nonactivatingPanel`.
   - Dimensionamiento estático del lienzo overlay (660×280 pt) con deformación elástica interna mediante animaciones de resorte (`spring`).
   - Detección precisa de las dimensiones del notch (`safeAreaInsets.top`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`) y modo de compatibilidad (cápsula flotante superior centrada de 210×32 pt) para monitores externos, iMac y Mac mini.
   - Hit testing passthrough para zonas transparentes: los clics fuera de la cápsula visible interactúan directamente con las ventanas situadas debajo sin robar foco de teclado.

2. **Mitigación de Fricción Cognitiva y Reglas de Cirillo**:
   - **Hover Debounce (120 ms)**: Retardo intencional de activación por proximidad para evitar expansiones accidentales al navegar hacia la barra de menús.
   - **Captura Rápida de Interrupciones Internas (⌘ + I)**: Entrada minimalista para redactar pensamientos o distracciones sin detener el avance del tiempo (regla del apóstrofe `'`).
   - **Estados Visuales**:
     - *Inactivo*: Gris neutro (`secondaryLabel`) con selector de preajustes (25, 45, 50 min).
     - *Enfoque*: Naranja cálido (`systemOrange`) con tipografía `.monospacedDigit()` y anillo de progreso radial.
     - *Descanso Corto*: Verde menta (`systemMint`) con consejos ergonómicos (regla 20-20-20, hidratación).
     - *Descanso Largo*: Azul hielo (`systemCyan`) tras completar 4 bloques de trabajo.
     - *Tiempo Excedido (Flow)*: Amarillo ámbar (`systemYellow`) con contador `+MM:SS`.

3. **Cálculo Diferencial Determinista**:
   - Motor `PomodoroStateCalculator` basado en `\(\Delta t = \max(0, targetTimestamp - now)\)`. Inmune a retrasos de hilos, App Nap y suspensión del equipo al cerrar la tapa del MacBook.

4. **Automatización de Modos de Concentración**:
   - Invocación asíncrona de `/usr/bin/shortcuts run` mediante `SystemFocusController` (proceso aislado en Foundation).
   - Implementación de `PomodoroFocusFilter` (`SetFocusFilterIntent`) con el framework de `AppIntents`.

---

## Estructura del Código

```
Pomodoro/
├── project.yml                          # Definición declarativa para XcodeGen
├── Pomodoro.xcodeproj/                  # Proyecto generado para Xcode
├── Sources/
│   ├── Info.plist                       # Configuración de LSUIElement (accesorio)
│   ├── Domain/
│   │   ├── PomodoroPhase.swift          # Fases temporales y metadatos visuales
│   │   ├── PomodoroPreset.swift         # Preajustes (25, 45, 50 min)
│   │   ├── PomodoroStateCalculator.swift# Cálculo diferencial determinista
│   │   ├── Interruption.swift           # Modelado de interrupciones (Cirillo)
│   │   └── PomodoroCoreEngine.swift     # Actor central del ciclo Pomodoro
│   ├── Infrastructure/
│   │   ├── DisplayNotchMetrics.swift    # Detección geométrica del notch/fallback
│   │   ├── DynamicNotchPanel.swift      # Subclase NSPanel no activable
│   │   ├── NotchWindowController.swift  # Controlador de ventana y passthrough
│   │   ├── SystemFocusController.swift  # Despacho de /usr/bin/shortcuts run
│   │   └── PomodoroFocusFilter.swift    # Focus Filter nativo con AppIntents
│   ├── Coordination/
│   │   └── SessionCoordinator.swift     # Coordinador @Observable en @MainActor
│   ├── Presentation/
│   │   ├── DynamicIslandSurface.swift   # Lienzo principal y morphing elástico
│   │   ├── CollapsedNotchWingView.swift # Alas colapsadas (tiempo monospaciado)
│   │   ├── ExpandedIslandView.swift     # Panel contextual expandido
│   │   └── QuickInterruptionCaptureView.swift # Captura rápida de distracciones
│   └── App/
│       └── PomodoroApp.swift            # Punto de entrada y menú de barra de menús
└── Tests/
    └── PomodoroCoreEngineTests.swift    # Suite de pruebas unitarias
```

---

## Comandos de Generación, Prueba y Compilación

```bash
# 1. Regenerar el proyecto de Xcode
xcodegen generate

# 2. Ejecutar la suite de pruebas unitarias
xcodebuild test -project Pomodoro.xcodeproj -scheme PomodoroTests -destination 'platform=macOS'

# 3. Compilar la aplicación
xcodebuild build -project Pomodoro.xcodeproj -scheme Pomodoro -destination 'platform=macOS'
```
