<%@ Page Title="Cancel seats" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="System.Linq" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <a href="MyBookings.aspx" class="back">&larr; My bookings</a>
  <h1>CANCEL SEATS</h1>
  <p class="meta"><asp:Label ID="lblInfo" runat="server"></asp:Label></p>
  <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>
  <asp:Label ID="lblOk" runat="server" CssClass="alert ok" Visible="false"></asp:Label>

  <asp:Panel ID="pnlForm" runat="server" CssClass="card form">
    <p class="muted">Tick the seats you want to cancel. Their price is refunded and the seats become free for other customers. You can cancel only until the show starts.</p>
    <asp:CheckBoxList ID="cblSeats" runat="server" RepeatColumns="4" CssClass="check"></asp:CheckBoxList>
    <asp:CustomValidator ID="cvSeats" runat="server" CssClass="field-err" Display="Dynamic"
        ErrorMessage="Tick at least one seat to cancel." OnServerValidate="cvSeats_ServerValidate"></asp:CustomValidator>
    <div class="row">
      <asp:Button ID="btnCancel" runat="server" Text="CANCEL SELECTED SEATS" CssClass="btn danger"
          OnClick="btnCancel_Click" OnClientClick="return confirm('Cancel the selected seats and refund them?');" />
    </div>
    <asp:ValidationSummary ID="vsCancel" runat="server" CssClass="alert err" HeaderText="Please fix:" />
  </asp:Panel>
</asp:Content>

<script runat="server">
    private int bookingId;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!int.TryParse(Request.QueryString["id"], out bookingId))
        {
            Response.Redirect("~/MyBookings.aspx", false);
            return;
        }
        if (!IsPostBack) LoadSeats();
    }

    /// <summary>Loads the seats of this booking, only when the booking is confirmed and the show has not started.</summary>
    private void LoadSeats()
    {
        DataTable b = Db.Fill(
            @"SELECT b.BookingID, b.BookingStatus, s.ShowDate, s.ShowTime, m.Title, t.TheatreName
              FROM Bookings b
              INNER JOIN Shows s ON s.ShowID = b.ShowID
              INNER JOIN Movies m ON m.MovieID = s.MovieID
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              WHERE b.BookingID = @B AND b.UserID = @U",
            Db.P("@B", bookingId), Db.P("@U", UserContext.CurrentUserId()));
        if (b.Rows.Count == 0)
        {
            Response.Redirect("~/MyBookings.aspx", false);
            return;
        }

        DataRow r = b.Rows[0];
        DateTime start = Convert.ToDateTime(r["ShowDate"]).Date + (TimeSpan)r["ShowTime"];
        lblInfo.Text = "Booking #" + bookingId + " &middot; " + Ui.Esc(r["Title"]) + " &middot; " + Ui.Esc(r["TheatreName"]) +
                       " &middot; " + start.ToString("dd MMM yyyy hh:mm tt", CultureInfo.InvariantCulture);

        string status = (string)r["BookingStatus"];
        if (status != "Confirmed" || start <= DateTime.Now)
        {
            ShowError(status != "Confirmed" ? "This booking is already cancelled." : "This show has already started, so seats can no longer be cancelled.");
            pnlForm.Visible = false;
            return;
        }

        DataTable seats = Db.Fill(
            @"SELECT se.SeatID, se.RowName, se.SeatNumber, se.Price
              FROM BookingSeats bs INNER JOIN Seats se ON se.SeatID = bs.SeatID
              WHERE bs.BookingID = @B ORDER BY se.RowName, se.SeatNumber", Db.P("@B", bookingId));
        cblSeats.Items.Clear();
        foreach (DataRow s in seats.Rows)
        {
            string text = ((string)s["RowName"]).Trim() + s["SeatNumber"] + " (refund &#8377;" +
                          Convert.ToDecimal(s["Price"]).ToString("0", CultureInfo.InvariantCulture) + ")";
            cblSeats.Items.Add(new ListItem(text, s["SeatID"].ToString()));
        }
    }

    protected void cvSeats_ServerValidate(object source, ServerValidateEventArgs args)
    {
        args.IsValid = cblSeats.Items.Cast<ListItem>().Any(i => i.Selected);
    }

    protected void btnCancel_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;

        List<int> ids = cblSeats.Items.Cast<ListItem>().Where(i => i.Selected).Select(i => int.Parse(i.Value)).ToList();
        string error = BookingRules.CancelSeats(bookingId, UserContext.CurrentUserId(), ids);
        if (error != null)
        {
            ShowError(error);
            LoadSeats();
            return;
        }

        lblOk.Text = ids.Count + " seat(s) cancelled. The refund is recorded in the payment history.";
        lblOk.Visible = true;
        LoadSeats();
        if (!pnlForm.Visible)
        {
            Response.Redirect("~/MyBookings.aspx?cancelled=1", false);
        }
    }

    private void ShowError(string message)
    {
        lblError.Text = message;
        lblError.Visible = true;
    }
</script>
