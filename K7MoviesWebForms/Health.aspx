<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<script runat="server">
    // Diagnostics: open http://localhost:<port>/Health.aspx on the same PC.
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "text/plain";
        if (!Request.IsLocal) { Response.Write("Not available from another machine."); return; }
        try
        {
            int users = Db.Count("SELECT COUNT(*) FROM Users");
            int admins = Db.Count("SELECT COUNT(*) FROM Users WHERE Role = 'Admin'");
            int movies = Db.Count("SELECT COUNT(*) FROM Movies");
            int shows = Db.Count("SELECT COUNT(*) FROM Shows");
            Response.Write("Database connection: OK\nUsers: " + users + "\nAdmins: " + admins +
                           "\nMovies: " + movies + "\nShows: " + shows + "\n");
            Response.Write(admins == 0
                ? "\nNo admin account. Run schema.sql (see README) on the database."
                : "\nAdmin account found. Sign in at Login.aspx.");
        }
        catch (Exception ex)
        {
            Response.Write("Database connection: FAILED\n\n" + ex.Message +
                           "\n\nCheck the Server= value in Web.config and that SQL Server (SQLEXPRESS) is running.");
        }
        Response.End();
    }
</script>
