# Stand-in for the user role in a harness check: fixed answers, no model call.
# MOCK_ROLE=complete (default): stages end at once and all variants are approved.
# MOCK_ROLE=reply: every turn end gets the canned reply (the stage-1 loop of run-32 and run-34).
import json, os, re, sys
msg = sys.stdin.read()
stage = re.search(r'現在の段階: (\d+)', msg).group(1)
if os.environ.get("MOCK_ROLE") == "reply":
    out = "REPLY\nテスト。"
else:
    out = {'1': 'COMPLETE\nテスト。', '3': '1: APPROVE\n2: APPROVE\n3: APPROVE\nテスト。',
           '4': 'COMPLETE\nテスト。'}.get(stage, 'REPLY\nテスト。')
print(json.dumps({'result': out}, ensure_ascii=False))
