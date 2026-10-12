#!/usr/bin/env python3
# git merge driver：把环境层（tools/exam-check 的 NORMALIZE 表）喂给 git，
# 让「上游值 vs 我的环境值」在 merge 时不算冲突。
# 接线：tools/setup-merge-driver（写 git config）+ .gitattributes 的 `* merge=normalize`。
import importlib.machinery
import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent / "exam-check"


def load():
    loader = importlib.machinery.SourceFileLoader("exam_check_merge", str(TOOL))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


M = load()


def norm(data):
    if b"\x00" in data:
        return data
    text = data.decode("utf-8", errors="surrogateescape")
    for old, new in M.NORMALIZE:
        text = text.replace(old, new)
    return text.encode("utf-8", errors="surrogateescape")


def main():
    base, ours, theirs = sys.argv[1], sys.argv[2], sys.argv[3]
    blobs = [Path(p).read_bytes() for p in (base, ours, theirs)]
    if any(b"\x00" in b for b in blobs):
        r = subprocess.run(["git", "merge-file", "-p", ours, base, theirs], capture_output=True)
    else:
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "base").write_bytes(norm(blobs[0]))
            (d / "ours").write_bytes(norm(blobs[1]))
            (d / "theirs").write_bytes(norm(blobs[2]))
            r = subprocess.run(
                [
                    "git",
                    "merge-file",
                    "-p",
                    "-L",
                    "ours",
                    "-L",
                    "base",
                    "-L",
                    "theirs",
                    str(d / "ours"),
                    str(d / "base"),
                    str(d / "theirs"),
                ],
                capture_output=True,
            )
    Path(ours).write_bytes(r.stdout)
    return 0 if r.returncode == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
