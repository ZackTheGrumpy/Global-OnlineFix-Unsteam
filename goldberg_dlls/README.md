# Goldberg Emulator DLLs

This folder should contain the Goldberg emulator DLL files for the app to function with Goldberg support.

## Required Files (IMPORTANT!)

Place ALL of the following files in this folder:

### 32-bit DLLs (Required for 32-bit games):
- `steam_api.dll` - 32-bit Steam API emulator
- `steamclient.dll` - 32-bit Steam client emulator
- `GameOverlayRenderer.dll` - 32-bit overlay renderer (required for overlay)

### 64-bit DLLs (Required for 64-bit games):
- `steam_api64.dll` - 64-bit Steam API emulator
- `steamclient64.dll` - 64-bit Steam client emulator
- `GameOverlayRenderer64.dll` - 64-bit overlay renderer (required for overlay)

### Optional Tools (Recommended):
You can also place the `tools` folder here if you want access to:
- `generate_interfaces.exe` - Generates steam_interfaces.txt (app does this automatically)
- `lobby_connect.exe` - Tool for connecting to game lobbies

## Where to Get Them

Download the latest release from the official Goldberg Emulator fork:

**GitHub Repository:** https://github.com/Detanup01/gbe_fork

**Latest Release:** https://github.com/Detanup01/gbe_fork/releases/latest

### Step-by-Step:
1. Go to the releases page
2. Download the Windows build (look for a `.7z` or `.zip` file)
3. Extract the archive with 7-Zip or WinRAR
4. Inside you'll find folders like `x32` and `x64` or similar
5. Copy ALL the DLLs listed above to this `goldberg_dlls` folder

## File Structure

After adding the files, this folder should look like:

```
goldberg_dlls/
├── README.md (this file)
├── steam_api.dll
├── steam_api64.dll
├── steamclient.dll
├── steamclient64.dll
├── GameOverlayRenderer.dll
├── GameOverlayRenderer64.dll
└── tools/ (optional)
    ├── generate_interfaces.exe
    └── lobby_connect.exe
```

## Why Are All These Files Needed?

- **steam_api.dll / steam_api64.dll** - Main emulator that replaces the game's Steam API
- **steamclient.dll / steamclient64.dll** - Emulates Steam client functionality
- **GameOverlayRenderer.dll / GameOverlayRenderer64.dll** - **CRITICAL** for overlay to work (achievements, friend list, etc.)

Without all three types of DLLs, the emulator may not work correctly or the overlay won't appear.

## Important Note

⚠️ The app will NOT install Goldberg without these DLL files. Make sure to download them from the official repository to ensure you have the latest and most secure version.

⚠️ If you're missing any DLLs, the installation will fail with an error message telling you which file is missing.
