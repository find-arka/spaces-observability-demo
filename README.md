# spaces-observability-demo

GitOps content that Argo CD (Akuity) syncs into Upbound Spaces managed control planes
(Crossplane 2.x) to give an observability demo real work to reconcile.

```
akuity/                       applied to the Akuity Argo CD instance
  appproject-crossplane.yaml  only *.crossplane.io and *.upbound.io APIs may sync
  appset-packages.yaml        -> packages/  Provider + Configuration
  appset-configs.yaml         -> configs/   ProviderConfigs (Azure, HTTP)
  appset-samples.yaml         -> samples/   Helm chart, one set per control plane
packages/   provider-http v1.0.15, configuration-azure-aks v2.0.3 (+ its dependencies)
configs/    azure.m.upbound.io and http.m.crossplane.io ProviderConfigs in namespace default
samples/    Network + AKS XRs (id demo-<ctp>), healthy and failing HTTP requests
```

Each ApplicationSet selects every Akuity cluster labeled
`upbound.io/kind=crossplane-controlplane` and names its Application
`<ctp>-packages`, `<ctp>-configs` and `<ctp>-samples`, using the `upbound.io/controlplane`
label. The samples chart takes that label as `controlPlane`.

## What each control plane gets

| Resource | Purpose |
|---|---|
| `Network` + `AKS` (`azure.platform.upbound.io/v1alpha1`) | Real Azure resources in `eastus`: resource group `demo-<ctp>-rg`, VNet, subnet, 1-node `Standard_B2s` AKS 1.34 |
| `Request` `<ctp>-healthy-observe` | Observe-only GET of `https://jsonplaceholder.typicode.com/posts/1` every poll |
| `DisposableRequest` `<ctp>-healthy-poll` | GET of `/todos/1` every 2 minutes |
| `Request` `<ctp>-failing` | Targets `does-not-exist.invalid`; fails every reconcile to drive error metrics |

Set `azure.aks.enabled=false` in `samples/values.yaml` to skip the AKS cluster.

## Prerequisites

- Control planes registered to Akuity with the labels above.
- Secret `azure-creds` in namespace `default` of each control plane, key `credentials`,
  holding the output of `az ad sp create-for-rbac --json-auth`. It is delivered outside Git
  (for example with a Spaces `SharedExternalSecret`); the AppProject blocks core Secrets.
- The service principal needs rights to create resource groups in the subscription
  (Contributor at subscription scope); the Network composition creates its own resource group.

## Ordering

The three Applications sync independently. CRDs for ProviderConfigs and samples exist only after
the packages install, so every Application uses `SkipDryRunOnMissingResource=true` and retries
without limit (30s backoff, capped at 3m). Expect `configs` and `samples` to fail and retry for
a few minutes on a new control plane.

## Apply

```bash
akuity argocd apply --organization-id "$AKUITY_ORG_ID" --name "$AKUITY_INSTANCE" \
  -f akuity/appproject-crossplane.yaml \
  -f akuity/appset-packages.yaml \
  -f akuity/appset-configs.yaml \
  -f akuity/appset-samples.yaml
```

## Teardown

Delete the `Network` and `AKS` XRs first (remove `samples/templates/azure.yaml` or set
`azure.aks.enabled=false`, then commit) so Crossplane deletes the Azure resources before the
control planes go away. The ApplicationSets use `preserveResourcesOnDeletion: true`, so
deleting an ApplicationSet leaves resources in place.
