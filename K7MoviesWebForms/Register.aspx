<%@ Page Title="Register" Language="C#" MasterPageFile="~/Site.Master" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
  <div class="auth auth-bg">
    <div class="card auth-card">
      <h1>CREATE NEW ACCOUNT</h1>
      <p class="sub">Join K7 Movies in a minute</p>
      <asp:Label ID="lblError" runat="server" CssClass="alert err" Visible="false"></asp:Label>

      <label>FULL NAME <asp:TextBox ID="txtName" runat="server"></asp:TextBox></label>
      <asp:RequiredFieldValidator ID="rfvName" runat="server" ControlToValidate="txtName" ErrorMessage="Please enter your full name." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>

      <label>USERNAME <asp:TextBox ID="txtUser" runat="server"></asp:TextBox></label>
      <asp:RequiredFieldValidator ID="rfvUser" runat="server" ControlToValidate="txtUser" ErrorMessage="Please choose a username." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
      <asp:RegularExpressionValidator ID="revUser" runat="server" ControlToValidate="txtUser" ValidationExpression="^[A-Za-z0-9_.]{3,50}$"
          ErrorMessage="Username: 3-50 letters, digits, dot or underscore." CssClass="field-err" Display="Dynamic"></asp:RegularExpressionValidator>

      <label>EMAIL <asp:TextBox ID="txtEmail" runat="server"></asp:TextBox></label>
      <asp:RequiredFieldValidator ID="rfvEmail" runat="server" ControlToValidate="txtEmail" ErrorMessage="Please enter your email." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
      <asp:RegularExpressionValidator ID="revEmail" runat="server" ControlToValidate="txtEmail" ValidationExpression="^[^@\s]+@[^@\s]+\.[^@\s]+$"
          ErrorMessage="Please enter a valid email address." CssClass="field-err" Display="Dynamic"></asp:RegularExpressionValidator>

      <label>Mobile (10 digits) <asp:TextBox ID="txtMobile" runat="server" MaxLength="10" inputmode="numeric"></asp:TextBox></label>
      <asp:RequiredFieldValidator ID="rfvMobile" runat="server" ControlToValidate="txtMobile" ErrorMessage="Please enter your mobile number." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
      <asp:RegularExpressionValidator ID="revMobile" runat="server" ControlToValidate="txtMobile" ValidationExpression="^\d{10}$"
          ErrorMessage="Mobile number must be exactly 10 digits." CssClass="field-err" Display="Dynamic"></asp:RegularExpressionValidator>

      <label>PASSWORD <asp:TextBox ID="txtPass" runat="server" TextMode="Password"></asp:TextBox></label>
      <asp:RequiredFieldValidator ID="rfvPass" runat="server" ControlToValidate="txtPass" ErrorMessage="Please enter a password." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
      <asp:RegularExpressionValidator ID="revPass" runat="server" ControlToValidate="txtPass" ValidationExpression="^.{6,}$"
          ErrorMessage="Password must contain at least 6 characters." CssClass="field-err" Display="Dynamic"></asp:RegularExpressionValidator>

      <label>Confirm password <asp:TextBox ID="txtConfirm" runat="server" TextMode="Password"></asp:TextBox></label>
      <asp:RequiredFieldValidator ID="rfvConfirm" runat="server" ControlToValidate="txtConfirm" ErrorMessage="Please confirm your password." CssClass="field-err" Display="Dynamic"></asp:RequiredFieldValidator>
      <asp:CompareValidator ID="cmpConfirm" runat="server" ControlToValidate="txtConfirm" ControlToCompare="txtPass"
          ErrorMessage="Passwords do not match." CssClass="field-err" Display="Dynamic"></asp:CompareValidator>

      <asp:CustomValidator ID="cvUnique" runat="server" CssClass="field-err" Display="Dynamic"
          ErrorMessage="This username or email is already registered." OnServerValidate="cvUnique_ServerValidate"></asp:CustomValidator>

      <asp:Button ID="btnRegister" runat="server" Text="REGISTER" CssClass="btn" OnClick="btnRegister_Click" />
      <p class="muted">Already registered? <asp:HyperLink runat="server" NavigateUrl="~/Login.aspx" Text="Login"></asp:HyperLink></p>
    </div>
  </div>
</asp:Content>

<script runat="server">
    protected void cvUnique_ServerValidate(object source, ServerValidateEventArgs args)
    {
        int taken = Db.Count("SELECT COUNT(*) FROM Users WHERE Username = @U OR Email = @E",
            Db.P("@U", txtUser.Text.Trim()), Db.P("@E", txtEmail.Text.Trim()));
        args.IsValid = taken == 0;
    }

    protected void btnRegister_Click(object sender, EventArgs e)
    {
        Page.Validate();
        if (!Page.IsValid) return;

        DataTable dt = Db.Fill("SELECT * FROM Users WHERE 1 = 0");
        DataRow r = dt.NewRow();
        r["FullName"] = txtName.Text.Trim();
        r["Username"] = txtUser.Text.Trim();
        r["Email"] = txtEmail.Text.Trim();
        r["Mobile"] = txtMobile.Text.Trim();
        r["PasswordHash"] = Db.Hash(txtPass.Text);
        r["Role"] = "User";
        dt.Rows.Add(r);

        try
        {
            Db.Save(dt, "Users", "UserID");
            Response.Redirect("~/Login.aspx?registered=1", false);
        }
        catch (SqlException ex)
        {
            lblError.Text = ex.Message;
            lblError.Visible = true;
        }
    }
</script>
