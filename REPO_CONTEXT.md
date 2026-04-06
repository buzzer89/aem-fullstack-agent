# 📚 Repository Context — Universal Patterns

> **This file is the agent's knowledge base.** It contains every convention, pattern, and template
> needed to generate code for ANY AEM project. All project-specific values come from `project.yaml`.
>
> When you see `{{something}}`, resolve it from `.agent/project.yaml`.

---

## 1. Project Identity

Read from `project.yaml`:

| Property | YAML Key |
|---|---|
| Group ID | `project.groupId` |
| Artifact ID | `project.artifactId` |
| Version | `project.version` |
| AEM Type | `aem.type` (`cloud` / `lts` / `ams` / `on-prem`) |
| Java Version | `aem.javaVersion` |
| Component Group | `components.group` |
| Component Resource Type Base | `components.resourceTypeBase` |
| Content Root | `jcr.contentRoot` |
| Test Pages Root | `jcr.testPagesRoot` |
| Apps Root | `jcr.appsRoot` |
| Conf Root | `jcr.confRoot` |
| Default PR Base Branch | `git.defaultBranch` |

---

## 2. Module Map

| Module | YAML Key | Purpose |
|---|---|---|
| Core | `modules.core` | Java backend: Models, Services, Servlets, Filters, Schedulers, Listeners |
| UI Apps | `modules.uiApps` | Components (HTL + dialogs), Clientlibs, i18n |
| UI Content | `modules.uiContent` | Templates, Policies, Content pages, DAM, Experience Fragments |
| UI Config | `modules.uiConfig` | OSGi configurations |
| UI Frontend | `modules.uiFrontend` | Webpack/Vite frontend build → clientlib-site |
| All | `modules.all` | Container package embedding all sub-packages |
| IT Tests | `modules.itTests` | Server-side integration tests |
| UI Tests | `modules.uiTests` | UI / E2E tests |
| Dispatcher | `modules.dispatcher` | Dispatcher configs |

---

## 3. Key Paths

```
# Java source
{{java.srcRoot}}/{{java.basePackagePath}}/
  ├── models/          # Sling Models
  ├── services/        # OSGi Services (create if needed)
  │   └── impl/        # Service implementations
  ├── servlets/        # Sling Servlets
  ├── filters/         # Servlet Filters
  ├── schedulers/      # Scheduled Tasks
  └── listeners/       # Resource/Event Listeners

# Java tests
{{java.testRoot}}/{{java.basePackagePath}}/
  ├── models/          # Model tests
  ├── services/        # Service tests
  ├── servlets/        # Servlet tests
  ├── filters/         # Filter tests
  ├── schedulers/      # Scheduler tests
  ├── listeners/       # Listener tests
  └── testcontext/     # {{java.testContextClass}}.java

# Components
{{modules.uiApps}}/src/main/content/jcr_root{{jcr.componentPath}}/
  └── {componentName}/
      ├── .content.xml              # cq:Component definition
      ├── {componentName}.html      # HTL template
      ├── _cq_dialog/
      │   └── .content.xml          # Authoring dialog
      ├── _cq_editConfig.xml        # (optional) Edit config
      └── _cq_template/
          └── .content.xml          # (optional) Default content

# Clientlibs
{{modules.uiApps}}/src/main/content/jcr_root{{jcr.clientlibPath}}/
  └── clientlib-{name}/
      ├── .content.xml
      ├── css.txt
      ├── js.txt
      ├── css/
      └── js/

# Templates & Policies
{{modules.uiContent}}/src/main/content/jcr_root{{jcr.confRoot}}/settings/wcm/
  ├── templates/
  └── policies/

# Content
{{modules.uiContent}}/src/main/content/jcr_root{{jcr.contentRoot}}/

# OSGi Configs
{{modules.uiConfig}}/src/main/content/jcr_root{{jcr.appsRoot}}/osgiconfig/
  ├── config/                    # All run modes
  ├── config.author/             # Author only (cloud/lts/ams)
  ├── config.publish/            # Publish only (cloud/lts/ams)
  ├── config.dev/                # Dev only (cloud only)
  ├── config.stage/              # Stage only (cloud only)
  └── config.prod/               # Prod only (cloud only)
```

---

## 4. Pattern: Component Definition (.content.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<jcr:root xmlns:cq="http://www.day.com/jcr/cq/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0"
    jcr:primaryType="cq:Component"
    jcr:title="Component Title Here"
    componentGroup="{{components.group}}"/>
```

**Notes:**
- `componentGroup` MUST match `{{components.group}}` from project.yaml so it lines up with repo policies and authoring groups
- Do not assume policy allow-lists update automatically. Inspect editable template policies before deciding whether a policy change is needed.
- For proxy components extending Core Components, add: `sling:resourceSuperType="core/wcm/components/image/v3/image"`

---

## 5. Pattern: Component Dialog (_cq_dialog/.content.xml)

### Simple single-field dialog:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jcr:root xmlns:sling="http://sling.apache.org/jcr/sling/1.0" xmlns:cq="http://www.day.com/jcr/cq/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0" xmlns:nt="http://www.jcp.org/jcr/nt/1.0"
    jcr:primaryType="nt:unstructured"
    jcr:title="Properties"
    sling:resourceType="cq/gui/components/authoring/dialog">
    <content
        jcr:primaryType="nt:unstructured"
        sling:resourceType="granite/ui/components/coral/foundation/fixedcolumns">
        <items jcr:primaryType="nt:unstructured">
            <column
                jcr:primaryType="nt:unstructured"
                sling:resourceType="granite/ui/components/coral/foundation/container">
                <items jcr:primaryType="nt:unstructured">
                    <fieldName
                        jcr:primaryType="nt:unstructured"
                        sling:resourceType="granite/ui/components/coral/foundation/form/textfield"
                        fieldLabel="Field Label"
                        name="./propertyName"/>
                </items>
            </column>
        </items>
    </content>
</jcr:root>
```

### Multi-tab dialog:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jcr:root xmlns:sling="http://sling.apache.org/jcr/sling/1.0" xmlns:cq="http://www.day.com/jcr/cq/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0" xmlns:nt="http://www.jcp.org/jcr/nt/1.0"
    jcr:primaryType="nt:unstructured"
    jcr:title="Properties"
    sling:resourceType="cq/gui/components/authoring/dialog">
    <content
        jcr:primaryType="nt:unstructured"
        sling:resourceType="granite/ui/components/coral/foundation/container">
        <items jcr:primaryType="nt:unstructured">
            <tabs
                jcr:primaryType="nt:unstructured"
                sling:resourceType="granite/ui/components/coral/foundation/tabs"
                maximized="{Boolean}true">
                <items jcr:primaryType="nt:unstructured">
                    <tab1
                        jcr:primaryType="nt:unstructured"
                        jcr:title="Tab 1"
                        sling:resourceType="granite/ui/components/coral/foundation/container"
                        margin="{Boolean}true">
                        <items jcr:primaryType="nt:unstructured">
                            <!-- fields here -->
                        </items>
                    </tab1>
                </items>
            </tabs>
        </items>
    </content>
</jcr:root>
```

### Common Dialog Field Types:
```xml
<!-- Text Field -->
<text jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/textfield"
    fieldLabel="Title" name="./title" required="{Boolean}true"/>

<!-- Text Area -->
<description jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/textarea"
    fieldLabel="Description" name="./description"/>

<!-- Rich Text -->
<richtext jcr:primaryType="nt:unstructured"
    sling:resourceType="cq/gui/components/authoring/dialog/richtext"
    fieldLabel="Body" name="./body" useFixedInlineToolbar="{Boolean}true"/>

<!-- Checkbox -->
<enabled jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/checkbox"
    text="Enable Feature" name="./enabled" value="{Boolean}true"/>

<!-- Select / Dropdown -->
<style jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/select"
    fieldLabel="Style" name="./style">
    <items jcr:primaryType="nt:unstructured">
        <default jcr:primaryType="nt:unstructured" text="Default" value="default"/>
        <dark jcr:primaryType="nt:unstructured" text="Dark" value="dark"/>
    </items>
</style>

<!-- Path Picker -->
<linkURL jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/pathfield"
    fieldLabel="Link" name="./linkURL" rootPath="/content"/>

<!-- Image / File Upload -->
<fileUpload jcr:primaryType="nt:unstructured"
    sling:resourceType="cq/gui/components/authoring/dialog/fileupload"
    fieldLabel="Image" name="./image" fileNameParameter="./imageName"
    fileReferenceParameter="./imageReference" allowUpload="{Boolean}true"/>

<!-- Number Field -->
<count jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/numberfield"
    fieldLabel="Count" name="./count" min="{Long}1" max="{Long}100" step="{Long}1"/>

<!-- Hidden Field -->
<resourceType jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/hidden"
    name="./sling:resourceType" value="{{components.resourceTypeBase}}/mycomponent"/>

<!-- Multifield -->
<items jcr:primaryType="nt:unstructured"
    sling:resourceType="granite/ui/components/coral/foundation/form/multifield"
    fieldLabel="Items" composite="{Boolean}true">
    <field jcr:primaryType="nt:unstructured"
        sling:resourceType="granite/ui/components/coral/foundation/container"
        name="./items">
        <items jcr:primaryType="nt:unstructured">
            <title jcr:primaryType="nt:unstructured"
                sling:resourceType="granite/ui/components/coral/foundation/form/textfield"
                fieldLabel="Title" name="./title"/>
            <link jcr:primaryType="nt:unstructured"
                sling:resourceType="granite/ui/components/coral/foundation/form/pathfield"
                fieldLabel="Link" name="./link" rootPath="/content"/>
        </items>
    </field>
</items>
```

---

## 6. Pattern: HTL Template

```html
<div class="cmp-mycomponent" data-cmp-is="mycomponent"
     data-sly-use.model="{{java.basePackage}}.models.MyComponentModel"
     data-sly-test="${model}">

    <h2 class="cmp-mycomponent__title" data-sly-test="${model.title}">${model.title}</h2>

    <div class="cmp-mycomponent__description" data-sly-test="${model.description}">
        ${model.description @ context='html'}
    </div>

    <ul class="cmp-mycomponent__list" data-sly-list.item="${model.items}">
        <li class="cmp-mycomponent__item">${item.title}</li>
    </ul>

    <a class="cmp-mycomponent__link" href="${model.linkURL @ extension='html'}"
       data-sly-test="${model.linkURL}">
        ${model.linkText || 'Read More'}
    </a>
</div>
```

**BEM Naming**: `.cmp-{componentname}`, `.cmp-{componentname}__{element}`, `.cmp-{componentname}--{modifier}`

**HTL Context Rules (CRITICAL for build validation):**
- Expressions in `style` attributes MUST have explicit context: `${value @ context='styleToken'}`
- Expressions in `href` use default context or `@ context='uri'`
- Rich text output: `${value @ context='html'}`
- Plain text (default): `${value}` — no context needed

---

## 7. Pattern: Sling Model

### Standard (all AEM versions):
```java
package {{java.basePackage}}.models;

import javax.annotation.PostConstruct;
import org.apache.sling.api.resource.Resource;
import org.apache.sling.api.resource.ResourceResolver;
import org.apache.sling.models.annotations.Default;
import org.apache.sling.models.annotations.Model;
import org.apache.sling.models.annotations.injectorspecific.InjectionStrategy;
import org.apache.sling.models.annotations.injectorspecific.OSGiService;
import org.apache.sling.models.annotations.injectorspecific.SlingObject;
import org.apache.sling.models.annotations.injectorspecific.ValueMapValue;
import org.apache.sling.models.annotations.injectorspecific.ChildResource;

@Model(adaptables = Resource.class)
public class MyComponentModel {

    @ValueMapValue(injectionStrategy = InjectionStrategy.OPTIONAL)
    private String title;

    @ValueMapValue(injectionStrategy = InjectionStrategy.OPTIONAL)
    private String description;

    @ValueMapValue(injectionStrategy = InjectionStrategy.OPTIONAL)
    private String linkURL;

    @SlingObject
    private Resource currentResource;

    @SlingObject
    private ResourceResolver resourceResolver;

    private String computedValue;

    @PostConstruct
    protected void init() {
        // initialization logic
    }

    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public String getLinkURL() { return linkURL; }
    public String getComputedValue() { return computedValue; }
}
```

### AEMaaCS enhanced (when `aem.type` is `cloud`):
```java
package {{java.basePackage}}.models;

import org.apache.sling.api.resource.Resource;
import org.apache.sling.models.annotations.Model;
import org.apache.sling.models.annotations.DefaultInjectionStrategy;
import org.apache.sling.models.annotations.Exporter;

@Model(
    adaptables = Resource.class,
    adapters = MyComponentModel.class,
    resourceType = "{{components.resourceTypeBase}}/mycomponent",
    defaultInjectionStrategy = DefaultInjectionStrategy.OPTIONAL
)
@Exporter(name = "jackson", extensions = "json")
public class MyComponentModel {
    // ... same fields and methods ...
}
```

### For child resource lists (multifield):
```java
@ChildResource(injectionStrategy = InjectionStrategy.OPTIONAL)
private List<Resource> items;

public List<ItemModel> getItems() {
    if (items == null) return Collections.emptyList();
    return items.stream()
        .map(r -> r.adaptTo(ItemModel.class))
        .filter(Objects::nonNull)
        .collect(Collectors.toList());
}
```

---

## 8. Pattern: OSGi Service

### Interface:
```java
package {{java.basePackage}}.services;

public interface MyService {
    String doSomething(String input);
}
```

### Implementation:
```java
package {{java.basePackage}}.services.impl;

import {{java.basePackage}}.services.MyService;
import org.osgi.service.component.annotations.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component(service = MyService.class, immediate = true)
public class MyServiceImpl implements MyService {
    private static final Logger LOG = LoggerFactory.getLogger(MyServiceImpl.class);

    @Override
    public String doSomething(String input) {
        LOG.debug("Processing: {}", input);
        return input;
    }
}
```

---

## 9. Pattern: Sling Servlet

```java
package {{java.basePackage}}.servlets;

import org.apache.sling.api.SlingHttpServletRequest;
import org.apache.sling.api.SlingHttpServletResponse;
import org.apache.sling.api.servlets.SlingSafeMethodsServlet;
import org.apache.sling.servlets.annotations.SlingServletResourceTypes;
import org.apache.sling.api.servlets.HttpConstants;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.propertytypes.ServiceDescription;

import javax.servlet.Servlet;
import javax.servlet.ServletException;
import java.io.IOException;

@Component(service = { Servlet.class })
@SlingServletResourceTypes(
        resourceTypes = "{{components.pageResourceType}}",
        methods = HttpConstants.METHOD_GET,
        extensions = "json",
        selectors = "data")
@ServiceDescription("My Data Servlet")
public class MyDataServlet extends SlingSafeMethodsServlet {
    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(final SlingHttpServletRequest req,
            final SlingHttpServletResponse resp) throws ServletException, IOException {
        resp.setContentType("application/json");
        resp.getWriter().write("{\"status\":\"ok\"}");
    }
}
```

**Fallback (if `@SlingServletResourceTypes` is not available in older AEM 6.5):**
```java
@Component(
    service = Servlet.class,
    property = {
        "sling.servlet.resourceTypes=" + "{{components.pageResourceType}}",
        "sling.servlet.methods=" + HttpConstants.METHOD_GET,
        "sling.servlet.extensions=json",
        "sling.servlet.selectors=data"
    }
)
```

---

## 10. Pattern: Scheduler

```java
package {{java.basePackage}}.schedulers;

import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.metatype.annotations.AttributeDefinition;
import org.osgi.service.metatype.annotations.Designate;
import org.osgi.service.metatype.annotations.ObjectClassDefinition;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Designate(ocd = MyScheduledTask.Config.class)
@Component(service = Runnable.class)
public class MyScheduledTask implements Runnable {

    @ObjectClassDefinition(name = "My Scheduled Task",
            description = "Configurable scheduled task")
    public static @interface Config {
        @AttributeDefinition(name = "Cron Expression")
        String scheduler_expression() default "0 0 2 * * ?";

        @AttributeDefinition(name = "Concurrent")
        boolean scheduler_concurrent() default false;

        @AttributeDefinition(name = "Enabled")
        boolean enabled() default true;
    }

    private final Logger logger = LoggerFactory.getLogger(getClass());
    private boolean enabled;

    @Activate
    protected void activate(final Config config) {
        enabled = config.enabled();
    }

    @Override
    public void run() {
        if (!enabled) return;
        logger.info("Running scheduled task...");
    }
}
```

---

## 11. Pattern: Unit Test

### JUnit 5 (default — check `testing.framework` in project.yaml):
```java
package {{java.basePackage}}.models;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import com.day.cq.wcm.api.Page;
import io.wcm.testing.mock.aem.junit5.AemContext;
import io.wcm.testing.mock.aem.junit5.AemContextExtension;
import {{java.basePackage}}.testcontext.{{java.testContextClass}};
import org.apache.sling.api.resource.Resource;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(AemContextExtension.class)
class MyComponentModelTest {

    private final AemContext context = {{java.testContextClass}}.newAemContext();

    private Page page;

    @BeforeEach
    void setup() {
        page = context.create().page("/content/mypage");
    }

    @Test
    void testGetTitle() {
        Resource resource = context.create().resource(page, "mycomp",
            "sling:resourceType", "{{components.resourceTypeBase}}/mycomponent",
            "title", "Test Title");
        MyComponentModel model = resource.adaptTo(MyComponentModel.class);
        assertNotNull(model);
        assertEquals("Test Title", model.getTitle());
    }

    @Test
    void testNullValues() {
        Resource emptyResource = context.create().resource(page, "empty",
            "sling:resourceType", "{{components.resourceTypeBase}}/mycomponent");
        MyComponentModel emptyModel = emptyResource.adaptTo(MyComponentModel.class);
        assertNotNull(emptyModel);
        assertNull(emptyModel.getTitle());
    }
}
```

### JUnit 4 (if `testing.framework` is `junit4`):
```java
package {{java.basePackage}}.models;

import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;

import io.wcm.testing.mock.aem.junit.AemContext;
import {{java.basePackage}}.testcontext.{{java.testContextClass}};

import static org.junit.Assert.*;

public class MyComponentModelTest {

    @Rule
    public final AemContext context = {{java.testContextClass}}.newAemContext();

    @Before
    public void setup() { ... }

    @Test
    public void testGetTitle() { ... }
}
```

### Servlet Test Pattern:
```java
package {{java.basePackage}}.servlets;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import io.wcm.testing.mock.aem.junit5.AemContext;
import io.wcm.testing.mock.aem.junit5.AemContextExtension;
import {{java.basePackage}}.testcontext.{{java.testContextClass}};

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(AemContextExtension.class)
class MyServletTest {

    private final AemContext context = {{java.testContextClass}}.newAemContext();
    private MyServlet servlet;

    @BeforeEach
    void setup() {
        servlet = new MyServlet();
        context.create().resource("/content/test",
            "sling:resourceType", "{{components.pageResourceType}}");
        context.currentResource("/content/test");
    }

    @Test
    void testDoGet() throws Exception {
        servlet.doGet(context.request(), context.response());
        assertEquals("application/json", context.response().getContentType());
        assertTrue(context.response().getOutputAsString().contains("status"));
    }
}
```

---

## 12. Pattern: Clientlib

### .content.xml:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jcr:root xmlns:cq="http://www.day.com/jcr/cq/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0"
    jcr:primaryType="cq:ClientLibraryFolder"
    categories="[{{components.clientlibPrefix}}.mycomponent]"
    allowProxy="{Boolean}true"/>
```

### css.txt:
```
#base=css
mycomponent.css
```

### js.txt:
```
#base=js
mycomponent.js
```

**To include in component HTL:**
```html
<sly data-sly-use.clientlib="/libs/granite/sightly/templates/clientlib.html">
    <sly data-sly-call="${clientlib.css @ categories='{{components.clientlibPrefix}}.mycomponent'}"/>
    <sly data-sly-call="${clientlib.js @ categories='{{components.clientlibPrefix}}.mycomponent'}"/>
</sly>
```

---

## 13. Pattern: Test Content Page

**⚠️ NEVER modify existing content pages. Always create a dedicated test page.**

### 13a. Learn from existing pages first

Before creating a test page, ask the user for their site root path (e.g. `/content/mysite/us/en`), then read 2–3 existing `.content.xml` pages under:
```
{{modules.uiContent}}/src/main/content/jcr_root{siteRoot}/
```
Study the page template, container nesting pattern, and component authoring conventions. Mirror what you find in your test page rather than only relying on the template below.

### 13b. Test page location

Use `{{jcr.testPagesRoot}}` as the dedicated parent for all agent-created pages.

If the path does not exist yet, create:
```
{{modules.uiContent}}/src/main/content/jcr_root{{jcr.testPagesRoot}}/
```

Then create the feature test page under:
```
{{modules.uiContent}}/src/main/content/jcr_root{{jcr.testPagesRoot}}/agent-test-{feature-name}/
```

If `{{jcr.testPagesRoot}}` is missing or clearly wrong and you cannot infer a safe authoring root from the repo, ask the user for the desired `/en` or language-root path and create `/test-pages` beneath it before proceeding.

### Full test page template:
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
                    <mycomponent_full
                        jcr:primaryType="nt:unstructured"
                        sling:resourceType="{{components.resourceTypeBase}}/mycomponent"
                        title="Sample Title"
                        description="Sample description text"/>

                    <!-- Instance 2: Empty / minimal (edge case) -->
                    <mycomponent_empty
                        jcr:primaryType="nt:unstructured"
                        sling:resourceType="{{components.resourceTypeBase}}/mycomponent"/>

                </container>
            </container>
        </root>
    </jcr:content>
</jcr:root>
```

### For multifield components, include child resource nodes:
```xml
<cardlist_full
    jcr:primaryType="nt:unstructured"
    sling:resourceType="{{components.resourceTypeBase}}/cardlist"
    layout="3-column">
    <cards jcr:primaryType="nt:unstructured">
        <item0 jcr:primaryType="nt:unstructured" title="Card One" linkURL="{{jcr.contentLangRoot}}"/>
        <item1 jcr:primaryType="nt:unstructured" title="Card Two" linkURL="{{jcr.contentLangRoot}}"/>
    </cards>
</cardlist_full>
```

### Test page URLs:
```
{{aem.authorUrl}}{{jcr.testPagesRoot}}/agent-test-{feature-name}.html
{{aem.authorUrl}}/editor.html{{jcr.testPagesRoot}}/agent-test-{feature-name}.html
```

---

## 14. Build & Deploy Commands

**IMPORTANT:** Always include `-T1` (single-threaded) in all Maven build commands to prevent `ConcurrentModificationException` errors caused by parallel module builds racing on shared plugin state (especially the FileVault content-package plugin). Also run `sync` before building to flush file-system buffers.

```bash
# Flush file-system buffers before building
cd {{PROJECT_ROOT}} && sync

# Core only (fast — Java changes)
cd {{PROJECT_ROOT}} && mvn clean install -T1 -pl {{modules.core}}

# Full build (all modules)
cd {{PROJECT_ROOT}} && mvn clean install -T1

# Build + deploy to local AEM author
cd {{PROJECT_ROOT}} && mvn clean install -T1 -P{{build.deployProfile}}

# Build + deploy to local AEM publish
cd {{PROJECT_ROOT}} && mvn clean install -T1 -P{{build.deployProfile}}Publish

# Deploy single module
cd {{PROJECT_ROOT}} && mvn clean install -T1 -pl {{modules.uiApps}} -P{{build.deployProfile}}
cd {{PROJECT_ROOT}} && mvn clean install -T1 -pl {{modules.core}} -P{{build.deployBundleProfile}}

# Run only unit tests
cd {{PROJECT_ROOT}} && mvn test -T1 -pl {{modules.core}}

# Full build skipping tests
cd {{PROJECT_ROOT}} && mvn clean install -T1 -DskipTests
```

### AEM Local Instance
- Author: `{{aem.authorUrl}}` (`{{aem.credentials}}`)
- Publish: `{{aem.publishUrl}}` (`{{aem.credentials}}`)

---

## 15. Package Info Files

When creating a new package (e.g., `services`, `services/impl`), create a `package-info.java`:

```java
@Version("1.0.0")
package {{java.basePackage}}.services;

import org.osgi.annotation.versioning.Version;
```

---

## 16. AEM Version-Specific Patterns

### OSGi Config Naming

| AEM Type | Config File Naming | Example |
|---|---|---|
| `cloud` | `<PID>-<identifier>.cfg.json` or `<PID>~<identifier>.cfg.json` | `com.mycompany.MyService~default.cfg.json` |
| `lts` / `ams` | `<PID>.xml` or `<PID>.config` or `<PID>.cfg.json` | `com.mycompany.MyService.xml` |
| `on-prem` | `<PID>.xml` or `<PID>.config` | `com.mycompany.MyService.xml` |

### OSGi Config XML Format (6.5 / LTS / AMS):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jcr:root xmlns:sling="http://sling.apache.org/jcr/sling/1.0" xmlns:jcr="http://www.jcp.org/jcr/1.0"
    jcr:primaryType="sling:OsgiConfig"
    property.name="value"
    property.boolean="{Boolean}true"
    property.long="{Long}42"/>
```

### OSGi Config JSON Format (Cloud / newer LTS):
```json
{
    "property.name": "value",
    "property.boolean": true,
    "property.long": 42
}
```

### Replication vs Distribution

| AEM Type | API | Pattern |
|---|---|---|
| `cloud` | Sling Content Distribution | `@Reference DistributionRequestHandler` |
| `lts` / `ams` / `on-prem` | Replication API | `@Reference Replicator` |

---

## 17. Existing Components

The `existingComponents` section in `project.yaml` lists all components already in the project. Use this to:
- Avoid naming conflicts
- Reference existing component patterns
- Determine what proxy components are already configured

---

## 18. Filter Files

### ui.apps filter:
Typically includes `{{jcr.componentPath}}` and `{{jcr.clientlibPath}}` — new components/clientlibs under these roots are **auto-included**.

### ui.content filter:
Check `build.contentFilterMode` in project.yaml:
- `merge` — New child nodes (pages, config) auto-included. No filter changes needed.
- `replace` — Only explicitly listed roots are included. You MAY need to add filter entries for new content.

### Editable Template Policies:
- Inspect `{{jcr.confRoot}}/settings/wcm/templates/` and `{{jcr.confRoot}}/settings/wcm/policies/` before adding a component to authorable pages.
- Reuse existing policy/container structures when possible instead of inventing new templates or policy trees.
