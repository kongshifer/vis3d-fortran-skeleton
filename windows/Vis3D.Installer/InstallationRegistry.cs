using Microsoft.Win32;

namespace Vis3D.Installer;

internal sealed class InstallationRegistry
{
    private const string UninstallKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\Vis3D";
    private const string DesktopShortcutName = "Vis3D.lnk";
    private const string StartMenuGroupName = "Vis3D";
    private const string StartMenuAppShortcutName = "Vis3D.lnk";
    private const string StartMenuUninstallShortcutName = "Uninstall Vis3D.lnk";

    public InstalledProduct? FindInstalledProduct()
    {
        using var key = Registry.LocalMachine.OpenSubKey(UninstallKeyPath, writable: false);
        if (key is null)
        {
            return null;
        }

        var installDirectory = key.GetValue("InstallLocation") as string;
        if (string.IsNullOrWhiteSpace(installDirectory))
        {
            return null;
        }

        installDirectory = Path.GetFullPath(installDirectory);
        var applicationPath = key.GetValue("ApplicationPath") as string;
        if (string.IsNullOrWhiteSpace(applicationPath))
        {
            applicationPath = Path.Combine(installDirectory, InstallerMetadata.ApplicationExecutableName);
        }

        var maintenanceExecutablePath = key.GetValue("MaintenancePath") as string;
        if (string.IsNullOrWhiteSpace(maintenanceExecutablePath))
        {
            maintenanceExecutablePath = Path.Combine(installDirectory, InstallerMetadata.MaintenanceExecutableName);
        }

        var hasDesktopShortcut = ReadBooleanValue(key, "DesktopShortcut", File.Exists(GetDesktopShortcutPath()));
        var hasStartMenuShortcut = ReadBooleanValue(key, "StartMenuShortcut", Directory.Exists(GetStartMenuFolderPath()));
        var version = key.GetValue("DisplayVersion") as string ?? InstallerMetadata.VersionDisplay;

        return new InstalledProduct(
            installDirectory,
            applicationPath,
            maintenanceExecutablePath,
            version,
            hasDesktopShortcut,
            hasStartMenuShortcut);
    }

    public void RegisterInstallation(
        string installDirectory,
        string applicationPath,
        string maintenanceExecutablePath,
        bool createDesktopShortcut,
        bool createStartMenuShortcut,
        long installedBytes)
    {
        using var key = Registry.LocalMachine.CreateSubKey(UninstallKeyPath, writable: true);
        var uninstallCommand = BuildCommandLine(
            maintenanceExecutablePath,
            "--uninstall",
            "--install-dir",
            installDirectory);
        var quietUninstallCommand = BuildCommandLine(
            maintenanceExecutablePath,
            "--uninstall",
            "--quiet",
            "--install-dir",
            installDirectory);

        key.SetValue("DisplayName", InstallerMetadata.ProductName);
        key.SetValue("DisplayVersion", InstallerMetadata.VersionDisplay);
        key.SetValue("Publisher", InstallerMetadata.Publisher);
        key.SetValue("InstallDate", DateTime.UtcNow.ToString("yyyyMMdd"));
        key.SetValue("InstallLocation", installDirectory);
        key.SetValue("ApplicationPath", applicationPath);
        key.SetValue("DisplayIcon", applicationPath);
        key.SetValue("MaintenancePath", maintenanceExecutablePath);
        key.SetValue("UninstallString", uninstallCommand);
        key.SetValue("QuietUninstallString", quietUninstallCommand);
        key.SetValue("EstimatedSize", ToEstimatedSizeKilobytes(installedBytes), RegistryValueKind.DWord);
        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
        key.SetValue("DesktopShortcut", createDesktopShortcut ? 1 : 0, RegistryValueKind.DWord);
        key.SetValue("StartMenuShortcut", createStartMenuShortcut ? 1 : 0, RegistryValueKind.DWord);
    }

    public void UnregisterInstallation()
    {
        Registry.LocalMachine.DeleteSubKeyTree(UninstallKeyPath, throwOnMissingSubKey: false);
    }

    public string GetDesktopShortcutPath()
    {
        var desktopDirectory = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
        if (string.IsNullOrWhiteSpace(desktopDirectory))
        {
            desktopDirectory = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        }

        return Path.Combine(desktopDirectory, DesktopShortcutName);
    }

    public string GetStartMenuFolderPath()
    {
        var programsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms);
        if (string.IsNullOrWhiteSpace(programsDirectory))
        {
            programsDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                "Programs");
        }

        return Path.Combine(programsDirectory, StartMenuGroupName);
    }

    public string GetStartMenuAppShortcutPath() =>
        Path.Combine(GetStartMenuFolderPath(), StartMenuAppShortcutName);

    public string GetStartMenuUninstallShortcutPath() =>
        Path.Combine(GetStartMenuFolderPath(), StartMenuUninstallShortcutName);

    private static bool ReadBooleanValue(RegistryKey key, string valueName, bool defaultValue)
    {
        var rawValue = key.GetValue(valueName);
        return rawValue switch
        {
            int integerValue => integerValue != 0,
            string textValue when int.TryParse(textValue, out var integerValue) => integerValue != 0,
            _ => defaultValue
        };
    }

    private static int ToEstimatedSizeKilobytes(long installedBytes)
    {
        var estimatedKilobytes = Math.Max(1L, (installedBytes + 1023L) / 1024L);
        return (int)Math.Min(int.MaxValue, estimatedKilobytes);
    }

    private static string BuildCommandLine(string executablePath, params string[] arguments)
    {
        var parts = new List<string> { Quote(executablePath) };
        parts.AddRange(arguments.Select(QuoteIfNeeded));
        return string.Join(" ", parts);
    }

    private static string QuoteIfNeeded(string value) =>
        value.Any(char.IsWhiteSpace) ? Quote(value) : value;

    private static string Quote(string value) =>
        "\"" + value.Replace("\"", "\\\"", StringComparison.Ordinal) + "\"";
}

internal sealed record InstalledProduct(
    string InstallDirectory,
    string ApplicationPath,
    string MaintenanceExecutablePath,
    string VersionDisplay,
    bool HasDesktopShortcut,
    bool HasStartMenuShortcut);
