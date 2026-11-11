using System;
using System.Data;
using System.Data.SqlClient;

/// <summary>Theatre seat layout and theatre owner accounts.</summary>
public static class TheatreRules
{
    /// <summary>
    /// Price of a seat by row: rows A-B = 180, C-D = 190, E-F = 200, G-H = 210, I-J = 220 (+10 per row pair).
    /// </summary>
    public static decimal PriceForRow(int rowIndexFromZero)
    {
        return 180m + 10m * (rowIndexFromZero / 2);
    }

    /// <summary>Rebuilds the seat layout (rows A.. x seats per row), sets prices and TotalSeats, in one transaction.</summary>
    public static void GenerateSeats(int theatreId, int rows, int seatsPerRow)
    {
        if (rows < 1 || rows > 10 || seatsPerRow < 1 || seatsPerRow > 30)
            throw new ArgumentException("Rows must be 1-10 and seats per row 1-30.");

        using (SqlConnection con = new SqlConnection(Db.ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    DataTable old = Db.FillTx(con, tx, "SELECT * FROM Seats WHERE TheatreID = @T", Db.P("@T", theatreId));
                    foreach (DataRow r in old.Rows) r.Delete();
                    Db.Save(con, tx, old, "Seats", "SeatID");

                    DataTable seats = Db.FillTx(con, tx, "SELECT * FROM Seats WHERE 1 = 0");
                    for (int i = 0; i < rows; i++)
                        for (int n = 1; n <= seatsPerRow; n++)
                        {
                            DataRow r = seats.NewRow();
                            r["TheatreID"] = theatreId;
                            r["RowName"] = ((char)('A' + i)).ToString();
                            r["SeatNumber"] = n;
                            r["Price"] = PriceForRow(i);
                            seats.Rows.Add(r);
                        }
                    Db.Save(con, tx, seats, "Seats", "SeatID");

                    DataTable theatre = Db.FillTx(con, tx, "SELECT * FROM Theatres WHERE TheatreID = @T", Db.P("@T", theatreId));
                    foreach (DataRow r in theatre.Rows) r["TotalSeats"] = rows * seatsPerRow;
                    Db.Save(con, tx, theatre, "Theatres", "TheatreID");

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

    /// <summary>
    /// Creates or updates the theatre owner login for a theatre.
    /// A new owner needs a password. An existing owner keeps the old one if no new password is typed.
    /// </summary>
    public static void SaveOwner(int theatreId, string ownerName, string username, string password)
    {
        if (string.IsNullOrWhiteSpace(username)) return;

        using (SqlConnection con = new SqlConnection(Db.ConnStr))
        {
            con.Open();
            using (SqlTransaction tx = con.BeginTransaction())
            {
                try
                {
                    DataTable users = Db.FillTx(con, tx, "SELECT * FROM Users WHERE Username = @U", Db.P("@U", username.Trim()));
                    if (users.Rows.Count == 0)
                    {
                        if (string.IsNullOrEmpty(password))
                            throw new ArgumentException("Type a password for the new theatre owner login.");
                        DataRow r = users.NewRow();
                        r["FullName"] = ownerName.Trim();
                        r["Username"] = username.Trim();
                        r["Email"] = username.Trim() + "@owner.cinebook.com";
                        r["PasswordHash"] = Db.Hash(password);
                        r["Role"] = "TheatreOwner";
                        r["TheatreID"] = theatreId;
                        users.Rows.Add(r);
                    }
                    else
                    {
                        DataRow r = users.Rows[0];
                        if ((string)r["Role"] != "TheatreOwner")
                            throw new ArgumentException("That username already belongs to a customer or admin.");
                        r["FullName"] = ownerName.Trim();
                        r["TheatreID"] = theatreId;
                        if (!string.IsNullOrEmpty(password)) r["PasswordHash"] = Db.Hash(password);
                    }
                    Db.Save(con, tx, users, "Users", "UserID");
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
}
