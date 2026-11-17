"""Whether the terminal shows a selection dialog, from the tail of the terminal log. No I/O."""

TAIL_BYTES = 65536


def dialog_on_screen(tail):
    """True if tail (the last TAIL_BYTES of terminal.log) shows a selection dialog that has not been
    answered yet. The AskUserQuestion record can reach the transcript a few seconds after the dialog
    is drawn (test-07), and text typed into an open dialog selects an option instead of being sent."""
    shown = tail.rfind(b"Enter to select")
    return shown >= 0 and shown > tail.rfind(b"User answered") and shown > tail.rfind(b"User declined")
