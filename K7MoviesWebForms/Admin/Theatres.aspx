<%@ Page Title="Manage theatres" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <h1>THEATRES</h1>
  <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>

  <section class="card form">
    <h3><asp:Label ID="lblMode" runat="server" Text="Add a theatre"></asp:Label></h3>
    <label>THEATRE NAME</label>
    <asp:TextBox ID="txtName" runat="server" MaxLength="120"></asp:TextBox>
    <asp:RequiredFieldValidator ID="rfvName" runat="server" ControlToValidate="txtName" ErrorMessage="Theatre name is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
    <label>LOCATION</label>
    <asp:TextBox ID="txtLocation" runat="server" MaxLength="200"></asp:TextBox>
    <asp:RequiredFieldValidator ID="rfvLocation" runat="server" ControlToValidate="txtLocation" ErrorMessage="Location is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
    <label>THEATRE OWNER NAME</label>
    <asp:TextBox ID="txtOwner" runat="server" MaxLength="100"></asp:TextBox>
    <asp:RequiredFieldValidator ID="rfvOwner" runat="server" ControlToValidate="txtOwner" ErrorMessage="Theatre owner name is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>

    <div class="two">
      <div>
        <label>OWNER LOGIN USERNAME (optional)</label>
        <asp:TextBox ID="txtOwnerUser" runat="server" MaxLength="50"></asp:TextBox>
        <asp:RegularExpressionValidator ID="revOwnerUser" runat="server" ControlToValidate="txtOwnerUser" ValidationExpression="^[A-Za-z0-9_.]{3,50}$"
            ErrorMessage="Owner username: 3-50 letters, digits, dot or underscore." CssClass="field-err" Display="Dynamic"></asp:RegularExpressionValidator>
      </div>
      <div>
        <label>OWNER PASSWORD (min 6, needed for a new owner)</label>
        <asp:TextBox ID="txtOwnerPass" runat="server" TextMode="Password"></asp:TextBox>
        <asp:RegularExpressionValidator ID="revOwnerPass" runat="server" ControlToValidate="txtOwnerPass" ValidationExpression="^$|^.{6,}$"
            ErrorMessage="Owner password must be at least 6 characters." CssClass="field-err" Display="Dynamic"></asp:RegularExpressionValidator>
        <asp:CustomValidator ID="cvOwnerNew" runat="server" CssClass="field-err" Display="Dynamic"
            ErrorMessage="A new theatre needs an owner username and password." OnServerValidate="cvOwnerNew_ServerValidate"></asp:CustomValidator>
      </div>
    </div>

    <asp:CheckBox ID="chkActive" runat="server" Checked="true" Text=" Active" CssClass="check" />
    <div class="row">
      <asp:Button ID="btnSave" runat="server" Text="SAVE THEATRE" CssClass="btn" OnClick="btnSave_Click" />
      <asp:HyperLink runat="server" NavigateUrl="~/Admin/Theatres.aspx" CssClass="btn ghost" Text="Clear form" />
    </div>
    <asp:ValidationSummary ID="vsTheatre" runat="server" CssClass="alert err" HeaderText="Please fix:" />
  </section>

  <h2>All theatres</h2>
  <asp:GridView ID="gvTheatres" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
      DataKeyNames="TheatreID" OnRowCommand="gvTheatres_RowCommand">
    <Columns>
      <asp:BoundField DataField="TheatreID" HeaderText="ID" />
      <asp:BoundField DataField="TheatreName" HeaderText="Name" />
      <asp:BoundField DataField="Location" HeaderText="Location" />
      <asp:BoundField DataField="OwnerName" HeaderText="Owner" />
      <asp:BoundField DataField="TotalSeats" HeaderText="Seats" />
      <asp:BoundField DataField="IsActive" HeaderText="Active" />
      <asp:HyperLinkField Text="Edit" DataNavigateUrlFields="TheatreID" DataNavigateUrlFormatString="~/Admin/Theatres.aspx?id={0}" />
      <asp:HyperLinkField Text="Seat layout" DataNavigateUrlFields="TheatreID" DataNavigateUrlFormatString="~/Admin/Seats.aspx?id={0}" />
      <asp:ButtonField ButtonType="Button" CommandName="DeleteTheatre" Text="Delete" />
    </Columns>
  </asp:GridView>
</asp:Content>

<script runat="server">
    private int editId;

    protected void Page_Load(object sender, EventArgs e)
    {
        int.TryParse(Request.QueryString["id"], out editId);
        if (!IsPostBack)
        {
            if (editId > 0) LoadForEdit();
            LoadGrid();
        }
    }

    private void LoadForEdit()
    {
        DataTable dt = Db.Fill("SELECT * FROM Theatres WHERE TheatreID = @T", Db.P("@T", editId));
        if (dt.Rows.Count == 0) { Message("Theatre not found.", false); editId = 0; return; }
        DataRow r = dt.Rows[0];
        lblMode.Text = "Edit theatre #" + editId;
        txtName.Text = (string)r["TheatreName"];
        txtLocation.Text = Convert.ToString(r["Location"]);
        txtOwner.Text = Convert.ToString(r["OwnerName"]);
        chkActive.Checked = (bool)r["IsActive"];
        DataTable owner = Db.Fill("SELECT Username FROM Users WHERE TheatreID = @T AND Role = 'TheatreOwner'", Db.P("@T", editId));
        if (owner.Rows.Count > 0) txtOwnerUser.Text = (string)owner.Rows[0]["Username"];
    }

    private void LoadGrid()
    {
        gvTheatres.DataSource = Db.Fill("SELECT TheatreID, TheatreName, Location, OwnerName, TotalSeats, IsActive FROM Theatres ORDER BY TheatreName");
        gvTheatres.DataBind();
    }

    private void Message(string text, bool ok)
    {
        lblMsg.Text = text;
        lblMsg.CssClass = ok ? "alert ok" : "alert err";
        lblMsg.Visible = true;
    }

    protected void cvOwnerNew_ServerValidate(object source, ServerValidateEventArgs args)
    {
        // a new theatre must be created together with its owner login
        args.IsValid = editId > 0 || (!string.IsNullOrWhiteSpace(txtOwnerUser.Text) && txtOwnerPass.Text.Length >= 6);
    }

    protected void btnSave_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;

        DataTable dt = editId > 0
            ? Db.Fill("SELECT * FROM Theatres WHERE TheatreID = @T", Db.P("@T", editId))
            : Db.Fill("SELECT * FROM Theatres WHERE 1 = 0");
        if (dt.Rows.Count == 0 && editId > 0) { Message("Theatre not found.", false); return; }

        DataRow r = editId > 0 ? dt.Rows[0] : Db.AddRow(dt, "TheatreID");
        r["TheatreName"] = txtName.Text.Trim();
        r["Location"] = txtLocation.Text.Trim();
        r["OwnerName"] = txtOwner.Text.Trim();
        r["IsActive"] = chkActive.Checked;
        if (editId == 0) r["TotalSeats"] = 0;

        try
        {
            Db.Save(dt, "Theatres", "TheatreID");
            int theatreId = (int)r["TheatreID"];
            TheatreRules.SaveOwner(theatreId, txtOwner.Text, txtOwnerUser.Text, txtOwnerPass.Text);
            Response.Redirect("~/Admin/Theatres.aspx?saved=1", false);
        }
        catch (ArgumentException ex) { Message(ex.Message, false); LoadGrid(); }
        catch (SqlException ex) { Message(ex.Message, false); LoadGrid(); }
    }

    protected void gvTheatres_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        if (e.CommandName != "DeleteTheatre") return;
        int id = Convert.ToInt32(gvTheatres.DataKeys[Convert.ToInt32(e.CommandArgument)].Value);
        DataTable dt = Db.Fill("SELECT * FROM Theatres WHERE TheatreID = @T", Db.P("@T", id));
        if (dt.Rows.Count == 0) return;
        try
        {
            dt.Rows[0].Delete();
            Db.Save(dt, "Theatres", "TheatreID");
            Message("Theatre deleted.", true);
        }
        catch (SqlException) { Message("This theatre has shows, bookings or owners and cannot be deleted. Mark it inactive instead.", false); }
        LoadGrid();
    }
</script>
