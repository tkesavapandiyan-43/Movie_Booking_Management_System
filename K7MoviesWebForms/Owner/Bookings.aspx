<%@ Page Title="Booked tickets" Language="C#" MasterPageFile="~/Owner/Owner.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Globalization" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <div class="page-head">
    <div>
      <h1>Booked tickets</h1>
      <p class="muted">Every booking for your theatre in the chosen dates.</p>
    </div>
  </div>

  <asp:Panel ID="pnlFilter" runat="server" CssClass="filters card" DefaultButton="btnApply">
    <label>FROM<asp:TextBox ID="txtFrom" runat="server" TextMode="Date"></asp:TextBox></label>
    <asp:RequiredFieldValidator ID="rfvFrom" runat="server" ControlToValidate="txtFrom" ErrorMessage="Start date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
    <label>TO<asp:TextBox ID="txtTo" runat="server" TextMode="Date"></asp:TextBox></label>
    <asp:RequiredFieldValidator ID="rfvTo" runat="server" ControlToValidate="txtTo" ErrorMessage="End date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
    <asp:CompareValidator ID="cmpDates" runat="server" ControlToValidate="txtTo" ControlToCompare="txtFrom" Operator="GreaterThanEqual" Type="Date"
        ErrorMessage="End date must be on or after the start date." CssClass="field-err" Display="Dynamic"></asp:CompareValidator>
    <label>STATUS
      <asp:DropDownList ID="ddlStatus" runat="server">
        <asp:ListItem>All</asp:ListItem>
        <asp:ListItem>Confirmed</asp:ListItem>
        <asp:ListItem>Cancelled</asp:ListItem>
      </asp:DropDownList>
    </label>
    <label>SEARCH<asp:TextBox ID="txtSearch" runat="server" placeholder="customer or movie"></asp:TextBox></label>
    <asp:Button ID="btnApply" runat="server" Text="APPLY" CssClass="btn" OnClick="btnApply_Click" />
    <asp:ValidationSummary ID="vsFilter" runat="server" CssClass="alert err" HeaderText="Please fix:" />
  </asp:Panel>
  <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>

  <asp:GridView ID="gvBookings" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None" EmptyDataText="No bookings in this range.">
    <Columns>
      <asp:BoundField DataField="BookingID" HeaderText="#" />
      <asp:BoundField DataField="ShowDate" HeaderText="Date" DataFormatString="{0:dd MMM yyyy}" />
      <asp:BoundField DataField="Time" HeaderText="Show time" />
      <asp:BoundField DataField="Customer" HeaderText="Customer" />
      <asp:BoundField DataField="Movie" HeaderText="Movie" />
      <asp:BoundField DataField="Seats" HeaderText="Seats" />
      <asp:BoundField DataField="Tickets" HeaderText="Tickets" />
      <asp:BoundField DataField="TotalAmount" HeaderText="Amount" DataFormatString="&#8377;{0:0.00}" HtmlEncode="false" />
      <asp:TemplateField HeaderText="Status">
        <ItemTemplate><%# Ui.StatusBadge(Eval("BookingStatus")) %></ItemTemplate>
      </asp:TemplateField>
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
            lblError.Text = "Your account is not linked to a theatre. Ask the admin to set it on the Theatres page.";
            lblError.Visible = true;
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
        DataTable dt = Db.Fill(
            @"SELECT b.BookingID, sh.ShowDate, sh.ShowTime, sh.ShowEndTime, u.FullName AS Customer, m.Title AS Movie,
                     ISNULL(STUFF((SELECT ', ' + RTRIM(se.RowName) + CAST(se.SeatNumber AS VARCHAR(10))
                                   FROM BookingSeats bs INNER JOIN Seats se ON se.SeatID = bs.SeatID
                                   WHERE bs.BookingID = b.BookingID
                                   ORDER BY se.RowName, se.SeatNumber FOR XML PATH('')), 1, 2, ''), '') AS Seats,
                     (SELECT COUNT(*) FROM BookingSeats x WHERE x.BookingID = b.BookingID) AS Tickets,
                     b.TotalAmount, b.BookingStatus
              FROM Bookings b
              INNER JOIN Shows sh ON sh.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = sh.MovieID
              INNER JOIN Users u ON u.UserID = b.UserID
              WHERE sh.TheatreID = @T AND sh.ShowDate BETWEEN @F AND @EndDate
                AND (@Status = 'All' OR b.BookingStatus = @Status)
                AND (u.FullName LIKE @S OR m.Title LIKE @S)
              ORDER BY sh.ShowDate, sh.SlotNumber, b.BookingID",
            Db.P("@T", theatreId),
            Db.P("@F", DateTime.Parse(txtFrom.Text).Date),
            Db.P("@EndDate", DateTime.Parse(txtTo.Text).Date),
            Db.P("@Status", ddlStatus.SelectedValue),
            Db.P("@S", "%" + txtSearch.Text.Trim() + "%"));

        dt.Columns.Add("Time", typeof(string));
        foreach (DataRow r in dt.Rows)
            r["Time"] = DateTime.Today.Add((TimeSpan)r["ShowTime"]).ToString("hh:mm tt", CultureInfo.InvariantCulture) + " - " +
                        DateTime.Today.Add((TimeSpan)r["ShowEndTime"]).ToString("hh:mm tt", CultureInfo.InvariantCulture);

        gvBookings.DataSource = dt;
        gvBookings.DataBind();
    }
</script>
