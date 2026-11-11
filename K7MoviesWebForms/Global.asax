<%@ Application Language="C#" %>
<%@ Import Namespace="System.Security.Principal" %>
<%@ Import Namespace="System.Web.Security" %>
<script runat="server">
    // Rebuilds the user principal from the login cookie. UserData = "UserID|Role".
    void Application_AuthenticateRequest(object sender, EventArgs e)
    {
        HttpCookie cookie = Request.Cookies[FormsAuthentication.FormsCookieName];
        if (cookie == null) return;
        FormsAuthenticationTicket ticket;
        try { ticket = FormsAuthentication.Decrypt(cookie.Value); }
        catch { return; }
        if (ticket == null || ticket.Expired) return;

        string[] parts = ticket.UserData.Split('|');
        string role = parts.Length > 1 ? parts[1] : "User";
        Context.User = new GenericPrincipal(new FormsIdentity(ticket), new[] { role });
    }
</script>
