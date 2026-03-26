---
name: kestra-plugin
description: Develop custom Kestra plugins (Tasks, Triggers, Conditions) in Java with correct annotations, patterns, and testing. Use when users ask to create, scaffold, or implement Kestra plugins, or need guidance on plugin development best practices, Lombok annotations, Property types, RunContext usage, or @KestraTest unit tests.
---

# Kestra Plugin Development Skill

Use this skill to develop production-ready custom Kestra plugins following official conventions.

## When to use

Use this skill when the request includes:
- Creating a new Kestra plugin module or scaffolding plugin structure
- Implementing custom Tasks (RunnableTask or FlowableTask)
- Implementing custom Triggers (PollingTriggerInterface or RealtimeTriggerInterface)
- Implementing custom Conditions
- Writing unit tests with @KestraTest
- Debugging plugin compilation or runtime errors
- Understanding Kestra plugin conventions and patterns

## Required inputs

- Plugin type (Task, Trigger, or Condition)
- Business logic description
- Target package name (e.g., `io.kestra.plugin.yourcompany`)
- Properties and outputs specification
- Whether testing is required

## Prerequisites

- Java 21+
- Gradle build system
- Kestra dependencies in build.gradle
- Lombok annotation processor configured

## Workflow

### Step 1 — Understand requirements

Clarify from the user message:
- What type of plugin to create (Task/Trigger/Condition)
- Input properties needed
- Expected outputs
- External systems to interact with
- Testing requirements

### Step 2 — Create plugin structure

Follow the standard Kestra plugin module structure:

```
plugin-name/
├── build.gradle
├── src/
│   ├── main/java/io/kestra/plugin/yourcompany/
│   │   └── YourTask.java
│   └── test/java/io/kestra/plugin/yourcompany/
│       └── YourTaskTest.java
└── README.md
```

### Step 3 — Implement the plugin

Apply all implementation rules below.

### Step 4 — Write tests

Create unit tests using @KestraTest pattern.

### Step 5 — Verify

Run `./gradlew test` to ensure compilation and tests pass.

## Implementation rules

### Class annotations (REQUIRED)

Every Task or Trigger class MUST have these Lombok annotations:

```java
@SuperBuilder
@ToString
@EqualsAndHashCode
@Getter
@NoArgsConstructor
```

These are required for Kestra serialization and plugin discovery.

### Task class structure

```java
@SuperBuilder
@ToString
@EqualsAndHashCode
@Getter
@NoArgsConstructor
@Schema(
    title = "Task title",
    description = "Task description"
)
public class YourTask extends Task implements RunnableTask<YourTask.Output> {
    // Properties here
    
    @Override
    public YourTask.Output run(RunContext runContext) throws Exception {
        // Implementation here
    }
    
    @Builder
    @Getter
    public static class Output implements io.kestra.core.models.tasks.Output {
        // Output properties here
    }
}
```

### Properties

- ALL input properties MUST use `Property<T>` type
- ALL properties MUST have `@Schema` annotation for documentation
- DO NOT use `@PluginProperty` annotation (deprecated)
- Validation annotations go on the inner type: `Property<@Min(1) Integer>`
- Render properties before use: `runContext.render(myProperty).as(String.class).orElse(null)`
- The `version` property is RESERVED for plugin management — never use it

```java
@Schema(title = "The endpoint URL")
private Property<String> endpoint;

@Schema(title = "Timeout in seconds")
@Builder.Default
private Property<@Min(1) @Max(300) Integer> timeout = Property.ofValue(30);

@Schema(title = "List of tags")
private Property<List<String>> tags;
```

### Property rendering

Always render Property values before use in the run() method:

```java
// String property
String rEndpoint = runContext.render(endpoint).as(String.class).orElseThrow();

// Integer property  
Integer rTimeout = runContext.render(timeout).as(Integer.class).orElse(30);

// List property
List<String> rTags = runContext.render(tags).asList(String.class);

// Map property
Map<String, String> rConfig = runContext.render(config).asMap(String.class, String.class);
```

### RunContext usage

```java
// Logging (REQUIRED - use runContext.logger(), not custom loggers)
Logger logger = runContext.logger();
logger.info("Processing started");

// Internal storage - reading files
InputStream inputStream = runContext.storage().getFile(uri);

// Internal storage - writing files
File file = runContext.workingDir().createFile("output.csv");
URI uri = runContext.storage().putFile(file);

// Metrics
runContext.metric(Counter.of("records.processed", count));
runContext.metric(Timer.of("processing.duration", duration));
```

### Outputs

Outputs are metadata, NOT data storage. Use internal storage URIs for data:

```java
@Builder
@Getter
public static class Output implements io.kestra.core.models.tasks.Output {
    @Schema(title = "Number of records processed")
    private final Integer recordCount;
    
    @Schema(title = "URI of the output file")
    private final URI outputUri;
}
```

For tasks with no output, use `VoidOutput`:

```java
public class NoOutputTask extends Task implements RunnableTask<VoidOutput> {
    @Override
    public VoidOutput run(RunContext runContext) throws Exception {
        // Do work
        return null;
    }
}
```

### Trigger implementation

#### Polling Trigger

```java
@SuperBuilder
@ToString
@EqualsAndHashCode
@Getter
@NoArgsConstructor
public class YourTrigger extends AbstractTrigger 
    implements PollingTriggerInterface, TriggerOutput<YourTrigger.Output> {
    
    @Builder.Default
    private final Duration interval = Duration.ofSeconds(60);
    
    @Override
    public Optional<Execution> evaluate(ConditionContext conditionContext, TriggerContext context) {
        RunContext runContext = conditionContext.getRunContext();
        
        // Check condition
        if (!shouldTrigger()) {
            return Optional.empty();
        }
        
        // Create execution with trigger output
        Execution execution = Execution.builder()
            .id(runContext.getTriggerExecutionId())
            .namespace(context.getNamespace())
            .flowId(context.getFlowId())
            .flowRevision(context.getFlowRevision())
            .state(new State())
            .trigger(ExecutionTrigger.of(this, Output.builder()...build()))
            .build();
            
        return Optional.of(execution);
    }
    
    @Builder
    @Getter
    public static class Output implements io.kestra.core.models.tasks.Output {
        // Trigger output properties
    }
}
```

#### Realtime Trigger

```java
@SuperBuilder
@ToString
@EqualsAndHashCode
@Getter
@NoArgsConstructor
public class YourRealtimeTrigger extends AbstractTrigger 
    implements RealtimeTriggerInterface, TriggerOutput<YourRealtimeTrigger.Output> {
    
    @Override
    public Publisher<Execution> evaluate(ConditionContext conditionContext, TriggerContext triggerContext) {
        // Return a reactive Publisher that emits Executions
    }
}
```

### Testing

Use @KestraTest annotation for all tests:

```java
@KestraTest
class YourTaskTest {
    @Inject
    private RunContextFactory runContextFactory;
    
    @Test
    void run() throws Exception {
        RunContext runContext = runContextFactory.of(Map.of("variable", "value"));
        
        YourTask task = YourTask.builder()
            .endpoint(Property.ofValue("https://api.example.com"))
            .build();
            
        YourTask.Output output = task.run(runContext);
        
        assertThat(output.getRecordCount(), is(100));
    }
}
```

For full flow testing:

```java
@KestraTest(startRunner = true)
class YourFlowTest {
    @Test
    @ExecuteFlow("flows/your-flow.yaml")
    void flow(Execution execution) throws Exception {
        assertThat(execution.getState().getCurrent(), is(State.Type.SUCCESS));
    }
}
```

Test dependencies in build.gradle:

```groovy
testAnnotationProcessor group: "io.kestra", name: "processor", version: kestraVersion
testImplementation group: "io.kestra", name: "core", version: kestraVersion
testImplementation group: "io.kestra", name: "tests", version: kestraVersion
testImplementation group: "io.kestra", name: "repository-memory", version: kestraVersion
testImplementation group: "io.kestra", name: "runner-memory", version: kestraVersion
testImplementation group: "io.kestra", name: "storage-local", version: kestraVersion
```

## Guardrails

- NEVER use `@PluginProperty` — always use `Property<T>` with `@Schema`
- NEVER create custom loggers — always use `runContext.logger()`
- NEVER store rendered values as instance fields — use local variables
- NEVER use `Property.of()` (deprecated) — use `Property.ofValue()`
- NEVER name any property `version` — it's reserved by Kestra
- ALWAYS include required Lombok annotations on Task/Trigger classes
- ALWAYS validate required business fields at run() entry point
- ALWAYS use `runContext.workingDir()` for file operations (security sandbox)
- ALWAYS return URIs from internal storage in outputs, not file contents

## Example prompts

- "Use kestra-plugin to create a DataSyncTask that copies data between two S3 buckets"
- "Use kestra-plugin to implement a PollingTrigger that monitors a database table for new records"
- "Use kestra-plugin to write unit tests for my HTTP request task"
- "Help me debug this Kestra plugin — it compiles but fails at runtime with a serialization error"
- "Scaffold a new Kestra plugin module for integrating with our internal API"

## Reference documentation

- Plugin Developer Guide: https://kestra.io/docs/plugin-developer-guide
- Task Development: https://kestra.io/docs/plugin-developer-guide/task
- Trigger Development: https://kestra.io/docs/plugin-developer-guide/trigger
- Unit Testing: https://kestra.io/docs/plugin-developer-guide/unit-tests
- Plugin Template: https://github.com/kestra-io/plugin-template
