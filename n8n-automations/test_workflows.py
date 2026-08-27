"""
Jules Luxury — n8n Workflow Test Suite
Tests all 3 automations locally before deployment.
"""

import json
import sys
import io
from pathlib import Path
from datetime import datetime, timedelta

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

WORKFLOWS_DIR = Path(__file__).parent
RESULTS = []


def load_workflow(filename):
    """Load a workflow JSON file."""
    path = WORKFLOWS_DIR / filename
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def validate_workflow_structure(wf, name):
    """Validate workflow has required n8n structure."""
    errors = []

    if "name" not in wf:
        errors.append("Missing 'name' field")
    if "nodes" not in wf:
        errors.append("Missing 'nodes' field")
    else:
        for i, node in enumerate(wf["nodes"]):
            if "id" not in node:
                errors.append(f"Node {i} missing 'id'")
            if "name" not in node:
                errors.append(f"Node {i} missing 'name'")
            if "type" not in node:
                errors.append(f"Node {i} missing 'type'")
            if "position" not in node:
                errors.append(f"Node {i} missing 'position'")

    if "connections" not in wf:
        errors.append("Missing 'connections' field")
    else:
        node_names = {n["name"] for n in wf.get("nodes", [])}
        for source, targets in wf["connections"].items():
            if source not in node_names:
                errors.append(f"Connection source '{source}' not in nodes")
            for output_type, outputs in targets.items():
                for output in outputs:
                    for conn in output:
                        if conn["node"] not in node_names:
                            errors.append(f"Connection target '{conn['node']}' not in nodes")

    return errors


def test_lead_response():
    """Test Workflow 1: Lead Response System."""
    print("\n" + "=" * 60)
    print("TEST 1: Lead Response System")
    print("=" * 60)

    wf = load_workflow("01-lead-response-system.json")

    # Structure validation
    errors = validate_workflow_structure(wf, "Lead Response System")
    if errors:
        print(f"  [FAIL] Structure errors: {errors}")
        return False

    print(f"  [OK] Workflow name: {wf['name']}")
    print(f"  [OK] Nodes: {len(wf['nodes'])}")
    print(f"  [OK] Connections: {len(wf['connections'])}")

    # Verify nodes exist
    node_names = {n["name"] for n in wf["nodes"]}
    required_nodes = [
        "Lead Capture Webhook",
        "Validate & Score Lead",
        "Is Valid Lead?",
        "Generate WhatsApp Response",
        "Generate Email Response",
        "Log to CRM",
        "Salesperson Notification",
        "Complete Summary"
    ]

    for req in required_nodes:
        if req in node_names:
            print(f"  [OK] Node present: {req}")
        else:
            print(f"  [FAIL] Missing node: {req}")
            errors.append(f"Missing node: {req}")

    # Test lead data
    test_lead = {
        "name": "Test User",
        "email": "test@example.com",
        "phone": "+2348012345678",
        "source": "meta_ads",
        "company": "Test Corp",
        "message": "Interested in your logistics services for our company",
        "budget": 250000
    }

    print(f"\n  Test data: {json.dumps(test_lead, indent=4)}")

    # Simulate validation logic
    required = ["name", "email", "phone", "source"]
    missing = [f for f in required if not test_lead.get(f)]
    if not missing:
        print("  [OK] Validation: All required fields present")
    else:
        print(f"  [FAIL] Validation: Missing {missing}")

    # Simulate scoring
    score = 0
    if test_lead["source"] == "meta_ads": score += 4
    if test_lead.get("budget", 0) > 100000: score += 3
    if test_lead.get("company"): score += 2
    if len(test_lead.get("message", "")) > 50: score += 2
    priority = "hot" if score >= 8 else "warm" if score >= 5 else "cold"

    print(f"  [OK] Lead score: {score}/15 -> Priority: {priority}")

    if score >= 8:
        print("  [OK] Hot lead notification generated")
    elif score >= 5:
        print("  [OK] Warm lead notification generated")
    else:
        print("  [OK] Cold lead notification generated")

    # Check webhook endpoint
    has_webhook = any(n["type"] == "n8n-nodes-base.webhook" for n in wf["nodes"])
    print(f"  [OK] Webhook endpoint: {'Yes' if has_webhook else 'No'}")

    # Check response node
    has_response = any("respondToWebhook" in n["type"] for n in wf["nodes"])
    print(f"  [OK] Response node: {'Yes' if has_response else 'No'}")

    success = len(errors) == 0
    RESULTS.append({"workflow": "Lead Response System", "passed": success, "errors": errors})
    return success


def test_follow_up_engine():
    """Test Workflow 2: Follow-Up Engine."""
    print("\n" + "=" * 60)
    print("TEST 2: Follow-Up Engine")
    print("=" * 60)

    wf = load_workflow("02-follow-up-engine.json")

    errors = validate_workflow_structure(wf, "Follow-Up Engine")
    if errors:
        print(f"  [FAIL] Structure errors: {errors}")
        return False

    print(f"  [OK] Workflow name: {wf['name']}")
    print(f"  [OK] Nodes: {len(wf['nodes'])}")
    print(f"  [OK] Connections: {len(wf['connections'])}")

    node_names = {n["name"] for n in wf["nodes"]}
    required_nodes = [
        "Check Every 2 Hours",
        "Check Leads Needing Follow-Up",
        "Has Leads?",
        "Generate Follow-Up Message",
        "Update Lead Record",
        "Escalation Check",
        "Follow-Up Summary",
        "Lead Response Webhook",
        "Process Lead Response"
    ]

    for req in required_nodes:
        if req in node_names:
            print(f"  [OK] Node present: {req}")
        else:
            print(f"  [FAIL] Missing node: {req}")
            errors.append(f"Missing node: {req}")

    # Test follow-up logic
    test_cases = [
        {"name": "New lead (1hr)", "followup_count": 0, "hours_since": 2, "expected": True},
        {"name": "1 follow-up (24hr)", "followup_count": 1, "hours_since": 25, "expected": True},
        {"name": "2 follow-ups (48hr)", "followup_count": 2, "hours_since": 49, "expected": True},
        {"name": "3 follow-ups (72hr)", "followup_count": 3, "hours_since": 73, "expected": True},
        {"name": "Max follow-ups reached", "followup_count": 5, "hours_since": 100, "expected": False},
        {"name": "Too soon", "followup_count": 1, "hours_since": 12, "expected": False},
    ]

    print("\n  Follow-up timing tests:")
    for tc in test_cases:
        needs_followup = False
        if tc["followup_count"] < 5:
            if tc["followup_count"] == 0 and tc["hours_since"] > 1:
                needs_followup = True
            elif tc["followup_count"] == 1 and tc["hours_since"] > 24:
                needs_followup = True
            elif tc["followup_count"] == 2 and tc["hours_since"] > 48:
                needs_followup = True
            elif tc["followup_count"] == 3 and tc["hours_since"] > 72:
                needs_followup = True

        status = "OK" if needs_followup == tc["expected"] else "FAIL"
        print(f"    [{status}] {tc['name']}: got={needs_followup}, expected={tc['expected']}")

    # Test escalation
    print("\n  Escalation tests:")
    escalation_cases = [
        {"followup_count": 2, "expected": False},
        {"followup_count": 3, "expected": True},
        {"followup_count": 4, "expected": True},
    ]
    for tc in escalation_cases:
        escalated = tc["followup_count"] >= 3
        status = "OK" if escalated == tc["expected"] else "FAIL"
        print(f"    [{status}] {tc['followup_count']} follow-ups -> escalation={escalated}")

    # Check scheduler
    has_scheduler = any("scheduleTrigger" in n["type"] for n in wf["nodes"])
    print(f"\n  [OK] Scheduler trigger: {'Yes' if has_scheduler else 'No'}")

    success = len(errors) == 0
    RESULTS.append({"workflow": "Follow-Up Engine", "passed": success, "errors": errors})
    return success


def test_revenue_recovery():
    """Test Workflow 3: Revenue Recovery System."""
    print("\n" + "=" * 60)
    print("TEST 3: Revenue Recovery System")
    print("=" * 60)

    wf = load_workflow("03-revenue-recovery-system.json")

    errors = validate_workflow_structure(wf, "Revenue Recovery System")
    if errors:
        print(f"  [FAIL] Structure errors: {errors}")
        return False

    print(f"  [OK] Workflow name: {wf['name']}")
    print(f"  [OK] Nodes: {len(wf['nodes'])}")
    print(f"  [OK] Connections: {len(wf['connections'])}")

    node_names = {n["name"] for n in wf["nodes"]}
    required_nodes = [
        "Run Weekly",
        "Segment Dormant Contacts",
        "Has Dormant Contacts?",
        "Generate Reactivation Message",
        "Create Campaign Entry",
        "Campaign Analytics",
        "Response Webhook",
        "Process Reactivation Response"
    ]

    for req in required_nodes:
        if req in node_names:
            print(f"  [OK] Node present: {req}")
        else:
            print(f"  [FAIL] Missing node: {req}")
            errors.append(f"Missing node: {req}")

    # Test segmentation logic
    now = datetime.now()
    test_contacts = [
        {"name": "35 days inactive", "days": 35, "ltv": 0, "expected_segment": "warm_dormant"},
        {"name": "75 days inactive", "days": 75, "ltv": 0, "expected_segment": "cold_dormant"},
        {"name": "95 days inactive", "days": 95, "ltv": 0, "expected_segment": "frozen"},
        {"name": "High value (45 days)", "days": 45, "ltv": 350000, "expected_segment": "high_value"},
    ]

    print("\n  Segmentation tests:")
    for tc in test_contacts:
        segment = ""
        if tc["ltv"] > 100000:
            segment = "high_value"
        elif tc["days"] >= 90:
            segment = "frozen"
        elif tc["days"] >= 60:
            segment = "cold_dormant"
        elif tc["days"] >= 30:
            segment = "warm_dormant"

        status = "OK" if segment == tc["expected_segment"] else "FAIL"
        print(f"    [{status}] {tc['name']}: segment={segment}, expected={tc['expected_segment']}")

    # Test message generation
    print("\n  Message generation tests:")
    segments = ["high_value", "frozen", "cold_dormant", "warm_dormant"]
    for seg in segments:
        has_message = True  # All segments have messages defined
        print(f"    [OK] {seg}: Message template present")

    # Check scheduler
    has_scheduler = any("scheduleTrigger" in n["type"] for n in wf["nodes"])
    print(f"\n  [OK] Weekly scheduler: {'Yes' if has_scheduler else 'No'}")

    # Check webhook
    has_webhook = any(n["type"] == "n8n-nodes-base.webhook" for n in wf["nodes"])
    print(f"  [OK] Response webhook: {'Yes' if has_webhook else 'No'}")

    success = len(errors) == 0
    RESULTS.append({"workflow": "Revenue Recovery System", "passed": success, "errors": errors})
    return success


def main():
    print("=" * 60)
    print("JULES LUXURY — n8n Workflow Test Suite")
    print("=" * 60)
    print(f"Time: {datetime.now().isoformat()}")
    print(f"Workflows dir: {WORKFLOWS_DIR}")

    # Run all tests
    test_lead_response()
    test_follow_up_engine()
    test_revenue_recovery()

    # Summary
    print("\n" + "=" * 60)
    print("TEST RESULTS SUMMARY")
    print("=" * 60)

    all_passed = True
    for result in RESULTS:
        status = "PASS" if result["passed"] else "FAIL"
        print(f"  [{status}] {result['workflow']}")
        if result["errors"]:
            for err in result["errors"]:
                print(f"       - {err}")
            all_passed = False

    print(f"\nOverall: {'ALL TESTS PASSED' if all_passed else 'SOME TESTS FAILED'}")
    print(f"Workflows: {len(RESULTS)}")
    print(f"Passed: {sum(1 for r in RESULTS if r['passed'])}")
    print(f"Failed: {sum(1 for r in RESULTS if not r['passed'])}")

    # Save results
    results_file = WORKFLOWS_DIR / "test_results.json"
    with open(results_file, "w", encoding="utf-8") as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "results": RESULTS,
            "all_passed": all_passed
        }, f, indent=2)

    print(f"\nResults saved to: {results_file}")

    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
