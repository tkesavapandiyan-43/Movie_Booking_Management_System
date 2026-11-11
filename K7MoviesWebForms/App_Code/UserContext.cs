using System;
using System.Data;
using System.Web;
using System.Web.Security;

/// <summary>Helpers for the logged-in user (the login cookie stores "UserID|Role").</summary>
public static class UserContext
{
    public static int CurrentUserId()
    {
        FormsIdentity id = HttpContext.Current.User.Identity as FormsIdentity;
        if (id == null) return 0;
        string[] parts = id.Ticket.UserData.Split('|');
        int n;
        return parts.Length > 0 && int.TryParse(parts[0], out n) ? n : 0;
    }

    public static bool IsAdmin()
    {
        return HttpContext.Current.User.IsInRole("Admin");
    }

    public static bool IsOwner()
    {
        return HttpContext.Current.User.IsInRole("TheatreOwner");
    }

    /// <summary>The theatre a theatre owner manages (0 when the user is not an owner).</summary>
    public static int OwnerTheatreId()
    {
        DataTable t = Db.Fill("SELECT TheatreID FROM Users WHERE UserID = @U AND Role = 'TheatreOwner'",
            Db.P("@U", CurrentUserId()));
        return t.Rows.Count == 0 || t.Rows[0]["TheatreID"] == DBNull.Value ? 0 : Convert.ToInt32(t.Rows[0]["TheatreID"]);
    }
}
