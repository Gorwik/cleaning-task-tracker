### Development Workflow & Rules

This is a strict, mandatory workflow. Each step must be followed precisely. Do not proceed to the next step without explicit user approval at the verification gates.

#### Phase 1: Mandatory Research & Planning

**This phase must be completed in full before any code is written or analyzed.**

1.  **Define Requirements (The "What"):**
    *   Clarify the precise business requirements for the feature.
    *   Break down the feature into a step-by-step implementation roadmap.
    *   **Action:** Update the `README.md` file with this plan.

2.  **Build Knowledge Base (The "How"):**
    *   **Prerequisite:** This is a mandatory, deep-dive research step.
    *   **Action:** Use the `GoogleSearch` tool to conduct thorough research.
    *   **Source Priority:** Your research must prioritize sources in this order:
        1.  **Official Documentation** (e.g., postgrest.org, postgresql.org, hub.docker.com)
        2.  **Official or acknowledged GitHub Repositories** containing examples.
    *   **Content Requirement:** The research must produce **concrete code examples** that are directly applicable to the task.
    *   **Action:** Synthesize this research and the examples into the "Knowledge Base" section in `README.md`.
    *   **Stuck?** If, after a thorough search, you cannot find sufficient information or clear examples, **STOP** and ask the user for help.

3.  **USER VERIFICATION GATE:**
    *   **STOP.**
    *   **Action:** Announce that Phase 1 is complete and present the gathered Knowledge Base to the user for review.
    *   **Action:** Ask for explicit approval to proceed (e.g., "Is this knowledge base sufficient? May I proceed to the next step?").
    *   **DO NOT** move to Phase 2 without a "yes" or equivalent confirmation from the user.

#### Phase 2: Implementation Cycle (Test-Driven)

This cycle should be followed for *one feature at a time*.

1.  **Write Tests First:** Before implementing the feature's logic, write the corresponding automated tests based on the test design from Phase 1.
2.  **Implement Feature Code:** Write the minimum amount of code necessary to make the newly created tests pass.
3.  **User Verification:** After the initial implementation, pause and ask for user verification of the approach and the code.
4.  **Run All Tests:** Execute the *entire* test suite to ensure the new code passes its own tests and has not introduced any regressions.
    *   **If all tests pass:** The feature is considered complete. Proceed to the next feature.
    *   **If tests fail:** Proceed to Phase 3.
5.  **USER VERIFICATION GATE:**
    *   **STOP.**
    *   **Action:** Announce that Phase 2 is complete and present the code changes and test results.
    *   **Action:** Ask for explicit approval to proceed.
    *   **DO NOT** move to the next phase without approval.

#### Phase 3: Troubleshooting & Code Quality

1.  **Isolate Failures:** If multiple tests fail, focus on fixing them *one at a time*. Start with the test most directly related to the new code.
2.  **Iterate Carefully:** Make targeted changes to the code to fix the failing test.
3.  **Prevent Regressions:** After each change, run the entire test suite again. If the change causes previously passing tests to fail, **revert the change immediately**. Discuss the problem with the user to find a better solution.
4.  **Handle Persistent Failures:** If a test fails repeatedly (e.g., 2-3 attempts) without a clear path to resolution, **stop**. Do not attempt random changes. Explain the issue to the user and ask for guidance.
5.  **Maintain Code Quality:** Avoid making superficial or nonsensical changes, such as arbitrarily renaming variables. All code changes must have a clear purpose.