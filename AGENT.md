# 🤖 AEM Feature Agent — Universal Pipeline

## How to Use

### First-Time Setup (once per project)
```bash
cd <your-aem-project-root>
bash .agent/universal/setup.sh
```
This scans your project and generates `.agent/project.yaml` with all project-specific values.

### Running the Agent
```
@workspace Read the files `.agent/AGENT.md`, `.agent/REPO_CONTEXT.md`, and `.agent/project.yaml` fully.
Then execute all 8 steps described in the agent pipeline for this feature request:

FEATURE: "<Describe your feature here>"

Do NOT stop until the Final Report (Step 8) is generated.
```

---

## 🧠 Operating Mode

You are a **Senior AEM Developer + DevOps + QA** agent.

**CRITICAL — Before doing ANYTHING, read `.agent/project.yaml` fully.** Every path, package name, component group, and command in this file uses values from `project.yaml`. When you see `{{something}}`, look it up in `project.yaml`.

### Variable Resolution Rules

All `{{placeholders}}` in this file and `REPO_CONTEXT.md` are resolved from `project.yaml`:

| Placeholder | YAML Path | Example Value |
|---|---|---|
| `{{project.artifactId}}` | `project.artifactId` | `mysite` |
| `{{java.basePackage}}` | `java.basePackage` | `com.mycompany.core` |
| `{{java.basePackagePath}}` | `java.basePackagePath` | `com/mycompany/core` |
| `{{jcr.appsRoot}}` | `jcr.appsRoot` | `/apps/mysite` |
| `{{jcr.contentRoot}}` | `jcr.contentRoot` | `/content/mysite` |
| `{{jcr.confRoot}}` | `jcr.confRoot` | `/conf/mysite` |
| `{{jcr.contentLangRoot}}` | `jcr.contentLangRoot` | `/content/mysite/us/en` |
| `{{jcr.testPagesRoot}}` | `jcr.testPagesRoot` | `/content/mysite/us/en/test-pages` |
| `{{jcr.componentPath}}` | `jcr.componentPath` | `/apps/mysite/components` |
| `{{jcr.clientlibPath}}` | `jcr.clientlibPath` | `/apps/mysite/clientlibs` |
| `{{components.group}}` | `components.group` | `My Site - Content` |
| `{{components.resourceTypeBase}}` | `components.resourceTypeBase` | `mysite/components` |
| `{{components.pageResourceType}}` | `components.pageResourceType` | `mysite/components/page` |
| `{{components.containerResourceType}}` | `components.containerResourceType` | `mysite/components/container` |
| `{{components.pageTemplate}}` | `components.pageTemplate` | `/conf/mysite/settings/wcm/templates/page-content` |
| `{{components.clientlibPrefix}}` | `components.clientlibPrefix` | `mysite` |
| `{{modules.core}}` | `modules.core` | `core` |
| `{{modules.uiApps}}` | `modules.uiApps` | `ui.apps` |
| `{{modules.uiContent}}` | `modules.uiContent` | `ui.content` |
| `{{modules.uiConfig}}` | `modules.uiConfig` | `ui.config` |
| `{{aem.type}}` | `aem.type` | `cloud` / `lts` / `ams` / `on-prem` |
| `{{aem.javaVersion}}` | `aem.javaVersion` | `11` |
| `{{aem.authorUrl}}` | `aem.authorUrl` | `http://localhost:4502` |
| `{{aem.credentials}}` | `aem.credentials` | `admin:admin` |
| `{{build.deployProfile}}` | `build.deployProfile` | `autoInstallPackage` |
| `{{build.deployBundleProfile}}` | `build.deployBundleProfile` | `autoInstallBundle` |
| `{{testing.framework}}` | `testing.framework` | `junit5` |
| `{{java.testContextClass}}` | `java.testContextClass` | `AppAemContext` |
| `{{git.defaultBranch}}` | `git.defaultBranch` | `main` |

Rules:
- Work **iteratively and autonomously**
- **Read `project.yaml` first** — all paths and names come from it
- **Prefer existing repo patterns** over generic best practices (see REPO_CONTEXT.md)
- Do NOT stop after code generation — **continue until tested and working**
- If blocked, clearly state what is missing
- NEVER fake deployment or test results

---

## 🔁 Agent Pipeline (8 Steps)

### Step 0 — Load Project Config

**Before anything else:**
1. Read `.agent/project.yaml` fully
2. Resolve all `{{placeholder}}` values for this project
3. Verify the `aem.type` — it affects Java version, OSGi config paths, and deploy profiles
4. Resolve `{{PROJECT_ROOT}}`:
   - Use the `projectRoot` key from `project.yaml` if it is set and the directory exists on disk.
   - Otherwise, derive it as the directory that **contains the `.agent/` folder** — i.e., the workspace root in VS Code, or the directory you ran setup.sh from.
   - All `cd {{PROJECT_ROOT}}` commands in this file use this resolved absolute path.

**AEM Version Awareness:**

| Concern | `cloud` | `lts` | `ams` | `on-prem` |
|---|---|---|---|---|
| Java | 11 or 17 | 11 or 17 | 8 or 11 | 8 or 11 |
| SDK/Jar | `aem-sdk-api` | `uber-jar 6.6+` | `uber-jar 6.5.x` | `uber-jar 6.5.x` |
| Deploy profile | `autoInstallSinglePackage` or `autoInstallPackage` | `autoInstallPackage` | `autoInstallPackage` | `autoInstallPackage` |
| OSGi config dirs | `config/`, `config.author/`, `config.publish/`, `config.dev/`, `config.stage/`, `config.prod/` | `config/`, `config.author/`, `config.publish/` | `config/`, `config.author/`, `config.publish/` | `config/` |
| Replication | Sling Content Distribution | Replication API | Replication API | Replication API |
| Dispatcher | Cloud Dispatcher SDK | AMS dispatcher | AMS dispatcher | Classic / none |

---

### Step 1 — Understand the Task

For the given feature request, identify ALL artifacts needed:

| Category | Path Pattern |
|---|---|
| Components | `{{modules.uiApps}}/src/main/content/jcr_root{{jcr.componentPath}}/` |
| Sling Models | `{{java.srcRoot}}/{{java.basePackagePath}}/models/` |
| OSGi Services | `{{java.srcRoot}}/{{java.basePackagePath}}/services/` |
| Servlets | `{{java.srcRoot}}/{{java.basePackagePath}}/servlets/` |
| Schedulers | `{{java.srcRoot}}/{{java.basePackagePath}}/schedulers/` |
| Clientlibs | `{{modules.uiApps}}/src/main/content/jcr_root{{jcr.clientlibPath}}/` |
| Templates/Policies | `{{modules.uiContent}}/src/main/content/jcr_root{{jcr.confRoot}}/settings/wcm/` |
| Content | `{{modules.uiContent}}/src/main/content/jcr_root{{jcr.contentRoot}}/` |
| OSGi Configs | `{{modules.uiConfig}}/src/main/content/jcr_root{{jcr.appsRoot}}/osgiconfig/` |
| Editable Template Policies | `{{modules.uiContent}}/src/main/content/jcr_root{{jcr.confRoot}}/settings/wcm/policies/` |
| Unit Tests | `{{java.testRoot}}/{{java.basePackagePath}}/` |

**Infer missing details from repo patterns. Only ask the user if truly blocked.**

Output:
```
## Artifacts Identified
- [ ] Component: ...
- [ ] Sling Model: ...
- [ ] Dialog: ...
- [ ] Test: ...
- [ ] Test Page: ...
```

---

### Step 2 — Plan Before Coding

Output a short, actionable plan:

```
## Implementation Plan
1. Files to create: ...
2. Files to update: ...
3. Architecture: ...
4. Deployment steps: ...
5. Test content strategy: Approach A / B / C (see Step 5)
```

Then proceed immediately — do NOT wait for approval.

---

### Step 3 — Implement

Create/update code following **REPO_CONTEXT.md** patterns strictly.

Rules:
- **Component .content.xml**: Use `componentGroup="{{components.group}}"`
- **Sling Models**: `@Model(adaptables = Resource.class)` with `InjectionStrategy.OPTIONAL`
- **Dialogs**: Coral UI 3 with `granite/ui/components/coral/foundation/` resource types
- **HTL**: Use `data-sly-use`, `data-sly-test`, `data-sly-list`, `data-sly-resource`
- **Servlets**: `@SlingServletResourceTypes` annotation pattern
- **Schedulers**: `@Designate(ocd=...)` + `@ObjectClassDefinition` pattern
- **Tests**: Use `{{testing.framework}}` + AEM Mocks via `{{java.testContextClass}}.newAemContext()`
- **Clientlibs**: Category naming `{{components.clientlibPrefix}}.{name}`, `allowProxy=true`
- **Package names**: `{{java.basePackage}}.{models|services|servlets|schedulers|listeners|filters}`
- **Editable templates/policies**: Inspect existing template + policy mappings first; only add or update policy nodes when the component is not already allowed

Use the available file editing tool for all file creation/modification. **Do not stop at pseudocode or codeblocks when you can edit the repo directly.**

**AEM Version-Specific Coding Rules:**

| Rule | `cloud` | `lts` / `ams` / `on-prem` |
|---|---|---|
| Sling Model exports | `@Model(adaptables=Resource.class, adapters=MyModel.class, resourceType="...")` required | `@Model(adaptables=Resource.class)` sufficient |
| `@SlingServletResourceTypes` | Preferred (annotation-based) | Preferred if available, else use `@Component(property={...})` |
| OSGi R7 annotations | Always use `@Component`, `@Activate`, `@Designate` | Use if available (check pom.xml for `org.osgi.service.component.annotations`) |
| `javax.inject` vs `org.apache.sling` | Prefer `org.apache.sling.models.annotations.injectorspecific.*` | Same |

---

### Step 4 — Build & Deploy Locally

**You MUST attempt a real build.**

#### Pre-Build Checklist

Before running any Maven command:
1. **Ensure ALL file creation/editing is complete.** Do NOT start a build while still writing files.
2. **Run `sync` to flush file system buffers** (prevents race conditions with FileVault scanning):
   ```
   cd {{PROJECT_ROOT}} && sync
   ```

#### Build Commands (resolve from project.yaml):

**IMPORTANT:** Always include `-T1` to force single-threaded Maven builds. This prevents `ConcurrentModificationException` errors caused by parallel module builds racing on shared plugin state (especially the FileVault content-package plugin). The `-T1` flag is mandatory for agent-driven builds even if the project normally builds with parallel threads.

1. **Core module only** (fast, for Java changes):
   ```
   cd {{PROJECT_ROOT}} && mvn clean install -T1 -pl {{modules.core}}
   ```

2. **Full build** (all modules):
   ```
   cd {{PROJECT_ROOT}} && mvn clean install -T1
   ```

3. **Build + Deploy to local AEM** (if AEM is running):
   ```
   cd {{PROJECT_ROOT}} && mvn clean install -T1 -P{{build.deployProfile}}
   ```

4. **Deploy single module**:
   ```
   cd {{PROJECT_ROOT}} && mvn clean install -T1 -pl {{modules.uiApps}} -P{{build.deployProfile}}
   ```

5. **Deploy bundle only**:
   ```
   cd {{PROJECT_ROOT}} && mvn clean install -T1 -pl {{modules.core}} -P{{build.deployBundleProfile}}
   ```

Note: `{{PROJECT_ROOT}}` is the actual absolute path to the project root on disk.

#### Validate:
- Build returns `BUILD SUCCESS`
- No compilation errors
- Unit tests pass
- If deploying: package installed successfully

#### On Build Failure:
- Read the error output carefully
- **If `ConcurrentModificationException`**: This is a transient race condition. Wait 2 seconds, then retry the exact same build command (with `-T1`). Usually passes on retry.
- Fix the code
- Rebuild
- Repeat until `BUILD SUCCESS`

---

### Step 5 — Create Test Page / Content

**⚠️ CRITICAL: NEVER modify existing content pages. Always create a DEDICATED test page.**

#### Step 5a — Learn from existing content pages (MANDATORY)

**⚠️ BLOCKING: You MUST complete Step 5a before creating any test page. Do NOT skip this step.**

1. **Resolve the site root** using this decision tree (do NOT ask unless resolution fails):
   - **Use `{{jcr.contentLangRoot}}` from project.yaml** as `{siteRoot}`. Verify the path exists on disk at:
     ```
     {{modules.uiContent}}/src/main/content/jcr_root{{jcr.contentLangRoot}}/
     ```
   - If the path **does not exist**, check `{{jcr.contentRoot}}` instead (one level up).
   - If **neither path exists**, then ask the user:
     > The content root path in project.yaml (`{{jcr.contentLangRoot}}`) does not exist in the local codebase. What is the correct path? (e.g. `/content/mysite/us/en`)
   - Once confirmed, use that path as `{siteRoot}` for the rest of this step.

2. **Locate the content on disk** at:
   ```
   {{modules.uiContent}}/src/main/content/jcr_root{siteRoot}/
   ```

3. **Inspect 2–3 existing pages** under that directory:
   - Pick child directories that contain a `.content.xml` (these are content pages).
   - Read each `.content.xml` and note:
     - **Page template** (`cq:template`) and **page resource type** (`sling:resourceType` on `jcr:content`).
     - **Container nesting pattern** — the exact node hierarchy from `jcr:content` down to where components are placed (e.g. `jcr:content/root/container/container` vs `jcr:content/root/responsivegrid`).
     - **Component instances** — which `sling:resourceType` values are used, how properties are named, whether multifield child nodes are present.
     - **Responsive grid markers** — presence of `layout="responsiveGrid"`, `cq:responsive` nodes, column offsets.

4. **Build a mental model** of the project's authoring conventions:
   - Correct container nesting depth to place components.
   - Actual template / resource type values (may differ from `project.yaml` defaults).
   - Property naming style (camelCase vs kebab-case, abbreviated vs full names).

5. **Apply what you learned** — when creating the test page below, mirror the container structure and page template you observed rather than only relying on `project.yaml` placeholders. If the observed values conflict with `project.yaml`, **prefer what is actually in the repo**.

> **QA-fix rerun exception:** If this is a QA-fix rerun where the test page already exists and only component properties are being updated, you may skip the site root resolution (use `{{jcr.contentLangRoot}}` directly) but you must still re-read at least 1 existing page to confirm the container structure before editing the test page.

---

The agent supports **3 approaches** depending on what is being tested.

#### Decision Logic

```
IF (feature is a visual component) {
    → Use Approach A (file-based test page) — ALWAYS
    → ALSO try Approach B (cURL) if AEM is confirmed running
}
ELSE IF (feature is a servlet) {
    → Use Approach C (documented verification)
    → Try the curl command if AEM is running
}
ELSE IF (feature is a service / scheduler / listener / filter) {
    → Use Approach C (documented verification)
    → Rely on unit tests as primary validation
}
```

---

#### Approach A — File-based test page (DEFAULT for all components)

Create a **new child page** under the dedicated test-pages root.

The `ui.content` filter typically uses `mode="merge"` for `{{jcr.contentRoot}}`, so new child pages are auto-included with **no filter changes needed**.

**If `build.contentFilterMode` is `replace`**, you MUST add a filter entry or the page will be deleted on next install. Check `project.yaml` before proceeding.

**Root resolution rules:**
- You MUST have completed Step 5a (resolved and verified the site root, inspected existing pages) before reaching this point.
- Use `{{jcr.testPagesRoot}}` from project.yaml as the dedicated test pages root.
- If that path does not exist yet on disk, create it under `{siteRoot}/test-pages` (where `{siteRoot}` was resolved in Step 5a).
- Always verify the test page template/container structure matches the patterns you learned in Step 5a.

**Steps:**

1. **Ensure the test-pages root exists** at:
   ```
   {{modules.uiContent}}/src/main/content/jcr_root{{jcr.testPagesRoot}}/
   ```

2. **Create the page directory** at:
   ```
   {{modules.uiContent}}/src/main/content/jcr_root{{jcr.testPagesRoot}}/agent-test-{feature-name}/
   ```

3. **Create `.content.xml`** inside that directory:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <jcr:root xmlns:sling="http://sling.apache.org/jcr/sling/1.0"
             xmlns:cq="http://www.day.com/jcr/cq/1.0"
             xmlns:jcr="http://www.jcp.org/jcr/1.0"
             xmlns:nt="http://www.jcp.org/jcr/nt/1.0"
       jcr:primaryType="cq:Page">
       <jcr:content
           jcr:primaryType="cq:PageContent"
           jcr:title="Agent Test - {Feature Name}"
           cq:template="{{components.pageTemplate}}"
           sling:resourceType="{{components.pageResourceType}}">
           <root
               jcr:primaryType="nt:unstructured"
               sling:resourceType="{{components.containerResourceType}}"
               layout="responsiveGrid">
               <container
                   jcr:primaryType="nt:unstructured"
                   sling:resourceType="{{components.containerResourceType}}">
                   <container
                       jcr:primaryType="nt:unstructured"
                       sling:resourceType="{{components.containerResourceType}}"
                       layout="responsiveGrid">

                       <!-- Instance 1: All fields populated (happy path) -->
                       <{componentName}_full
                           jcr:primaryType="nt:unstructured"
                           sling:resourceType="{{components.resourceTypeBase}}/{componentName}"
                           ... />

                       <!-- Instance 2: Minimal / empty (edge case) -->
                       <{componentName}_empty
                           jcr:primaryType="nt:unstructured"
                           sling:resourceType="{{components.resourceTypeBase}}/{componentName}"/>

                   </container>
               </container>
           </root>
       </jcr:content>
   </jcr:root>
   ```

   **Note:** Use `{{components.resourceTypeBase}}/{componentName}` for `sling:resourceType`. It is already expressed relative to `/apps/` and is safe to reuse across repos.

4. **Include at least 2 component instances** — one full, one empty.

5. **Resulting test page URL:**
   ```
   {{aem.authorUrl}}{{jcr.testPagesRoot}}/agent-test-{feature-name}.html
   ```

---

#### Approach B — cURL-based creation (when AEM is confirmed running)

**First, check if AEM is running:**
```bash
curl -s -o /dev/null -w "%{http_code}" -u {{aem.credentials}} {{aem.authorUrl}}/libs/granite/core/content/login.html
```
If response is `200`, AEM is running. If anything else, **skip Approach B entirely**.

**If AEM is running, create the page via Sling POST Servlet** — same structure as Approach A but via curl commands. See REPO_CONTEXT.md for the template.

---

#### Approach C — Documented verification (for backend features)

For **servlets, services, schedulers, listeners, filters**:

1. **Rely on unit tests** as primary validation
2. **Document verification commands** for manual testing:

| Feature Type | Verification Command |
|---|---|
| Servlet (GET) | `curl -u {{aem.credentials}} "{{aem.authorUrl}}{{jcr.contentLangRoot}}.{selector}.{extension}"` |
| Servlet (POST) | `curl -u {{aem.credentials}} -X POST -F "param=value" "{{aem.authorUrl}}/..."` |
| Scheduler | OSGi Console: `{{aem.authorUrl}}/system/console/configMgr` |
| Service | Verified via unit tests |
| Listener | Modify a resource → check `error.log` |
| Filter | `curl -I -u {{aem.credentials}} "{{aem.authorUrl}}{{jcr.contentLangRoot}}.html"` |

---

#### Policy Note

Components using `componentGroup="{{components.group}}"` often align with existing policies, but they are **not automatically allowed in every repo**. Inspect the editable template policy mappings and add/update policy entries only when the component is missing.

---

### Step 6 — Test

| Artifact | Validation Method |
|---|---|
| Component HTL | Check HTML output renders on test page |
| Dialog | Verify field names match Sling Model `@ValueMapValue` names |
| Sling Model | Unit test passes |
| Servlet | Unit test passes, correct response |
| Service | Unit test passes |
| Scheduler | Unit test passes, OSGi annotations valid |
| Clientlib | CSS/JS referenced correctly |
| Test Page | `.content.xml` is well-formed XML |

Run unit tests:
```
cd {{PROJECT_ROOT}} && mvn test -T1 -pl {{modules.core}}
```

---

### Step 7 — Auto Fix Loop (CRITICAL)

```
WHILE (issues exist) {
    1. Identify root cause from build/test output
    2. Fix code/config using the available file editing tool
    3. Rebuild
    4. Retest
    5. Check for new errors
}
```

**Do NOT stop after first failure. Iterate until:**
- ✅ Build succeeds AND
- ✅ All tests pass AND
- ✅ No compilation errors

**OR clearly state why you're blocked.**

---

### Step 8 — Final Report

Generate this exact format:

```
## 📊 Final Report

### ✅ Summary
What was implemented (1-2 sentences)

### 📁 Files Changed
| File | Action | Description |
|---|---|---|
| `path/to/file` | Created / Modified | What changed |

### ⚙️ Deployment
- Command: `mvn clean install -T1 -P{{build.deployProfile}}`
- Build Status: ✅ SUCCESS / ❌ FAILED (reason)
- Deploy Status: ✅ DEPLOYED / ⚠️ NOT DEPLOYED (AEM not running)

### 🌐 Test Content
- **Approach Used:** A (file-based) / B (cURL) / C (documented)
- **Test Page URL:** `{{aem.authorUrl}}{{jcr.testPagesRoot}}/agent-test-{feature-name}.html`
- **Authoring URL:** `{{aem.authorUrl}}/editor.html{{jcr.testPagesRoot}}/agent-test-{feature-name}.html`
- **Test Instances:** 2 (full + empty)
- **Cleanup:** Delete `agent-test-{feature-name}/` directory when done

### 🧪 Results
- Unit Tests: ✅ PASSED (X tests)
- Build: ✅ SUCCESS
- Rendering: ✅ Verified / ⚠️ Needs AEM running

### 🔁 Fixes Applied
| Issue | Root Cause | Fix |
|---|---|---|

### ⚠️ Notes
- Any limitations, follow-ups, or manual steps needed
```

---

## 🚫 Guardrails

- Do NOT modify existing content pages
- Do NOT break existing code
- Do NOT delete unrelated files
- Do NOT fake deployment/test results
- Do NOT modify production systems
- Do NOT introduce new frameworks unless already used in this repo
- Do NOT create files outside the repository structure
- ALWAYS use existing patterns from REPO_CONTEXT.md
- ALWAYS read project.yaml before generating any code
- ALWAYS create test content as a separate page (Approach A), never inline into existing pages
