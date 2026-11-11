using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

/// <summary>
/// Disconnected data access: DataSet / DataTable + SqlDataAdapter.
///  - Fill  : opens the connection, fills a DataTable in memory, closes the connection.
///  - Change: add / edit / delete DataRows in memory (RowState tracks the changes).
///  - Save  : SqlDataAdapter.Update writes only the changed rows, inside a transaction.
/// </summary>
public static class Db
{
    public static string ConnStr
    {
        get { return ConfigurationManager.ConnectionStrings["MovieDb"].ConnectionString; }
    }

    public static SqlParameter P(string name, object value)
    {
        return new SqlParameter(name, value ?? DBNull.Value);
    }

    /// <summary>SHA-256 hex (lower case), the same hash used by schema and the sample accounts.</summary>
    public static string Hash(string password)
    {
        using (SHA256 sha = SHA256.Create())
        {
            byte[] bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(password ?? ""));
            StringBuilder sb = new StringBuilder();
            foreach (byte b in bytes) sb.Append(b.ToString("x2"));
            return sb.ToString();
        }
    }

    // ---------------- READ (disconnected) ----------------

    public static DataTable Fill(string sql, params SqlParameter[] parameters)
    {
        using (SqlConnection con = new SqlConnection(ConnStr))
        using (SqlCommand cmd = new SqlCommand(sql, con))
        using (SqlDataAdapter da = new SqlDataAdapter())
        {
            if (parameters != null) cmd.Parameters.AddRange(parameters);
            da.SelectCommand = cmd;
            DataTable dt = new DataTable();
            da.Fill(dt);
            return dt;
        }
    }

    public static DataTable FillTx(SqlConnection con, SqlTransaction tx, string sql, params SqlParameter[] parameters)
    {
        using (SqlCommand cmd = new SqlCommand(sql, con, tx))
        using (SqlDataAdapter da = new SqlDataAdapter())
        {
            if (parameters != null) cmd.Parameters.AddRange(parameters);
            da.SelectCommand = cmd;
            DataTable dt = new DataTable();
            da.Fill(dt);
            return dt;
        }
    }

    public static int Count(string sql, params SqlParameter[] parameters)
    {
        return Convert.ToInt32(Scalar(sql, parameters) ?? 0);
    }

    public static decimal Sum(string sql, params SqlParameter[] parameters)
    {
        object v = Scalar(sql, parameters);
        return v == null ? 0m : Convert.ToDecimal(v);
    }

    /// <summary>Runs a command that returns no rows (for example EXEC dbo.usp_RebuildShows).</summary>
    public static int Execute(string sql, params SqlParameter[] parameters)
    {
        using (SqlConnection con = new SqlConnection(ConnStr))
        using (SqlCommand cmd = new SqlCommand(sql, con))
        {
            if (parameters != null) cmd.Parameters.AddRange(parameters);
            con.Open();
            return cmd.ExecuteNonQuery();
        }
    }

    private static object Scalar(string sql, SqlParameter[] parameters)
    {
        using (SqlConnection con = new SqlConnection(ConnStr))
        using (SqlCommand cmd = new SqlCommand(sql, con))
        {
            if (parameters != null) cmd.Parameters.AddRange(parameters);
            con.Open();
            object v = cmd.ExecuteScalar();
            return v == DBNull.Value ? null : v;
        }
    }

    /// <summary>A new row with a temporary negative key (the database assigns the real identity on Save).</summary>
    public static DataRow AddRow(DataTable dt, string keyColumn)
    {
        DataRow row = dt.NewRow();
        int min = 0;
        foreach (DataRow r in dt.Rows)
            if (r.RowState != DataRowState.Deleted) min = Math.Min(min, Convert.ToInt32(r[keyColumn]));
        row[keyColumn] = min - 1;
        dt.Rows.Add(row);
        return row;
    }

    // ---------------- SAVE (disconnected update) ----------------

    public static void Save(DataTable dt, string table, string keyColumn)
    {
        using (SqlConnection con = new SqlConnection(ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    Save(con, tx, dt, table, keyColumn);
                    tx.Commit();
                }
                catch
                {
                    tx.Rollback();
                    throw;
                }
            }
        }
    }

    /// <summary>Saves the changes of a DataTable using the connection and transaction supplied by the caller.</summary>
    public static void Save(SqlConnection con, SqlTransaction tx, DataTable dt, string table, string keyColumn)
    {
        List<DataColumn> all = dt.Columns.Cast<DataColumn>().ToList();
        DataColumn keyCol = all.First(c => c.ColumnName == keyColumn);
        List<DataColumn> others = all.Where(c => c.ColumnName != keyColumn).ToList();

        // INSERT returns the new identity, which is written back into the DataRow
        string insertSql =
            "INSERT INTO " + table + " (" + string.Join(", ", others.Select(c => c.ColumnName)) + ") " +
            "VALUES (" + string.Join(", ", others.Select(c => "@" + c.ColumnName)) + "); " +
            "SELECT CAST(SCOPE_IDENTITY() AS INT) AS " + keyColumn + ";";
        SqlCommand insert = new SqlCommand(insertSql, con, tx);
        insert.UpdatedRowSource = UpdateRowSource.FirstReturnedRecord;
        foreach (DataColumn c in others) insert.Parameters.Add(Prm(c, DataRowVersion.Current));

        string setSql = string.Join(", ", others.Select(c => c.ColumnName + " = @" + c.ColumnName));
        SqlCommand update = new SqlCommand(
            "UPDATE " + table + " SET " + setSql + " WHERE " + keyColumn + " = @" + keyColumn, con, tx);
        foreach (DataColumn c in others) update.Parameters.Add(Prm(c, DataRowVersion.Current));
        update.Parameters.Add(Prm(keyCol, DataRowVersion.Original));

        SqlCommand delete = new SqlCommand(
            "DELETE FROM " + table + " WHERE " + keyColumn + " = @" + keyColumn, con, tx);
        delete.Parameters.Add(Prm(keyCol, DataRowVersion.Original));

        using (SqlDataAdapter da = new SqlDataAdapter())
        {
            da.InsertCommand = insert;
            da.UpdateCommand = update;
            da.DeleteCommand = delete;
            da.Update(dt);
        }
    }

    private static SqlParameter Prm(DataColumn c, DataRowVersion version)
    {
        SqlParameter p = new SqlParameter
        {
            ParameterName = "@" + c.ColumnName,
            SqlDbType = TypeOf(c.DataType),
            SourceColumn = c.ColumnName,
            SourceVersion = version
        };
        if (c.DataType == typeof(decimal)) { p.Precision = 18; p.Scale = 2; }
        return p;
    }

    private static SqlDbType TypeOf(Type t)
    {
        if (t == typeof(int)) return SqlDbType.Int;
        if (t == typeof(decimal)) return SqlDbType.Decimal;
        if (t == typeof(bool)) return SqlDbType.Bit;
        if (t == typeof(DateTime)) return SqlDbType.DateTime;
        if (t == typeof(TimeSpan)) return SqlDbType.Time;
        return SqlDbType.NVarChar;
    }

    /// <summary>Seat numbers are validated integers, so they can be joined into an IN (...) list.</summary>
    public static string IdList(IEnumerable<int> ids)
    {
        return string.Join(",", ids.Select(i => i.ToString()));
    }

    // ---------------- BOOKING (one transaction over three tables) ----------------

    /// <summary>
    /// Creates a booking: Bookings + BookingSeats + Payments in one transaction.
    /// The price of each seat comes from its row (Seats.Price); the total is the sum of the seats.
    /// Throws InvalidOperationException with a user-friendly message on a business-rule failure.
    /// </summary>
    public static int CreateBooking(int userId, int showId, List<int> seatIds, string paymentMethod)
    {
        using (SqlConnection con = new SqlConnection(ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    DataTable show = FillTx(con, tx,
                        @"SELECT s.TheatreID, s.ShowDate, s.ShowTime, m.BookingStatus, m.IsActive
                          FROM Shows s INNER JOIN Movies m ON s.MovieID = m.MovieID WHERE s.ShowID = @S",
                        P("@S", showId));
                    if (show.Rows.Count == 0) throw new InvalidOperationException("This show no longer exists.");
                    DataRow sr = show.Rows[0];
                    if (!(bool)sr["IsActive"] || (string)sr["BookingStatus"] != "Open")
                        throw new InvalidOperationException("Booking is closed for this movie.");
                    DateTime start = Convert.ToDateTime(sr["ShowDate"]).Date + (TimeSpan)sr["ShowTime"];
                    if (start <= DateTime.Now) throw new InvalidOperationException("This show has already started.");

                    int theatreId = (int)sr["TheatreID"];
                    DataTable seats = FillTx(con, tx,
                        "SELECT SeatID, Price FROM Seats WHERE TheatreID = @T AND SeatID IN (" + IdList(seatIds) + ")",
                        P("@T", theatreId));
                    if (seats.Rows.Count != seatIds.Count) throw new InvalidOperationException("Invalid seat selection.");
                    decimal total = seats.AsEnumerable().Sum(r => (decimal)r["Price"]);

                    DataTable taken = FillTx(con, tx,
                        @"SELECT bs.SeatID FROM BookingSeats bs WITH (UPDLOCK, HOLDLOCK)
                          INNER JOIN Bookings b ON bs.BookingID = b.BookingID
                          WHERE b.ShowID = @S AND b.BookingStatus <> 'Cancelled' AND bs.SeatID IN (" + IdList(seatIds) + ")",
                        P("@S", showId));
                    if (taken.Rows.Count > 0)
                        throw new InvalidOperationException("Sorry, one or more selected seats were just booked. Please choose again.");

                    // 1. header
                    DataTable bookings = FillTx(con, tx, "SELECT * FROM Bookings WHERE 1 = 0");
                    DataRow b1 = bookings.NewRow();
                    b1["UserID"] = userId;
                    b1["ShowID"] = showId;
                    b1["BookingDate"] = DateTime.Now;
                    b1["TotalAmount"] = total;
                    b1["BookingStatus"] = "Confirmed";
                    bookings.Rows.Add(b1);
                    Save(con, tx, bookings, "Bookings", "BookingID");
                    int bookingId = (int)b1["BookingID"];

                    // 2. seats
                    DataTable bookingSeats = FillTx(con, tx, "SELECT * FROM BookingSeats WHERE 1 = 0");
                    foreach (int seatId in seatIds)
                    {
                        DataRow r = bookingSeats.NewRow();
                        r["BookingID"] = bookingId;
                        r["SeatID"] = seatId;
                        bookingSeats.Rows.Add(r);
                    }
                    Save(con, tx, bookingSeats, "BookingSeats", "BookingSeatID");

                    // 3. payment (simulated)
                    AddPayment(con, tx, bookingId, paymentMethod, total, "Success");

                    tx.Commit();
                    return bookingId;
                }
                catch
                {
                    tx.Rollback();
                    throw;
                }
            }
        }
    }

    /// <summary>Adds a payment row. 'Success' = money received, 'Refunded' = money returned.</summary>
    public static void AddPayment(SqlConnection con, SqlTransaction tx, int bookingId, string method, decimal amount, string status)
    {
        DataTable payments = FillTx(con, tx, "SELECT * FROM Payments WHERE 1 = 0");
        DataRow pay = payments.NewRow();
        pay["BookingID"] = bookingId;
        pay["PaymentMethod"] = method;
        pay["TransactionReference"] = (status == "Refunded" ? "REF" : "TXN") + DateTime.Now.ToString("yyyyMMddHHmmss") + new Random().Next(1000, 9999);
        pay["Amount"] = amount;
        pay["PaymentDate"] = DateTime.Now;
        pay["PaymentStatus"] = status;
        payments.Rows.Add(pay);
        Save(con, tx, payments, "Payments", "PaymentID");
    }
}
