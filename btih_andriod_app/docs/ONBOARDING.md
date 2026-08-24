# BTIH Mobile App — Developer Onboarding Guide

> **Audience:** A junior developer new to Flutter who will be working on this project.
> This document explains, from zero, what the app is, how it is structured, how every
> folder/file fits together, how it talks to the .NET Core (Swagger) backend, and how to
> run and extend it.

Take your time. Read section 1–4 first (concepts + run), then use section 6 (file-by-file)
as a reference while you work.

---

## Table of Contents

1. [What this app is](#1-what-this-app-is)
2. [Flutter concepts you must know first](#2-flutter-concepts-you-must-know-first)
3. [How to set up your machine and run the app](#3-how-to-set-up-your-machine-and-run-the-app)
4. [The big picture: architecture & layers](#4-the-big-picture-architecture--layers)
5. [Directory structure (what lives where)](#5-directory-structure-what-lives-where)
6. [File-by-file explanation](#6-file-by-file-explanation)
7. [App flow (screen by screen)](#7-app-flow-screen-by-screen)
8. [How the app talks to the .NET backend](#8-how-the-app-talks-to-the-net-backend)
9. [Connecting to the backend / Swagger — step by step](#9-connecting-to-the-backend--swagger--step-by-step)
10. [Local storage (SQLite + SharedPreferences)](#10-local-storage-sqlite--sharedpreferences)
11. [Recipe: how to add a new feature](#11-recipe-how-to-add-a-new-feature)
12. [Known issues & technical debt](#12-known-issues--technical-debt)
13. [Useful commands & glossary](#13-useful-commands--glossary)

---

## 1. What this app is

**BTIH App** (`btih_andriod_app`) is the **patient-facing mobile app for Bahria Town
International Hospital Karachi**. Patients use it to:

- Log in with their **contact number + password** (MR = Medical Record number identifies a patient).
- Browse **doctors** and their **schedules**, and **book appointments**.
- View their **profile**, **appointments**, **discharge history**, and **medical reports** (PDF).
- Use some features as a **guest** (without logging in); other features require login.

It is a **Flutter** app (written in the **Dart** language). Flutter builds Android, iOS,
web, Windows, macOS, and Linux from one codebase — but this project targets **Android**
primarily. The app is a **client**: it has almost no business logic of its own. It calls a
separate **.NET Core Web API** (the one you see in **Swagger**) over HTTP, and that API talks
to the **Oracle hospital database**.

```
[ Flutter Mobile App ]  --HTTP/JSON-->  [ .NET Core API (Swagger) ]  --SQL-->  [ Oracle DB ]
        (this repo)                          (separate backend repo)              (HMIS)
```

---

## 2. Flutter concepts you must know first

You don't need to be an expert, but these 8 ideas explain 90% of the code:

1. **Everything is a Widget.** A button, text, padding, a whole screen — all are widgets.
   You build UI by **nesting** widgets inside each other (a "widget tree").

2. **`StatelessWidget`** — a widget whose look never changes after it's built (e.g.
   `SplashScreen`'s logo, `HomeScreen`). It only has a `build()` method.

3. **`StatefulWidget`** — a widget that can **change over time** (e.g. a screen that loads
   data, shows a spinner, then shows a list). It comes in **two classes**:
   - `XxxScreen extends StatefulWidget` — holds the constructor parameters.
   - `_XxxScreenState extends State<XxxScreen>` — holds the changing data and the `build()`.

4. **`setState(() { ... })`** — call this inside a State class when data changes. It tells
   Flutter to **re-run `build()`** and repaint the screen. If you change a variable without
   `setState`, the UI won't update.

5. **`build(BuildContext context)`** — returns the widget tree to display. `context` is the
   widget's position in the tree; it's needed for navigation, themes, dialogs, etc.

6. **Navigation** — screens are a stack. To open a screen:
   ```dart
   Navigator.push(context, MaterialPageRoute(builder: (_) => SomeScreen()));
   ```
   To go back: `Navigator.pop(context)`. To replace and clear history (e.g. after login):
   `Navigator.pushAndRemoveUntil(...)`.

7. **`async` / `await` / `Future`** — network and database calls take time. A `Future<T>` is
   "a value that will arrive later." You `await` it to get the result without freezing the UI:
   ```dart
   final response = await http.post(url, body: ...); // waits for the server
   ```

8. **`FutureBuilder`** — a widget that shows a spinner while a `Future` is loading, then shows
   the result (used in list/report screens).

**Naming conventions:** Dart uses `lowerCamelCase` for variables/functions, `UpperCamelCase`
for classes, and `lower_snake_case.dart` for file names. Anything prefixed with `_`
(underscore) is **private** to its file.

---

## 3. How to set up your machine and run the app

### 3.1 Install the tools

1. **Flutter SDK** — install and add to `PATH`. Verify with `flutter --version`.
2. **Android Studio** — provides the Android SDK, emulator, and device drivers.
3. **VS Code or Cursor** with the Flutter/Dart extensions (this repo is used with Cursor).
4. **A JDK 21** — see the important note below.

### 3.2 IMPORTANT: use JDK 21 for the Android build

This project's Gradle/Kotlin toolchain does **not** work with the very new JDK 25 that
Android Studio may bundle. Point Flutter at a **JDK 21**:

```powershell
# install once (in a normal PowerShell)
winget install --id EclipseAdoptium.Temurin.21.JDK -e
# tell Flutter to use it (adjust the folder to the version you installed)
flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.8-hotspot"
```

> There are also two project settings already applied for this environment:
> - `android/gradle.properties` sets `kotlin.incremental=false` (the project is on `D:` while
>   the Flutter pub cache is on `C:`, and Kotlin's incremental compiler crashes across drives).
> - If you ever hit an NDK error like `did not have a source.properties file`, delete the
>   folder it names (e.g. `...\Android\sdk\ndk\<version>`) and rebuild so it re-downloads.

### 3.3 Run the app

```powershell
cd "D:\MUNIZAH_HOSPITAL_MOBILE APP\btih_andriod_app"
flutter pub get        # download Dart package dependencies (run after pulling changes)
flutter devices        # confirm your phone/emulator is listed
flutter run            # build & launch on the selected device
```

While it runs, press **`r`** for hot-reload (fast UI refresh) or **`R`** for hot-restart.

> **Before login will work**, you must point the app at a reachable API and have that API
> running — see [section 9](#9-connecting-to-the-backend--swagger--step-by-step).

---

## 4. The big picture: architecture & layers

The app follows a simple, common Flutter layering. There is **no state-management library**
(no Provider/Bloc/Riverpod) — state is kept inside each screen's `State` class and passed
between screens via **constructor parameters**.

```
┌────────────────────────────────────────────────────────────┐
│  UI LAYER  →  lib/screens/*.dart                            │
│  Screens/pages the user sees. Hold UI state, call services. │
└───────────────┬────────────────────────────────────────────┘
                │ calls
┌───────────────▼────────────────────────────────────────────┐
│  SERVICE LAYER  →  lib/services/*.dart                       │
│  Talk to the backend over HTTP. Return typed models.        │
└───────────────┬────────────────────────────────────────────┘
                │ parse JSON into
┌───────────────▼────────────────────────────────────────────┐
│  MODEL LAYER  →  lib/models/*.dart                           │
│  Plain Dart classes with fromJson()/toJson(). Data shapes.  │
└─────────────────────────────────────────────────────────────┘

  CROSS-CUTTING  →  lib/utils/*.dart
  Config (API base URL), date formatting, validation, local DB.
```

**The golden rule of this codebase:** the API address is configured in **one place** —
`lib/utils/ip_file.dart` (`ApiConfig.baseUrl`) — and every service builds its URLs from it.

**Typical data flow for one feature (e.g. "list doctors"):**

1. `DoctorsListScreen` (screen) calls `DoctorService().getDoctorsPaginated()`.
2. `DoctorService` (service) does `http.get("${ApiConfig.baseUrl}/api/Doctor?...")`.
3. The JSON response is parsed by `DoctorResponse.fromJson(...)` (model).
4. The screen calls `setState(...)` to show the list.

---

## 5. Directory structure (what lives where)

Only `lib/` and `android/` matter day-to-day. The other platform folders
(`ios/`, `web/`, `windows/`, `macos/`, `linux/`) are auto-generated and rarely touched.

```
btih_andriod_app/
├─ lib/                     ← ALL your Dart code lives here
│  ├─ main.dart             ← app entry point (starts MyApp → SplashScreen)
│  ├─ models/               ← data classes (JSON ↔ Dart objects)
│  ├─ screens/              ← UI pages the user navigates between
│  ├─ services/             ← HTTP calls to the .NET API
│  └─ utils/                ← config, helpers, local database
│
├─ android/                 ← native Android project & build config
│  ├─ app/src/main/AndroidManifest.xml   ← permissions, app name, cleartext HTTP
│  ├─ app/build.gradle.kts               ← app module build settings
│  ├─ build.gradle.kts                   ← root Gradle config
│  ├─ settings.gradle.kts                ← Gradle plugin versions
│  └─ gradle.properties                  ← JVM/Kotlin build flags
│
├─ pubspec.yaml             ← dependencies & project metadata (the "package.json" of Flutter)
├─ pubspec.lock             ← locked exact dependency versions (auto-generated)
├─ analysis_options.yaml    ← lint rules for `flutter analyze`
├─ test/widget_test.dart    ← (default template test)
├─ docs/ONBOARDING.md       ← this document
│
├─ ios/ web/ windows/ macos/ linux/   ← per-platform generated projects (mostly ignore)
└─ README.md .gitignore .metadata     ← standard project files
```

---

## 6. File-by-file explanation

### 6.1 Entry point

| File | What it does |
|------|--------------|
| `lib/main.dart` | Starts the app. Creates `MyApp`, a `MaterialApp` whose first route `'/'` is `SplashScreen`. This is where global app config (title, theme, routes) would go. |

### 6.2 `lib/screens/` — the UI pages

| File | Purpose |
|------|---------|
| `splash_screen.dart` | Animated logo shown for ~3 seconds on launch, then navigates to the Dashboard as a **guest** (`isLoggedIn: false`). |
| `dashboard_screen.dart` | **The hub.** Bottom navigation + feature tiles. Holds `patientMrNo`, `patientName`, `isLoggedIn`. **Gates protected features**: if a guest taps a login-only feature, it shows a "Login Required" dialog and routes to `LoginScreen`. This is the biggest, most important screen. |
| `login_screen.dart` | Login by contact number + password. Also contains OTP verification, phone verification, and password-update flows. **Note:** the active auth network class (with `login()`, `sendOtp()`, `verifyOtp()`, etc.) is defined **inside this file**. On success it navigates to `DashboardScreen(isLoggedIn: true)` with the returned MR number and name. |
| `doctors_list_screen.dart` | Lists doctors (paginated) via `DoctorService`. Tapping a doctor opens their schedule. |
| `doctor_schedule_screen.dart` | Shows a doctor's available slots and lets the user **book an appointment** (uses `BookingService`). Also has a hardcoded phone-verify URL (see tech debt). |
| `AppointmentsInfoScreen.dart` | Shows the patient's appointments (from `/api/Patient/appointments/{mrNo}`). *(File name breaks the snake_case convention — see tech debt.)* |
| `discharge_history_screen.dart` | Lists the patient's discharge records (paginated). |
| `patient_profile_screen.dart` | Shows the logged-in patient's profile (`/api/Patient?MR_NO=...`). |
| `reports_screen.dart` | Lab/gastro/radiology/prescription reports; can generate/open PDF reports. Large screen with tabs. |
| `patient_report_history_screen.dart` | History of generated reports; opens PDFs (via Syncfusion PDF viewer / url_launcher). |
| `home_screen.dart` | Unused placeholder ("Welcome to the Home Screen"). Safe to ignore. |

### 6.3 `lib/services/` — backend communication

Each service wraps a set of related API endpoints. They use the `http` package (a few use
`dio`) and build URLs from `ApiConfig.baseUrl`.

| File | Talks to | Notes |
|------|----------|-------|
| `doctors_service.dart` | `/api/Doctor`, `/api/Doctor/{id}/schedule` | `getDoctorsPaginated()` is the current method; `getDoctors()` is legacy. |
| `specialization_service.dart` | `/api/Doctor/specialization` | Doctor specializations. |
| `booking_service.dart` | `POST /api/Patient/insertchallan` | Creates an appointment ("challan"). |
| `apointment_service.dart` | appointment endpoints | (Note the misspelled filename.) |
| `discharge_history_service.dart` | `/api/Patient/dischargeHistory/{mrNo}` | Paginated discharge list. |
| `discharge_report_service.dart` | `/api/PatientReport/DischargeReport` | Generates a discharge report PDF. |
| `patient_report_service.dart` | `/api/PatientReport/history/{mrNo}` | Report history. |
| `bill_category_service.dart` | `https://172.16.40.56:80/api/BillData` | **Does NOT use `ApiConfig.baseUrl`** — hardcoded IP (tech debt). |
| `patients_service.dart` | — | Mostly commented-out/legacy. |
| `auth_service.dart` | `/api/Auth/login` | **Legacy/unused** — the real auth code lives in `login_screen.dart`. |
| `webview_flutter.dart` | — | Helper to open web content. |
| `url_launcher.dart` | — | Helper to open external URLs (e.g. PDFs, tel:). |

### 6.4 `lib/models/` — data shapes

Each model is a plain class with a `fromJson()` factory (JSON → object) and often a
`toJson()` (object → JSON). This is how raw API responses become typed Dart objects.

| File | Classes | Represents |
|------|---------|-----------|
| `patient_model.dart` | `PatientVisit`, `PatientInfo` | A patient visit & profile info. |
| `doctors_model.dart` | `Doctor`, `DoctorResponse`, `Pagination` | Doctor + paginated response wrapper. |
| `doctor_schedule_model.dart` | `DoctorSchedule` | A doctor's available slots. |
| `specialization_model.dart` | specialization | Department/specialization. |
| `discharge_history_model.dart` | discharge record | (Uses raw API field names like `mR_NO` — see tech debt.) |
| `patient_report_model.dart` | report item | A medical report entry. |
| `bill_category_model.dart` | bill category | Billing categories. |
| `user_model.dart` | `User` | Logged-in user. |
| `local_appointment.dart` | `LocalAppointment` | An appointment **stored locally** in SQLite (has `toMap()`/`fromMap()` for the DB). |

### 6.5 `lib/utils/` — configuration & helpers

| File | What it does |
|------|--------------|
| **`ip_file.dart`** | **Most important config file.** Defines `ApiConfig.baseUrl` — the single place to set the API address. Change this to point the app at your backend. |
| `date_formatter.dart` | `DateFormatter.formatDate(...)` — turns ISO date strings into `dd/MM/yyyy`. |
| `validation_mixin.dart` | `ValidationMixin` — reusable form validators (email, password, confirm password). |
| `database_helper.dart` | `DatabaseHelper` — a singleton wrapping the local **SQLite** database (`appointments` table) using `sqflite`. Used to store **guest appointments** offline. |

### 6.6 Key Android files

| File | What it does |
|------|--------------|
| `android/app/src/main/AndroidManifest.xml` | App name, icon, **permissions** (INTERNET, Bluetooth, location, storage), and **`usesCleartextTraffic="true"`** which allows plain `http://` calls (needed since `baseUrl` uses http). |
| `android/gradle.properties` | JVM memory + `kotlin.incremental=false` (cross-drive fix). |
| `android/settings.gradle.kts` | Android Gradle Plugin (`8.11.1`) and Kotlin (`2.2.20`) versions. |
| `pubspec.yaml` | Dart dependencies: `http`, `dio`, `firebase_auth`, `google_sign_in`, `syncfusion_flutter_pdfviewer`, `sqflite`, `shared_preferences`, `permission_handler`, `url_launcher`, etc. |

---

## 7. App flow (screen by screen)

```
main.dart
  └─ MyApp (MaterialApp, route '/')
       └─ SplashScreen  (2–3s animated logo)
            └─ DashboardScreen(isLoggedIn: false, name: "Guest")   ← lands here as GUEST
                 ├─ Browse Doctors ──────────────► DoctorsListScreen ─► DoctorScheduleScreen ─► (book) BookingService
                 │
                 ├─ Tap a PROTECTED feature (Profile / Reports / Appointments / Discharge)
                 │       └─ if not logged in → "Login Required" dialog → LoginScreen
                 │
                 └─ LoginScreen
                      └─ enter contactNo + password → AuthService.login() → POST /api/Auth/login
                            └─ on success: DashboardScreen(isLoggedIn: true, patientMrNo, patientName)
                                 ├─ PatientProfilePage
                                 ├─ ReportsScreen / PatientReportHistoryScreen
                                 ├─ AppointmentsInfoScreen
                                 └─ DischargeHistoryScreen
```

**Session model (important & simple):** After login, the MR number and name are passed to
`DashboardScreen` **via constructor parameters** and kept **in memory only**. The login state
is **not persisted** — if the app is closed and reopened, you start again as a guest. (See
tech debt: this is a good candidate for improvement using `SharedPreferences`.)

---

## 8. How the app talks to the .NET backend

### 8.1 The single source of truth for the URL

```1:8:lib/utils/ip_file.dart
class ApiConfig {
  // 🔹 Change this URL only once here.
  // Use your PC's LAN IPv4 address + the HTTP port the API listens on.
  // The API must be started bound to 0.0.0.0 (all interfaces), e.g.:
  //   dotnet run --urls "http://0.0.0.0:5000"
  // and your phone must be on the SAME network as this PC.
  static const String baseUrl = "http://172.16.40.53:5000";
}
```

Every service composes its endpoint like:

```dart
Uri.parse("${ApiConfig.baseUrl}/api/Doctor?pageNumber=$pageNumber&pageSize=$pageSize")
```

### 8.2 The request/response pattern (learn this once)

```dart
final response = await http.post(
  Uri.parse("${ApiConfig.baseUrl}/api/Auth/login"),
  headers: {'Content-Type': 'application/json', 'accept': '*/*'},
  body: jsonEncode({"contactNo": contactNo, "password": password}),
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);   // Map<String, dynamic>
  // ... build a model with SomeModel.fromJson(data)
} else {
  throw Exception(response.body);           // screen shows the error
}
```

### 8.3 Endpoints the app currently uses

These map directly to controllers you'll see in **Swagger**:

| Feature | Method & path |
|---------|---------------|
| Login | `POST /api/Auth/login` (body: `contactNo`, `password`) |
| Verify phone | `POST /api/Auth/verifyPhoneNo?ContactNo=...` |
| Send OTP | `POST /api/Auth/send-otp?phoneNumber=...` |
| Verify OTP | `POST /api/Auth/verify-otp?phoneNumber=...&otp=...` |
| Update password | `/api/Patient/updatePassword?mrno=...&patientPassword=...` |
| Doctors (paginated) | `GET /api/Doctor?pageNumber=&pageSize=` |
| Doctor schedule | `GET /api/Doctor/{id}/schedule` |
| Specializations | `GET /api/Doctor/specialization` |
| Patient profile | `GET /api/Patient?MR_NO=...` |
| Appointments | `GET /api/Patient/appointments/{mrNo}` |
| Discharge history | `GET /api/Patient/dischargeHistory/{mrNo}?pageNumber=&pageSize=` |
| Book appointment | `POST /api/Patient/insertchallan` |
| Report history | `GET /api/PatientReport/history/{mrNo}` |
| Generate report(s) | `GET /api/PatientReport/GenerateReports?rptId=&param=` and `POST /api/PatientReport/GenerateReport` |
| Discharge report | `GET /api/PatientReport/DischargeReport?rptId=&param=&empId=` |
| Bill data | `GET https://172.16.40.56:80/api/BillData` (hardcoded — tech debt) |

> **Note:** the login response nests the patient under `mR_NO`, e.g.
> `{ "message": "Login successful", "mR_NO": { "mrNo": "...", "firstName": "..." } }`.
> The login screen reads `response['mR_NO']` then `mrNo` / `firstName` from it.

---

## 9. Connecting to the backend / Swagger — step by step

Your API works in Swagger at `https://localhost:44387` because Swagger runs in a browser
**on the same PC** as the API. A **phone cannot reach `localhost`** — `localhost` on the
phone means the phone itself. So you must expose the API on your PC's **LAN IP** and point
the app there.

**Step 1 — Find your PC's LAN IP** (PowerShell): `ipconfig` → look at the IPv4 Address
(e.g. `172.16.40.53`).

**Step 2 — Run the API bound to all network interfaces** (in the .NET API project folder):
```powershell
dotnet run --urls "http://0.0.0.0:5000"
```
Now the API is reachable at `http://<YOUR_PC_IP>:5000`. (Using `http` avoids the self-signed
HTTPS certificate errors you'd get on a phone.)

**Step 3 — Open the firewall for that port** (PowerShell **as Administrator**):
```powershell
New-NetFirewallRule -DisplayName "HMIS API 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow
```

**Step 4 — Put the phone on the SAME Wi-Fi/LAN** as the PC. Test from the **phone's browser**:
```
http://<YOUR_PC_IP>:5000/swagger
```
If Swagger loads on the phone, networking is good. If it times out, the phone can't reach the
PC (wrong network, firewall, or Wi-Fi "client isolation") — fix that first.

**Step 5 — Point the app at that address** in `lib/utils/ip_file.dart`:
```dart
static const String baseUrl = "http://172.16.40.53:5000"; // your PC IP + port
```

**Step 6 — Rebuild** (the URL is a compile-time constant, so hot-reload isn't enough):
```powershell
flutter run
```

**How the backend/DB is configured (for context):** the .NET API's `appsettings.json` holds
Oracle connection strings (host, port, service name, user/password) under `ConnectionStrings`.
That's how the API reaches the HMIS Oracle database. You generally won't touch that from the
Flutter side — you only need the API's **URL**.

---

## 10. Local storage (SQLite + SharedPreferences)

- **SQLite (`sqflite`)** via `lib/utils/database_helper.dart`: a local `appointments` table
  used to save **guest appointments** on the device (so a not-logged-in user can still keep a
  booking locally). Model: `LocalAppointment` (`toMap()`/`fromMap()`).
- **`shared_preferences`**: simple key–value storage on the device. Used in a few screens for
  small flags. (It is **not** currently used to remember the logged-in session — see tech debt.)

---

## 11. Recipe: how to add a new feature

Say the backend adds `GET /api/Patient/allergies/{mrNo}`. To surface it in the app:

1. **Model** — create `lib/models/allergy_model.dart`:
   ```dart
   class Allergy {
     final String name;
     final String severity;
     Allergy({required this.name, required this.severity});
     factory Allergy.fromJson(Map<String, dynamic> json) => Allergy(
       name: json['name'] ?? '',
       severity: json['severity'] ?? '',
     );
   }
   ```
2. **Service** — create `lib/services/allergy_service.dart`:
   ```dart
   import 'dart:convert';
   import 'package:http/http.dart' as http;
   import 'package:btih_andriod_app/utils/ip_file.dart';
   import '../models/allergy_model.dart';

   class AllergyService {
     Future<List<Allergy>> getAllergies(String mrNo) async {
       final res = await http.get(
         Uri.parse("${ApiConfig.baseUrl}/api/Patient/allergies/$mrNo"),
       );
       if (res.statusCode == 200) {
         final List data = jsonDecode(res.body);
         return data.map((e) => Allergy.fromJson(e)).toList();
       }
       throw Exception('Failed to load allergies: ${res.statusCode}');
     }
   }
   ```
3. **Screen** — create `lib/screens/allergies_screen.dart` (a `StatefulWidget`), call the
   service in `initState()` or with a `FutureBuilder`, and render the list.
4. **Navigation** — add a tile/button on `dashboard_screen.dart` that does
   `Navigator.push(... AllergiesScreen(mrNo: widget.patientMrNo) ...)`, and (if login-only)
   wrap it in the existing `_checkLoginAndNavigate(...)` gate.
5. **Test** — `flutter run`, then verify against Swagger.

Follow the existing files as templates — every feature already follows this exact pattern.

---

## 12. Known issues & technical debt

These are safe to know about now and fix gradually. None block the app from running.

- **In-memory session only:** login state is lost on app restart. Consider saving `mrNo` +
  name in `shared_preferences` and reading it on `SplashScreen`.
- **Hardcoded IPs bypassing `ApiConfig`:** `bill_category_service.dart`
  (`https://172.16.40.56:80`) and `doctor_schedule_screen.dart` line ~807
  (`http://172.16.40.10:8080/api/Auth/verifyPhoneNo`). These should use `ApiConfig.baseUrl`.
- **`auth_service.dart` is legacy/unused;** real auth lives in `login_screen.dart`. Consider
  extracting auth into a proper service file.
- **Plaintext debugging:** many `print(...)` calls (lint `avoid_print`). Use a logger or wrap
  in `if (kDebugMode)`.
- **`use_build_context_synchronously` warnings:** several screens use `context` after an
  `await` without a `mounted` check — a real crash risk. Guard with `if (!mounted) return;`.
- **Naming lints:** `AppointmentsInfoScreen.dart` should be `appointments_info_screen.dart`;
  model fields like `mR_NO`, `patienT_VISIT_ID` aren't `lowerCamelCase` (renaming must be done
  carefully so JSON keys still map).
- Run `flutter analyze` to see the current list; many trivial ones can be auto-fixed with
  `dart fix --apply`.

---

## 13. Useful commands & glossary

### Commands

```powershell
flutter pub get                 # install/refresh dependencies (after pulling or editing pubspec)
flutter run                     # build & run on the connected device
flutter devices                 # list connected devices/emulators
flutter analyze                 # static analysis (lints/warnings/errors)
dart fix --dry-run              # preview auto-fixable lints
dart fix --apply                # apply safe auto-fixes
flutter clean                   # delete build/ (fixes many weird build issues), then pub get
flutter build apk --debug       # build a debug APK
```

### Glossary

| Term | Meaning |
|------|---------|
| **MR / MR_NO** | Medical Record number — the unique ID for a patient. |
| **Widget** | A UI building block in Flutter. |
| **State** | The changing data of a `StatefulWidget`; changing it via `setState` repaints. |
| **Future / async / await** | Tools for handling operations that complete later (network/DB). |
| **Service** | A class in `lib/services/` that calls the backend. |
| **Model** | A class in `lib/models/` describing a data shape with `fromJson`. |
| **`ApiConfig.baseUrl`** | The single configured API address (`lib/utils/ip_file.dart`). |
| **Swagger** | The interactive UI for the .NET API where you can test endpoints. |
| **Gradle / Kotlin / NDK** | Parts of the Android build system (see section 3.2). |
| **Hot reload / restart** | `r` / `R` while `flutter run` is active — apply code changes fast. |

---

### Suggested reading order for your first week

1. `lib/main.dart` → `lib/screens/splash_screen.dart` → `lib/screens/dashboard_screen.dart`
   (understand navigation and the guest/login gate).
2. `lib/utils/ip_file.dart` (config) → `lib/services/doctors_service.dart` +
   `lib/models/doctors_model.dart` (one full service+model example).
3. `lib/screens/login_screen.dart` (auth flow end-to-end).
4. Pick one feature screen (e.g. `discharge_history_screen.dart` + its service + model) and
   trace it from tap → service → model → UI.

Welcome to the team — start by getting the app to log in successfully against your local API
(section 9), then trace the doctors-list feature end to end. That will teach you the whole
pattern the rest of the app repeats.
