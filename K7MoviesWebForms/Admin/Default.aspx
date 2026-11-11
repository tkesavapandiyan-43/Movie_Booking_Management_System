<%@ Page Title="Admin dashboard" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <div class="page-head">
    <div>
      <h1>Welcome back, Administrator</h1>
      <p class="muted">Dashboard &middot; overview of movies, shows, bookings and revenue</p>
    </div>
  </div>

  <div class="stats">
    <asp:HyperLink runat="server" CssClass="stat" NavigateUrl="~/Admin/Users.aspx"><span>Users</span><b><asp:Label ID="lblUsers" runat="server"></asp:Label></b></asp:HyperLink>
    <asp:HyperLink runat="server" CssClass="stat" NavigateUrl="~/Admin/Movies.aspx"><span>Movies</span><b><asp:Label ID="lblMovies" runat="server"></asp:Label></b></asp:HyperLink>
    <asp:HyperLink runat="server" CssClass="stat" NavigateUrl="~/Admin/Theatres.aspx"><span>Theatres</span><b><asp:Label ID="lblTheatres" runat="server"></asp:Label></b></asp:HyperLink>
    <asp:HyperLink runat="server" CssClass="stat" NavigateUrl="~/Admin/Shows.aspx"><span>Shows</span><b><asp:Label ID="lblShows" runat="server"></asp:Label></b></asp:HyperLink>
    <asp:HyperLink runat="server" CssClass="stat" NavigateUrl="~/Admin/Bookings.aspx"><span>Bookings</span><b><asp:Label ID="lblBookings" runat="server"></asp:Label></b></asp:HyperLink>
    <asp:HyperLink runat="server" CssClass="stat" NavigateUrl="~/Admin/Payments.aspx"><span>Payments</span><b><asp:Label ID="lblPayments" runat="server"></asp:Label></b></asp:HyperLink>
    <asp:HyperLink runat="server" CssClass="stat wide" NavigateUrl="~/Admin/Reports.aspx"><span>Total revenue</span><b><asp:Label ID="lblRevenue" runat="server"></asp:Label></b></asp:HyperLink>
  </div>

  <h2>Recent System Activity</h2>
  <asp:Label ID="lblNoActivity" runat="server" CssClass="card empty" Visible="false"
      Text="No bookings yet. Activity appears here once customers book tickets."></asp:Label>
  <asp:Panel ID="pnlActivity" runat="server" CssClass="scroll">
    <table class="tbl">
      <thead><tr><th>#</th><th>Customer</th><th>Movie</th><th>Show</th><th>Seats</th><th>Amount</th><th>Status</th></tr></thead>
      <tbody>
        <asp:Repeater ID="rptRecent" runat="server">
          <ItemTemplate>
            <tr>
              <td><%# Eval("BookingID") %></td>
              <td><%# Ui.Esc(Eval("FullName")) %></td>
              <td><%# Ui.Esc(Eval("Title")) %></td>
              <td><%# Ui.Date(Eval("ShowDate"), "dd MMM") %>, <%# Ui.Time(Eval("ShowDate"), Eval("ShowTime")) %></td>
              <td><%# Ui.Esc(Eval("Seats")) %></td>
              <td>&#8377;<%# Convert.ToDecimal(Eval("TotalAmount")).ToString("0") %></td>
              <td><%# Ui.StatusBadge(Eval("BookingStatus")) %></td>
            </tr>
          </ItemTemplate>
        </asp:Repeater>
      </tbody>
    </table>
  </asp:Panel>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        lblUsers.Text = Db.Count("SELECT COUNT(*) FROM Users").ToString();
        lblMovies.Text = Db.Count("SELECT COUNT(*) FROM Movies").ToString();
        lblTheatres.Text = Db.Count("SELECT COUNT(*) FROM Theatres").ToString();
        lblShows.Text = Db.Count("SELECT COUNT(*) FROM Shows").ToString();
        lblBookings.Text = Db.Count("SELECT COUNT(*) FROM Bookings").ToString();
        lblPayments.Text = Db.Count("SELECT COUNT(*) FROM Payments").ToString();
        lblRevenue.Text = "\u20B9" + Db.Sum("SELECT (SELECT ISNULL(SUM(Amount), 0) FROM Payments WHERE PaymentStatus = 'Success') - (SELECT ISNULL(SUM(Amount), 0) FROM Payments WHERE PaymentStatus = 'Refunded')").ToString("N2");

        DataTable recent = Db.Fill(
            @"SELECT TOP 8 b.BookingID, u.FullName, m.Title, s.ShowDate, s.ShowTime, b.TotalAmount, b.BookingStatus,
                     ISNULL(STUFF((SELECT ', ' + RTRIM(se.RowName) + CAST(se.SeatNumber AS VARCHAR(10))
                                   FROM BookingSeats bs INNER JOIN Seats se ON se.SeatID = bs.SeatID
                                   WHERE bs.BookingID = b.BookingID
                                   ORDER BY se.RowName, se.SeatNumber FOR XML PATH('')), 1, 2, ''), '') AS Seats
              FROM Bookings b
              INNER JOIN Users u ON u.UserID = b.UserID
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              ORDER BY b.BookingDate DESC");
        rptRecent.DataSource = recent;
        rptRecent.DataBind();
        pnlActivity.Visible = recent.Rows.Count > 0;
        lblNoActivity.Visible = recent.Rows.Count == 0;
    }
</script>
