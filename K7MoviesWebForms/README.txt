K7 MOVIES - ONLINE MOVIE TICKET BOOKING (ASP.NET Web Forms, .aspx, C#) - VERSION 4
===========================================================================

WHAT IS NEW IN VERSION 4
1. Cancel or change a booking before the show starts:
   - Cancel some seats: those seats are refunded and released (Booking > Cancel seats).
   - Cancel all: the whole booking is refunded.
   - Add seats: buy more seats for a booking; the total is updated (Booking > Add seats).
   - Refunds are recorded as payments with status Refunded.
2. New role: THEATRE OWNER. Owners see booked tickets and statistics for their own
   theatre, date-wise and show-wise (Theatre dashboard, Booked tickets).
3. Theatres have a name, location and owner name. Admins set up the owner login on the
   Theatres page. Seats are 10 rows x 10 (A-J). Price by row:
       rows A-B 180 | C-D 190 | E-F 200 | G-H 210 | I-J 220
4. Shows use fixed slots per theatre per day:
       1: 09:00 AM - 12:15 PM    2: 12:30 PM - 03:45 PM    3: 04:00 PM - 07:15 PM
       4: 07:30 PM - 10:30 PM    5: 10:45 PM - 01:45 AM
   Monday to Friday = 4 shows, Saturday and Sunday = 5 shows.
   Old shows (before today, with no bookings) are removed by "Rebuild schedule (7 days)".

STEP 1 - DATABASE (required)
  Open Database\MovieTicketBooking_v4.sql in SQL Server Management Studio (connected to
  localhost\SQLEXPRESS) and press Execute. It DROPS and recreates MovieTicketBookingDB,
  so all old data is removed. It creates the tables, rules, trigger, sample data and the
  show schedule.

STEP 2 - RUN THE SITE
  Double-click run.bat. Open http://localhost:5080/Default.aspx

ACCOUNTS
  Admin           Kesavan      / Kesavan@43
  Customer        demo         / User@123
  Theatre owner   pvr_owner    / Owner@123   (PVR Cinemas, Madurai)
  Theatre owner   inox_owner   / Owner@123   (INOX Galaxy, Virudhunagar)

ADMIN WORK
  Theatres      add a theatre (name, location, owner name, optional owner login),
                edit it, and generate its seat layout.
  Shows         add a show manually (theatre, movie, date, slot) or "Rebuild schedule (7 days)".
  Movies        open or close booking; a movie with BookingStatus Open and Active gets shows.

PAGES
  Customer: Default, Shows, Seats (book / add seats), Receipt, MyBookings, CancelSeats,
            Login, Register
  Admin:    Admin/Default, Movies, Shows, Theatres, Seats, Users, Bookings, Payments, Reports
  Owner:    Owner/Default (statistics), Owner/Bookings (booked tickets)
  Other:    Health.aspx (database check)

RULES
- A booking can have at most 10 seats. A customer can change a booking only before the show starts.
- Revenue = Success payments minus Refunded payments.
- Double booking is blocked by the application and by a database trigger.

VALIDATORS (ASP.NET validation controls, C#)
RequiredFieldValidator, RangeValidator, RegularExpressionValidator, CompareValidator,
CustomValidator and ValidationSummary, with Page.Validate() on the server.

DISCONNECTED ARCHITECTURE
Data is read into DataTables (Db.Fill), changed in memory, and saved with SqlDataAdapter
inside transactions (Db.Save). Booking, cancellation and seat changes each run in one
transaction across all the tables they touch.

VERSION 4 CHANGES
- 43 movies are bookable: every title released on or before 31 Oct 2026 has status Open.
  Titles released after 31 Oct 2026 are Closed and appear under Coming soon.
- Shows are created for one week (7 days) for all 43 bookable movies. Each day has
  4 shows per theatre on Monday-Friday and 5 on Saturday-Sunday.
- Now showing / Coming soon and Book tickets follow the movie's booking status.

VERSION 4 CHANGES
- Movies come from the poster folder: 29 titles. Now showing = released on or before today.
  Upcoming = release date after today. Booking opens for released movies only.
- Run Database/MovieTicketBooking_v4.sql, then Database/set_posters.sql.
