"""What the main loop does at one tick, from the state at that tick. No I/O.

The probes on_screen() and busy() do I/O (terminal log, docker exec ps) and are called lazily,
in the same order and under the same conditions as in the original loop.
"""
DIALOG = "dialog"      # answer the pending AskUserQuestion dialog
TIME_UP = "time_up"    # type the stage-4 time-up text (staged.py only)
BREAK = "break"        # the agent is at a break: act on its last turn
WAIT = "wait"


def decide(*, now, qid, last_change, turn_ends, handled_turns, in_turn, time_up, quiet, dialog_quiet,
           on_screen, busy):
    if qid and now - last_change > dialog_quiet:
        return DIALOG
    if time_up and not qid and not on_screen():
        return TIME_UP
    if turn_ends <= handled_turns:
        return WAIT
    # Act only at a break: the latest turn has ended and nothing has started since.
    if in_turn or now - last_change < quiet or busy():
        return WAIT
    return BREAK


def handled_after_time_up(handled_turns, ends_before):
    """Turn ends that happen from the time-up text on are handled at stage 45, which waits until the
    agent has written text after the message."""
    return min(handled_turns, ends_before)
