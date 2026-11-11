<%@ Page Title="Theatre dashboard" Language="C#" MasterPageFile="~/Owner/Owner.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Linq" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <div class="page-head">
    <div>
      <h1>Theatre dashboard</h1>
      <p class="muted">Booked tickets and statistics for your theatre, by date and by show.</p>
    </div>
  </div>

  <asp:Panel ID="pnlFilter" runat="server" CssClass="filters card" DefaultButton="btnApply">
    <label>FROM<asp:TextBox ID="txtFrom" runat="server" TextMode="Date"></asp:TextBox></label>
    <asp:RequiredFieldValidator ID="rfvFrom" runat="server" ControlToValidate="txtFrom" ErrorMessage="Start date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
    <label>TO<asp:TextBox ID="txtTo" runat="server" TextMode="Date"></asp:TextBox></label>
    <asp:RequiredFieldValidator ID="rfvTo" runat="server" ControlToValidate="txtTo" ErrorMessage="End date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
    <asp:CompareValidator ID="cmpDates" runat="server" ControlToValidate="txtTo" ControlToCompare="txtFrom" Operator="GreaterThanEqual" Type="Date"
        ErrorMessage="End date must be on or after the start date." CssClass="field-err" Display="Dynamic"></asp:CompareValidator>
    <asp:Button ID="btnApply" runat="server" Text="APPLY" CssClass="btn" OnClick="btnApply_Click" />
    <asp:ValidationSummary ID="vsFilter" runat="server" CssClass="alert err" HeaderText="Please fix:" />
  </asp:Panel>
  <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>

  <div class="stats">
    <div class="stat"><span>Bookings</span><b><asp:Label ID="lblBookings" runat="server"></asp:Label></b></div>
    <div class="stat"><span>Tickets sold</span><b><asp:Label ID="lblTickets" runat="server"></asp:Label></b></div>
    <div class="stat"><span>Revenue</span><b><asp:Label ID="lblRevenue" runat="server"></asp:Label></b></div>
    <div class="stat"><span>Cancelled bookings</span><b><asp:Label ID="lblCancelled" runat="server"></asp:Label></b></div>
    <div class="stat"><span>Refunds paid</span><b><asp:Label ID="lblRefunds" runat="server"></asp:Label></b></div>
  </div>

  <h2>Date-wise</h2>
  <asp:GridView ID="gvDates" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None" EmptyDataText="No shows in this date range.">
    <Columns>
      <asp:BoundField DataField="ShowDate" HeaderText="Date" DataFormatString="{0:ddd, dd MMM yyyy}" />
      <asp:BoundField DataField="Bookings" HeaderText="Bookings" />
      <asp:BoundField DataField="Tickets" HeaderText="Tickets" />
      <asp:BoundField DataField="Revenue" HeaderText="Revenue" DataFormatString="&#8377;{0:0.00}" HtmlEncode="false" />
      <asp:BoundField DataField="Cancelled" HeaderText="Cancelled" />
      <asp:BoundField DataField="Refunds" HeaderText="Refunds" DataFormatString="&#8377;{0:0.00}" HtmlEncode="false" />
    </Columns>
  </asp:GridView>

  <h2>Show-wise</h2>
  <asp:GridView ID="gvShows" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None" EmptyDataText="No shows in this date range.">
    <Columns>
      <asp:BoundField DataField="ShowDate" HeaderText="Date" DataFormatString="{0:dd MMM yyyy}" />
      <asp:BoundField DataField="SlotNumber" HeaderText="Slot" />
      <asp:BoundField DataField="Time" HeaderText="Time" />
      <asp:BoundField DataField="Title" HeaderText="Movie" />
      <asp:BoundField DataField="Bookings" HeaderText="Bookings" />
      <asp:BoundField DataField="Tickets" HeaderText="Tickets" />
      <asp:BoundField DataField="Capacity" HeaderText="Seats" />
      <asp:BoundField DataField="Occupancy" HeaderText="Occupancy" />
      <asp:BoundField DataField="Revenue" HeaderText="Revenue" DataFormatString="&#8377;{0:0.00}" HtmlEncode="false" />
    </Columns>
  </asp:GridView>
</asp:Content>

<script runat="server">
    private int theatreId;

    protected void Page_Load(object sender, EventArgs e)
    {
        theatreId = UserContext.OwnerTheatreId();
        if (theatreId == 0)
        {
            ShowError("Your account is not linked to a theatre. Ask the admin to set it on the Theatres page.");
            pnlFilter.Visible = false;
            return;
        }
        if (!IsPostBack)
        {
            txtFrom.Text = DateTime.Today.AddDays(-6).ToString("yyyy-MM-dd");
            txtTo.Text = DateTime.Today.AddDays(6).ToString("yyyy-MM-dd");
            Load();
        }
    }

    protected void btnApply_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;
        Load();
    }

    private void Load()
    {
        DateTime from = DateTime.Parse(txtFrom.Text).Date;
        DateTime to = DateTime.Parse(txtTo.Text).Date;

        DataTable dates = Db.Fill(
            @"SELECT sh.ShowDate,
                     SUM(CASE WHEN b.BookingStatus = N'Confirmed' THEN 1 ELSE 0 END) AS Bookings,
                     SUM(CASE WHEN b.BookingStatus = N'Confirmed' THEN ISNULL(sc.Tickets, 0) ELSE 0 END) AS Tickets,
                     SUM(CASE WHEN b.BookingStatus = N'Confirmed' THEN b.TotalAmount ELSE 0 END) AS Revenue,
                     SUM(CASE WHEN b.BookingStatus = N'Cancelled' THEN 1 ELSE 0 END) AS Cancelled,
                     (SELECT ISNULL(SUM(p.Amount), 0) FROM Payments p
                        INNER JOIN Bookings bb ON bb.BookingID = p.BookingID
                        INNER JOIN Shows ss ON ss.ShowID = bb.ShowID
                      WHERE ss.TheatreID = @T AND ss.ShowDate = sh.ShowDate AND p.PaymentStatus = N'Refunded') AS Refunds
              FROM Shows sh
              LEFT JOIN Bookings b ON b.ShowID = sh.ShowID
              OUTER APPLY (SELECT COUNT(*) AS Tickets FROM BookingSeats bs WHERE bs.BookingID = b.BookingID) sc
              WHERE sh.TheatreID = @T AND sh.ShowDate BETWEEN @F AND @EndDate
              GROUP BY sh.ShowDate
              ORDER BY sh.ShowDate",
            Db.P("@T", theatreId), Db.P("@F", from), Db.P("@EndDate", to));
        gvDates.DataSource = dates;
        gvDates.DataBind();

        DataTable shows = Db.Fill(
            @"SELECT sh.ShowDate, sh.SlotNumber, sh.ShowTime, sh.ShowEndTime, m.Title,
                     (SELECT COUNT(*) FROM Bookings b WHERE b.ShowID = sh.ShowID AND b.BookingStatus = N'Confirmed') AS Bookings,
                     (SELECT COUNT(*) FROM BookingSeats bs INNER JOIN Bookings b ON b.BookingID = bs.BookingID
                        WHERE b.ShowID = sh.ShowID AND b.BookingStatus = N'Confirmed') AS Tickets,
                     (SELECT ISNULL(SUM(b.TotalAmount), 0) FROM Bookings b WHERE b.ShowID = sh.ShowID AND b.BookingStatus = N'Confirmed') AS Revenue,
                     (SELECT COUNT(*) FROM Seats se WHERE se.TheatreID = sh.TheatreID) AS Capacity
              FROM Shows sh
              INNER JOIN Movies m ON m.MovieID = sh.MovieID
              WHERE sh.TheatreID = @T AND sh.ShowDate BETWEEN @F AND @EndDate
              ORDER BY sh.ShowDate, sh.SlotNumber",
            Db.P("@T", theatreId), Db.P("@F", from), Db.P("@EndDate", to));

        // presentation columns for the show table
        shows.Columns.Add("Time", typeof(string));
        shows.Columns.Add("Occupancy", typeof(string));
        foreach (DataRow r in shows.Rows)
        {
            DateTime start = Convert.ToDateTime(r["ShowDate"]).Date + (TimeSpan)r["ShowTime"];
            r["Time"] = DateTime.Today.Add((TimeSpan)r["ShowTime"]).ToString("hh:mm tt", CultureInfo.InvariantCulture) + " - " +
                        DateTime.Today.Add((TimeSpan)r["ShowEndTime"]).ToString("hh:mm tt", CultureInfo.InvariantCulture);
            int capacity = Convert.ToInt32(r["Capacity"]);
            double pct = capacity == 0 ? 0 : 100.0 * Convert.ToInt32(r["Tickets"]) / capacity;
            r["Occupancy"] = pct.ToString("0", CultureInfo.InvariantCulture) + "%";
        }
        gvShows.DataSource = shows;
        gvShows.DataBind();

        // totals for the stat tiles
        int bookings = dates.AsEnumerable().Sum(r => Convert.ToInt32(r["Bookings"]));
        int tickets = dates.AsEnumerable().Sum(r => Convert.ToInt32(r["Tickets"]));
        decimal revenue = dates.AsEnumerable().Sum(r => Convert.ToDecimal(r["Revenue"]));
        int cancelled = dates.AsEnumerable().Sum(r => Convert.ToInt32(r["Cancelled"]));
        decimal refunds = dates.AsEnumerable().Sum(r => Convert.ToDecimal(r["Refunds"]));
        lblBookings.Text = bookings.ToString();
        lblTickets.Text = tickets.ToString();
        lblRevenue.Text = "&#8377;" + revenue.ToString("0.00", CultureInfo.InvariantCulture);
        lblCancelled.Text = cancelled.ToString();
        lblRefunds.Text = "&#8377;" + refunds.ToString("0.00", CultureInfo.InvariantCulture);
    }

    private void ShowError(string message)
    {
        lblError.Text = message;
        lblError.Visible = true;
    }
</script>
