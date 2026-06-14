-- ============================================================
-- Smart Hostel Management System (SHMS) – Girls Hostel
-- dbDML.sql  –  Sample / Seed Data
-- Run AFTER dbDDL.sql
-- ============================================================

USE shms;

-- ============================================================
-- 1. GEOFENCE BOUNDARY (Namal University campus approx)
-- ============================================================
INSERT INTO GeofenceBoundary (BoundaryName, LatitudeCenter, LongitudeCenter, RadiusMeters, IsActive)
VALUES ('Namal University Girls Hostel Premises', 32.4780000, 71.9680000, 300.00, 1);

-- ============================================================
-- 2. ROOMS (10 rooms, capacity 2 each – Girls Hostel)
-- ============================================================
INSERT INTO Room (RoomNumber, Capacity, CurrentOccupancy, RoomStatus) VALUES
('G-101', 2, 0, 'Available'),
('G-102', 2, 0, 'Available'),
('G-103', 2, 0, 'Available'),
('G-104', 2, 0, 'Available'),
('G-105', 2, 0, 'Available'),
('G-201', 2, 0, 'Available'),
('G-202', 2, 0, 'Available'),
('G-203', 2, 0, 'Available'),
('G-204', 2, 0, 'Available'),
('G-205', 2, 0, 'Available');

-- ============================================================
-- 3. ADMIN USER  (Password: admin#1219@)
-- ============================================================
INSERT INTO User (Name, Email, PasswordHash, Phone, Role) VALUES
('System Administrator', 'admin@namal.edu.pk',
 'PLACEHOLDER', '0300-0000000', 'Admin');

INSERT INTO SystemAdministrator (AdminID) VALUES (LAST_INSERT_ID());

-- ============================================================
-- 4. WARDEN USER  (Password: nidanida12)
-- ============================================================
INSERT INTO User (Name, Email, PasswordHash, Phone, Role) VALUES
('Nida Sultan', 'nida.sultan@namal.edu.pk',
 'PLACEHOLDER', '0300-1111111', 'Warden');

INSERT INTO Warden (WardenID, OfficePhone, HireDate) VALUES (LAST_INSERT_ID(), '0459-000111', '2022-01-15');

-- ============================================================
-- 5. SECURITY PERSONNEL (no login – opened directly via button)
-- ============================================================
INSERT INTO User (Name, Email, PasswordHash, Phone, Role) VALUES
('Security Guard', 'security@namal.edu.pk',
 'PLACEHOLDER', '0300-2222222', 'Security');

INSERT INTO SecurityPersonnel (SecurityID) VALUES (LAST_INSERT_ID());

-- ============================================================
-- 6. STUDENTS – 15 girls  (All passwords: 12121212)
-- ============================================================
INSERT INTO User (Name, Email, PasswordHash, Phone, Role) VALUES
('Ayesha Khan',    'bscs24f01@namal.edu.pk', 'PLACEHOLDER', '0300-1010101', 'Student'),
('Sara Malik',     'bscs24f02@namal.edu.pk', 'PLACEHOLDER', '0300-2020202', 'Student'),
('Fatima Zafar',   'bscs24f03@namal.edu.pk', 'PLACEHOLDER', '0300-3030303', 'Student'),
('Zainab Bibi',    'bscs24f04@namal.edu.pk', 'PLACEHOLDER', '0300-4040404', 'Student'),
('Mariam Tariq',   'bscs24f05@namal.edu.pk', 'PLACEHOLDER', '0300-5050505', 'Student'),
('Hira Shahzad',   'bscs24f06@namal.edu.pk', 'PLACEHOLDER', '0300-6060606', 'Student'),
('Nida Aslam',     'bscs24f07@namal.edu.pk', 'PLACEHOLDER', '0300-7070707', 'Student'),
('Sana Iqbal',     'bscs24f08@namal.edu.pk', 'PLACEHOLDER', '0300-8080808', 'Student'),
('Amna Rashid',    'bscs24f09@namal.edu.pk', 'PLACEHOLDER', '0300-9090909', 'Student'),
('Rabia Noor',     'bscs24f10@namal.edu.pk', 'PLACEHOLDER', '0300-1011011', 'Student'),
('Iqra Butt',      'bscs24f11@namal.edu.pk', 'PLACEHOLDER', '0300-1121212', 'Student'),
('Mahnoor Ahmed',  'bscs24f12@namal.edu.pk', 'PLACEHOLDER', '0300-1231313', 'Student'),
('Khadija Sultan', 'bscs24f13@namal.edu.pk', 'PLACEHOLDER', '0300-1341414', 'Student'),
('Mehwish Ali',    'bscs24f14@namal.edu.pk', 'PLACEHOLDER', '0300-1451515', 'Student'),
('Bushra Nawaz',   'bscs24f15@namal.edu.pk', 'PLACEHOLDER', '0300-1561616', 'Student');

-- Student sub-records (Admin=1, Warden=2, Security=3, students start at 4)
INSERT INTO Student (StudentID, RollNumber, Department, Semester) VALUES
(4,  'NUM-BSCS-2024-01', 'Computer Science', 2),
(5,  'NUM-BSCS-2024-02', 'Computer Science', 2),
(6,  'NUM-BSCS-2024-03', 'Computer Science', 2),
(7,  'NUM-BSCS-2024-04', 'Computer Science', 2),
(8,  'NUM-BSCS-2024-05', 'Computer Science', 2),
(9,  'NUM-BSCS-2024-06', 'Computer Science', 2),
(10, 'NUM-BSCS-2024-07', 'Computer Science', 2),
(11, 'NUM-BSCS-2024-08', 'Computer Science', 2),
(12, 'NUM-BSCS-2024-09', 'Computer Science', 2),
(13, 'NUM-BSCS-2024-10', 'Computer Science', 2),
(14, 'NUM-BSCS-2024-11', 'Computer Science', 2),
(15, 'NUM-BSCS-2024-12', 'Computer Science', 2),
(16, 'NUM-BSCS-2024-13', 'Computer Science', 2),
(17, 'NUM-BSCS-2024-14', 'Computer Science', 2),
(18, 'NUM-BSCS-2024-15', 'Computer Science', 2);

-- ============================================================
-- 7. ROOM ALLOCATIONS (pair girls two per room)
-- ============================================================
INSERT INTO RoomAllocation (StudentID, RoomID, AllocationType, AllocationDate, IsCurrent, Status) VALUES
(4,  1, 'ByWarden', NOW(), 1, 'Active'),
(5,  1, 'ByWarden', NOW(), 1, 'Active'),
(6,  2, 'ByWarden', NOW(), 1, 'Active'),
(7,  2, 'ByWarden', NOW(), 1, 'Active'),
(8,  3, 'ByWarden', NOW(), 1, 'Active'),
(9,  3, 'ByWarden', NOW(), 1, 'Active'),
(10, 4, 'ByWarden', NOW(), 1, 'Active'),
(11, 4, 'ByWarden', NOW(), 1, 'Active'),
(12, 5, 'ByWarden', NOW(), 1, 'Active'),
(13, 5, 'ByWarden', NOW(), 1, 'Active'),
(14, 6, 'ByWarden', NOW(), 1, 'Active'),
(15, 6, 'ByWarden', NOW(), 1, 'Active'),
(16, 7, 'ByWarden', NOW(), 1, 'Active'),
(17, 7, 'ByWarden', NOW(), 1, 'Active'),
(18, 8, 'ByWarden', NOW(), 1, 'Active');

-- Fix occupancy counts (triggers don't fire on bulk inserts)
UPDATE Room SET CurrentOccupancy = 2, RoomStatus = 'Full'      WHERE RoomID IN (1,2,3,4,5,6,7,8);
UPDATE Room SET CurrentOccupancy = 0, RoomStatus = 'Available' WHERE RoomID IN (9,10);

-- ============================================================
-- 8. SAMPLE NOTIFICATIONS
-- ============================================================
INSERT INTO Notification (UserID, Type, Message, IsRead) VALUES
(4, 'Welcome', 'Welcome to Smart Hostel Management System, Ayesha Khan!', 0),
(5, 'Welcome', 'Welcome to Smart Hostel Management System, Sara Malik!', 0),
(2, 'System',  'SHMS Girls Hostel is now active. All students enrolled.', 0);

-- ============================================================
-- 9. SAMPLE COMPLAINTS
-- ============================================================
INSERT INTO Complaint (StudentID, Title, Description, ComplaintType, Status) VALUES
(4,  'Water Shortage',  'No water in bathroom since morning.',          'Maintenance', 'Pending'),
(6,  'Wi-Fi Issues',    'Internet very slow in room G-102.',            'Facility',    'Pending'),
(8,  'Broken Fan',      'Ceiling fan in G-103 not working.',            'Maintenance', 'In Progress');

-- ============================================================
-- 10. SAMPLE EXIT APPLICATIONS
-- ============================================================
INSERT INTO ExitApplication (StudentID, Destination, IsOnLeave, Reason, DepartureTime, ExpectedReturnTime, RestrictedTimeFlag, ApprovalStatus) VALUES
(4, 'Home - Lahore', 1, 'Family event', NOW(), DATE_ADD(NOW(), INTERVAL 2 DAY), 0, 'Pending');

-- ============================================================
-- NOTE ON PASSWORDS
-- Visit http://127.0.0.1:5000/init-passwords once after starting app
-- to replace all PLACEHOLDER hashes with proper bcrypt hashes.
-- ============================================================
