<%@ Page Title="Showtimes" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Linq" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <a href="Default.aspx" class="back">&larr; All movies</a>
  <asp:Panel ID="pnlMovie" runat="server">
    <asp:Literal ID="litHero" runat="server" EnableViewState="false"></asp:Literal>
    <h2>Choose a showtime</h2>
    <asp:Literal ID="litShows" runat="server" EnableViewState="false"></asp:Literal>
  </asp:Panel>
  <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        int movieId;
        if (!int.TryParse(Request.QueryString["movie"], out movieId))
        {
            Response.Redirect("~/Default.aspx", false);
            return;
        }

        DataTable movie = Db.Fill(
            "SELECT MovieID, Title, Genre, Language, DurationMinutes, ReleaseDate, Rating, Description, PosterPath, BookingStatus FROM Movies WHERE MovieID = @M AND IsActive = 1",
            Db.P("@M", movieId));
        if (movie.Rows.Count == 0)
        {
            Response.Redirect("~/Default.aspx", false);
            return;
        }
        DataRow m = movie.Rows[0];
        string title = Ui.Esc(m["Title"]);

        litHero.Text =
            "<section class=\"movie-hero\">" +
            "<div class=\"poster lg\" style=\"--hue:" + Ui.Hue(m["Title"]) + "\">" + Ui.Poster(m["PosterPath"], m["Title"]) +
            "<span class=\"poster-title\">" + title + "</span></div>" +
            "<div class=\"movie-hero-body\"><h1>" + title + "</h1>" +
            "<p class=\"meta\">" + Ui.Esc(m["Genre"]) + " &middot; " + Ui.Esc(m["Language"]) + " &middot; " +
            m["DurationMinutes"] + " min &middot; Release " + Ui.Date(m["ReleaseDate"], "dd MMM yyyy") + "</p>" +
            Ui.RatingBig(m["Rating"]) +
            (m["Description"] == DBNull.Value || string.IsNullOrWhiteSpace((string)m["Description"])
                ? ""
                : "<p class=\"desc-full\">" + Ui.Esc(m["Description"]) + "</p>") +
            "</div></section>";

        if (Convert.ToString(m["BookingStatus"]) != "Open")
        {
            litShows.Text = "<div class=\"alert err\">Booking is closed for this movie.</div>";
            return;
        }

        DataTable shows = Db.Fill(
            @"SELECT s.ShowID, s.ShowDate, s.ShowTime, s.ShowEndTime, s.SlotNumber, (SELECT MIN(se.Price) FROM Seats se WHERE se.TheatreID = s.TheatreID) AS FromPrice, t.TheatreName, t.Location
              FROM Shows s
              INNER JOIN Theatres t ON t.TheatreID = s.TheatreID
              WHERE s.MovieID = @M AND t.IsActive = 1 AND s.ShowDate >= CAST(GETDATE() AS DATE)
              ORDER BY s.ShowDate, s.ShowTime", Db.P("@M", movieId));

        if (shows.Rows.Count == 0)
        {
            litShows.Text = "<div class=\"card empty\">No upcoming shows are scheduled yet.</div>";
            return;
        }

        List<DateTime> dates = shows.Rows.Cast<DataRow>()
            .Select(r => Convert.ToDateTime(r["ShowDate"]).Date).Distinct().OrderBy(d => d).ToList();

        StringBuilder html = new StringBuilder();
        html.Append("<div class=\"date-tabs\" role=\"tablist\">");
        for (int i = 0; i < dates.Count; i++)
        {
            html.Append("<button type=\"button\" class=\"date-tab" + (i == 0 ? " active" : "") + "\" data-date=\"" +
                        dates[i].ToString("yyyy-MM-dd") + "\"><b>" + dates[i].ToString("ddd") + "</b><span>" +
                        dates[i].ToString("dd MMM") + "</span></button>");
        }
        html.Append("</div><div class=\"scroll\"><table class=\"tbl shows\">" +
                    "<thead><tr><th>Theatre</th><th>Location</th><th>Time</th><th>Price</th><th></th></tr></thead><tbody>");
        foreach (DataRow s in shows.Rows)
        {
            DateTime d = Convert.ToDateTime(s["ShowDate"]).Date;
            html.Append("<tr class=\"show-row\" data-date=\"" + d.ToString("yyyy-MM-dd") + "\"" +
                        (d != dates[0] ? " hidden" : "") + ">" +
                        "<td><b>" + Ui.Esc(s["TheatreName"]) + "</b></td>" +
                        "<td>" + Ui.Esc(s["Location"]) + "</td>" +
                        "<td><span class=\"time-chip\">" + Ui.Time(s["ShowDate"], s["ShowTime"]) + " &ndash; " + Ui.Time(s["ShowDate"], s["ShowEndTime"]) + "</span></td>" +
                        "<td>from &#8377;" + Convert.ToDecimal(s["FromPrice"]).ToString("0") + "</td>" +
                        "<td><a class=\"btn small\" href=\"Seats.aspx?show=" + s["ShowID"] + "\">Select seats</a></td></tr>");
        }
        html.Append("</tbody></table></div>");
        litShows.Text = html.ToString();
    }
</script>
