-- ============================================================
-- Smart Hostel Management System (SHMS) – Girls Hostel
-- Namal University, Mianwali
-- dbDDL.sql – Complete schema: Tables, Views, Functions,
--              Stored Procedures, Triggers, Events
-- MySQL 8.x
-- ============================================================

DROP DATABASE IF EXISTS shms;
CREATE DATABASE shms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE shms;

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE User (
    UserID       INT AUTO_INCREMENT PRIMARY KEY,
    Name         VARCHAR(100)  NOT NULL,
    Email        VARCHAR(150)  NOT NULL UNIQUE,
    PasswordHash VARCHAR(255)  NOT NULL,
    Phone        VARCHAR(20),
    Role         ENUM('Student','Warden','Security','Admin') NOT NULL,
    CreatedAt    DATETIME      DEFAULT CURRENT_TIMESTAMP,
    IsActive     TINYINT(1)    DEFAULT 1
);

-- Photo control columns included from the start
CREATE TABLE Student (
    StudentID          INT PRIMARY KEY,
    RollNumber         VARCHAR(50)  NOT NULL UNIQUE,
    Department         VARCHAR(100),
    Semester           INT,
    ProfilePhotoPath   VARCHAR(255),
    LastPhotoUpdate    DATETIME     DEFAULT NULL,
    PhotoUpdateLocked  TINYINT(1)   DEFAULT 0
        COMMENT '1 = locked by admin/warden, student cannot update photo',
    FOREIGN KEY (StudentID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Warden (
    WardenID    INT PRIMARY KEY,
    OfficePhone VARCHAR(20),
    HireDate    DATE,
    FOREIGN KEY (WardenID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE SecurityPersonnel (
    SecurityID INT PRIMARY KEY,
    FOREIGN KEY (SecurityID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE SystemAdministrator (
    AdminID INT PRIMARY KEY,
    FOREIGN KEY (AdminID) REFERENCES User(UserID) ON DELETE CASCADE
);

CREATE TABLE Room (
    RoomID           INT AUTO_INCREMENT PRIMARY KEY,
    RoomNumber       VARCHAR(20) NOT NULL UNIQUE,
    Capacity         INT         NOT NULL DEFAULT 2,
    CurrentOccupancy INT         NOT NULL DEFAULT 0,
    RoomStatus       ENUM('Available','Full','Maintenance') DEFAULT 'Available'
);

CREATE TABLE RoomAllocation (
    AllocationID     INT AUTO_INCREMENT PRIMARY KEY,
    StudentID        INT NOT NULL,
    RoomID           INT NOT NULL,
    AllocationType   ENUM('Manual','ByWarden') DEFAULT 'ByWarden',
    AllocationDate   DATETIME DEFAULT CURRENT_TIMESTAMP,
    DeallocationDate DATETIME,
    IsCurrent        TINYINT(1) DEFAULT 1,
    Status           ENUM('Active','Ended') DEFAULT 'Active',
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    FOREIGN KEY (RoomID)    REFERENCES Room(RoomID)
);

CREATE TABLE GeofenceBoundary (
    GeofenceID      INT AUTO_INCREMENT PRIMARY KEY,
    BoundaryName    VARCHAR(100) NOT NULL,
    LatitudePolygon TEXT,
    LongitudeCenter DECIMAL(10,7),
    LatitudeCenter  DECIMAL(10,7),
    RadiusMeters    DECIMAL(10,2) NOT NULL DEFAULT 200.00,
    IsActive        TINYINT(1) DEFAULT 1
);

CREATE TABLE DeviceRegistration (
    DeviceID     INT AUTO_INCREMENT PRIMARY KEY,
    StudentID    INT NOT NULL,
    DeviceToken  VARCHAR(255) NOT NULL UNIQUE,
    DeviceType   ENUM('iOS','Android','Web') DEFAULT 'Web',
    LastActiveAt DATETIME,
    RegisteredAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    IsActive     TINYINT(1) DEFAULT 1,
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID)
);

-- Selfie paths auto-purged after 30 days (see event below)
CREATE TABLE AttendanceRecord (
    AttendanceID       INT AUTO_INCREMENT PRIMARY KEY,
    StudentID          INT  NOT NULL,
    Date               DATE NOT NULL,
    VerificationTime   TIME,
    Status             ENUM('Present','Absent','OnLeave') DEFAULT 'Absent',
    VerificationMethod ENUM('Selfie+Geofence','Auto-Leave','AutoAbsent') DEFAULT 'AutoAbsent',
    GPSLocation        VARCHAR(100),
    SuspiciousFlag     TINYINT(1) DEFAULT 0,
    SelfiePath         VARCHAR(255),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    UNIQUE KEY uq_attendance (StudentID, Date)
);

CREATE TABLE ExitApplication (
    ApplicationID      INT AUTO_INCREMENT PRIMARY KEY,
    StudentID          INT NOT NULL,
    Destination        VARCHAR(200),
    IsOnLeave          TINYINT(1) DEFAULT 0,
    Reason             TEXT,
    DepartureTime      DATETIME,
    ExpectedReturnTime DATETIME,
    RestrictedTimeFlag TINYINT(1) DEFAULT 0,
    SubmittedAt        DATETIME DEFAULT CURRENT_TIMESTAMP,
    ApprovalStatus     ENUM('Pending','Approved','Rejected','Active','Returned') DEFAULT 'Pending',
    WardenID           INT,
    WardenRemarks      TEXT,
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    FOREIGN KEY (WardenID)  REFERENCES Warden(WardenID)
);

CREATE TABLE EntryExitLog (
    LogID                    INT AUTO_INCREMENT PRIMARY KEY,
    ApplicationID            INT,
    StudentID                INT NOT NULL,
    ExitTime                 DATETIME,
    ActualReturnTime         DATETIME,
    SelfiePath               VARCHAR(255),
    LateReturnAlert          TINYINT(1) DEFAULT 0,
    ReturnConfirmedByGeofence TINYINT(1) DEFAULT 0,
    FOREIGN KEY (ApplicationID) REFERENCES ExitApplication(ApplicationID),
    FOREIGN KEY (StudentID)     REFERENCES Student(StudentID)
);

CREATE TABLE Complaint (
    ComplaintID   INT AUTO_INCREMENT PRIMARY KEY,
    StudentID     INT NOT NULL,
    Title         VARCHAR(200) NOT NULL,
    Description   TEXT,
    ComplaintType VARCHAR(100),
    Attachment    VARCHAR(255),
    Status        ENUM('Pending','In Progress','Resolved','Rejected') DEFAULT 'Pending',
    SubmittedAt   DATETIME DEFAULT CURRENT_TIMESTAMP,
    ResolvedAt    DATETIME,
    WardenID      INT,
    WardenRemarks TEXT,
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    FOREIGN KEY (WardenID)  REFERENCES Warden(WardenID)
);

CREATE TABLE Notification (
    NotificationID INT AUTO_INCREMENT PRIMARY KEY,
    UserID         INT NOT NULL,
    Type           VARCHAR(100),
    Message        TEXT,
    SentAt         DATETIME DEFAULT CURRENT_TIMESTAMP,
    IsRead         TINYINT(1) DEFAULT 0,
    FOREIGN KEY (UserID) REFERENCES User(UserID)
);

CREATE TABLE SystemChangeLog (
    LogID       INT AUTO_INCREMENT PRIMARY KEY,
    AdminID     INT NOT NULL,
    Action      ENUM('CREATE','UPDATE','DELETE','SUSPEND') NOT NULL,
    EntityName  VARCHAR(100),
    RecordID    INT,
    ChangeTime  DATETIME DEFAULT CURRENT_TIMESTAMP,
    Description TEXT,
    FOREIGN KEY (AdminID) REFERENCES SystemAdministrator(AdminID)
);

-- ============================================================
-- 2. VIEWS
-- ============================================================

-- Security gate: today's approved exits not yet returned
CREATE OR REPLACE VIEW vw_SecurityGate AS
SELECT
    ea.ApplicationID,
    ea.StudentID,
    u.Name             AS StudentName,
    s.RollNumber,
    s.Department,
    s.ProfilePhotoPath,
    ea.IsOnLeave,
    ea.DepartureTime,
    ea.ExpectedReturnTime,
    ea.ApprovalStatus,
    ea.SubmittedAt,
    ea.RestrictedTimeFlag,
    CASE WHEN eel.ExitTime IS NOT NULL THEN 1 ELSE 0 END AS AlreadyExited,
    eel.ExitTime,
    eel.LogID
FROM ExitApplication ea
JOIN Student s ON ea.StudentID = s.StudentID
JOIN User u    ON s.StudentID  = u.UserID
LEFT JOIN EntryExitLog eel ON eel.ApplicationID = ea.ApplicationID
WHERE ea.ApprovalStatus IN ('Approved','Active')
  AND DATE(ea.DepartureTime) = CURDATE()
  AND (eel.ActualReturnTime IS NULL);

-- Gate history: all students who have returned
CREATE OR REPLACE VIEW vw_GateHistory AS
SELECT
    eel.LogID,
    eel.ApplicationID,
    eel.StudentID,
    u.Name             AS StudentName,
    s.RollNumber,
    s.Department,
    s.ProfilePhotoPath,
    ea.IsOnLeave,
    ea.DepartureTime,
    ea.ExpectedReturnTime,
    eel.ExitTime,
    eel.ActualReturnTime,
    eel.LateReturnAlert,
    eel.ReturnConfirmedByGeofence
FROM EntryExitLog eel
JOIN ExitApplication ea ON eel.ApplicationID = ea.ApplicationID
JOIN Student s          ON eel.StudentID = s.StudentID
JOIN User u             ON s.StudentID   = u.UserID
WHERE eel.ActualReturnTime IS NOT NULL
ORDER BY eel.ActualReturnTime DESC;

-- Warden: pending exit applications
CREATE OR REPLACE VIEW vw_PendingExits AS
SELECT
    ea.ApplicationID,
    ea.StudentID,
    u.Name             AS StudentName,
    s.RollNumber,
    ea.Destination,
    ea.IsOnLeave,
    ea.Reason,
    ea.DepartureTime,
    ea.ExpectedReturnTime,
    ea.RestrictedTimeFlag,
    ea.SubmittedAt,
    ea.ApprovalStatus
FROM ExitApplication ea
JOIN Student s ON ea.StudentID = s.StudentID
JOIN User u    ON s.StudentID  = u.UserID
WHERE ea.ApprovalStatus = 'Pending'
ORDER BY ea.SubmittedAt DESC;

-- Current room allocations
CREATE OR REPLACE VIEW vw_CurrentAllocations AS
SELECT
    ra.AllocationID,
    ra.StudentID,
    u.Name         AS StudentName,
    s.RollNumber,
    r.RoomNumber,
    r.Capacity,
    r.CurrentOccupancy,
    ra.AllocationDate,
    ra.AllocationType
FROM RoomAllocation ra
JOIN Student s ON ra.StudentID = s.StudentID
JOIN User u    ON s.StudentID  = u.UserID
JOIN Room r    ON ra.RoomID    = r.RoomID
WHERE ra.IsCurrent = 1 AND ra.Status = 'Active';

-- Today's absent students
CREATE OR REPLACE VIEW vw_AbsentToday AS
SELECT
    s.StudentID,
    u.Name,
    s.RollNumber,
    s.Department,
    s.Semester,
    COALESCE(ar.Status,'Absent') AS AttendanceStatus
FROM Student s
JOIN User u ON s.StudentID = u.UserID
LEFT JOIN AttendanceRecord ar
       ON ar.StudentID = s.StudentID AND ar.Date = CURDATE()
WHERE u.IsActive = 1
  AND (ar.Status = 'Absent' OR ar.AttendanceID IS NULL);

-- Attendance detail with selfies (warden, last 30 days)
CREATE OR REPLACE VIEW vw_AttendanceDetail AS
SELECT
    ar.AttendanceID,
    ar.StudentID,
    u.Name             AS StudentName,
    s.RollNumber,
    s.Department,
    s.ProfilePhotoPath,
    ar.Date,
    ar.VerificationTime,
    ar.Status,
    ar.VerificationMethod,
    ar.GPSLocation,
    ar.SuspiciousFlag,
    ar.SelfiePath      AS AttendanceSelfiePath
FROM AttendanceRecord ar
JOIN Student s ON ar.StudentID = s.StudentID
JOIN User u    ON s.StudentID  = u.UserID
WHERE ar.Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY ar.Date DESC, ar.VerificationTime DESC;

-- ============================================================
-- 3. FUNCTIONS
-- ============================================================

DELIMITER $$

CREATE FUNCTION fn_GetAttendancePercentage(
    p_StudentID INT,
    p_StartDate DATE,
    p_EndDate   DATE
) RETURNS DECIMAL(5,2) DETERMINISTIC
BEGIN
    DECLARE total_days   INT DEFAULT 0;
    DECLARE present_days INT DEFAULT 0;

    SELECT COUNT(*) INTO total_days
    FROM AttendanceRecord
    WHERE StudentID = p_StudentID AND Date BETWEEN p_StartDate AND p_EndDate;

    SELECT COUNT(*) INTO present_days
    FROM AttendanceRecord
    WHERE StudentID = p_StudentID AND Date BETWEEN p_StartDate AND p_EndDate
      AND Status IN ('Present','OnLeave');

    IF total_days = 0 THEN RETURN 0.00; END IF;
    RETURN ROUND((present_days / total_days) * 100, 2);
END$$

CREATE FUNCTION fn_GetCurrentRoom(p_StudentID INT)
RETURNS VARCHAR(20) DETERMINISTIC
BEGIN
    DECLARE room_num VARCHAR(20);
    SELECT r.RoomNumber INTO room_num
    FROM RoomAllocation ra JOIN Room r ON ra.RoomID = r.RoomID
    WHERE ra.StudentID = p_StudentID AND ra.IsCurrent = 1 AND ra.Status = 'Active'
    LIMIT 1;
    RETURN IFNULL(room_num, 'Not Assigned');
END$$

CREATE FUNCTION fn_IsInsideGeofence(
    p_Latitude  DECIMAL(10,7),
    p_Longitude DECIMAL(10,7)
) RETURNS TINYINT(1) DETERMINISTIC
BEGIN
    DECLARE geo_lat    DECIMAL(10,7);
    DECLARE geo_lon    DECIMAL(10,7);
    DECLARE geo_radius DECIMAL(10,2);
    DECLARE distance   DECIMAL(10,2);

    SELECT LatitudeCenter, LongitudeCenter, RadiusMeters
    INTO geo_lat, geo_lon, geo_radius
    FROM GeofenceBoundary WHERE IsActive = 1 LIMIT 1;

    IF geo_lat IS NULL THEN RETURN 1; END IF;  -- no boundary = allow

    SET distance = 6371000 * ACOS(
        LEAST(1.0, COS(RADIANS(geo_lat)) * COS(RADIANS(p_Latitude)) *
        COS(RADIANS(p_Longitude) - RADIANS(geo_lon)) +
        SIN(RADIANS(geo_lat)) * SIN(RADIANS(p_Latitude)))
    );
    RETURN IF(distance <= geo_radius, 1, 0);
END$$

DELIMITER ;

-- ============================================================
-- 4. STORED PROCEDURES
-- ============================================================

DELIMITER $$

-- ── Authentication ──────────────────────────────────────────
CREATE PROCEDURE sp_Login(IN p_Email VARCHAR(150))
BEGIN
    SELECT u.UserID, u.Name, u.Email, u.PasswordHash, u.Role, u.IsActive,
           s.StudentID, s.RollNumber, s.Department, s.Semester,
           s.ProfilePhotoPath, s.LastPhotoUpdate, s.PhotoUpdateLocked,
           w.WardenID, w.OfficePhone,
           sec.SecurityID,
           adm.AdminID
    FROM User u
    LEFT JOIN Student             s   ON u.UserID = s.StudentID
    LEFT JOIN Warden              w   ON u.UserID = w.WardenID
    LEFT JOIN SecurityPersonnel   sec ON u.UserID = sec.SecurityID
    LEFT JOIN SystemAdministrator adm ON u.UserID = adm.AdminID
    WHERE u.Email = p_Email AND u.IsActive = 1
    LIMIT 1;
END$$

-- ── Attendance ───────────────────────────────────────────────
CREATE PROCEDURE sp_MarkAttendance(
    IN  p_StudentID  INT,
    IN  p_GPS        VARCHAR(100),
    IN  p_Latitude   DECIMAL(10,7),
    IN  p_Longitude  DECIMAL(10,7),
    IN  p_SelfiePath VARCHAR(255),
    OUT p_Result     VARCHAR(200)
)
BEGIN
    DECLARE v_Inside   TINYINT(1);
    DECLARE v_Existing INT;
    DECLARE v_OnLeave  INT;

    SET v_Inside = fn_IsInsideGeofence(p_Latitude, p_Longitude);

    IF v_Inside = 0 THEN
        SET p_Result = 'ERROR: You are outside the hostel geofence. Cannot mark attendance.';
    ELSE
        SELECT COUNT(*) INTO v_Existing FROM AttendanceRecord
        WHERE StudentID = p_StudentID AND Date = CURDATE() AND Status = 'Present';

        IF v_Existing > 0 THEN
            SET p_Result = 'ERROR: Attendance already marked for today.';
        ELSE
            SELECT COUNT(*) INTO v_OnLeave FROM ExitApplication
            WHERE StudentID = p_StudentID AND IsOnLeave = 1
              AND ApprovalStatus = 'Active' AND DATE(DepartureTime) <= CURDATE();

            IF v_OnLeave > 0 THEN
                INSERT INTO AttendanceRecord
                    (StudentID, Date, VerificationTime, Status, VerificationMethod, GPSLocation, SelfiePath)
                VALUES (p_StudentID, CURDATE(), CURTIME(), 'OnLeave', 'Auto-Leave', p_GPS, p_SelfiePath)
                ON DUPLICATE KEY UPDATE
                    Status = 'OnLeave', VerificationTime = CURTIME(),
                    VerificationMethod = 'Auto-Leave', GPSLocation = p_GPS;
                SET p_Result = 'Attendance marked as OnLeave (active leave).';
            ELSE
                INSERT INTO AttendanceRecord
                    (StudentID, Date, VerificationTime, Status, VerificationMethod, GPSLocation, SelfiePath)
                VALUES (p_StudentID, CURDATE(), CURTIME(), 'Present', 'Selfie+Geofence', p_GPS, p_SelfiePath)
                ON DUPLICATE KEY UPDATE
                    Status = 'Present', VerificationTime = CURTIME(),
                    VerificationMethod = 'Selfie+Geofence', GPSLocation = p_GPS, SelfiePath = p_SelfiePath;
                SET p_Result = 'Attendance marked successfully as Present.';
            END IF;
        END IF;
    END IF;
END$$

-- ── Exit Application ─────────────────────────────────────────
-- Before 5 PM short exit → auto-approved (return by 5 PM)
-- At/after 5 PM OR leave → warden approval required
CREATE PROCEDURE sp_SubmitExitApplication(
    IN  p_StudentID        INT,
    IN  p_Destination      VARCHAR(200),
    IN  p_IsOnLeave        TINYINT(1),
    IN  p_Reason           TEXT,
    IN  p_DepartureTime    DATETIME,
    IN  p_ExpectedReturn   DATETIME,
    OUT p_Result           VARCHAR(200),
    OUT p_AppID            INT
)
BEGIN
    DECLARE v_Hour       INT;
    DECLARE v_Restricted TINYINT(1);
    DECLARE v_Status     VARCHAR(20);
    DECLARE v_ExpReturn  DATETIME;
    DECLARE v_WardenID   INT;

    SET v_Hour = HOUR(p_DepartureTime);
    SET v_Restricted = IF(v_Hour >= 17, 1, 0);  -- 5 PM threshold

    IF p_IsOnLeave = 0 AND v_Restricted = 0 THEN
        -- Before 5 PM short exit: auto-approve, cap return at 17:00
        SET v_Status    = 'Approved';
        SET v_ExpReturn = IFNULL(p_ExpectedReturn,
                          TIMESTAMP(DATE(p_DepartureTime), '17:00:00'));
    ELSE
        SET v_Status    = 'Pending';
        SET v_ExpReturn = p_ExpectedReturn;
    END IF;

    SELECT WardenID INTO v_WardenID FROM Warden LIMIT 1;

    INSERT INTO ExitApplication
        (StudentID, Destination, IsOnLeave, Reason, DepartureTime,
         ExpectedReturnTime, RestrictedTimeFlag, ApprovalStatus)
    VALUES
        (p_StudentID, p_Destination, p_IsOnLeave, p_Reason,
         p_DepartureTime, v_ExpReturn, v_Restricted, v_Status);

    SET p_AppID = LAST_INSERT_ID();

    -- Notify student
    INSERT INTO Notification (UserID, Type, Message) VALUES
        (p_StudentID, 'Exit Application',
         IF(v_Status = 'Approved',
            CONCAT('Exit to ', p_Destination, ' auto-approved. Return before 5:00 PM.'),
            CONCAT('Exit to ', p_Destination, ' submitted. Awaiting warden approval.')));

    -- Notify warden only when approval needed
    IF v_Status = 'Pending' AND v_WardenID IS NOT NULL THEN
        INSERT INTO Notification (UserID, Type, Message) VALUES
            (v_WardenID, 'New Exit Application',
             CONCAT('Student exit to ', p_Destination, '. Approval required.'));
    END IF;

    SET p_Result = IF(v_Status = 'Approved',
        'Auto-approved. Return before 5:00 PM.',
        'Submitted. Waiting for warden approval.');
END$$

-- ── Approve/Reject Exit ──────────────────────────────────────
CREATE PROCEDURE sp_ApproveExit(
    IN  p_ApplicationID INT,
    IN  p_WardenID      INT,
    IN  p_Action        VARCHAR(20),
    IN  p_Remarks       TEXT,
    OUT p_Result        VARCHAR(200)
)
BEGIN
    DECLARE v_StudentID INT;
    DECLARE v_IsOnLeave TINYINT(1);
    DECLARE v_DepDate   DATE;

    SELECT StudentID, IsOnLeave, DATE(DepartureTime)
    INTO v_StudentID, v_IsOnLeave, v_DepDate
    FROM ExitApplication WHERE ApplicationID = p_ApplicationID;

    UPDATE ExitApplication
    SET ApprovalStatus = p_Action, WardenID = p_WardenID, WardenRemarks = p_Remarks
    WHERE ApplicationID = p_ApplicationID;

    -- NOTE: Attendance is NOT auto-marked here.
    -- Students on leave must mark attendance manually during the 8-10 PM window.
    -- The auto-absent event will mark them Absent if they don't mark by 10 PM.

    INSERT INTO Notification (UserID, Type, Message) VALUES
        (v_StudentID, 'Exit Application Update',
         CONCAT('Your exit has been ', p_Action,
                IF(p_Remarks IS NOT NULL AND p_Remarks != '',
                   CONCAT('. Remarks: ', p_Remarks), '.')));

    SET p_Result = CONCAT('Application ', p_Action, ' successfully.');
END$$

-- ── Record Return (Security Guard) ───────────────────────────
CREATE PROCEDURE sp_RecordReturn(
    IN  p_StudentID     INT,
    IN  p_ApplicationID INT,
    OUT p_Result        VARCHAR(200)
)
BEGIN
    DECLARE v_ExpReturn   DATETIME;
    DECLARE v_Now         DATETIME;
    DECLARE v_Late        TINYINT(1);
    DECLARE v_WardenID    INT;
    DECLARE v_Name        VARCHAR(100);
    DECLARE v_Roll        VARCHAR(50);

    SET v_Now = NOW();

    SELECT ExpectedReturnTime INTO v_ExpReturn
    FROM ExitApplication WHERE ApplicationID = p_ApplicationID;

    IF v_ExpReturn IS NULL THEN
        SET v_ExpReturn = TIMESTAMP(DATE(v_Now), '17:00:00');
    END IF;

    SET v_Late = IF(v_Now > v_ExpReturn, 1, 0);

    SELECT u.Name, s.RollNumber INTO v_Name, v_Roll
    FROM User u JOIN Student s ON u.UserID = s.StudentID
    WHERE s.StudentID = p_StudentID;

    IF EXISTS (SELECT 1 FROM EntryExitLog
               WHERE ApplicationID = p_ApplicationID AND StudentID = p_StudentID) THEN
        UPDATE EntryExitLog
        SET ActualReturnTime = v_Now, LateReturnAlert = v_Late, ReturnConfirmedByGeofence = 0
        WHERE ApplicationID = p_ApplicationID AND StudentID = p_StudentID;
    ELSE
        INSERT INTO EntryExitLog
            (ApplicationID, StudentID, ExitTime, ActualReturnTime, LateReturnAlert, ReturnConfirmedByGeofence)
        VALUES (p_ApplicationID, p_StudentID, v_Now, v_Now, v_Late, 0);
    END IF;

    -- Mark application as Returned (not Active)
    UPDATE ExitApplication SET ApprovalStatus = 'Returned'
    WHERE ApplicationID = p_ApplicationID;

    -- NOTE: Attendance is NOT auto-marked on return.
    -- Student must mark attendance manually during the 8-10 PM window.

    -- Always notify the student of their return being recorded
    SELECT WardenID INTO v_WardenID FROM Warden LIMIT 1;

    IF v_Late = 1 THEN
        INSERT INTO Notification (UserID, Type, Message) VALUES
            (p_StudentID, 'Late Return',
             CONCAT('Your return has been recorded. You returned LATE. Expected: ',
                    DATE_FORMAT(v_ExpReturn, '%d %b %H:%i'),
                    '. Actual: ', DATE_FORMAT(v_Now, '%H:%i'), '.'));

        IF v_WardenID IS NOT NULL THEN
            INSERT INTO Notification (UserID, Type, Message) VALUES
                (v_WardenID, '⚠ Late Return Alert',
                 CONCAT('Student ', v_Name, ' (', v_Roll, ') has RETURNED LATE. Expected: ',
                        DATE_FORMAT(v_ExpReturn, '%d %b %H:%i'),
                        ' — Actual: ', DATE_FORMAT(v_Now, '%d %b %H:%i'), '.'));
        END IF;

        SET p_Result = CONCAT('Return recorded. LATE ALERT sent. Expected: ',
            DATE_FORMAT(v_ExpReturn, '%H:%i'), ', Returned: ', DATE_FORMAT(v_Now, '%H:%i'));
    ELSE
        -- On-time return: notify student and warden
        INSERT INTO Notification (UserID, Type, Message) VALUES
            (p_StudentID, 'Return Confirmed',
             CONCAT('Your return has been recorded at ', DATE_FORMAT(v_Now, '%H:%i'),
                    '. Welcome back!'));

        IF v_WardenID IS NOT NULL THEN
            INSERT INTO Notification (UserID, Type, Message) VALUES
                (v_WardenID, 'Student Returned',
                 CONCAT('Student ', v_Name, ' (', v_Roll, ') has returned at ',
                        DATE_FORMAT(v_Now, '%d %b %H:%i'), '.'));
        END IF;

        SET p_Result = 'Return recorded successfully. On time.';
    END IF;
END$$

-- ── Complaint ────────────────────────────────────────────────
CREATE PROCEDURE sp_SubmitComplaint(
    IN  p_StudentID   INT,
    IN  p_Title       VARCHAR(200),
    IN  p_Description TEXT,
    IN  p_Type        VARCHAR(100),
    OUT p_Result      VARCHAR(200)
)
BEGIN
    DECLARE v_WardenID INT;
    SELECT WardenID INTO v_WardenID FROM Warden LIMIT 1;

    INSERT INTO Complaint (StudentID, Title, Description, ComplaintType)
    VALUES (p_StudentID, p_Title, p_Description, p_Type);

    IF v_WardenID IS NOT NULL THEN
        INSERT INTO Notification (UserID, Type, Message)
        VALUES (v_WardenID, 'New Complaint', CONCAT('New complaint: ', p_Title));
    END IF;
    SET p_Result = 'Complaint submitted successfully.';
END$$

CREATE PROCEDURE sp_ResolveComplaint(
    IN  p_ComplaintID INT,
    IN  p_WardenID    INT,
    IN  p_Status      VARCHAR(20),
    IN  p_Remarks     TEXT,
    OUT p_Result      VARCHAR(200)
)
BEGIN
    DECLARE v_StudentID INT;
    SELECT StudentID INTO v_StudentID FROM Complaint WHERE ComplaintID = p_ComplaintID;

    UPDATE Complaint
    SET Status = p_Status, WardenID = p_WardenID, WardenRemarks = p_Remarks,
        ResolvedAt = IF(p_Status IN ('Resolved','Rejected'), NOW(), NULL)
    WHERE ComplaintID = p_ComplaintID;

    INSERT INTO Notification (UserID, Type, Message) VALUES
        (v_StudentID, 'Complaint Update',
         CONCAT('Complaint ', p_Status,
                IF(p_Remarks IS NOT NULL AND p_Remarks != '',
                   CONCAT('. Remarks: ', p_Remarks), '.')));
    SET p_Result = CONCAT('Complaint updated to ', p_Status, '.');
END$$

-- ── Room Allocation ──────────────────────────────────────────
CREATE PROCEDURE sp_AllocateRoom(
    IN  p_StudentID INT,
    IN  p_RoomID    INT,
    IN  p_WardenID  INT,
    OUT p_Result    VARCHAR(200)
)
BEGIN
    DECLARE v_Cap INT; DECLARE v_Occ INT;
    SELECT Capacity, CurrentOccupancy INTO v_Cap, v_Occ FROM Room WHERE RoomID = p_RoomID;

    IF v_Occ >= v_Cap THEN
        SET p_Result = 'ERROR: Room is full.';
    ELSE
        UPDATE RoomAllocation SET IsCurrent = 0, Status = 'Ended', DeallocationDate = NOW()
        WHERE StudentID = p_StudentID AND IsCurrent = 1;

        INSERT INTO RoomAllocation (StudentID, RoomID, AllocationType, AllocationDate, IsCurrent, Status)
        VALUES (p_StudentID, p_RoomID, 'ByWarden', NOW(), 1, 'Active');
        SET p_Result = 'Room allocated successfully.';
    END IF;
END$$

-- ── Student Dashboard ────────────────────────────────────────
CREATE PROCEDURE sp_GetStudentDashboard(IN p_StudentID INT)
BEGIN
    SELECT u.Name, u.Email, u.Phone, s.RollNumber, s.Department,
           s.Semester, s.ProfilePhotoPath, s.LastPhotoUpdate, s.PhotoUpdateLocked
    FROM User u JOIN Student s ON u.UserID = s.StudentID
    WHERE s.StudentID = p_StudentID;

    SELECT Status, VerificationTime FROM AttendanceRecord
    WHERE StudentID = p_StudentID AND Date = CURDATE();

    SELECT Date, Status FROM AttendanceRecord
    WHERE StudentID = p_StudentID AND Date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    ORDER BY Date DESC;

    SELECT r.RoomNumber, r.Capacity, r.CurrentOccupancy
    FROM RoomAllocation ra JOIN Room r ON ra.RoomID = r.RoomID
    WHERE ra.StudentID = p_StudentID AND ra.IsCurrent = 1 LIMIT 1;

    SELECT ApplicationID, Destination, IsOnLeave, ApprovalStatus,
           DepartureTime, ExpectedReturnTime
    FROM ExitApplication
    WHERE StudentID = p_StudentID
      AND ApprovalStatus IN ('Pending','Approved','Active')
    ORDER BY SubmittedAt DESC LIMIT 1;

    SELECT COUNT(*) AS UnreadCount FROM Notification
    WHERE UserID = p_StudentID AND IsRead = 0;

    SELECT fn_GetAttendancePercentage(p_StudentID,
           DATE_SUB(CURDATE(), INTERVAL 30 DAY), CURDATE()) AS AttendancePct;
END$$

-- ── Profile & Password ───────────────────────────────────────
CREATE PROCEDURE sp_ChangePassword(
    IN  p_UserID  INT,
    IN  p_NewHash VARCHAR(255),
    OUT p_Result  VARCHAR(200)
)
BEGIN
    UPDATE User SET PasswordHash = p_NewHash WHERE UserID = p_UserID;
    SET p_Result = 'Password changed successfully.';
END$$

-- ── Photo Lock (Admin/Warden) ────────────────────────────────
CREATE PROCEDURE sp_TogglePhotoLock(
    IN  p_StudentID INT,
    IN  p_Locked    TINYINT(1),
    OUT p_Result    VARCHAR(200)
)
BEGIN
    UPDATE Student SET PhotoUpdateLocked = p_Locked WHERE StudentID = p_StudentID;
    SET p_Result = IF(p_Locked = 1,
        'Profile photo update locked for this student.',
        'Profile photo update unlocked for this student.');
END$$

-- ── Admin: Get All Students ──────────────────────────────────
CREATE PROCEDURE sp_GetAllStudents()
BEGIN
    SELECT u.UserID, u.Name, u.Email, u.Phone, u.IsActive,
           s.StudentID, s.RollNumber, s.Department, s.Semester,
           s.ProfilePhotoPath, s.LastPhotoUpdate, s.PhotoUpdateLocked,
           fn_GetCurrentRoom(s.StudentID) AS CurrentRoom
    FROM User u
    JOIN Student s ON u.UserID = s.StudentID
    ORDER BY s.RollNumber;
END$$

-- ── Admin: Add Student (temp password namal123) ──────────────
CREATE PROCEDURE sp_AddStudent(
    IN  p_Name         VARCHAR(100),
    IN  p_Email        VARCHAR(150),
    IN  p_PasswordHash VARCHAR(255),
    IN  p_Phone        VARCHAR(20),
    IN  p_RollNumber   VARCHAR(50),
    IN  p_Department   VARCHAR(100),
    IN  p_Semester     INT,
    IN  p_AdminID      INT,
    OUT p_Result       VARCHAR(200)
)
BEGIN
    DECLARE v_UserID INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        SET p_Result = 'ERROR: Email or Roll Number already exists.';

    INSERT INTO User (Name, Email, PasswordHash, Phone, Role)
    VALUES (p_Name, p_Email, p_PasswordHash, p_Phone, 'Student');
    SET v_UserID = LAST_INSERT_ID();

    INSERT INTO Student (StudentID, RollNumber, Department, Semester)
    VALUES (v_UserID, p_RollNumber, p_Department, p_Semester);

    INSERT INTO SystemChangeLog (AdminID, Action, EntityName, RecordID, Description)
    VALUES (p_AdminID, 'CREATE', 'Student', v_UserID, CONCAT('Added student: ', p_Name));

    SET p_Result = CONCAT('Student added. ID: ', v_UserID, '. Temp password: namal123');
END$$

-- ── Admin: Update Student ────────────────────────────────────
CREATE PROCEDURE sp_UpdateStudent(
    IN  p_StudentID  INT,
    IN  p_Name       VARCHAR(100),
    IN  p_Email      VARCHAR(150),
    IN  p_Phone      VARCHAR(20),
    IN  p_RollNumber VARCHAR(50),
    IN  p_Department VARCHAR(100),
    IN  p_Semester   INT,
    IN  p_AdminID    INT,
    OUT p_Result     VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        SET p_Result = 'ERROR: Email or Roll Number conflict.';

    UPDATE User    SET Name = p_Name, Email = p_Email, Phone = p_Phone WHERE UserID    = p_StudentID;
    UPDATE Student SET RollNumber = p_RollNumber, Department = p_Department, Semester = p_Semester
    WHERE StudentID = p_StudentID;

    INSERT INTO SystemChangeLog (AdminID, Action, EntityName, RecordID, Description)
    VALUES (p_AdminID, 'UPDATE', 'Student', p_StudentID, CONCAT('Updated: ', p_Name));
    SET p_Result = 'Student updated successfully.';
END$$

-- ── Admin: Hard Delete Student ───────────────────────────────
CREATE PROCEDURE sp_DeleteStudent(
    IN  p_StudentID INT,
    IN  p_AdminID   INT,
    OUT p_Result    VARCHAR(200)
)
BEGIN
    DECLARE v_Name VARCHAR(100);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        SET p_Result = 'ERROR: Cannot delete – check for linked records.';

    SELECT Name INTO v_Name FROM User WHERE UserID = p_StudentID;

    DELETE FROM EntryExitLog       WHERE StudentID = p_StudentID;
    DELETE FROM RoomAllocation     WHERE StudentID = p_StudentID;
    DELETE FROM AttendanceRecord   WHERE StudentID = p_StudentID;
    DELETE FROM ExitApplication    WHERE StudentID = p_StudentID;
    DELETE FROM Complaint          WHERE StudentID = p_StudentID;
    DELETE FROM DeviceRegistration WHERE StudentID = p_StudentID;
    DELETE FROM Notification       WHERE UserID    = p_StudentID;
    DELETE FROM Student            WHERE StudentID = p_StudentID;
    DELETE FROM User               WHERE UserID    = p_StudentID;

    INSERT INTO SystemChangeLog (AdminID, Action, EntityName, RecordID, Description)
    VALUES (p_AdminID, 'DELETE', 'Student', p_StudentID,
            CONCAT('Hard deleted: ', IFNULL(v_Name, p_StudentID)));
    SET p_Result = CONCAT('Student "', IFNULL(v_Name,''), '" permanently deleted.');
END$$

-- ── Admin: Reset Student Password ───────────────────────────
CREATE PROCEDURE sp_AdminChangeStudentPassword(
    IN  p_StudentID INT,
    IN  p_NewHash   VARCHAR(255),
    IN  p_AdminID   INT,
    OUT p_Result    VARCHAR(200)
)
BEGIN
    UPDATE User SET PasswordHash = p_NewHash WHERE UserID = p_StudentID;
    INSERT INTO SystemChangeLog (AdminID, Action, EntityName, RecordID, Description)
    VALUES (p_AdminID, 'UPDATE', 'Student', p_StudentID, 'Admin reset student password');
    SET p_Result = 'Student password updated successfully.';
END$$

-- ── Admin: Warden Password ───────────────────────────────────
CREATE PROCEDURE sp_UpdateWardenPassword(
    IN  p_WardenID INT,
    IN  p_NewHash  VARCHAR(255),
    IN  p_AdminID  INT,
    OUT p_Result   VARCHAR(200)
)
BEGIN
    UPDATE User SET PasswordHash = p_NewHash WHERE UserID = p_WardenID;
    INSERT INTO SystemChangeLog (AdminID, Action, EntityName, RecordID, Description)
    VALUES (p_AdminID, 'UPDATE', 'Warden', p_WardenID, 'Warden password updated by admin');
    SET p_Result = 'Warden password updated.';
END$$

-- ── Geofence ─────────────────────────────────────────────────
CREATE PROCEDURE sp_GetGeofenceConfig()
BEGIN
    SELECT GeofenceID, BoundaryName, LatitudeCenter, LongitudeCenter, RadiusMeters, IsActive
    FROM GeofenceBoundary ORDER BY GeofenceID DESC LIMIT 1;
END$$

CREATE PROCEDURE sp_UpdateGeofenceConfig(
    IN  p_GeofenceID   INT,
    IN  p_BoundaryName VARCHAR(100),
    IN  p_LatCenter    DECIMAL(10,7),
    IN  p_LonCenter    DECIMAL(10,7),
    IN  p_Radius       DECIMAL(10,2),
    IN  p_AdminID      INT,
    OUT p_Result       VARCHAR(200)
)
BEGIN
    IF p_GeofenceID IS NULL OR p_GeofenceID = 0 THEN
        INSERT INTO GeofenceBoundary (BoundaryName, LatitudeCenter, LongitudeCenter, RadiusMeters, IsActive)
        VALUES (p_BoundaryName, p_LatCenter, p_LonCenter, p_Radius, 1);
    ELSE
        UPDATE GeofenceBoundary
        SET BoundaryName = p_BoundaryName, LatitudeCenter = p_LatCenter,
            LongitudeCenter = p_LonCenter, RadiusMeters = p_Radius
        WHERE GeofenceID = p_GeofenceID;
    END IF;

    INSERT INTO SystemChangeLog (AdminID, Action, EntityName, RecordID, Description)
    VALUES (p_AdminID, 'UPDATE', 'GeofenceBoundary', IFNULL(p_GeofenceID, 0),
            CONCAT('Geofence updated: radius=', p_Radius, 'm'));
    SET p_Result = 'Geofence configuration updated.';
END$$

DELIMITER ;

-- ============================================================
-- 5. TRIGGERS
-- ============================================================

DELIMITER $$

-- Update room occupancy when allocation is created
CREATE TRIGGER trg_RoomOccupancy_Insert
AFTER INSERT ON RoomAllocation
FOR EACH ROW
BEGIN
    IF NEW.IsCurrent = 1 AND NEW.Status = 'Active' THEN
        UPDATE Room SET CurrentOccupancy = CurrentOccupancy + 1 WHERE RoomID = NEW.RoomID;
        UPDATE Room SET RoomStatus = IF(CurrentOccupancy >= Capacity, 'Full', 'Available')
        WHERE RoomID = NEW.RoomID;
    END IF;
END$$

-- Update room occupancy when allocation is ended
CREATE TRIGGER trg_RoomOccupancy_Update
AFTER UPDATE ON RoomAllocation
FOR EACH ROW
BEGIN
    IF OLD.IsCurrent = 1 AND NEW.IsCurrent = 0 THEN
        UPDATE Room SET CurrentOccupancy = GREATEST(0, CurrentOccupancy - 1) WHERE RoomID = OLD.RoomID;
        UPDATE Room SET RoomStatus = IF(CurrentOccupancy >= Capacity, 'Full', 'Available')
        WHERE RoomID = OLD.RoomID;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- 6. EVENTS
-- ============================================================

SET GLOBAL event_scheduler = ON;

-- Auto-mark absent students at 10 PM
DELIMITER $$
CREATE EVENT IF NOT EXISTS evt_AutoMarkAbsent
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURDATE(), '22:00:00'))
DO
BEGIN
    INSERT INTO AttendanceRecord (StudentID, Date, Status, VerificationMethod)
    SELECT s.StudentID, CURDATE(), 'Absent', 'AutoAbsent'
    FROM Student s JOIN User u ON s.StudentID = u.UserID
    WHERE u.IsActive = 1
      AND NOT EXISTS (
          SELECT 1 FROM AttendanceRecord ar
          WHERE ar.StudentID = s.StudentID AND ar.Date = CURDATE())
      AND NOT EXISTS (
          SELECT 1 FROM ExitApplication ea
          WHERE ea.StudentID = s.StudentID AND ea.IsOnLeave = 1
            AND ea.ApprovalStatus IN ('Approved','Active')
            AND DATE(ea.DepartureTime) <= CURDATE());
END$$
DELIMITER ;

-- Purge attendance selfie paths older than 30 days (keeps the record, clears the file path)
DELIMITER $$
CREATE EVENT IF NOT EXISTS evt_PurgeSelfies
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURDATE(), '03:00:00')
DO
BEGIN
    UPDATE AttendanceRecord
    SET SelfiePath = NULL
    WHERE Date < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      AND SelfiePath IS NOT NULL;
END$$
DELIMITER ;
