using System.Drawing.Drawing2D;

namespace Vis3D.Installer;

internal sealed class BrandBannerPanel : Panel
{
    public BrandBannerPanel()
    {
        DoubleBuffered = true;
        ResizeRedraw = true;
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        var rect = ClientRectangle;
        if (rect.Width <= 0 || rect.Height <= 0)
        {
            return;
        }

        using var brush = new LinearGradientBrush(
            rect,
            Color.FromArgb(14, 52, 94),
            Color.FromArgb(15, 102, 131),
            LinearGradientMode.ForwardDiagonal);
        e.Graphics.FillRectangle(brush, rect);

        using var glowBrush = new SolidBrush(Color.FromArgb(18, Color.White));
        using var accentBrush = new SolidBrush(Color.FromArgb(26, 117, 213, 237));
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        e.Graphics.FillEllipse(glowBrush, rect.Width - 210, -30, 220, 220);
        e.Graphics.FillEllipse(glowBrush, rect.Width - 80, 40, 110, 110);
        e.Graphics.FillEllipse(accentBrush, rect.Width - 280, -70, 320, 260);
    }
}
