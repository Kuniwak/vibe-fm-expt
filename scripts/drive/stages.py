"""The staged procedure of conditions D and D2 (preregistration.md ch. 11) as a state machine. No I/O.

Each step takes the state (not modified) and returns (new state, actions); the shell executes the
actions in order:
  MarkTime(key)              stage_times[key] = now
  Snapshot(label, stage)     snapshot of the container; the record carries `stage`
  StartClock()               the stage-4 clock starts now (after the S2 snapshot)
  Send(text, stage, fields)  type text and wait for its delivery; the "sent" record carries
                             `stage` and then `fields` in this order. text may be FileText(key):
                             the shell reads that fixed text when it executes the action.
  Record(fields)             write fields (the event name first) to operator.jsonl
  Exit()                     type /exit and end the session
"""
import copy
from dataclasses import dataclass
from typing import Callable

TYPES = (1, 2, 3)
MAX_INSTRUCTIONS = 2


class State:
    def __init__(self, stage=1, verdict=None, instructions=None, stage45_text=None):
        self.stage = stage
        self.verdict = verdict if verdict is not None else {t: None for t in TYPES}   # APPROVE / FAILED
        self.instructions = instructions if instructions is not None else {t: 0 for t in TYPES}
        self.stage45_text = stage45_text   # the stage-4 closing text actually sent (time-up or done)

    def __repr__(self):
        return f"State({self.__dict__})"


@dataclass(frozen=True)
class Config:
    reply: str
    fixed: str
    remake_text: str
    evidence_text: str
    read: Callable    # read(key) -> fixed text; key in "stage2", "stage4", "timeup", "done"


@dataclass(frozen=True)
class FileText:
    key: str


@dataclass(frozen=True)
class MarkTime:
    key: str


@dataclass(frozen=True)
class Snapshot:
    label: str
    stage: int


@dataclass(frozen=True)
class StartClock:
    pass


@dataclass(frozen=True)
class Send:
    text: object
    stage: int
    fields: dict


@dataclass(frozen=True)
class Record:
    fields: dict


@dataclass(frozen=True)
class Exit:
    pass


def is_time_up(stage, stage4_start, now, minutes):
    return stage == 4 and stage4_start is not None and now - stage4_start >= minutes * 60


def break_kind(state):
    """"final" (stage 5), "closing" (stage 45) or "role" (the user role is asked first)."""
    if state.stage == 5:
        return "final"
    if state.stage == 45:
        return "closing"
    return "role"


def final(state, last):
    """Stage 5: the agent answered the final question."""
    return state, [Snapshot("S3", state.stage),
                   Record({"event": "end", "after_message": last[0], "reason": "agent answered the final question"}),
                   Exit()]


def closing(state, cfg, last, answered):
    """Stage 45: advance only after the agent has written text following the time-up / done message.
    answered: the closing text was delivered and agent text followed it."""
    if not answered:
        return state, [Record({"event": "wait", "stage": 45, "after_message": last[0],
                               "reason": "no agent text after the stage-4 closing message yet"})]
    s = copy.deepcopy(state)
    s.stage = 5
    return s, [Send(cfg.fixed, s.stage, {"after_message": last[0], "rule": "段階5の固定文"})]


def after_role(state, cfg, last, message, parsed, raw, tries):
    """Stages 1, 3 and 4: act on the user role's parsed answer (None: no valid answer)."""
    s = copy.deepcopy(state)
    base = {"after_message": last[0], "role_input": message, "role_output": raw, "role_attempts": tries}
    if parsed is None:
        return s, [Record({"event": "role_error", "stage": s.stage, **base}), Exit()]
    if parsed["choice"] == "REPLY":
        return s, [Send(cfg.reply, s.stage, {"rule": "規則による「お任せします」", **base})]
    if s.stage == 1:                       # COMPLETE
        acts = [MarkTime("stage2_start"), Snapshot("S1", s.stage)]
        s.stage = 3
        return s, acts + [Send(FileText("stage2"), s.stage, {"rule": "段階2の固定文", **base})]
    if s.stage == 3:                       # JUDGE
        parts, decisions = [], {}
        for t in TYPES:
            if s.verdict[t] is not None:
                continue
            v = parsed["types"][t]
            if v == "APPROVE":
                s.verdict[t] = "APPROVE"
            elif s.instructions[t] >= MAX_INSTRUCTIONS:
                s.verdict[t] = "FAILED"    # 変種を作れなかった
            else:
                s.instructions[t] += 1
                parts.append((cfg.remake_text if v == "REMAKE" else cfg.evidence_text).format(n=t))
            decisions[t] = {"judgement": v, "verdict": s.verdict[t], "instructions": s.instructions[t]}
        acts = [Record({"event": "review", "stage": 3, "decisions": decisions, **base})]
        if parts:
            return s, acts + [Send("\n".join(parts), s.stage, {"rule": "段階3の規則", "after_message": last[0]})]
        acts += [MarkTime("stage4_start"), Snapshot("S2", s.stage), StartClock()]
        s.stage = 4
        return s, acts + [Send(FileText("stage4"), s.stage, {"rule": "段階4の固定文", "after_message": last[0]})]
    if s.stage == 4:                       # COMPLETE before the time limit
        s.stage = 45
        s.stage45_text = cfg.read("done")
        return s, [Send(s.stage45_text, s.stage, {"rule": "段階4の完了の報告を受けた（「時間です。」を省く）", **base})]
    return s, []


def time_up(state, cfg, last, agent_busy):
    """Stage 4 time limit: the time-up text is typed even while the agent works."""
    s = copy.deepcopy(state)
    s.stage = 45
    s.stage45_text = cfg.read("timeup")
    return s, [Send(s.stage45_text, s.stage, {"rule": "段階4の制限時間（60分）", "after_message": last[0],
                                              "agent_busy": agent_busy})]


def summary_fields(state):
    return {"final_stage": state.stage, "verdicts": state.verdict, "instructions": state.instructions,
            "fixed_sent": state.stage == 5}
