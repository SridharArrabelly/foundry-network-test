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
azd up
```

### Tear down

```bash
azd down
```

## Validate the deployment

After `azd up` completes, run the **[7 copy-paste CLI checks](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/validation-checklist.md#cli-verification--7-concrete-checks)** to prove the full chain works end-to-end:

1. provisioning state → 2. public network OFF on all 4 data resources → 3. managed PEs approved → 4. `capabilityHost` bound to all 3 connections → 5. connections use `authType: AAD` → 6. DNS resolves to private IPs from jumpbox → 7. agent smoke test returns `completed`

## Troubleshooting

The single most common silent failure is an agent run that returns:

```
Invalid endpoint or connection failed
```

That almost always means `capabilityHost` is missing or unbound. Start with [Design rationale → What happens if you skip capabilityHost](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/design-rationale.md#what-happens-if-you-skip-capabilityhost), then run [validation check #4](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/validation-checklist.md#check-4--capabilityhost-is-bound-to-all-3-connections).

For other failure modes (deployment errors, RBAC, DNS, region capacity), see the [Troubleshooting order](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/capabilityhost-rbac-dns.md#troubleshooting-order) and [Known limitations](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/known-limitations.md).

## Related docs

- [Compare with BYO VNet](https://github.com/SridharArrabelly/foundry-private-byo-vnet)
- [Decision hub](https://github.com/SridharArrabelly/foundry-private-networking-samples)
- [Managed VNet architecture](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/architecture-diagrams/managed-vnet.md)
- [Side-by-side architecture comparison](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/architecture-diagrams/side-by-side.md)
- [Design rationale](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/design-rationale.md) — the four "why" questions, including what to check when you see `Invalid endpoint or connection failed`
- [Shared data plane](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/shared-data-plane.md)
- [capabilityHost, RBAC, and DNS](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/capabilityhost-rbac-dns.md)
- [Validation checklist](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/validation-checklist.md) — 7 copy-paste CLI checks
- [Known limitations](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/known-limitations.md)
