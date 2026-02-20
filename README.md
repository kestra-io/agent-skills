# Kestra Agent Skills

A curated collection of agent skills for operating Kestra environments.


## Available skill

### kestra-ops

Operate Kestra using `kestractl` for flow, execution, namespace, and namespace-file operations.

**Use when:**
- Validating or deploying flows
- Triggering executions and checking status
- Managing namespaces and `nsfiles`
- Configuring or switching CLI contexts

**Covers:**
- Context and auth setup (`config add`, `config use`, `config show`)
- Read and inspection flows (`flows list/get`, `executions get`, `namespaces list`)
- Safe write operations (`flows deploy`, `nsfiles upload/delete`)
- Operational guardrails for production and automation output

Skill path: `skills/kestra-ops/SKILL.md`

## Usage

Load the skill and provide a concrete operational objective.

Examples:

```text
Use kestra-ops to validate and deploy all flows in ./flows to prod.namespace with fail-fast.
```

```text
Use kestra-ops to run my-flow in my.namespace, wait for completion, and summarize the result.
```

## Structure

```
.
├── README.md
└── skills/
    └── kestra-ops/
        └── SKILL.md
```

## Contributing

- Add each skill as `skills/<skill-name>/SKILL.md`.
- Include purpose, trigger conditions, required inputs, workflow, guardrails, and example prompts.
- Keep commands copy-pasteable and production-safe.
