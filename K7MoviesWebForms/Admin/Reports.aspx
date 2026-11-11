<%@ Page Title="Reports" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>REPORTS &amp; RECEIPTS</h1>

    <asp:Panel ID="pnlFilter" runat="server" CssClass="filters card" DefaultButton="btnApply">
        <label>FROM<asp:TextBox ID="txtFrom" runat="server" TextMode="Date"></asp:TextBox></label>
        <asp:RequiredFieldValidator ID="rfvFrom" runat="server" ControlToValidate="txtFrom" ErrorMessage="Start date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
        <label>TO<asp:TextBox ID="txtTo" runat="server" TextMode="Date"></asp:TextBox></label>
        <asp:RequiredFieldValidator ID="rfvTo" runat="server" ControlToValidate="txtTo" ErrorMessage="End date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
        <asp:CompareValidator ID="cmpDates" runat="server" ControlToValidate="txtTo" ControlToCompare="txtFrom" Operator="GreaterThanEqual" Type="Date"
            ErrorMessage="End date must be on or after the start date." CssClass="field-err" Display="Dynamic"></asp:CompareValidator>
        <label>SEARCH<asp:TextBox ID="txtQ" runat="server" placeholder="customer, movie, theatre, reference"></asp:TextBox></label>
        <label>STATUS
            <asp:DropDownList ID="ddlStatus" runat="server">
                <asp:ListItem>All</asp:ListItem>
                <asp:ListItem>Confirmed</asp:ListItem>
                <asp:ListItem>Cancelled</asp:ListItem>
                <asp:ListItem>Success</asp:ListItem>
            </asp:DropDownList>
        </label>
        <asp:Button ID="btnApply" runat="server" Text="APPLY" CssClass="btn" OnClick="btnApply_Click" />
        <asp:ValidationSummary ID="vsReport" runat="server" CssClass="alert err" HeaderText="Please fix:" />
    </asp:Panel>

    <div class="stats">
        <div class="stat"><span>Revenue</span><b><asp:Label ID="lblRevenue" runat="server"></asp:Label></b></div>
        <div class="stat"><span>Bookings</span><b><asp:Label ID="lblBookings" runat="server"></asp:Label></b></div>
        <div class="stat"><span>Tickets sold</span><b><asp:Label ID="lblTickets" runat="server"></asp:Label></b></div>
        <div class="stat"><span>Successful payments</span><b><asp:Label ID="lblPayments" runat="server"></asp:Label></b></div>
    </div>

    <asp:GridView ID="gvRows" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None" EmptyDataText="No records for this filter.">
        <Columns>
            <asp:BoundField DataField="BookingID" HeaderText="#" />
            <asp:BoundField DataField="FullName" HeaderText="Customer" />
            <asp:BoundField DataField="Title" HeaderText="Movie" />
            <asp:BoundField DataField="TheatreName" HeaderText="Theatre" />
            <asp:BoundField DataField="ShowDate" HeaderText="Show" DataFormatString="{0:dd MMM yyyy}" />
            <asp:BoundField DataField="Tickets" HeaderText="Tickets" />
            <asp:BoundField DataField="TotalAmount" HeaderText="Amount" DataFormatString="{0:0.00}" />
            <asp:BoundField DataField="BookingStatus" HeaderText="Booking" />
            <asp:BoundField DataField="PaymentStatus" HeaderText="Payment" />
            <asp:BoundField DataField="TransactionReference" HeaderText="Reference" />
        </Columns>
    </asp:GridView>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            txtTo.Text = DateTime.Today.ToString("yyyy-MM-dd");
            txtFrom.Text = DateTime.Today.AddDays(-30).ToString("yyyy-MM-dd");
            RunReport();
        }
    }

    protected void btnApply_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;
        RunReport();
    }

    private void RunReport()
    {
        DateTime from, to;
        if (!DateTime.TryParse(txtFrom.Text, out from) || !DateTime.TryParse(txtTo.Text, out to)) return;
        DateTime f = from.Date;
        DateTime t = to.Date.AddDays(1);            // end date is inclusive
        string like = "%" + txtQ.Text.Trim() + "%";
        string status = ddlStatus.SelectedValue;

        lblRevenue.Text = "\u20B9" + Db.Sum(
            "SELECT (SELECT ISNULL(SUM(Amount), 0) FROM Payments WHERE PaymentStatus = 'Success' AND PaymentDate >= @F AND PaymentDate < @T) - (SELECT ISNULL(SUM(Amount), 0) FROM Payments WHERE PaymentStatus = 'Refunded' AND PaymentDate >= @F AND PaymentDate < @T)",
            Db.P("@F", f), Db.P("@T", t)).ToString("N2");
        lblBookings.Text = Db.Count(
            "SELECT COUNT(*) FROM Bookings WHERE BookingStatus <> 'Cancelled' AND BookingDate >= @F AND BookingDate < @T",
            Db.P("@F", f), Db.P("@T", t)).ToString();
        lblTickets.Text = Db.Count(
            @"SELECT COUNT(*) FROM BookingSeats bs INNER JOIN Bookings b ON b.BookingID = bs.BookingID
              WHERE b.BookingStatus <> 'Cancelled' AND b.BookingDate >= @F AND b.BookingDate < @T",
            Db.P("@F", f), Db.P("@T", t)).ToString();
        lblPayments.Text = Db.Count(
            "SELECT COUNT(*) FROM Payments WHERE PaymentStatus = 'Success' AND PaymentDate >= @F AND PaymentDate < @T",
            Db.P("@F", f), Db.P("@T", t)).ToString();

        gvRows.DataSource = Db.Fill(
            @"SELECT b.BookingID, u.FullName, m.Title, t.TheatreName, s.ShowDate, b.TotalAmount, b.BookingStatus,
                     (SELECT COUNT(*) FROM BookingSeats x WHERE x.BookingID = b.BookingID) AS Tickets,
                     p.PaymentStatus, p.TransactionReference
              FROM Bookings b
              INNER JOIN Users u ON u.UserID = b.UserID
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              OUTER APPLY (SELECT TOP 1 PaymentStatus, TransactionReference FROM Payments
                           WHERE BookingID = b.BookingID ORDER BY PaymentID DESC) p
              WHERE b.BookingDate >= @F AND b.BookingDate < @T
                AND (u.FullName LIKE @S OR m.Title LIKE @S OR t.TheatreName LIKE @S OR ISNULL(p.TransactionReference, '') LIKE @S)
                AND (@Status = 'All' OR b.BookingStatus = @Status OR ISNULL(p.PaymentStatus, '') = @Status)
              ORDER BY b.BookingID DESC",
            Db.P("@F", f), Db.P("@T", t), Db.P("@S", like), Db.P("@Status", status));
        gvRows.DataBind();
    }
</script>
