#!/usr/bin/env python3
"""ghost-check: AI provenance and attribution scanner.

Scans repository files and commit messages for explicit AI attribution,
suspicious AI-origin references, and emoji usage in comments. Designed
for standalone use and future pre-commit / commit-msg hook integration.

Supported comment syntaxes for comment-scoped rules:
    Single-line:  #  //  --  ;
    Multi-line:   /* */   <!-- -->

File types are identified by extension and filename. Binary and non-text
files are skipped automatically. Inline suppression is available via
'ghost-check: ignore' placed on the offending line.

Exit codes:
    0  Clean — no policy violations
    1  Violations found
    2  Runtime or configuration error
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, NamedTuple

try:
    from rich import box as rich_box
    from rich.align import Align
    from rich.console import Console, Group
    from rich.panel import Panel
    from rich.rule import Rule as RichRule
    from rich.table import Table
    from rich.text import Text
except ImportError:
    sys.stderr.write(
        "ghost-check requires the 'rich' library.\nInstall:  pip install rich\n"
    )
    sys.exit(2)


# ───────────────────────────────────────────────────────────────────────────
# Exit codes
# ───────────────────────────────────────────────────────────────────────────

EXIT_CLEAN = 0
EXIT_VIOLATION = 1
EXIT_ERROR = 2


# ───────────────────────────────────────────────────────────────────────────
# Scan configuration
# ───────────────────────────────────────────────────────────────────────────

SCANNER_NAME = "ghost-check"
VERSION = "1.0.0"

MAX_FILE_BYTES = 1_048_576  # 1 MB — skip anything larger

# Directories excluded from scanning (matched by name at any depth).
EXCLUDED_DIRS: frozenset[str] = frozenset(
    {
        ".git",
        ".build",
        ".swiftpm",
        ".claude",
        ".github",
        ".venv",
        "venv",
        "__pycache__",
        "DerivedData",
        "Pods",
        "Carthage",
        "node_modules",
        "docs",
    }
)

# Filenames excluded from scanning (matched exactly).
EXCLUDED_FILES: frozenset[str] = frozenset(
    {
        "CLAUDE.md",
        "README.md",
        "LICENSE.txt",
        "LICENSE",
        ".gitignore",
        ".gitattributes",
        ".swiftlint.yml",
        ".editorconfig",
        "Package.resolved",
        "Podfile.lock",
        "Gemfile.lock",
        "yarn.lock",
        "package-lock.json",
        "Cartfile.resolved",
        "ghost_check.py",
    }
)

# Extensions treated as binary — never opened for reading.
BINARY_EXTENSIONS: frozenset[str] = frozenset(
    {
        # Images
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".bmp",
        ".ico",
        ".icns",
        ".webp",
        ".tiff",
        ".tif",
        ".svg",
        ".heic",
        # Documents
        ".pdf",
        ".doc",
        ".docx",
        ".xls",
        ".xlsx",
        ".ppt",
        ".pptx",
        # Archives
        ".zip",
        ".tar",
        ".gz",
        ".bz2",
        ".xz",
        ".7z",
        ".rar",
        # Media
        ".mp3",
        ".mp4",
        ".wav",
        ".mov",
        ".avi",
        ".mkv",
        ".flac",
        ".aac",
        # Fonts
        ".ttf",
        ".otf",
        ".woff",
        ".woff2",
        ".eot",
        # Compiled / object
        ".dylib",
        ".so",
        ".a",
        ".o",
        ".obj",
        ".exe",
        ".dll",
        ".class",
        ".jar",
        ".pyc",
        ".pyo",
        # Databases
        ".sqlite",
        ".db",
        ".realm",
        # Xcode / iOS artifacts
        ".pbxproj",
        ".xcscheme",
        ".xcworkspacedata",
        ".storyboard",
        ".xib",
        ".plist",
        ".car",
        ".strings",
        ".stringsdict",
        ".entitlements",
        ".mobileprovision",
        ".ipa",
        # Misc
        ".DS_Store",
        ".lock",
    }
)

# Directory suffixes treated as opaque bundles — skipped entirely.
OPAQUE_DIR_SUFFIXES: tuple[str, ...] = (
    ".xcodeproj",
    ".xcworkspace",
    ".xcassets",
    ".framework",
    ".bundle",
    ".app",
    ".dSYM",
)

SUPPRESSION_MARKER = "ghost-check: ignore"


# ───────────────────────────────────────────────────────────────────────────
# Comment syntax definitions
# ───────────────────────────────────────────────────────────────────────────


class CommentSyntax(NamedTuple):
    """Single-line prefixes and multi-line delimiter pairs for a language."""

    single: tuple[str, ...]
    multi: tuple[tuple[str, str], ...]


_HASH = CommentSyntax(single=("#",), multi=())
_C = CommentSyntax(single=("//",), multi=(("/*", "*/"),))
_DASH = CommentSyntax(single=("--",), multi=())
_XML = CommentSyntax(single=(), multi=(("<!--", "-->"),))
_CSS = CommentSyntax(single=(), multi=(("/*", "*/"),))
_SCSS = CommentSyntax(single=("//",), multi=(("/*", "*/"),))
_SEMI = CommentSyntax(single=(";",), multi=())
_INI = CommentSyntax(single=(";", "#"), multi=())

# Extension -> syntax mapping (covers 40+ file types).
COMMENT_SYNTAX: dict[str, CommentSyntax] = {
    # C-family / Swift / Kotlin / Go / Rust / JS / TS
    ".swift": _C,
    ".m": _C,
    ".mm": _C,
    ".h": _C,
    ".c": _C,
    ".cpp": _C,
    ".hpp": _C,
    ".cc": _C,
    ".java": _C,
    ".kt": _C,
    ".kts": _C,
    ".go": _C,
    ".rs": _C,
    ".js": _C,
    ".jsx": _C,
    ".ts": _C,
    ".tsx": _C,
    ".mjs": _C,
    ".cjs": _C,
    ".cs": _C,
    ".scala": _C,
    ".groovy": _C,
    ".dart": _C,
    ".zig": _C,
    # Hash-comment languages
    ".py": _HASH,
    ".pyi": _HASH,
    ".sh": _HASH,
    ".bash": _HASH,
    ".zsh": _HASH,
    ".yaml": _HASH,
    ".yml": _HASH,
    ".toml": _HASH,
    ".rb": _HASH,
    ".pl": _HASH,
    ".r": _HASH,
    ".jl": _HASH,
    ".tf": _HASH,
    ".hcl": _HASH,
    ".cfg": _HASH,
    ".conf": _HASH,
    # INI (supports both ; and #)
    ".ini": _INI,
    # SQL / Lua / Haskell
    ".sql": _DASH,
    ".lua": _DASH,
    ".hs": _DASH,
    ".elm": _DASH,
    # Markup
    ".html": _XML,
    ".xml": _XML,
    ".vue": _XML,
    ".md": _XML,
    # Stylesheets
    ".css": _CSS,
    ".less": _CSS,
    ".scss": _SCSS,
    # Assembly / Lisp
    ".asm": _SEMI,
    ".clj": _SEMI,
    ".cljs": _SEMI,
    ".el": _SEMI,
    ".lisp": _SEMI,
}

# Filename-based fallback for extensionless files.
COMMENT_SYNTAX_BY_NAME: dict[str, CommentSyntax] = {
    "Dockerfile": _HASH,
    "Makefile": _HASH,
    "Rakefile": _HASH,
    "Gemfile": _HASH,
    "Podfile": _HASH,
    "Brewfile": _HASH,
    "Fastfile": _HASH,
    "Appfile": _HASH,
    "Matchfile": _HASH,
    "Dangerfile": _HASH,
    "Jenkinsfile": _C,
}


# ───────────────────────────────────────────────────────────────────────────
# Severity model
# ───────────────────────────────────────────────────────────────────────────


class Severity(Enum):
    BLOCKER = "BLOCKER"
    WARNING = "WARNING"

    @property
    def style(self) -> str:
        if self == Severity.BLOCKER:
            return "bold red"
        return "yellow"


# ───────────────────────────────────────────────────────────────────────────
# Rule definitions
# ───────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Rule:
    """One detection rule: a compiled regex, severity, and scope flag."""

    id: str
    category: str
    severity: Severity
    pattern: re.Pattern[str]
    description: str
    comments_only: bool  # True = match only inside extracted comment text


# Reusable regex fragments for attribution patterns.
_AI_TOOLS = (
    r"(?:ChatGPT|GPT[\s-]?[34o]?|Claude|Gemini|Copilot|Cursor|"
    r"GitHub\s+Copilot|Anthropic|OpenAI|Bard|Codeium|Tabnine|"
    r"Amazon\s+Q|Windsurf|Devin)"
)

_ATTR_VERBS = (
    r"(?:Co[\s-]?authored[\s-]by|Written\s+by|Generated\s+by|"
    r"Created\s+by|Reviewed\s+by|Authored\s+by)"
)

RULES: tuple[Rule, ...] = (
    # ── ATTRIBUTION: explicit provenance claims ─────────── BLOCKER ──
    #
    # These scan full line text (comments_only=False) because attribution
    # markers are distinctive enough that non-comment matches are still
    # policy-relevant and extremely unlikely to be false positives.
    Rule(
        id="ATTR-001",
        category="attribution",
        severity=Severity.BLOCKER,
        pattern=re.compile(
            rf"{_ATTR_VERBS}\s*:?\s*.*?{_AI_TOOLS}",
            re.IGNORECASE,
        ),
        description="Explicit AI attribution (verb + tool name)",
        comments_only=False,
    ),
    Rule(
        id="ATTR-002",
        category="attribution",
        severity=Severity.BLOCKER,
        pattern=re.compile(
            r"\b(?:generated|assisted|drafted|reviewed|written|created|produced)"
            r"\s+(?:by|with|using|via)\s+" + _AI_TOOLS,
            re.IGNORECASE,
        ),
        description="AI provenance phrase with tool name",
        comments_only=False,
    ),
    Rule(
        id="ATTR-003",
        category="attribution",
        severity=Severity.BLOCKER,
        pattern=re.compile(
            r"\b(?:generated|assisted|drafted|reviewed|written|created|produced)"
            r"\s+(?:by|with|using|via)\s+(?:an?\s+)?"
            r"(?:AI|LLM|artificial\s+intelligence|language\s+model)\b",
            re.IGNORECASE,
        ),
        description="AI provenance phrase (generic AI reference)",
        comments_only=False,
    ),
    # ── AI REFERENCES: tool/company names in comments ──── WARNING ──
    #
    # Scoped to comment text only (comments_only=True) to avoid flagging
    # legitimate code that integrates with AI services (e.g. import
    # statements, SDK configuration, API clients).
    Rule(
        id="AIREF-001",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bChatGPT\b", re.IGNORECASE),
        description="ChatGPT reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-002",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bGPT[\s-]?[34o]\b", re.IGNORECASE),
        description="GPT model version reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-003",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bClaude\b"),
        description="Claude reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-004",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bGemini\b"),
        description="Gemini reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-005",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bCopilot\b"),
        description="Copilot reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-006",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bCursor\b"),
        description="Cursor (AI editor) reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-007",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bAnthropic\b"),
        description="Anthropic reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-008",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bOpenAI\b"),
        description="OpenAI reference",
        comments_only=True,
    ),
    Rule(
        id="AIREF-009",
        category="ai_reference",
        severity=Severity.WARNING,
        pattern=re.compile(r"\bLLM\b"),
        description="LLM reference",
        comments_only=True,
    ),
    # ── EMOJI: in comments and commit messages ─────────── WARNING ──
    #
    # Covers standard Unicode emoji ranges. Does not include variation
    # selectors (U+FE0F) or ZWJ (U+200D) as standalone matches to
    # avoid false positives on combining characters.
    Rule(
        id="EMOJI-001",
        category="emoji",
        severity=Severity.WARNING,
        pattern=re.compile(
            "["
            "\U0001f600-\U0001f64f"  # emoticons
            "\U0001f300-\U0001f5ff"  # misc symbols & pictographs
            "\U0001f680-\U0001f6ff"  # transport & map
            "\U0001f1e0-\U0001f1ff"  # flags
            "\U0001f900-\U0001f9ff"  # supplemental symbols
            "\U0001fa00-\U0001fa6f"  # chess symbols
            "\U0001fa70-\U0001faff"  # symbols extended-A
            "\U00002702-\U000027b0"  # dingbats
            "\U00002600-\U000026ff"  # misc symbols
            "\U00002b50-\U00002b55"  # stars & circles
            "]"
        ),
        description="Emoji in comment",
        comments_only=True,
    ),
)


# ───────────────────────────────────────────────────────────────────────────
# Data structures
# ───────────────────────────────────────────────────────────────────────────


@dataclass
class Finding:
    rule: Rule
    file_path: str
    line_number: int
    line_text: str
    source: str  # "file" | "commit-msg"


@dataclass
class ScanResult:
    findings: list[Finding] = field(default_factory=list)
    files_scanned: int = 0
    files_skipped: int = 0

    @property
    def blocker_count(self) -> int:
        return sum(1 for f in self.findings if f.rule.severity == Severity.BLOCKER)

    @property
    def warning_count(self) -> int:
        return sum(1 for f in self.findings if f.rule.severity == Severity.WARNING)

    def merge(self, other: ScanResult) -> None:
        self.findings.extend(other.findings)
        self.files_scanned += other.files_scanned
        self.files_skipped += other.files_skipped


# ───────────────────────────────────────────────────────────────────────────
# Comment extraction engine
# ───────────────────────────────────────────────────────────────────────────


def extract_comment_map(
    lines: list[str],
    syntax: CommentSyntax,
) -> dict[int, str]:
    """Build line_number (1-indexed) -> comment_text mapping.

    Heuristic parser: does not account for comment delimiters inside
    string literals. Acceptable trade-off for a policy scanner.
    """
    result: dict[int, str] = {}
    in_block = False
    close_marker = ""

    for lineno, line in enumerate(lines, start=1):
        if in_block:
            close_pos = line.find(close_marker)
            if close_pos >= 0:
                result[lineno] = line[:close_pos]
                in_block = False
            else:
                result[lineno] = line
            continue

        # Multi-line openers take precedence.
        found_multi = False
        for open_d, close_d in syntax.multi:
            open_pos = line.find(open_d)
            if open_pos < 0:
                continue
            after = line[open_pos + len(open_d) :]
            close_pos = after.find(close_d)
            if close_pos >= 0:
                result[lineno] = after[:close_pos]
            else:
                result[lineno] = after
                in_block = True
                close_marker = close_d
            found_multi = True
            break

        if found_multi:
            continue

        for prefix in syntax.single:
            pos = line.find(prefix)
            if pos >= 0:
                result[lineno] = line[pos + len(prefix) :]
                break

    return result


# ───────────────────────────────────────────────────────────────────────────
# File classification helpers
# ───────────────────────────────────────────────────────────────────────────


def is_binary(path: Path, sample_size: int = 8192) -> bool:
    """Null-byte heuristic for binary detection."""
    try:
        with path.open("rb") as fh:
            return b"\x00" in fh.read(sample_size)
    except OSError:
        return True


def _skip_dir(name: str) -> bool:
    if name in EXCLUDED_DIRS:
        return True
    return any(name.endswith(s) for s in OPAQUE_DIR_SUFFIXES)


def _skip_file(path: Path) -> bool:
    if path.name in EXCLUDED_FILES:
        return True
    if path.suffix.lower() in BINARY_EXTENSIONS:
        return True
    try:
        if path.stat().st_size > MAX_FILE_BYTES:
            return True
    except OSError:
        return True
    return False


def _syntax_for(path: Path) -> CommentSyntax | None:
    return COMMENT_SYNTAX.get(path.suffix.lower()) or COMMENT_SYNTAX_BY_NAME.get(
        path.name
    )


# ───────────────────────────────────────────────────────────────────────────
# Policy engine
# ───────────────────────────────────────────────────────────────────────────


def apply_rules(
    lines: list[str],
    file_path: str,
    syntax: CommentSyntax | None,
    source: str,
    *,
    full_text_mode: bool,
) -> list[Finding]:
    """Match every rule against a list of lines.

    full_text_mode: when True all rules match against the full line
    (used for commit messages where every line is policy-relevant).
    When False, comments_only rules match only extracted comment text.
    """
    findings: list[Finding] = []
    comment_map: dict[int, str] = {}

    if syntax and not full_text_mode:
        comment_map = extract_comment_map(lines, syntax)

    for lineno, line in enumerate(lines, start=1):
        if SUPPRESSION_MARKER in line:
            continue

        for rule in RULES:
            target: str
            if full_text_mode or not rule.comments_only:
                target = line
            else:
                comment_text = comment_map.get(lineno)
                if comment_text is None:
                    continue
                target = comment_text

            if rule.pattern.search(target):
                findings.append(
                    Finding(
                        rule=rule,
                        file_path=file_path,
                        line_number=lineno,
                        line_text=line.rstrip(),
                        source=source,
                    )
                )

    return findings


# ───────────────────────────────────────────────────────────────────────────
# Repository file scanner
# ───────────────────────────────────────────────────────────────────────────


def scan_files(repo_root: Path) -> ScanResult:
    """Walk the repository tree and scan all eligible text files."""
    result = ScanResult()

    for dirpath, dirnames, filenames in os.walk(repo_root, topdown=True):
        dirnames[:] = sorted(d for d in dirnames if not _skip_dir(d))

        for name in sorted(filenames):
            path = Path(dirpath) / name

            if _skip_file(path):
                result.files_skipped += 1
                continue

            if is_binary(path):
                result.files_skipped += 1
                continue

            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                result.files_skipped += 1
                continue

            lines = text.splitlines()
            syntax = _syntax_for(path)
            rel = str(path.relative_to(repo_root))

            result.findings.extend(
                apply_rules(lines, rel, syntax, source="file", full_text_mode=False)
            )
            result.files_scanned += 1

    return result


# ───────────────────────────────────────────────────────────────────────────
# Commit message scanner
# ───────────────────────────────────────────────────────────────────────────


def scan_commit_msg(msg_file: Path) -> ScanResult:
    """Scan a commit message file for policy violations.

    Lines starting with '#' are stripped (Git comment convention).
    """
    result = ScanResult()

    try:
        text = msg_file.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return result

    lines = [ln for ln in text.splitlines() if not ln.startswith("#")]

    result.findings.extend(
        apply_rules(
            lines,
            file_path=str(msg_file),
            syntax=None,
            source="commit-msg",
            full_text_mode=True,
        )
    )
    result.files_scanned = 1
    return result


# ───────────────────────────────────────────────────────────────────────────
# Renderer
# ───────────────────────────────────────────────────────────────────────────


def _truncate(text: str, width: int = 100) -> str:
    return text if len(text) <= width else text[: width - 3] + "..."


def _build_context(
    finding: Finding,
    repo_root: Path,
    radius: int = 2,
) -> Text | None:
    """Build surrounding source lines as a Rich Text block."""
    path = repo_root / finding.file_path
    try:
        all_lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None

    ctx = Text()
    start = max(0, finding.line_number - 1 - radius)
    end = min(len(all_lines), finding.line_number + radius)

    for i in range(start, end):
        num = i + 1
        is_match = num == finding.line_number
        prefix = ">>" if is_match else "  "
        line_content = all_lines[i].rstrip()
        if len(line_content) > 88:
            line_content = line_content[:85] + "..."
        style = "bold" if is_match else "dim"
        if i > start:
            ctx.append("\n")
        ctx.append(f"{prefix} {num:>4} | {line_content}", style=style)

    return ctx


def render(
    result: ScanResult,
    console: Console,
    *,
    strict: bool,
    show_context: bool,
    repo_root: Path | None = None,
) -> None:
    """Render scan results to the terminal."""
    console.print()
    if not result.findings:
        _render_clean(result, console)
    else:
        _render_violations(result, console, strict, show_context, repo_root)
    console.print()


def _render_clean(result: ScanResult, console: Console) -> None:
    stats = Table.grid(padding=(0, 3))
    stats.add_column(justify="right", style="dim")
    stats.add_column()
    stats.add_column(justify="right", style="dim")
    stats.add_column()
    stats.add_column(justify="right", style="dim")
    stats.add_column()
    stats.add_row(
        "Scanned",
        str(result.files_scanned),
        "Skipped",
        str(result.files_skipped),
        "Status",
        Text("PASS", style="bold green"),
    )

    content = Group(
        Text(""),
        Align.center(
            Text("Clean -- no policy violations detected.", style="bold green")
        ),
        Text(""),
        Align.center(stats),
        Text(""),
    )
    console.print(
        Panel(
            content,
            title=f"[bold]{SCANNER_NAME} v{VERSION}[/bold]",
            border_style="green",
            padding=(0, 2),
        )
    )


def _render_violations(
    result: ScanResult,
    console: Console,
    strict: bool,
    show_context: bool,
    repo_root: Path | None,
) -> None:
    has_blockers = result.blocker_count > 0
    fail = has_blockers or (strict and result.warning_count > 0)
    border = "red" if fail else "yellow"

    parts: list[Any] = []

    by_file: dict[str, list[Finding]] = {}
    for f in result.findings:
        by_file.setdefault(f.file_path, []).append(f)
    for file_findings in by_file.values():
        file_findings.sort(key=lambda finding: finding.line_number)

    for file_path in sorted(by_file):
        findings = by_file[file_path]

        if findings[0].source == "commit-msg":
            label = f"COMMIT MESSAGE  {file_path}"
        else:
            label = file_path
        parts.append(RichRule(label, style="cyan", align="left"))

        table = Table(
            box=rich_box.HEAVY_HEAD,
            expand=True,
            show_lines=True,
            border_style="dim",
            header_style="bold",
            padding=(0, 1),
        )
        table.add_column("Line", width=6, justify="right", style="cyan")
        table.add_column("Severity", width=9, justify="center")
        table.add_column("Finding", ratio=1)

        for finding in findings:
            sev = finding.rule.severity
            sev_text = Text(sev.value, style=sev.style)

            cell = Text()
            cell.append(finding.rule.id, style="bold dim")
            cell.append(f"  {finding.rule.description}\n")
            cell.append(
                _truncate(finding.line_text.strip()), style="dim italic"
            )

            if show_context and repo_root and finding.source == "file":
                ctx = _build_context(finding, repo_root)
                if ctx:
                    cell.append("\n")
                    cell.append_text(ctx)

            table.add_row(str(finding.line_number), sev_text, cell)

        parts.append(table)
        parts.append(Text(""))

    parts.append(_build_summary(result, strict, fail))

    outer = Panel(
        Group(*parts),
        title=f"[bold]{SCANNER_NAME} v{VERSION}[/bold]",
        subtitle="[dim]policy violations detected[/dim]",
        border_style=border,
        padding=(1, 2),
    )
    console.print(outer)


def _build_summary(result: ScanResult, strict: bool, fail: bool) -> Panel:
    grid = Table.grid(padding=(0, 4))
    grid.add_column()
    grid.add_column()

    left = Table.grid(padding=(0, 2))
    left.add_column(justify="right", style="dim")
    left.add_column()
    left.add_row("Files scanned", str(result.files_scanned))
    left.add_row("Files skipped", str(result.files_skipped))
    left.add_row("Total findings", str(len(result.findings)))

    right = Table.grid(padding=(0, 2))
    right.add_column(justify="right", style="dim")
    right.add_column()
    right.add_row(
        "Blockers",
        Text(
            str(result.blocker_count),
            style="bold red" if result.blocker_count else "green",
        ),
    )
    right.add_row(
        "Warnings",
        Text(
            str(result.warning_count),
            style="yellow" if result.warning_count else "green",
        ),
    )
    status = Text("FAIL", style="bold red") if fail else Text("PASS", style="bold green")
    right.add_row("Status", status)

    grid.add_row(left, right)

    subtitle = None
    if strict and result.warning_count > 0 and not result.blocker_count:
        subtitle = "[dim]--strict: warnings elevated to failures[/dim]"

    return Panel(
        grid,
        title="[bold]Summary[/bold]",
        border_style="red" if fail else "green",
        padding=(1, 2),
        subtitle=subtitle,
    )


# ───────────────────────────────────────────────────────────────────────────
# CLI
# ───────────────────────────────────────────────────────────────────────────


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog=SCANNER_NAME,
        description="Scan for AI attribution markers and policy violations.",
    )
    p.add_argument(
        "--scan-files",
        action="store_true",
        help="Scan repository files (default when no mode specified).",
    )
    p.add_argument(
        "--scan-commit-msg",
        action="store_true",
        help="Scan a commit message file.",
    )
    p.add_argument(
        "--commit-msg-file",
        type=Path,
        metavar="PATH",
        help="Path to commit message file (required with --scan-commit-msg).",
    )
    p.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        metavar="PATH",
        help="Repository root (default: cwd).",
    )
    p.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as failures (exit 1 on any finding).",
    )
    p.add_argument(
        "--show-context",
        action="store_true",
        help="Show surrounding source lines for each finding.",
    )
    p.add_argument(
        "--version",
        action="version",
        version=f"{SCANNER_NAME} {VERSION}",
    )
    return p


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if not args.scan_files and not args.scan_commit_msg:
        args.scan_files = True

    if args.scan_commit_msg and not args.commit_msg_file:
        parser.error("--commit-msg-file is required with --scan-commit-msg")

    console = Console()
    combined = ScanResult()

    try:
        if args.scan_files:
            root = args.repo_root.resolve()
            if not root.is_dir():
                console.print(
                    f"[bold red]Error:[/bold red] repository root not found: {root}"
                )
                return EXIT_ERROR
            combined.merge(scan_files(root))

        if args.scan_commit_msg:
            msg_path = args.commit_msg_file.resolve()
            if not msg_path.is_file():
                console.print(
                    f"[bold red]Error:[/bold red] "
                    f"commit message file not found: {msg_path}"
                )
                return EXIT_ERROR
            combined.merge(scan_commit_msg(msg_path))

    except KeyboardInterrupt:
        console.print("\n[dim]Interrupted.[/dim]")
        return EXIT_ERROR
    except Exception as exc:
        console.print(f"[bold red]Runtime error:[/bold red] {exc}")
        return EXIT_ERROR

    render(
        combined,
        console,
        strict=args.strict,
        show_context=args.show_context,
        repo_root=args.repo_root.resolve() if args.scan_files else None,
    )

    if combined.blocker_count > 0:
        return EXIT_VIOLATION
    if args.strict and combined.warning_count > 0:
        return EXIT_VIOLATION
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())
