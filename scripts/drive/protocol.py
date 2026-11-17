"""Conditions A-C (driver.py): at each break the blind operator decides between the reply and the
fixed message; after the answer to the fixed message the session ends. No I/O."""
END = "end"        # the agent answered the fixed message
LIMIT = "limit"    # reply limit reached: send the fixed message without asking
ASK = "ask"        # ask the operator


def at_break(*, fixed_sent, replies, max_replies):
    if fixed_sent:
        return END
    if replies >= max_replies:
        return LIMIT
    return ASK


def limit_answer(max_replies):
    """(choice, reason, attempts, raw) used instead of the operator at the reply limit."""
    return "2", f"reply limit {max_replies} reached", 0, ""


def after_answer(choice, *, replies, fixed_sent, reply, fixed):
    """(text to send, replies, fixed_sent) after the operator's choice."""
    if choice == "1":
        return reply, replies + 1, fixed_sent
    return fixed, replies, True


def end_record(last):
    return {"event": "end", "after_message": last[0], "reason": "agent answered the fixed message"}


def error_record(last, raw):
    return {"event": "operator_error", "after_message": last[0], "raw": raw}


def sent_record(last, choice, reason, tries, text, ok):
    return {"event": "sent", "after_message": last[0], "agent_text": last[1], "operator_choice": choice,
            "operator_reason": reason, "operator_attempts": tries, "sent": text, "confirmed": ok}


def summary_fields(replies, fixed_sent):
    return {"replies_sent": replies, "fixed_sent": fixed_sent}
