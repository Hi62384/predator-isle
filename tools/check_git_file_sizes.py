"""Check the staged Git snapshot before committing (no dependencies required)."""
import subprocess
import sys

LIMIT = 50 * 1024 * 1024


def main():
    paths = subprocess.check_output(["git", "ls-files", "--stage", "-z"])
    oversized = []
    seen = set()
    largest = (0, "")
    for entry in paths.split(b"\0"):
        if not entry:
            continue
        metadata, path = entry.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        if stage != b"0":
            print("Resolve merge conflicts before checking file sizes.", file=sys.stderr)
            return 1
        if mode == b"160000" or oid in seen:
            continue
        seen.add(oid)
        size = int(subprocess.check_output(["git", "cat-file", "-s", oid.decode()]))
        name = path.decode("utf-8", errors="replace")
        largest = max(largest, (size, name))
        if size > LIMIT:
            oversized.append((size, name))
    for size, name in sorted(oversized, reverse=True):
        print(f"TOO LARGE: {size / 1024**2:.2f} MiB {name}")
    if oversized:
        print("Stage the size-reduction changes and update any unpublished commits containing these files.")
        return 1
    print(f"PASS: all staged files <= 50 MiB; largest {largest[0] / 1024**2:.2f} MiB {largest[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
