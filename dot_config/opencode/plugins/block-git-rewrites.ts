import type { Plugin } from "@opencode-ai/plugin";

export const BlockGitRewrites: Plugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;
      const command = output.args.command;
      if (!command) return;

      // Format input like Claude Code's protocol and call the existing hook
      const hookInput = JSON.stringify({
        tool_name: "Bash",
        tool_input: { command },
      });

      try {
        await $`echo ${hookInput} | python3 ~/.claude/hooks/block-git-rewrites.py`.quiet();
      } catch (e: any) {
        // Exit code 2 is the Claude protocol's "blocked", with the reason on
        // stderr. Throwing is what stops the tool call. An earlier version
        // built this string and discarded it as an unused expression, so every
        // violation was detected and then allowed straight through.
        if (e.exitCode === 2) {
          throw new Error(
            e.stderr?.toString().trim() || "Blocked by git safety hook",
          );
        }

        // Anything else means the hook could not run at all, either because
        // python3 is missing or because ~/.claude/hooks was never deployed.
        // Warn rather than throw. The Python hooks also fail open on unexpected
        // errors, and a missing interpreter should not make every bash command
        // unusable. Flip this to a throw if you would rather fail closed.
        console.warn(
          `block-git-rewrites: hook did not run (${e.message ?? e}); command allowed.`,
        );
      }
    },
  };
};
