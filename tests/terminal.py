#!/usr/bin/env python3
"""Exercise stock Readline/fzf and the real prompt through a temporary PTY."""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parents[1]
FZF = Path("/usr/share/fzf")
bash = shutil.which("bash")
version = subprocess.check_output([bash, "--noprofile", "--norc", "-c", "echo ${BASH_VERSINFO[0]}"], text=True)
if int(version) < 5 or not shutil.which("fzf") or not shutil.which("starship") or not (FZF / "key-bindings.bash").is_file():
    print("skip - PTY acceptance requires Bash 5, Starship and packaged fzf (covered by Arch CI)")
    raise SystemExit(0)

with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    (home / "selected file.txt").write_text("fixture")
    (home / "selected directory").mkdir()
    rc = home / "rc"
    rc.write_text(f'''source {shlex.quote(str(ROOT / "tests/fixtures/omarchy-4.0.0-alpha.bash"))}
source /usr/share/fzf/completion.bash
source /usr/share/fzf/key-bindings.bash
eval "$(starship init bash)"
source {shlex.quote(str(ROOT / "modules/bash/rc.bash"))}
HISTFILE="$HOME/history"
''')
    env = {key: value for key, value in os.environ.items() if key in ("PATH", "USER", "LOGNAME", "LANG")}
    env.update(HOME=str(home), TERM="xterm-256color", XDG_CONFIG_HOME=str(home / "config"),
               XDG_CACHE_HOME=str(home / "cache"), XDG_DATA_HOME=str(home / "data"),
               XDG_STATE_HOME=str(home / "state"), FZF_DEFAULT_OPTS="--height=10 --no-color --no-unicode --sync")
    pid, master = pty.fork()
    if pid == 0:
        os.chdir(home)
        os.execve(bash, [bash, "--noprofile", "--rcfile", str(rc), "-i"], env)
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))
    transcript = bytearray()
    pending = bytearray()

    def read_until(needle, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if needle in pending:
                end = pending.index(needle) + len(needle)
                output = bytes(pending[:end])
                del pending[:end]
                return output
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                pending.extend(chunk)
                transcript.extend(chunk)
                # Answer Readline's cursor-position query when emitted.
                if b"\x1b[6n" in chunk:
                    os.write(master, b"\x1b[1;1R")
        raise AssertionError(f"PTY did not emit {needle!r}: {bytes(transcript[-5000:])!r}")

    def send(text):
        os.write(master, text)

    try:
        read_until("❯".encode())
        send(b"printf '%s%s\\n' PTY- READY\n")
        read_until(b"PTY-READY\r\n")
        read_until("❯".encode())
        # Ordinary filename completion must quote spaces correctly.
        send(b"cat selected\\ f\t\n")
        read_until(b"fixture")
        # Force a new prompt marker rather than relying on output chunk boundaries.
        send(b"printf '%s%s\\n' TAB- DONE\n")
        read_until(b"TAB-DONE\r\n")
        read_until("❯".encode())
        # Ctrl-R selects the prior split-marker command and executes it.
        send(b"\x12PTY-")
        read_until(b"1/3")
        send(b"\r")
        read_until("❯".encode())
        send(b"\r")
        read_until(b"PTY-READY\r\n")
        read_until("❯".encode())
        # Ctrl-T inserts a selected filename, preserving whitespace.
        send(b"printf '<%s>\\n' \x14selected file")
        read_until(b"  1/")
        send(b"\r")
        read_until(b"selected\\ file.txt")
        send(b"\r")
        read_until(b"<selected file.txt>\r\n")
        read_until("❯".encode())
        # Alt-C enters a selected directory; cancellation then leaves Bash usable.
        send(b"\x1bcselected directory")
        read_until(b"  1/")
        send(b"\r")
        read_until("❯".encode())
        send(b"pwd\n")
        read_until((str(home / "selected directory") + "\r\n").encode())
        read_until("❯".encode())
        send(b"\x12")
        read_until(b"/", timeout=10)
        send(b"\x03")
        read_until("❯".encode())
        send(b"printf '%s%s\\n' CANCEL- DONE\n")
        read_until(b"CANCEL-DONE\r\n")
        send(b"exit\n")
    finally:
        os.close(master)
        try:
            os.kill(pid, signal.SIGHUP)
        except ProcessLookupError:
            pass
        os.waitpid(pid, 0)
print("ok - PTY Starship, Tab, fzf Ctrl-R/Ctrl-T/Alt-C, whitespace and cancellation")
