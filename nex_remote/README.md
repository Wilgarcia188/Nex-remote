# Nex Remote

Remapeador de botones para Android TV. Asigna apps a los botones del control
remoto (keycodes 195, 247, 249 y 265) y lánzalas con una sola pulsación.
Incluye una pantalla de depuración que muestra cualquier keycode en tiempo
real.

## Arquitectura

```
Flutter UI
├── HomeScreen        → botones configurados (195/247/249/265 → app)
├── AppPickerScreen   → selector de apps instaladas (icono + nombre)
├── SettingsScreen    → exportar / importar / resetear mapeos
└── DebugScreen       → último keycode, historial y mapeos actuales
        ↑ EventChannel  "nex_remote/key_events"   (keycodes en vivo)
        ↑ MethodChannel "nex_remote/methods"      (apps, mapeos, export/import)
Kotlin
├── MainActivity      → registra ambos canales, descubre apps (PackageManager)
├── MappingStore      → SharedPreferences: keycode → package (sobrevive reboot)
├── KeyEventDispatcher→ puente de keycodes al hilo principal
└── KeyEventService   → AccessibilityService: recibe teclas de hardware,
                        lanza la app mapeada y consume el evento; las teclas
                        sin mapeo pasan al sistema sin tocarse
```

- Si un botón tiene mapeo: el servicio lanza la app (intent Leanback si
  existe, launcher normal si no) y **consume** el evento (DOWN y UP).
- Si no tiene mapeo: comportamiento normal de Android.
- Todos los keycodes se registran en Logcat (tag `NexRemote`) y se envían a
  la DebugScreen.

## Estructura del proyecto

```
nex_remote/
├── lib/
│   ├── main.dart                 # Punto de entrada → HomeScreen
│   ├── home_screen.dart          # Botones configurados + navegación
│   ├── app_picker_screen.dart    # "Select Action for Button N"
│   ├── settings_screen.dart      # Export / Import / Reset
│   ├── debug_screen.dart         # Keycodes en vivo + mapeos actuales
│   └── mapping_channel.dart      # Wrapper Dart del MethodChannel
├── android/app/src/main/
│   ├── AndroidManifest.xml       # Leanback, queries, servicio accesibilidad
│   ├── kotlin/com/nexremote/nex_remote/
│   │   ├── MainActivity.kt       # EventChannel + MethodChannel
│   │   ├── MappingStore.kt       # Persistencia SharedPreferences
│   │   ├── KeyEventDispatcher.kt # Puente servicio → Flutter
│   │   └── KeyEventService.kt    # Interceptor + lanzador de apps
│   └── res/
│       ├── xml/accessibility_service_config.xml
│       ├── values/strings.xml
│       └── drawable-xhdpi/tv_banner.png
└── pubspec.yaml                  # Sin dependencias adicionales
```

## Compilar

```bash
cd nex_remote
flutter pub get
flutter analyze
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

## Instalar y probar en Android TV

1. `adb connect <IP-del-TV>:5555 && adb install app-debug.apk`
2. **Activa el servicio**: la HomeScreen muestra un aviso naranja si el
   servicio de accesibilidad está apagado; selecciónalo con OK para abrir
   Ajustes → Accesibilidad → **Nex Remote** → Activar.
3. En la HomeScreen, selecciona un botón (ej. `247 → Not Configured`) con
   el D-pad y pulsa OK.
4. En el selector, elige una app (ej. YouTube) con el control. Sin teclear
   nada: solo UP/DOWN/OK/BACK.
5. Pulsa el botón físico 247 del control: se lanza YouTube al instante.
6. DebugScreen: muestra Last Keycode, History y Current Mappings en vivo.
   También por Logcat: `adb logcat -s NexRemote`.

### Exportar / importar mapeos

Settings → **Export mappings** guarda el JSON en:

```
/sdcard/Android/data/com.nexremote.nex_remote/files/nex_remote_mappings.json
```

Formato:

```json
{
  "247": "com.google.android.youtube.tv",
  "249": "com.netflix.ninja",
  "195": "org.xbmc.kodi",
  "265": "com.teamsmart.videomanager.tv"
}
```

Cópialo entre dispositivos con `adb pull` / `adb push` y usa
**Import mappings** en el TV de destino. **Reset all mappings** borra todo
(con confirmación). Los mapeos persisten tras reiniciar la app y el TV.

### Notas

- Los mapeos se guardan en SharedPreferences: sobreviven a reinicios.
- Algunos botones patrocinados de ciertos controles los intercepta el
  firmware antes de llegar a Android; esos no generan evento y no se pueden
  remapear. Los keycodes 195, 247, 249 y 265 están confirmados.
