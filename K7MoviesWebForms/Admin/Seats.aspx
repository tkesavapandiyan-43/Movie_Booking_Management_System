<%@ Page Title="Seat layout" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Collections.Generic" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <asp:HyperLink runat="server" NavigateUrl="~/Admin/Theatres.aspx" CssClass="back">&larr; Back to theatres</asp:HyperLink>
    <h1>SEAT LAYOUT: <asp:Label ID="lblTheatre" runat="server"></asp:Label></h1>
    <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>

    <section class="card form">
        <h3>Generate layout</h3>
        <p class="muted">This replaces the current layout. It is blocked if any seat already has a booking.</p>
        <div class="two">
            <div>
                <label>ROWS (1-10)</label>
                <asp:TextBox ID="txtRows" runat="server" TextMode="Number">10</asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvRows" runat="server" ControlToValidate="txtRows" ErrorMessage="Rows is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
                <asp:RangeValidator ID="rngRows" runat="server" ControlToValidate="txtRows" Type="Integer" MinimumValue="1" MaximumValue="10"
                    ErrorMessage="Rows must be 1 to 10." CssClass="field-err" Display="Dynamic"></asp:RangeValidator>
            </div>
            <div>
                <label>SEATS PER ROW (1-30)</label>
                <asp:TextBox ID="txtPerRow" runat="server" TextMode="Number">10</asp:TextBox>
                <asp:RequiredFieldValidator ID="rfvPerRow" runat="server" ControlToValidate="txtPerRow" ErrorMessage="Seats per row is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
                <asp:RangeValidator ID="rngPerRow" runat="server" ControlToValidate="txtPerRow" Type="Integer" MinimumValue="1" MaximumValue="30"
                    ErrorMessage="Seats per row must be 1 to 30." CssClass="field-err" Display="Dynamic"></asp:RangeValidator>
            </div>
        </div>
        <asp:Button ID="btnGenerate" runat="server" Text="GENERATE LAYOUT" CssClass="btn" OnClick="btnGenerate_Click" OnClientClick="return confirm('Rebuild the whole layout?');" />
        <asp:ValidationSummary ID="vsSeats" runat="server" CssClass="alert err" HeaderText="Please fix:" />
    </section>

    <p class="muted">Current seats: <b><asp:Label ID="lblCount" runat="server"></asp:Label></b></p>
    <div class="card seat-card">
        <asp:Repeater ID="rptRows" runat="server">
            <ItemTemplate>
                <div class="seatrow"><span class="rowlabel"><%# Eval("RowName") %></span>
                    <asp:Repeater ID="rptSeats" runat="server" DataSource='<%# Eval("Seats") %>'>
                        <ItemTemplate><span class="seat static"><%# Eval("SeatNumber") %></span></ItemTemplate>
                    </asp:Repeater>
                </div>
            </ItemTemplate>
        </asp:Repeater>
    </div>
</asp:Content>

<script runat="server">
    private int theatreId;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!int.TryParse(Request.QueryString["id"], out theatreId))
        {
            Response.Redirect("~/Admin/Theatres.aspx", false);
            return;
        }
        if (!IsPostBack) LoadLayout();
    }

    private void LoadLayout()
    {
        DataTable t = Db.Fill("SELECT TheatreName FROM Theatres WHERE TheatreID = @T", Db.P("@T", theatreId));
        if (t.Rows.Count == 0)
        {
            Response.Redirect("~/Admin/Theatres.aspx", false);
            return;
        }
        lblTheatre.Text = (string)t.Rows[0]["TheatreName"];

        DataTable seats = Db.Fill(
            "SELECT RowName, SeatNumber FROM Seats WHERE TheatreID = @T ORDER BY RowName, SeatNumber", Db.P("@T", theatreId));
        lblCount.Text = seats.Rows.Count.ToString();

        // group seats by row for the Repeaters (row -> list of seat numbers)
        var rows = new List<object>();
        var grouped = new Dictionary<string, DataTable>();
        foreach (DataRow s in seats.Rows)
        {
            string row = ((string)s["RowName"]).Trim();
            if (!grouped.ContainsKey(row))
            {
                DataTable list = new DataTable();
                list.Columns.Add("SeatNumber", typeof(int));
                grouped[row] = list;
            }
            grouped[row].Rows.Add(Convert.ToInt32(s["SeatNumber"]));
        }
        DataTable rowTable = new DataTable();
        rowTable.Columns.Add("RowName", typeof(string));
        rowTable.Columns.Add("Seats", typeof(DataTable));
        foreach (var kv in grouped) rowTable.Rows.Add(kv.Key, kv.Value);
        rptRows.DataSource = rowTable;
        rptRows.DataBind();
    }

    protected void btnGenerate_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;
        try
        {
            TheatreRules.GenerateSeats(theatreId, int.Parse(txtRows.Text), int.Parse(txtPerRow.Text));
            lblMsg.Text = "Seat layout created: " + txtRows.Text + " rows x " + txtPerRow.Text + " seats.";
            lblMsg.CssClass = "alert ok";
        }
        catch (SqlException)
        {
            lblMsg.Text = "Seats already have bookings, so the layout cannot be rebuilt.";
            lblMsg.CssClass = "alert err";
        }
        catch (ArgumentException ex)
        {
            lblMsg.Text = ex.Message;
            lblMsg.CssClass = "alert err";
        }
        lblMsg.Visible = true;
        LoadLayout();
    }
</script>
