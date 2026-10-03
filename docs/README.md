# OTA Metadata

This folder is intended to be published with GitHub Pages.

Current endpoint after enabling Pages from the `docs` folder:

```text
https://unicastbg.github.io/mi439-ota/Mi439-23.2.json
```

The file starts as an empty update list. Generate real metadata after uploading a
signed ROM zip to GitHub Releases:

```powershell
.\tools\New-Mi439OtaJson.ps1 `
    -ZipPath "C:\path\to\lineage-23.2-YYYYMMDD-UNOFFICIAL-Mi439-signed.zip" `
    -DownloadUrl "https://github.com/unicastbg/mi439-builds/releases/download/YYYYMMDD/lineage-23.2-YYYYMMDD-UNOFFICIAL-Mi439-signed.zip" `
    -OutputPath ".\docs\Mi439-23.2.json"
```
