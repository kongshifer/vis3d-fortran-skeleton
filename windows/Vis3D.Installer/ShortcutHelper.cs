namespace Vis3D.Installer;

internal static class ShortcutHelper
{
    public static void CreateShortcut(
        string shortcutPath,
        string targetPath,
        string workingDirectory,
        string description,
        string? arguments = null,
        string? iconPath = null)
    {
        var shellType = Type.GetTypeFromProgID("WScript.Shell")
            ?? throw new InvalidOperationException("Unable to create the Windows shortcut component.");

        dynamic shell = Activator.CreateInstance(shellType)
            ?? throw new InvalidOperationException("Unable to start the Windows shortcut component.");
        dynamic shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = targetPath;
        shortcut.WorkingDirectory = workingDirectory;
        shortcut.Description = description;
        shortcut.Arguments = arguments ?? string.Empty;
        shortcut.IconLocation = iconPath ?? targetPath;
        shortcut.Save();
    }
}
