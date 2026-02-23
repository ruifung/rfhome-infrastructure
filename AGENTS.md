# AGENTS.md - Kubernetes & Talos Infrastructure Guidelines

This guide is for agentic coding agents operating on this repository. Primary tasks are:
1. Adding, removing, and modifying Kubernetes deployments in the Pathweb cluster via Flux CD
2. Managing Talos Linux node configuration via Pulumi (authoritative source)

**Important:** Talos configuration is managed entirely through Pulumi TypeScript code. Never manually edit files in `talos/pathweb/patches/` or `talos/pathweb/base/` - these are generated artifacts.

## Repository Structure

Deployments use a **two-tier system**:

- **`deployments/pathweb/_index_/`** - Index files that tell Flux what to deploy
- **`deployments/pathweb/workloads/`** - Actual workload directories (pure Kustomize)
- **`deployments/pathweb/cluster-*/`** - System components (Helm, Kustomize, Hybrid)

Flux reads the index tier and recursively deploys all referenced resources.

## Deployment Patterns

Choose the pattern based on requirements:

### 1. Pure Kustomize (Simple Custom Workloads)
**Use for:** Custom deployments with raw Kubernetes manifests
**Structure:**
```
deployments/pathweb/workloads/{category}/{app-name}/
├── kustomization.yaml          # References all resources
├── statefulset.yaml / deployment.yaml
├── service.yaml
├── persistentvolumeclaim.yaml
├── networkattachmentdefinition.yaml
├── httproute.yaml
├── ciliumnetworkpolicy.yaml
├── *.sealed.yaml               # Secrets (sealed)
└── configmap-file.ext          # ConfigMap source files
```

**Index entry** (`_index_/workloads/{category}/{app-name}.yaml`):
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-name
  namespace: flux-system
spec:
  interval: 15m
  path: ./deployments/pathweb/workloads/{category}/{app-name}
  prune: true
  sourceRef:
    kind: GitRepository
    name: rfhome-infrastructure
  targetNamespace: {namespace}
```

### 2. Pure Helm (Official Charts)
**Use for:** Official Helm charts with minimal customization
**Structure:**
```
deployments/pathweb/workloads/{category}/{app-name}/
└── helm.yaml                   # OCIRepository + HelmRelease
```

**Example pattern:**
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: app-chart
  namespace: flux-system
spec:
  interval: 24h
  url: oci://harbor.services.home.yrf.me/chartproxy/{chart-path}
  ref:
    tag: {version}
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-name
  namespace: flux-system
spec:
  releaseName: app-name
  chartRef:
    kind: OCIRepository
    name: app-chart
  interval: 15m
  targetNamespace: {namespace}
  install:
    createNamespace: true
  values:
    key: value
```

### 3. Helm + Kustomize PostRenderers (Chart Patching)
**Use for:** Helm charts that don't expose required values fields
**IMPORTANT:** Only patch if the chart lacks a values field for what you need. Prefer values-based configuration.

Use `postRenderers.kustomize.patches` for JSON Patch operations on Helm-generated manifests:
```yaml
postRenderers:
  - kustomize:
      patches:
        - target:
            group: networking.k8s.io
            version: v1
            kind: Ingress
            name: app-name
          patch: |-
            - op: add
              path: /metadata/annotations/key
              value: value
```

### 4. Hybrid Kustomize (Multiple Components)
**Use for:** Complex setups with multiple Helm releases, custom resources, and dependencies
**Structure:**
```
deployments/pathweb/cluster-services/{service}/
├── kustomization.yaml          # Orchestrates all components
├── helm.yaml                   # Main HelmRelease
├── helm-crds.yaml              # CRDs (separate)
├── helm-external.yaml          # External config
├── ocirepository.yaml          # Chart source
├── ciliumnetworkpolicy.yaml
├── custom-deployment.yaml
└── config/
    └── config-file.yaml
```

**kustomization.yaml orchestrates everything:**
```yaml
---
resources:
  - ocirepository.yaml
  - helm-crds.yaml
  - helm.yaml
  - custom-deployment.yaml
  - ciliumnetworkpolicy.yaml
```

## Adding a Deployment

1. **Choose pattern** based on requirements (Kustomize/Helm/Hybrid)
2. **Create workload directory:**
   ```
   deployments/pathweb/workloads/{category}/{app-name}/
   ```
3. **Add manifests** or helm.yaml according to chosen pattern
4. **Create index entry:**
   ```
   deployments/pathweb/_index_/workloads/{category}/{app-name}.yaml
   ```
5. **Reference in category index** (if it exists, update the parent index)
6. **Commit and push** - Flux will deploy within 15m

## Removing/Disabling a Deployment

### Soft-Removal (Preferred - Reversible)
Comment out the index entry:
```yaml
# ---
# apiVersion: kustomize.toolkit.fluxcd.io/v1
# kind: Kustomization
# ...
```
Flux will not deploy commented resources. Workload directory can be kept or deleted.

### Hard-Removal (Permanent)
1. Delete the index entry file: `deployments/pathweb/_index_/workloads/{category}/{app-name}.yaml`
2. Delete the workload directory: `deployments/pathweb/workloads/{category}/{app-name}/`
3. Flux will auto-cleanup resources with `prune: true`

## Code Style Guidelines

**YAML Formatting:**
- Use 4-space indentation (enforced by yamlfmt pre-commit hook)
- Trailing whitespace forbidden
- YAML documents separated by `---`

**Kubernetes Naming:**
- Metadata names: lowercase, hyphens only (no underscores)
- Namespaces: lowercase, descriptive (e.g., `home-network`, `portainer`)
- Labels follow `app.kubernetes.io/` convention: `name`, `version`, `component`

**Flux Patterns:**
- `interval: 15m` - standard check interval
- `prune: true` - Flux removes resources if removed from source
- `sourceRef: kind: GitRepository, name: rfhome-infrastructure` - standard reference
- `targetNamespace` - where Flux deploys the resources

**Sealed Secrets:**
- Sensitive files: `{name}.sealed.yaml` (encrypted)
- Also commit `{name}.secret.yaml` (plaintext template for documentation)
- Never commit actual credentials

**Labels & Annotations:**
- Standard: `app.kubernetes.io/name`, `app.kubernetes.io/version`
- Custom: `home.yrf.me/{key}` (e.g., `home.yrf.me/backup-to-okinawa-s3: 'true'`)
- Ingress annotations: Use `traefik.ingress.kubernetes.io/` prefix
- External DNS: Label `external-dns: local-pdns` for local resolution

**Node Selection:**
- Always include nodeSelector: `kubernetes.io/os: linux` and `location: rfhome`
- Use priorityClassName: `rfhome-network-critical` for critical services
- Consider pod affinity/anti-affinity for HA workloads

**Domain Naming:**
- Services: `{app}.{cluster}.clusters.home.yrf.me` (e.g., `portainer.pathweb.clusters.home.yrf.me`)
- Internal: Use local DNS (`home.yrf.me`)

## Talos Linux Configuration

Talos configuration is managed as Infrastructure as Code via Pulumi TypeScript. The `talos/pathweb/` directory contains generated artifacts only.

### Structure

**Authoritative Source (Pulumi):**
- `pulumi/rfhome/pathweb/talos-*.ts` - Cluster bootstrap and configuration
- `pulumi/rfhome/pathweb/config-patches/*.ts` - Configuration patches for nodes
- `pulumi/rfhome/pathweb/types/` - TypeScript type definitions
- `pulumi/Pulumi.homelab.yaml` - Configuration values (versions, networking, etc.)

**Generated Artifacts (DO NOT EDIT):**
- `talos/pathweb/machineconfig/` - Generated node configurations
- `talos/pathweb/base/` - Generated base configs (controlplane.yaml, worker.yaml)
- `talos/pathweb/patches/` - Generated patch files
- `talos/pathweb/talos-version.json` - Generated version information

**Deployment Scripts (Legacy):**
- `talos/pathweb/generate-configs.ps1` - Generates machine configs from Pulumi outputs
- `talos/pathweb/apply-configs.ps1` - Applies configs to cluster nodes
- `talos/pathweb/upgrade-talos.ps1` - Cluster upgrade script

### Modifying Talos Configuration

Always modify the **Pulumi source**, never the generated files:

1. **Update versions:** Modify `pulumi/Pulumi.homelab.yaml`
   - `talos-pathweb:talos-version` - Talos OS version
   - `talos-pathweb:kubernetes-version` - Kubernetes version

2. **Update patches:** Modify TypeScript files in `pulumi/rfhome/pathweb/config-patches/`
   - `node-patches.ts` - Common patches for all nodes
   - `controlplane-patches.ts` - Control plane specific patches
   - `worker-patches.ts` - Worker specific patches
   - `node-specific-patch.ts` - Per-node customizations
   - `watchdog.ts`, `seccomp-profiles.ts`, etc. - Specialized patches

3. **Update networking:** Modify `pulumi/Pulumi.homelab.yaml`
   - `talos-pathweb:pod-subnets`
   - `talos-pathweb:service-subnets`
   - `homelab:servers-vlan-subnet`

4. **Update node definitions:** Modify `pulumi/rfhome/pathweb/talos-nodes.ts`
   - Node addresses, hostnames, roles
   - VM specifications
   - Kubernetes labels

5. **Add system extensions:** Modify `pulumi/rfhome/pathweb/talos-schematics.ts`
   - Official Talos system extensions
   - Kernel arguments for specialized hardware

### Code Style Guidelines (Talos/Pulumi)

**TypeScript:**
- Use strict mode (enforced by tsconfig.json)
- Import from `@pulumiverse/talos` for Talos resources
- Use `pulumi.Config()` for configuration values
- Export patch functions/objects for composition in `talos-patches.ts`

**ConfigPatch Objects:**
- Follow Talos machine config schema
- Patches are merged in order defined in `getNodePatches()`
- Use `requireObject<Type>()` for structured config values
- Use `require()` for string values

**Example Patch Structure:**
```typescript
export const customPatch: ConfigPatch = {
  machine: {
    sysctls: {
      "key": value
    },
    network: { /* ... */ },
    kubelet: { /* ... */ }
  },
  cluster: {
    apiServer: { /* ... */ }
  }
}
```

## Validation

Run before committing:

```bash
# Install pre-commit hooks (first time)
pre-commit install

# Validate changes
pre-commit run --all-files
```

**Pre-commit checks:**
- YAML syntax and formatting (yamlfmt)
- Trailing whitespace and EOF fixes
- Secret detection (gitleaks)
- JSON/TOML validation

**Manual checks:**
- Verify Flux Kustomization references correct `path`
- Confirm `targetNamespace` matches intended deployment namespace
- Check sealed secrets exist for all sensitive data
- Ensure labels and selectors are consistent
- Verify nodeSelector/affinity matches cluster setup
