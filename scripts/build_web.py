"""
FocusEcho Web Application Build & Static Analysis Utility
Builds static bundle to dist/ for GitHub Pages deployment.
Injects base-href, copies stylesheets/scripts, and runs static analysis checks.
"""

import os
import sys
import shutil
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEB_SRC = PROJECT_ROOT / "web"
DIST_DIR = PROJECT_ROOT / "dist"

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

def build(base_path: str = "/FocusEcho/") -> bool:
    """Build the FocusEcho web app into dist/."""
    print("=" * 60)
    print("[*] FocusEcho Web Application Build Engine")
    print(f"Source Directory: {WEB_SRC}")
    print(f"Target Directory: {DIST_DIR}")
    print(f"Target Base Path: {base_path}")
    print("=" * 60)

    if not WEB_SRC.exists():
        print(f"ERROR: Source directory {WEB_SRC} does not exist.")
        return False

    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)
    DIST_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Copy assets, css, js
    for sub in ["css", "js", "assets"]:
        src_sub = WEB_SRC / sub
        dst_sub = DIST_DIR / sub
        if src_sub.exists():
            shutil.copytree(src_sub, dst_sub)
            print(f"[OK] Copied {sub}/ -> dist/{sub}/")

    # 2. Process index.html with base href
    index_src = WEB_SRC / "index.html"
    index_dst = DIST_DIR / "index.html"
    if not index_src.exists():
        print(f"ERROR: Missing {index_src}")
        return False

    html_content = index_src.read_text(encoding="utf-8")
    
    # Ensure proper base tag
    base_tag = f'<base href="{base_path}">'
    if "<base " in html_content:
        html_content = re.sub(r'<base\s+href="[^"]*"\s*/?>', base_tag, html_content)
    else:
        html_content = html_content.replace("<head>", f'<head>\n  {base_tag}')

    index_dst.write_text(html_content, encoding="utf-8")
    print(f"[OK] Injected base href ({base_path}) into dist/index.html")

    # 3. Static Analysis Checks
    print("\n--- Running Static Analysis ---")
    errors = 0

    # Verify CSS links
    css_files = list((DIST_DIR / "css").glob("*.css"))
    if not css_files:
        print("ERROR: No CSS files found in dist/css/")
        errors += 1
    else:
        print(f"[OK] Validated {len(css_files)} CSS files.")

    # Verify JS files
    js_files = list((DIST_DIR / "js").glob("*.js"))
    if not js_files:
        print("ERROR: No JS files found in dist/js/")
        errors += 1
    else:
        print(f"[OK] Validated {len(js_files)} JS files.")

    # Check for empty files
    for f in DIST_DIR.rglob("*"):
        if f.is_file() and f.stat().st_size == 0:
            print(f"WARNING: Empty file detected at {f.relative_to(DIST_DIR)}")

    print(f"\nBuild complete with {errors} errors.")
    return errors == 0

if __name__ == "__main__":
    base = os.environ.get("BASE_HREF", "./")
    success = build(base)
    sys.exit(0 if success else 1)
