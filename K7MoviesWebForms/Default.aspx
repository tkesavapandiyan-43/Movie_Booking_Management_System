<%@ Page Title="Now showing" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Data" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <section class="hero">
    <div>
      <span class="eyebrow">Online Movie Ticket Booking</span>
      <h1>NOW SHOWING</h1>
      <p class="muted">Tamil cinema &middot; book seats in a few clicks</p>
    </div>
    <asp:Panel ID="pnlSearch" runat="server" CssClass="search-lg" DefaultButton="btnSearch">
      <asp:TextBox ID="txtSearch" runat="server" placeholder="Search movie title or genre" aria-label="Search movies"></asp:TextBox>
      <asp:Button ID="btnSearch" runat="server" Text="SEARCH" CssClass="btn" OnClick="btnSearch_Click" />
    </asp:Panel>
  </section>

  <div class="toolbar">
    <div class="seg" role="tablist">
      <button type="button" class="seg-btn active" data-tab="now" role="tab" aria-selected="true">
        NOW SHOWING <span class="count"><asp:Label ID="lblNow" runat="server"></asp:Label></span></button>
      <button type="button" class="seg-btn" data-tab="soon" role="tab" aria-selected="false">
        UPCOMING MOVIES <span class="count"><asp:Label ID="lblSoon" runat="server"></asp:Label></span></button>
    </div>
  </div>

  <div id="tab-now" class="grid tabpanel">
    <asp:Repeater ID="rptNow" runat="server">
      <ItemTemplate>
        <article class="movie">
          <a class="poster" style="--hue:<%# Ui.Hue(Eval("Title")) %>" href="Shows.aspx?movie=<%# Eval("MovieID") %>" aria-label="<%# Ui.Esc(Eval("Title")) %>">
            <%# Ui.Poster(Eval("PosterPath"), Eval("Title")) %>
            <span class="poster-title"><%# Ui.Esc(Eval("Title")) %></span>
            <%# Ui.RatingPill(Eval("Rating")) %>
          </a>
          <div class="info">
            <h3><%# Ui.Esc(Eval("Title")) %></h3>
            <p class="meta"><%# Ui.Esc(Eval("Genre")) %> &middot; <%# Ui.Esc(Eval("Language")) %> &middot; <%# Eval("DurationMinutes") %> min</p>
            <p class="meta">Release: <%# Ui.Date(Eval("ReleaseDate"), "dd MMM yyyy") %></p>
            <div class="card-foot">
              <%# Ui.Action(Eval("MovieID"), Eval("BookingStatus"), Eval("ReleaseDate")) %>
              <%# Ui.NotRated(Eval("Rating")) %>
            </div>
          </div>
        </article>
      </ItemTemplate>
    </asp:Repeater>
  </div>

  <div id="tab-soon" class="grid tabpanel" hidden>
    <asp:Repeater ID="rptSoon" runat="server">
      <ItemTemplate>
        <article class="movie">
          <a class="poster" style="--hue:<%# Ui.Hue(Eval("Title")) %>" href="Shows.aspx?movie=<%# Eval("MovieID") %>" aria-label="<%# Ui.Esc(Eval("Title")) %>">
            <%# Ui.Poster(Eval("PosterPath"), Eval("Title")) %>
            <span class="poster-title"><%# Ui.Esc(Eval("Title")) %></span>
          </a>
          <div class="info">
            <h3><%# Ui.Esc(Eval("Title")) %></h3>
            <p class="meta"><%# Ui.Esc(Eval("Genre")) %> &middot; <%# Ui.Esc(Eval("Language")) %></p>
            <p class="meta">Release: <%# Ui.Date(Eval("ReleaseDate"), "dd MMM yyyy") %></p>
            <div class="card-foot">
              <%# Ui.Action(Eval("MovieID"), Eval("BookingStatus"), Eval("ReleaseDate")) %>
            </div>
          </div>
        </article>
      </ItemTemplate>
    </asp:Repeater>
  </div>

  <asp:Label ID="lblEmpty" runat="server" CssClass="card empty" Visible="false" Text="No movies match your search. "></asp:Label>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack) LoadMovies();
    }

    private void LoadMovies()
    {
        string like = "%" + txtSearch.Text.Trim() + "%";

        DataTable now = Db.Fill(
            @"SELECT MovieID, Title, Genre, Language, DurationMinutes, ReleaseDate, Rating, BookingStatus, PosterPath
              FROM Movies
              WHERE IsActive = 1 AND ReleaseDate <= CAST(GETDATE() AS DATE)
                AND (Title LIKE @S OR Genre LIKE @S OR Language LIKE @S)
              ORDER BY ReleaseDate DESC", Db.P("@S", like));
        rptNow.DataSource = now;
        rptNow.DataBind();
        lblNow.Text = now.Rows.Count.ToString();

        DataTable soon = Db.Fill(
            @"SELECT MovieID, Title, Genre, Language, DurationMinutes, ReleaseDate, Rating, BookingStatus, PosterPath
              FROM Movies
              WHERE IsActive = 1 AND ReleaseDate > CAST(GETDATE() AS DATE)
                AND (Title LIKE @S OR Genre LIKE @S OR Language LIKE @S)
              ORDER BY ReleaseDate", Db.P("@S", like));
        rptSoon.DataSource = soon;
        rptSoon.DataBind();
        lblSoon.Text = soon.Rows.Count.ToString();

        lblEmpty.Visible = now.Rows.Count == 0 && soon.Rows.Count == 0;
    }

    protected void btnSearch_Click(object sender, EventArgs e)
    {
        LoadMovies();
    }
</script>
