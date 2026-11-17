# Atrium — Windows updates

This repository is the **signed-update feed for the original Windows Atrium application**, not the GitHub Pages website.

The client receives updates from `latest.json` and `atrium-update-<version>.zip`. Existing copies validate the `latest.json` RSA signature, the ZIP file length and SHA-256 before installing. The private RSA signing key belongs on the **owner's Windows PC only**. Do not upload it or change existing clients' verification rules.

## Asian Dramas update

The web Atrium app already includes Asian Dramas: https://jeysxn9321.github.io/Atrium/

The **Windows** app uses **http://localhost:18731/**, served by `mpv/home-server.ps1` and `mpv/home.html`. Changes to the web page do not automatically modify the locally installed Windows application.

The update currently advertised by this repository is still **2026.10.10.112233**. The new Asian Dramas release is **not yet published**: it must first be installed in the **original owner PC** and signed there. Do **not** edit `latest.json` by hand, reuse an old `sig`, or publish an unsigned ZIP; copies will reject it.

### Publishing a real automatic update

1. Start the original Windows Atrium on the creator PC and check `http://localhost:18731/`. Locate the real folder containing `mpv/home.html` and `mpv/home-server.ps1`. The separate `C:\Users\Jvson\workspace\Atrium` folder with `config.xml` and `Atrium.wgt` is a Samsung/Tizen app, **not** this Windows server.
2. Integrate Asian Dramas into those **actual local Windows server files** first. Use only a compatible, backed-up patch; do not overwrite a newer version with an old file. Check that the page shows one **Asian Dramas** tab with All / Korean / Japanese filters and the Stremio catalogs work.
3. Ensure `git` and `gh` are installed, `gh auth login` has been completed, and the connected account has push access to this repository.
4. Download and review [Publier-Asian-Dramas.ps1](Publier-Asian-Dramas.ps1); run it from PowerShell on the owner PC:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File ".\Publier-Asian-Dramas.ps1"
   ```

The script checks that Asian Dramas is installed locally; calls the *existing* Windows Atrium `/api/update/build` endpoint; verifies that the signed manifest matches the public key embedded in existing clients; checks package size, SHA-256 and archive layout; then commits the new ZIP and `latest.json` together to `main` through GitHub CLI.

If the feature is not on that PC, or if the signing key is different, the script **refuses to publish**. It never copies the private signing key, Stremio account secrets, or local user data.

### How to verify

After a successful signed publication, reload the repo's `latest.json` and check that its version is newer than `2026.10.10.112233`. On a compatible portable Windows copy, use **Update** in Atrium. Do not expect the separate GitHub Pages site or the Samsung TV widget to use this Windows updater.

Current state: **publishing helper added, signed Asian Dramas release not created yet**.
