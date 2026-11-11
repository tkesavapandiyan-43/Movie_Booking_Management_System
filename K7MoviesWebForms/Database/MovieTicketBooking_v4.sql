/* =====================================================================
   MovieTicketBookingDB - VERSION 4 (complete rebuild, movies from the poster folder)
   SQL Server Express (SQLEXPRESS). Run in SSMS: File > Open > Execute.

   WARNING: this DROPS and recreates MovieTicketBookingDB. All data is lost.
   Use it for the new project. For an old database, back it up first.

   Accounts created:
     Admin          Kesavan / Kesavan@43
     Customer       demo / User@123
     Theatre owner  pvr_owner / Owner@123   (PVR Cinemas, Madurai)
     Theatre owner  inox_owner / Owner@123  (INOX Galaxy, Virudhunagar)

   Rules in this version:
   - Seats: 10 rows (A-J) x 10 seats. Price per row:
       rows A-B = 180, C-D = 190, E-F = 200, G-H = 210, I-J = 220.
   - Shows: slots per day, per theatre
       1: 09:00-12:15   2: 12:30-15:45   3: 16:00-19:15
       4: 19:30-22:30   5: 22:45-01:45 (next day)
     Monday-Friday = 4 shows, Saturday and Sunday = 5 shows.
   - Booking can be cancelled or changed (cancel seats / add seats) only
     before the show starts. Refunds are recorded as 'Refunded' payments.
   - Revenue = Success payments minus Refunded payments.
   - Bookable movies (43): release on or before 31 Oct 2026, status Open.
   - Movies released after 31 Oct 2026 are Closed (Coming soon).
   ===================================================================== */

USE master;
GO
IF DB_ID(N'MovieTicketBookingDB') IS NOT NULL
BEGIN
    ALTER DATABASE MovieTicketBookingDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MovieTicketBookingDB;
END;
GO
CREATE DATABASE MovieTicketBookingDB;
GO
USE MovieTicketBookingDB;
GO

/* ---------------------------------------------------------------- TABLES */

CREATE TABLE dbo.Theatres
(
    TheatreID   INT IDENTITY(1,1) CONSTRAINT PK_Theatres PRIMARY KEY,
    TheatreName NVARCHAR(120) NOT NULL,
    Location    NVARCHAR(200) NOT NULL,
    OwnerName   NVARCHAR(100) NOT NULL,
    TotalSeats  INT NOT NULL CONSTRAINT DF_Theatres_TotalSeats DEFAULT 0
                CONSTRAINT CK_Theatres_TotalSeats CHECK (TotalSeats BETWEEN 0 AND 1000),
    IsActive    BIT NOT NULL CONSTRAINT DF_Theatres_IsActive DEFAULT 1
);

CREATE TABLE dbo.Users
(
    UserID       INT IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    FullName     NVARCHAR(100) NOT NULL,
    Username     NVARCHAR(50)  NOT NULL CONSTRAINT UQ_Users_Username UNIQUE,
    Email        NVARCHAR(150) NOT NULL CONSTRAINT UQ_Users_Email UNIQUE
                 CONSTRAINT CK_Users_Email CHECK (Email LIKE N'%_@_%._%'),
    Mobile       NVARCHAR(15)  NULL
                 CONSTRAINT CK_Users_Mobile CHECK (Mobile IS NULL OR (LEN(Mobile) = 10 AND Mobile NOT LIKE N'%[^0-9]%')),
    PasswordHash NVARCHAR(255) NOT NULL,
    Role         NVARCHAR(20)  NOT NULL CONSTRAINT DF_Users_Role DEFAULT N'User'
                 CONSTRAINT CK_Users_Role CHECK (Role IN (N'User', N'Admin', N'TheatreOwner')),
    TheatreID    INT NULL CONSTRAINT FK_Users_Theatres REFERENCES dbo.Theatres(TheatreID),
    CONSTRAINT CK_Users_OwnerTheatre CHECK (Role <> N'TheatreOwner' OR TheatreID IS NOT NULL)
);

CREATE TABLE dbo.Movies
(
    MovieID         INT IDENTITY(1,1) CONSTRAINT PK_Movies PRIMARY KEY,
    Title           NVARCHAR(150) NOT NULL,
    Genre           NVARCHAR(80)  NULL,
    Language        NVARCHAR(50)  NULL,
    DurationMinutes INT NOT NULL CONSTRAINT DF_Movies_Duration DEFAULT 120
                    CONSTRAINT CK_Movies_Duration CHECK (DurationMinutes BETWEEN 1 AND 600),
    ReleaseDate     DATE NULL,
    Rating          DECIMAL(3,1) NULL CONSTRAINT CK_Movies_Rating CHECK (Rating IS NULL OR Rating BETWEEN 0 AND 10),
    Description     NVARCHAR(MAX) NULL,
    PosterPath      NVARCHAR(500) NULL,
    IsActive        BIT NOT NULL CONSTRAINT DF_Movies_IsActive DEFAULT 1,
    BookingStatus   NVARCHAR(20) NOT NULL CONSTRAINT DF_Movies_BookingStatus DEFAULT N'Open'
                    CONSTRAINT CK_Movies_BookingStatus CHECK (BookingStatus IN (N'Open', N'Closed'))
);

CREATE TABLE dbo.Seats
(
    SeatID     INT IDENTITY(1,1) CONSTRAINT PK_Seats PRIMARY KEY,
    TheatreID  INT NOT NULL CONSTRAINT FK_Seats_Theatres REFERENCES dbo.Theatres(TheatreID) ON DELETE CASCADE,
    RowName    NVARCHAR(5) NOT NULL,
    SeatNumber INT NOT NULL CONSTRAINT CK_Seats_Number CHECK (SeatNumber > 0),
    Price      DECIMAL(10,2) NOT NULL CONSTRAINT CK_Seats_Price CHECK (Price > 0),
    CONSTRAINT UQ_Seats UNIQUE (TheatreID, RowName, SeatNumber)
);

CREATE TABLE dbo.Shows
(
    ShowID      INT IDENTITY(1,1) CONSTRAINT PK_Shows PRIMARY KEY,
    MovieID     INT NOT NULL CONSTRAINT FK_Shows_Movies REFERENCES dbo.Movies(MovieID),
    TheatreID   INT NOT NULL CONSTRAINT FK_Shows_Theatres REFERENCES dbo.Theatres(TheatreID),
    ShowDate    DATE NOT NULL,
    ShowTime    TIME(0) NOT NULL,
    ShowEndTime TIME(0) NOT NULL,
    SlotNumber  TINYINT NOT NULL CONSTRAINT CK_Shows_Slot CHECK (SlotNumber BETWEEN 1 AND 5),
    CONSTRAINT UQ_Shows_Slot UNIQUE (TheatreID, ShowDate, SlotNumber)
);

CREATE TABLE dbo.Bookings
(
    BookingID     INT IDENTITY(1,1) CONSTRAINT PK_Bookings PRIMARY KEY,
    UserID        INT NOT NULL CONSTRAINT FK_Bookings_Users REFERENCES dbo.Users(UserID),
    ShowID        INT NOT NULL CONSTRAINT FK_Bookings_Shows REFERENCES dbo.Shows(ShowID),
    BookingDate   DATETIME NOT NULL CONSTRAINT DF_Bookings_Date DEFAULT GETDATE(),
    TotalAmount   DECIMAL(10,2) NOT NULL CONSTRAINT CK_Bookings_Amount CHECK (TotalAmount >= 0),
    BookingStatus NVARCHAR(20) NOT NULL CONSTRAINT DF_Bookings_Status DEFAULT N'Confirmed'
                  CONSTRAINT CK_Bookings_Status CHECK (BookingStatus IN (N'Confirmed', N'Cancelled'))
);

CREATE TABLE dbo.BookingSeats
(
    BookingSeatID INT IDENTITY(1,1) CONSTRAINT PK_BookingSeats PRIMARY KEY,
    BookingID     INT NOT NULL CONSTRAINT FK_BookingSeats_Bookings REFERENCES dbo.Bookings(BookingID) ON DELETE CASCADE,
    SeatID        INT NOT NULL CONSTRAINT FK_BookingSeats_Seats REFERENCES dbo.Seats(SeatID)
);

CREATE TABLE dbo.Payments
(
    PaymentID            INT IDENTITY(1,1) CONSTRAINT PK_Payments PRIMARY KEY,
    BookingID            INT NOT NULL CONSTRAINT FK_Payments_Bookings REFERENCES dbo.Bookings(BookingID) ON DELETE CASCADE,
    PaymentMethod        NVARCHAR(30) NOT NULL
                         CONSTRAINT CK_Payments_Method CHECK (PaymentMethod IN (N'UPI', N'Credit Card', N'Debit Card', N'Net Banking')),
    TransactionReference NVARCHAR(50) NULL,
    Amount               DECIMAL(10,2) NOT NULL CONSTRAINT CK_Payments_Amount CHECK (Amount >= 0),
    PaymentDate          DATETIME NOT NULL CONSTRAINT DF_Payments_Date DEFAULT GETDATE(),
    PaymentStatus        NVARCHAR(20) NOT NULL CONSTRAINT DF_Payments_Status DEFAULT N'Success'
                         CONSTRAINT CK_Payments_Status CHECK (PaymentStatus IN (N'Success', N'Failed', N'Refunded'))
);
GO

/* ---------------------------------------------------------------- INDEXES */
CREATE INDEX IX_Shows_Movie        ON dbo.Shows(MovieID);
CREATE INDEX IX_Shows_Date         ON dbo.Shows(ShowDate, ShowTime);
CREATE INDEX IX_Bookings_Show      ON dbo.Bookings(ShowID, BookingStatus);
CREATE INDEX IX_Bookings_User      ON dbo.Bookings(UserID, BookingDate);
CREATE INDEX IX_BookingSeats_Book  ON dbo.BookingSeats(BookingID);
CREATE INDEX IX_BookingSeats_Seat  ON dbo.BookingSeats(SeatID);
CREATE INDEX IX_Payments_Booking   ON dbo.Payments(BookingID);
CREATE INDEX IX_Payments_Date      ON dbo.Payments(PaymentDate);
GO

/* ------------------------------------------- DOUBLE-BOOKING GUARD (trigger) */
CREATE TRIGGER dbo.TR_BookingSeats_Guard ON dbo.BookingSeats
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Bookings AS nb ON nb.BookingID = i.BookingID
        INNER JOIN dbo.BookingSeats AS bs ON bs.SeatID = i.SeatID AND bs.BookingSeatID <> i.BookingSeatID
        INNER JOIN dbo.Bookings AS ob ON ob.BookingID = bs.BookingID
        WHERE nb.BookingStatus <> N'Cancelled' AND ob.BookingStatus <> N'Cancelled' AND nb.ShowID = ob.ShowID)
    BEGIN
        RAISERROR('One or more selected seats are already booked for this show.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.Bookings AS b ON b.BookingID = i.BookingID
        INNER JOIN dbo.Shows AS s ON s.ShowID = b.ShowID
        INNER JOIN dbo.Seats AS se ON se.SeatID = i.SeatID
        WHERE se.TheatreID <> s.TheatreID)
    BEGIN
        RAISERROR('Seat does not belong to the theatre of this show.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

/* ---------------------------------------------------------- SAMPLE DATA */

INSERT INTO dbo.Theatres (TheatreName, Location, OwnerName, IsActive) VALUES
    (N'PVR Cinemas',  N'Madurai',      N'Ramesh Kumar', 1),
    (N'INOX Galaxy',  N'Virudhunagar', N'Priya Devi',   1);

-- 10 rows (A-J) x 10 seats. Price by row pair: A-B 180, C-D 190, E-F 200, G-H 210, I-J 220
DECLARE @t INT, @r INT, @n INT;
DECLARE tc CURSOR LOCAL FAST_FORWARD FOR SELECT TheatreID FROM dbo.Theatres;
OPEN tc;
FETCH NEXT FROM tc INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @r = 0;
    WHILE @r < 10
    BEGIN
        SET @n = 1;
        WHILE @n <= 10
        BEGIN
            INSERT INTO dbo.Seats (TheatreID, RowName, SeatNumber, Price)
            VALUES (@t, CHAR(65 + @r), @n, 180 + 10 * (@r / 2));
            SET @n = @n + 1;
        END;
        SET @r = @r + 1;
    END;
    UPDATE dbo.Theatres SET TotalSeats = 100 WHERE TheatreID = @t;
    FETCH NEXT FROM tc INTO @t;
END;
CLOSE tc;
DEALLOCATE tc;
GO

INSERT INTO dbo.Users (FullName, Username, Email, Mobile, PasswordHash, Role, TheatreID) VALUES
    (N'Kesavan',       N'Kesavan',    N'kesavan@cinebook.com', N'9999999999', N'16b202bb1baaf71cf4988303db6d0462941751c59c88d0688ba66f7f21a77846', N'Admin', NULL),
    (N'Demo User',     N'demo',       N'user@cinebook.com',    N'8888888888', N'3e7c19576488862816f13b512cacf3e4ba97dd97243ea0bd6a2ad1642d86ba72',  N'User',  NULL),
    (N'Ramesh Kumar',  N'pvr_owner',  N'pvr_owner@owner.cinebook.com',  NULL, N'553feacf899a72916b2b50e4c95f587a06d6d1b8b4e6b433beb5fea315d0acb0', N'TheatreOwner',
        (SELECT TheatreID FROM dbo.Theatres WHERE TheatreName = N'PVR Cinemas')),
    (N'Priya Devi',    N'inox_owner', N'inox_owner@owner.cinebook.com', NULL, N'553feacf899a72916b2b50e4c95f587a06d6d1b8b4e6b433beb5fea315d0acb0', N'TheatreOwner',
        (SELECT TheatreID FROM dbo.Theatres WHERE TheatreName = N'INOX Galaxy'));
GO

INSERT INTO dbo.Movies (Title, Genre, Language, DurationMinutes, ReleaseDate, Rating, Description, PosterPath, IsActive, BookingStatus) VALUES
    (N'Aasai', N'Romance', N'Tamil', 120, '2026-11-06', NULL, N'Kathir and Divya Bharti.', N'/posters/aasai.jpg', 1, N'Open'),
    (N'Anbil Avan', N'Romance', N'Tamil', 120, '2026-10-02', NULL, N'', N'/posters/anbil.jpg', 1, N'Open'),
    (N'Black Gold', N'Drama', N'Tamil', 120, '2026-07-17', NULL, N'', N'/posters/black.jpg', 1, N'Open'),
    (N'Con City', N'Drama', N'Tamil', 120, '2026-06-26', NULL, N'', N'/posters/city.jpg', 1, N'Open'),
    (N'Drones', N'Action, Thriller', N'Tamil', 120, '2026-10-16', NULL, N'', N'/posters/drones.jpg', 1, N'Open'),
    (N'Habeebi', N'Drama', N'Tamil', 120, '2026-06-12', NULL, N'', N'/posters/ha.jpg', 1, N'Open'),
    (N'Idhayam Murali', N'Romance, Drama', N'Tamil', 120, '2026-07-10', NULL, N'An emotional story with strong music, starring Atharvaa Murali.', N'/posters/ida.jpg', 1, N'Open'),
    (N'Jailer 2', N'Action, Comedy', N'Tamil', 120, '2026-10-15', NULL, N'Rajinikanth returns in Nelson Dilipkumar''s sequel.', N'/posters/jailer2.jpg', 1, N'Open'),
    (N'Jana Nayagan', N'Action', N'Tamil', 120, '2026-07-23', NULL, N'Vijay''s farewell film, co-starring Pooja Hegde, Bobby Deol and Mamitha Baiju.', N'/posters/jana.jpg', 1, N'Open'),
    (N'Karuppu', N'Action, Drama, Fantasy', N'Tamil', 150, '2026-05-15', 6.6, N'A lawyer is possessed by a guardian deity and battles a corrupt legal system.', N'/posters/karrupu.jpg', 1, N'Open'),
    (N'Appa Kutty', N'Drama', N'Tamil', 120, '2026-11-06', NULL, N'Vijay Antony.', N'/posters/kutty.jpg', 1, N'Open'),
    (N'Lakshmikanthan Kolai Vazhakku', N'Drama', N'Tamil', 120, '2026-06-26', NULL, N'', N'/posters/lp.jpg', 1, N'Open'),
    (N'Maaruvesham', N'Drama', N'Tamil', 120, '2026-10-23', NULL, N'', N'/posters/maru.jpg', 1, N'Open'),
    (N'Mookuthi Amman 2', N'Comedy, Fantasy', N'Tamil', 120, '2026-11-06', NULL, N'Nayanthara returns.', N'/posters/mook.jpg', 1, N'Open'),
    (N'Mudharkanal', N'Drama', N'Tamil', 120, '2026-07-10', NULL, N'', N'/posters/mud.jpg', 1, N'Open'),
    (N'Ranabaali', N'Action', N'Tamil', 120, '2026-10-16', NULL, N'', N'/posters/ranabaali.jpg', 1, N'Open'),
    (N'Sardar 2', N'Action, Thriller', N'Tamil', 120, '2026-09-10', NULL, N'', N'/posters/sardar.jpg', 1, N'Open'),
    (N'Scene', N'Drama', N'Tamil', 120, '2026-11-06', NULL, N'', N'/posters/scene.jpg', 1, N'Open'),
    (N'Seyon', N'Action', N'Tamil', 120, '2026-10-26', NULL, N'Sivakarthikeyan and Bhagyashri Borse.', N'/posters/seyon.jpg', 1, N'Open'),
    (N'Sigma', N'Action, Thriller', N'Tamil', 120, '2026-10-02', NULL, N'', N'/posters/sigma.jpg', 1, N'Open'),
    (N'Picasso', N'Drama', N'Tamil', 120, '2026-10-23', NULL, N'', N'/posters/siva.jpg', 1, N'Open'),
    (N'Mandaadi', N'Action', N'Tamil', 120, '2026-09-10', NULL, N'', N'/posters/soori.jpg', 1, N'Open'),
    (N'Titanic', N'Drama', N'Tamil', 120, '2026-10-23', NULL, N'', N'/posters/titanic.jpg', 1, N'Open'),
    (N'Don''t Trouble The Trouble', N'Comedy', N'Tamil', 120, '2026-10-02', NULL, N'', N'/posters/trouble.jpg', 1, N'Open'),
    (N'Vaa Deal', N'Comedy', N'Tamil', 120, '2026-11-20', NULL, N'', N'/posters/vaa.jpg', 1, N'Open'),
    (N'Varavu', N'Drama', N'Tamil', 120, '2026-06-12', NULL, N'', N'/posters/varavu.jpg', 1, N'Open'),
    (N'Vasudheva Sutham', N'Drama', N'Tamil', 120, '2026-07-10', NULL, N'', N'/posters/vasu.jpg', 1, N'Open'),
    (N'Yellow Yellow Dirty Fellow', N'Comedy', N'Tamil', 120, '2026-11-19', NULL, N'', N'/posters/yellow.jpg', 1, N'Open'),
    (N'Yezhu Kadal Yezhu Malai', N'Drama', N'Tamil', 120, '2026-10-01', NULL, N'', N'/posters/yezhu.jpg', 1, N'Open');
GO

/* ------------------------------------------------- SHOW SCHEDULE PROCEDURE
   Creates shows for the next @Days days (default 7).
   - Bookable movies = IsActive = 1, BookingStatus = 'Open' and released (ReleaseDate on or before today).
     Upcoming movies get no shows until their release date.
   - Every day has 4 shows per theatre on Monday-Friday and 5 on Saturday-Sunday.
   - Movies are handed out one after another over (day, theatre, slot), so every
     bookable movie gets a show before any movie gets a second one.
   - Old shows before today with no bookings are deleted first.
   Run again any time from the admin page, or:  EXEC dbo.usp_RebuildShows @Days = 7; */
IF OBJECT_ID(N'dbo.usp_RebuildShows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_RebuildShows;
GO
CREATE PROCEDURE dbo.usp_RebuildShows
    @Days INT = 7
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. remove past shows that have no bookings
    DELETE FROM dbo.Shows
    WHERE ShowDate < CAST(GETDATE() AS DATE)
      AND ShowID NOT IN (SELECT ShowID FROM dbo.Bookings);

    -- 2. bookable movies, numbered 1..M
    DECLARE @Movies TABLE (rn INT NOT NULL PRIMARY KEY, MovieID INT NOT NULL);
    INSERT INTO @Movies (rn, MovieID)
    SELECT ROW_NUMBER() OVER (ORDER BY MovieID), MovieID
    FROM dbo.Movies
    WHERE IsActive = 1 AND BookingStatus = N'Open' AND ReleaseDate <= CAST(GETDATE() AS DATE);

    DECLARE @M INT = (SELECT COUNT(*) FROM @Movies);
    IF @M = 0 RETURN;

    -- 3. days x active theatres x slots, in order; movie = position modulo M
    ;WITH Dates AS
    (
        SELECT 0 AS n, CAST(GETDATE() AS DATE) AS d
        UNION ALL
        SELECT n + 1, DATEADD(DAY, 1, d) FROM Dates WHERE n + 1 < @Days
    ),
    Theatres AS
    (
        SELECT TheatreID, ROW_NUMBER() OVER (ORDER BY TheatreID) AS tn
        FROM dbo.Theatres WHERE IsActive = 1
    ),
    Slots AS
    (
        SELECT v AS SlotNumber FROM (VALUES (1), (2), (3), (4), (5)) AS x(v)
    ),
    SchedulePlan AS
    (
        SELECT dt.n, dt.d, th.TheatreID, th.tn, sl.SlotNumber
        FROM Dates AS dt
        CROSS JOIN Theatres AS th
        CROSS JOIN Slots AS sl
        WHERE sl.SlotNumber <= CASE WHEN DATEDIFF(DAY, '19000101', dt.d) % 7 >= 5 THEN 5 ELSE 4 END
    ),
    Numbered AS
    (
        SELECT sp.*, ROW_NUMBER() OVER (ORDER BY sp.n, sp.tn, sp.SlotNumber) AS seq
        FROM SchedulePlan AS sp
    )
    INSERT INTO dbo.Shows (MovieID, TheatreID, ShowDate, ShowTime, ShowEndTime, SlotNumber)
    SELECT mv.MovieID, nu.TheatreID, nu.d,
           CASE nu.SlotNumber WHEN 1 THEN '09:00' WHEN 2 THEN '12:30' WHEN 3 THEN '16:00' WHEN 4 THEN '19:30' ELSE '22:45' END,
           CASE nu.SlotNumber WHEN 1 THEN '12:15' WHEN 2 THEN '15:45' WHEN 3 THEN '19:15' WHEN 4 THEN '22:30' ELSE '01:45' END,
           nu.SlotNumber
    FROM Numbered AS nu
    INNER JOIN @Movies AS mv ON mv.rn = ((nu.seq - 1) % @M) + 1
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Shows AS s
                      WHERE s.TheatreID = nu.TheatreID AND s.ShowDate = nu.d AND s.SlotNumber = nu.SlotNumber)
    OPTION (MAXRECURSION 400);
END;
GO

-- one week of shows for every bookable movie
EXEC dbo.usp_RebuildShows @Days = 7;
GO

-- check: bookable (released) movies and shows created
SELECT COUNT(*) AS NowShowing FROM dbo.Movies WHERE IsActive = 1 AND BookingStatus = N'Open' AND ReleaseDate <= CAST(GETDATE() AS DATE);
SELECT COUNT(*) AS Upcoming FROM dbo.Movies WHERE ReleaseDate > CAST(GETDATE() AS DATE);
SELECT COUNT(*) AS ShowsThisWeek FROM dbo.Shows WHERE ShowDate BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 6, CAST(GETDATE() AS DATE));
GO

PRINT N'MovieTicketBookingDB version 4 is ready.';
GO
