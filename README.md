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

## Sample data and the test index

The `data/` folder ships with `sample_document.pdf` as a generic placeholder corpus, used purely to prove the private **AI Search** path works end-to-end. During `azd up`, the postprovision hook runs `scripts/setup_aisearch_index.py` on the jumpbox, which:

- Creates an AI Search index named `documents-index` (override with the `AI_SEARCH_INDEX_NAME` env var)
- Reads every `.docx` and `.pdf` file under `data/`, chunks the content, generates embeddings via Azure OpenAI, and uploads them

To test with your own corpus, drop your `.docx` / `.pdf` files into `data/` and re-run either:

```bash
azd provision    # re-runs the full postprovision hook
# or, from the jumpbox directly:
python scripts/setup_aisearch_index.py
```

Once testing is done, you have two options — neither affects the rest of the infrastructure:

- **Delete the sample index** when you no longer need it:
  ```bash
  az search index delete --service-name <ai-search-name> --name documents-index -y
  ```
- **Point the agent at your own existing AI Search index** instead — set `AI_SEARCH_INDEX_NAME` in your `.env` to your index name before `azd provision`, and skip the sample indexer by emptying `data/`.

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
