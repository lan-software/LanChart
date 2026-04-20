# Cluster-Scoped Operator Prerequisites

The `lan-software` umbrella chart **does not** install these operators — they
are cluster-wide (their CRDs affect every namespace) and belong to the
cluster operator, not the app chart. Install them once before the first
`helm install lan-software`.

## Install order

Run in this order (some have implicit dependencies on the Ingress controller
being up first so webhook admission works):

1. **ingress-nginx**
   ```sh
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
       -n ingress-nginx --create-namespace
   ```

2. **cert-manager**
   ```sh
   helm repo add jetstack https://charts.jetstack.io
   helm upgrade --install cert-manager jetstack/cert-manager \
       -n cert-manager --create-namespace \
       --set crds.enabled=true
   ```
   Then create a `ClusterIssuer`:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       email: you@example.com
       server: https://acme-v02.api.letsencrypt.org/directory
       privateKeySecretRef: { name: letsencrypt-prod-private-key }
       solvers:
         - http01: { ingress: { class: nginx } }
   ```

3. **CloudNativePG**
   ```sh
   helm repo add cnpg https://cloudnative-pg.github.io/charts
   helm upgrade --install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace
   ```

4. **Dragonfly Operator** (Redis wire-protocol compatible cache)
   ```sh
   kubectl apply -f https://raw.githubusercontent.com/dragonflydb/dragonfly-operator/main/manifests/dragonfly-operator.yaml
   ```

5. **MinIO Operator** *(optional — required only if any sub-chart uses `storage.mode: minio-tenant`)*
   ```sh
   helm repo add minio-operator https://operator.min.io
   helm upgrade --install minio-operator minio-operator/operator \
       -n minio-operator --create-namespace
   ```

6. **prometheus-operator / kube-prometheus-stack** *(optional — required only if `global.monitoring.enabled: true`)*
   ```sh
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
       -n monitoring --create-namespace
   ```

## Version matrix (targeting Kubernetes 1.31)

| Operator | Tested version | CRDs |
|----------|---------------|------|
| ingress-nginx | 4.11.x | — |
| cert-manager | 1.16.x | `certmanager.io`, `acme.cert-manager.io` |
| CloudNativePG | 1.24.x | `postgresql.cnpg.io/v1` |
| Dragonfly Operator | 1.1.x | `dragonflydb.io/v1alpha1` |
| MinIO Operator | 7.x | `minio.min.io/v2` |
| kube-prometheus-stack | 65.x | `monitoring.coreos.com/*` |

Pin these in `docs/operators.md` and bump them deliberately (CRD upgrades
are cluster-wide and not reversible by a chart uninstall).
