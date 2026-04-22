using System.Diagnostics;

namespace Vis3D.App;

internal sealed class BackendRunner
{
    private static readonly string[] OutputExtensions = { ".vti", ".vtp", ".vtu" };
    private readonly string backendExecutablePath;

    public BackendRunner(string appBaseDirectory)
    {
        backendExecutablePath = Path.Combine(appBaseDirectory, "backend", "vis3d_export_demo.exe");
    }

    public string BackendExecutablePath => backendExecutablePath;

    public bool IsAvailable => File.Exists(backendExecutablePath);

    public async Task<ConversionResult> ConvertAsync(
        ConversionRequest request,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        if (!IsAvailable)
        {
            return ConversionResult.Fail("The backend executable is missing. Reinstall Vis3D or restore the backend folder.");
        }

        Directory.CreateDirectory(request.OutputDirectory);

        var startTimeUtc = DateTime.UtcNow.AddSeconds(-2);
        var stopwatch = Stopwatch.StartNew();
        var startInfo = new ProcessStartInfo
        {
            FileName = backendExecutablePath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(backendExecutablePath) ?? AppContext.BaseDirectory
        };

        startInfo.ArgumentList.Add("--syntax");
        startInfo.ArgumentList.Add(request.Syntax);
        startInfo.ArgumentList.Add("--output-dir");
        startInfo.ArgumentList.Add(request.OutputDirectory);
        startInfo.ArgumentList.Add(request.InputFile);

        using var process = new Process { StartInfo = startInfo };

        try
        {
            if (!process.Start())
            {
                return ConversionResult.Fail("Vis3D could not start the backend conversion process.");
            }
        }
        catch (Exception ex)
        {
            return ConversionResult.Fail($"Unable to start the backend process: {ex.Message}");
        }

        var stdoutTask = PumpLinesAsync(process.StandardOutput, progress, cancellationToken);
        var stderrTask = PumpLinesAsync(process.StandardError, progress, cancellationToken);

        await process.WaitForExitAsync(cancellationToken);
        await Task.WhenAll(stdoutTask, stderrTask);
        stopwatch.Stop();

        var outputFile = FindOutputFile(request, startTimeUtc);
        if (process.ExitCode == 0)
        {
            var message = outputFile is null
                ? $"Conversion finished in {stopwatch.Elapsed.TotalSeconds:F1}s, but Vis3D could not locate the output file automatically."
                : $"Conversion finished in {stopwatch.Elapsed.TotalSeconds:F1}s.";
            return ConversionResult.Success(outputFile, message, stopwatch.Elapsed);
        }

        return ConversionResult.Fail($"The backend exited with code {process.ExitCode}. Review the log for details.");
    }

    private static async Task PumpLinesAsync(
        StreamReader reader,
        IProgress<string>? progress,
        CancellationToken cancellationToken)
    {
        while (!reader.EndOfStream && !cancellationToken.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync();
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            progress?.Report(line.Trim());
        }
    }

    private static string? FindOutputFile(ConversionRequest request, DateTime startTimeUtc)
    {
        var baseName = Path.GetFileNameWithoutExtension(request.InputFile);
        var candidates = Directory
            .EnumerateFiles(request.OutputDirectory, $"{baseName}.*", SearchOption.TopDirectoryOnly)
            .Where(path => OutputExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase))
            .Select(path => new FileInfo(path))
            .Where(info => info.LastWriteTimeUtc >= startTimeUtc)
            .OrderByDescending(info => info.LastWriteTimeUtc)
            .ToList();

        if (candidates.Count > 0)
        {
            return candidates[0].FullName;
        }

        var fallbackPath = Path.Combine(request.OutputDirectory, $"{baseName}{GetFallbackExtension(request)}");
        return File.Exists(fallbackPath) ? fallbackPath : null;
    }

    private static string GetFallbackExtension(ConversionRequest request)
    {
        return request.Syntax switch
        {
            "mcnp" => ".vti",
            "mcx" => ".vtp",
            _ => Path.GetExtension(request.InputFile).Equals(".xml", StringComparison.OrdinalIgnoreCase)
                ? ".vtp"
                : ".vti"
        };
    }
}

internal sealed record ConversionRequest(string InputFile, string Syntax, string OutputDirectory);

internal sealed record ConversionResult(
    bool Succeeded,
    string? OutputFile,
    string Message,
    TimeSpan Duration)
{
    public static ConversionResult Success(string? outputFile, string message, TimeSpan duration) =>
        new(true, outputFile, message, duration);

    public static ConversionResult Fail(string message) =>
        new(false, null, message, TimeSpan.Zero);
}
