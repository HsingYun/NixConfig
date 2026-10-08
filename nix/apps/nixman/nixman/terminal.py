"""Terminal presentation only; structured output never passes through styling."""
import os
import re
import sys


STYLES = {
    "heading": "1;36",
    "success": "32",
    "warning": "33",
    "error": "31",
    "add": "32",
    "remove": "31",
    "change": "33",
    "prompt": "1",
}
CHANGE_STYLES = {"+": "add", "-": "remove", "~": "change"}
SGR = re.compile(r"\x1b\[[0-9;:]*m")


def color_enabled(stream=None):
    stream = sys.stdout if stream is None else stream
    return (stream.isatty() and os.environ.get("TERM", "").lower() not in ("", "dumb", "unknown")
            and not os.environ.get("NO_COLOR"))


def style(text, kind, *, stream=None):
    return f"\x1b[{STYLES[kind]}m{text}\x1b[0m" if color_enabled(stream) else text


def emit(text, kind, *, file=None, flush=False):
    print(style(text, kind, stream=file), file=file, flush=flush)


def field(name, value):
    print(f"{style(name + ':', 'heading')} {value}")


def external(text):
    # Nix diff-closures may include SGR even when stdout is redirected.
    return text if color_enabled() else SGR.sub("", text)
