using System.Diagnostics;

namespace Vis3D.App;

internal sealed class MainForm : Form
{
    private readonly AppSettingsStore settingsStore = new();
    private readonly BackendRunner backendRunner = new(AppContext.BaseDirectory);
    private readonly TextBox inputFileTextBox = new();
    private readonly TextBox outputDirectoryTextBox = new();
    private readonly ComboBox syntaxComboBox = new();
    private readonly PickerButton browseInputButton = new();
    private readonly PickerButton browseOutputButton = new();
    private readonly Button convertButton = new();
    private readonly Button openOutputFileButton = new();
    private readonly Button openOutputFolderButton = new();
    private readonly Button copyLogButton = new();
    private readonly Button clearLogButton = new();
    private readonly Button openGuideButton = new();
    private readonly CheckBox openOutputCheckBox = new();
    private readonly Label detectedSyntaxLabel = new();
    private readonly Label dropHintLabel = new();
    private readonly Label statusLabel = new();
    private readonly Label backendLabel = new();
    private readonly Label lastOutputLabel = new();
    private readonly Label lastDurationLabel = new();
    private readonly Label lastFormatLabel = new();
    private readonly Label summaryLabel = new();
    private readonly Label recentHintLabel = new();
    private readonly ListBox recentFilesListBox = new();
    private readonly RichTextBox logTextBox = new();
    private readonly ProgressBar progressBar = new();
    private readonly ToolStripStatusLabel shellStatusLabel = new() { Spring = true, TextAlign = ContentAlignment.MiddleLeft };
    private readonly ToolStripStatusLabel versionStatusLabel = new() { TextAlign = ContentAlignment.MiddleRight };
    private readonly Size expandableResultLabelSize = new(720, 0);
    private AppSettings settings = new();
    private bool isBusy;
    private string? lastOutputFile;

    public MainForm()
    {
        Text = AppMetadata.ProductName;
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(1180, 780);
        Size = new Size(1260, 860);
        Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
        BackColor = Color.FromArgb(244, 247, 250);
        AllowDrop = true;

        InitializeUi();
        LoadSettings();
        ApplySettings();
        UpdateBackendStatus();
        UpdateDetectedSyntax();
        UpdateSummary(null);
    }

    private void InitializeUi()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 176F));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        root.Controls.Add(BuildBanner(), 0, 0);
        root.Controls.Add(BuildBody(), 0, 1);
        root.Controls.Add(BuildStatusBar(), 0, 2);

        Controls.Add(root);

        DragEnter += OnAnyDragEnter;
        DragDrop += OnAnyDragDrop;
        AcceptButton = convertButton;
    }

    private Control BuildBanner()
    {
        var banner = new BrandBannerPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(30, 18, 30, 18)
        };

        var titleLabel = new Label
        {
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 28F, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = Color.White,
            Text = AppMetadata.ProductName
        };

        var subtitleLabel = new Label
        {
            AutoSize = true,
            Font = new Font("Segoe UI", 12F, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(244, 249, 252),
            MaximumSize = new Size(820, 0),
            Text = "A desktop workspace for turning MCX and MCNP geometry files into ParaView-ready VTK outputs with one click."
        };

        var versionLabel = new Label
        {
            AutoSize = true,
            Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(223, 239, 248),
            Text = $"Version {AppMetadata.VersionDisplay}"
        };

        var layout = new TransparentTableLayoutPanel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.Transparent,
            ColumnCount = 1,
            RowCount = 3,
            Padding = new Padding(10, 8, 0, 0)
        };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.Controls.Add(titleLabel, 0, 0);
        layout.Controls.Add(subtitleLabel, 0, 1);
        layout.Controls.Add(versionLabel, 0, 2);

        banner.Controls.Add(layout);
        return banner;
    }

    private Control BuildBody()
    {
        var split = new SplitContainer
        {
            Dock = DockStyle.Fill,
            Orientation = Orientation.Vertical,
            SplitterDistance = 820,
            FixedPanel = FixedPanel.Panel2,
            SplitterWidth = 8,
            BackColor = BackColor,
            Padding = new Padding(18, 18, 18, 18)
        };

        split.Panel1.Padding = new Padding(0, 0, 12, 0);
        split.Panel2.Padding = new Padding(12, 0, 0, 0);

        var mainScrollHost = new Panel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            BackColor = BackColor
        };
        mainScrollHost.Controls.Add(BuildMainWorkspace());

        var sidebarScrollHost = new Panel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            BackColor = BackColor
        };
        sidebarScrollHost.Controls.Add(BuildSidebar());

        split.Panel1.Controls.Add(mainScrollHost);
        split.Panel2.Controls.Add(sidebarScrollHost);
        return split;
    }

    private Control BuildMainWorkspace()
    {
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            ColumnCount = 1,
            RowCount = 5
        };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        layout.Controls.Add(BuildWorkspaceCard(), 0, 0);
        layout.Controls.Add(BuildDropCard(), 0, 1);
        layout.Controls.Add(BuildActionCard(), 0, 2);
        layout.Controls.Add(BuildResultCard(), 0, 3);
        layout.Controls.Add(BuildLogCard(), 0, 4);
        return layout;
    }

    private Control BuildSidebar()
    {
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            ColumnCount = 1,
            RowCount = 4
        };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        layout.Controls.Add(BuildAboutCard(), 0, 0);
        layout.Controls.Add(BuildRecentFilesCard(), 0, 1);
        layout.Controls.Add(BuildTipsCard(), 0, 2);
        layout.Controls.Add(BuildSupportCard(), 0, 3);
        return layout;
    }

    private Control BuildWorkspaceCard()
    {
        var card = CreateCard("Workspace", out var body);

        inputFileTextBox.Dock = DockStyle.Fill;
        inputFileTextBox.PlaceholderText = "Choose an input file or drop one into the area below";
        inputFileTextBox.TextChanged += (_, _) => OnInputPathChanged();

        browseInputButton.Text = "Select file";
        browseInputButton.Dock = DockStyle.Fill;
        browseInputButton.Click += (_, _) => BrowseInputFile();

        syntaxComboBox.Dock = DockStyle.Left;
        syntaxComboBox.Width = 200;
        syntaxComboBox.DropDownStyle = ComboBoxStyle.DropDownList;
        syntaxComboBox.Items.AddRange(new object[] { "auto", "mcx", "mcnp" });
        syntaxComboBox.SelectedIndexChanged += (_, _) => UpdateDetectedSyntax();

        detectedSyntaxLabel.AutoSize = true;
        detectedSyntaxLabel.ForeColor = Color.FromArgb(82, 96, 110);
        detectedSyntaxLabel.Margin = new Padding(18, 8, 0, 0);

        outputDirectoryTextBox.Dock = DockStyle.Fill;
        outputDirectoryTextBox.PlaceholderText = "Choose where the converted file should be written";

        browseOutputButton.Text = "Select folder";
        browseOutputButton.Dock = DockStyle.Fill;
        browseOutputButton.Click += (_, _) => BrowseOutputDirectory();

        openOutputCheckBox.Text = "Open the output folder after a successful conversion";
        openOutputCheckBox.AutoSize = true;

        var grid = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 3,
            RowCount = 4
        };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 140F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 150F));

        grid.Controls.Add(BuildFieldLabel("Input file"), 0, 0);
        grid.Controls.Add(inputFileTextBox, 1, 0);
        grid.Controls.Add(browseInputButton, 2, 0);

        grid.Controls.Add(BuildFieldLabel("Syntax"), 0, 1);
        grid.Controls.Add(syntaxComboBox, 1, 1);
        grid.Controls.Add(detectedSyntaxLabel, 2, 1);

        grid.Controls.Add(BuildFieldLabel("Output folder"), 0, 2);
        grid.Controls.Add(outputDirectoryTextBox, 1, 2);
        grid.Controls.Add(browseOutputButton, 2, 2);

        grid.Controls.Add(new Label { AutoSize = true }, 0, 3);
        grid.Controls.Add(openOutputCheckBox, 1, 3);

        body.Controls.Add(grid, 0, 0);
        return card;
    }

    private Control BuildDropCard()
    {
        var panel = new Panel
        {
            Dock = DockStyle.Top,
            Height = 150,
            MinimumSize = new Size(0, 150),
            Margin = new Padding(0, 14, 0, 0),
            BackColor = Color.White,
            Padding = new Padding(2)
        };

        var inner = new Panel
        {
            Dock = DockStyle.Fill,
            AllowDrop = true,
            BackColor = Color.FromArgb(249, 251, 253)
        };
        inner.Paint += (_, e) =>
        {
            using var pen = new Pen(Color.FromArgb(188, 201, 213), 2F) { DashPattern = new[] { 6F, 6F } };
            e.Graphics.DrawRectangle(pen, 6, 6, inner.Width - 14, inner.Height - 14);
        };
        inner.DragEnter += OnAnyDragEnter;
        inner.DragDrop += OnAnyDragDrop;

        dropHintLabel.Dock = DockStyle.Fill;
        dropHintLabel.TextAlign = ContentAlignment.MiddleCenter;
        dropHintLabel.Font = new Font("Segoe UI Semibold", 13F, FontStyle.Bold, GraphicsUnit.Point);
        dropHintLabel.ForeColor = Color.FromArgb(58, 76, 90);
        dropHintLabel.Text = "Drop a file here to start a new conversion session";

        inner.Controls.Add(dropHintLabel);
        panel.Controls.Add(inner);
        return panel;
    }

    private Control BuildActionCard()
    {
        var card = CreateCard("Run conversion", out var body);
        card.Margin = new Padding(0, 14, 0, 0);

        convertButton.Text = "Convert now";
        convertButton.AutoSize = true;
        convertButton.Padding = new Padding(24, 10, 24, 10);
        convertButton.Click += async (_, _) => await ConvertAsync();
        StylePrimaryButton(convertButton);

        progressBar.Dock = DockStyle.Fill;
        progressBar.Height = 14;

        statusLabel.AutoSize = true;
        statusLabel.ForeColor = Color.FromArgb(82, 96, 110);
        statusLabel.Text = "Ready";

        var actionRow = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 3,
            RowCount = 2
        };
        actionRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        actionRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        actionRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));

        actionRow.Controls.Add(convertButton, 0, 0);
        actionRow.Controls.Add(statusLabel, 1, 0);
        actionRow.Controls.Add(new Label { AutoSize = true }, 2, 0);
        actionRow.Controls.Add(progressBar, 0, 1);
        actionRow.SetColumnSpan(progressBar, 3);

        body.Controls.Add(actionRow, 0, 0);
        return card;
    }

    private Control BuildResultCard()
    {
        var card = CreateCard("Latest result", out var body);
        card.Margin = new Padding(0, 14, 0, 0);

        summaryLabel.AutoSize = true;
        summaryLabel.ForeColor = Color.FromArgb(52, 66, 78);
        summaryLabel.MaximumSize = expandableResultLabelSize;

        lastOutputLabel.AutoSize = true;
        lastOutputLabel.MaximumSize = expandableResultLabelSize;
        lastDurationLabel.AutoSize = true;
        lastFormatLabel.AutoSize = true;

        openOutputFileButton.Text = "Open output file";
        openOutputFileButton.AutoSize = true;
        openOutputFileButton.Click += (_, _) => OpenOutputFile();
        StyleSecondaryButton(openOutputFileButton);

        openOutputFolderButton.Text = "Open output folder";
        openOutputFolderButton.AutoSize = true;
        openOutputFolderButton.Click += (_, _) => OpenOutputFolder();
        StyleSecondaryButton(openOutputFolderButton);

        var details = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 2,
            RowCount = 4
        };
        details.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 120F));
        details.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        details.Controls.Add(BuildFieldLabel("Summary"), 0, 0);
        details.Controls.Add(summaryLabel, 1, 0);
        details.Controls.Add(BuildFieldLabel("Output"), 0, 1);
        details.Controls.Add(lastOutputLabel, 1, 1);
        details.Controls.Add(BuildFieldLabel("Duration"), 0, 2);
        details.Controls.Add(lastDurationLabel, 1, 2);
        details.Controls.Add(BuildFieldLabel("Format"), 0, 3);
        details.Controls.Add(lastFormatLabel, 1, 3);

        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            FlowDirection = FlowDirection.LeftToRight,
            AutoSize = true,
            Margin = new Padding(0, 12, 0, 0)
        };
        buttons.Controls.Add(openOutputFileButton);
        buttons.Controls.Add(openOutputFolderButton);

        body.Controls.Add(details, 0, 0);
        body.Controls.Add(buttons, 0, 1);
        return card;
    }

    private Control BuildLogCard()
    {
        var card = CreateCard("Session log", out var body);
        card.Margin = new Padding(0, 14, 0, 0);

        clearLogButton.Text = "Clear";
        clearLogButton.AutoSize = true;
        clearLogButton.Click += (_, _) => logTextBox.Clear();
        StyleSecondaryButton(clearLogButton);

        copyLogButton.Text = "Copy log";
        copyLogButton.AutoSize = true;
        copyLogButton.Click += (_, _) => CopyLogToClipboard();
        StyleSecondaryButton(copyLogButton);

        var headerActions = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            FlowDirection = FlowDirection.RightToLeft,
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 12)
        };
        headerActions.Controls.Add(clearLogButton);
        headerActions.Controls.Add(copyLogButton);

        logTextBox.Dock = DockStyle.Fill;
        logTextBox.ReadOnly = true;
        logTextBox.BackColor = Color.FromArgb(249, 251, 252);
        logTextBox.BorderStyle = BorderStyle.FixedSingle;
        logTextBox.Font = new Font("Consolas", 10F, FontStyle.Regular, GraphicsUnit.Point);

        var logHost = new Panel
        {
            Dock = DockStyle.Top,
            Height = 220,
            MinimumSize = new Size(0, 220)
        };
        logHost.Controls.Add(logTextBox);

        body.Controls.Add(headerActions, 0, 0);
        body.Controls.Add(logHost, 0, 1);
        return card;
    }

    private Control BuildAboutCard()
    {
        var card = CreateCard("Overview", out var body);

        var blurb = new Label
        {
            AutoSize = true,
            MaximumSize = new Size(280, 0),
            ForeColor = Color.FromArgb(70, 84, 97),
            Text = "Vis3D wraps the Fortran exporter in a friendlier desktop workspace. Use it when you want drag-and-drop conversion, recent files, and installer-based deployment."
        };

        backendLabel.AutoSize = true;
        backendLabel.MaximumSize = new Size(280, 0);
        backendLabel.ForeColor = Color.FromArgb(82, 96, 110);

        body.Controls.Add(blurb, 0, 0);
        body.Controls.Add(backendLabel, 0, 1);
        return card;
    }

    private Control BuildRecentFilesCard()
    {
        var card = CreateCard("Recent files", out var body);
        card.Margin = new Padding(0, 14, 0, 0);

        recentHintLabel.AutoSize = true;
        recentHintLabel.ForeColor = Color.FromArgb(82, 96, 110);

        recentFilesListBox.Dock = DockStyle.Fill;
        recentFilesListBox.IntegralHeight = false;
        recentFilesListBox.DoubleClick += (_, _) => UseSelectedRecentFile();

        var listHost = new Panel
        {
            Dock = DockStyle.Top,
            Height = 230,
            MinimumSize = new Size(0, 230)
        };
        listHost.Controls.Add(recentFilesListBox);

        var buttonBar = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            FlowDirection = FlowDirection.LeftToRight,
            AutoSize = true,
            Margin = new Padding(0, 10, 0, 0)
        };

        var useButton = new Button { Text = "Use selected", AutoSize = true };
        useButton.Click += (_, _) => UseSelectedRecentFile();
        StyleSecondaryButton(useButton);

        var removeButton = new Button { Text = "Remove", AutoSize = true };
        removeButton.Click += (_, _) => RemoveSelectedRecentFile();
        StyleSecondaryButton(removeButton);

        var clearButton = new Button { Text = "Clear all", AutoSize = true };
        clearButton.Click += (_, _) => ClearRecentFiles();
        StyleSecondaryButton(clearButton);

        buttonBar.Controls.Add(useButton);
        buttonBar.Controls.Add(removeButton);
        buttonBar.Controls.Add(clearButton);

        body.Controls.Add(recentHintLabel, 0, 0);
        body.Controls.Add(listHost, 0, 1);
        body.Controls.Add(buttonBar, 0, 2);
        return card;
    }

    private Control BuildTipsCard()
    {
        var card = CreateCard("Tips", out var body);
        card.Margin = new Padding(0, 14, 0, 0);

        var text = new Label
        {
            AutoSize = true,
            MaximumSize = new Size(280, 0),
            ForeColor = Color.FromArgb(70, 84, 97),
            Text = "Use auto syntax unless you know the file type. XML files usually resolve as MCX. Most non-XML inputs will be treated as MCNP. The output format still follows the backend rules you already use today."
        };

        body.Controls.Add(text, 0, 0);
        return card;
    }

    private Control BuildSupportCard()
    {
        var card = CreateCard("Help", out var body);
        card.Margin = new Padding(0, 14, 0, 0);

        var text = new Label
        {
            AutoSize = true,
            MaximumSize = new Size(280, 0),
            ForeColor = Color.FromArgb(70, 84, 97),
            Text = "The packaged desktop build can include a local guide. You can also inspect the live backend log here whenever a conversion fails."
        };

        openGuideButton.Text = "Open local guide";
        openGuideButton.AutoSize = true;
        openGuideButton.Click += (_, _) => OpenLocalGuide();
        StyleSecondaryButton(openGuideButton);

        body.Controls.Add(text, 0, 0);
        body.Controls.Add(openGuideButton, 0, 1);
        return card;
    }

    private Control BuildStatusBar()
    {
        versionStatusLabel.Text = $"{AppMetadata.ProductName} {AppMetadata.VersionDisplay}";

        var statusStrip = new StatusStrip
        {
            Dock = DockStyle.Fill,
            SizingGrip = false
        };
        statusStrip.Items.Add(shellStatusLabel);
        statusStrip.Items.Add(versionStatusLabel);
        return statusStrip;
    }

    private Panel CreateCard(string title, out TableLayoutPanel body)
    {
        var card = new Panel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            BackColor = Color.White,
            BorderStyle = BorderStyle.FixedSingle,
            Margin = new Padding(0)
        };

        var titleLabel = new Label
        {
            Dock = DockStyle.Top,
            Height = 42,
            Font = new Font("Segoe UI Semibold", 12F, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(34, 51, 66),
            Padding = new Padding(16, 12, 16, 0),
            Text = title
        };

        body = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            ColumnCount = 1,
            RowCount = 8,
            Padding = new Padding(16, 8, 16, 16)
        };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));

        card.Controls.Add(body);
        card.Controls.Add(titleLabel);
        return card;
    }

    private static Label BuildFieldLabel(string text) =>
        new()
        {
            Text = text,
            Dock = DockStyle.Fill,
            AutoSize = true,
            ForeColor = Color.FromArgb(82, 96, 110),
            Padding = new Padding(0, 8, 0, 0)
        };

    private static void StylePrimaryButton(Button button)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = Color.FromArgb(18, 116, 140);
        button.ForeColor = Color.White;
    }

    private static void StyleSecondaryButton(Button button)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = Color.FromArgb(194, 206, 218);
        button.FlatAppearance.BorderSize = 1;
        button.BackColor = Color.White;
        button.ForeColor = Color.FromArgb(40, 56, 70);
        button.Padding = new Padding(10, 6, 10, 6);
    }

    private void LoadSettings()
    {
        settings = settingsStore.Load();
    }

    private void ApplySettings()
    {
        inputFileTextBox.Text = settings.LastInputFile;
        outputDirectoryTextBox.Text = settings.LastOutputDirectory;
        openOutputCheckBox.Checked = settings.OpenOutputDirectory;

        if (syntaxComboBox.Items.Contains(settings.LastSyntax))
        {
            syntaxComboBox.SelectedItem = settings.LastSyntax;
        }
        else
        {
            syntaxComboBox.SelectedItem = "auto";
        }

        RefreshRecentFiles();
        UpdateDropHint();
    }

    private void SaveSettings()
    {
        settings.LastInputFile = inputFileTextBox.Text.Trim();
        settings.LastOutputDirectory = outputDirectoryTextBox.Text.Trim();
        settings.LastSyntax = syntaxComboBox.SelectedItem?.ToString() ?? "auto";
        settings.OpenOutputDirectory = openOutputCheckBox.Checked;
        settings.Normalize();
        settingsStore.Save(settings);
    }

    private void RefreshRecentFiles()
    {
        recentFilesListBox.BeginUpdate();
        recentFilesListBox.Items.Clear();
        foreach (var path in settings.RecentFiles)
        {
            recentFilesListBox.Items.Add(path);
        }
        recentFilesListBox.EndUpdate();
        recentHintLabel.Text = settings.RecentFiles.Count == 0
            ? "No recent conversions yet."
            : $"Showing {settings.RecentFiles.Count} recent file(s). Double-click any item to reuse it.";
    }

    private void PushRecentFile(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        settings.RecentFiles.RemoveAll(existing => string.Equals(existing, path, StringComparison.OrdinalIgnoreCase));
        settings.RecentFiles.Insert(0, path);
        settings.Normalize();
        RefreshRecentFiles();
    }

    private void UseSelectedRecentFile()
    {
        if (recentFilesListBox.SelectedItem is string path)
        {
            SetInputFile(path);
        }
    }

    private void RemoveSelectedRecentFile()
    {
        if (recentFilesListBox.SelectedItem is string path)
        {
            settings.RecentFiles.RemoveAll(existing => string.Equals(existing, path, StringComparison.OrdinalIgnoreCase));
            RefreshRecentFiles();
            SaveSettings();
        }
    }

    private void ClearRecentFiles()
    {
        settings.RecentFiles.Clear();
        RefreshRecentFiles();
        SaveSettings();
    }

    private void UpdateBackendStatus()
    {
        backendLabel.Text = backendRunner.IsAvailable
            ? $"Backend ready at:{Environment.NewLine}{backendRunner.BackendExecutablePath}"
            : $"Backend missing:{Environment.NewLine}{backendRunner.BackendExecutablePath}";
        shellStatusLabel.Text = backendRunner.IsAvailable
            ? "Backend ready"
            : "Backend missing";
        convertButton.Enabled = backendRunner.IsAvailable && !isBusy;
    }

    private void UpdateDetectedSyntax()
    {
        var requestedSyntax = syntaxComboBox.SelectedItem?.ToString() ?? "auto";
        detectedSyntaxLabel.Text = requestedSyntax == "auto"
            ? $"Detected: {DetectSyntaxFromPath(inputFileTextBox.Text.Trim())}"
            : $"Fixed: {requestedSyntax}";
    }

    private void UpdateDropHint()
    {
        var path = inputFileTextBox.Text.Trim();
        dropHintLabel.Text = string.IsNullOrWhiteSpace(path)
            ? "Drop a file here to start a new conversion session"
            : $"Current input: {path}";
    }

    private void UpdateSummary(ConversionResult? result)
    {
        if (result is null || !result.Succeeded)
        {
            summaryLabel.Text = "No completed conversion in this session.";
            lastOutputLabel.Text = "-";
            lastDurationLabel.Text = "-";
            lastFormatLabel.Text = "-";
            openOutputFileButton.Enabled = false;
            openOutputFolderButton.Enabled = false;
            return;
        }

        var outputPath = result.OutputFile ?? "(not located)";
        summaryLabel.Text = result.Message;
        lastOutputLabel.Text = outputPath;
        lastDurationLabel.Text = $"{result.Duration.TotalSeconds:F1}s";
        lastFormatLabel.Text = result.OutputFile is null ? "Unknown" : Path.GetExtension(result.OutputFile).TrimStart('.').ToUpperInvariant();
        openOutputFileButton.Enabled = result.OutputFile is not null && File.Exists(result.OutputFile);
        openOutputFolderButton.Enabled = result.OutputFile is not null && Directory.Exists(Path.GetDirectoryName(result.OutputFile));
    }

    private void BrowseInputFile()
    {
        using var dialog = new OpenFileDialog
        {
            Title = "Choose an input geometry file",
            Filter = "All files (*.*)|*.*"
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            SetInputFile(dialog.FileName);
        }
    }

    private void BrowseOutputDirectory()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose the output folder",
            UseDescriptionForTitle = true,
            SelectedPath = outputDirectoryTextBox.Text.Trim()
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            outputDirectoryTextBox.Text = dialog.SelectedPath;
        }
    }

    private void SetInputFile(string path)
    {
        inputFileTextBox.Text = path;
        if (string.IsNullOrWhiteSpace(outputDirectoryTextBox.Text))
        {
            outputDirectoryTextBox.Text = Path.GetDirectoryName(path) ?? string.Empty;
        }

        UpdateDetectedSyntax();
        UpdateDropHint();
    }

    private void OnInputPathChanged()
    {
        UpdateDetectedSyntax();
        UpdateDropHint();
    }

    private void OnAnyDragEnter(object? sender, DragEventArgs e)
    {
        if (e.Data?.GetDataPresent(DataFormats.FileDrop) == true)
        {
            e.Effect = DragDropEffects.Copy;
        }
    }

    private void OnAnyDragDrop(object? sender, DragEventArgs e)
    {
        if (e.Data?.GetData(DataFormats.FileDrop) is string[] files && files.Length > 0)
        {
            SetInputFile(files[0]);
        }
    }

    private async Task ConvertAsync()
    {
        if (isBusy)
        {
            return;
        }

        var inputFile = inputFileTextBox.Text.Trim();
        var outputDirectory = outputDirectoryTextBox.Text.Trim();
        var syntax = syntaxComboBox.SelectedItem?.ToString() ?? "auto";

        if (string.IsNullOrWhiteSpace(inputFile))
        {
            MessageBox.Show(this, "Choose an input file first.", AppMetadata.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        if (!File.Exists(inputFile))
        {
            MessageBox.Show(this, "The selected input file does not exist.", AppMetadata.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        if (string.IsNullOrWhiteSpace(outputDirectory))
        {
            outputDirectory = Path.GetDirectoryName(inputFile) ?? string.Empty;
            outputDirectoryTextBox.Text = outputDirectory;
        }

        if (string.IsNullOrWhiteSpace(outputDirectory))
        {
            MessageBox.Show(this, "Choose an output folder before starting the conversion.", AppMetadata.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        Directory.CreateDirectory(outputDirectory);

        SetBusy(true);
        SaveSettings();
        logTextBox.Clear();
        AppendLog($"Input file: {inputFile}");
        AppendLog($"Output folder: {outputDirectory}");
        AppendLog($"Requested syntax: {syntax}");
        AppendLog($"Effective syntax: {GetEffectiveSyntax(inputFile, syntax)}");
        AppendLog($"Backend path: {backendRunner.BackendExecutablePath}");

        var progress = new Progress<string>(AppendLog);
        var request = new ConversionRequest(inputFile, syntax, outputDirectory);
        var result = await backendRunner.ConvertAsync(request, progress, CancellationToken.None);

        lastOutputFile = result.OutputFile;
        UpdateSummary(result);
        AppendLog(result.Message);

        if (!result.Succeeded)
        {
            MessageBox.Show(this, result.Message, AppMetadata.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Error);
            SetBusy(false);
            return;
        }

        PushRecentFile(inputFile);
        if (openOutputCheckBox.Checked && !string.IsNullOrWhiteSpace(outputDirectory))
        {
            OpenPath(outputDirectory);
        }

        MessageBox.Show(this, "Conversion completed successfully.", AppMetadata.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Information);
        SetBusy(false);
    }

    private void SetBusy(bool busy)
    {
        isBusy = busy;
        browseInputButton.Enabled = !busy;
        browseOutputButton.Enabled = !busy;
        convertButton.Enabled = backendRunner.IsAvailable && !busy;
        syntaxComboBox.Enabled = !busy;
        inputFileTextBox.Enabled = !busy;
        outputDirectoryTextBox.Enabled = !busy;
        openOutputCheckBox.Enabled = !busy;
        progressBar.Style = busy ? ProgressBarStyle.Marquee : ProgressBarStyle.Blocks;
        statusLabel.Text = busy ? "Conversion in progress..." : "Ready";
        shellStatusLabel.Text = busy ? "Running backend conversion..." : (backendRunner.IsAvailable ? "Backend ready" : "Backend missing");
    }

    private void AppendLog(string message)
    {
        var line = $"[{DateTime.Now:HH:mm:ss}] {message}";
        logTextBox.AppendText(line + Environment.NewLine);
        logTextBox.SelectionStart = logTextBox.TextLength;
        logTextBox.ScrollToCaret();
    }

    private void CopyLogToClipboard()
    {
        if (string.IsNullOrWhiteSpace(logTextBox.Text))
        {
            return;
        }

        Clipboard.SetText(logTextBox.Text);
        shellStatusLabel.Text = "Log copied to clipboard";
    }

    private void OpenOutputFile()
    {
        if (!string.IsNullOrWhiteSpace(lastOutputFile) && File.Exists(lastOutputFile))
        {
            OpenPath(lastOutputFile);
        }
    }

    private void OpenOutputFolder()
    {
        if (!string.IsNullOrWhiteSpace(lastOutputFile))
        {
            var directory = Path.GetDirectoryName(lastOutputFile);
            if (!string.IsNullOrWhiteSpace(directory))
            {
                OpenPath(directory);
            }
        }
    }

    private void OpenLocalGuide()
    {
        var docPath = Path.Combine(AppContext.BaseDirectory, "docs", "WINDOWS_GUI.md");
        if (File.Exists(docPath))
        {
            OpenPath(docPath);
            return;
        }

        MessageBox.Show(this, "The local guide is not bundled with this build.", AppMetadata.ProductName, MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    private static void OpenPath(string path)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = path,
                UseShellExecute = true
            });
        }
        catch
        {
            // Ignore shell launch failures.
        }
    }

    private static string DetectSyntaxFromPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return "unknown";
        }

        return Path.GetExtension(path).Equals(".xml", StringComparison.OrdinalIgnoreCase)
            ? "mcx"
            : "mcnp";
    }

    private static string GetEffectiveSyntax(string path, string requestedSyntax)
    {
        return requestedSyntax == "auto" ? DetectSyntaxFromPath(path) : requestedSyntax;
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        SaveSettings();
        base.OnFormClosing(e);
    }
}
