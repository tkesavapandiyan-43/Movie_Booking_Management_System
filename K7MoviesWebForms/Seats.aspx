<%@ Page Title="Select seats" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Linq" %>
<%@ Import Namespace="System.Text" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <a href="Shows.aspx?movie=<%= movieId %>" class="back">&larr; Back to showtimes</a>
  <h1><asp:Label ID="lblTitle" runat="server"></asp:Label></h1>
  <p class="meta"><asp:Label ID="lblInfo" runat="server"></asp:Label></p>
  <asp:Label ID="lblMode" runat="server" CssClass="alert ok" Visible="false"></asp:Label>
  <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>

  <div class="seat-layout">
    <section class="card seat-card">
      <div class="screen">ALL EYES THIS WAY</div>
      <asp:Literal ID="litSeatMap" runat="server" EnableViewState="false"></asp:Literal>
      <div class="legend">
        <span><i class="seat sample"></i> Available</span>
        <span><i class="seat sample sel"></i> Selected</span>
        <span><i class="seat sample booked"></i> Booked</span>
        <asp:Literal ID="litOwnLegend" runat="server"></asp:Literal>
      </div>
    </section>

    <aside class="card summary">
      <h3><asp:Label ID="lblSummaryTitle" runat="server" Text="Your booking"></asp:Label></h3>
      <asp:HiddenField ID="seatIds" runat="server" ClientIDMode="Static" />
      <dl class="kv-list">
        <div><dt>Seats</dt><dd id="sel">None selected</dd></div>
        <div><dt>Tickets</dt><dd id="count">0</dd></div>
        <div class="total"><dt>Total</dt><dd>&#8377;<span id="total">0</span></dd></div>
      </dl>
      <asp:CustomValidator ID="cvSeats" runat="server" CssClass="field-err" Display="Dynamic"
          ErrorMessage="Select between 1 and 10 seats in total for this booking." OnServerValidate="cvSeats_ServerValidate"></asp:CustomValidator>
      <label>Payment method
        <asp:DropDownList ID="ddlPayment" runat="server">
          <asp:ListItem Text="UPI" Value="UPI"></asp:ListItem>
          <asp:ListItem Text="Credit Card" Value="Credit Card"></asp:ListItem>
          <asp:ListItem Text="Debit Card" Value="Debit Card"></asp:ListItem>
          <asp:ListItem Text="Net Banking" Value="Net Banking"></asp:ListItem>
        </asp:DropDownList>
      </label>
      <asp:Button ID="paybtn" runat="server" Text="Pay &amp; confirm" CssClass="btn block" ClientIDMode="Static" OnClick="btnPay_Click" />
      <p class="muted small">Seat prices depend on the row. Up to 10 seats per booking. Payment is simulated for this project.</p>
      <asp:ValidationSummary ID="vsSeats" runat="server" CssClass="alert err" HeaderText="Please fix:" />
    </aside>
  </div>
  <script src="/js/seats.js"></script>
</asp:Content>

<script runat="server">
    private int showId;
    private int bookingId;
    private int movieId;
    private int theatreId;
    private bool addMode;
    private bool bookingOk = true;
    private bool showOpen;
    private HashSet<int> ownedSeats = new HashSet<int>();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!int.TryParse(Request.QueryString["show"], out showId))
        {
            Response.Redirect("~/Default.aspx", false);
            return;
        }
        addMode = int.TryParse(Request.QueryString["booking"], out bookingId);

        DataTable show = Db.Fill(
            @"SELECT s.TheatreID, s.MovieID, s.ShowDate, s.ShowTime, s.ShowEndTime, m.Title, m.BookingStatus, m.IsActive,
                     t.TheatreName, t.Location
              FROM Shows s
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              WHERE s.ShowID = @S", Db.P("@S", showId));
        if (show.Rows.Count == 0)
        {
            Response.Redirect("~/Default.aspx", false);
            return;
        }

        DataRow r = show.Rows[0];
        movieId = (int)r["MovieID"];
        theatreId = (int)r["TheatreID"];
        lblTitle.Text = (string)r["Title"];
        DateTime start = Convert.ToDateTime(r["ShowDate"]).Date + (TimeSpan)r["ShowTime"];

        DataTable range = Db.Fill("SELECT MIN(Price) AS Lo, MAX(Price) AS Hi FROM Seats WHERE TheatreID = @T", Db.P("@T", theatreId));
        string price = range.Rows.Count == 0 || range.Rows[0]["Lo"] == DBNull.Value
            ? ""
            : "&#8377;" + Convert.ToDecimal(range.Rows[0]["Lo"]).ToString("0") + " to &#8377;" + Convert.ToDecimal(range.Rows[0]["Hi"]).ToString("0") + " per seat (by row)";
        lblInfo.Text = r["TheatreName"] + ", " + r["Location"] + " &middot; " + start.ToString("ddd, dd MMM yyyy hh:mm tt", CultureInfo.InvariantCulture) +
                       " &middot; " + price;

        if (addMode)
        {
            DataTable b = Db.Fill(
                "SELECT BookingID, ShowID, BookingStatus FROM Bookings WHERE BookingID = @B AND UserID = @U",
                Db.P("@B", bookingId), Db.P("@U", UserContext.CurrentUserId()));
            bookingOk = b.Rows.Count > 0 && (int)b.Rows[0]["ShowID"] == showId && (string)b.Rows[0]["BookingStatus"] == "Confirmed";
            if (bookingOk)
            {
                DataTable owned = Db.Fill("SELECT SeatID FROM BookingSeats WHERE BookingID = @B", Db.P("@B", bookingId));
                ownedSeats = new HashSet<int>(owned.AsEnumerable().Select(x => (int)x["SeatID"]));
                lblMode.Text = "You are adding seats to booking #" + bookingId + ". Your current seats are shown in dark green.";
                lblMode.Visible = true;
                lblSummaryTitle.Text = "Add seats to booking #" + bookingId;
                paybtn.Text = "ADD SEATS &amp; PAY";
                litOwnLegend.Text = "<span><i class=\"seat sample owned\"></i> Your seats</span>";
            }
            else
            {
                ShowError("This booking cannot be changed (it may be cancelled or belong to another show).");
            }
        }

        showOpen = (bool)r["IsActive"] && (string)r["BookingStatus"] == "Open" && start > DateTime.Now;
        if (!showOpen) ShowError("Booking is closed for this show.");

        litSeatMap.Text = BuildSeatMap();
        paybtn.Enabled = showOpen && bookingOk;
    }

    /// <summary>Seat buttons with the same markup and classes as the MVC version. Price is stored on each seat.</summary>
    private string BuildSeatMap()
    {
        DataTable seats = Db.Fill(
            @"SELECT se.SeatID, se.RowName, se.SeatNumber, se.Price,
                     CASE WHEN taken.SeatID IS NULL THEN 0 ELSE 1 END AS Booked
              FROM Seats se
              LEFT JOIN (SELECT bs.SeatID
                         FROM BookingSeats bs
                         INNER JOIN Bookings b ON b.BookingID = bs.BookingID
                         WHERE b.ShowID = @S AND b.BookingStatus <> 'Cancelled' AND b.BookingID <> @B) taken ON taken.SeatID = se.SeatID
              WHERE se.TheatreID = @T
              ORDER BY se.RowName, se.SeatNumber",
            Db.P("@S", showId), Db.P("@T", theatreId), Db.P("@B", addMode ? bookingId : 0));

        HashSet<int> chosen = new HashSet<int>(SelectedIds());
        StringBuilder sb = new StringBuilder();
        sb.Append("<div class=\"seatmap\" id=\"seatmap\" data-existing=\"" + ownedSeats.Count + "\" data-closed=\"" +
                  (showOpen && bookingOk ? "false" : "true") + "\">");

        string currentRow = null;
        foreach (DataRow s in seats.Rows)
        {
            string row = ((string)s["RowName"]).Trim();
            if (row != currentRow)
            {
                if (currentRow != null) sb.Append("<span class=\"muted small\" style=\"margin-left:.6rem\">&#8377;" +
                                                  Convert.ToDecimal(lastPrice).ToString("0") + "</span></div>");
                sb.Append("<div class=\"seatrow\"><span class=\"rowlabel\">" + Ui.Esc(row) + "</span>");
                currentRow = row;
            }
            lastPrice = s["Price"];

            int id = (int)s["SeatID"];
            bool booked = Convert.ToInt32(s["Booked"]) == 1;
            bool owned = ownedSeats.Contains(id);
            string label = row + s["SeatNumber"];
            string cls = "seat" + (owned ? " owned" : booked ? " booked" : chosen.Contains(id) ? " sel" : "");
            bool disabled = booked || owned;
            sb.Append("<button type=\"button\" class=\"" + cls + "\" data-id=\"" + id + "\" data-label=\"" + Ui.Esc(label) +
                      "\" data-price=\"" + Convert.ToDecimal(s["Price"]).ToString("0", CultureInfo.InvariantCulture) + "\"" +
                      (disabled ? " disabled=\"disabled\"" : "") + " title=\"" + Ui.Esc(label) + "\">" +
                      s["SeatNumber"] + "</button>");
        }
        if (currentRow != null) sb.Append("<span class=\"muted small\" style=\"margin-left:.6rem\">&#8377;" +
                                          Convert.ToDecimal(lastPrice).ToString("0") + "</span></div>");
        sb.Append("</div>");
        return sb.ToString();
    }

    private object lastPrice = 0m;

    private List<int> SelectedIds()
    {
        List<int> ids = new List<int>();
        foreach (string part in (seatIds.Value ?? "").Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
        {
            int n;
            if (int.TryParse(part.Trim(), out n)) ids.Add(n);
        }
        return ids;
    }

    protected void cvSeats_ServerValidate(object source, ServerValidateEventArgs args)
    {
        List<int> ids = SelectedIds();
        int existing = addMode ? ownedSeats.Count : 0;
        args.IsValid = ids.Count >= 1 && ids.Distinct().Count() == ids.Count
                       && ids.Count <= BookingRules.MaxSeatsPerBooking
                       && existing + ids.Count <= BookingRules.MaxSeatsPerBooking;
    }

    protected void btnPay_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;
        if (!Request.IsAuthenticated)
        {
            Response.Redirect("~/Login.aspx", false);
            return;
        }

        int userId = UserContext.CurrentUserId();
        try
        {
            if (addMode)
            {
                string error = BookingRules.AddSeats(bookingId, userId, SelectedIds(), ddlPayment.SelectedValue);
                if (error != null) { ShowError(error); return; }
                Response.Redirect("~/Receipt.aspx?id=" + bookingId, false);
            }
            else
            {
                int id = Db.CreateBooking(userId, showId, SelectedIds(), ddlPayment.SelectedValue);
                Response.Redirect("~/Receipt.aspx?id=" + id, false);
            }
        }
        catch (InvalidOperationException ex) { ShowError(ex.Message); }
        catch (SqlException ex) { ShowError(ex.Message); }
    }

    private void ShowError(string message)
    {
        lblError.Text = message;
        lblError.Visible = true;
    }
</script>
