#!/usr/bin/env python3
"""Static integrity checks for local Supabase database and Storage tests."""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATABASE_DIR = ROOT / "supabase" / "tests" / "database"
STORAGE_TEST = ROOT / "supabase" / "tests" / "storage" / "payment_proofs_storage_test.py"
MIGRATION = ROOT / "supabase" / "migrations" / "20260715192117_secure_platform_schema.sql"
CLOUD_REFS = {
    "zegjqwsv" + "saprnguvxuwk",
    "txxokpov" + "dbvsvnkpbrrp",
}
SECRET_PATTERNS = {
    "JWT-like token": re.compile(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"),
    "Supabase secret key": re.compile(r"sb_secret_[A-Za-z0-9_-]{12,}"),
    "Supabase service key": re.compile(r"service_role\s*[=:]\s*['\"][A-Za-z0-9._-]{20,}", re.I),
}
ASSERTION = re.compile(
    r"(?im)^\s*select\s+(?:\*\s+from\s+)?"
    r"(ok|is|isnt|cmp_ok|results_eq|results_ne|throws_ok|throws_like|"
    r"lives_ok|dies_ok|has_table|has_column|has_type|has_index|"
    r"col_type_is|col_is_pk|col_is_unique|fk_ok|policy_cmd_is|rls_enabled)\s*\("
)
PLAN = re.compile(r"(?im)^\s*select\s+plan\((\d+)\)\s*;")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_sql(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    if not re.search(r"(?im)^\s*begin\s*;", text):
        fail(f"{path}: missing begin")
    if not re.search(r"(?im)^\s*select\s+\*\s+from\s+finish\(\)\s*;", text):
        fail(f"{path}: missing finish()")
    if not re.search(r"(?im)^\s*rollback\s*;\s*$", text):
        fail(f"{path}: missing final rollback")
    plans = PLAN.findall(text)
    if len(plans) != 1:
        fail(f"{path}: expected exactly one plan(), found {len(plans)}")
    actual = len(ASSERTION.findall(text))
    expected = int(plans[0])
    if expected != actual:
        fail(f"{path}: plan({expected}) but found {actual} assertions")
    if re.search(r"(?i)\b(skip|todo)\b", text):
        fail(f"{path}: permanent skip/TODO marker is not allowed")
    return actual


def validate_storage_case_count() -> int:
    tree = ast.parse(STORAGE_TEST.read_text(encoding="utf-8"), filename=str(STORAGE_TEST))
    run_method = next(
        (
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.FunctionDef) and node.name == "run"
        ),
        None,
    )
    if run_method is None:
        fail(f"{STORAGE_TEST}: run() not found")
    count = sum(
        1
        for node in ast.walk(run_method)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr in {"expect", "expect_status"}
    )
    if count != 25:
        fail(f"{STORAGE_TEST}: expected 25 reported HTTP cases, found {count}")
    return count


def validate_repository_content() -> None:
    checked = list(DATABASE_DIR.glob("*.sql")) + [STORAGE_TEST, MIGRATION, Path(__file__)]
    for path in checked:
        text = path.read_text(encoding="utf-8")
        for ref in CLOUD_REFS:
            if ref in text:
                fail(f"{path}: cloud project ref is forbidden in local tests")
        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(text):
                fail(f"{path}: possible {label} committed")
        for email in re.findall(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+", text):
            if not email.endswith("@test.invalid"):
                fail(f"{path}: non-test email found: {email}")


def main() -> int:
    sql_files = sorted(DATABASE_DIR.glob("*.test.sql"))
    expected_names = [
        "010_schema.test.sql",
        "020_grants_rls.test.sql",
        "030_orders.test.sql",
        "040_admin_transitions.test.sql",
        "050_storage_policies.test.sql",
    ]
    if [path.name for path in sql_files] != expected_names:
        fail("database test file set is incomplete or unexpectedly changed")
    counts = {path.name: validate_sql(path) for path in sql_files}
    storage_count = validate_storage_case_count()
    validate_repository_content()
    for name, count in counts.items():
        print(f"OK {name}: {count} pgTAP assertions")
    print(f"OK payment_proofs_storage_test.py: {storage_count} HTTP cases")
    print(f"OK total pgTAP assertions: {sum(counts.values())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
