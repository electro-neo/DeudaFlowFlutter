
## 📝 Cambios Recientes y Soluciones

## Regla principal antes de hacer cambios
no hagas cambios aun primero dime si es posible, analiza el escenario y dame una respuesta corta y brvee de todo, a menos que indique lo contrario. SE BREVE DA RESPUESTAS CORTAS


### Últimos cambios y refactorizaciones
Ver archivo `CAMBIOS_ULTIMA_SESION.txt` para detalles de refactor, mejoras visuales, lógica de sincronización offline/online, gestión de monedas, fixes de Provider, y optimizaciones en recibos PDF y UI/UX. Incluye commits sugeridos y fechas de cada cambio relevante.

### Errores encontrados y soluciones aplicadas
Ver archivo `Errores corregidos.txt` para una lista detallada de bugs, problemas de sincronización, fixes de lógica de filtros, errores de Provider, problemas de UI (Dismissible, padding, animaciones), y soluciones aplicadas. Incluye mejoras en la experiencia offline-first, login con Google, y generación de PDFs personalizados.

### Estructura y lógica de la app
Ver archivo `indice_estructura_app.txt` para el índice actualizado de pantallas, widgets, botones, lógica de navegación, permisos Android, y el flujo offline-first. Incluye detalles de formularios, botones, relación con Hive/Supabase, y el estado visual de sincronización en tarjetas de cliente y transacción.

### Resumen de integración
- Los cambios recientes y errores corregidos están documentados en los archivos txt para consulta rápida.
- La estructura y lógica de la app se mantiene actualizada en el índice para facilitar onboarding, refactor y solución de problemas.
- Ante cualquier bug, error visual, problema de sincronización o duda sobre el flujo, revisar primero los txt antes de modificar código.
# Copilot Instructions for Deuda Flow Flutter

## Project Overview
- This is a Flutter app for debt management, supporting offline/online sync, user sessions, and multi-platform deployment (Android, iOS, Web, Desktop).
- Data is stored locally using Hive and synced to Supabase (PostgreSQL backend).
- The app enforces single-session-per-device logic using a local device ID (not hardware ID).

## Key Architecture
- `lib/main.dart`: App entry point, initializes Supabase, Hive, and providers.
- `lib/services/`: Core business logic and backend integration:
  - `session_authority_service.dart`: Manages session authority, device ID, and real-time sync with Supabase.
  - `supabase_service.dart`: Handles all Supabase data operations (CRUD, sync, user settings).
- `lib/models/`: Data models for clients and transactions, including Hive adapters. The initial balance description is captured in the client form and used only in the initial transaction, not in the client model.
- `lib/providers/`: State management using Provider for clients, transactions, sync, navigation, etc.
- `lib/screens/`: UI screens for login, dashboard, transactions, etc.
- `lib/widgets/`: Reusable UI components and theming.
- `lib/offline/offline_helper.dart`: Utilities for offline data persistence and sync.

## Developer Workflows
- **Build (Android .aab):**
  - `flutter build appbundle --release`
- **Run (Web):**
  - `flutter run -d chrome`
- **Local Storage:**
  - Uses Hive; boxes are opened in `main.dart` and `offline_helper.dart`.
- **Sync:**
  - Supabase is the source of truth; local changes are synced when online.
- **Session Management:**
  - Device ID is generated and stored locally (not hardware ID), synced to Supabase for session authority.

## Project Conventions
- Spanish is used for code comments and some identifiers.
- All business logic and data access are in `services/` and `offline/`.
- UI logic is separated into `screens/` and `widgets/`.
- Providers are used for state management; avoid direct setState in screens.
- The client creation form (`ClientForm`) now captures a custom description for the initial balance, which is passed to the client screen and used only for the initial transaction.
- Do not use hardware/system device IDs; only use the app-generated device ID.
- Use `BudgetoTheme` and `budgeto_colors.dart` for consistent theming.

## External Integrations
- **Supabase:** Auth, real-time sync, and data storage.
- **Hive:** Local/offline storage.
- **Provider:** State management.
- **Other:** Google Sign-In, PDF/printing, app links, permissions, etc.

## Examples
- See `session_authority_service.dart` for device/session logic.
- See `offline_helper.dart` for offline-first patterns.
- See `main.dart` for initialization and provider setup.
- See `client_form.dart` and `clients_screen.dart` for the flow of capturing and using the initial balance description in the transaction.

---
If you are unsure about a workflow or pattern, check the relevant file in `lib/services/`, `lib/providers/`, or `lib/offline/` for examples.

---
## 🔄 Sesión Persistente (Actualizado)
Objetivo: Mantener sesión iniciada (correo y Google) tras cerrar la app y permitir acceso offline controlado.

Implementación:
1. Restauración antes de `runApp()` en `main.dart` (método `_initializeApp`).
2. Guardado local de la sesión Supabase como JSON (no tokens crudos separados) en `SessionAuthorityService.saveSupabaseSessionLocally()`.
3. Recuperación por `SessionAuthorityService.restoreSessionIfNeeded(hasInternet)` usando `auth.recoverSession` solo si hay red (si no, se permite modo offline con datos locales).
4. Limpieza segura en logout: `clearLocalSupabaseSession()` + `signOut` Supabase.
5. Ruta inicial dinámica (`_initialRoute`):
  - `/dashboard` si sesión válida.
  - `/dashboard` offline si no hay red pero existen datos Hive (clients/transactions).
  - `/` (Welcome) en caso contrario.

Archivos clave:
- `lib/main.dart`
- `lib/services/session_authority_service.dart`
- `lib/screens/login_screen.dart`

Notas:
- No borrar cajas Hive en arranque (evita perder sesión / offline).
- Tiempo máximo de restauración: 3s con timeout para no bloquear UI.

## 📱 Autoridad de Dispositivo / Sesión Única
- Device ID generado internamente (no hardware ID) y sincronizado con Supabase para validar unicidad de sesión.
- Conflictos manejados mostrando diálogo (ver `session_authority_service.dart`).
- Al reautenticar se revalida el device ID antes de permitir continuar.

## 📦 Offline-First
- Hive almacena: clientes, transacciones, settings, sesión.
- Acceso offline permitido solo si existen datos locales (al menos una caja con registros) y NO hay conectividad en arranque.
- Sync diferido: cambios se juntan y se empujan cuando vuelve la conectividad (ver `SyncProvider`).

## 🚀 Secuencia de Arranque / Splash (Optimizado)
Fases:
1. Splash nativo Android (`launch_background.xml` / tema `LaunchTheme`).
2. (Android 12+) API de splash: color + icono (config en `values-v31/styles.xml`).
3. Frame inicial Flutter con overlay propio (fade) definido en `MaterialApp.builder` (Stack) para transicionar suavemente.

Cambios aplicados:
- Fondo morado corporativo (`#6C63FF`) reemplazó al blanco inicial.
- Icono nativo usa `@mipmap/ic_launcher` para aparición inmediata (vector previo podía retrasarse).
- Overlay Flutter ahora desaparece con un fade rápido (~380ms) tras el primer frame.
- Eliminadas sombras y fondos según preferencia visual solicitada.

Problemas comunes y soluciones:
- Parpadeo negro antes del color: forzar `android:forceDarkAllowed=false` y usar mismo color en `LaunchTheme` y `NormalTheme`.
- Icono tardío: evitar vectores grandes o assets pesados; usar mipmap adaptativo.

## 🎨 Iconos, Assets y Marca
- Icono base: `assets/app_icon.png` (también usado para launcher icons via `flutter_launcher_icons`).
- Splash overlay actual: usa `Icons.account_balance_wallet_rounded` (se sustituyó la imagen por ícono Material según solicitud). 
- Sombra en texto/logo opcional; actualmente desactivada.

## 🔐 Google Sign-In + Email
- Tras login (correo / Google) se invoca `saveSupabaseSessionLocally()` antes de navegar al dashboard para evitar condición de carrera.
- Evitar navegar antes de persistir la sesión.

## 🧪 Errores Típicos Detectados
| Problema | Causa | Fix |
|----------|-------|-----|
| `Unable to load asset assets/app_icon.png` | Asset no declarado | Agregar en `pubspec.yaml` sección `assets:` |
| Flash blanco inicial | Color por defecto + falta de tema unificado | Ajustar `launch_background.xml` + `NormalTheme` |
| Icono no aparece hasta segundos después | Uso de vector/bitmap diferido | Cambiar a `@mipmap/ic_launcher` en splash |
| Sesión pierde persistencia | Borrado de Hive o falta de restore antes de UI | Restaurar antes de `runApp` |

## 🧭 Convenciones Ampliadas
- Lógica de sesión y sync solo en `services/` o `providers/` (no en widgets directamente).
- Evitar `setState` repetitivo en pantallas: usar Providers.
- No introducir dependencias que requieran IDs de hardware reales (privacidad / políticas store).
- Comentarios en español, código limpio y conciso.
- Revisar antes de agregar paquetes: si ya existe util en `utils/` o `offline/` reutilizar.

## 🛠 Checklist para Nuevos Features
1. ¿Requiere datos persistentes? -> Crear modelo + adapter Hive si aplica.
2. ¿Afecta sesión / auth? -> Coordinar con `SessionAuthorityService`.
3. ¿Necesita sync remoto? -> Extender `SupabaseService` / `SyncProvider`.
4. ¿UI reactiva? -> Añadir Provider dedicado en `providers/`.
5. ¿Afecta arranque? -> Validar no rompe `_initializeApp` ni initialRoute.
6. ¿Añade assets? -> Declarar en `pubspec.yaml`.
7. ¿Necesita deep link? -> Configurar `AppLinks` y rutas.
8. ¿Captura descripción personalizada de saldo inicial? -> Usar el flujo de `ClientForm` y pasar la descripción a la transacción inicial en `ClientsScreen`.
9. Tests rápidos: compilar, login, restart en modo avión, logout.

## 🧩 Próximas Mejoras Sugeridas (Opcionales)
- Pre-cache de imagen/icono para web y desktop (reduce primer frame delay).
- Splash unificado multi-plataforma con `flutter_native_splash` si se desea estandarizar.
- Telemetría ligera (opcional) para medir tiempos de arranque (sin datos sensibles).
- Estrategia de retry/backoff centralizada para sync.
- Modo onboarding (aprovechar `WelcomeScreen` antes de login).

## ⚠️ Pitfalls Evitados
- No usar `auth.persistSessionString` (se optó por JSON robusto real).
- Evitar limpiar Hive automáticamente (rompe offline y sesión persistente).
- No colocar lógica de network/recover en cada pantalla (solo en bootstrap + AuthGate).

## 🧾 Resumen Rápido de Flujos
- Arranque: Hive + Supabase -> restore -> route -> runApp -> overlay fade.
- Login: credenciales -> Supabase session -> save local -> navegar.
- Offline: sin red + datos locales => dashboard con userId `offline`.
- Logout: signOut supabase + clear session local + navegar a welcome/login.

## 📨 Deep Links
- Soportado: `deudaflow://reset-password` (manejado en `_handleIncomingLinks`).
- Extender: añadir nuevos hosts -> actualizar manifest + lógica central.

## 🔍 Debug Rápido
- Ver logs de arranque: buscar `[BOOT]` en consola.
- Ver restauración: mensajes en `restoreSessionIfNeeded`.
- Problemas visuales de splash: revisar `launch_background.xml` + estilos v31.


Última actualización: (auto) refactor splash, persistencia sesión híbrida y optimizaciones de arranque.
Mantener este documento sincronizado con cambios estructurales futuros.
