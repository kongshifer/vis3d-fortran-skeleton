using System.Diagnostics;

namespace Vis3D.Installer;

internal sealed class InstallerForm : Form
{
    private readonly EmbeddedPayloadInstaller installer = new();
    private readonly InstallerCliOptions launchOptions;
    private readonly bool launchedInMaintenanceMode;
    private readonly Panel[] pages = new Panel[4];
    private readonly TextBox installDirectoryTextBox = new();
    private readonly CheckBox desktopShortcutCheckBox = new();
    private readonly CheckBox startMenuShortcutCheckBox = new();
    private readonly CheckBox finishLaunchCheckBox = new();
    private readonly CheckBox finishOpenFolderCheckBox = new();
    private readonly PickerButton browseButton = new();
    private readonly Button backButton = new();
    private readonly Button nextButton = new();
    private readonly Button cancelButton = new();
    private readonly ProgressBar progressBar = new();
    private readonly RichTextBox logTextBox = new();
    private readonly Label pageTitleLabel = new();
    private readonly Label pageSubtitleLabel = new();
    private readonly Label payloadSummaryLabel = new();
    private readonly Label installScopeLabel = new();
    private readonly Label finishSummaryLabel = new();
    private readonly Label welcomeIntroLabel = new();
    private readonly Label welcomeHighlightsLabel = new();
    private readonly Label maintenanceSummaryLabel = new();
    private readonly Label installingIntroLabel = new();
    private readonly RadioButton updateRadioButton = new();
    private readonly RadioButton removeRadioButton = new();
    private readonly Panel maintenanceActionPanel = new();
    private InstalledProduct? installedProduct;
    private PayloadSummary payloadSummary;
    private SetupAction? lastCompletedAction;
    private bool isInstalling;
    private bool requiresClosingSetupForCleanup;
    private int currentStep;
    private string installedApplicationPath = string.Empty;

    public InstallerForm(InstallerCliOptions? launchOptions = null)
    {
        this.launchOptions = launchOptions ?? new InstallerCliOptions();
        installedProduct = installer.GetInstalledProduct();
        launchedInMaintenanceMode = installedProduct is not null;
        payloadSummary = installer.GetPayloadSummary();

        Text = InstallerMetadata.SetupName;
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(900, 680);
        Size = new Size(980, 730);
        Font = new Font("Segoe UI", 10F, FontStyle.Regular, GraphicsUnit.Point);
        BackColor = Color.FromArgb(245, 248, 251);

        InitializeUi();
        InitializeState();

        var initialStep = launchedInMaintenanceMode && this.launchOptions.UninstallRequested ? 1 : 0;
        ShowStep(initialStep);
    }

    private bool RemoveActionSelected =>
        launchedInMaintenanceMode && removeRadioButton.Checked;

    private bool RelocatingInstallSelected =>
        launchedInMaintenanceMode
        && installedProduct is not null
        && !RemoveActionSelected
        && !PathsEqual(installDirectoryTextBox.Text.Trim(), installedProduct.InstallDirectory);

    private void InitializeUi()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 138F));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        root.Controls.Add(BuildBanner(), 0, 0);
        root.Controls.Add(BuildPageHost(), 0, 1);
        root.Controls.Add(BuildFooter(), 0, 2);

        Controls.Add(root);
    }

    private void InitializeState()
    {
        installDirectoryTextBox.Text = !string.IsNullOrWhiteSpace(launchOptions.InstallDirectory)
            ? launchOptions.InstallDirectory
            : installedProduct?.InstallDirectory
            ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                InstallerMetadata.ProductName);

        desktopShortcutCheckBox.Checked = installedProduct?.HasDesktopShortcut ?? launchOptions.CreateDesktopShortcut;
        startMenuShortcutCheckBox.Checked = installedProduct?.HasStartMenuShortcut ?? launchOptions.CreateStartMenuShortcut;
        finishLaunchCheckBox.Checked = true;
        finishOpenFolderCheckBox.Checked = false;

        if (launchedInMaintenanceMode)
        {
            removeRadioButton.Checked = launchOptions.UninstallRequested;
            updateRadioButton.Checked = !removeRadioButton.Checked;
        }
        else
        {
            updateRadioButton.Checked = true;
        }

        UpdateModePresentation();
    }

    private Control BuildBanner()
    {
        var banner = new BrandBannerPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(30, 18, 30, 18)
        };

        pageTitleLabel.AutoSize = true;
        pageTitleLabel.Font = new Font("Segoe UI Semibold", 26F, FontStyle.Bold, GraphicsUnit.Point);
        pageTitleLabel.ForeColor = Color.White;

        pageSubtitleLabel.AutoSize = true;
        pageSubtitleLabel.MaximumSize = new Size(820, 0);
        pageSubtitleLabel.Font = new Font("Segoe UI", 11F, FontStyle.Regular, GraphicsUnit.Point);
        pageSubtitleLabel.ForeColor = Color.FromArgb(244, 249, 252);

        var versionLabel = new Label
        {
            AutoSize = true,
            Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(223, 239, 248),
            Text = $"Version {InstallerMetadata.VersionDisplay}"
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
        layout.Controls.Add(pageTitleLabel, 0, 0);
        layout.Controls.Add(pageSubtitleLabel, 0, 1);
        layout.Controls.Add(versionLabel, 0, 2);

        banner.Controls.Add(layout);
        return banner;
    }

    private Control BuildPageHost()
    {
        var host = new Panel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(18)
        };

        pages[0] = BuildWelcomePage();
        pages[1] = BuildOptionsPage();
        pages[2] = BuildInstallingPage();
        pages[3] = BuildFinishPage();

        foreach (var page in pages)
        {
            page.Visible = false;
            host.Controls.Add(page);
        }

        return host;
    }

    private Control BuildFooter()
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 4,
            Padding = new Padding(18, 10, 18, 16)
        };
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));

        backButton.Text = "< Back";
        backButton.AutoSize = true;
        backButton.Click += (_, _) => MoveStep(-1);
        StyleSecondaryButton(backButton);

        nextButton.AutoSize = true;
        nextButton.Click += async (_, _) => await AdvanceAsync();
        StylePrimaryButton(nextButton);

        cancelButton.Text = "Cancel";
        cancelButton.AutoSize = true;
        cancelButton.Click += (_, _) => Close();
        StyleSecondaryButton(cancelButton);

        panel.Controls.Add(new Label { AutoSize = true }, 0, 0);
        panel.Controls.Add(backButton, 1, 0);
        panel.Controls.Add(nextButton, 2, 0);
        panel.Controls.Add(cancelButton, 3, 0);
        return panel;
    }

    private Panel BuildWelcomePage()
    {
        var page = CreatePage();
        var card = CreateCard("Welcome", out var body, true);

        welcomeIntroLabel.AutoSize = true;
        welcomeIntroLabel.MaximumSize = new Size(780, 0);
        welcomeIntroLabel.ForeColor = Color.FromArgb(58, 72, 86);

        welcomeHighlightsLabel.AutoSize = true;
        welcomeHighlightsLabel.MaximumSize = new Size(780, 0);
        welcomeHighlightsLabel.ForeColor = Color.FromArgb(58, 72, 86);

        body.Controls.Add(welcomeIntroLabel, 0, 0);
        body.Controls.Add(welcomeHighlightsLabel, 0, 1);
        page.Controls.Add(card);
        return page;
    }

    private Panel BuildOptionsPage()
    {
        var page = CreatePage();
        var card = CreateCard("Installation options", out var body, false);

        maintenanceActionPanel.Dock = DockStyle.Top;
        maintenanceActionPanel.AutoSize = true;
        maintenanceActionPanel.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        maintenanceActionPanel.Margin = new Padding(0, 0, 0, 16);

        maintenanceSummaryLabel.AutoSize = true;
        maintenanceSummaryLabel.MaximumSize = new Size(760, 0);
        maintenanceSummaryLabel.ForeColor = Color.FromArgb(58, 72, 86);

        updateRadioButton.Text = "Update or reinstall";
        updateRadioButton.AutoSize = true;
        updateRadioButton.CheckedChanged += (_, _) => UpdateModePresentation();

        removeRadioButton.Text = "Remove Vis3D";
        removeRadioButton.AutoSize = true;
        removeRadioButton.CheckedChanged += (_, _) => UpdateModePresentation();

        var maintenanceLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 1,
            RowCount = 3
        };
        maintenanceLayout.Controls.Add(maintenanceSummaryLabel, 0, 0);
        maintenanceLayout.Controls.Add(updateRadioButton, 0, 1);
        maintenanceLayout.Controls.Add(removeRadioButton, 0, 2);
        maintenanceActionPanel.Controls.Add(maintenanceLayout);

        installDirectoryTextBox.Dock = DockStyle.Fill;

        browseButton.Text = "Select folder";
        browseButton.Dock = DockStyle.Fill;
        browseButton.Click += (_, _) => BrowseInstallDirectory();

        desktopShortcutCheckBox.Text = "Create a desktop shortcut";
        desktopShortcutCheckBox.AutoSize = true;

        startMenuShortcutCheckBox.Text = "Create Start menu shortcuts";
        startMenuShortcutCheckBox.AutoSize = true;

        payloadSummaryLabel.AutoSize = true;
        payloadSummaryLabel.MaximumSize = new Size(760, 0);
        payloadSummaryLabel.ForeColor = Color.FromArgb(82, 96, 110);

        installScopeLabel.AutoSize = true;
        installScopeLabel.MaximumSize = new Size(760, 0);
        installScopeLabel.ForeColor = Color.FromArgb(82, 96, 110);

        var grid = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 3,
            RowCount = 5
        };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 130F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 150F));
        grid.Controls.Add(BuildFieldLabel("Install folder"), 0, 0);
        grid.Controls.Add(installDirectoryTextBox, 1, 0);
        grid.Controls.Add(browseButton, 2, 0);
        grid.Controls.Add(BuildFieldLabel("Package"), 0, 1);
        grid.Controls.Add(payloadSummaryLabel, 1, 1);
        grid.Controls.Add(new Label { AutoSize = true }, 2, 1);
        grid.Controls.Add(new Label { AutoSize = true }, 0, 2);
        grid.Controls.Add(desktopShortcutCheckBox, 1, 2);
        grid.Controls.Add(new Label { AutoSize = true }, 0, 3);
        grid.Controls.Add(startMenuShortcutCheckBox, 1, 3);
        grid.Controls.Add(new Label { AutoSize = true }, 0, 4);
        grid.Controls.Add(installScopeLabel, 1, 4);

        body.Controls.Add(maintenanceActionPanel, 0, 0);
        body.Controls.Add(grid, 0, 1);
        page.Controls.Add(card);
        return page;
    }

    private Panel BuildInstallingPage()
    {
        var page = CreatePage();
        var card = CreateCard("Working", out var body, true);

        installingIntroLabel.AutoSize = true;
        installingIntroLabel.MaximumSize = new Size(780, 0);
        installingIntroLabel.ForeColor = Color.FromArgb(58, 72, 86);

        progressBar.Dock = DockStyle.Top;
        progressBar.Style = ProgressBarStyle.Marquee;
        progressBar.Margin = new Padding(0, 16, 0, 12);

        logTextBox.Dock = DockStyle.Fill;
        logTextBox.ReadOnly = true;
        logTextBox.BackColor = Color.FromArgb(249, 251, 252);
        logTextBox.Font = new Font("Consolas", 10F, FontStyle.Regular, GraphicsUnit.Point);

        body.Controls.Add(installingIntroLabel, 0, 0);
        body.Controls.Add(progressBar, 0, 1);
        body.Controls.Add(logTextBox, 0, 2);
        page.Controls.Add(card);
        return page;
    }

    private Panel BuildFinishPage()
    {
        var page = CreatePage();
        var card = CreateCard("Complete", out var body, false);

        finishSummaryLabel.AutoSize = true;
        finishSummaryLabel.MaximumSize = new Size(780, 0);
        finishSummaryLabel.ForeColor = Color.FromArgb(58, 72, 86);

        finishLaunchCheckBox.Text = "Launch Vis3D after closing the setup wizard";
        finishLaunchCheckBox.AutoSize = true;

        finishOpenFolderCheckBox.Text = "Open the installation folder";
        finishOpenFolderCheckBox.AutoSize = true;

        body.Controls.Add(finishSummaryLabel, 0, 0);
        body.Controls.Add(finishLaunchCheckBox, 0, 1);
        body.Controls.Add(finishOpenFolderCheckBox, 0, 2);
        page.Controls.Add(card);
        return page;
    }

    private Panel CreatePage() =>
        new()
        {
            Dock = DockStyle.Fill
        };

    private Panel CreateCard(string title, out TableLayoutPanel body, bool fillHeight)
    {
        var card = new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.White,
            BorderStyle = BorderStyle.FixedSingle,
            Padding = new Padding(18)
        };

        var titleLabel = new Label
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            Font = new Font("Segoe UI Semibold", 14F, FontStyle.Bold, GraphicsUnit.Point),
            ForeColor = Color.FromArgb(34, 51, 66),
            Text = title
        };

        body = new TableLayoutPanel
        {
            Dock = fillHeight ? DockStyle.Fill : DockStyle.Top,
            AutoSize = !fillHeight,
            ColumnCount = 1,
            RowCount = 8,
            Padding = new Padding(0, 16, 0, 0)
        };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        if (fillHeight)
        {
            body.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            body.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            body.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        }

        card.Controls.Add(body);
        card.Controls.Add(titleLabel);
        return card;
    }

    private static Label BuildFieldLabel(string text) =>
        new()
        {
            Text = text,
            AutoSize = true,
            ForeColor = Color.FromArgb(82, 96, 110),
            Padding = new Padding(0, 8, 0, 0)
        };

    private static void StylePrimaryButton(Button button)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = Color.FromArgb(19, 115, 139);
        button.ForeColor = Color.White;
        button.Padding = new Padding(18, 8, 18, 8);
    }

    private static void StyleSecondaryButton(Button button)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = Color.FromArgb(194, 206, 218);
        button.FlatAppearance.BorderSize = 1;
        button.BackColor = Color.White;
        button.ForeColor = Color.FromArgb(40, 56, 70);
        button.Padding = new Padding(14, 8, 14, 8);
    }

    private async Task AdvanceAsync()
    {
        switch (currentStep)
        {
            case 0:
                ShowStep(1);
                break;
            case 1:
                if (!ValidateOptions())
                {
                    return;
                }

                ShowStep(2);
                await RunSelectedActionAsync();
                break;
            case 3:
                FinishSetup();
                break;
        }
    }

    private void MoveStep(int delta)
    {
        if (isInstalling)
        {
            return;
        }

        ShowStep(Math.Clamp(currentStep + delta, 0, pages.Length - 1));
    }

    private void ShowStep(int step)
    {
        currentStep = step;
        for (var index = 0; index < pages.Length; index++)
        {
            pages[index].Visible = index == step;
        }

        UpdateModePresentation();
    }

    private void UpdateModePresentation()
    {
        maintenanceActionPanel.Visible = launchedInMaintenanceMode;
        var canEditInstallDirectory = !isInstalling && !RemoveActionSelected;
        installDirectoryTextBox.ReadOnly = !canEditInstallDirectory;
        installDirectoryTextBox.BackColor = canEditInstallDirectory
            ? Color.White
            : Color.FromArgb(247, 249, 251);

        browseButton.Enabled = canEditInstallDirectory;
        installDirectoryTextBox.Enabled = true;
        updateRadioButton.Enabled = !isInstalling;
        removeRadioButton.Enabled = !isInstalling;
        desktopShortcutCheckBox.Enabled = !isInstalling && !RemoveActionSelected;
        startMenuShortcutCheckBox.Enabled = !isInstalling && !RemoveActionSelected;

        payloadSummaryLabel.Text = payloadSummary.IsAvailable
            ? $"Payload contains {payloadSummary.FileCount} files and about {payloadSummary.HumanReadableSize}."
            : "Payload not embedded in this build.";

        if (launchedInMaintenanceMode && installedProduct is not null)
        {
            maintenanceSummaryLabel.Text =
                $"Detected Vis3D {installedProduct.VersionDisplay} in:{Environment.NewLine}{installedProduct.InstallDirectory}";
        }

        if (launchedInMaintenanceMode)
        {
            welcomeIntroLabel.Text =
                "Vis3D is already installed on this machine. The setup wizard can refresh the current installation or remove it entirely.";
            welcomeHighlightsLabel.Text =
                "Use Update to replace the application files in place and adjust shortcut choices. Use Remove to clean the installed files, Start menu entries, desktop shortcut, and the Windows Apps & Features entry.";
        }
        else
        {
            welcomeIntroLabel.Text =
                "This setup will install the Vis3D desktop workspace together with the Fortran backend and required runtime files.";
            welcomeHighlightsLabel.Text =
                "Included in this build:" + Environment.NewLine + Environment.NewLine +
                "- Desktop conversion app with drag and drop" + Environment.NewLine +
                "- Embedded backend runtime" + Environment.NewLine +
                "- Machine-wide Windows installer support" + Environment.NewLine +
                "- Start menu and desktop shortcuts";
        }

        installScopeLabel.Text = RemoveActionSelected
            ? "Removing Vis3D deletes the installed desktop app, backend files, shortcuts, and uninstall registration. User-generated output files outside the install folder are not touched."
            : launchedInMaintenanceMode
                ? RelocatingInstallSelected
                    ? "Vis3D will be reinstalled into the selected folder. The previous install directory will be cleaned up when possible after the new install succeeds."
                    : "You can keep the current install location or choose a different folder to relocate Vis3D."
                : "This installer requests administrator privileges and is designed for a machine-wide installation under Program Files.";

        installingIntroLabel.Text = RemoveActionSelected
            ? "Vis3D is removing program files, shortcuts, and uninstall metadata."
            : launchedInMaintenanceMode
                ? RelocatingInstallSelected
                    ? "Vis3D is installing to the selected folder and preparing to retire the previous location."
                    : "Vis3D is refreshing the installed application, backend runtime, and shortcuts."
                : "Vis3D is unpacking application files, runtime dependencies, and shortcuts.";

        UpdateStepChrome();
    }

    private void UpdateStepChrome()
    {
        switch (currentStep)
        {
            case 0:
                pageTitleLabel.Text = launchedInMaintenanceMode ? "Manage Vis3D" : "Welcome";
                pageSubtitleLabel.Text = launchedInMaintenanceMode
                    ? "A maintenance experience for updating or removing the existing installation."
                    : "A guided setup experience for the Vis3D desktop application.";
                backButton.Enabled = false;
                nextButton.Enabled = !isInstalling;
                nextButton.Text = "Next >";
                cancelButton.Enabled = !isInstalling;
                break;
            case 1:
                pageTitleLabel.Text = launchedInMaintenanceMode ? "Maintenance options" : "Choose install options";
                pageSubtitleLabel.Text = RemoveActionSelected
                    ? "Remove the current Vis3D installation from this machine."
                    : launchedInMaintenanceMode
                        ? RelocatingInstallSelected
                            ? "Install Vis3D into the selected folder and replace the previous location."
                            : "Refresh the current installation or choose a new install folder."
                        : "Pick a destination folder and decide which shortcuts the setup should create.";
                backButton.Enabled = !isInstalling;
                nextButton.Enabled = !isInstalling;
                nextButton.Text = RemoveActionSelected
                    ? "Remove"
                    : RelocatingInstallSelected
                        ? "Move"
                    : launchedInMaintenanceMode
                        ? "Update"
                        : "Install";
                cancelButton.Enabled = !isInstalling;
                break;
            case 2:
                pageTitleLabel.Text = RemoveActionSelected
                    ? "Removing"
                    : RelocatingInstallSelected
                        ? "Moving"
                    : launchedInMaintenanceMode
                        ? "Updating"
                        : "Installing";
                pageSubtitleLabel.Text = RemoveActionSelected
                    ? "The setup is deleting program files, shortcuts, and uninstall metadata."
                    : RelocatingInstallSelected
                        ? "The setup is installing Vis3D into the new folder and cleaning up the previous location when possible."
                    : "The setup is copying application files and preparing shortcuts.";
                backButton.Enabled = false;
                nextButton.Enabled = false;
                nextButton.Text = RemoveActionSelected
                    ? "Remove"
                    : RelocatingInstallSelected
                        ? "Move"
                        : "Install";
                cancelButton.Enabled = false;
                break;
            case 3:
                if (lastCompletedAction == SetupAction.Remove)
                {
                    pageTitleLabel.Text = "Removal complete";
                    pageSubtitleLabel.Text = requiresClosingSetupForCleanup
                        ? "Close the wizard to let Windows finish removing the last setup helper."
                        : "Vis3D has been removed from this machine.";
                    nextButton.Text = "Close";
                }
                else
                {
                    pageTitleLabel.Text = launchedInMaintenanceMode ? "Update complete" : "Setup complete";
                    pageSubtitleLabel.Text = "Vis3D is installed and ready to use.";
                    nextButton.Text = "Finish";
                }

                backButton.Enabled = false;
                nextButton.Enabled = !isInstalling;
                cancelButton.Enabled = false;
                break;
        }
    }

    private bool ValidateOptions()
    {
        if (string.IsNullOrWhiteSpace(installDirectoryTextBox.Text))
        {
            MessageBox.Show(
                this,
                "Choose an installation folder before continuing.",
                InstallerMetadata.SetupName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
            return false;
        }

        if (!RemoveActionSelected && !installer.HasPayload)
        {
            MessageBox.Show(
                this,
                "This build does not contain an embedded application payload. Rebuild the setup bundle first.",
                InstallerMetadata.SetupName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
            return false;
        }

        return true;
    }

    private void BrowseInstallDirectory()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose the installation folder",
            UseDescriptionForTitle = true,
            SelectedPath = installDirectoryTextBox.Text.Trim()
        };

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            installDirectoryTextBox.Text = dialog.SelectedPath;
        }
    }

    private async Task RunSelectedActionAsync()
    {
        if (RemoveActionSelected)
        {
            await RunUninstallAsync();
            return;
        }

        await RunInstallAsync();
    }

    private async Task RunInstallAsync()
    {
        if (isInstalling)
        {
            return;
        }

        var targetInstallDirectory = installDirectoryTextBox.Text.Trim();
        var previousInstallDirectory = installedProduct?.InstallDirectory;
        var relocatingInstall = launchedInMaintenanceMode
            && !string.IsNullOrWhiteSpace(previousInstallDirectory)
            && !PathsEqual(targetInstallDirectory, previousInstallDirectory);

        SetBusy(true);
        logTextBox.Clear();
        AppendLog($"Target directory: {targetInstallDirectory}");
        AppendLog(
            relocatingInstall
                ? $"Mode: move installation from {previousInstallDirectory}"
                : launchedInMaintenanceMode
                    ? "Mode: update existing installation"
                    : "Mode: first-time install");

        var progress = new Progress<string>(AppendLog);
        var result = await installer.InstallAsync(
            new InstallRequest(
                targetInstallDirectory,
                desktopShortcutCheckBox.Checked,
                startMenuShortcutCheckBox.Checked,
                previousInstallDirectory),
            progress,
            CancellationToken.None);

        SetBusy(false);
        if (!result.Succeeded)
        {
            AppendLog(result.Message);
            MessageBox.Show(this, result.Message, InstallerMetadata.SetupName, MessageBoxButtons.OK, MessageBoxIcon.Error);
            ShowStep(1);
            return;
        }

        installedProduct = installer.GetInstalledProduct();
        installedApplicationPath = result.ApplicationPath;
        requiresClosingSetupForCleanup = false;
        lastCompletedAction = SetupAction.InstallOrUpdate;
        finishLaunchCheckBox.Visible = true;
        finishOpenFolderCheckBox.Visible = true;
        finishSummaryLabel.Text =
            $"{(relocatingInstall ? "Vis3D was moved to:" : launchedInMaintenanceMode ? "Vis3D was updated in:" : "Vis3D was installed to:")}{Environment.NewLine}{result.InstallDirectory}{Environment.NewLine}{Environment.NewLine}{(relocatingInstall ? "The previous install directory is being cleaned up when possible." : "The application is now registered in Windows Apps & Features and includes a Start menu uninstall entry.")}";
        AppendLog(result.Message);
        ShowStep(3);
    }

    private async Task RunUninstallAsync()
    {
        if (isInstalling)
        {
            return;
        }

        SetBusy(true);
        logTextBox.Clear();
        AppendLog($"Removing from: {installDirectoryTextBox.Text.Trim()}");

        var progress = new Progress<string>(AppendLog);
        var result = await installer.UninstallAsync(
            new UninstallRequest(installDirectoryTextBox.Text.Trim()),
            progress,
            CancellationToken.None);

        SetBusy(false);
        if (!result.Succeeded)
        {
            AppendLog(result.Message);
            MessageBox.Show(this, result.Message, InstallerMetadata.SetupName, MessageBoxButtons.OK, MessageBoxIcon.Error);
            ShowStep(1);
            return;
        }

        installedApplicationPath = string.Empty;
        installedProduct = null;
        requiresClosingSetupForCleanup = result.RequiresClosingSetupForCleanup;
        lastCompletedAction = SetupAction.Remove;
        finishLaunchCheckBox.Visible = false;
        finishOpenFolderCheckBox.Visible = false;
        finishSummaryLabel.Text = result.Message;
        AppendLog(result.Message);
        ShowStep(3);
    }

    private void SetBusy(bool busy)
    {
        isInstalling = busy;
        progressBar.Style = busy ? ProgressBarStyle.Marquee : ProgressBarStyle.Blocks;
        UpdateModePresentation();
    }

    private void AppendLog(string message)
    {
        logTextBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}");
        logTextBox.SelectionStart = logTextBox.TextLength;
        logTextBox.ScrollToCaret();
    }

    private void FinishSetup()
    {
        if (lastCompletedAction == SetupAction.Remove)
        {
            Close();
            return;
        }

        if (finishOpenFolderCheckBox.Checked && File.Exists(installedApplicationPath))
        {
            var installDirectory = Path.GetDirectoryName(installedApplicationPath);
            if (!string.IsNullOrWhiteSpace(installDirectory))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = installDirectory,
                    UseShellExecute = true
                });
            }
        }

        if (finishLaunchCheckBox.Checked && File.Exists(installedApplicationPath))
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = installedApplicationPath,
                UseShellExecute = true
            });
        }

        Close();
    }

    private static bool PathsEqual(string leftPath, string rightPath)
    {
        if (string.IsNullOrWhiteSpace(leftPath) || string.IsNullOrWhiteSpace(rightPath))
        {
            return false;
        }

        return string.Equals(
            Path.GetFullPath(leftPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            Path.GetFullPath(rightPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            StringComparison.OrdinalIgnoreCase);
    }
}

internal enum SetupAction
{
    InstallOrUpdate,
    Remove
}
