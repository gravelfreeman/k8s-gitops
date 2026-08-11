@.agents/instructions/sorting.md

# AGENTS.md

Global guardrails for AI agents working in this Talos, Kubernetes, and Flux GitOps repo.

## Repository Map

```
k8s-gitops
├── bootstrap ──────────── operator-driven bootstrap resources
├── kubernetes ─────────── primary flux/kubernetes manifests
│   ├── apps ───────────── app and platform workloads by domain
│   │   ├── core
│   │   ├── media
│   │   ├── services
│   │   ├── system
│   │   └── utils
│   ├── components ─────── reusable app components
│   │   ├── cnpg
│   │   ├── common
│   │   ├── dragonfly
│   │   └── volsync
│   └── flux ───────────── flux cluster-level wiring
│       ├── cluster
│       └── repositories
└── talos ──────────────── talos machine config
```

## Safety

- Do not print secrets in clear text.
- Do not run Git operations.

Without the user's explicit authorization;

- Do not run Flux operations that modify live cluster state.
- Do not modify generated or sensitive artifacts.
- Do not run destructive operations or alter persistent state, versions, storage, ingress, or backups.

## Editing

- Keep edits surgical and localized.
- No hacks, workarounds, or outdated methods; use clean modern patterns.
- Use `.agents/skills/add-app/SKILL.md` for app-specific workflows.

## Communication

- State assumptions when repository context is ambiguous.
- Flag risky infrastructure changes before making them.
- If a request conflicts with these safety rules, stop and ask.
