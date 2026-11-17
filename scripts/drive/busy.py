"""Whether the agent still has child processes (e.g. a background build), from `ps` output. No I/O."""

PS_SCRIPT = "ps -eo comm= | sort | uniq -c"
IGNORED = frozenset({"docker-init", "claude", "ps", "sort", "uniq", "sh"})
# Preregistration 12.5: once the agent's turn has ended, leftover child processes (e.g. a background
# wait that never finishes) delay the operator by at most this long.
BUSY_GRACE_SECS = 600


def other_processes(ps_output):
    """Command names in `ps -eo comm= | sort | uniq -c` output other than the agent's and the harness's."""
    names = {ln.split()[-1] for ln in ps_output.splitlines() if ln.strip()}
    return names - IGNORED


def decide(ps_output, *, in_turn, turn_end_at, turn_ends, grace_recorded, now, grace):
    """(busy, grace_event). grace_event is the busy_grace_elapsed record's fields (without the
    event name) the first time the grace has elapsed after turn end number turn_ends, else None."""
    others = other_processes(ps_output)
    if not others:
        return False, None
    # Preregistration 12.5: the turn has ended and the processes have outlived the grace period.
    if not in_turn and turn_end_at is not None and now - turn_end_at >= grace:
        event = None
        if grace_recorded != turn_ends:
            event = {"turn": turn_ends, "seconds_since_turn_end": int(now - turn_end_at),
                     "processes": sorted(others)}
        return False, event
    return True, None
