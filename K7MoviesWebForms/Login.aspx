<%@ Page Title="Login" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Web.Security" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <div class="auth auth-bg">
    <div class="card auth-card">
      <h1>WELCOME BACK</h1>
      <p class="sub">Sign in to continue</p>
      <asp:Label ID="lblRegistered" runat="server" CssClass="alert ok" Visible="false" Text="Registration successful. Please log in."></asp:Label>
      <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>

      <label>USERNAME OR EMAIL
        <asp:TextBox ID="txtUser" runat="server" autocomplete="username"></asp:TextBox>
      </label>
      <asp:RequiredFieldValidator ID="rfvUser" runat="server" ControlToValidate="txtUser"
          ErrorMessage="Please enter your username or email." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>

      <label>PASSWORD
        <asp:TextBox ID="txtPass" runat="server" TextMode="Password" autocomplete="current-password"></asp:TextBox>
      </label>
      <asp:RequiredFieldValidator ID="rfvPass" runat="server" ControlToValidate="txtPass"
          ErrorMessage="Please enter your password." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>

      <asp:Button ID="btnLogin" runat="server" Text="LOGIN" CssClass="btn" OnClick="btnLogin_Click" />

     
      <p class="muted">New here? <asp:HyperLink runat="server" NavigateUrl="~/Register.aspx" Text="CREATE NEW ACCOUNT"></asp:HyperLink></p>
    </div>
  </div>
</asp:Content>

<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        lblRegistered.Visible = Request.QueryString["registered"] == "1";
    }

    protected void btnLogin_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;

        DataTable u = Db.Fill(
            "SELECT UserID, Username, Role, PasswordHash FROM Users WHERE Username = @U OR Email = @U",
            Db.P("@U", txtUser.Text.Trim()));

        bool ok = u.Rows.Count > 0 &&
                  string.Equals((string)u.Rows[0]["PasswordHash"], Db.Hash(txtPass.Text), StringComparison.OrdinalIgnoreCase);
        if (!ok)
        {
            lblError.Text = "Invalid username or password.";
            lblError.Visible = true;
            return;
        }

        DataRow r = u.Rows[0];
        string role = Convert.ToString(r["Role"]);
        string name = Convert.ToString(r["Username"]);
        FormsAuthenticationTicket ticket = new FormsAuthenticationTicket(
            1, name, DateTime.Now, DateTime.Now.AddHours(8), false, r["UserID"] + "|" + role);
        Response.Cookies.Add(new HttpCookie(FormsAuthentication.FormsCookieName, FormsAuthentication.Encrypt(ticket)));
        string target = role == "Admin" ? "~/Admin/Default.aspx" : role == "TheatreOwner" ? "~/Owner/Default.aspx" : "~/Default.aspx";
        Response.Redirect(target, false);
    }
</script>
