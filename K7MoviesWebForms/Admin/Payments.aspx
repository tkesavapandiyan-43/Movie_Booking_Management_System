<%@ Page Title="Payments" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>PAYMENTS</h1>
    <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>

    <asp:Panel ID="pnlSearch" runat="server" CssClass="filters card" DefaultButton="btnSearch">
        <label>SEARCH<asp:TextBox ID="txtSearch" runat="server" placeholder="customer, movie, method, reference"></asp:TextBox></label>
        <asp:Button ID="btnSearch" runat="server" Text="SEARCH" CssClass="btn" OnClick="btnSearch_Click" />
    </asp:Panel>

    <asp:GridView ID="gvPayments" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
        DataKeyNames="PaymentID" OnRowCommand="gvPayments_RowCommand" EmptyDataText="No payments found.">
        <Columns>
            <asp:BoundField DataField="PaymentID" HeaderText="Payment" />
            <asp:BoundField DataField="BookingID" HeaderText="Booking" />
            <asp:BoundField DataField="FullName" HeaderText="Customer" />
            <asp:BoundField DataField="Title" HeaderText="Movie" />
            <asp:BoundField DataField="PaymentMethod" HeaderText="Method" />
            <asp:BoundField DataField="TransactionReference" HeaderText="Reference" />
            <asp:BoundField DataField="Amount" HeaderText="Amount" DataFormatString="{0:0.00}" />
            <asp:BoundField DataField="PaymentDate" HeaderText="Date" DataFormatString="{0:dd MMM yyyy HH:mm}" />
            <asp:BoundField DataField="PaymentStatus" HeaderText="Status" />
            <asp:ButtonField ButtonType="Button" CommandName="DeletePayment" Text="Delete" />
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
        string like = "%" + txtSearch.Text.Trim() + "%";
        gvPayments.DataSource = Db.Fill(
            @"SELECT p.PaymentID, p.BookingID, u.FullName, m.Title, p.PaymentMethod, p.TransactionReference,
                     p.Amount, p.PaymentDate, p.PaymentStatus
              FROM Payments p
              INNER JOIN Bookings b ON b.BookingID = p.BookingID
              INNER JOIN Users u ON u.UserID = b.UserID
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              WHERE u.FullName LIKE @S OR m.Title LIKE @S OR p.PaymentMethod LIKE @S
                 OR ISNULL(p.TransactionReference, '') LIKE @S OR p.PaymentStatus LIKE @S
              ORDER BY p.PaymentDate DESC, p.PaymentID DESC",
            Db.P("@S", like));
        gvPayments.DataBind();
    }

    protected void btnSearch_Click(object sender, EventArgs e)
    {
        LoadGrid();
    }

    protected void gvPayments_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        if (e.CommandName != "DeletePayment") return;
        int id = Convert.ToInt32(gvPayments.DataKeys[Convert.ToInt32(e.CommandArgument)].Value);
        DataTable dt = Db.Fill("SELECT * FROM Payments WHERE PaymentID = @P", Db.P("@P", id));
        if (dt.Rows.Count == 0) return;
        dt.Rows[0].Delete();
        try
        {
            Db.Save(dt, "Payments", "PaymentID");
            lblMsg.Text = "Payment record deleted.";
            lblMsg.CssClass = "alert ok";
        }
        catch (SqlException ex)
        {
            lblMsg.Text = ex.Message;
            lblMsg.CssClass = "alert err";
        }
        lblMsg.Visible = true;
        LoadGrid();
    }
</script>
