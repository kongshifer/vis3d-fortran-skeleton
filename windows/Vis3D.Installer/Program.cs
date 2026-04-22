using System.Diagnostics;

namespace Vis3D.Installer;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (!InstallerCli.TryParse(args, out var options, out var errorMessage))
        {
            MessageBox.Show(errorMessage, InstallerMetadata.SetupName, MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.Exit(1);
            return;
        }

        if (options.QuietMode)
        {
            RunQuietMode(options);
            return;
        }

        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm(options));
    }

    private static void RunQuietMode(InstallerCliOptions options)
    {
        var installer = new EmbeddedPayloadInstaller();
        var installedProduct = installer.GetInstalledProduct();
        var installDirectory = ResolveInstallDirectory(options, installedProduct);
        if (string.IsNullOrWhiteSpace(installDirectory))
        {
            Console.Error.WriteLine("A valid install directory could not be resolved.");
            Environment.Exit(1);
            return;
        }

        if (options.UninstallRequested)
        {
            var uninstallResult = installer.UninstallAsync(
                    new UninstallRequest(installDirectory),
                    progress: null,
                    CancellationToken.None)
                .GetAwaiter()
                .GetResult();
            if (!uninstallResult.Succeeded)
            {
                Console.Error.WriteLine(uninstallResult.Message);
            }
            Environment.Exit(uninstallResult.Succeeded ? 0 : 1);
            return;
        }

        var installResult = installer.InstallAsync(
                new InstallRequest(
                    installDirectory,
                    options.CreateDesktopShortcut,
                    options.CreateStartMenuShortcut,
                    installedProduct?.InstallDirectory),
                progress: null,
                CancellationToken.None)
            .GetAwaiter()
            .GetResult();

        if (!installResult.Succeeded)
        {
            Console.Error.WriteLine(installResult.Message);
            Environment.Exit(1);
            return;
        }

        if (options.LaunchAfterInstall && File.Exists(installResult.ApplicationPath))
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = installResult.ApplicationPath,
                UseShellExecute = true
            });
        }
    }

    private static string ResolveInstallDirectory(InstallerCliOptions options, InstalledProduct? installedProduct)
    {
        if (!string.IsNullOrWhiteSpace(options.InstallDirectory))
        {
            return options.InstallDirectory;
        }

        if (options.UninstallRequested)
        {
            return installedProduct?.InstallDirectory ?? string.Empty;
        }

        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            InstallerMetadata.ProductName);
    }
}

internal sealed class InstallerCliOptions
{
    public bool QuietMode { get; init; }

    public bool UninstallRequested { get; init; }

    public string InstallDirectory { get; init; } = string.Empty;

    public bool CreateDesktopShortcut { get; init; } = true;

    public bool CreateStartMenuShortcut { get; init; } = true;

    public bool LaunchAfterInstall { get; init; }
}

internal static class InstallerCli
{
    public static bool TryParse(string[] args, out InstallerCliOptions options, out string errorMessage)
    {
        options = new InstallerCliOptions();
        errorMessage = string.Empty;

        if (args.Length == 0)
        {
            return true;
        }

        var quietMode = false;
        var uninstallRequested = false;
        var installDirectory = string.Empty;
        var desktopShortcut = true;
        var startMenuShortcut = true;
        var launchAfterInstall = false;

        for (var index = 0; index < args.Length; index++)
        {
            switch (args[index])
            {
                case "--quiet":
                    quietMode = true;
                    break;
                case "--uninstall":
                    uninstallRequested = true;
                    break;
                case "--install-dir":
                    if (index + 1 >= args.Length)
                    {
                        errorMessage = "Missing a directory value after --install-dir.";
                        return false;
                    }

                    installDirectory = args[++index];
                    break;
                case "--no-desktop-shortcut":
                    desktopShortcut = false;
                    break;
                case "--no-start-menu-shortcut":
                    startMenuShortcut = false;
                    break;
                case "--launch":
                    launchAfterInstall = true;
                    break;
                default:
                    errorMessage = $"Unsupported argument: {args[index]}";
                    return false;
            }
        }

        if (quietMode && !uninstallRequested && string.IsNullOrWhiteSpace(installDirectory))
        {
            errorMessage = "Silent installs require --install-dir.";
            return false;
        }

        if (launchAfterInstall && uninstallRequested)
        {
            errorMessage = "--launch cannot be used together with --uninstall.";
            return false;
        }

        options = new InstallerCliOptions
        {
            QuietMode = quietMode,
            UninstallRequested = uninstallRequested,
            InstallDirectory = installDirectory,
            CreateDesktopShortcut = desktopShortcut,
            CreateStartMenuShortcut = startMenuShortcut,
            LaunchAfterInstall = launchAfterInstall
        };
        return true;
    }
}
