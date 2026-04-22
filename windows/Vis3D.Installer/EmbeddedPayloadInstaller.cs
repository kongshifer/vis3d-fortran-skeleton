using System.ComponentModel;
using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Text;

namespace Vis3D.Installer;

internal sealed class EmbeddedPayloadInstaller
{
    private const string PayloadResourceName = "Vis3D.Installer.Payload.zip";
    private readonly InstallationRegistry installationRegistry = new();

    public bool HasPayload =>
        Assembly.GetExecutingAssembly().GetManifestResourceNames().Contains(PayloadResourceName, StringComparer.Ordinal);

    public InstalledProduct? GetInstalledProduct() =>
        installationRegistry.FindInstalledProduct();

    public PayloadSummary GetPayloadSummary()
    {
        try
        {
            using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResourceName);
            if (stream is null)
            {
                return new PayloadSummary(false, 0, 0);
            }

            using var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: false);
            var fileCount = archive.Entries.Count(entry => !string.IsNullOrEmpty(entry.Name));
            var totalBytes = archive.Entries
                .Where(entry => !string.IsNullOrEmpty(entry.Name))
                .Sum(entry => entry.Length);

            return new PayloadSummary(true, fileCount, totalBytes);
        }
        catch
        {
            return new PayloadSummary(false, 0, 0);
        }
    }

    public Task<InstallResult> InstallAsync(
        InstallRequest request,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        return Task.Run(
            () => InstallCore(request, progress, cancellationToken),
            cancellationToken);
    }

    public Task<UninstallResult> UninstallAsync(
        UninstallRequest request,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        return Task.Run(
            () => UninstallCore(request, progress, cancellationToken),
            cancellationToken);
    }

    private InstallResult InstallCore(
        InstallRequest request,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.InstallDirectory))
            {
                return InstallResult.Fail("The install directory cannot be empty.");
            }

            var installDirectory = Path.GetFullPath(request.InstallDirectory);
            if (!IsSafeInstallDirectory(installDirectory))
            {
                return InstallResult.Fail("The selected install directory is not valid.");
            }

            var applicationPath = Path.Combine(installDirectory, InstallerMetadata.ApplicationExecutableName);
            if (IsApplicationRunning(applicationPath))
            {
                return InstallResult.Fail("Close Vis3D before updating the installation.");
            }

            cancellationToken.ThrowIfCancellationRequested();

            using var payloadStream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResourceName);
            if (payloadStream is null)
            {
                return InstallResult.Fail("This installer does not contain an application payload. Rebuild the setup bundle first.");
            }

            Directory.CreateDirectory(installDirectory);

            using var archive = new ZipArchive(payloadStream, ZipArchiveMode.Read, leaveOpen: false);
            foreach (var entry in archive.Entries)
            {
                cancellationToken.ThrowIfCancellationRequested();

                var destinationPath = Path.GetFullPath(Path.Combine(installDirectory, entry.FullName));
                if (!IsPathInsideDirectory(destinationPath, installDirectory))
                {
                    return InstallResult.Fail("The installer payload contains an invalid path and was blocked.");
                }

                if (string.IsNullOrEmpty(entry.Name))
                {
                    Directory.CreateDirectory(destinationPath);
                    continue;
                }

                var directory = Path.GetDirectoryName(destinationPath);
                if (!string.IsNullOrWhiteSpace(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                entry.ExtractToFile(destinationPath, overwrite: true);
                progress?.Report($"Copied {entry.FullName}");
            }

            if (!File.Exists(applicationPath))
            {
                return InstallResult.Fail("The main application executable was not found after extraction.");
            }

            var maintenanceExecutablePath = CopyMaintenanceExecutable(installDirectory, progress);
            CreateShortcuts(request, installDirectory, applicationPath, maintenanceExecutablePath, progress);
            installationRegistry.RegisterInstallation(
                installDirectory,
                applicationPath,
                maintenanceExecutablePath,
                request.CreateDesktopShortcut,
                request.CreateStartMenuShortcut,
                ComputeDirectorySize(installDirectory));
            progress?.Report("Registered Vis3D in Windows Apps & Features.");
            TryCleanReplacedInstallDirectory(
                request.PreviousInstallDirectory,
                installDirectory,
                progress);

            return InstallResult.Success(
                applicationPath,
                maintenanceExecutablePath,
                installDirectory,
                "Installation completed successfully.");
        }
        catch (OperationCanceledException)
        {
            return InstallResult.Fail("Installation was cancelled.");
        }
        catch (Exception exception)
        {
            return InstallResult.Fail($"Installation failed: {exception.Message}");
        }
    }

    private UninstallResult UninstallCore(
        UninstallRequest request,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(request.InstallDirectory))
            {
                return UninstallResult.Fail("The install directory cannot be empty.");
            }

            var installDirectory = Path.GetFullPath(request.InstallDirectory);
            if (!IsSafeInstallDirectory(installDirectory))
            {
                return UninstallResult.Fail("The selected install directory is not valid.");
            }

            var applicationPath = Path.Combine(installDirectory, InstallerMetadata.ApplicationExecutableName);
            if (IsApplicationRunning(applicationPath))
            {
                return UninstallResult.Fail("Close Vis3D before removing the installation.");
            }

            cancellationToken.ThrowIfCancellationRequested();

            var currentExecutablePath = Environment.ProcessPath ?? string.Empty;
            var currentExecutableInsideInstallDirectory = IsPathInsideDirectory(currentExecutablePath, installDirectory);

            if (Directory.Exists(installDirectory))
            {
                if (currentExecutableInsideInstallDirectory)
                {
                    DeleteDirectoryContentsPreservingCurrentExecutable(installDirectory, currentExecutablePath, progress);
                    ScheduleFinalCleanup(currentExecutablePath, installDirectory, progress);
                }
                else
                {
                    DeleteDirectoryRecursively(installDirectory);
                    progress?.Report("Removed installed application files.");
                }
            }

            RemoveShortcuts(progress);
            installationRegistry.UnregisterInstallation();
            progress?.Report("Removed Windows Apps & Features registration.");

            return UninstallResult.Success(
                currentExecutableInsideInstallDirectory,
                currentExecutableInsideInstallDirectory
                    ? "Vis3D is ready to be removed. Close the setup window to finish cleanup."
                    : "Vis3D was removed successfully.");
        }
        catch (OperationCanceledException)
        {
            return UninstallResult.Fail("Removal was cancelled.");
        }
        catch (Exception exception)
        {
            return UninstallResult.Fail($"Removal failed: {exception.Message}");
        }
    }

    private string CopyMaintenanceExecutable(string installDirectory, IProgress<string>? progress)
    {
        var sourceExecutablePath = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(sourceExecutablePath) || !File.Exists(sourceExecutablePath))
        {
            throw new InvalidOperationException("The setup executable could not be located for maintenance registration.");
        }

        var destinationPath = Path.Combine(installDirectory, InstallerMetadata.MaintenanceExecutableName);
        if (!string.Equals(
                Path.GetFullPath(sourceExecutablePath),
                Path.GetFullPath(destinationPath),
                StringComparison.OrdinalIgnoreCase))
        {
            File.Copy(sourceExecutablePath, destinationPath, overwrite: true);
            progress?.Report("Installed the maintenance executable.");
        }

        return destinationPath;
    }

    private void CreateShortcuts(
        InstallRequest request,
        string installDirectory,
        string applicationPath,
        string maintenanceExecutablePath,
        IProgress<string>? progress)
    {
        var desktopShortcutPath = installationRegistry.GetDesktopShortcutPath();
        var startMenuFolderPath = installationRegistry.GetStartMenuFolderPath();
        var startMenuShortcutPath = installationRegistry.GetStartMenuAppShortcutPath();
        var startMenuUninstallShortcutPath = installationRegistry.GetStartMenuUninstallShortcutPath();

        if (request.CreateDesktopShortcut)
        {
            ShortcutHelper.CreateShortcut(
                desktopShortcutPath,
                applicationPath,
                installDirectory,
                "Open Vis3D",
                iconPath: applicationPath);
            progress?.Report("Created the desktop shortcut.");
        }
        else
        {
            DeleteFileIfExists(desktopShortcutPath);
        }

        if (request.CreateStartMenuShortcut)
        {
            Directory.CreateDirectory(startMenuFolderPath);
            ShortcutHelper.CreateShortcut(
                startMenuShortcutPath,
                applicationPath,
                installDirectory,
                "Open Vis3D",
                iconPath: applicationPath);
            ShortcutHelper.CreateShortcut(
                startMenuUninstallShortcutPath,
                maintenanceExecutablePath,
                installDirectory,
                "Remove Vis3D",
                arguments: $"--uninstall --install-dir \"{installDirectory}\"",
                iconPath: applicationPath);
            progress?.Report("Created the Start menu shortcuts.");
        }
        else
        {
            DeleteFileIfExists(startMenuShortcutPath);
            DeleteFileIfExists(startMenuUninstallShortcutPath);
            DeleteDirectoryIfEmpty(startMenuFolderPath);
        }
    }

    private void RemoveShortcuts(IProgress<string>? progress)
    {
        DeleteFileIfExists(installationRegistry.GetDesktopShortcutPath());
        DeleteFileIfExists(installationRegistry.GetStartMenuAppShortcutPath());
        DeleteFileIfExists(installationRegistry.GetStartMenuUninstallShortcutPath());
        DeleteDirectoryIfEmpty(installationRegistry.GetStartMenuFolderPath());
        progress?.Report("Removed shortcuts.");
    }

    private void TryCleanReplacedInstallDirectory(
        string? previousInstallDirectory,
        string currentInstallDirectory,
        IProgress<string>? progress)
    {
        if (string.IsNullOrWhiteSpace(previousInstallDirectory))
        {
            return;
        }

        try
        {
            var previousInstallFullPath = Path.GetFullPath(previousInstallDirectory);
            if (string.Equals(previousInstallFullPath, currentInstallDirectory, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            if (!IsSafeInstallDirectory(previousInstallFullPath) || !Directory.Exists(previousInstallFullPath))
            {
                return;
            }

            if (IsPathInsideDirectory(currentInstallDirectory, previousInstallFullPath)
                || IsPathInsideDirectory(previousInstallFullPath, currentInstallDirectory))
            {
                progress?.Report("Kept the previous installation directory because the old and new folders overlap.");
                return;
            }

            var previousApplicationPath = Path.Combine(previousInstallFullPath, InstallerMetadata.ApplicationExecutableName);
            if (IsApplicationRunning(previousApplicationPath))
            {
                progress?.Report("Kept the previous installation directory because Vis3D is still running from there.");
                return;
            }

            var currentExecutablePath = Environment.ProcessPath ?? string.Empty;
            var currentExecutableInsidePreviousInstall = IsPathInsideDirectory(currentExecutablePath, previousInstallFullPath);

            if (currentExecutableInsidePreviousInstall)
            {
                DeleteDirectoryContentsPreservingCurrentExecutable(previousInstallFullPath, currentExecutablePath, progress);
                ScheduleFinalCleanup(currentExecutablePath, previousInstallFullPath, progress);
                progress?.Report("Scheduled cleanup of the previous installation directory after setup closes.");
                return;
            }

            DeleteDirectoryRecursively(previousInstallFullPath);
            progress?.Report("Removed the previous installation directory.");
        }
        catch (Exception exception)
        {
            progress?.Report($"Kept the previous installation directory: {exception.Message}");
        }
    }

    private static long ComputeDirectorySize(string directoryPath)
    {
        if (!Directory.Exists(directoryPath))
        {
            return 0;
        }

        return Directory.EnumerateFiles(directoryPath, "*", SearchOption.AllDirectories)
            .Sum(filePath => new FileInfo(filePath).Length);
    }

    private static bool IsSafeInstallDirectory(string directoryPath)
    {
        if (!Path.IsPathFullyQualified(directoryPath))
        {
            return false;
        }

        var fullPath = Path.GetFullPath(directoryPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var rootPath = Path.GetPathRoot(fullPath)?.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return !string.IsNullOrWhiteSpace(rootPath)
            && !string.Equals(fullPath, rootPath, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsApplicationRunning(string applicationPath)
    {
        var expectedPath = Path.GetFullPath(applicationPath);
        var processName = Path.GetFileNameWithoutExtension(applicationPath);
        foreach (var process in Process.GetProcessesByName(processName))
        {
            try
            {
                if (string.Equals(
                        Path.GetFullPath(process.MainModule?.FileName ?? string.Empty),
                        expectedPath,
                        StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            catch (InvalidOperationException)
            {
            }
            catch (Win32Exception)
            {
            }
            finally
            {
                process.Dispose();
            }
        }

        return false;
    }

    private static bool IsPathInsideDirectory(string filePath, string directoryPath)
    {
        if (string.IsNullOrWhiteSpace(filePath))
        {
            return false;
        }

        var fullFilePath = Path.GetFullPath(filePath);
        var fullDirectoryPath = Path.GetFullPath(directoryPath)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            + Path.DirectorySeparatorChar;

        return fullFilePath.StartsWith(fullDirectoryPath, StringComparison.OrdinalIgnoreCase)
            || string.Equals(
                fullFilePath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                fullDirectoryPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                StringComparison.OrdinalIgnoreCase);
    }

    private static void DeleteDirectoryContentsPreservingCurrentExecutable(
        string installDirectory,
        string currentExecutablePath,
        IProgress<string>? progress)
    {
        foreach (var filePath in Directory.EnumerateFiles(installDirectory))
        {
            if (string.Equals(
                    Path.GetFullPath(filePath),
                    Path.GetFullPath(currentExecutablePath),
                    StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            DeleteFileIfExists(filePath);
            progress?.Report($"Removed {Path.GetFileName(filePath)}");
        }

        foreach (var directoryPath in Directory.EnumerateDirectories(installDirectory))
        {
            DeleteDirectoryRecursively(directoryPath);
            progress?.Report($"Removed {Path.GetFileName(directoryPath)}");
        }
    }

    private static void DeleteDirectoryRecursively(string directoryPath)
    {
        foreach (var filePath in Directory.EnumerateFiles(directoryPath, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(filePath, FileAttributes.Normal);
        }

        Directory.Delete(directoryPath, recursive: true);
    }

    private static void DeleteFileIfExists(string filePath)
    {
        if (!File.Exists(filePath))
        {
            return;
        }

        File.SetAttributes(filePath, FileAttributes.Normal);
        File.Delete(filePath);
    }

    private static void DeleteDirectoryIfEmpty(string directoryPath)
    {
        if (!Directory.Exists(directoryPath))
        {
            return;
        }

        if (!Directory.EnumerateFileSystemEntries(directoryPath).Any())
        {
            Directory.Delete(directoryPath, recursive: false);
        }
    }

    private static void ScheduleFinalCleanup(
        string currentExecutablePath,
        string installDirectory,
        IProgress<string>? progress)
    {
        var cleanupDirectory = Path.Combine(Path.GetTempPath(), "Vis3D");
        Directory.CreateDirectory(cleanupDirectory);

        var cleanupScriptPath = Path.Combine(cleanupDirectory, $"cleanup-{Guid.NewGuid():N}.ps1");
        var scriptContents = BuildCleanupScript(
            Environment.ProcessId,
            currentExecutablePath,
            installDirectory);
        File.WriteAllText(cleanupScriptPath, scriptContents, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

        Process.Start(new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{cleanupScriptPath}\"",
            CreateNoWindow = true,
            UseShellExecute = false,
            WindowStyle = ProcessWindowStyle.Hidden
        });
        progress?.Report("Scheduled final cleanup after the setup window closes.");
    }

    private static string BuildCleanupScript(int processId, string executablePath, string installDirectory)
    {
        var escapedExecutablePath = EscapePowerShellLiteral(executablePath);
        var escapedInstallDirectory = EscapePowerShellLiteral(installDirectory);

        return
            "$ErrorActionPreference = 'SilentlyContinue'" + Environment.NewLine +
            $"$processId = {processId}" + Environment.NewLine +
            "while (Get-Process -Id $processId -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 500 }" + Environment.NewLine +
            "Start-Sleep -Milliseconds 500" + Environment.NewLine +
            $"Remove-Item -LiteralPath '{escapedExecutablePath}' -Force -ErrorAction SilentlyContinue" + Environment.NewLine +
            $"if (Test-Path -LiteralPath '{escapedInstallDirectory}') {{ Remove-Item -LiteralPath '{escapedInstallDirectory}' -Recurse -Force -ErrorAction SilentlyContinue }}" + Environment.NewLine +
            "Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue";
    }

    private static string EscapePowerShellLiteral(string value) =>
        value.Replace("'", "''", StringComparison.Ordinal);
}

internal sealed record InstallRequest(
    string InstallDirectory,
    bool CreateDesktopShortcut,
    bool CreateStartMenuShortcut,
    string? PreviousInstallDirectory = null);

internal sealed record UninstallRequest(string InstallDirectory);

internal sealed record InstallResult(
    bool Succeeded,
    string ApplicationPath,
    string MaintenanceExecutablePath,
    string InstallDirectory,
    string Message)
{
    public static InstallResult Success(
        string applicationPath,
        string maintenanceExecutablePath,
        string installDirectory,
        string message) =>
        new(true, applicationPath, maintenanceExecutablePath, installDirectory, message);

    public static InstallResult Fail(string message) =>
        new(false, string.Empty, string.Empty, string.Empty, message);
}

internal sealed record UninstallResult(
    bool Succeeded,
    bool RequiresClosingSetupForCleanup,
    string Message)
{
    public static UninstallResult Success(bool requiresClosingSetupForCleanup, string message) =>
        new(true, requiresClosingSetupForCleanup, message);

    public static UninstallResult Fail(string message) =>
        new(false, false, message);
}

internal sealed record PayloadSummary(bool IsAvailable, int FileCount, long TotalBytes)
{
    public string HumanReadableSize =>
        !IsAvailable ? "Unavailable" :
        TotalBytes >= 1024L * 1024L ? $"{TotalBytes / 1024d / 1024d:F1} MB" :
        TotalBytes >= 1024L ? $"{TotalBytes / 1024d:F1} KB" :
        $"{TotalBytes} bytes";
}
