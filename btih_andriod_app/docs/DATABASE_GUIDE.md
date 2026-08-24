# HMIS Oracle Database Guide

Simple guide for exploring the hospital database used by the mobile app.

---

## 1. Connect in SQL Developer

Use your **HMISConnection** settings:

| Field | Value |
|-------|--------|
| Username | `HMIS` |
| Password | `hmis` |
| Hostname | `172.20.10.52` |
| Port | `8076` |
| Service name | `SIDHOSER` |

Click **Test** → **Connect**.

---

## 2. See ALL tables you can access

```sql
-- All tables owned by HMIS user
SELECT table_name
FROM user_tables
ORDER BY table_name;
```

```sql
-- All tables HMIS can see (other schemas too)
SELECT owner, table_name
FROM all_tables
WHERE owner IN ('HMIS', 'HOSWEB_MVC_LOCAL', 'HOSWEB_MVC_LIVE')
ORDER BY owner, table_name;
```

In SQL Developer UI (no SQL):
1. Left panel → **Connections**
2. Expand **HMISConnection**
3. Expand **Tables** → full list with row counts

---

## 3. See columns of any table

Replace `PATIENT_MST` with any table name:

```sql
SELECT column_name, data_type, data_length, nullable
FROM all_tab_columns
WHERE table_name = 'PATIENT_MST'
  AND owner = 'HMIS'
ORDER BY column_id;
```

Quick peek at data:

```sql
SELECT * FROM PATIENT_MST WHERE ROWNUM <= 10;
```

---

## 4. Main tables for the mobile app

| Table | What it stores |
|-------|----------------|
| **PATIENT_MST** | Patient master: name, gender, **PATIENT_PASSWORD** (login password) |
| **PATIENT_INFORMATION** | Contact, CNIC, email, blood group, DOB |
| **PATIENT_VISIT** | Hospital visits (needed for full profile/history) |
| **PRESCRIPTIONS** | Prescription records |
| **V_LABORATORY_GEN** | Lab / gastro / radiology reports (view) |

### Login uses these two:

```sql
SELECT pi.MR_NO, pi.CONTACT_NO, pm.FIRST_NAME, pm.PATIENT_PASSWORD
FROM PATIENT_MST pm
JOIN PATIENT_INFORMATION pi ON pi.MR_NO = pm.MR_NO
WHERE pi.CONTACT_NO = '03032431177';
```

---

## 5. Patient Sign Up — same tables as Login

Sign Up does **not** use a separate table. It writes to:

- **PATIENT_MST** — name, password, new MR number (e.g. `MOB-250824-1234`)
- **PATIENT_INFORMATION** — phone number

After sign-up, verify with:

```sql
SELECT pi.MR_NO, pi.CONTACT_NO, pm.FIRST_NAME, pm.PATIENT_PASSWORD
FROM PATIENT_MST pm
JOIN PATIENT_INFORMATION pi ON pi.MR_NO = pm.MR_NO
WHERE pi.CONTACT_NO = 'YOUR_PHONE_HERE';
```

See **[PATIENT_AUTH_GUIDE.md](PATIENT_AUTH_GUIDE.md)** for the full welcome-screen flow.

---

## 6. Find tables by keyword

```sql
SELECT owner, table_name
FROM all_tables
WHERE UPPER(table_name) LIKE '%PATIENT%'
ORDER BY owner, table_name;
```

```sql
SELECT owner, table_name
FROM all_tables
WHERE UPPER(table_name) LIKE '%BILL%'
   OR UPPER(table_name) LIKE '%APPOINT%'
ORDER BY owner, table_name;
```

---

## 7. Count rows in important tables

```sql
SELECT 'PATIENT_MST' AS tbl, COUNT(*) AS cnt FROM PATIENT_MST
UNION ALL
SELECT 'PATIENT_INFORMATION', COUNT(*) FROM PATIENT_INFORMATION
UNION ALL
SELECT 'PATIENT_VISIT', COUNT(*) FROM PATIENT_VISIT;
```

---

## 8. SQL Developer tips

| Task | How |
|------|-----|
| Browse tables | Connections → Tables → double-click table → **Data** tab |
| Run one statement | Select SQL → **Ctrl+Enter** |
| Run script (CREATE TABLE) | **F5** (Run Script) |
| Export results | Right-click result grid → Export |
| Table relationships | Right-click table → **Data Modeler** (if licensed) |

---

## 9. Two databases in appsettings.json

| Connection name | Host | Used for |
|-----------------|------|----------|
| **HMISConnection** | 172.20.10.52:8076 | Login, patients, reports, signup |
| **HOS_WEB_MVC_LIVE** | 172.16.10.73:1522 | Appointments (separate DB) |

Connect to each separately in SQL Developer if you need appointment tables.

---

## 10. After implementing Sign Up

1. Restart API (`start-mobile-dev.bat`)
2. Sign up in the app with a new phone number
3. Check in SQL Developer:

```sql
SELECT pi.MR_NO, pi.CONTACT_NO, pm.FIRST_NAME, pm.PATIENT_PASSWORD
FROM PATIENT_MST pm
JOIN PATIENT_INFORMATION pi ON pi.MR_NO = pm.MR_NO
WHERE pi.CONTACT_NO = 'YOUR_PHONE';
```

4. Use **Login** with the same phone + password.

---

## 11. Safety

- **Live DB** — avoid `DELETE` / `UPDATE` without IT approval  
- Always use `SELECT` first  
- Use `COMMIT` only when you intend to save changes  
- Test patients use MR numbers starting with `MOB-` from mobile registration
