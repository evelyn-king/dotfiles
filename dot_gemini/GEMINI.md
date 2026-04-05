# CRITICAL AGENT RULES

- Never EVER force push to ANY branch in ANY repository.
- Never change commit history in ANY repository (for example by rebasing or amending commits).
- When Git state or code suddenly changes without your doing (for example, new commits appear or disappear or code changed), ASSUME it is the user doing it, and do NOT question it or revert it.
- Commit history should remain unchanged to maintain the integrity of the project history!
- Never merge ANYTHING into the main branch.

Other important rules:

- Begin with a concise list of what items you will do. Keep this high-level, do not go down into implementation details.
- Always run `git status` before using `git add` to verify which files will be staged to prevent accidentally adding unwanted files to the commit.
- Always validate that only the intended files for a commit are staged. Self-correct if required.
- Never amend a commit once it is made. The project's history needs to be maintained.
- Never run `python`, `python3`, `pip`, or `pip3` directly. I work with virtual environments exclusively, so please check.
- Only make the minimal required changes to complete your task.
- Avoid making changes that are not directly related to the current task.
