#!/usr/bin/env python3
"""Read the most recent Apple 6-digit 2FA code from the macOS Messages database.

Used by the app-store-submission Playwright flow to auto-fill App Store Connect's
two-factor prompt. Apple's *trusted-device* push shows the code only in an on-device
dialog (unreadable) — so on the ASC login screen choose **"Didn't get a code? → Send
code via text message"**, which delivers an SMS that syncs into Messages and lands here.

Prerequisites:
  - The terminal / Claude Code must have **Full Disk Access** (System Settings → Privacy
    & Security → Full Disk Access) — otherwise chat.db is "authorization denied".
  - The trusted phone number's SMS must sync to this Mac's Messages app.

Usage:
  python3 read_imessage_2fa.py                # newest code from the last 5 minutes
  python3 read_imessage_2fa.py --within 120   # only codes from the last 120 seconds
  python3 read_imessage_2fa.py --wait 90      # poll up to 90s until a fresh code arrives

Prints just the 6-digit code to stdout (exit 0), or nothing + exit 1 if none found.
"""
import argparse, os, re, sqlite3, sys, time

DB = os.path.expanduser("~/Library/Messages/chat.db")
# Apple verification texts: "Your Apple Account code is: 123456", "Apple ID Code: 123456",
# "...código de Apple es: 123456", etc. Require an Apple/verification cue near a 6-digit run.
CUE = re.compile(r"(apple|verification|verify|code|c[oó]digo|one[- ]time)", re.I)
CODE = re.compile(r"(?<!\d)(\d{6})(?!\d)")
APPLE_COOKIE = b"#@"  # Apple appends a no-autofill marker; not required but common


def _decode_attributed_body(blob: bytes) -> str:
    """Best-effort text extraction from the NSAttributedString typedstream blob."""
    if not blob:
        return ""
    # The readable message text is plain ASCII inside the archive; decode loosely and
    # keep printable runs so the regex can find the code + cue words.
    s = blob.decode("utf-8", "ignore")
    return "".join(ch if 32 <= ord(ch) < 127 else " " for ch in s)


def latest_code(within_seconds: int):
    if not os.path.exists(DB):
        print("chat.db not found", file=sys.stderr)
        return None
    try:
        con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    except sqlite3.OperationalError as e:
        print(f"cannot open chat.db ({e}); grant Full Disk Access", file=sys.stderr)
        return None
    try:
        # Apple epoch = 2001-01-01; `date` is nanoseconds since then.
        cutoff_apple_ns = int((time.time() - within_seconds - 978307200) * 1_000_000_000)
        rows = con.execute(
            "SELECT text, attributedBody, date FROM message "
            "WHERE is_from_me=0 AND date > ? ORDER BY date DESC LIMIT 30",
            (cutoff_apple_ns,),
        ).fetchall()
    except sqlite3.OperationalError as e:
        print(f"query failed ({e}); grant Full Disk Access", file=sys.stderr)
        return None
    finally:
        con.close()

    for text, body, _ in rows:
        msg = text or _decode_attributed_body(body)
        if not msg or not CUE.search(msg):
            continue
        m = CODE.search(msg)
        if m:
            return m.group(1)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--within", type=int, default=300, help="max age of code, seconds")
    ap.add_argument("--wait", type=int, default=0, help="poll up to N seconds for a code")
    a = ap.parse_args()

    deadline = time.time() + a.wait
    while True:
        code = latest_code(a.within)
        if code:
            print(code)
            return 0
        if time.time() >= deadline:
            return 1
        time.sleep(3)


if __name__ == "__main__":
    sys.exit(main())
