# ForEach / ForEachItem / Each* → Loop

Official guide: `https://kestra.io/docs/migration-guide/v2.0.0/foreach-loop` · best practices: `https://kestra.io/docs/best-practices/loop`

All four iteration types — `ForEach`, `ForEachItem`, `EachSequential`, `EachParallel` — are removed in 2.0 and **fail to parse**. The replacement is `io.kestra.plugin.core.flow.Loop`: each iteration is an isolated sub-execution, `item` is reachable from any nesting depth, and post-loop outputs must be declared.

## Expression mapping

| 1.x expression | Loop equivalent | Note |
|---|---|---|
| `taskrun.value` | `item.value` | |
| `taskrun.iteration` | `item.index` | zero-based in both |
| `parent.taskrun.value` | `item.value` | no prefix needed at any depth (incl. inside `If`/`Parallel`) |
| `parents[0].taskrun.value` | `item.parent.value` | only inside the inner of two nested Loops; inside a nested flowable within one Loop use `item.value` |
| `parents[n].taskrun.value` | `item.parents[n].value` | |
| `outputs.task_id[taskrun.value].value` | `outputs.task_id.value` | inside the iteration — outputs are scoped to the sub-execution |
| `outputs.each_id[value].field` (after the loop) | `outputs.loop_id.outputs[n].outputs.<id>` or `loopOutputs(outputs.loop_id.outputs, '<id>')` | key-by-value access is gone; declare outputs (below) |

`item.value` is always a **string** when list elements aren't plain strings — use `fromJson(item.value).field`, never `item.value.field`.

## Pattern mapping

| 1.x pattern | 2.0 replacement |
|---|---|
| `ForEach` / `EachSequential` / `EachParallel` | `Loop` (same shape; `concurrencyLimit`: 1 = sequential default, N = bounded, 0 = unlimited) |
| `ForEach` + `If`/`Parallel` inside | `Loop` + same flowables — update expressions only |
| `ForEach` > `AllowFailure` > tasks | `Loop` with `transmitFailed: false`; drop the `AllowFailure` wrapper. Also new: `errors:` (per failed iteration) and `finally:` (once after all iterations) |
| `ForEachItem` | see the decision below |
| `subflowOutputs` | declared `outputs: [{id, type, value}]` on the Loop |
| built-in batch aggregation | compose explicitly after the loop: `Concat` + transform `Aggregate` |

## Post-loop outputs — always ask when the loop's results are consumed downstream

Declare `outputs:` on the Loop and pick `fetchType`:

| `fetchType` | Downstream access | Use for |
|---|---|---|
| `AUTO` (default) | STORE when `values` is a URI, FETCH otherwise | general |
| `FETCH` | `outputs.<loop_id>.outputs` in-memory list | small iteration counts |
| `STORE` | `outputs.<loop_id>.uri` internal-storage file | large iteration counts |

```yaml
- id: loop
  type: io.kestra.plugin.core.flow.Loop
  values: ["a", "b", "c"]
  outputs:
    - id: result
      type: STRING
      value: "{{ outputs.process.value }}"
  tasks:
    - id: process
      type: io.kestra.plugin.core.debug.Return
      format: "processed {{ item.value }}"
- id: summary
  type: io.kestra.plugin.core.log.Log
  message: "{{ loopOutputs(outputs.loop.outputs, 'result') }} in {{ outputs.loop.iterationCount }} iterations"
```

## ForEachItem — ask, then pick one of two options

**Ask the user per flow:** do the batches need isolated execution — their own retries, their own logs, independently restartable?

**Option A — inline (default when the child logic can live inline):** `Loop` with `values: "{{ inputs.file }}"`. A **single internal-storage URI iterates line-by-line** through the file; a **list of URIs** iterates over the elements. Child tasks go inline; no subflow.

**Option B — isolated per-batch (when isolation is needed or a child flow already exists):** `Split` → `Loop` → `Subflow`:

```yaml
- id: split
  type: io.kestra.plugin.core.storage.Split
  from: "{{ inputs.file }}"
  rows: 100
- id: per_batch
  type: io.kestra.plugin.core.flow.Loop
  values: "{{ outputs.split.uris }}"
  concurrencyLimit: 4
  fetchType: FETCH
  outputs:
    - id: result_uri
      type: STRING
      value: "{{ outputs.run_child.outputs.uri }}"
  tasks:
    - id: run_child
      type: io.kestra.plugin.core.flow.Subflow
      namespace: company.team
      flowId: process_batch
      wait: true
      transmitFailed: true
      inputs:
        batch_uri: "{{ item.value }}"
- id: concat
  type: io.kestra.plugin.core.storage.Concat
  files: "{{ loopOutputs(outputs.per_batch.outputs, 'result_uri') }}"
  extension: .ion
```

The child flow surfaces results via flow-level `outputs:`. For reduce-style aggregation, the canonical map-reduce shape is `Split` → `Loop[Filter/Aggregate per chunk]` → `Concat` → final `Aggregate`.
