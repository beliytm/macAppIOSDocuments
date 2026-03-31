#!/usr/bin/env python3
"""
Payslip GPT extraction test runner.

Usage:
  python3 run_tests.py                     # run all tests
  python3 run_tests.py werckpost-week12    # run specific test by id
  python3 run_tests.py --list              # list all test ids

To add a new PDF format:
  1. Open payslip_cases.json
  2. Add a new object with:
     - "id": unique identifier (e.g. "worketeers-week12-2026")
     - "description": what's special about this format
     - "source_file": original PDF filename
     - "pdf_text": extracted text from the PDF (copy from Xcode console logs)
     - "expected": dict of field names -> expected values (only fields you want to verify)
  3. Run this script to verify
"""

import json, sys, urllib.request, re
from pathlib import Path

TESTS_DIR = Path(__file__).parent
CASES_FILE = TESTS_DIR / "payslip_cases.json"
PROMPT_SOURCE = TESTS_DIR.parent / "AppModules" / "Tab2Module.swift"

# ── Load system prompt from the Swift file ──────────────────────────────────

def load_system_prompt() -> str:
    source = PROMPT_SOURCE.read_text()
    match = re.search(r'let systemPrompt = """(.*?)"""', source, re.DOTALL)
    if not match:
        print("❌ Could not find systemPrompt in Tab2Module.swift")
        sys.exit(1)
    # strip leading whitespace that Swift indentation adds
    lines = match.group(1).split("\n")
    cleaned = "\n".join(line.lstrip("                ") for line in lines)
    return cleaned.strip()

# ── GPT call ────────────────────────────────────────────────────────────────

def call_gpt(api_key: str, system: str, user: str) -> dict:
    body = json.dumps({
        "model": "gpt-4o-mini",
        "response_format": {"type": "json_object"},
        "max_tokens": 1000,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user",   "content": user[:2500]}
        ]
    }).encode()
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(json.loads(r.read())["choices"][0]["message"]["content"])

# ── Compare result vs expected ───────────────────────────────────────────────

TOLERANCE = 0.05  # allow ±0.05 difference for floats

def compare(result: dict, expected: dict) -> tuple[list, list]:
    ok, fail = [], []
    for key, exp_val in expected.items():
        got = result.get(key, "MISSING")
        if isinstance(exp_val, float) and isinstance(got, (int, float)):
            passed = abs(float(got) - exp_val) <= TOLERANCE
        elif isinstance(exp_val, str):
            passed = str(got).strip() == exp_val.strip()
        else:
            passed = got == exp_val
        entry = f"  {'✅' if passed else '❌'} {key}: got={got}  expected={exp_val}"
        (ok if passed else fail).append(entry)
    return ok, fail

# ── Main ────────────────────────────────────────────────────────────────────

def main():
    cases = json.loads(CASES_FILE.read_text())

    # --list
    if "--list" in sys.argv:
        print("Available test cases:")
        for c in cases:
            print(f"  {c['id']}  —  {c['description']}")
        return

    # filter by id if given
    filter_id = next((a for a in sys.argv[1:] if not a.startswith("-")), None)
    if filter_id:
        cases = [c for c in cases if filter_id in c["id"]]
        if not cases:
            print(f"❌ No test found matching '{filter_id}'")
            sys.exit(1)

    # API key
    api_key = input("OpenAI API key (or press Enter to skip GPT calls): ").strip()
    if not api_key:
        print("No key provided — skipping GPT calls, showing test structure only.")
        for c in cases:
            print(f"\n📄 {c['id']}: {c['description']}")
            print(f"   Fields to verify: {list(c['expected'].keys())}")
        return

    system_prompt = load_system_prompt()
    print(f"\n✓ Loaded system prompt ({len(system_prompt)} chars) from Tab2Module.swift")
    print(f"✓ Running {len(cases)} test(s)...\n")

    total_ok = total_fail = 0

    for case in cases:
        print(f"{'='*65}")
        print(f"  {case['id']}")
        print(f"  {case['description']}")
        print(f"{'='*65}")

        try:
            result = call_gpt(api_key, system_prompt, case["pdf_text"])
        except Exception as e:
            print(f"  ❌ GPT call failed: {e}")
            total_fail += 1
            continue

        ok, fail = compare(result, case["expected"])
        total_ok += len(ok)
        total_fail += len(fail)

        for f in fail: print(f)
        for o in ok:   print(o)

        extra = result.get("extra", {})
        if extra:
            print(f"\n  ⚠️  extra fields found: {extra}")
            print("     → Add these to SalaryAnalysis if they appear consistently!")
        else:
            print(f"\n  extra: {{}}  ✅ (no unknown fields)")

        print(f"  company: {result.get('companyName')}  |  {result.get('dateFrom')} → {result.get('dateTo')}")
        print()

    print(f"{'='*65}")
    print(f"  TOTAL: {total_ok} ✅  {total_fail} ❌")
    print(f"{'='*65}")

if __name__ == "__main__":
    main()
