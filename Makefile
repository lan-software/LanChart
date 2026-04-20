SHELL := /usr/bin/env bash

CHARTS := lan-common lancore lanbrackets lanentrance lanshout lanhelp lan-software
UMBRELLA := charts/lan-software
DEV_VALUES := examples/values-dev-kind.yaml
KIND_CLUSTER ?= lan-software-dev
K8S_VERSION ?= 1.31.0
NS ?= lan-software
RELEASE ?= lan-software

.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: dep-up
dep-up: ## Resolve Chart.yaml dependencies for the umbrella
	helm dependency update $(UMBRELLA)

.PHONY: lint
lint: dep-up ## helm lint across all charts
	@set -e; for chart in $(CHARTS); do \
	  echo "== helm lint charts/$$chart =="; \
	  helm lint charts/$$chart; \
	done

.PHONY: template
template: dep-up ## Render the umbrella to stdout with the dev values
	helm template $(RELEASE) $(UMBRELLA) -f $(DEV_VALUES) --namespace $(NS)

.PHONY: kubeconform
kubeconform: dep-up ## Validate rendered manifests against Kubernetes schemas
	helm template $(RELEASE) $(UMBRELLA) -f $(DEV_VALUES) --namespace $(NS) \
	  | kubeconform -strict -summary -kubernetes-version $(K8S_VERSION) \
	      -schema-location default \
	      -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

.PHONY: unittest
unittest: ## Run helm-unittest (requires the plugin)
	@for chart in $(CHARTS); do \
	  if [ -d charts/$$chart/tests ]; then \
	    echo "== helm unittest charts/$$chart =="; \
	    helm unittest charts/$$chart || exit 1; \
	  fi; \
	done

.PHONY: kind-up
kind-up: ## Create a local kind cluster
	kind create cluster --name $(KIND_CLUSTER) --image kindest/node:v$(K8S_VERSION) || true
	kubectl cluster-info --context kind-$(KIND_CLUSTER)

.PHONY: kind-down
kind-down: ## Delete the local kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

.PHONY: prereqs
prereqs: ## Install cluster-scoped prerequisite operators (destructive — targets current context!)
	kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx
	kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --set crds.enabled=true
	kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install cnpg cnpg/cloudnative-pg -n cnpg-system
	kubectl apply -f https://raw.githubusercontent.com/dragonflydb/dragonfly-operator/main/manifests/dragonfly-operator.yaml

.PHONY: install-dev
install-dev: dep-up ## helm install the umbrella with the dev values
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl label namespace $(NS) pod-security.kubernetes.io/enforce=baseline --overwrite
	helm upgrade --install $(RELEASE) $(UMBRELLA) -n $(NS) -f $(DEV_VALUES)

.PHONY: uninstall-dev
uninstall-dev: ## helm uninstall the dev release
	helm uninstall $(RELEASE) -n $(NS) || true

.PHONY: smoke
smoke: ## Smoke-test each app's /up endpoint via an in-cluster curl pod
	@for app in lancore lanbrackets lanentrance lanshout lanhelp; do \
	  echo "== smoke $$app =="; \
	  kubectl -n $(NS) run --rm -i curl-$$app --image=curlimages/curl --restart=Never -- \
	    curl -fsSL --max-time 10 http://$$app-web.$(NS).svc.cluster.local/up \
	    || echo "FAIL: $$app"; \
	done

.PHONY: package
package: dep-up ## helm package all charts into dist/
	mkdir -p dist
	@for chart in $(CHARTS); do \
	  helm package charts/$$chart -d dist || exit 1; \
	done

.PHONY: schema-validate
schema-validate: dep-up ## Render every chart and cross-check against its values.schema.json
	@set -e; for chart in $(CHARTS); do \
	  if [ -f "charts/$$chart/values.schema.json" ]; then \
	    echo "== schema-validate charts/$$chart =="; \
	    helm template "validate-$$chart" "charts/$$chart" --values "charts/$$chart/values.yaml" > /dev/null; \
	  else \
	    echo "-- skip charts/$$chart (no values.schema.json)"; \
	  fi; \
	done

.PHONY: verify-hostnames
verify-hostnames: dep-up ## Assert every rendered Ingress host aligns with global.domain (no example.com leaks)
	@set -e; \
	for values in $(DEV_VALUES) examples/values-prod.yaml; do \
	  echo "== verify-hostnames $$values =="; \
	  leaks=$$(helm template $(RELEASE) $(UMBRELLA) -n $(NS) -f $$values \
	    | awk '/^[[:space:]]+- host:/' \
	    | grep -E 'example\.com' || true); \
	  if [ -n "$$leaks" ]; then \
	    echo "FAIL: example.com hostname leak:"; echo "$$leaks"; exit 1; \
	  fi; \
	  echo "  clean"; \
	done

.PHONY: policy-check
policy-check: dep-up ## Render prod values and run conftest against policies/
	@command -v conftest >/dev/null 2>&1 || { echo "conftest not installed: see docs/supply-chain.md"; exit 1; }
	helm template $(RELEASE) $(UMBRELLA) -n $(NS) -f examples/values-prod.yaml \
	  | conftest test --policy policies/ -

.PHONY: sign-local
sign-local: ## Sign a local chart tarball with cosign (keyful if COSIGN_KEY=…, else keyless OIDC)
	@test -n "$(CHART_TGZ)" || { echo "CHART_TGZ=dist/<chart>.tgz required"; exit 2; }
	@test -n "$(OCI_REF)"   || { echo "OCI_REF=oci://ghcr.io/lan-software/charts/<chart>:<tag> required"; exit 2; }
	scripts/cosign-sign.sh $(OCI_REF)
	scripts/sbom-attach.sh $(CHART_TGZ) $(OCI_REF)

.PHONY: release-dry
release-dry: dep-up ## Dry-run of the release path: package + cosign sign (local key) against a fake ref
	mkdir -p dist
	@for chart in $(CHARTS); do helm package charts/$$chart -d dist; done
	@echo "dry-run done — packaged charts in dist/. Use 'make sign-local CHART_TGZ=… OCI_REF=…' to exercise cosign."

.PHONY: clean
clean: ## Remove packaged chart tarballs and resolved dependencies
	rm -rf dist sbom
	@for chart in $(CHARTS); do \
	  rm -rf charts/$$chart/charts charts/$$chart/Chart.lock; \
	done
