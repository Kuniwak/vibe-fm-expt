# Stand-in for the user role in a harness check: fixed answers, no model call.
# MOCK_ROLE=complete (default): stages end at once and all variants are approved.
# MOCK_ROLE=reply: every turn end gets the canned reply (the stage-1 loop of run-32 and run-34).
# MOCK_ROLE=remake: type 1 is never approved (instructions, then "could not be made"); stage 4 is
#   never complete, so the stage-4 time limit closes it.
# MOCK_ROLE=garbage: no valid answer at all.
import json, os, re, sys
msg = sys.stdin.read()
stage = re.search(r'現在の段階: (\d+)', msg).group(1)
mode = os.environ.get("MOCK_ROLE")
if mode == "reply":
    out = "REPLY\nテスト。"
elif mode == "garbage":
    out = "わかりません。"
elif mode == "remake":
    out = {'1': 'COMPLETE\nテスト。', '3': '1: REMAKE\n2: APPROVE\n3: APPROVE\nテスト。'}.get(stage, 'REPLY\nテスト。')
else:
    out = {'1': 'COMPLETE\nテスト。', '3': '1: APPROVE\n2: APPROVE\n3: APPROVE\nテスト。',
           '4': 'COMPLETE\nテスト。'}.get(stage, 'REPLY\nテスト。')
print(json.dumps({'result': out}, ensure_ascii=False))
