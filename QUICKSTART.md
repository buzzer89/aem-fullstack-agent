# 🚀 AEM Feature Agent — Universal Quick Start

## For Any Team, Any AEM Version

This agent works with **AEM 6.5**, **AEM LTS**, **AEM AMS**, and **AEM as a Cloud Service** projects. It auto-detects your project structure and generates code that follows YOUR repo's conventions.

---

## 📦 Distribution

The `.agent/universal/` folder contains everything a team needs:

```
.agent/universal/
├── install.sh                # One-command installer — copy + scan in one step
├── setup.sh                  # Bootstrap script — scans your project, generates project.yaml
├── AGENT.md                  # Generic 8-step pipeline (same for ALL teams)
├── REPO_CONTEXT.md           # Universal code patterns with {{placeholders}}
├── aem-feature.agent.md      # VS Code agent: build AEM features end-to-end
├── aem-qa.agent.md           # VS Code agent: visual QA validation of components
├── aem-fullstack.agent.md    # VS Code agent: Plan → Build → QA → PR in one pipeline
├── jira-planner.agent.md     # VS Code agent: Jira → dev plans → implementation → PRs
└── QUICKSTART.md             # This file
```

---

## 🛠️ First-Time Setup (Once Per Project)

### Option A — One-Command Install (recommended)

If any teammate or project already has the agent, run:

```bash
bash /path/to/any-project/.agent/universal/install.sh /path/to/your-aem-project
```

This copies all agent files **and** runs the scanner in one step. Done.

**Example — install from this project into a sibling project:**
```bash
bash .agent/universal/install.sh ../other-aem-project
```

### Option B — Manual Copy + Setup

```bash
# 1. Copy agent files
cp -r /path/to/existing-project/.agent/universal /path/to/your-aem-project/.agent/universal

# 2. Run the scanner
cd /path/to/your-aem-project
bash .agent/universal/setup.sh
```

### After Install — Review and Commit

```bash
# Check the generated config (fix any ⚠️  warnings)
cat .agent/project.yaml

# Commit so all team members get the agents
git add .agent/ .github/agents/
git commit -m "Add AEM agents"
```

### Spreading to More Teams

Once installed in your project, you can install into another project from yours:
```bash
bash .agent/universal/install.sh /path/to/another-team-project
```

The agent is fully self-propagating — every project that has it can install it into the next.

---

## 🚀 Running the Agents

### Agent 1: AEM Feature (Build components/features)

1. Open **VS Code Copilot Chat**
2. Click the **agent picker** → select **"aem-feature"**
3. Type your feature description:

```
Create a Hero Banner component with background image, title, subtitle, and CTA button
```

The agent executes all 8 pipeline steps and gives you the **Authoring URL** in the final report.

### Agent 2: AEM QA (Visual QA validation)

1. Agent picker → select **"aem-qa"**
2. Provide a component name or authoring URL:

```
Hero Banner
```
or
```
http://localhost:4502/editor.html/content/mysite/us/en/agent-test-hero-banner.html
```

The agent opens the page, inspects component rendering, reports defects, and drives fix-retest cycles with `aem-feature`.

### Agent 3: AEM Full-Stack (Plan → Build → QA → PR in one go)

1. Agent picker → select **"aem-fullstack"**
2. Provide EITHER a Jira export file OR a list of features:

```
/Users/me/Downloads/sprint-14-stories.xlsx
```
or
```
Build these features: Hero Banner, FAQ Accordion, Testimonial Carousel
```

The agent orchestrates the entire pipeline: **jira-planner** (plan) → **aem-feature** (build) → **aem-qa** (test) → PR creation. One PR per story, only for QA-passing features.

### Agent 4: Jira Planner (Jira → Dev plans → PRs)

1. Agent picker → select **"jira-planner"**
2. Provide a Jira export file path:

```
/Users/me/Downloads/sprint-14-stories.xlsx
```

Use this when you only want the planning/orchestration part without QA visual testing.

**Prerequisites for Jira Planner:**
- Python 3 with `openpyxl` (`pip install openpyxl`)
- GitHub MCP server configured (for PR creation)

### Alternative: Classic Prompt (without agent picker)

```
@workspace Read .agent/AGENT.md, .agent/REPO_CONTEXT.md, and .agent/project.yaml fully.
Then execute all 8 steps for: FEATURE: "Your feature here"
```

---

## 📋 Ready-Made Feature Prompts

### 🧱 Component Features

```
FEATURE: "Create a Hero Banner component with background image, title, subtitle, CTA button (text + link), and overlay opacity control. Support full-width and contained layout variants."
```

```
FEATURE: "Create a Card List component that displays a configurable grid of cards. Each card has an image, title, description, and CTA link. Authors can add/remove/reorder cards via a multifield dialog. Support 2, 3, and 4 column layouts."
```

```
FEATURE: "Create an FAQ Accordion component using a multifield for question/answer pairs. Answers should support rich text. Include expand-all/collapse-all functionality."
```

```
FEATURE: "Create a Testimonial Carousel component with author photo, quote text, author name, and designation. Authors can add multiple testimonials via multifield."
```

---

### ⚙️ Backend Features

```
FEATURE: "Create a Sling Servlet that exposes page metadata as JSON at selector 'metadata' and extension 'json' for any page under our content root. Include title, description, tags, lastModified, and template info."
```

```
FEATURE: "Build an OSGi service that generates a sitemap XML for all published pages under our content root. Expose it via a servlet at {contentRoot}.sitemap.xml"
```

```
FEATURE: "Create a scheduled task that runs daily at 2 AM and logs all pages under our content root that haven't been modified in the last 30 days. Make the path and days configurable via OSGi config."
```

---

### 🔧 Utility Features

```
FEATURE: "Create a custom Sling Filter that adds security headers (X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security) to all responses for pages under our content root."
```

```
FEATURE: "Create a ResourceChangeListener that automatically updates a 'lastReviewedBy' property whenever a page under our content root is modified."
```

---

## 🏗️ How It Works (Architecture)

```
┌─────────────────────────────────────────────────────┐
│                    setup.sh                          │
│         (run once — scans your AEM project)          │
└───────────────────────┬─────────────────────────────┘
                        │ generates
                        ▼
┌─────────────────────────────────────────────────────┐
│                  project.yaml                        │
│    (all project-specific values in one place)        │
│                                                      │
│  project.groupId: "com.acme"                         │
│  aem.type: "cloud"                                   │
│  java.basePackage: "com.acme.core"                   │
│  jcr.contentRoot: "/content/acmesite"                │
│  components.group: "ACME Site - Content"             │
│  ...                                                 │
└───────────────────────┬─────────────────────────────┘
                        │ referenced by
                        ▼
┌─────────────────────────────────────────────────────┐
│    AGENT.md              REPO_CONTEXT.md             │
│  (8-step pipeline)     (code patterns)               │
│                                                      │
│  Uses {{project.groupId}}, {{java.basePackage}},     │
│  {{jcr.contentRoot}}, etc. — resolved at runtime     │
│                                                      │
│  ✅ Same files for ALL teams                         │
│  ✅ Never needs editing                              │
│  ✅ Works with any AEM version                       │
└─────────────────────────────────────────────────────┘
```

### What changes per team?
**Only `project.yaml`** — everything else is identical across all projects.

### What the agent reads at runtime:
1. `project.yaml` → knows your project structure
2. `AGENT.md` → follows the 8-step pipeline
3. `REPO_CONTEXT.md` → uses your project's patterns for code generation

---

## � Non-Standard Project Structures

The scanner handles projects that **don't follow the AEM archetype naming conventions**. Module detection works by **inspecting content** (directories, POM packaging, config files) rather than relying on directory names.

### Supported Module Name Variations

| Standard Name | Also Detects |
|---|---|
| `core` | `bundle`, `bundles`, `backend`, `java` — or any module with `src/main/java` + `packaging=bundle` |
| `ui.apps` | `apps`, `applications`, `uiapps` — or any module with `jcr_root/apps/` |
| `ui.content` | `content`, `uicontent`, `sample-content` — or any module with `jcr_root/content/` |
| `ui.config` | `config`, `uiconfig`, `osgi-config` — or any module with `osgiconfig/` or `config.author/` dirs |
| `ui.frontend` | `frontend`, `uifrontend`, `ui` — or any module with `package.json` / `webpack.config.js` / `vite.config.ts` |
| `all` | `complete`, `full`, `assembly` — or any content-package with `<embeddeds>` |
| `it.tests` | `integration-tests` — or any module matching `it[._-]test` / `integration[._-]test` |
| `ui.tests` | `e2e`, `cypress`, `playwright` — or any module with Cypress/Playwright config |
| `dispatcher` | `dispatcher.ams`, `dispatcher.cloud` — or any module with `conf.dispatcher.d/` |

### Property Chain Resolution

Maven property references like `${aem.version}` or `${java.version}` are followed through the POM `<properties>` section, including chained references (e.g., `<maven.compiler.source>${java.version}</maven.compiler.source>`).

### When Auto-Detection Fails

If a module can't be classified by content inspection, the scanner falls back to name-based matching. If that also fails, it prints a **warning** and uses the archetype default name. You can always fix values manually in `project.yaml`.

---

## �🔄 AEM Version Compatibility

| Feature | AEM 6.5 On-Prem | AEM 6.5 AMS | AEM LTS | AEMaaCS |
|---|---|---|---|---|
| Auto-detection | ✅ | ✅ | ✅ | ✅ |
| Component generation | ✅ | ✅ | ✅ | ✅ |
| Sling Model pattern | Standard | Standard | Standard | Enhanced (adapters, resourceType, @Exporter) |
| OSGi config format | `.xml` | `.xml` | `.xml` / `.cfg.json` | `.cfg.json` |
| OSGi run modes | `config/` | `config/`, `config.author/` | `config/`, `config.author/` | `config.author/`, `config.dev/`, `config.prod/` |
| Deploy profile | `autoInstallPackage` | `autoInstallPackage` | `autoInstallPackage` | `autoInstallSinglePackage` |
| Replication API | Classic | Classic | Classic | Sling Content Distribution |
| Java version | 8 / 11 | 8 / 11 | 11 / 17 | 11 / 17 |
| Servlet annotations | `@Component(property)` | `@Component(property)` | `@SlingServletResourceTypes` | `@SlingServletResourceTypes` |

---

## 📁 Final File Structure (After Setup)

```
your-aem-project/
├── .agent/
│   ├── project.yaml       ← Generated (project-specific config)
│   ├── AGENT.md            ← Installed (generic pipeline)
│   ├── REPO_CONTEXT.md     ← Installed (generic patterns)
│   ├── QUICKSTART.md       ← Installed (this file)
│   └── universal/          ← Source files (distribute to other teams)
│       ├── setup.sh
│       ├── AGENT.md
│       ├── REPO_CONTEXT.md
│       ├── QUICKSTART.md
│       └── aem-feature.agent.md
├── .github/
│   └── agents/
│       └── aem-feature.agent.md  ← Custom Agent Mode (auto-installed)
├── core/
├── ui.apps/
├── ui.content/
├── ...
└── pom.xml
```

---

## 💡 Tips

1. **Be specific** — The more detail in your feature description, the better the output
2. **Let it run** — The agent builds, tests, fixes, and iterates automatically
3. **Check the report** — Step 8 gives you a full summary of everything done
4. **AEM not running?** — The agent still generates code, builds, and runs unit tests
5. **Multiple features?** — Run the agent once per feature for best results
6. **Re-run setup.sh** — Safe to re-run if you change project structure; it regenerates `project.yaml`
7. **Commit `.agent/`** — The whole folder should be in version control so all team members can use it
