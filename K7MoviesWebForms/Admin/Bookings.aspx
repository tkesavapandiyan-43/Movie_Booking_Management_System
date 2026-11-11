<%@ Page Title="Manage bookings" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>BOOKINGS</h1>
    <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>
    <asp:GridView ID="gvBookings" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
        DataKeyNames="BookingID" OnRowCommand="gvBookings_RowCommand">
        <Columns>
            <asp:BoundField DataField="BookingID" HeaderText="#" />
            <asp:BoundField DataField="FullName" HeaderText="Customer" />
            <asp:BoundField DataField="Title" HeaderText="Movie" />
            <asp:BoundField DataField="TheatreName" HeaderText="Theatre" />
            <asp:BoundField DataField="ShowDate" HeaderText="Date" DataFormatString="{0:dd MMM yyyy}" />
            <asp:BoundField DataField="Seats" HeaderText="Seats" />
            <asp:BoundField DataField="TotalAmount" HeaderText="Amount" DataFormatString="{0:0.00}" />
            <asp:BoundField DataField="BookingStatus" HeaderText="Status" />
            <asp:HyperLinkField Text="Receipt" DataNavigateUrlFields="BookingID" DataNavigateUrlFormatString="~/Receipt.aspx?id={0}" />
            <asp:ButtonField ButtonType="Button" CommandName="CancelBooking" Text="Cancel" />
        </Columns>
    </asp:GridView>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack) LoadGrid();
    }

    private void LoadGrid()
    {
        gvBookings.DataSource = Db.Fill(
            @"SELECT TOP 300 b.BookingID, u.FullName, m.Title, t.TheatreName, s.ShowDate, b.TotalAmount, b.BookingStatus,
                     ISNULL(STUFF((SELECT ', ' + RTRIM(se.RowName) + CAST(se.SeatNumber AS VARCHAR(10))
                                   FROM BookingSeats bs INNER JOIN Seats se ON se.SeatID = bs.SeatID
                                   WHERE bs.BookingID = b.BookingID
                                   ORDER BY se.RowName, se.SeatNumber FOR XML PATH('')), 1, 2, ''), '') AS Seats
              FROM Bookings b
              INNER JOIN Users u ON u.UserID = b.UserID
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              ORDER BY b.BookingID DESC");
        gvBookings.DataBind();
    }

    protected void gvBookings_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        if (e.CommandName != "CancelBooking") return;
        int id = Convert.ToInt32(gvBookings.DataKeys[Convert.ToInt32(e.CommandArgument)].Value);
        string error = BookingRules.Cancel(id, null);
        lblMsg.Text = error ?? ("Booking #" + id + " cancelled and refunded.");
        lblMsg.CssClass = error == null ? "alert ok" : "alert err";
        lblMsg.Visible = true;
        LoadGrid();
    }
</script>
