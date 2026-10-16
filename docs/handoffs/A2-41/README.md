# A2-41: report exhausted results-publication retries

Baseline: wip/week-plan 3619041d54705173d2074bfbe026086204d947c0.

Source review and executed supplemental Bash reproduction: all four failed git pushes currently end with a successful sleep, giving the loop exit 0. This falsely reports publication success. Proposed patch records successful push explicitly and exits 1 after exhausted retries, with the uploaded artifact name in the warning. Successful first/third attempts retain exit 0; final failed attempt does not sleep unnecessarily.

The step remains continue-on-error, with its existing six-minute bound. Required test gates and durable artifact uploads are unchanged. This is a reporting fix; it does not resolve the observed slow/hung Git upload. No extra CI dispatch or active source change.

Six mock-git checks executed: old all-fail returns 0; patched all-fail returns 1; first/third success returns 0 with exact attempt counts in both versions. Real GitHub runner execution pending. A3 owns integration; A1's Move/Undo investigation and A3's week fix are untouched.
