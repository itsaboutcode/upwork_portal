<!-- Copyright (c) 2026 Fortex Solutions. All rights reserved. -->

# Fortex repository policy reference

The companion JSON file is strict machine-readable configuration. Edit only
allowlisted advisory values; immutable safety and specialist controls remain fixed.

## Contents

- [Identity and schema](#identity-and-schema)
- [Activity logging](#activity-logging)
- [Workflow](#workflow)
- [Orchestration](#orchestration)
- [Model routing](#model-routing)
- [Enforcement](#enforcement)
- [Workflow profile behavior](#workflow-profile-behavior)

## Identity and schema

### `copyright`

- **Description:** Repository ownership notice retained by policy validation and audits without changing mandatory source-file notices. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"Copyright (c) 2026 Fortex Solutions. All rights reserved."`
- **Accepted values:** A non-empty printable string of at most 500 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Repository ownership notice retained by policy validation and audits without changing mandatory source-file notices.

### `schemaVersion`

- **Description:** Compatibility version used to reject unsupported policy shapes. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `1`
- **Accepted values:** The fixed plugin value `1`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Compatibility version used to reject unsupported policy shapes.

## Activity logging

### `activityLogging`

- **Description:** Settings consumed by the activity hook for bounded, redacted repository logs. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Settings consumed by the activity hook for bounded, redacted repository logs.

### `activityLogging.enabled`

- **Description:** Activity logging is disabled by default; set true to opt into repository-local persistence. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `false`
- **Accepted values:** `true` or `false`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Activity logging is disabled by default; set true to opt into repository-local persistence.

### `activityLogging.modelReportsEnabled`

- **Description:** Model-report persistence is independently disabled by default and also requires activity logging to be enabled. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `false`
- **Accepted values:** `true` or `false`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Model-report persistence is independently disabled by default and also requires activity logging to be enabled.

### `activityLogging.contentMode`

- **Description:** Available options: metadata, excerpt, or full; content-bearing modes stay redacted and bounded. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"metadata"`
- **Accepted values:** `"excerpt"`, `"full"`, `"metadata"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Available options: metadata, excerpt, or full; content-bearing modes stay redacted and bounded.

### `activityLogging.commandDetail`

- **Description:** Available options: category or summary; summaries stay redacted and bounded. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"category"`
- **Accepted values:** `"category"`, `"summary"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Available options: category or summary; summaries stay redacted and bounded.

### `activityLogging.maxContentCharacters`

- **Description:** Caps retained prompt or completion excerpt characters to limit exposure. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `500`
- **Accepted values:** Any integer from `0` through `8000` inclusive.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Caps retained prompt or completion excerpt characters to limit exposure.

### `activityLogging.retentionDays`

- **Description:** Controls how long active and rotated activity records are retained. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `90`
- **Accepted values:** Any integer from `1` through `3650` inclusive.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Controls how long active and rotated activity records are retained.

### `activityLogging.maxFileBytes`

- **Description:** Caps each active developer activity file before rotation occurs. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `2000000`
- **Accepted values:** Any integer from `256` through `50000000` inclusive.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Caps each active developer activity file before rotation occurs.

### `activityLogging.maxRotatedFiles`

- **Description:** Limits the number of rotated activity files retained per developer. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `5`
- **Accepted values:** Any integer from `0` through `100` inclusive.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Limits the number of rotated activity files retained per developer.

## Workflow

### `workflow`

- **Description:** Defaults consumed by workflow-profile selection and long-turn context guidance. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Defaults consumed by workflow-profile selection and long-turn context guidance.

### `workflow.defaultProfile`

- **Description:** Selects the advisory profile when no task-specific profile is stronger. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"standard"`
- **Accepted values:** `"compact"`, `"device"`, `"full"`, `"review"`, `"standard"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Selects the advisory profile when no task-specific profile is stronger.

### `workflow.turnCheckpointActions`

- **Description:** Controls when the non-blocking long-turn checkpoint is suggested. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `40`
- **Accepted values:** Any integer from `0` through `10000` inclusive.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Controls when the non-blocking long-turn checkpoint is suggested.

### `workflow.minimumProfiles`

- **Description:** Sets immutable context floors for recognized high-risk tasks before ordinary profile selection. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Sets immutable context floors for recognized high-risk tasks before ordinary profile selection.

### `workflow.minimumProfiles.security`

- **Description:** Uses full context for authentication, authorization, secrets, injection, dependencies, and other security boundaries. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"full"`
- **Accepted values:** The fixed plugin value `"full"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Uses full context for authentication, authorization, secrets, injection, dependencies, and other security boundaries.

### `workflow.minimumProfiles.migration`

- **Description:** Uses full context for schema or data changes, locking, backfills, constraints, reversibility, rollout, RLS, and tenant effects. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"full"`
- **Accepted values:** The fixed plugin value `"full"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Uses full context for schema or data changes, locking, backfills, constraints, reversibility, rollout, RLS, and tenant effects.

### `workflow.minimumProfiles.release`

- **Description:** Uses full context for compatibility, versioning, changelogs, packaging, validation, rollback, and publication or tag checkpoints. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"full"`
- **Accepted values:** The fixed plugin value `"full"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Uses full context for compatibility, versioning, changelogs, packaging, validation, rollback, and publication or tag checkpoints.

### `workflow.minimumProfiles.production`

- **Description:** Uses full context for reliability, monitoring, deployment sequencing, rollback, recovery, and operational impact. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"full"`
- **Accepted values:** The fixed plugin value `"full"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Uses full context for reliability, monitoring, deployment sequencing, rollback, recovery, and operational impact.

### `workflow.minimumProfiles.tenant`

- **Description:** Uses full context for tenant authorization, ownership, queries, indexes, RLS, logging, and cross-tenant leakage risks. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"full"`
- **Accepted values:** The fixed plugin value `"full"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Uses full context for tenant authorization, ownership, queries, indexes, RLS, logging, and cross-tenant leakage risks.

## Orchestration

### `orchestration`

- **Description:** Central configuration for optional task state, shell-free verification, evidence persistence, and workspace impact. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Central configuration for optional task state, shell-free verification, evidence persistence, and workspace impact.

### `orchestration.taskLedger`

- **Description:** Controls repository-local durable task-state persistence. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Controls repository-local durable task-state persistence.

### `orchestration.taskLedger.enabled`

- **Description:** Allows task-ledger creation and mutation only after explicit repository opt-in. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `false`
- **Accepted values:** `true` or `false`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Allows task-ledger creation and mutation only after explicit repository opt-in.

### `orchestration.verification`

- **Description:** Defines repository-owned shell-free checks and whether their metadata-only evidence may persist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Defines repository-owned shell-free checks and whether their metadata-only evidence may persist.

### `orchestration.verification.evidenceEnabled`

- **Description:** Allows verification results to create or update the repository evidence file. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `false`
- **Accepted values:** `true` or `false`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Allows verification results to create or update the repository evidence file.

### `orchestration.verification.requiredChecks`

- **Description:** Names checks required for repository readiness; source and coverage enforcement remains independently mandatory when applicable. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `[]`
- **Accepted values:** A list of unique non-empty check names.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Names checks required for repository readiness; source and coverage enforcement remains independently mandatory when applicable.

### `orchestration.verification.checks`

- **Description:** Maps check names to one argument array or an ordered sequence of argument arrays; shell strings are rejected. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** Named non-empty argument arrays or ordered sequences of argument arrays.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Maps check names to one argument array or an ordered sequence of argument arrays; shell strings are rejected.

### `orchestration.workspaceImpact`

- **Description:** Records whether an explicit workspace dependency graph is required for this repository. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Records whether an explicit workspace dependency graph is required for this repository.

### `orchestration.workspaceImpact.mode`

- **Description:** Uses notConfigured, required, or notApplicable to describe workspace-impact adoption. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"notConfigured"`
- **Accepted values:** `"notApplicable"`, `"notConfigured"`, `"required"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Uses notConfigured, required, or notApplicable to describe workspace-impact adoption.

### `orchestration.workspaceImpact.reason`

- **Description:** Explains why workspace impact is not applicable; required when that mode is selected. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `""`
- **Accepted values:** A value matching the default type: str.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Explains why workspace impact is not applicable; required when that mode is selected.

## Model routing

### `modelRouting`

- **Description:** Configured model selections consumed by task guidance; the plugin never silently changes the active model. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Configured model selections consumed by task guidance; the plugin never silently changes the active model.

### `modelRouting.enabled`

- **Description:** Enables or disables configured model-selection guidance without changing the active model. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `true`
- **Accepted values:** `true` or `false`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Enables or disables configured model-selection guidance without changing the active model.

### `modelRouting.codexRoot`

- **Description:** Configured Codex model selections for core, high-judgment, and routine work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Configured Codex model selections for core, high-judgment, and routine work.

### `modelRouting.codexRoot.core`

- **Description:** Selects the model and reasoning effort for ordinary production and core implementation. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Selects the model and reasoning effort for ordinary production and core implementation.

### `modelRouting.codexRoot.core.model`

- **Description:** Codex model selected for ordinary core implementation. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"gpt-5.6-terra"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Codex model selected for ordinary core implementation.

### `modelRouting.codexRoot.core.reasoning`

- **Description:** Reasoning effort selected for ordinary core implementation. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"medium"`
- **Accepted values:** `"high"`, `"low"`, `"max"`, `"medium"`, `"ultra"`, `"xhigh"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Reasoning effort selected for ordinary core implementation.

### `modelRouting.codexRoot.highJudgment`

- **Description:** Selects the model and reasoning effort for security, release, migration, and ambiguous work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Selects the model and reasoning effort for security, release, migration, and ambiguous work.

### `modelRouting.codexRoot.highJudgment.model`

- **Description:** Codex model selected for high-judgment work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"gpt-5.6-sol"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Codex model selected for high-judgment work.

### `modelRouting.codexRoot.highJudgment.reasoning`

- **Description:** Reasoning effort selected for high-judgment work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"high"`
- **Accepted values:** `"high"`, `"low"`, `"max"`, `"medium"`, `"ultra"`, `"xhigh"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Reasoning effort selected for high-judgment work.

### `modelRouting.codexRoot.routine`

- **Description:** Selects the model and reasoning effort for narrow, repetitive work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Selects the model and reasoning effort for narrow, repetitive work.

### `modelRouting.codexRoot.routine.model`

- **Description:** Codex model selected for routine work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"gpt-5.6-luna"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Codex model selected for routine work.

### `modelRouting.codexRoot.routine.reasoning`

- **Description:** Reasoning effort selected for routine work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"low"`
- **Accepted values:** `"high"`, `"low"`, `"max"`, `"medium"`, `"ultra"`, `"xhigh"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Reasoning effort selected for routine work.

### `modelRouting.codexSpecialists`

- **Description:** Repository-configurable Codex specialist recommendations for bounded documentation, Git, and test-generation tasks. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Repository-configurable Codex specialist recommendations for bounded documentation, Git, and test-generation tasks.

### `modelRouting.codexSpecialists.sourceDocumentation`

- **Description:** Recommends the Codex specialist for source-documentation work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Recommends the Codex specialist for source-documentation work.

### `modelRouting.codexSpecialists.sourceDocumentation.model`

- **Description:** Model used by the Codex source-documentation specialist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"gpt-5.6-luna"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Model used by the Codex source-documentation specialist.

### `modelRouting.codexSpecialists.sourceDocumentation.reasoning`

- **Description:** Reasoning effort used by the Codex source-documentation specialist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"low"`
- **Accepted values:** `"high"`, `"low"`, `"max"`, `"medium"`, `"ultra"`, `"xhigh"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Reasoning effort used by the Codex source-documentation specialist.

### `modelRouting.codexSpecialists.gitWorkflow`

- **Description:** Recommends the Codex specialist for Git-workflow work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Recommends the Codex specialist for Git-workflow work.

### `modelRouting.codexSpecialists.gitWorkflow.model`

- **Description:** Model used by the Codex Git-workflow specialist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"gpt-5.6-luna"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Model used by the Codex Git-workflow specialist.

### `modelRouting.codexSpecialists.gitWorkflow.reasoning`

- **Description:** Reasoning effort used by the Codex Git-workflow specialist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"low"`
- **Accepted values:** `"high"`, `"low"`, `"max"`, `"medium"`, `"ultra"`, `"xhigh"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Reasoning effort used by the Codex Git-workflow specialist.

### `modelRouting.codexSpecialists.testGeneration`

- **Description:** Recommends the Codex specialist for test-generation work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Recommends the Codex specialist for test-generation work.

### `modelRouting.codexSpecialists.testGeneration.model`

- **Description:** Model used by the Codex test-generation specialist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"gpt-5.6-luna"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Model used by the Codex test-generation specialist.

### `modelRouting.codexSpecialists.testGeneration.reasoning`

- **Description:** Reasoning effort used by the Codex test-generation specialist. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"medium"`
- **Accepted values:** `"high"`, `"low"`, `"max"`, `"medium"`, `"ultra"`, `"xhigh"`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Reasoning effort used by the Codex test-generation specialist.

### `modelRouting.claudeRoot`

- **Description:** Advisory Claude aliases for high-judgment and routine root work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Advisory Claude aliases for high-judgment and routine root work.

### `modelRouting.claudeRoot.highJudgment`

- **Description:** Claude model alias recommended for high-judgment work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"opus"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Claude model alias recommended for high-judgment work.

### `modelRouting.claudeRoot.routine`

- **Description:** Claude model alias recommended for routine work. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `"haiku"`
- **Accepted values:** A non-empty model label of at most 128 characters.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Claude model alias recommended for routine work.

### `modelRouting.claudeSpecialists`

- **Description:** Fixed Claude plugin agents and models for bounded specialist tasks; never overrideable. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Fixed Claude plugin agents and models for bounded specialist tasks; never overrideable.

### `modelRouting.claudeSpecialists.sourceDocumentation`

- **Description:** Assigns the fixed Claude source-documentation specialist. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Assigns the fixed Claude source-documentation specialist.

### `modelRouting.claudeSpecialists.sourceDocumentation.agent`

- **Description:** Claude plugin agent used for source-documentation work. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"fortex-codex:source-documenter"`
- **Accepted values:** The fixed plugin value `"fortex-codex:source-documenter"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Claude plugin agent used for source-documentation work.

### `modelRouting.claudeSpecialists.sourceDocumentation.model`

- **Description:** Claude model used by the source-documentation specialist. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"haiku"`
- **Accepted values:** The fixed plugin value `"haiku"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Claude model used by the source-documentation specialist.

### `modelRouting.claudeSpecialists.gitWorkflow`

- **Description:** Assigns the fixed Claude Git-workflow specialist. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Assigns the fixed Claude Git-workflow specialist.

### `modelRouting.claudeSpecialists.gitWorkflow.agent`

- **Description:** Claude plugin agent used for Git-workflow work. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"fortex-codex:git-assistant"`
- **Accepted values:** The fixed plugin value `"fortex-codex:git-assistant"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Claude plugin agent used for Git-workflow work.

### `modelRouting.claudeSpecialists.gitWorkflow.model`

- **Description:** Claude model used by the Git-workflow specialist. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"haiku"`
- **Accepted values:** The fixed plugin value `"haiku"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Claude model used by the Git-workflow specialist.

### `modelRouting.claudeSpecialists.testGeneration`

- **Description:** Assigns the fixed Claude test-generation specialist. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Assigns the fixed Claude test-generation specialist.

### `modelRouting.claudeSpecialists.testGeneration.agent`

- **Description:** Claude plugin agent used for test-generation work. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"fortex-codex:test-generator"`
- **Accepted values:** The fixed plugin value `"fortex-codex:test-generator"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Claude plugin agent used for test-generation work.

### `modelRouting.claudeSpecialists.testGeneration.model`

- **Description:** Claude model used by the test-generation specialist. This field is fixed by the plugin and cannot be changed by repository policy.
- **Default:** `"sonnet"`
- **Accepted values:** The fixed plugin value `"sonnet"`.
- **Repository override:** No; plugin-owned and immutable.
- **Effect during code generation:** Claude model used by the test-generation specialist.

## Enforcement

### `enforcement`

- **Description:** Contains the repository-configurable prompt-time plan gate; mandatory safety, evidence, review, and documentation controls remain plugin-owned. Every other child value remains fixed by the plugin.
- **Default:** Object; see the documented child defaults below.
- **Accepted values:** An object containing only the documented child keys.
- **Repository override:** Partially; only `enforcement.planApprovalRequired` is repository-configurable.
- **Effect during code generation:** Contains the repository-configurable prompt-time plan gate; mandatory safety, evidence, review, and documentation controls remain plugin-owned.

### `enforcement.planApprovalRequired`

- **Description:** Requires explicit plan approval before repository mutation when enabled; repositories may disable only this prompt-time gate. Repository overrides are accepted only when they satisfy the documented value constraints.
- **Default:** `true`
- **Accepted values:** `true` or `false`.
- **Repository override:** Yes; validated and bounded.
- **Effect during code generation:** Requires explicit plan approval before repository mutation when enabled; repositories may disable only this prompt-time gate.

## Workflow profile behavior

`workflow.defaultProfile` is the fallback for ordinary work when no explicit
profile or stronger task-specific recommendation applies. The default `standard`
profile provides balanced read, plan, write, review, and verify guidance for
normal code generation. Profiles change loaded engineering context, not authority
or permission to perform protected actions.

| Profile | Code-generation purpose |
| --- | --- |
| `compact` | Focused context for narrow implementation: read, plan, write, and verify. |
| `review` | Focused read, plan, and engineering-review context without a write-oriented profile. |
| `standard` | Balanced specification-driven context for ordinary implementation and maintenance. |
| `device` | Specialized Flutter, emulator, simulator, TV, pairing, and physical-device validation context. |
| `full` | Comprehensive specification, testing, security, review, and verification context for high-risk work. |

## Profile selection order

1. A recognized high-risk minimum is applied first.
2. Otherwise, an explicit supported developer profile is used.
3. Otherwise, task, model-tier, and client-surface evidence recommends a profile.
4. When ordinary recommendation resolves to `standard`, `defaultProfile` supplies
   the repository fallback.

## Turn checkpoints

`workflow.turnCheckpointActions` controls the non-blocking reminder interval for
long sessions. The default `40` suggests reconciling the approved to-do list,
verification evidence, blockers, completed work, and remaining work after roughly
40 meaningful actions. `0 disables` this reminder. It never stops generation or
creates new approval by itself.

## Minimum profile categories

Each `workflow.minimumProfiles` value is an immutable high-risk minimum. A value
of `full` is a comprehensive context floor with these distinct purposes:

- `security`: authentication, authorization, secrets, injection, dependency, and
  other security-boundary analysis.
- `migration`: schema and data safety, locks, backfills, constraints, reversibility,
  staged rollout, RLS, and tenant effects.
- `release`: compatibility, semantic versioning, changelogs, packaging, validation,
  rollback, and separate publication or tag checkpoints.
- `production`: reliability, monitoring, deployment sequencing, rollback, recovery,
  and operational-impact analysis.
- `tenant`: tenant authorization, ownership, queries, indexes, RLS, logging, and
  cross-tenant leakage prevention.

A stronger profile does not authorize deployment and does not authorize migration execution.
It does not authorize release publication and does not authorize tagging.
It does not authorize production access and does not authorize bypass approval or any
other checkpoint.
