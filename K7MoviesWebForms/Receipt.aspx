<%@ Page Title="Receipt" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Data" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <asp:Label ID="lblMsg" runat="server" CssClass="alert err" Visible="false"></asp:Label>
  <asp:Panel ID="pnlReceipt" runat="server" CssClass="card receipt">
    <div class="row between">
      <h1>&#127903; Booking <asp:Label ID="lblStatusTitle" runat="server"></asp:Label></h1>
      <asp:Literal ID="litBadge" runat="server"></asp:Literal>
    </div>
    <table class="kv">
      <tr><th>Booking ID</th><td>#<asp:Label ID="lblId" runat="server"></asp:Label></td></tr>
      <tr><th>Customer</th><td><asp:Label ID="lblCustomer" runat="server"></asp:Label></td></tr>
      <tr><th>Movie</th><td><asp:Label ID="lblMovie" runat="server"></asp:Label></td></tr>
      <tr><th>Theatre</th><td><asp:Label ID="lblTheatre" runat="server"></asp:Label></td></tr>
      <tr><th>Show</th><td><asp:Label ID="lblShow" runat="server"></asp:Label></td></tr>
      <tr><th>Seats</th><td><asp:Label ID="lblSeats" runat="server"></asp:Label></td></tr>
      <tr><th>Total paid</th><td><strong><asp:Label ID="lblTotal" runat="server"></asp:Label></strong></td></tr>
      <tr><th>Payment</th><td><asp:Label ID="lblPayment" runat="server"></asp:Label></td></tr>
      <tr><th>Booked on</th><td><asp:Label ID="lblBooked" runat="server"></asp:Label></td></tr>
    </table>
    <div class="row no-print">
      <button type="button" class="btn" onclick="window.print()">Print receipt</button>
      <asp:HyperLink runat="server" NavigateUrl="~/MyBookings.aspx" CssClass="btn ghost" Text="My bookings"></asp:HyperLink>
    </div>
  </asp:Panel>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        int id;
        if (!int.TryParse(Request.QueryString["id"], out id)) { ShowMessage("Booking not found."); return; }

        DataTable dt = Db.Fill(
            @"SELECT b.BookingID, b.UserID, b.BookingDate, b.TotalAmount, b.BookingStatus,
                     u.FullName, m.Title, t.TheatreName, t.Location, s.ShowDate, s.ShowTime,
                     p.PaymentMethod, p.PaymentStatus,
                     ISNULL(STUFF((SELECT ', ' + RTRIM(se.RowName) + CAST(se.SeatNumber AS VARCHAR(10))
                                   FROM BookingSeats bs INNER JOIN Seats se ON se.SeatID = bs.SeatID
                                   WHERE bs.BookingID = b.BookingID
                                   ORDER BY se.RowName, se.SeatNumber FOR XML PATH('')), 1, 2, ''), '') AS Seats,
                     (SELECT COUNT(*) FROM BookingSeats x WHERE x.BookingID = b.BookingID) AS Tickets
              FROM Bookings b
              INNER JOIN Users u ON u.UserID = b.UserID
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              OUTER APPLY (SELECT TOP 1 PaymentMethod, PaymentStatus FROM Payments
                           WHERE BookingID = b.BookingID ORDER BY PaymentID DESC) p
              WHERE b.BookingID = @B", Db.P("@B", id));

        if (dt.Rows.Count == 0) { ShowMessage("Booking not found."); return; }
        DataRow r = dt.Rows[0];

        if ((int)r["UserID"] != UserContext.CurrentUserId() && !UserContext.IsAdmin())
        {
            ShowMessage("You can only view your own receipts.");
            return;
        }

        string status = (string)r["BookingStatus"];
        lblStatusTitle.Text = status;
        litBadge.Text = Ui.StatusBadge(status);
        lblId.Text = r["BookingID"].ToString();
        lblCustomer.Text = Ui.Esc(r["FullName"]);
        lblMovie.Text = Ui.Esc(r["Title"]);
        lblTheatre.Text = Ui.Esc(r["TheatreName"]) + ", " + Ui.Esc(r["Location"]);
        DateTime start = Convert.ToDateTime(r["ShowDate"]).Date + (TimeSpan)r["ShowTime"];
        lblShow.Text = start.ToString("ddd, dd MMM yyyy hh:mm tt");
        string seats = Convert.ToString(r["Seats"]);
        int tickets = Convert.ToInt32(r["Tickets"]);
        lblSeats.Text = Ui.Esc(seats) + " (" + tickets + " tickets)";
        lblTotal.Text = "&#8377;" + Convert.ToDecimal(r["TotalAmount"]).ToString("0.00");
        lblPayment.Text = Ui.Esc(r["PaymentMethod"]) + " &middot; " + Ui.Esc(r["PaymentStatus"]);
        lblBooked.Text = Convert.ToDateTime(r["BookingDate"]).ToString("dd MMM yyyy, hh:mm tt");
    }

    private void ShowMessage(string message)
    {
        lblMsg.Text = message;
        lblMsg.Visible = true;
        pnlReceipt.Visible = false;
    }
</script>
