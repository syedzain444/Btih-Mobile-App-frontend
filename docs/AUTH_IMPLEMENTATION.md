# Authentication Implementation Plan & Summary

This document describes how login and auth APIs were stabilized across the **Flutter app** and **ASP.NET Core API**, and how to maintain them going forward.

---

## Goals

1. Stable auth endpoints: `login`, `verifyPhoneNo`, `send-otp`, `verify-otp`, `updatePassword`
2. Consistent API error responses
3. Input validation on server and client
4. Login screen with phone + password, inline validation, loading state, and network error handling
5. Single consolidated `AuthService` on Flutter (no duplicated HTTP logic)

---

## Architecture Overview

```
Login Screen / Forgot Password Screen
        │
        ▼
  AuthService (Flutter)  ──►  ApiConfig (auto server URL)
        │
        ▼
  POST /api/Auth/*
        │
        ▼
  AuthController (ASP.NET)
        │
        ├── IAuthService → AuthRepository → Oracle DB
        └── IPatientService → updatePassword
```

---

## Backend Changes (HospitalMobileAPPApi)

### 1. Standard API response shape

All auth endpoints now return a consistent JSON structure:

**Success**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "MR_NO": "010-002-152",
    "mrNo": "010-002-152",
    "firstName": "Ali"
  }
}
```

**Failure**
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": ["Contact number must be 10–15 digits."]
}
```

Files:
- `Models/ApiResponse.cs`
- `Models/AuthRequests.cs`

### 2. AuthController improvements

| Endpoint | Method | Validation | Notes |
|----------|--------|------------|-------|
| `/api/Auth/login` | POST body | Contact 10–15 digits, password ≥ 4 chars | Returns MR number + first name |
| `/api/Auth/verifyPhoneNo` | POST query | Contact or MR required | Returns `mr_no`, `contactno` |
| `/api/Auth/send-otp` | POST query/body | Valid phone | Caches OTP 2 min; dev mode returns `debugOtp` if SMS fails |
| `/api/Auth/verify-otp` | POST query/body | 6-digit OTP | Removes OTP from cache on success |
| `/api/Auth/updatePassword` | POST query/body | MR + password ≥ 6 chars | Moved under Auth for consistency |

File: `Controllers/AuthController.cs`

### 3. PatientController

`/api/Patient/updatePassword` kept for backward compatibility with the same validation rules.

---

## Flutter Changes (btih_andriod_app)

### 1. Consolidated AuthService

**Before:** Each method (`login`, `sendOtp`, etc.) had its own HTTP call, timeout, and error parsing.

**After:** One private `_request()` method handles:
- API URL resolution via `ApiConfig`
- Network retry (re-probes server once on connection failure)
- JSON decode
- Unified `AuthApiException` with error type (`network`, `validation`, `unauthorized`, `server`)

Files:
- `lib/services/auth_service.dart`
- `lib/services/auth_exceptions.dart`

### 2. Login screen

| Feature | Implementation |
|---------|----------------|
| Phone + password | `TextFormField` with validators |
| Validation messages | Inline under fields (required, min length, digits only) |
| Loading state | Button disabled + spinner while `_loading == true` |
| Network errors | Caught as `AuthApiException` with user-friendly message |
| Duplicate logic removed | No manual `SocketException` checks in screen — handled in service |

File: `lib/screens/login_screen.dart`

### 3. Forgot password screen

Updated to use `AuthApiException` and the new API response format. In **development**, if SMS is unavailable, the API returns `debugOtp` so OTP flow can still be tested.

File: `lib/screens/forgot_password_screen.dart`

### 4. Server connection (related fix)

`ApiConfig` auto-detects the API URL, remembers the last working address, and re-probes on failure. Run `start-mobile-dev.bat` before testing.

File: `lib/utils/ip_file.dart`

---

## How to Test

### 1. Start the API
```bat
start-mobile-dev.bat
```
Or:
```powershell
cd HospitalMobileAPPApi
dotnet run --launch-profile http
```

### 2. Run the app
```powershell
cd btih_andriod_app
flutter run
```

### 3. Test cases

| Test | Expected result |
|------|-----------------|
| Empty login fields | Inline validation errors on screen |
| Wrong password | "Invalid contact number or password" |
| API not running | Network error with setup instructions |
| Forgot password → valid phone | OTP sent (or dev OTP shown) |
| Wrong OTP | "Invalid or expired OTP" |
| Password update | Success message, return to login |

---

## Deployment Checklist

- [ ] API running on `http://0.0.0.0:8080`
- [ ] Windows Firewall allows port 8080 (handled by `start-mobile-dev.bat`)
- [ ] USB phone: `adb reverse tcp:8080 tcp:8080`
- [ ] Wi‑Fi phone: same network as PC
- [ ] SMS gateway reachable from API server for production OTP
- [ ] Restart API after backend code changes

---

## Future Improvements (optional)

1. Move OTP/SMS logic into a dedicated `ISmsService`
2. Hash passwords instead of plain-text comparison in Oracle
3. JWT tokens for session management
4. Rate-limit OTP requests per phone number
5. Fix hardcoded URL in `doctor_schedule_screen.dart` to use `ApiConfig`

---

## Files Changed

### Backend
- `Models/ApiResponse.cs` *(new)*
- `Models/AuthRequests.cs` *(new)*
- `Controllers/AuthController.cs`
- `Controllers/PatientController.cs`

### Flutter
- `lib/services/auth_service.dart`
- `lib/services/auth_exceptions.dart` *(new)*
- `lib/screens/login_screen.dart`
- `lib/screens/forgot_password_screen.dart`
- `lib/utils/ip_file.dart` *(connection stability)*
