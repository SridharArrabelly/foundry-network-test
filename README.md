# Foundry Private Networking — Managed VNet

Deploy Azure AI Foundry Agents with private access to Foundry, Cosmos DB, Storage, and AI Search using the **Managed VNet** pattern, where the agent runtime lives inside a Microsoft-managed network boundary.

This is the recommended starting point for most private-networking scenarios.

> **New here?** Start with the [decision hub](https://github.com/SridharArrabelly/foundry-private-networking-samples) to choose between Managed VNet and BYO VNet.

## Why use this sample

Use this sample when you want:

- Private access to Foundry and the data layer
- A simpler deployment model with fewer networking decisions
- No customer-managed subnet sizing for agent compute
- A practical baseline you can adapt into production

If you need agent compute to live inside your own VNet, use the [BYO VNet sample](https://github.com/SridharArrabelly/foundry-private-byo-vnet) instead.

## What this sample proves

This sample demonstrates that an Azure AI Foundry agent can:

- Call **AI Search** privately
- Store thread state in **Cosmos DB** privately
- Upload files to **Storage** privately
- Work without public network exposure on the core data resources

## What this repo deploys

- Azure AI Foundry account and project
- Agent runtime inside a Microsoft-managed VNet
- BYO Cosmos DB, Storage, and AI Search
- `capabilityHost` binding between the project and the data layer
- Private networking and the required RBAC chain
- One-command deployment with `azd up`
- One-command teardown with `azd down`

## Architecture

See the detailed architecture walkthrough here:

- [Managed VNet architecture](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/architecture-diagrams/managed-vnet.md)
- [Side-by-side comparison with BYO VNet](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/architecture-diagrams/side-by-side.md)

At a high level:

- Agent compute runs in a Microsoft-managed VNet
- Cosmos DB, Storage, and AI Search are customer-owned resources
- `capabilityHost` binds those resources to the agent runtime
- The data layer stays private
- Correct RBAC, private endpoints, and DNS are required for end-to-end success

## Quick start

### Prerequisites

- An Azure subscription you can deploy into
- Azure CLI
- Azure Developer CLI (`azd`)
- Rights to create resources and assign required roles
- A target region that supports your chosen Foundry setup
- **VNet address space must be RFC 1918** (`10.0.0.0/8`, `172.16.0.0/12`, or `192.168.0.0/16`). CGNAT (`100.64.0.0/10`) and other Azure-reserved ranges fail at `capabilityHost` create — see [known limitations #10](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/known-limitations.md#10-rfc-1918-only--cgnat-and-reserved-ranges-fail-at-capabilityhost-create).
- **Resource providers registered:** the agent runtime needs both `Microsoft.App` and `Microsoft.ContainerService` registered on the target subscription before `azd up`. Without them, `capabilityHost` create fails.
  ```bash
  az provider register --namespace 'Microsoft.App'
  az provider register --namespace 'Microsoft.ContainerService'
  # Wait until both report Registered:
  az provider show -n 'Microsoft.App' --query registrationState -o tsv
  az provider show -n 'Microsoft.ContainerService' --query registrationState -o tsv
  ```

### Deploy

```bash
git clone https://github.com/SridharArrabelly/foundry-private-managed-vnet.git
cd foundry-private-managed-vnet
azd auth login

# Required: set the jumpbox local-admin password before `azd up` (12+ chars, mixed case + digits + symbols).
# `main.parameters.json` requires this and has no default — `azd up` will fail without it.
azd env set VM_ADMIN_PASSWORD '<your-strong-password>'

# Optional: pin a short prefix used in resource names (3–10 lowercase letters/digits)
azd env set PREFIX 'fun'

# Optional: keep one public IP/CIDR reachable (your laptop) while everything else stays private.
# Leave unset to disable all public exposure.
azd env set ALLOWED_IP_ADDRESS '<your-public-ip>'

azd up
```

You'll be prompted for `AZURE_ENV_NAME` and `AZURE_LOCATION` on first run. The samples are validated in `swedencentral`; other regions may require Foundry / capabilityHost preview availability checks.

### Tear down

```bash
azd down
```

## Validate the deployment

After `azd up` completes, run the **[7 copy-paste CLI checks](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/validation-checklist.md#cli-verification--7-concrete-checks)** in the parent docs. All 7 apply to Managed VNet (Check 3 confirms the MS-managed PEs were auto-approved by the Foundry account MI).

Checks 1–6 run from your dev box (`az` CLI + `nslookup` from a Bastion session). **Check 7** is a Python smoke test that runs from the jumpbox — to use it you need Python + the project's dependencies on the jumpbox, which is what `scripts/bootstrap-jumpbox.{ps1,sh}` sets up (see [Optional: populate sample data + bootstrap the jumpbox](#optional-populate-sample-data--bootstrap-the-jumpbox) below).

## Optional: populate sample data + bootstrap the jumpbox

> `azd up` provisions infrastructure only. It does **not** install Python on the jumpbox or index any sample data. Run this step **only** if you want the AI Search smoke test (validation Check 7) or File Search to have data to query. Most real customers will skip this and bring their own data + their own indexer.

The repo ships `data/sample_document.pdf` as a generic test corpus, and `scripts/bootstrap-jumpbox.{ps1,sh}` automates one-time setup of the jumpbox.

### What it does

Run from your dev box, against the active `azd` environment. It:

1. Reads `AZURE_RESOURCE_GROUP`, `JUMPBOX_VM_NAME`, `AI_SEARCH_ENDPOINT`, `AI_FOUNDRY_ENDPOINT` from `azd env get-values`
2. Calls `az vm run-command invoke` to push `scripts/jumpbox-bootstrap.ps1` to the jumpbox over the Azure backplane (no Bastion / RDP required)
3. The jumpbox-side script installs Python 3.12, downloads the repo zip, runs `scripts/setup_aisearch_index.py` (auth via the VM's system-assigned managed identity), and uploads embeddings for every `.pdf` / `.docx` under `data/`

### Run it

```bash
./scripts/bootstrap-jumpbox.sh      # macOS / Linux / WSL
./scripts/bootstrap-jumpbox.ps1     # Windows PowerShell
```

Takes ~5–10 minutes on first run. Re-running it is safe — Python install is skipped if already present, and the index is upserted.

### Use your own corpus

Drop `.pdf` / `.docx` files into `data/`, then re-run `bootstrap-jumpbox`. Override the index name with `AI_SEARCH_INDEX_NAME` before running if you want a non-default name.

### Point the agent at an existing index instead

If you already have an AI Search index you want to use, **skip this step entirely**. Set `AI_SEARCH_INDEX_NAME` to your index name when wiring up your agent — the infrastructure deployment does not assume `documents-index` exists.

### Clean up the sample index

```bash
az search index delete --service-name <ai-search-name> --name documents-index -y
```

Doesn't affect the rest of the infrastructure.

## Troubleshooting

The single most common silent failure is an agent run that returns:

```
Invalid endpoint or connection failed
```

That almost always means `capabilityHost` is missing or unbound. Start with [Design rationale → What happens if you skip capabilityHost](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/design-rationale.md#2-what-happens-if-you-skip-capabilityhost), then run [validation check #4](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/validation-checklist.md#check-4--capabilityhost-is-bound-to-all-3-connections).

For other failure modes (deployment errors, RBAC, DNS, region capacity), see the [Troubleshooting order](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/capabilityhost-rbac-dns.md#troubleshooting-order) and [Known limitations](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/known-limitations.md).

## Related docs

- [Decision hub (parent)](https://github.com/SridharArrabelly/foundry-private-networking-samples) — when to pick Managed VNet vs BYO
- [Compare with BYO VNet](https://github.com/SridharArrabelly/foundry-private-byo-vnet) — the other sample in this family
- [Managed VNet architecture](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/architecture-diagrams/managed-vnet.md) — diagram + component walkthrough
- [Side-by-side architecture comparison](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/architecture-diagrams/side-by-side.md)
