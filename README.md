# Stats-UI

**Set your gaming status everywhere at once.** Stats-UI sets your Steam, Discord, Xbox and other launcher statuses for you from one tray icon, so you never have to open each app.

🌐 Website: https://0mrcrazy0.github.io/status/

## What it does
- Sets your status on **Steam, Discord, the Xbox app**, and launchers you add (Epic, Ubisoft Connect, Rockstar, EA app, Battle.net, GOG or any other program)
- **Tray menu**: set each program separately, or use **Set all** in one click
- Works with **any number of screens**, any size and any scaling, detected automatically
- Starts with Windows (optional) and stays out of your way

## Install (Windows 10/11)
1. Click the green **Code** button above, then **Download ZIP**.
2. Right-click the ZIP and choose **Extract All**.
3. Open the extracted folder and double-click **`build.bat`**. It builds the installer for you. The first time can take a few minutes.
4. When it finishes, the `release` folder opens. Double-click **`Stats-UI-Setup-x.x.x.exe`** to install.
5. If Windows SmartScreen pops up, click **More info**, then **Run anyway**. The app isn't code-signed yet, so Windows warns about it.

Stats-UI is now in your Start Menu.

## First-time setup
- **Steam** works straight away. Nothing to set up.
- **Discord and the Xbox app**: open Stats-UI, pick a status, and click **Teach it now**. Click through the status menu in that app the way you normally would (for example profile picture, then status, then Online), then press **Done**. Stats-UI remembers those clicks and repeats them for you.
- **Xbox**: use the **Xbox app** from the Microsoft Store, not Game Bar. Windows blocks other apps from clicking on Game Bar.

## Updating
Download the new version, run `build.bat` again and install over the top. Your settings and taught clicks are kept.

## Troubleshooting
- **A status didn't change?** Teach that status again. Window layouts change after app updates.
- **Still stuck?** Go to Settings, then **Copy diagnostics**. A zip is saved to your Desktop. Open an issue on this repo and attach it.

## Privacy
Stats-UI never asks for your passwords or account tokens. Everything stays on your PC.

## License
See [LICENSE](LICENSE).
