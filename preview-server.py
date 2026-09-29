"""Opens the pre-built UI for a new test user, in the tenant's current theme.

Run:   python3 preview-server.py
Open:  http://localhost:8787/live

Each visit creates a new test user, so the link never expires.
"""

import http.server
import pathlib
import subprocess

HERE = pathlib.Path(__file__).parent
PORT = 8787


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.rstrip("/") not in ("", "/live"):
            self.send_error(404)
            return
        result = subprocess.run([str(HERE / "preview-url.sh")], capture_output=True, text=True, cwd=HERE)
        url = result.stdout.strip()
        if result.returncode != 0 or not url.startswith("https://"):
            self.send_error(502, "Could not create a preview link: " + result.stderr.strip()[:200])
            return
        self.send_response(302)
        self.send_header("Location", url)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
