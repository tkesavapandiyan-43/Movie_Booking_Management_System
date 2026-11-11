<%@ Page Title="My bookings" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Data" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <h1>My bookings</h1>
  <asp:Label ID="lblMsg" runat="server" CssClass="alert ok" Visible="false"></asp:Label>
  <asp:Label ID="lblNone" runat="server" CssClass="muted" Visible="false" Text="You have no bookings yet. "></asp:Label>
  <asp:HyperLink ID="lnkBrowse" runat="server" NavigateUrl="~/Default.aspx" Text="Browse movies" Visible="false"></asp:HyperLink>

  <asp:GridView ID="gvBookings" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
      DataKeyNames="BookingID" OnRowCommand="gvBookings_RowCommand" ShowHeaderWhenEmpty="false">
    <Columns>
      <asp:BoundField DataField="BookingID" HeaderText="#" />
      <asp:BoundField DataField="Title" HeaderText="Movie" />
      <asp:BoundField DataField="TheatreName" HeaderText="Theatre" />
      <asp:TemplateField HeaderText="Show">
        <ItemTemplate>
          <%# Ui.Date(Eval("ShowDate"), "dd MMM yyyy") %>, <%# Ui.Time(Eval("ShowDate"), Eval("ShowTime")) %>
        </ItemTemplate>
      </asp:TemplateField>
      <asp:BoundField DataField="Seats" HeaderText="Seats" />
      <asp:TemplateField HeaderText="Amount">
        <ItemTemplate>&#8377;<%# Convert.ToDecimal(Eval("TotalAmount")).ToString("0.00") %></ItemTemplate>
      </asp:TemplateField>
      <asp:TemplateField HeaderText="Status">
        <ItemTemplate><%# Ui.StatusBadge(Eval("BookingStatus")) %></ItemTemplate>
      </asp:TemplateField>
      <asp:TemplateField HeaderText="">
        <ItemTemplate>
          <asp:HyperLink runat="server" CssClass="btn small ghost" Text="Receipt"
              NavigateUrl='<%# "~/Receipt.aspx?id=" + Eval("BookingID") %>'></asp:HyperLink>
          <asp:HyperLink runat="server" CssClass="btn small ghost" Text="Add seats"
              NavigateUrl='<%# "~/Seats.aspx?show=" + Eval("ShowID") + "&booking=" + Eval("BookingID") %>'
              Visible='<%# CanChange(Eval("BookingStatus"), Eval("ShowDate"), Eval("ShowTime")) %>'></asp:HyperLink>
          <asp:HyperLink runat="server" CssClass="btn small ghost" Text="Cancel seats"
              NavigateUrl='<%# "~/CancelSeats.aspx?id=" + Eval("BookingID") %>'
              Visible='<%# CanChange(Eval("BookingStatus"), Eval("ShowDate"), Eval("ShowTime")) %>'></asp:HyperLink>
          <asp:Button runat="server" CssClass="btn small danger" Text="Cancel all" CommandName="CancelBooking"
              CommandArgument='<%# Eval("BookingID") %>' OnClientClick="return confirm('Cancel the whole booking and refund it?');"
              Visible='<%# CanChange(Eval("BookingStatus"), Eval("ShowDate"), Eval("ShowTime")) %>' />
        </ItemTemplate>
      </asp:TemplateField>
    </Columns>
  </asp:GridView>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["cancelled"] == "1")
            {
                lblMsg.Text = "The seats were cancelled and refunded.";
                lblMsg.Visible = true;
            }
            LoadBookings();
        }
    }

    /// <summary>Bookings can be changed only while confirmed and before the show starts.</summary>
    protected bool CanChange(object status, object showDate, object showTime)
    {
        DateTime start = Convert.ToDateTime(showDate).Date + (TimeSpan)showTime;
        return Convert.ToString(status) == "Confirmed" && start > DateTime.Now;
    }

    private void LoadBookings()
    {
        DataTable dt = Db.Fill(
            @"SELECT b.BookingID, s.ShowID, m.Title, t.TheatreName, s.ShowDate, s.ShowTime, b.TotalAmount, b.BookingStatus,
                     ISNULL(STUFF((SELECT ', ' + RTRIM(se.RowName) + CAST(se.SeatNumber AS VARCHAR(10))
                                   FROM BookingSeats bs INNER JOIN Seats se ON se.SeatID = bs.SeatID
                                   WHERE bs.BookingID = b.BookingID
                                   ORDER BY se.RowName, se.SeatNumber FOR XML PATH('')), 1, 2, ''), '') AS Seats
              FROM Bookings b
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              WHERE b.UserID = @U
              ORDER BY b.BookingDate DESC", Db.P("@U", UserContext.CurrentUserId()));

        gvBookings.DataSource = dt;
        gvBookings.DataBind();
        lblNone.Visible = dt.Rows.Count == 0;
        lnkBrowse.Visible = dt.Rows.Count == 0;
    }

    protected void gvBookings_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        if (e.CommandName != "CancelBooking") return;
        int bookingId = Convert.ToInt32(e.CommandArgument);

        string error = BookingRules.Cancel(bookingId, UserContext.CurrentUserId());
        lblMsg.CssClass = error == null ? "alert ok" : "alert err";
        lblMsg.Text = error ?? ("Booking #" + bookingId + " cancelled and refunded.");
        lblMsg.Visible = true;
        LoadBookings();
    }
</script>
