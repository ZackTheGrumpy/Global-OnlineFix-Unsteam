import os
import sys
import time
import json
import shutil
import winreg
import ctypes
import zipfile
import subprocess
import urllib.request
import re
from pathlib import Path

# Constants
BASE_URL = "https://raw.githubusercontent.com/ZackTheGrumpy/Global-OnlineFix-Unsteam/main/Unsteam/"

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def log(message, level="INFO"):
    print(f"[{level}] {message}")

def find_steam_path():
    """Finds the Steam installation path via Registry or common paths."""
    # Method 1: Registry
    registry_keys = [
        r"SOFTWARE\WOW6432Node\Valve\Steam",
        r"SOFTWARE\Valve\Steam"
    ]
    
    for key_path in registry_keys:
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                path_val, _ = winreg.QueryValueEx(key, "InstallPath")
                if os.path.isdir(path_val) and os.path.exists(os.path.join(path_val, "steam.exe")):
                    log(f"Found Steam via Registry: {path_val}")
                    return path_val
        except OSError:
            continue
            
    # Method 2: Common Paths
    common_paths = [
        r"C:\Program Files (x86)\Steam",
        r"C:\Program Files\Steam",
        r"D:\Steam",
        r"E:\Steam"
    ]
    
    for path_val in common_paths:
        if os.path.isdir(path_val) and os.path.exists(os.path.join(path_val, "steam.exe")):
             log(f"Found Steam via Common Paths: {path_val}")
             return path_val
             
    log("Steam installation not found!", "ERROR")
    return None

def get_steam_library_paths(steam_path):
    """Parses libraryfolders.vdf to find all library paths."""
    library_vdf = os.path.join(steam_path, "steamapps", "libraryfolders.vdf")
    libraries = [steam_path]
    
    if not os.path.exists(library_vdf):
        return libraries
        
    try:
        with open(library_vdf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Regex to find "path" "..."
        matches = re.findall(r'"path"\s+"(.+?)"', content, re.IGNORECASE)
        for match in matches:
            path_val = match.replace("\\\\", "\\")
            if os.path.isdir(path_val):
                libraries.append(path_val)
                
    except Exception as e:
        log(f"Error parsing libraryfolders.vdf: {e}", "ERROR")
        
    return list(set(libraries))

def find_game_by_appid(libraries, app_id):
    """Finds the game installation directory by AppID."""
    for lib in libraries:
        steamapps = os.path.join(lib, "steamapps")
        manifest = os.path.join(steamapps, f"appmanifest_{app_id}.acf")
        
        if os.path.exists(manifest):
            try:
                with open(manifest, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                match = re.search(r'"installdir"\s+"(.+?)"', content, re.IGNORECASE)
                if match:
                    install_dir = match.group(1)
                    game_path = os.path.join(steamapps, "common", install_dir)
                    if os.path.isdir(game_path):
                        return game_path
            except Exception as e:
                log(f"Error reading manifest: {e}", "ERROR")
                
    return None

def find_game_exe(game_folder):
    """Recursively finds the main game executable."""
    for root, dirs, files in os.walk(game_folder):
        exe_files = [f for f in files if f.lower().endswith('.exe')]
        
        # Filter out common utility exes
        filtered_exes = []
        for f in exe_files:
            lower_f = f.lower()
            if not any(x in lower_f for x in ['uninstall', 'crash', 'report', 'setup', 'config', 'launcher', 'unitycrashhandler']):
                filtered_exes.append(f)
                
        if filtered_exes:
            return os.path.join(root, filtered_exes[0])
            
    return None

def download_file(url, dest_path):
    """Downloads a single file."""
    log(f"Downloading {url}...")
    try:
        urllib.request.urlretrieve(url, dest_path)
        return True
    except Exception as e:
        log(f"Download failed: {e}", "ERROR")
        return False

def modify_unsteam_ini(ini_path, exe_path, dll_path, app_id):
    """Configures unsteam.ini."""
    try:
        with open(ini_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Replace values using regex to preserve comments/structure
        content = re.sub(r'^exe_file=.*$', f'exe_file={exe_path}', content, flags=re.MULTILINE)
        content = re.sub(r'^dll_file=.*$', f'dll_file={dll_path}', content, flags=re.MULTILINE)
        content = re.sub(r'^real_app_id=.*$', f'real_app_id={app_id}', content, flags=re.MULTILINE)
        
        with open(ini_path, 'w', encoding='utf-8') as f:
            f.write(content)
            
        log(f"Configured {ini_path}")
        return True
    except Exception as e:
        log(f"Error modifying unsteam.ini: {e}", "ERROR")
        return False

def main():
    if not is_admin():
        log("Please run this script as Administrator!", "ERROR")
        # Attempt to elevate
        try:
            ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)
        except Exception as e:
            log(f"Failed to elevate: {e}", "ERROR")
        return

    print("=== Unsteam Python Installer ===")
    
    # 1. Steam Detection
    steam_path = find_steam_path()
    if not steam_path:
        input("Steam not found. Press Enter to exit.")
        return

    # 2. AppID Input
    while True:
        app_id = input("\nEnter Steam AppID: ").strip()
        if app_id.isdigit():
            break
        print("Invalid AppID. Please enter a number.")

    # 3. Game Detection
    log("Scanning libraries...")
    libraries = get_steam_library_paths(steam_path)
    game_path = find_game_by_appid(libraries, app_id)
    
    if not game_path:
        log(f"Game with AppID {app_id} not found installed.", "ERROR")
        input("Press Enter to exit.")
        return
        
    log(f"Found game at: {game_path}")
    
    # 4. EXE Detection
    game_exe_full = find_game_exe(game_path)
    if not game_exe_full:
        log("Could not find game executable.", "ERROR")
        input("Press Enter to exit.")
        return
        
    game_exe_dir = os.path.dirname(game_exe_full)
    game_exe_name = os.path.basename(game_exe_full)
    log(f"Game Executable: {game_exe_name}")
    
    # 5. Install Fix
    FILES_MAP = {
        "unsteam.dll": "unsteam.dll", 
        "unsteam.ini": "unsteam.ini", 
        "winmm.dll": "winmm.dll"
    }
    
    success_count = 0
    for source_name, dest_name in FILES_MAP.items():
        url = BASE_URL + source_name
        dest = os.path.join(game_exe_dir, dest_name)
        if download_file(url, dest):
            success_count += 1
            
    if success_count == len(FILES_MAP):
        # 6. Configure INI
        exe_in_subfolder = os.path.normpath(game_exe_dir) != os.path.normpath(game_path)
        
        if exe_in_subfolder:
            # Setup logic for subfolder
            extracted_ini = os.path.join(game_exe_dir, "unsteam.ini")
            root_ini = os.path.join(game_path, "unsteam.ini")
            
            if os.path.exists(extracted_ini):
                shutil.copy2(extracted_ini, root_ini)
                
                full_dll_path = os.path.join(game_exe_dir, "unsteam.dll")
                
                modify_unsteam_ini(extracted_ini, game_exe_full, full_dll_path, app_id)
                modify_unsteam_ini(root_ini, game_exe_full, full_dll_path, app_id)
                log("Configured INI files (Subfolder mode)")
        else:
            # Root mode
            ini_path = os.path.join(game_exe_dir, "unsteam.ini")
            if os.path.exists(ini_path):
                modify_unsteam_ini(ini_path, game_exe_name, "unsteam.dll", app_id)
                log("Configured INI file (Root mode)")

        print("\n=== SUCCESS! ===")
        print("The fix has been applied.")
        print("Launch your game from Steam to play!")
            
    else:
        log("Failed to download all fix files.", "ERROR")

    input("\nPress Enter to exit.")

if __name__ == "__main__":
    main()
