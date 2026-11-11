using System;
using System.Globalization;
using System.Web;

/// <summary>HTML helpers that produce the same markup and CSS classes as the MVC version.</summary>
public static class Ui
{
    public static string Esc(object value)
    {
        return HttpUtility.HtmlEncode(Convert.ToString(value));
    }

    private static bool Has(object v)
    {
        return v != null && v != DBNull.Value;
    }

    /// <summary>Same colour rule as the MVC card: sum of the title's characters modulo 360.</summary>
    public static int Hue(object title)
    {
        int sum = 0;
        foreach (char c in Convert.ToString(title)) sum += c;
        return sum % 360;
    }

    public static string Date(object value, string format)
    {
        if (!Has(value)) return "";
        return Convert.ToDateTime(value).ToString(format, CultureInfo.InvariantCulture);
    }

    public static string Time(object showDate, object showTime)
    {
        DateTime d = Convert.ToDateTime(showDate).Date;
        TimeSpan t = (TimeSpan)showTime;
        return d.Add(t).ToString("hh:mm tt", CultureInfo.InvariantCulture);
    }

    private static string Rate(object r)
    {
        return Convert.ToDecimal(r).ToString("0.0", CultureInfo.InvariantCulture);
    }

    public static string RatingPill(object rating)
    {
        if (!Has(rating)) return "";
        return "<span class=\"rating\" title=\"Rating\"><span class=\"star\">&#9733;</span> " + Rate(rating) + "</span>";
    }

    public static string RatingBig(object rating)
    {
        if (!Has(rating)) return "<p class=\"muted small\">Not rated yet</p>";
        return "<p><span class=\"rating big\"><span class=\"star\">&#9733;</span> " + Rate(rating) +
               "</span> <span class=\"muted small\">out of 10</span></p>";
    }

    public static string NotRated(object rating)
    {
        return Has(rating) ? "" : "<span class=\"muted small\">Not rated yet</span>";
    }

    public static string Poster(object path, object title)
    {
        string p = Has(path) ? Convert.ToString(path).Trim() : "";
        if (p.Length == 0) return "";
        return "<img class=\"poster-img\" src=\"" + HttpUtility.HtmlAttributeEncode(p) + "\" alt=\"Poster of " +
               Esc(title) + "\" loading=\"lazy\" onerror=\"this.remove()\" />";
    }

    /// <summary>Upcoming movies show "Opens ..."; open movies show Book tickets; closed movies show Booking closed.</summary>
    public static string Action(object movieId, object status, object release)
    {
        DateTime rel = Convert.ToDateTime(release);
        if (rel.Date > DateTime.Today)
            return "<span class=\"badge soon\">Opens " + rel.ToString("dd MMM", CultureInfo.InvariantCulture) + "</span>";
        if (Convert.ToString(status) == "Open")
            return "<a class=\"btn small\" href=\"Shows.aspx?movie=" + Convert.ToString(movieId) + "\">Book tickets</a>";
        return "<span class=\"badge closed\">Booking closed</span>";
    }

    public static string StatusBadge(object status)
    {
        string s = Convert.ToString(status);
        return "<span class=\"badge " + (s == "Cancelled" ? "closed" : "open") + "\">" + Esc(s) + "</span>";
    }
}
