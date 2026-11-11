<%@ Page Title="Manage users" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>USERS</h1>
    <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>
    <asp:GridView ID="gvUsers" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
        DataKeyNames="UserID" OnRowCommand="gvUsers_RowCommand">
        <Columns>
            <asp:BoundField DataField="UserID" HeaderText="ID" />
            <asp:BoundField DataField="Username" HeaderText="Username" NullDisplayText="-" />
            <asp:BoundField DataField="FullName" HeaderText="Name" />
            <asp:BoundField DataField="Email" HeaderText="Email" />
            <asp:BoundField DataField="Mobile" HeaderText="Mobile" />
            <asp:BoundField DataField="Role" HeaderText="Role" />
            <asp:ButtonField ButtonType="Button" CommandName="ToggleRole" Text="Make Admin / User" />
            <asp:ButtonField ButtonType="Button" CommandName="DeleteUser" Text="Delete" />
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
        gvUsers.DataSource = Db.Fill("SELECT UserID, Username, FullName, Email, Mobile, Role FROM Users ORDER BY UserID");
        gvUsers.DataBind();
    }

    private void Message(string text, bool ok)
    {
        lblMsg.Text = text;
        lblMsg.CssClass = ok ? "alert ok" : "alert err";
        lblMsg.Visible = true;
    }

    protected void gvUsers_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        int id = Convert.ToInt32(gvUsers.DataKeys[Convert.ToInt32(e.CommandArgument)].Value);
        if (id == UserContext.CurrentUserId())
        {
            Message("You cannot change or delete your own account here.", false);
            return;
        }

        DataTable dt = Db.Fill("SELECT * FROM Users WHERE UserID = @U", Db.P("@U", id));
        if (dt.Rows.Count == 0) return;
        if (e.CommandName == "ToggleRole" && (string)dt.Rows[0]["Role"] == "TheatreOwner")
        { Message("Theatre owners are managed on the Theatres page.", false); LoadGrid(); return; }
        try
        {
            if (e.CommandName == "ToggleRole")
            {
                DataRow r = dt.Rows[0];
                r["Role"] = (string)r["Role"] == "Admin" ? "User" : "Admin";
                Db.Save(dt, "Users", "UserID");
                Message("Role changed.", true);
            }
            else if (e.CommandName == "DeleteUser")
            {
                dt.Rows[0].Delete();
                Db.Save(dt, "Users", "UserID");
                Message("User deleted.", true);
            }
        }
        catch (SqlException) { Message("This user has bookings and cannot be deleted.", false); }
        LoadGrid();
    }
</script>
