# Foundry Network Test

End-to-end private networking test for **Azure AI Foundry** and **Azure AI Search** communicating over private endpoints. Built to validate a client's network configuration before a support call.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  VNet: 10.0.0.0/16                                              │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │ snet-pe          │  │ snet-vm          │  │ AzureBastion  │ │
│  │ 10.0.1.0/24      │  │ 10.0.2.0/24      │  │ 10.0.3.0/26   │ │
│  │                  │  │                  │  │               │ │
│  │ ● PE (Foundry)   │  │ ● Windows 11 VM  │  │ ● Bastion     │ │
│  │ ● PE (AI Search) │  │   (jumpbox, MI)  │  │  (Standard)   │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
│                                                                  │
│  Private DNS Zones (linked to VNet):                            │
│  • privatelink.cognitiveservices.azure.com → AI Foundry PE IP   │
│  • privatelink.search.windows.net → AI Search PE IP             │
└─────────────────────────────────────────────────────────────────┘

                    RBAC (System MIs)
    ┌──────────────┐ ──────────────────► ┌──────────────┐
    │ AI Foundry   │  Search Index Data   │  AI Search   │
    │ (AIServices) │  Contributor +       │  (basic SKU) │
    │              │  Search Service      │              │
    │ Models:      │  Contributor         │  Index:      │
    │ • embedding  │                      │  documents-  │
    │   -3-large   │                      │  index       │
    │ • gpt-4.1-   │                      │              │
    │   mini       │                      │              │
    └──────────────┘                      └──────────────┘
           ▲                                     ▲
           │ Cognitive Services                  │ Search Index Data
           │ OpenAI User                         │ Contributor +
           │                                     │ Search Service
           │                                     │ Contributor
           └─────────────┬───────────────────────┘
                  ┌──────┴───────┐
                  │ Jumpbox VM   │
                  │ (System MI)  │
                  └──────────────┘
```

## Resources Deployed

| Resource | Type | Purpose |
|----------|------|---------|
| VNet | `Microsoft.Network/virtualNetworks` | Hosts all subnets for private connectivity |
| PE Subnet | Subnet (10.0.1.0/24) | Private endpoints for AI services |
| VM Subnet | Subnet (10.0.2.0/24) | Jumpbox VM |
| Bastion Subnet | AzureBastionSubnet (10.0.3.0/26) | Azure Bastion host |
| AI Foundry | `Microsoft.CognitiveServices/accounts` (kind: AIServices) | AI Services with project management |
| Foundry Project | `accounts/projects` | Foundry project for model management |
| text-embedding-3-large | Model deployment (GlobalStandard) | Embedding model for vectorizing documents (3072 dims) |
| gpt-4.1-mini | Model deployment (GlobalStandard) | Chat/completion model |
| AI Search | `Microsoft.Search/searchServices` (basic) | Search index for document chunks |
| RBAC: Foundry MI → Search | Search Index Data Contributor + Search Service Contributor | Lets Foundry read/write the search index |
| RBAC: Jumpbox MI → Search | Search Index Data Contributor + Search Service Contributor | Lets the indexer (running on the jumpbox) create the index and upload chunks |
| RBAC: Jumpbox MI → Foundry | Cognitive Services OpenAI User | Lets the indexer call the embedding model |
| Private Endpoint (Foundry) | `Microsoft.Network/privateEndpoints` | Private connectivity to AI Foundry |
| Private Endpoint (Search) | `Microsoft.Network/privateEndpoints` | Private connectivity to AI Search |
| Private DNS Zone (Foundry) | `privatelink.cognitiveservices.azure.com` | DNS resolution for Foundry PE |
| Private DNS Zone (Search) | `privatelink.search.windows.net` | DNS resolution for Search PE |
| Windows 11 VM | `Microsoft.Compute/virtualMachines` (Standard_B2ms, System MI) | Jumpbox for testing private access and running the indexer |
| Azure Bastion | `Microsoft.Network/bastionHosts` (Standard, tunneling enabled) | Secure RDP / native client tunneling to VM without public IP |

## Prerequisites

- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed — already present in Azure Cloud Shell
- Azure CLI (`az`) installed and authenticated — used by `azd` for some operations and by the postprovision hook to invoke the indexer on the jumpbox
- Subscription with **Owner** role (or Contributor + RBAC Administrator) — required because the deployment creates role assignments
- A clone of this repository (the postprovision hook reads the git remote to know where the jumpbox should download the code from)

You do **not** need Python installed locally — Python is installed on the jumpbox VM by the postprovision script and used there.

## Deployment

### 1. Deploy Infrastructure

```bash
# First time only: log in and create an environment
azd auth login
azd env new <your-env-name>     # pick any name, e.g. foundry-net-dev

# (Optional) set non-default values BEFORE running azd up
azd env set ALLOWED_IP_ADDRESS  <your.public.ip>   # only if you want portal access from your IP
azd env set VM_ADMIN_USERNAME   azureadmin
azd env set PREFIX              <lowercase-prefix>   # defaults to env name

# Deploy
azd up
```

`azd up` will prompt for the Azure subscription, location, and the required `vmAdminPassword` (stored securely, not written to disk). All other values come from the azd environment.

After provisioning succeeds, the `postprovision` hook runs `scripts/setup_aisearch_index.py` **on the jumpbox VM** via `az vm run-command`. The hook itself runs wherever you invoked `azd up` (your machine or Cloud Shell); it bootstraps Python on the VM, downloads this repo from GitHub, and runs the indexer using the VM's system-assigned managed identity (which has been granted Search + Foundry RBAC by the deployment).

This works the same from Cloud Shell as from a local machine — `ALLOWED_IP_ADDRESS` does **not** need to be set, because all indexer traffic to the private endpoints originates from the jumpbox (which is on the VNet).

Assumption: this GitHub repo is public (so the jumpbox can download it via HTTPS without auth). If you fork to a private repo, replace the download step in `scripts/jumpbox-bootstrap.ps1` accordingly.

Expected first-run timings:
- `azd provision`: ~10–15 minutes (Bastion + VM dominate)
- `postprovision` hook on the jumpbox: ~5–10 minutes (Python install + pip + indexing)

Environment variables consumed by `infra/main.parameters.json`:

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_ENV_NAME` | yes (set by `azd env new`) | Used to name the resource group (`rg-<env>`) and tag resources |
| `AZURE_LOCATION` | yes (prompted by `azd up`) | Azure region (e.g. `australiaeast`, `eastus`) |
| `PREFIX` | no | Resource name prefix (lowercase, no special chars). Defaults to `AZURE_ENV_NAME` |
| `ALLOWED_IP_ADDRESS` | no | Your public IP for portal access. Empty = fully private |
| `VM_ADMIN_USERNAME` | no | Jumpbox admin user (default: `azureadmin`) |
| `VM_ADMIN_PASSWORD` | yes (prompted) | Jumpbox admin password (12+ chars, upper/lower/number/special) |

### 2. Connect to Jumpbox via Bastion (optional — for manual exploration)

The indexer has already run automatically. Connect to the jumpbox if you want to use the Foundry/Search portals interactively, inspect the index, or re-run the indexer manually.

1. Azure Portal → your resource group → `bas-<prefix>` (Bastion)
2. Click **Connect** → select `vm-<prefix>`
3. Enter the admin credentials you set during `azd up`
4. From the VM, open a browser — you now have private access to:
   - Foundry portal: `https://ai.azure.com`
   - AI Search portal: `https://srch-<prefix>.search.windows.net`

Or via CLI (Bastion native client tunneling is enabled):
```bash
az network bastion rdp \
  --name bas-<prefix> \
  --resource-group rg-<env> \
  --target-resource-id $(az vm show -g rg-<env> -n vm-<prefix> --query id -o tsv)
```

### 3. Re-run the indexer manually (optional)

The `postprovision` hook runs automatically on `azd up`. To re-run it later — for example after dropping new files into `data/` and pushing them to the repo — call the hook script directly:

```bash
# from Cloud Shell or your local machine, in the repo root, after azd env is loaded
./scripts/postprovision.sh        # Linux / macOS / Cloud Shell
./scripts/postprovision.ps1       # Windows PowerShell
```

Or skip the wrapper and invoke it via azd:
```bash
azd hooks run postprovision
```

To run the indexer interactively *on the jumpbox* (e.g. for debugging), connect via Bastion and from a PowerShell prompt:
```powershell
# the bootstrap script is the same one the hook invokes
pwsh C:\Path\To\jumpbox-bootstrap.ps1 `
  -RepoUrl https://github.com/SridharArrabelly/foundry-network-test.git `
  -RepoBranch master `
  -AiSearchEndpoint  https://srch-<prefix>.search.windows.net `
  -AiFoundryEndpoint https://ais-<prefix>.cognitiveservices.azure.com
```

## Project Structure

```
foundry-network-test/
├── .azure/                       # azd environment state (git-ignored)
├── .gitignore
├── azure.yaml                    # azd project + postprovision hook wiring
├── README.md
├── data/                         # Drop .docx files here and commit them; the jumpbox downloads the repo zip
├── scripts/
│   ├── requirements.txt          # Python dependencies (installed on the jumpbox)
│   ├── setup_aisearch_index.py   # Creates index, chunks, embeds, uploads (auth via DefaultAzureCredential)
│   ├── jumpbox-bootstrap.ps1     # Runs ON the jumpbox: installs Python, pulls repo, runs the indexer
│   ├── postprovision.ps1         # azd postprovision hook (Windows / Cloud Shell pwsh)
│   └── postprovision.sh          # azd postprovision hook (Linux / macOS / Cloud Shell bash)
└── infra/
    ├── main.bicep                # Subscription-scope entry point (creates RG)
    ├── main.parameters.json      # azd → bicep parameter bindings
    ├── resources.bicep           # Resource-group-scope orchestrator
    └── modules/
        ├── network.bicep         # VNet + subnets (PE, VM, Bastion)
        ├── ai-foundry.bicep      # AI Services + project + model deployments
        ├── ai-search.bicep       # AI Search (basic SKU)
        ├── role-assignments.bicep # RBAC: Foundry MI + Jumpbox MI → Search + Foundry
        ├── private-endpoints.bicep # PEs + DNS zones + VNet links
        └── jumpbox.bicep         # Windows VM (System MI) + Azure Bastion
```

## Network Flow

1. **Foundry → AI Search**: Uses Foundry's system-assigned MI over the private endpoint. Traffic stays on the Azure backbone.
2. **Jumpbox → AI Search / Foundry (indexer)**: VM resolves the privatelink DNS zones to PE IPs, authenticates with the VM's system-assigned MI, and calls both services over the private endpoints.
3. **You → Foundry/Search portals**: Connect to the jumpbox via Bastion; the VM resolves private DNS to PE IPs.
4. **Cloud Shell / your laptop → Jumpbox indexer**: The `postprovision` hook reaches the jumpbox via the Azure ARM control plane (`az vm run-command`), which does not require network connectivity to the private endpoints from your machine.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `IfMatchPreconditionFailed` during provision | Two resources updated the same parent in parallel. The template already serializes the known cases (two PEs on one subnet, role assignments on one scope). If a new one appears, add an explicit `dependsOn`. |
| `InsufficientQuota` on embedding deployment | Lower `capacity` in `infra/modules/ai-foundry.bicep` or request quota in your region. |
| `Cognitive Services OpenAI User` 403 from the indexer | RBAC propagation can take 5–10 minutes; re-run `azd hooks run postprovision`. |
| `Private network access required` in Foundry portal | Access from jumpbox VM via Bastion, or set `azd env set ALLOWED_IP_ADDRESS <your.ip>` and re-provision. |
| DNS not resolving to private IP | Verify private DNS zones are linked to VNet: Portal → DNS Zone → Virtual network links. |
| Bastion can't connect | `AzureBastionSubnet` must be /26; Bastion takes ~5 min to provision. |
| Postprovision hook fails: "VM not found" | Check `azd env get-values` includes `JUMPBOX_VM_NAME` and `AZURE_RESOURCE_GROUP`. Re-run `azd provision` if missing. |
| `az vm run-command` times out | The bootstrap takes up to 10 min on first run (Python install). Retry with `azd hooks run postprovision`. |
| Hook prints "Indexer failed on jumpbox" with stderr | The bootstrap surfaces the VM-side error. Common causes: parser errors if you edit `jumpbox-bootstrap.ps1` with PowerShell 7+ syntax (the VM runs Windows PowerShell **5.1** — avoid `?.`, `??`, ternary, etc.); or transient RBAC propagation (re-run the hook after a few minutes). |
| Python installer returns exit code `1603` | Python is already installed on the jumpbox from a prior run. The bootstrap checks `C:\Python312\python.exe` first to skip re-install — pull latest and re-run the hook. |
| `ModuleNotFoundError: No module named 'encodings'` on the jumpbox | Python's `sys.prefix` was derived from cwd instead of the install dir. The bootstrap sets `PYTHONHOME` to pin it. Pull latest. |
| `UnicodeEncodeError: 'charmap' codec can't encode` on the jumpbox | Windows console defaults to cp1252. The bootstrap sets `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1`. Pull latest. |

## Cleanup

```bash
azd down --purge --force
```

`--purge` permanently removes soft-deleted Cognitive Services / Key Vault resources so the prefix can be reused. Omit `--force` if you want to be prompted for confirmation.
