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
- Documenting plugins with annotations (@Plugin, @Schema, @Metric)
- Building and publishing plugins to Maven Central
- Debugging plugin compilation or runtime errors
- Understanding Kestra plugin conventions and patterns

## Required inputs

- Plugin type (Task, Trigger, or Condition)
- Business logic description
- Target package name (e.g., `io.kestra.plugin.yourcompany`)
- Properties and outputs specification
- Whether testing is required

## Prerequisites

- Java 25+
- IntelliJ IDEA (enable annotation processors)
- Gradle build system (included with IDE)
- Use [plugin-template](https://github.com/kestra-io/plugin-template) to scaffold new plugins
- Kestra dependencies in build.gradle
- Lombok annotation processor configured (IntelliJ 2020.03+ includes it by default)

## Workflow

### Step 1 — Understand requirements

Clarify from the user message:
- What type of plugin to create (Task/Trigger/Condition)
- Input properties needed
- Expected outputs
- External systems to interact with
- Testing requirements

### Step 2 — Scaffold from plugin-template

Go to https://github.com/kestra-io/plugin-template, click **Use this template**, then:

```bash
git clone git@github.com:{{user}}/{{name}}.git
```

Directory structure:
```
plugin-name/
├── build.gradle
├── settings.gradle
├── gradle.properties          # kestraVersion, project version
├── src/
│   ├── main/
│   │   ├── java/io/kestra/plugin/yourcompany/
│   │   │   ├── package-info.java   # @PluginSubGroup annotation
│   │   │   └── YourTask.java
│   │   └── resources/
│   │       ├── icons/
│   │       │   ├── plugin-icon.svg
│   │       │   └── io.kestra.plugin.yourcompany.svg
│   │       └── metadata/
│   │           └── index.yaml
│   └── test/
│       ├── java/io/kestra/plugin/yourcompany/
│       │   └── YourTaskTest.java
│       └── resources/
│           ├── application.yml
│           └── flows/
│               └── your-flow.yaml
└── README.md
```

### Step 3 — Configure Gradle

**settings.gradle**: Set `rootProject.name = 'plugin-yourplugin'`

**build.gradle**: Set `group "io.kestra.plugin.yourcompany"`

Core dependency (compileOnly):
```groovy
compileOnly group: "io.kestra", name: "core", version: kestraVersion
```

Additional isolated dependencies (use `api` for isolation):
```groovy
api group: 'com.google.code.gson', name: 'gson', version: '2.8.6'
```

Plugin library version must align with your Kestra instance. Set in `gradle.properties`:
```properties
version=0.20.0-SNAPSHOT
kestraVersion=[0.20,)
```

### Step 4 — Implement the plugin

Apply all implementation rules below.

### Step 5 — Document the plugin

Add documentation annotations (@Plugin, @Schema, @Example, @Metric).

### Step 6 — Write tests

Create unit tests using @KestraTest pattern.

### Step 7 — Verify

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

### Task class structure (RunnableTask)

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
@Plugin(
    examples = {
        @Example(
            full = true,
            title = "Basic usage",
            code = """
                id: my_task
                namespace: company.team
                tasks:
                  - id: step1
                    type: io.kestra.plugin.yourcompany.YourTask
                    endpoint: "https://api.example.com"
                """
        )
    }
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
- Prefer `Property<T>` carrier type; use `@PluginProperty(dynamic = true)` ONLY when you need its metadata attributes (`group`, `hidden`, `internalStorageURI`) not available on `Property<T>`
- Validation annotations go on the inner type: `Property<@Min(1) Integer>`
- Render properties before use: `runContext.render(myProperty).as(String.class).orElse(null)`
- The `version` property is RESERVED for plugin management — never use it
- Default values: use `Property.ofValue(V)` (not `Property.of()` which is deprecated)

```java
@Schema(title = "The endpoint URL")
private Property<String> endpoint;

@Schema(title = "Timeout in seconds")
@Builder.Default
private Property<@Min(1) @Max(300) Integer> timeout = Property.ofValue(30);

@Schema(title = "List of tags")
private Property<List<String>> tags;

@Schema(
    title = "JSON configuration",
    anyOf = {String.class, Map.class}
)
private Property<Map<String, Object>> config;
```

#### Custom validation

You can create custom Jakarta validation annotations:

```java
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = { CronExpressionValidator.class })
public @interface CronExpression {
    String message() default "invalid cron expression ({validatedValue})";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

### Property rendering

Always render Property values before use in the run() method:

```java
// String property (required)
String rEndpoint = runContext.render(endpoint).as(String.class).orElseThrow();

// String property (optional with default)
String rEndpoint = runContext.render(endpoint).as(String.class).orElse("default");

// Integer property
Integer rTimeout = runContext.render(timeout).as(Integer.class).orElse(30);

// Duration property
Duration rDuration = runContext.render(duration).as(Duration.class).orElse(null);

// List property
List<String> rTags = runContext.render(tags).asList(String.class);

// Map property
Map<String, String> rConfig = runContext.render(config).asMap(String.class, String.class);

// JSON object as Map
Map<String, Object> rData = runContext.render(jsonProperty).asMap(String.class, Object.class);
```

### RunContext usage

```java
// Logging (REQUIRED - use runContext.logger(), not custom loggers)
Logger logger = runContext.logger();
logger.info("Processing started");

// Internal storage - reading files
final URI from = new URI(runContext.render(this.from).as(String.class).orElseThrow());
InputStream inputStream = runContext.storage().getFile(from);

// Internal storage - writing files (use workingDir for security sandbox)
File file = runContext.workingDir().createFile("output.csv");
// ... fill the file ...
URI uri = runContext.storage().putFile(file);

// If file may already exist, use createTempFile
File tempFile = runContext.workingDir().createTempFile(".csv");

// Metrics
runContext.metric(Counter.of("records.processed", count, "zone", "EU"));
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

Rules:
- Do NOT send back as outputs the same information you already have in properties
- Do NOT output the same information twice (e.g., status code and error code saying the same thing)
- If fetching data, use `Property<FetchType> fetchType` for FETCH_ONE, FETCH, or STORE

### Flowable Task

Flowable tasks are complex and usually only in Kestra core. When developing:
- Must be fault-tolerant (exceptions can endanger Kestra instance)
- Must have low CPU usage — evaluated frequently in the Executor
- No I/O should be done by flowable tasks

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
        Logger logger = conditionContext.getRunContext().logger();

        // Check condition
        if (!shouldTrigger()) {
            return Optional.empty();
        }

        // IMPORTANT: Free resources for next evaluation
        // Move the file or remove the record to avoid infinite triggering

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
        // Trigger output available via {{ trigger.* }} variables
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
        // Return a reactive Publisher that continuously emits Executions
        // Maintains a connection/subscription to external system
    }
}
```

### Condition implementation

```java
@SuperBuilder
@ToString
@EqualsAndHashCode
@Getter
@NoArgsConstructor
@Schema(title = "Condition for a specific flow")
@Plugin(
    examples = {
        @Example(
            full = true,
            code = {
                "- conditions:",
                "    - type: io.kestra.plugin.core.condition.FlowCondition",
                "      namespace: company.team",
                "      flowId: my-current-flow"
            }
        )
    }
)
public class FlowCondition extends Condition {
    @NotNull
    @Schema(title = "The namespace of the flow")
    public String namespace;

    @NotNull
    @Schema(title = "The flow ID")
    public String flowId;

    @Override
    public boolean test(ConditionContext conditionContext) {
        return conditionContext.getFlow().getNamespace().equals(this.namespace)
            && conditionContext.getFlow().getId().equals(this.flowId);
    }
}
```

ConditionContext exposes:
- `conditionContext.getFlow()`: the current flow
- `conditionContext.getExecution()`: the current execution (null for triggers)
- `conditionContext.getRunContext()`: a RunContext for rendering properties

## Documentation

### Plugin class documentation

Use `@Schema` for description and `@Plugin` for examples:

```java
@Schema(
    title = "Query a PostgreSQL server.",
    description = "Longer description of what this task does."
)
@Plugin(
    examples = {
        @Example(
            full = true,
            title = "Execute a query.",
            code = """
                id: query_postgres
                namespace: company.team
                tasks:
                  - id: query
                    type: io.kestra.plugin.jdbc.postgresql.Query
                    url: jdbc:postgresql://127.0.0.1:56982/
                    username: pg_user
                    password: "{{ secret('PG_PASSWORD') }}"
                    sql: select * from my_table
                    fetchType: FETCH
                """
        )
    },
    metrics = {
        @Metric(name = "length", type = Counter.TYPE),
        @Metric(name = "duration", type = Timer.TYPE)
    }
)
```

### Sub-group documentation (package-info.java)

Each sub-package needs a `package-info.java`:

```java
@PluginSubGroup(
    title = "BigQuery",
    description = "Tasks for accessing Google Cloud BigQuery.",
    categories = { PluginSubGroup.PluginCategory.DATABASE, PluginSubGroup.PluginCategory.CLOUD }
)
package io.kestra.plugin.gcp.bigquery;

import io.kestra.core.models.annotations.PluginSubGroup;
```

### Plugin icons

- Add SVG icons in `src/main/resources/icons/`
- Group icon: `plugin-icon.svg`
- Sub-group icon: `<package-name>.svg` (e.g., `io.kestra.plugin.aws.s3.svg`)
- Use `"{{ secret('YOUR_SECRET') }}"` in examples for sensitive info (API keys, passwords)

### Metrics documentation

Document metrics with `@Metric` annotation in `@Plugin`:

```java
@Plugin(
    metrics = {
        @Metric(name = "records.processed", type = Counter.TYPE),
        @Metric(name = "processing.duration", type = Timer.TYPE)
    }
)
```

Metric names must be lowercase with dots (e.g., `records.processed`).
Counter tags must be pairs: `Counter.of("name", count, "key1", "value1", "key2", "value2")`.

## Testing

### Unit test a RunnableTask

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

### Full flow testing with @ExecuteFlow

```java
@KestraTest(startRunner = true)
class YourFlowTest {
    @Test
    @ExecuteFlow("flows/your-flow.yaml")
    void flow(Execution execution) throws Exception {
        assertThat(execution.getState().getCurrent(), is(State.Type.SUCCESS));
        assertThat(execution.getTaskRunList(), hasSize(3));
    }
}
```

### Test application.yml (minimum config)

```yaml
kestra:
  repository:
    type: memory
  queue:
    type: memory
  storage:
    type: local
    local:
      base-path: /tmp/unittest
```

### Test dependencies in build.gradle

```groovy
testAnnotationProcessor group: "io.kestra", name: "processor", version: kestraVersion
testImplementation group: "io.kestra", name: "core", version: kestraVersion
testImplementation group: "io.kestra", name: "tests", version: kestraVersion
testImplementation group: "io.kestra", name: "repository-memory", version: kestraVersion
testImplementation group: "io.kestra", name: "runner-memory", version: kestraVersion
testImplementation group: "io.kestra", name: "storage-local", version: kestraVersion
```

### Testing best practices

- Prefer **Testcontainers** over Docker services in CI (less flakiness, less disk)
- If Testcontainers not suitable, use `.github/setup-unit.sh` + `docker-compose-ci.yml`
- Provide screenshots of local QA testing in PR description

## Build and publish

### Build

```bash
./gradlew shadowJar
```

JAR output: `build/libs/`

### Docker test image

```dockerfile
FROM kestra/kestra:develop
COPY build/libs/* /app/plugins/
```

```bash
./gradlew shadowJar && docker build -t kestra-custom . && docker run --rm -p 8080:8080 kestra-custom server local
```

### Publish to Maven Central

Configure `gradle.properties`:
```properties
sonatypeUsername=
sonatypePassword=
signing.keyId=
signing.password=
signing.secretKeyRingFile=
```

GitHub Actions workflow is included in plugin-template (`.github/workflows/main.yml`).

## Contribution guidelines

- PR title and commits follow [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/)
- Add `closes #ISSUE_ID` or `fixes #ISSUE_ID` in PR description
- Prefix rendered properties by `r` not `rendered` (e.g., `rHost`)
- Use `runContext.logger()` with appropriate log levels (DEBUG, INFO, WARN, ERROR)
- Use Kestra's internal HTTP client: `io.kestra.core.http.client`
- Use Jackson mappers from `io.kestra.core.serializers`
- Add `@JsonIgnoreProperties(ignoreUnknown = true)` on API response classes
- Every `runContext.metric(...)` must have a corresponding `@Metric` annotation
- Mandatory properties: use `@NotNull` and validate during rendering

## Guardrails

- NEVER use `@PluginProperty` for basic properties — always use `Property<T>` with `@Schema`
- NEVER create custom loggers — always use `runContext.logger()`
- NEVER store rendered values as instance fields — use local variables
- NEVER use `Property.of()` (deprecated) — use `Property.ofValue()`
- NEVER name any property `version` — it's reserved by Kestra
- NEVER use `@Schema` on Java enum types and their properties simultaneously
- ALWAYS include required Lombok annotations on Task/Trigger classes
- ALWAYS validate required business fields at run() entry point
- ALWAYS use `runContext.workingDir()` for file operations (security sandbox)
- ALWAYS return URIs from internal storage in outputs, not file contents
- ALWAYS use `runContext.workingDir().createTempFile()` if file may already exist
- When fetching data, ALWAYS provide `Property<FetchType> fetchType` property

## Example prompts

- "Use kestra-plugin to create a DataSyncTask that copies data between two S3 buckets"
- "Use kestra-plugin to implement a PollingTrigger that monitors a database table for new records"
- "Use kestra-plugin to write unit tests for my HTTP request task"
- "Help me debug this Kestra plugin — it compiles but fails at runtime with a serialization error"
- "Scaffold a new Kestra plugin module for integrating with our internal API"
- "Add documentation and metrics to my existing Kestra plugin"

## Reference documentation

- Plugin Developer Guide: https://kestra.io/docs/plugin-developer-guide
- Setup: https://kestra.io/docs/plugin-developer-guide/setup
- Contribution Guidelines: https://kestra.io/docs/plugin-developer-guide/contribution-guidelines
- Gradle Configuration: https://kestra.io/docs/plugin-developer-guide/gradle
- Task Development: https://kestra.io/docs/plugin-developer-guide/task
- Trigger Development: https://kestra.io/docs/plugin-developer-guide/trigger
- Condition Development: https://kestra.io/docs/plugin-developer-guide/condition
- Unit Testing: https://kestra.io/docs/plugin-developer-guide/unit-tests
- Documentation: https://kestra.io/docs/plugin-developer-guide/document
- Build & Publish: https://kestra.io/docs/plugin-developer-guide/publish
- Plugin Template: https://github.com/kestra-io/plugin-template
