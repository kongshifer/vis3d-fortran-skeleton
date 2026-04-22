# Windows Desktop App and Installer

This repository includes two Windows projects:

- `windows/Vis3D.App`
  The installed desktop application. It provides a workbench-style UI with drag and drop, recent files, logs, and one-click conversion.
- `windows/Vis3D.Installer`
  The setup and maintenance application. It supports first-time installation, in-place update, removal, Start menu integration, and Windows Apps & Features registration.

## Project layout

- Desktop app project: `windows/Vis3D.App/Vis3D.App.csproj`
- Installer project: `windows/Vis3D.Installer/Vis3D.Installer.csproj`
- Packaging script: `scripts/publish_windows_bundle.ps1`

## Building the Windows bundle

Make sure the backend has already been compiled in `build-winlibs/`, including at least:

- `vis3d_export_demo.exe`
- `libgfortran-5.dll`
- `libgcc_s_seh-1.dll`
- `libquadmath-0.dll`
- `libstdc++-6.dll`
- `libwinpthread-1.dll`

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_windows_bundle.ps1
```

The script performs these steps:

1. Publishes the WinForms desktop application.
2. Collects the desktop app, backend runtime, and guide into `dist/windows/package/`.
3. Creates an embedded payload zip for the installer.
4. Publishes the installer and places the setup executable directly in `dist/windows/`.

The final setup executable is:

```text
dist/windows/Vis3DSetup.exe
```

## Installed layout

After installation, the main application is arranged like this:

```text
Vis3D.exe
Vis3DSetup.exe
backend/
  vis3d_export_demo.exe
  libgfortran-5.dll
  ...
docs/
  WINDOWS_GUI.md
```

The desktop app automatically runs:

```text
backend/vis3d_export_demo.exe
```

The installer also copies a local maintenance executable:

```text
Vis3DSetup.exe
```

That maintenance executable is used for:

- Windows Apps & Features uninstall integration
- Start menu "Uninstall Vis3D"
- In-place update and maintenance mode

## Installer features

The current installer experience includes:

- Welcome and finish pages
- Install folder selection for first-time installs
- Desktop and Start menu shortcut options
- Maintenance mode when Vis3D is already installed
- In-place update or reinstall
- Full removal flow
- Registration in Windows Apps & Features
- Quiet install and quiet uninstall command-line support

## Quiet mode

Silent install example:

```powershell
.\dist\windows\Vis3DSetup.exe --quiet --install-dir "C:\Program Files\Vis3D"
```

Silent uninstall example:

```powershell
.\dist\windows\Vis3DSetup.exe --quiet --uninstall --install-dir "C:\Program Files\Vis3D"
```

Optional switches:

- `--no-desktop-shortcut`
- `--no-start-menu-shortcut`
- `--launch`

## Backend command-line support

The backend now supports an explicit output directory so the GUI can control where converted files are written:

```powershell
.\build-winlibs\vis3d_export_demo.exe --syntax mcnp --output-dir .\out .\validation\mcnp_examples\angle\inp
```

The legacy positional form is still supported:

```powershell
.\build-winlibs\vis3d_export_demo.exe <input_file> [auto|mcx|mcnp] [output_dir]
```
