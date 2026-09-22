#!/usr/bin/env python3
"""Emit metadata for a Dev migration plan, never state values or an apply approval."""
import argparse
import hashlib
import json
import re
from pathlib import Path


def summarize(plan, revision, stack):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full source revision is required")
    if stack not in {"api", "campaign-processing"}:
        raise ValueError("Unsupported stack")
    if plan.get("errored") or plan.get("complete") is not True:
        raise ValueError("The plan is not complete")
    variables = {k: v.get("value") for k, v in plan.get("variables", {}).items()}
    if [variables.get(k) for k in ("environment", "aws_region", "project_name")] != ["dev", "us-east-1", "trustcheckradar"]:
        raise ValueError("Only the existing Dev project is allowed")
    selected = bool(variables.get("research_consent_migration_deployment")) if stack == "api" else variables.get("research_consent_migration") is True
    changes = []
    for resource in plan.get("resource_changes", []):
        if resource.get("mode") != "managed" or resource["change"]["actions"] == ["no-op"]:
            continue
        changes.append({"address": resource["address"], "actions": resource["change"]["actions"]})
    # Hash all plan contents privately; this identifies this observation only.
    # It is deliberately not a digest that grants permission to apply later.
    digest = hashlib.sha256(json.dumps(plan, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"revision": revision, "environment": "dev", "stack": stack,
            "candidateSelected": selected, "planSha256": digest,
            "changes": changes, "applyAuthorizedByThisReport": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--stack", required=True)
    args = parser.parse_args()
    print(json.dumps(summarize(json.loads(args.plan.read_text()), args.revision, args.stack), indent=2))
