# Agent workflow

For each task:

1. Read the root `AGENTS.md` and the relevant pages linked from [INDEX.md](INDEX.md).
2. Inspect the implementation, relevant files, and current Git status; preserve existing changes.
3. Identify the smallest useful change. For nontrivial work, state assumptions and a brief plan.
4. Implement within the requested scope and established conventions.
5. Run relevant available checks and report their actual results.
6. Review the diff for regressions, unnecessary complexity, and security or privacy issues.
7. Update the relevant docs when verified facts or behavior change; leave unknowns marked TBD.
8. Report changes, verification, limitations, and remaining tasks. Use [HANDOVER.md](HANDOVER.md) for a session or agent transfer.

## Parallel work
- Give each agent a specific task and explicit file or interface scope.
- Avoid concurrent edits to the same files; assign ownership of shared files and interfaces first.
- Inspect another agent's changes and results before relying on or integrating them.
- Integrate and verify the combined changes before reporting completion.
- Use parallel work only when the available tooling supports it and the work can be safely separated.

## Knowledge maintenance
Put stable, verified facts needed by future work in the appropriate wiki page. Keep task-specific progress, transient findings, and next actions in the active task or handover. Avoid duplicate rules and facts; link to the canonical page. Remove obsolete statements only when their replacement is verified.

When the project owner points to another project's wiki as a reference, inspect its relevant pages before updating this wiki. Adapt useful documentation structure and workflow, but do not import project facts or assumptions that have not been verified for this project.

For substantive project claims, preserve provenance and limits: record the date, source, scope, and whether the item is an owner decision, observation, proposal, open question, or verified result. Keep current status concise and link to supporting research rather than duplicating it.
