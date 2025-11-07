# Goldberg Emulator DLLs

This folder should contain the Goldberg emulator DLL files for the app to function with Goldberg support.

## Required Files

Place the following files in this folder:

- `steam_api.dll` - 32-bit version of Goldberg emulator
- `steam_api64.dll` - 64-bit version of Goldberg emulator

## Where to Get Them

Download the latest release from the official Goldberg Emulator fork:

**GitHub Repository:** https://github.com/Detanup01/gbe_fork

**Latest Release:** https://github.com/Detanup01/gbe_fork/releases/latest

1. Go to the releases page
2. Download the Windows build (usually a `.7z` or `.zip` file)
3. Extract the archive
4. Copy `steam_api.dll` and `steam_api64.dll` to this folder

## File Structure

After adding the files, this folder should look like:

```
goldberg_dlls/
├── README.md (this file)
├── steam_api.dll
└── steam_api64.dll
```

## Important Note

The app will not be able to install Goldberg emulator without these DLL files. Make sure to download them from the official repository to ensure you have the latest and most secure version.
