using System.Drawing.Drawing2D;

namespace Vis3D.Installer;

internal sealed class PickerButton : Button
{
    private bool isHovering;
    private bool isPressed;

    public PickerButton()
    {
        SetStyle(
            ControlStyles.UserPaint |
            ControlStyles.AllPaintingInWmPaint |
            ControlStyles.OptimizedDoubleBuffer |
            ControlStyles.ResizeRedraw,
            true);

        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        Cursor = Cursors.Hand;
        BackColor = Color.White;
        ForeColor = Color.FromArgb(28, 50, 64);
        Padding = new Padding(12, 6, 12, 6);
        MinimumSize = new Size(150, 30);
        UseMnemonic = false;
    }

    protected override void OnEnabledChanged(EventArgs e)
    {
        base.OnEnabledChanged(e);
        Invalidate();
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        base.OnMouseEnter(e);
        isHovering = true;
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        isHovering = false;
        isPressed = false;
        Invalidate();
    }

    protected override void OnMouseDown(MouseEventArgs mevent)
    {
        base.OnMouseDown(mevent);
        if (mevent.Button == MouseButtons.Left)
        {
            isPressed = true;
            Invalidate();
        }
    }

    protected override void OnMouseUp(MouseEventArgs mevent)
    {
        base.OnMouseUp(mevent);
        isPressed = false;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs pevent)
    {
        var bounds = ClientRectangle;
        if (bounds.Width <= 0 || bounds.Height <= 0)
        {
            return;
        }

        pevent.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

        using var backgroundBrush = new SolidBrush(GetBackgroundColor());
        using var borderPen = new Pen(GetBorderColor());
        var fillBounds = new Rectangle(0, 0, bounds.Width - 1, bounds.Height - 1);

        pevent.Graphics.FillRectangle(backgroundBrush, fillBounds);
        pevent.Graphics.DrawRectangle(borderPen, fillBounds);

        var textBounds = Rectangle.Inflate(fillBounds, -10, -4);
        TextRenderer.DrawText(
            pevent.Graphics,
            Text,
            Font,
            textBounds,
            GetTextColor(),
            TextFormatFlags.HorizontalCenter |
            TextFormatFlags.VerticalCenter |
            TextFormatFlags.EndEllipsis |
            TextFormatFlags.SingleLine |
            TextFormatFlags.NoPrefix);

        if (Focused && ShowFocusCues && Enabled)
        {
            var focusBounds = Rectangle.Inflate(fillBounds, -4, -4);
            ControlPaint.DrawFocusRectangle(pevent.Graphics, focusBounds);
        }
    }

    private Color GetBackgroundColor()
    {
        if (!Enabled)
        {
            return Color.FromArgb(242, 245, 248);
        }

        if (isPressed)
        {
            return Color.FromArgb(211, 228, 237);
        }

        if (isHovering)
        {
            return Color.FromArgb(227, 239, 246);
        }

        return Color.FromArgb(238, 244, 248);
    }

    private Color GetBorderColor()
    {
        if (!Enabled)
        {
            return Color.FromArgb(208, 216, 224);
        }

        if (isPressed)
        {
            return Color.FromArgb(101, 136, 156);
        }

        if (isHovering)
        {
            return Color.FromArgb(121, 153, 171);
        }

        return Color.FromArgb(150, 176, 190);
    }

    private Color GetTextColor()
    {
        return Enabled
            ? Color.FromArgb(24, 44, 58)
            : Color.FromArgb(130, 142, 152);
    }
}
