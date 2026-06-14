# Smart Hostel Management System (SHMS)

**Namal University Girls Hostel — Database Systems Project**
Department of Computer Science | Namal University, Mianwali | 2025–26

---

## Description

The Smart Hostel Management System (SHMS) is a full-stack web application designed to automate and digitise the daily operations of Namal University's Girls Hostel. It replaces manual paper-based processes with a secure, role-based digital system.

**Core functionality includes:**

- **Attendance Management** — Students mark attendance between 8:00 PM and 10:00 PM using a live camera selfie and GPS geofence verification. Students outside the hostel boundary cannot mark attendance. Absentees are automatically recorded at 10:00 PM.
- **Exit Management** — Students submit exit applications. Exits before 5:00 PM are auto-approved with a mandatory return by 5:00 PM. Exits at or after 5:00 PM require warden approval. The security guard confirms physical exit and records return.
- **Room Allocation** — The warden assigns rooms to students. Each student may have only one active room at a time. Room occupancy is tracked automatically.
- **Complaint Handling** — Students file complaints which the warden reviews and resolves. Students can view their complaint history and resolution notes.
- **Security Gate Screen** — PIN-protected screen (no login) for the security guard. Shows today's approved exits. Guard confirms exit and records student return. Sends notifications to warden on late returns.
- **Admin Panel** — Manage students (add/edit/hard-delete), rooms (add/edit/delete), warden credentials, geofence configuration, gate PIN, and all system settings.

---

## System Requirements

### Software
| Requirement | Version |
|-------------|---------|
| Python | 3.10 or higher |
| MySQL Server | 8.0 or higher |
| MySQL Workbench | Any recent version (optional, for running SQL files) |
| Web Browser | Chrome, Firefox, or Edge (for camera/GPS support) |

### Python Libraries
```
Flask==3.0.3
PyMySQL==1.1.1
Werkzeug==3.0.3
gunicorn==21.2.0
```

### Hardware
- Laptop or PC with a working camera and GPS (or browser location permission)
- Minimum 2 GB RAM, any modern processor
- Network connection (WiFi or ZeroTier for LAN access from Android)

---

## Installation

### Step 1 — Install Python dependencies

```bash
pip install -r requirements.txt
```

### Step 2 — Set up the MySQL database

Open MySQL Workbench or a MySQL terminal and run the files in this exact order:

```sql
SOURCE path/to/dbDDL.sql;
SOURCE path/to/dbDML.sql;
```

If you also need migration fixes and new rooms:

```sql
SOURCE path/to/dbMigration_fixes.sql;
SOURCE path/to/dbMigration_rooms.sql;
SOURCE path/to/dbDDL_v2_additions.sql;
```

### Step 3 — Configure database password

Open `app.py` and locate the configuration block. Set your MySQL root password:

```python
MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', 'YOUR_PASSWORD_HERE'),
```

Or set an environment variable before running:

```bash
# Windows CMD
set MYSQL_PASSWORD=yourpassword

# Windows PowerShell
$env:MYSQL_PASSWORD="yourpassword"
```

### Step 4 — Start the application

```bash
python app.py
```

The server starts on `http://0.0.0.0:5000` — accessible from your machine and the local network.

### Step 5 — Initialise passwords (one time only)

Visit this URL once in your browser immediately after starting the app:

```
http://127.0.0.1:5000/init-passwords
```

This sets the correct bcrypt password hashes for all seed users. Without this step, no one can log in.

---

## Usage

### Accessing the System

| URL | Purpose |
|-----|---------|
| `http://127.0.0.1:5000` | Main login page |
| `http://127.0.0.1:5000/init-passwords` | One-time password initialiser |
| `http://127.0.0.1:5000/team` | Development team page |

### Default Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@namal.edu.pk | admin#1219@00 |
| Warden | nida.sultan@namal.edu.pk | nidanida1200 |
| Security Gate | *(PIN on login page)* | 65432100 |
| Students (real) | their university email | namal123 |


### Android / ZeroTier Access

Since ZeroTier is installed on both the laptop and your Android device:

1. Find your ZeroTier IP (shown in the ZeroTier app, e.g. `10.x.x.x`)
2. Make sure both devices are on the same ZeroTier network
3. Open Chrome on Android and visit: `http://10.x.x.x:5000`

### Key Features by Role

**Student**
- Mark attendance (8–10 PM only, selfie + GPS required)
- Submit exit application
- View My Complaints and My Exit History (last 30 days)
- Change password and update profile photo

**Warden**
- Approve or reject exit applications
- View absent students, students on leave, returned today
- Click any student to see full profile + 30-day attendance with selfies
- Resolve complaints
- Allocate rooms
- Download CSV reports (attendance, rooms, exits) by date range
- Lock/unlock student profile photo updates

**Security Guard**
- Enter gate PIN (default: 654321) to access gate screen
- Confirm student exit and record student return
- View history of all exits/returns
- English/Urdu language toggle

**Admin**
- Full student management (add, edit, hard delete, reset password)
- Batch import students from CSV (download template from admin panel)
- Room management (add, edit, delete)
- Configure geofence (radius 20m–10,000m)
- Change gate PIN
- Advanced system settings (attendance window, exit approval rules, photo cooldown, session timeout)
- View full system change log

---

## Code Structure

```
HELEN X SHMS/
│
├── app.py                    Main Flask application — all routes for 4 roles
├── database.py               Database wrapper — all queries via stored procedures
│
├── dbDDL.sql                 Full schema: 15 tables, views, functions,
│                             stored procedures, triggers, events
├── dbDML.sql                 Seed data: admin, warden, security, 15 demo students, rooms
├── dbDML_students.sql        335 real female students (generated from Excel)
├── dbMigration_fixes.sql     Bug fixes: attendance, Returned status, notifications
├── dbMigration_rooms.sql     Room reset, E/F block rooms, bulk allocation
├── dbDDL_v2_additions.sql    SystemSettings table, exit expiry event
│
├── generate_students_sql.py  Script that generated dbDML_students.sql
│
├── requirements.txt          Python dependencies
├── Procfile                  For Railway/Heroku deployment
├── README.md                 Original README
├── PROJECT_README.md         This file
│
├── static/
│   ├── css/style.css         Green theme, sidebar layout, dark mode
│   ├── js/main.js            Camera capture, GPS detection, UI helpers
│   ├── images/               Logo and team photos (logo.png, nida.jpg, etc.)
│   └── uploads/              Auto-created: profile photos and attendance selfies
│
└── templates/
    ├── base.html             Shared navbar, flash messages, dark/light toggle
    ├── login.html            Login form + Security Gate button + Team page link
    ├── security_pin.html     Gate PIN entry with numpad
    ├── student_dashboard.html  Sidebar layout: attendance, exit, complaints, history
    ├── warden_dashboard.html   Tabs: exits, complaints, attendance, students, reports
    ├── security_dashboard.html Gate screen: student cards, confirm exit, record return
    ├── admin_dashboard.html    Full admin panel with all management tabs
    ├── team.html              Development team and supervisor page
    └── warden_student_detail.html  Full student profile view for warden
```

### Key Files Explained

| File | Role |
|------|------|
| `app.py` | All Flask routes. Entry point. Bind to `0.0.0.0` for LAN access. |
| `database.py` | Every DB call goes here. Uses stored procedures via PyMySQL. |
| `dbDDL.sql` | Single source of truth for the database schema. |
| `static/js/main.js` | Handles browser camera (getUserMedia) and GPS (geolocation API). |
| `dbMigration_fixes.sql` | Run this if upgrading from an earlier version of the schema. |

---

## Database Design Summary

| Object Type | Count |
|-------------|-------|
| Tables | 15 |
| Views | 6 |
| Stored Procedures | 18 |
| Functions | 3 |
| Triggers | 2 |
| Events | 3 |

**Supertype / Subtype:** `User` (supertype) → `Student`, `Warden`, `SecurityPersonnel`, `SystemAdministrator`

---

## Team

| Name | Roll Number | Role |
|------|-------------|------|
| Muhammad Ahmad | NUM-BSCS-2024-44 | Team Lead / Frontend |
| Asad Ullah Khan | NUM-BSCS-2024-17 | DB Design / Backend |
| Maryam Rashid | NUM-BSCS-2024-33 | ERD Design / Frontend |

**Requirement Provider & Supervisor:** Ms. Nida Sultan Nahra, Ms. Asiya Batool
**Course:** Database Systems | Namal University, Mianwali
