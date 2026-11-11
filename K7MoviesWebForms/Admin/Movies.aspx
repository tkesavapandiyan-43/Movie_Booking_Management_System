<%@ Page Title="Manage movies" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h1>MOVIES</h1>
    <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>

    <section class="card form">
        <h3><asp:Label ID="lblMode" runat="server" Text="Add a movie"></asp:Label></h3>
        <label>TITLE</label>
        <asp:TextBox ID="txtTitle" runat="server" MaxLength="150"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvTitle" runat="server" ControlToValidate="txtTitle" ErrorMessage="Title is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>

        <div class="two">
            <div>
                <label>GENRE</label>
                <asp:TextBox ID="txtGenre" runat="server" MaxLength="80"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvGenre" runat="server" ControlToValidate="txtGenre" ErrorMessage="Genre is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
            </div>
            <div>
                <label>LANGUAGE</label>
                <asp:TextBox ID="txtLanguage" runat="server" MaxLength="50">Tamil</asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvLanguage" runat="server" ControlToValidate="txtLanguage" ErrorMessage="Language is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
            </div>
        </div>

        <div class="two">
            <div>
                <label>DURATION (MINUTES)</label>
                <asp:TextBox ID="txtDuration" runat="server" TextMode="Number">120</asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvDuration" runat="server" ControlToValidate="txtDuration" ErrorMessage="Duration is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
                <asp:RangeValidator ID="rngDuration" runat="server" ControlToValidate="txtDuration" Type="Integer" MinimumValue="1" MaximumValue="600"
                    ErrorMessage="Duration must be 1 to 600 minutes." CssClass="field-err" Display="Dynamic"></asp:RangeValidator>
            </div>
            <div>
                <label>RATING (0-10, OPTIONAL)</label>
                <asp:TextBox ID="txtRating" runat="server"></asp:TextBox>
                <asp:RangeValidator ID="rngRating" runat="server" ControlToValidate="txtRating" Type="Double" MinimumValue="0" MaximumValue="10"
                    ErrorMessage="Rating must be between 0 and 10." CssClass="field-err" Display="Dynamic"></asp:RangeValidator>
            </div>
        </div>

        <div class="two">
            <div>
                <label>RELEASE DATE</label>
                <asp:TextBox ID="txtRelease" runat="server" TextMode="Date"></asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvRelease" runat="server" ControlToValidate="txtRelease" ErrorMessage="Release date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
            </div>
            <div>
                <label>BOOKING STATUS</label>
                <asp:DropDownList ID="ddlStatus" runat="server">
                    <asp:ListItem>Open</asp:ListItem>
                    <asp:ListItem>Closed</asp:ListItem>
                </asp:DropDownList>
            </div>
        </div>

        <label>POSTER (e.g. /posters/file.jpg, optional)</label>
        <asp:TextBox ID="txtPoster" runat="server" MaxLength="500"></asp:TextBox>
        <label>DESCRIPTION (optional)</label>
        <asp:TextBox ID="txtDescription" runat="server" TextMode="MultiLine" Rows="3" MaxLength="1000"></asp:TextBox>
        <asp:CheckBox ID="chkActive" runat="server" Checked="true" Text=" Active (visible to customers)" CssClass="check" />

        <div class="row">
            <asp:Button ID="btnSave" runat="server" Text="SAVE MOVIE" CssClass="btn" OnClick="btnSave_Click" />
            <asp:HyperLink ID="lnkCancel" runat="server" NavigateUrl="~/Admin/Movies.aspx" CssClass="btn ghost" Text="Clear form" />
        </div>
        <asp:ValidationSummary ID="vsMovie" runat="server" CssClass="alert err" HeaderText="Please fix:" />
    </section>

    <h2>All movies</h2>
    <asp:GridView ID="gvMovies" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
        DataKeyNames="MovieID" OnRowCommand="gvMovies_RowCommand">
        <Columns>
            <asp:BoundField DataField="MovieID" HeaderText="ID" />
            <asp:BoundField DataField="Title" HeaderText="Title" />
            <asp:BoundField DataField="Language" HeaderText="Language" />
            <asp:BoundField DataField="ReleaseDate" HeaderText="Release" DataFormatString="{0:dd MMM yyyy}" />
            <asp:BoundField DataField="Rating" HeaderText="Rating" DataFormatString="{0:0.0}" NullDisplayText="-" />
            <asp:BoundField DataField="BookingStatus" HeaderText="Booking" />
            <asp:HyperLinkField Text="Edit" DataNavigateUrlFields="MovieID" DataNavigateUrlFormatString="~/Admin/Movies.aspx?id={0}" />
            <asp:ButtonField ButtonType="Button" CommandName="ToggleStatus" Text="Open / Close" />
            <asp:ButtonField ButtonType="Button" CommandName="DeleteMovie" Text="Delete" />
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
            txtRelease.Text = DateTime.Today.ToString("yyyy-MM-dd");
            if (editId > 0) LoadForEdit();
            LoadGrid();
        }
    }

    private void LoadForEdit()
    {
        DataTable dt = Db.Fill("SELECT * FROM Movies WHERE MovieID = @M", Db.P("@M", editId));
        if (dt.Rows.Count == 0) { Message("Movie not found.", false); editId = 0; return; }
        DataRow r = dt.Rows[0];
        lblMode.Text = "Edit movie #" + editId;
        txtTitle.Text = (string)r["Title"];
        txtGenre.Text = Convert.ToString(r["Genre"]);
        txtLanguage.Text = Convert.ToString(r["Language"]);
        txtDuration.Text = r["DurationMinutes"].ToString();
        txtRating.Text = r["Rating"] == DBNull.Value ? "" : Convert.ToDecimal(r["Rating"]).ToString("0.0");
        txtRelease.Text = r["ReleaseDate"] == DBNull.Value ? "" : Convert.ToDateTime(r["ReleaseDate"]).ToString("yyyy-MM-dd");
        txtPoster.Text = Convert.ToString(r["PosterPath"]);
        txtDescription.Text = Convert.ToString(r["Description"]);
        ddlStatus.SelectedValue = Convert.ToString(r["BookingStatus"]);
        chkActive.Checked = (bool)r["IsActive"];
    }

    private void LoadGrid()
    {
        gvMovies.DataSource = Db.Fill(
            "SELECT MovieID, Title, Language, ReleaseDate, Rating, BookingStatus FROM Movies ORDER BY MovieID DESC");
        gvMovies.DataBind();
    }

    private void Message(string text, bool ok)
    {
        lblMsg.Text = text;
        lblMsg.CssClass = ok ? "alert ok" : "alert err";
        lblMsg.Visible = true;
    }

    protected void btnSave_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;

        DataTable dt = editId > 0
            ? Db.Fill("SELECT * FROM Movies WHERE MovieID = @M", Db.P("@M", editId))
            : Db.Fill("SELECT * FROM Movies WHERE 1 = 0");
        if (dt.Rows.Count == 0 && editId > 0) { Message("Movie not found.", false); return; }

        DataRow r = editId > 0 ? dt.Rows[0] : Db.AddRow(dt, "MovieID");
        r["Title"] = txtTitle.Text.Trim();
        r["Genre"] = txtGenre.Text.Trim();
        r["Language"] = txtLanguage.Text.Trim();
        r["DurationMinutes"] = int.Parse(txtDuration.Text);
        r["ReleaseDate"] = DateTime.Parse(txtRelease.Text);
        if (string.IsNullOrWhiteSpace(txtRating.Text)) r["Rating"] = DBNull.Value;
        else r["Rating"] = decimal.Parse(txtRating.Text);
        r["Description"] = string.IsNullOrWhiteSpace(txtDescription.Text) ? (object)DBNull.Value : txtDescription.Text.Trim();
        r["PosterPath"] = string.IsNullOrWhiteSpace(txtPoster.Text) ? (object)DBNull.Value : txtPoster.Text.Trim();
        r["IsActive"] = chkActive.Checked;
        r["BookingStatus"] = ddlStatus.SelectedValue;

        try
        {
            Db.Save(dt, "Movies", "MovieID");
            Response.Redirect("~/Admin/Movies.aspx?saved=1", false);
        }
        catch (SqlException ex) { Message(ex.Message, false); LoadGrid(); }
    }

    protected void gvMovies_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        int id = Convert.ToInt32(gvMovies.DataKeys[Convert.ToInt32(e.CommandArgument)].Value);
        DataTable dt = Db.Fill("SELECT * FROM Movies WHERE MovieID = @M", Db.P("@M", id));
        if (dt.Rows.Count == 0) return;
        try
        {
            if (e.CommandName == "ToggleStatus")
            {
                DataRow r = dt.Rows[0];
                r["BookingStatus"] = (string)r["BookingStatus"] == "Open" ? "Closed" : "Open";
                Db.Save(dt, "Movies", "MovieID");
                Message("Booking status changed.", true);
            }
            else if (e.CommandName == "DeleteMovie")
            {
                dt.Rows[0].Delete();
                Db.Save(dt, "Movies", "MovieID");
                Message("Movie deleted.", true);
            }
        }
        catch (SqlException)
        {
            Message("This movie has shows or bookings, so it cannot be deleted. Close it instead.", false);
        }
        LoadGrid();
    }
</script>
