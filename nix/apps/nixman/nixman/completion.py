"""Read-only completion candidates derived from the actual CLI parser."""
import argparse
from pathlib import Path

from .backends import detect
from .inspection import list_data
from .runtime import Error


def script(shell):
    return (Path(__file__).resolve().parent.parent / "completions" / shell).read_text()


def complete(words, parser):
    """Words exclude the executable and include the current (possibly empty) word."""
    if not words:
        words = [""]
    prefix = words[-1]
    positional = 0
    pending = None
    options = True
    for word in words[:-1]:
        if pending is not None:
            pending = None
            continue
        if options and word == "--":
            options = False
            continue
        if options and word.startswith("-"):
            flag, separator, _ = word.partition("=")
            action = parser._option_string_actions.get(flag)
            if action is None:
                return []
            if action.nargs != 0 and not separator:
                pending = action
            continue
        actions = [action for action in parser._actions if not action.option_strings]
        if positional >= len(actions):
            return []
        action = actions[positional]
        if isinstance(action, argparse._SubParsersAction):
            parser = action.choices.get(word)
            if parser is None:
                return []
            positional = 0
        else:
            positional += 1
    if pending is not None:
        choices = list(pending.choices or [])
    elif options and prefix.startswith("-"):
        choices = list(parser._option_string_actions)
    else:
        actions = [action for action in parser._actions if not action.option_strings]
        action = actions[positional] if positional < len(actions) else None
        if isinstance(action, argparse._SubParsersAction):
            choices = list(action.choices)
        elif action is not None and action.choices is not None:
            choices = list(action.choices)
        elif action is not None and action.dest in ("generation", "before", "after"):
            try:
                choices = [str(gen["id"]) for gen in list_data(detect())["generations"] if gen["available"]]
            except (Error, OSError, ValueError):
                choices = []
        else:
            choices = []
    return sorted(value for value in choices if value.startswith(prefix))
