ohome server portable package

1. Double-click start.bat (Windows) or start.command (macOS).
2. The package now uses:
   - conf/config.yaml
   - data/
   - log/
   - versions/<version>/
   - current.txt
3. The updater binary runs locally and is responsible for switching server versions.
4. Default port: 18090
5. Swagger URL: http://127.0.0.1:18090/swagger/index.html
6. Optional override: set OHOME_BASE_DIR to point at another package root.

macOS note:
- This package is not code signed yet.
- If macOS blocks it on first launch, right-click start.command and choose Open.
- If the package was quarantined after download, run:
  xattr -dr com.apple.quarantine .
