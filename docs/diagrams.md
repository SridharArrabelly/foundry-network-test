# Architecture Diagrams — Managed VNet flavor

Four diagrams, each answering one question. Read them top-to-bottom on first visit; jump straight to a specific one on follow-ups. All diagrams use the same colour legend so concepts stay recognisable across views.

## Colour legend

| Colour | Meaning |
|---|---|
| 🟦 Blue | **Your** VNet, subnets, resources, identities |
| 🟪 Purple | **Microsoft-managed** components — the hidden VNet that hosts the agent runtime and its auto-created PEs |
| 🟧 Orange | **Private Endpoint / DNS** — solid border = yours, dashed border = Microsoft-created |
| 🟩 Green | **Identity / RBAC** — managed identities and role assignments |

There is **no grey path** — the entire architecture is private. If you ever see a "public internet" arrow, that's a bug.

---

## 1. Solution context — what did we deploy and why?

The big picture. Two VNets are involved: yours (everything you can see) and a hidden Microsoft-managed VNet that hosts the agent runtime. Each VNet has its **own** PE to each backend — that's the dual-PE design that lets `publicNetworkAccess=Disabled` work for both you and the runtime.

```mermaid
flowchart TB
  USER(("👤 You<br/>(laptop)"))

  subgraph YOUR["🟦 Your VNet — vnet-PREFIX (10.0.0.0/16)"]
    direction TB

    subgraph SNET_PE["snet-pe — 10.0.1.0/24"]
      PE_FND["pep-foundry"]:::pe
      PE_SRCH["pep-search"]:::pe
      PE_COSMOS["pep-cosmos"]:::pe
      PE_BLOB["pep-blob"]:::pe
      PE_AMPLS["pep-ampls"]:::pe
    end

    subgraph SNET_VM["snet-vm — 10.0.2.0/24"]
      VM["Jumpbox VM<br/>(Win11 + system MI)"]:::yours
      NAT["NAT Gateway<br/>(egress for pip / git)"]:::yours
    end

    subgraph SNET_BAS["AzureBastionSubnet — 10.0.3.0/26"]
      BAS["Azure Bastion<br/>(browser RDP)"]:::yours
    end
  end

  subgraph MSVNET["🟪 Microsoft-managed VNet (hidden from you)"]
    AGENT["Agent runtime<br/>(Microsoft-owned compute)"]:::msft
    MPE_SRCH["managed-pe → Search"]:::msftpe
    MPE_COSMOS["managed-pe → Cosmos"]:::msftpe
    MPE_BLOB["managed-pe → Storage"]:::msftpe
  end

  subgraph BACKEND["🟦 Data plane — publicNetworkAccess: Disabled on every resource"]
    FND["Foundry account<br/>ais-PREFIX"]:::yours
    SRCH["AI Search<br/>srch-PREFIX"]:::yours
    COSMOS["Cosmos DB<br/>cosmos-PREFIX"]:::yours
    BLOB["Storage<br/>stPREFIX"]:::yours
    OBS["App Insights + LAW<br/>via AMPLS"]:::yours
  end

  USER ==HTTPS==> BAS
  BAS --> VM
  VM ==Foundry portal==> PE_FND

  AGENT ==AI Search tool==> MPE_SRCH
  AGENT ==thread state==> MPE_COSMOS
  AGENT ==files==> MPE_BLOB
  AGENT -.telemetry.-> PE_AMPLS

  PE_FND --> FND
  PE_SRCH --> SRCH
  PE_COSMOS --> COSMOS
  PE_BLOB --> BLOB
  PE_AMPLS --> OBS
  MPE_SRCH --> SRCH
  MPE_COSMOS --> COSMOS
  MPE_BLOB --> BLOB

  classDef yours fill:#dbeafe,stroke:#1e3a8a,color:#000
  classDef msft fill:#ede9fe,stroke:#5b21b6,color:#000
  classDef pe fill:#fed7aa,stroke:#9a3412,color:#000
  classDef msftpe fill:#fed7aa,stroke:#5b21b6,stroke-dasharray: 5 5
```

**Three things to notice:**

1. **Two VNets** are involved. You only see and own the blue one. The purple one is provisioned and operated by Microsoft as part of the Foundry account.
2. **Two PEs to each backend** — your `pep-*` (solid orange) and Microsoft's `managed-pe` (dashed orange). They are physically separate Azure resources, in different VNets, but they point to the same target.
3. The `capabilityHost` resource is what triggers Microsoft to create the dashed PEs. Without it, the agent runtime has no path to your backends and every tool call fails with *"Invalid endpoint or connection failed"*.

---

## 2. Network topology — where does every packet go?

Same components, drawn to make the **DNS resolution path** explicit. The key insight: there are **two DNS resolution contexts** here — yours and Microsoft's. They independently resolve the same FQDN to different PE IPs.

```mermaid
flowchart LR
  subgraph YOUR["🟦 Your VNet"]
    direction TB
    DNS_YOU["Your Private DNS Zones<br/>(linked to your VNet)"]:::pe

    subgraph PE_SUB["snet-pe"]
      PEs["5 PEs<br/>(yours)"]:::pe
    end

    subgraph VM_SUB["snet-vm"]
      JMP["Jumpbox"]:::yours
    end
  end

  subgraph MSVNET["🟪 Microsoft-managed VNet"]
    DNS_MS["Microsoft's<br/>Private DNS Zones"]:::pe
    RUNTIME["Agent runtime"]:::msft
    MPEs["3 managed PEs<br/>(MS-created)"]:::msftpe
  end

  JMP -->|"1. resolve srch-PREFIX.search.windows.net"| DNS_YOU
  DNS_YOU -->|"2. returns 10.0.1.x (your PE IP)"| JMP
  JMP -->|"3. TCP to 10.0.1.x"| PEs

  RUNTIME -->|"1. resolve same FQDN"| DNS_MS
  DNS_MS -->|"2. returns MS-VNet PE IP"| RUNTIME
  RUNTIME -->|"3. TCP through managed-pe"| MPEs

  subgraph TARGETS["🟦 Data resources (no public IP)"]
    T1["Search / Cosmos / Storage / Foundry / App Insights"]:::yours
  end

  PEs --> TARGETS
  MPEs --> TARGETS

  classDef yours fill:#dbeafe,stroke:#1e3a8a,color:#000
  classDef msft fill:#ede9fe,stroke:#5b21b6,color:#000
  classDef pe fill:#fed7aa,stroke:#9a3412,color:#000
  classDef msftpe fill:#fed7aa,stroke:#5b21b6,stroke-dasharray: 5 5
```

**Debugging tip — when something fails, identify which path is broken:**

| Symptom | Likely path | Check |
|---|---|---|
| You can't open `https://ais-…` from jumpbox | Your DNS / your PE | `nslookup` should return `10.0.1.x` |
| Agent fails with *"Invalid endpoint or connection failed"* | Microsoft path | `capabilityHost` missing or managed PEs not approved |
| Indexer script works from jumpbox, agent run-time fails | The two paths diverged | Run `az network private-endpoint list -g $RG` (yours only) — managed ones aren't visible here, check the Managed VNet outbound rules instead |

---

## 3. Identity & RBAC chain — who is allowed to do what, in what order?

Identical structure to the BYO flavor — the data layer is the same. The one extra role here is the **account-level network connection approver**, which lets the Foundry account auto-approve the managed PEs Microsoft creates on your behalf.

```mermaid
flowchart TB
  subgraph PHASE0["Phase 0 — Account-level (one-time)"]
    direction LR
    FND_MI(("Foundry account MI<br/>(system-assigned)")):::id
    FND_MI -->|Azure AI Enterprise<br/>Network Connection Approver| RG_SCOPE["Resource Group"]:::yours
  end

  subgraph PHASE1["Phase 1 — Pre-capabilityHost (set BEFORE capHost is created)"]
    direction LR
    PROJ_MI(("Project MI<br/>(system-assigned)")):::id
    PROJ_MI -->|Storage Blob Data Contributor| ST1["Storage account"]:::yours
    PROJ_MI -->|Cosmos DB Operator| CX1["Cosmos DB"]:::yours
    PROJ_MI -->|Search Index Data Contributor<br/>+ Search Service Contributor| SR1["AI Search"]:::yours
  end

  CAPHOST{{"capabilityHost provisioning<br/>(binds connections, triggers managed PE creation)"}}:::id

  subgraph PHASE2["Phase 2 — Post-capabilityHost (granted AFTER caphost, needs the workspace GUID)"]
    direction LR
    PROJ_MI2(("Project MI<br/>(same identity)")):::id
    PROJ_MI2 -->|Storage Blob Data Owner<br/>ABAC: container LIKE '*-azureml-agent'| ST2["Storage account<br/>(scoped to agent containers)"]:::yours
    PROJ_MI2 -->|Cosmos SQL Data Contributor<br/>built-in role 0000...0002| CX2["Cosmos DB<br/>(data-plane RBAC)"]:::yours
  end

  PHASE0 --> PHASE1
  PHASE1 --> CAPHOST
  CAPHOST --> PHASE2

  JMP_MI(("Jumpbox VM MI")):::id
  JMP_MI -->|Search Index Data Contributor<br/>Cognitive Services OpenAI User| SR2["AI Search + Foundry<br/>(for indexer script)"]:::yours

  classDef yours fill:#dbeafe,stroke:#1e3a8a,color:#000
  classDef id fill:#d1fae5,stroke:#047857,color:#000
```

**Why two phases?**

- **Phase 0 (account-level)** is unique to the Managed VNet flavor. The Foundry account creates managed PEs into your subscription during caphost provisioning; without this role, those PEs land in `Pending` state and the deployment hangs.
- **Phase 1 roles** must exist *before* `capabilityHost` is provisioned — Foundry validates that the project MI can read the BYO resources during caphost bootstrap.
- **Phase 2 roles** can only be granted *after* caphost completes — they reference the project's *workspace GUID*, which only comes into existence as a side effect of caphost provisioning. The ABAC condition on Storage scopes the project to its own containers (`<workspaceGuid>*-azureml-agent`).

---

## 4. Request flow — what happens between prompt and answer?

A timeline view of one user message. The key difference vs the BYO flavor: every step from `Runtime` outward traverses a **managed PE** (Microsoft-owned), not your PE.

```mermaid
sequenceDiagram
  autonumber
  actor U as You (jumpbox)
  participant Portal as Foundry portal<br/>ai.azure.com
  participant Proj as Foundry project
  participant Runtime as Agent runtime<br/>(MS-managed VNet)
  participant Search as AI Search
  participant Cosmos as Cosmos DB
  participant Blob as Storage
  participant Model as gpt-4.1-mini

  U->>Portal: HTTPS via your pep-foundry
  Portal->>Proj: POST /agents/{id}/runs
  Proj->>Runtime: dispatch (via capabilityHost binding)
  Runtime->>Cosmos: write new thread (project MI, through managed-pe)
  Runtime->>Search: AI Search tool query (through managed-pe)
  Search-->>Runtime: top-k document chunks
  Runtime->>Blob: persist citations (through managed-pe)
  Runtime->>Model: chat completion (intra-account, no PE)
  Model-->>Runtime: streaming tokens
  Runtime-->>Proj: SSE
  Proj-->>Portal: stream
  Portal-->>U: rendered answer
```

**Where things typically break:**

| Step | Failure | Root cause |
|---|---|---|
| 1 | `nslookup` returns public IP | `privatelink.cognitiveservices.azure.com` zone not linked to your VNet |
| 3 | "Invalid endpoint or connection failed" | `capabilityHost` missing, or its managed PEs stuck in `Pending` (account MI missing the approver role from Phase 0) |
| 4 | 403 from Cosmos | Phase 2 RBAC missing (Cosmos SQL Data Contributor) |
| 5 | 403 from Search | Phase 1 RBAC missing (Search Index Data Contributor on project MI) |
| 8 | model timeout | model quota / deployment SKU mismatch — *not* a network issue |

---

## Where these diagrams live (and how to keep them in sync)

- **Source of truth:** this file (`docs/diagrams.md`). All mermaid blocks render natively on GitHub — no images to maintain.
- The repo `README.md` embeds **diagram #1** inline and links here for #2–#4 so a quick reader gets the gist without scrolling through four diagrams.
- If you change the topology (new subnet, new PE, new connection), update **only this file**. The README link still works.
- The BYO VNet flavor has a parallel `docs/diagrams.md` with the same 4 diagrams — placing them side by side is the fastest way to grok the difference between the two flavors.
