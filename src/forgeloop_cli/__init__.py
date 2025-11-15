#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "typer",
#     "rich",
#     "platformdirs",
#     "readchar",
#     "httpx",
# ]
# ///
"""
ForgeLoop CLI - Setup tool for ForgeLoop projects

Usage:
    uvx forgeloop-cli.py init <project-name>
    uvx forgeloop-cli.py init .
    uvx forgeloop-cli.py init --here

Or install globally:
    uv tool install --from forgeloop-cli.py forgeloop-cli
    forgeloop init <project-name>
    forgeloop init .
    forgeloop init --here
"""

import os
import subprocess
import sys
import zipfile
import tempfile
import shutil
import shlex
import json
from pathlib import Path
from typing import Optional, Tuple

import typer
import httpx
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.text import Text
from rich.live import Live
from rich.align import Align
from rich.table import Table
from rich.tree import Tree

# For cross-platform keyboard input
import readchar
import ssl
import truststore
from datetime import datetime, timezone

ssl_context = truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
client = httpx.Client(verify=ssl_context)

# Agent configuration with name, folder, install URL, and CLI tool requirement
AGENT_CONFIG = {
    "copilot": {"name": "GitHub Copilot", "folder": ".github/", "install_url": None, "requires_cli": False},
    "claude": {"name": "Claude Code", "folder": ".claude/", "install_url": "https://docs.anthropic.com/en/docs/claude-code/setup", "requires_cli": True},
    "gemini": {"name": "Gemini CLI", "folder": ".gemini/", "install_url": "https://github.com/google-gemini/gemini-cli", "requires_cli": True},
    "cursor-agent": {"name": "Cursor", "folder": ".cursor/", "install_url": None, "requires_cli": False},
    "qwen": {"name": "Qwen Code", "folder": ".qwen/", "install_url": "https://github.com/QwenLM/qwen-code", "requires_cli": True},
    "opencode": {"name": "opencode", "folder": ".opencode/", "install_url": "https://opencode.ai", "requires_cli": True},
    "codex": {"name": "Codex CLI", "folder": ".codex/", "install_url": "https://github.com/openai/codex", "requires_cli": True},
    "windsurf": {"name": "Windsurf", "folder": ".windsurf/", "install_url": None, "requires_cli": False},
    "kilocode": {"name": "Kilo Code", "folder": ".kilocode/", "install_url": None, "requires_cli": False},
    "auggie": {"name": "Auggie CLI", "folder": ".augment/", "install_url": "https://docs.augmentcode.com/cli/setup-auggie/install-auggie-cli", "requires_cli": True},
    "codebuddy": {"name": "CodeBuddy", "folder": ".codebuddy/", "install_url": "https://www.codebuddy.ai/cli", "requires_cli": True},
    "roo": {"name": "Roo Code", "folder": ".roo/", "install_url": None, "requires_cli": False},
    "q": {"name": "Amazon Q Developer CLI", "folder": ".amazonq/", "install_url": "https://aws.amazon.com/developer/learning/q-developer-cli/", "requires_cli": True},
    "amp": {"name": "Amp", "folder": ".agents/", "install_url": "https://ampcode.com/manual#install", "requires_cli": True},
    "shai": {"name": "SHAI", "folder": ".shai/", "install_url": "https://github.com/ovh/shai", "requires_cli": True},
}

SCRIPT_TYPE_CHOICES = {"sh": "POSIX Shell (bash/zsh)", "ps": "PowerShell"}

CLAUDE_LOCAL_PATH = Path.home() / ".claude" / "local" / "claude"

BANNER = """
███████╗ ██████╗ ██████╗  ██████╗ ███████╗██╗      ██████╗   ██████╗
██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝██║     ██╔═══██╗ ██╔════╝
█████╗  ██║   ██║██████╔╝██║  ███╗█████╗  ██║     ██║   ██║ ██║  ███╗
██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  ██║     ██║   ██║ ██║   ██║
███████╗╚██████╔╝██║  ██║╚██████╔╝███████╗███████╗╚██████╔╝ ╚██████╔╝
╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝   ╚═════╝
"""

TAGLINE = "ForgeLoop – Spec-Driven Development Toolkit"

class StepTracker:
    """Track and render hierarchical steps without emojis, similar to Claude Code tree output.
    Supports live auto-refresh via an attached refresh callback.
    """
    def __init__(self, title: str):
        self.title = title
        self.steps = []
        self.status_order = {"pending": 0, "running": 1, "done": 2, "error": 3, "skipped": 4}
        self._refresh_cb = None

    def attach_refresh(self, cb):
        self._refresh_cb = cb

    def add(self, key: str, label: str):
        if key not in [s["key"] for s in self.steps]:
            self.steps.append({"key": key, "label": label, "status": "pending", "detail": ""})
            self._maybe_refresh()

    def start(self, key: str, detail: str = ""):
        self._update(key, status="running", detail=detail)

    def complete(self, key: str, detail: str = ""):
        self._update(key, status="done", detail=detail)

    def error(self, key: str, detail: str = ""):
        self._update(key, status="error", detail=detail)

    def skip(self, key: str, detail: str = ""):
        self._update(key, status="skipped", detail=detail)

    def _update(self, key: str, status: str, detail: str):
        for s in self.steps:
            if s["key"] == key:
                s["status"] = status
                if detail:
                    s["detail"] = detail
                self._maybe_refresh()
                return
        self.steps.append({"key": key, "label": key, "status": status, "detail": detail})
        self._maybe_refresh()

    def _maybe_refresh(self):
        if self._refresh_cb:
            try:
                self._refresh_cb()
            except Exception:
                pass

    def render(self):
        tree = Tree(f"[cyan]{self.title}[/cyan]", guide_style="grey50")
        for step in self.steps:
            label = step["label"]
            detail_text = step["detail"].strip() if step["detail"] else ""
            status = step["status"]
            if status == "done":
                symbol = "[green]●[/green]"
            elif status == "pending":
                symbol = "[green dim]○[/green dim]"
            elif status == "running":
                symbol = "[cyan]○[/cyan]"
            elif status == "error":
                symbol = "[red]●[/red]"
            elif status == "skipped":
                symbol = "[yellow]○[/yellow]"
            else:
                symbol = " "
            if status == "pending":
                line = f"{symbol} [bright_black]{label} ({detail_text})[/bright_black]" if detail_text else f"{symbol} [bright_black]{label}[/bright_black]"
            else:
                line = f"{symbol} [white]{label}[/white] [bright_black]({detail_text})[/bright_black]" if detail_text else f"{symbol} [white]{label}[/white]"
            tree.add(line)
        return tree

def _github_token(cli_token: str | None = None) -> str | None:
    return ((cli_token or os.getenv("GH_TOKEN") or os.getenv("GITHUB_TOKEN") or "").strip()) or None

def _github_auth_headers(cli_token: str | None = None) -> dict:
    token = _github_token(cli_token)
    return {"Authorization": f"Bearer {token}"} if token else {}

def _parse_rate_limit_headers(headers: httpx.Headers) -> dict:
    info = {}
    if "X-RateLimit-Limit" in headers:
        info["limit"] = headers.get("X-RateLimit-Limit")
    if "X-RateLimit-Remaining" in headers:
        info["remaining"] = headers.get("X-RateLimit-Remaining")
    if "X-RateLimit-Reset" in headers:
        reset_epoch = int(headers.get("X-RateLimit-Reset", "0"))
        if reset_epoch:
            reset_time = datetime.fromtimestamp(reset_epoch, tz=timezone.utc)
            info["reset_epoch"] = reset_epoch
            info["reset_time"] = reset_time
            info["reset_local"] = reset_time.astimezone()
    if "Retry-After" in headers:
        retry_after = headers.get("Retry-After")
        try:
            info["retry_after_seconds"] = int(retry_after)
        except ValueError:
            info["retry_after"] = retry_after
    return info

def _format_rate_limit_error(status_code: int, headers: httpx.Headers, url: str) -> str:
    rate_info = _parse_rate_limit_headers(headers)
    lines = [f"GitHub API returned status {status_code} for {url}"]
    lines.append("")
    if rate_info:
        lines.append("[bold]Rate Limit Information:[/bold]")
        if "limit" in rate_info:
            lines.append(f"  • Rate Limit: {rate_info['limit']} requests/hour")
        if "remaining" in rate_info:
            lines.append(f"  • Remaining: {rate_info['remaining']}")
        if "reset_local" in rate_info:
            reset_str = rate_info["reset_local"].strftime("%Y-%m-%d %H:%M:%S %Z")
            lines.append(f"  • Resets at: {reset_str}")
        if "retry_after_seconds" in rate_info:
            lines.append(f"  • Retry after: {rate_info['retry_after_seconds']} seconds")
        lines.append("")
    lines.append("[bold]Troubleshooting Tips:[/bold]")
    lines.append("  • If you're on a shared CI or corporate environment, you may be rate-limited.")
    lines.append("  • Consider using a GitHub token via --github-token or the GH_TOKEN/GITHUB_TOKEN environment variable.")
    lines.append("  • Authenticated requests have a limit of 5,000/hour vs 60/hour for unauthenticated.")
    return "\n".join(lines)

def main():
    console = Console()
    console.print(BANNER)
    console.print(TAGLINE)
    console.print("Run 'forgeloop --help' or 'specify --help' for usage information")

if __name__ == "__main__":
    main()

