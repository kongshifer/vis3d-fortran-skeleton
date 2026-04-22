namespace Vis3D.App;

internal sealed class TransparentTableLayoutPanel : TableLayoutPanel
{
    public TransparentTableLayoutPanel()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
    }
}
