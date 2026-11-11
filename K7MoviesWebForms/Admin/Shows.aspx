<%@ Page Title="Manage shows" Language="C#" MasterPageFile="~/Admin/Admin.master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <h1>SHOWS</h1>
  <p class="muted">Five fixed time slots per theatre per day: Monday to Friday has shows 1-4, Saturday and Sunday has shows 1-5.</p>
  <asp:Label ID="lblMsg" runat="server" Visible="false"></asp:Label>

  <section class="card form">
    <div class="row between">
      <h3>Schedule</h3>
      <asp:Button ID="btnRebuild" runat="server" Text="REBUILD SCHEDULE (7 DAYS)" CssClass="btn ghost"
          OnClick="btnRebuild_Click" OnClientClick="return confirm('Delete old shows without bookings and create the schedule for the next 7 days?');" />
    </div>
    <p class="muted small">Old shows (before today) with no bookings are deleted. Shows with bookings are kept.</p>
  </section>

  <section class="card form">
    <h3>Add a show manually</h3>
    <label>THEATRE</label>
    <asp:DropDownList ID="ddlTheatre" runat="server" DataTextField="TheatreName" DataValueField="TheatreID"></asp:DropDownList>
    <label>MOVIE</label>
    <asp:DropDownList ID="ddlMovie" runat="server" DataTextField="Title" DataValueField="MovieID"></asp:DropDownList>
    <div class="two">
      <div>
        <label>SHOW DATE</label>
        <asp:TextBox ID="txtDate" runat="server" TextMode="Date"></asp:TextBox>
        <asp:RequiredFieldValidator ID="rfvDate" runat="server" ControlToValidate="txtDate" ErrorMessage="Show date is required." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
        <asp:CustomValidator ID="cvDate" runat="server" ControlToValidate="txtDate" CssClass="field-err" Display="Dynamic"
            ErrorMessage="A show cannot be scheduled in the past." OnServerValidate="cvDate_ServerValidate"></asp:CustomValidator>
      </div>
      <div>
        <label>SLOT</label>
        <asp:DropDownList ID="ddlSlot" runat="server">
          <asp:ListItem Text="1 &middot; 09:00 AM - 12:15 PM" Value="1"></asp:ListItem>
          <asp:ListItem Text="2 &middot; 12:30 PM - 03:45 PM" Value="2"></asp:ListItem>
          <asp:ListItem Text="3 &middot; 04:00 PM - 07:15 PM" Value="3"></asp:ListItem>
          <asp:ListItem Text="4 &middot; 07:30 PM - 10:30 PM" Value="4"></asp:ListItem>
          <asp:ListItem Text="5 &middot; 10:45 PM - 01:45 AM (weekends only)" Value="5"></asp:ListItem>
        </asp:DropDownList>
        <asp:CustomValidator ID="cvSlot" runat="server" CssClass="field-err" Display="Dynamic"
            ErrorMessage="Slot 5 runs only on Saturday and Sunday." OnServerValidate="cvSlot_ServerValidate"></asp:CustomValidator>
      </div>
    </div>
    <div class="row">
      <asp:Button ID="btnAdd" runat="server" Text="ADD SHOW" CssClass="btn" OnClick="btnAdd_Click" />
    </div>
    <asp:ValidationSummary ID="vsShow" runat="server" CssClass="alert err" HeaderText="Please fix:" />
  </section>

  <h2>Scheduled shows</h2>
  <asp:GridView ID="gvShows" runat="server" AutoGenerateColumns="false" CssClass="tbl" GridLines="None"
      DataKeyNames="ShowID" OnRowCommand="gvShows_RowCommand">
    <Columns>
      <asp:BoundField DataField="ShowID" HeaderText="ID" />
      <asp:BoundField DataField="Title" HeaderText="Movie" />
      <asp:BoundField DataField="TheatreName" HeaderText="Theatre" />
      <asp:BoundField DataField="ShowDate" HeaderText="Date" DataFormatString="{0:ddd, dd MMM yyyy}" />
      <asp:BoundField DataField="SlotNumber" HeaderText="Slot" />
      <asp:TemplateField HeaderText="Time">
        <ItemTemplate><%# Ui.Time(Eval("ShowDate"), Eval("ShowTime")) %> &ndash; <%# Ui.Time(Eval("ShowDate"), Eval("ShowEndTime")) %></ItemTemplate>
      </asp:TemplateField>
      <asp:ButtonField ButtonType="Button" CommandName="DeleteShow" Text="Delete" />
    </Columns>
  </asp:GridView>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            ddlTheatre.DataSource = Db.Fill("SELECT TheatreID, TheatreName FROM Theatres WHERE IsActive = 1 ORDER BY TheatreName");
            ddlTheatre.DataBind();
            ddlMovie.DataSource = Db.Fill("SELECT MovieID, Title FROM Movies WHERE IsActive = 1 ORDER BY Title");
            ddlMovie.DataBind();
            txtDate.Text = DateTime.Today.ToString("yyyy-MM-dd");
            LoadGrid();
        }
    }

    private void LoadGrid()
    {
        gvShows.DataSource = Db.Fill(
            @"SELECT TOP 300 s.ShowID, m.Title, t.TheatreName, s.ShowDate, s.SlotNumber, s.ShowTime, s.ShowEndTime
              FROM Shows s INNER JOIN Movies m ON m.MovieID = s.MovieID INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              ORDER BY s.ShowDate DESC, s.ShowTime DESC");
        gvShows.DataBind();
    }

    private void Message(string text, bool ok)
    {
        lblMsg.Text = text;
        lblMsg.CssClass = ok ? "alert ok" : "alert err";
        lblMsg.Visible = true;
    }

    /// <summary>Monday = 0 ... Sunday = 6, using the same rule as the database procedure.</summary>
    private static bool IsWeekend(DateTime d)
    {
        return d.DayOfWeek == DayOfWeek.Saturday || d.DayOfWeek == DayOfWeek.Sunday;
    }

    protected void cvDate_ServerValidate(object source, ServerValidateEventArgs args)
    {
        DateTime d;
        args.IsValid = DateTime.TryParse(txtDate.Text, out d) && d.Date >= DateTime.Today;
    }

    protected void cvSlot_ServerValidate(object source, ServerValidateEventArgs args)
    {
        DateTime d;
        if (!DateTime.TryParse(txtDate.Text, out d)) { args.IsValid = true; return; }
        args.IsValid = ddlSlot.SelectedValue != "5" || IsWeekend(d);
    }

    protected void btnAdd_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;

        int slot = int.Parse(ddlSlot.SelectedValue);
        string start = slot == 1 ? "09:00" : slot == 2 ? "12:30" : slot == 3 ? "16:00" : slot == 4 ? "19:30" : "22:45";
        string end = slot == 1 ? "12:15" : slot == 2 ? "15:45" : slot == 3 ? "19:15" : slot == 4 ? "22:30" : "01:45";

        DataTable dt = Db.Fill("SELECT * FROM Shows WHERE 1 = 0");
        DataRow r = Db.AddRow(dt, "ShowID");
        r["MovieID"] = int.Parse(ddlMovie.SelectedValue);
        r["TheatreID"] = int.Parse(ddlTheatre.SelectedValue);
        r["ShowDate"] = DateTime.Parse(txtDate.Text);
        r["ShowTime"] = TimeSpan.Parse(start);
        r["ShowEndTime"] = TimeSpan.Parse(end);
        r["SlotNumber"] = slot;

        try
        {
            Db.Save(dt, "Shows", "ShowID");
            Message("Show added.", true);
        }
        catch (SqlException ex)
        {
            Message(ex.Number == 2627 || ex.Number == 2601 ? "A show already exists for this theatre, date and slot." : ex.Message, false);
        }
        LoadGrid();
    }

    protected void btnRebuild_Click(object sender, EventArgs e)
    {
        try
        {
            Db.Execute("EXEC dbo.usp_RebuildShows @Days = 7");
            Message("Schedule rebuilt for the next 7 days. Old shows without bookings were removed.", true);
        }
        catch (SqlException ex) { Message(ex.Message, false); }
        LoadGrid();
    }

    protected void gvShows_RowCommand(object sender, GridViewCommandEventArgs e)
    {
        if (e.CommandName != "DeleteShow") return;
        int id = Convert.ToInt32(gvShows.DataKeys[Convert.ToInt32(e.CommandArgument)].Value);
        DataTable dt = Db.Fill("SELECT * FROM Shows WHERE ShowID = @S", Db.P("@S", id));
        if (dt.Rows.Count == 0) return;
        try
        {
            dt.Rows[0].Delete();
            Db.Save(dt, "Shows", "ShowID");
            Message("Show deleted.", true);
        }
        catch (SqlException) { Message("This show has bookings and cannot be deleted.", false); }
        LoadGrid();
    }
</script>
