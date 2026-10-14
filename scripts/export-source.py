#!/usr/bin/env python3
"""Create a reviewable source export; this is not a secret scanner or publisher."""

import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat


ROOT_FILES = {
    "README.md", "Dockerfile", ".dockerignore", ".gitignore", ".gitattributes", "compose.yaml",
    "LICENSE", "LICENSE.md", "NOTICE", "docs/development.md",
    "docs/self-hosting.md", "docs/demo.md", "secretpod/pubspec.yaml",
    "secretpod/pubspec.lock",
}
PACKAGE_FILES = {
    "pubspec.yaml", "analysis_options.yaml", "dart_test.yaml",
    "dartdoc_options.yaml", "README.md", "CHANGELOG.md", ".gitignore", ".metadata",
}
TREE_ROOTS = [
    ".github/workflows", "scripts", "deploy", "tests",
    "secretpod/secretpod_server/lib", "secretpod/secretpod_server/bin",
    "secretpod/secretpod_server/test", "secretpod/secretpod_server/config",
    "secretpod/secretpod_server/web/pages", "secretpod/secretpod_server/web/static",
    "secretpod/secretpod_server/web/templates", "secretpod/secretpod_client/lib",
    "secretpod/secretpod_client/test", "secretpod/secretpod_client/doc",
    "secretpod/secretpod_flutter/lib", "secretpod/secretpod_flutter/test",
    "secretpod/secretpod_flutter/web", "secretpod/secretpod_flutter/assets",
    "secretpod/secretpod_flutter/android", "secretpod/secretpod_flutter/ios",
    "secretpod/secretpod_flutter/linux", "secretpod/secretpod_flutter/macos",
    "secretpod/secretpod_flutter/windows",
]
EXCLUDED_DIRECTORIES = {
    ".git", ".cache", ".dart_tool", "build", "data", "backup", "backups",
    ".aws", ".ssh", ".gnupg", ".codex", ".agents", ".claude", ".gemini",
    ".cursor", ".idea", ".gradle", ".symlinks", "ephemeral", "pods",
    "xcuserdata", "deriveddata", ".swiftpm", ".swift_pm", "__pycache__",
    ".pytest_cache", "node_modules", ".superpowers", ".serverpod", ".scloud",
}
EXCLUDED_FILES = {
    "agents.md", "local.properties", "key.properties", "generated.xcconfig",
    "flutter_export_environment.sh", ".flutter-plugins-dependencies",
    "credentials.json", ".mcp.json", "google-services.json",
    "googleservice-info.plist", "gradlew", "gradlew.bat",
}
EXCLUDED_PATTERNS = (
    ".env*", "*.env", "*.env.*", "passwords*", "*service_account*",
    "*service-account*", "*.pem", "*.key", "*.p12", "*.pfx", "*.jks",
    "*.keystore", "id_rsa*", "id_ed25519*", "*.sqlite*", "*.db", "*.db-*",
    "*.db.*", "vault.json*", "vault.lock", "*.bak", "*.backup", "*.dump",
    "*.log", "*.iml", "*.pyc", "*.xcuserstate",
)
SOURCE_SUFFIXES = {
    ".dart", ".yaml", ".yml", ".md", ".py", ".ps1", ".sh", ".mjs",
    ".js", ".json", ".html", ".css", ".svg", ".png", ".ico", ".ttf",
    ".otf", ".xml", ".plist", ".entitlements", ".swift", ".h", ".m",
    ".mm", ".c", ".cc", ".cpp", ".cmake", ".txt", ".rc", ".manifest",
    ".kts", ".kt", ".java", ".properties", ".xcconfig", ".pbxproj",
    ".xcworkspacedata", ".xcscheme", ".storyboard", ".xib",
}


def is_link(path):
    # Python before 3.12 has no Path.is_junction. Reject every Windows reparse
    # point rather than letting os.walk follow a junction outside the source.
    attributes = getattr(path.lstat(), "st_file_attributes", 0)
    return path.is_symlink() or bool(attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)


def safe_name(path):
    name = path.name.lower()
    return (
        not any(part.lower() in EXCLUDED_DIRECTORIES for part in path.parts)
        and name not in EXCLUDED_FILES
        and not any(fnmatch.fnmatchcase(name, pattern) for pattern in EXCLUDED_PATTERNS)
    )


def selected_files(source):
    """Enumerate only approved source trees, without following filesystem links."""
    selected = set()
    exact_files = set(ROOT_FILES)
    for package in ("secretpod_server", "secretpod_client", "secretpod_flutter"):
        exact_files.update(f"secretpod/{package}/{name}" for name in PACKAGE_FILES)
    for name in exact_files:
        path = source / name
        if path.is_file() and not any(is_link(parent) for parent in [path, *path.parents] if parent != source.parent):
            selected.add(path.relative_to(source))
    for name in TREE_ROOTS:
        tree = source / name
        if not tree.is_dir() or any(is_link(parent) for parent in [tree, *tree.parents] if parent != source.parent):
            continue
        for directory, folders, files in os.walk(tree, followlinks=False):
            directory = Path(directory)
            folders[:] = [folder for folder in folders if not folder.startswith('.') and safe_name(Path(folder)) and not is_link(directory / folder)]
            for filename in files:
                path = directory / filename
                relative = path.relative_to(source)
                if is_link(path) or not safe_name(relative):
                    continue
                if path.suffix.lower() in SOURCE_SUFFIXES or filename in {"Caddyfile", "manager.Dockerfile", "demo.Dockerfile", "demo.Caddyfile", "CMakeLists.txt", ".gitignore"}:
                    selected.add(relative)
    return sorted(selected, key=lambda path: path.as_posix())


def export(source, output):
    source, output = Path(source).resolve(), Path(output).resolve()
    if not source.is_dir():
        raise ValueError("Source directory does not exist.")
    if source == output or output in source.parents:
        raise ValueError("Destination must not be the source directory or its ancestor.")
    if output.exists():
        raise ValueError("Destination already exists; choose a new empty export path.")
    manifest_path = output.with_name(output.name + "-manifest.json")
    if manifest_path.exists():
        raise ValueError("Manifest already exists; choose a new export path.")
    paths = selected_files(source)
    output.mkdir(parents=True)
    entries = []
    for relative in paths:
        original, target = source / relative, output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)
        entries.append({
            "path": relative.as_posix(), "bytes": target.stat().st_size,
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        })
    manifest_path.write_text(json.dumps({"files": entries}, indent=2) + "\n", encoding="utf-8")
    return manifest_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True, help="New destination directory; never overwritten")
    args = parser.parse_args()
    try:
        manifest = export(args.source, args.output)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Export failed: {error}\n")
    count = len(json.loads(manifest.read_text(encoding="utf-8"))["files"])
    print(f"Exported {count} source files. Review and scan before publication.")
    print(f"Manifest: {manifest}")


if __name__ == "__main__":
    main()
