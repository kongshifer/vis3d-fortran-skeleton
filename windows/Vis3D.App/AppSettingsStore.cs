using System.Text.Json;

namespace Vis3D.App;

internal sealed class AppSettingsStore
{
    private readonly JsonSerializerOptions jsonOptions = new() { WriteIndented = true };
    private readonly string settingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Vis3D",
        "settings.json");

    public AppSettings Load()
    {
        try
        {
            if (!File.Exists(settingsPath))
            {
                return new AppSettings();
            }

            var json = File.ReadAllText(settingsPath);
            var settings = JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            settings.Normalize();
            return settings;
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        try
        {
            settings.Normalize();
            var folder = Path.GetDirectoryName(settingsPath);
            if (!string.IsNullOrWhiteSpace(folder))
            {
                Directory.CreateDirectory(folder);
            }

            var json = JsonSerializer.Serialize(settings, jsonOptions);
            File.WriteAllText(settingsPath, json);
        }
        catch
        {
            // Ignore persistence failures.
        }
    }
}

internal sealed class AppSettings
{
    public string LastInputFile { get; set; } = string.Empty;

    public string LastOutputDirectory { get; set; } = string.Empty;

    public string LastSyntax { get; set; } = "auto";

    public bool OpenOutputDirectory { get; set; } = true;

    public List<string> RecentFiles { get; set; } = new();

    public void Normalize()
    {
        if (string.IsNullOrWhiteSpace(LastSyntax))
        {
            LastSyntax = "auto";
        }

        RecentFiles = RecentFiles
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(8)
            .ToList();
    }
}
