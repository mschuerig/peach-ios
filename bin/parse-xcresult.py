#!/usr/bin/env python3
"""Parse xcresult bundle and print failed test details with failure messages."""

import json
import subprocess
import sys
import os


def find_latest_xcresult(derived_data_path):
    """Find the most recent .xcresult directory in the test logs."""
    test_log_dir = os.path.join(derived_data_path, "Logs", "Test")
    if not os.path.isdir(test_log_dir):
        print(f"Test log directory not found: {test_log_dir}", file=sys.stderr)
        sys.exit(1)

    xcresults = sorted([
        os.path.join(test_log_dir, d)
        for d in os.listdir(test_log_dir)
        if d.endswith(".xcresult") and os.path.isdir(os.path.join(test_log_dir, d))
    ])
    if not xcresults:
        print("No .xcresult bundles found", file=sys.stderr)
        sys.exit(1)
    return xcresults[-1]


def get_test_results(xcresult_path):
    """Use xcrun xcresulttool to get test results JSON."""
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", xcresult_path],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"xcresulttool error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout)


def collect_all_results(nodes, path=""):
    """Recursively collect ALL result values from leaf nodes."""
    results = set()
    for node in nodes:
        name = node.get("name", "")
        current_path = f"{path}/{name}" if path else name
        result = node.get("result", "")
        children = node.get("children", [])

        if children:
            results.update(collect_all_results(children, current_path))
        else:
            results.add(result)

    return results


def collect_failures(nodes, path=""):
    """Recursively find all leaf-level non-Passed nodes."""
    failures = []
    for node in nodes:
        name = node.get("name", "")
        current_path = f"{path}/{name}" if path else name
        result = node.get("result", "").lower()
        children = node.get("children", [])

        if children:
            failures.extend(collect_failures(children, current_path))
        elif result != "passed":
            failures.append({
                "path": current_path,
                "result": node.get("result", ""),
                "node": node
            })

    return failures


def main():
    xcresult_path = None
    for arg in sys.argv[1:]:
        xcresult_path = arg

    derived_data_root = os.path.expanduser("~/Library/Developer/Xcode/DerivedData")
    peach_dirs = sorted([
        os.path.join(derived_data_root, d)
        for d in os.listdir(derived_data_root)
        if d.startswith("Peach-") and os.path.isdir(os.path.join(derived_data_root, d))
    ], key=os.path.getmtime, reverse=True)
    if not peach_dirs:
        print("No Peach DerivedData directory found", file=sys.stderr)
        sys.exit(1)
    derived_data = peach_dirs[0]
    if not xcresult_path:
        xcresult_path = find_latest_xcresult(derived_data)

    print(f"Parsing: {os.path.basename(xcresult_path)}")
    data = get_test_results(xcresult_path)

    test_nodes = data.get("testNodes", [])

    # Show all unique result values
    all_results = collect_all_results(test_nodes)
    print(f"Unique result values: {all_results}")

    failures = collect_failures(test_nodes)

    if not failures:
        print("All tests passed.")
        return

    print(f"\n{len(failures)} non-passing test(s):\n")
    for f in failures:
        print(f"  [{f['result']}] {f['path']}")
        node = f["node"]
        for key, val in node.items():
            if key in ("name", "nodeType", "result", "nodeIdentifier", "nodeIdentifierURL"):
                continue
            if isinstance(val, str):
                print(f"    {key}: {val}")
            elif isinstance(val, list):
                for item in val:
                    print(f"    {key}: {json.dumps(item)[:400]}")
            elif isinstance(val, dict):
                print(f"    {key}: {json.dumps(val)[:400]}")
        print()


if __name__ == "__main__":
    main()
