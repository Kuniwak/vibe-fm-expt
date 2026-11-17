"""The keystrokes that answer an AskUserQuestion dialog with the reply text. No I/O.

Operations, executed in order by the shell:
  ("key", bytes)          write the bytes, then pump 0.7 s (Session.key)
  ("type", text, enter)   write the text, pump 0.5 s, Enter if enter, pump 0.5 s (Session.type)
  ("pump", secs)          read the terminal for secs
"""
DOWN = b"\x1b[B"
ENTER = b"\r"
QUESTION_PAUSE = 1.5     # after each question
CONFIRM_POLLS = 5        # polls (1 s each) for the result before, and again after, the fallback Enter


def keystrokes(qinput, reply):
    # Layout per question: options 1..k, then "k+1. Type something." (free text), then a
    # separator and "Chat about this". The cursor starts on option 1, so k presses of the
    # down arrow land on the free-text entry; typing there and pressing Enter answers it.
    ops = []
    for q in qinput.get("questions", []) or [{}]:
        for _ in range(len(q.get("options", []))):
            ops.append(("key", DOWN))
        if q.get("multiSelect"):
            # In a multi-select question, typing into the free-text entry ticks it and Enter would
            # untick it. The entry right below it ("Next", or "Submit" for the last question)
            # moves on, so type without Enter, step down once, and press Enter there.
            ops += [("type", reply, False), ("key", DOWN), ("key", ENTER)]
        else:
            ops.append(("type", reply, True))
        ops.append(("pump", QUESTION_PAUSE))
    return ops


def record_fields(qid, qinput, reply):
    """Fields of the "dialog" record (without the event name)."""
    n = len(qinput.get("questions", [])) or 1
    return {"tool_use_id": qid, "questions": qinput.get("questions"),
            "action": f"typed {reply!r} into the free-text option of {n} question(s)"}
