using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;

/// <summary>
/// Booking changes made by customers, all before the show starts:
///   Cancel        - cancel the whole booking and refund it
///   CancelSeats   - cancel some seats of a booking and refund those seats
///   AddSeats      - add more seats to an existing booking and pay for them
/// Every change runs in one transaction. Refunds are recorded as 'Refunded' payments.
/// Revenue = Success payments minus Refunded payments.
/// </summary>
public static class BookingRules
{
    public const int MaxSeatsPerBooking = 10;

    /// <summary>Cancels the whole booking. ownerId = null means admin (any booking). Returns an error message, or null on success.</summary>
    public static string Cancel(int bookingId, int? ownerId)
    {
        using (SqlConnection con = new SqlConnection(Db.ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    string error = FullCancel(con, tx, bookingId, ownerId);
                    if (error != null) { tx.Rollback(); return error; }
                    tx.Commit();
                    return null;
                }
                catch
                {
                    tx.Rollback();
                    throw;
                }
            }
        }
    }

    /// <summary>Cancels selected seats of a booking the customer owns, and refunds their price.</summary>
    public static string CancelSeats(int bookingId, int userId, List<int> seatIds)
    {
        if (seatIds == null || seatIds.Count == 0) return "Choose at least one seat to cancel.";

        using (SqlConnection con = new SqlConnection(Db.ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    DataTable booking = FillOwnBooking(con, tx, bookingId, userId);
                    if (booking.Rows.Count == 0) { tx.Rollback(); return "Booking not found."; }
                    DataRow br = booking.Rows[0];
                    string error = CheckChangeable(con, tx, br);
                    if (error != null) { tx.Rollback(); return error; }

                    DataTable bookingSeats = Db.FillTx(con, tx, "SELECT * FROM BookingSeats WHERE BookingID = @B", Db.P("@B", bookingId));
                    HashSet<int> chosen = new HashSet<int>(seatIds);
                    if (!bookingSeats.AsEnumerable().Select(r => (int)r["SeatID"]).Where(id => chosen.Contains(id)).Count().Equals(chosen.Count))
                    { tx.Rollback(); return "Some selected seats are not part of this booking."; }

                    // cancelling every seat is the same as cancelling the booking
                    if (chosen.Count == bookingSeats.Rows.Count)
                    {
                        error = FullCancel(con, tx, bookingId, userId);
                        if (error != null) { tx.Rollback(); return error; }
                        tx.Commit();
                        return null;
                    }

                    DataTable prices = Db.FillTx(con, tx,
                        "SELECT SeatID, Price FROM Seats WHERE SeatID IN (" + Db.IdList(chosen) + ")");
                    decimal refund = prices.AsEnumerable().Sum(r => (decimal)r["Price"]);

                    foreach (DataRow r in bookingSeats.Rows)
                        if (chosen.Contains((int)r["SeatID"])) r.Delete();
                    Db.Save(con, tx, bookingSeats, "BookingSeats", "BookingSeatID");

                    br["TotalAmount"] = (decimal)br["TotalAmount"] - refund;
                    Db.Save(con, tx, booking, "Bookings", "BookingID");

                    Db.AddPayment(con, tx, bookingId, LastMethod(con, tx, bookingId), refund, "Refunded");
                    tx.Commit();
                    return null;
                }
                catch
                {
                    tx.Rollback();
                    throw;
                }
            }
        }
    }

    /// <summary>Adds seats to a booking the customer owns and charges for them.</summary>
    public static string AddSeats(int bookingId, int userId, List<int> seatIds, string paymentMethod)
    {
        if (seatIds == null || seatIds.Count == 0) return "Choose at least one seat to add.";

        using (SqlConnection con = new SqlConnection(Db.ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    DataTable booking = FillOwnBooking(con, tx, bookingId, userId);
                    if (booking.Rows.Count == 0) { tx.Rollback(); return "Booking not found."; }
                    DataRow br = booking.Rows[0];
                    string error = CheckChangeable(con, tx, br);
                    if (error != null) { tx.Rollback(); return error; }

                    DataTable current = Db.FillTx(con, tx, "SELECT SeatID FROM BookingSeats WHERE BookingID = @B", Db.P("@B", bookingId));
                    HashSet<int> have = new HashSet<int>(current.AsEnumerable().Select(r => (int)r["SeatID"]));
                    List<int> fresh = seatIds.Distinct().Where(id => !have.Contains(id)).ToList();
                    if (fresh.Count == 0) { tx.Rollback(); return "Those seats are already in this booking."; }
                    if (have.Count + fresh.Count > MaxSeatsPerBooking)
                    { tx.Rollback(); return "A booking can have at most " + MaxSeatsPerBooking + " seats."; }

                    int theatreId = Convert.ToInt32(Db.FillTx(con, tx,
                        "SELECT s.TheatreID FROM Shows s WHERE s.ShowID = @S", Db.P("@S", (int)br["ShowID"])).Rows[0]["TheatreID"]);

                    DataTable seats = Db.FillTx(con, tx,
                        "SELECT SeatID, Price FROM Seats WHERE TheatreID = @T AND SeatID IN (" + Db.IdList(fresh) + ")",
                        Db.P("@T", theatreId));
                    if (seats.Rows.Count != fresh.Count) { tx.Rollback(); return "Invalid seat selection."; }

                    DataTable taken = Db.FillTx(con, tx,
                        @"SELECT bs.SeatID FROM BookingSeats bs WITH (UPDLOCK, HOLDLOCK)
                          INNER JOIN Bookings b ON bs.BookingID = b.BookingID
                          WHERE b.ShowID = @S AND b.BookingStatus <> 'Cancelled' AND b.BookingID <> @B
                            AND bs.SeatID IN (" + Db.IdList(fresh) + ")",
                        Db.P("@S", (int)br["ShowID"]), Db.P("@B", bookingId));
                    if (taken.Rows.Count > 0)
                    { tx.Rollback(); return "Sorry, one or more selected seats were just booked by someone else."; }

                    DataTable bookingSeats = Db.FillTx(con, tx, "SELECT * FROM BookingSeats WHERE 1 = 0");
                    foreach (int seatId in fresh)
                    {
                        DataRow r = bookingSeats.NewRow();
                        r["BookingID"] = bookingId;
                        r["SeatID"] = seatId;
                        bookingSeats.Rows.Add(r);
                    }
                    Db.Save(con, tx, bookingSeats, "BookingSeats", "BookingSeatID");

                    decimal add = seats.AsEnumerable().Sum(r => (decimal)r["Price"]);
                    br["TotalAmount"] = (decimal)br["TotalAmount"] + add;
                    Db.Save(con, tx, booking, "Bookings", "BookingID");

                    Db.AddPayment(con, tx, bookingId, paymentMethod, add, "Success");
                    tx.Commit();
                    return null;
                }
                catch
                {
                    tx.Rollback();
                    throw;
                }
            }
        }
    }

    // ---------------- helpers ----------------

    /// <summary>Full cancellation inside an open transaction. Refunds the booking's current total.</summary>
    private static string FullCancel(SqlConnection con, SqlTransaction tx, int bookingId, int? ownerId)
    {
        string sql = "SELECT * FROM Bookings WHERE BookingID = @B";
        DataTable bookings = ownerId.HasValue
            ? Db.FillTx(con, tx, sql + " AND UserID = @U", Db.P("@B", bookingId), Db.P("@U", ownerId.Value))
            : Db.FillTx(con, tx, sql, Db.P("@B", bookingId));
        if (bookings.Rows.Count == 0) return "Booking not found.";

        DataRow br = bookings.Rows[0];
        if ((string)br["BookingStatus"] == "Cancelled") return "This booking is already cancelled.";
        string error = CheckChangeable(con, tx, br);
        if (error != null) return error;

        decimal refund = (decimal)br["TotalAmount"];
        br["BookingStatus"] = "Cancelled";
        Db.Save(con, tx, bookings, "Bookings", "BookingID");
        if (refund > 0) Db.AddPayment(con, tx, bookingId, LastMethod(con, tx, bookingId), refund, "Refunded");
        return null;
    }

    private static DataTable FillOwnBooking(SqlConnection con, SqlTransaction tx, int bookingId, int userId)
    {
        return Db.FillTx(con, tx, "SELECT * FROM Bookings WHERE BookingID = @B AND UserID = @U",
            Db.P("@B", bookingId), Db.P("@U", userId));
    }

    /// <summary>The booking must be Confirmed and its show must not have started yet.</summary>
    private static string CheckChangeable(SqlConnection con, SqlTransaction tx, DataRow booking)
    {
        if ((string)booking["BookingStatus"] != "Confirmed") return "This booking is already cancelled.";
        DataTable show = Db.FillTx(con, tx, "SELECT ShowDate, ShowTime FROM Shows WHERE ShowID = @S",
            Db.P("@S", (int)booking["ShowID"]));
        if (show.Rows.Count == 0) return "This show no longer exists.";
        DateTime start = Convert.ToDateTime(show.Rows[0]["ShowDate"]).Date + (TimeSpan)show.Rows[0]["ShowTime"];
        if (start <= DateTime.Now) return "This show has already started, so the booking can no longer be changed.";
        return null;
    }

    private static string LastMethod(SqlConnection con, SqlTransaction tx, int bookingId)
    {
        DataTable t = Db.FillTx(con, tx,
            "SELECT TOP 1 PaymentMethod FROM Payments WHERE BookingID = @B ORDER BY PaymentID DESC", Db.P("@B", bookingId));
        return t.Rows.Count == 0 ? "UPI" : (string)t.Rows[0]["PaymentMethod"];
    }
}
