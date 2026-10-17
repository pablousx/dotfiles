# Global development agents

Rulesync is the source of truth. Developer is the primary session, defined in
`ai/.rulesync/rules/developer.md`; Coder and Tester are defined in
`ai/.rulesync/subagents/{coder,tester}.md`. No additional skill, orchestrator,
daemon, worktree manager or production integration is installed.

## Editing and generation

Edit canonical Markdown, then run from the checkout on Linux or macOS:

```sh
rtk ./scripts/sync-ai.sh --dry-run
rtk ./scripts/sync-ai.sh
```

The existing pinned mise toolset supplies Python and Rulesync. Codex must be
installed separately. The wrapper runs Rulesync's dry run, generates in a
temporary HOME, checks all paths and conflicts, then installs global rules,
skills and only `~/.codex/agents/coder.toml` and `tester.toml`. It preserves
unrelated agents, local edits, symlinks, MCP, authentication and permissions
using the existing refusal and ownership rules. A conflict stops all installation;
reconcile the canonical source and existing content before retrying. With
`delete: false`, deleting a source does not remove an installed agent.
`df up`/`df down` continue to use this same wrapper on opted-in machines.

Do not edit generated TOML. Keep shared role instructions provider agnostic;
put optional harness-specific settings in frontmatter. To configure a role's
model, add the following block to its canonical Markdown, replacing the model
placeholder with an identifier verified in your current harness/account:

```yaml
codexcli:
  model: "<verified available model ID>"
  model_reasoning_effort: medium
```

The placeholder is documentation, not a usable model. Choose a reasoning level
supported by that model/client. Omitting both settings inherits the parent;
this is the committed default. A standalone agent's explicit settings override
spawn-time values, so remove them to choose a model dynamically. These fields
do not change the primary model, provider or credentials. Switching providers
is not a capability of a native Codex agent definition.

## Running the workflow

Open a new Codex or T3 Code session after generation so it loads the global
instructions and discovers the agents. For example:

> Implement this feature using coder, wait for the result, then ask a separate
> tester to verify the original acceptance criteria independently. Coordinate
> fixes and report the final checks and remaining limitations.

Developer scopes the task and supplies original requirements and acceptance
criteria. It waits for Coder, then starts Tester independently with the actual
diff/files and relevant commands. Findings go back to Developer, who delegates
corrections to Coder and requests another independent validation. Simple tasks
stay in the main session. Children do not delegate; normally only one runs at
a time. In Codex CLI, `/subagents` inspects spawned sessions; natural language
requests invoke the roles, rather than an invented `/coder` command.

For a small smoke test, ask Coder for a clamp function as text, wait, then give
Tester the actual function plus criteria: below/inside/above bounds and invalid
bounds. Request named native agents explicitly and have them report IDs. This
needs no repository edits, test data or installations.

T3 Code may expose a different child-task interface from native Codex tools.
Use named native agents when the interface supports them. Otherwise read the
generated agent's `developer_instructions` and include them explicitly in the
T3 delegated task: naming a task “Coder” or “Tester” alone does not load a role.
Use `orchestrator_capabilities` to check the live provider/model catalog,
`delegate_task` for a child and `task_status` to await its result. Each independent
review round uses a new task with the original brief and unresolved findings.
Do not use top-level thread creation as a substitute for a subagent.

For an alternative Tester model in T3, select an available compatible model
from that live catalog on the Tester child only. Native Codex can select a
compatible model using its per-agent frontmatter above. If unavailable, keep
the inherited model and disclose that independent validation used the same
model in a separate session. Do not alter authentication to enable a model.

## Safety and compatibility

Role instructions do not create technical permission boundaries. Codex children
inherit the parent's current permissions and MCP access; Tester’s no-edit rule
is behavioral, not a separate read-only sandbox. Use disposable data and mocks;
never run tests that can modify production data. No Auditor or production access
is configured. Existing Codex permission settings remain authoritative.

Verified baseline: Rulesync 37.0.0 emits Codex's documented standalone TOML
format. Installed Codex CLI 0.163.0 already enables native delegation, so no
global config change or experimental flag is needed. Current Codex documentation uses
`agents.enabled` (default true); on a machine that explicitly disables delegation,
review that local setting instead of silently overriding it during sync.
Do not add legacy `[agents.coder]` registrations or unverified feature flags.

The sync code uses the existing cross-platform Python/mise wrapper and adds no
OS-specific commands. macOS execution still requires validation on a Mac.
Older Codex versions may require an upgrade before recognizing standalone agents.

References: [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[Rulesync file formats](https://rulesync.dyoshikawa.com/reference/file-formats),
[Rulesync global mode](https://rulesync.dyoshikawa.com/guide/global-mode).

## Validation on this machine

- Linux: real Rulesync dry run and generation succeeded in a temporary HOME;
  the reviewed wrapper then installed global instructions and both agents.
  Generated TOML parses with the required fields and no model override.
- The 18 offline preservation tests and six repository synchronization tests
  passed. Dry-run checks include unchanged contents and modification times.
- Codex `debug prompt-input` loaded the generated global instructions. A
  standalone ephemeral CLI smoke run completed the clamp exercise in two
  sequential child sessions. Its JSON events expose waits and reported child
  IDs, but do not establish that the named TOML roles were selected: this
  harness exposes `collaboration.spawn_agent` without an `agent_type` selector.
  Native named-role selection remains a manual check in a client exposing it;
  do not interpret the smoke run as proof of per-agent model overrides.
- T3's live catalog supports Codex children and an alternative compatible
  model. The implementation was delegated to a Coder child and awaited before
  an independent Tester review using a different available model. Roles were
  supplied in the task brief, rather than assuming automatic TOML loading.
  Tester reproduced a generated directory-symlink validation gap; Coder fixed
  it and added a regression test. A fresh independent Tester session confirmed
  the fix and all 24 preservation/repository tests, with no remaining finding.
- The subsequent merge resolution retained shared `--tools` and removed the
  conflicting duplicate runtime installer. The complete AI suite now passes
  19 tests (18 preservation plus interactive setup), repository synchronization
  passes six, and omasync passes 41. Whitespace, Bash syntax and ShellCheck pass;
  `make check` passes the preceding suites but stops because `zsh` is not
  installed on this host. Zsh syntax/startup, plugin bundle regeneration,
  macOS execution, interactive
  `/subagents` display and automatic named-role loading in T3 remain unverified.
