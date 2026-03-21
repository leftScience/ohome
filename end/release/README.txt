ohome server portable package

1. Double-click start.bat (Windows) or start.command (macOS), or run the binary directly.
2. Default port: 18090
3. Swagger URL: http://127.0.0.1:18090/swagger/index.html
4. SQLite database: ./data/ohome.db
5. Logs: ./log/
6. Optional override: set OHOME_BASE_DIR to point at another package directory.

macOS note:
- This package is not code signed yet.
- If macOS blocks it on first launch, right-click start.command and choose Open.
- If the package was quarantined after download, run:
  xattr -dr com.apple.quarantine .
