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

After deployment, validate the following:

- You can reach the Foundry experience through the intended private access path
- The agent can call AI Search
- Thread state is written to Cosmos DB
- File operations land in Storage
- Public network access is not required on the core data resources

For a full checklist, see the [Validation checklist](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/validation-checklist.md).

## Troubleshooting

If deployment succeeds but the scenario does not work end-to-end, check these first:

- Private endpoint provisioning and approval state
- Private DNS resolution
- RBAC timing and sequencing
- Post-provision steps that depend on resource readiness
- Region-specific support or platform constraints

Deeper explanation: [capabilityHost, RBAC, and DNS](https://github.com/SridharArrabelly/foundry-private-networking-samples/blob/master/docs/capabilityhost-rbac-dns.md).

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
