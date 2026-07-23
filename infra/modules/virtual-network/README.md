# Virtual Network Module

Enterprise-grade networking infrastructure with trust-tier isolation, observability, and compliance controls.

## Features

### Core Networking
- **VNet & Subnets**: Flexible address space with multi-subnet support
- **Trust Tiers**: Classify subnets as `trusted`, `untrusted`, or `management` for policy enforcement
- **Route Tables**: Per-tier routing with optional firewall/NVA integration
- **Private DNS Zones**: Automatic Private Link DNS for services (Key Vault, PostgreSQL, Service Bus, Redis, etc.)

### Security & Zero-Trust
- **NSG Rules**: Granular inbound/outbound traffic control with source/destination subnet mapping
- **Cross-Tier Deny Rules**: Explicit NSG deny rules between trust tiers (e.g., untrusted→trusted blocked by default)
- **NSG Flow Logs**: Full traffic audit trail (allowed + denied) sent to Log Analytics
- **Default Deny Inbound**: Optional explicit deny-all-inbound rule (priority 4096) for zero-trust readiness

### Controlled Egress & DDoS
- **NAT Gateway**: Static public IP for controlled outbound access from private subnets
  - Per-NAT-tier public IP assigned to tagged subnets
  - Enables firewall/proxy IP whitelisting for outbound rules
- **DDoS Protection**: Optional binding to Azure DDoS Standard plan for layer 3/4 protection

### Governance & Compliance
- **Management Locks**: Optional `CanNotDelete` or `ReadOnly` locks on VNet and NSGs (prod/regulated environments)
- **Resource Tagging**: All resources inherit VNet tags for cost tracking and compliance
- **Address Space Validation**: Prevents misconfiguration of CIDR blocks

## Usage

### Basic Configuration (Minimal)

```hcl
module "network" {
  source = "../../modules/virtual-network"

  resource_group_name = azurerm_resource_group.this.name
  location            = "centralus"
  vnet_name           = "my-vnet"
  address_space       = ["10.0.0.0/16"]

  subnets = {
    app = {
      address_prefixes = ["10.0.1.0/24"]
      trust_tier       = "trusted"
      route_table_key  = "trusted"
    }
  }

  nsg_rules = {}
  tags      = { Environment = "dev" }
}
```

### Enterprise Configuration (Full Features)

```hcl
module "network" {
  source = "../../modules/virtual-network"

  resource_group_name = azurerm_resource_group.this.name
  location            = "centralus"
  vnet_name           = "enterprise-vnet"
  address_space       = ["10.0.0.0/16"]

  # Subnets with trust tiers
  subnets = {
    public = {
      address_prefixes = ["10.0.1.0/24"]
      trust_tier       = "untrusted"
      route_table_key  = "untrusted"
    }
    app = {
      address_prefixes = ["10.0.10.0/24"]
      trust_tier       = "trusted"
      route_table_key  = "trusted"
    }
    database = {
      address_prefixes                    = ["10.0.20.0/24"]
      private_endpoint_network_policies   = "Disabled"
      trust_tier                          = "trusted"
      route_table_key                     = "trusted"
    }
  }

  # Route tables for per-tier routing (e.g., force egress through firewall)
  route_tables = {
    trusted = {
      name = "trusted-rt"
      routes = {
        to_firewall = {
          address_prefix         = "0.0.0.0/0"
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = var.firewall_private_ip
        }
      }
    }
  }

  # NSG allow rules (explicit denies added automatically per cross_tier_deny_rules)
  nsg_rules = {
    app = [
      {
        name                       = "Allow-HTTP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_subnet              = "public"
        destination_address_prefix = "10.0.10.0/24"
      }
    ]
  }

  # Cross-tier deny (untrusted cannot initiate to trusted)
  cross_tier_deny_rules = {
    boundary_protection = {
      source_tier      = "untrusted"
      destination_tier = "trusted"
      protocol         = "*"
      port_range       = "*"
    }
  }

  # Private DNS zones for Private Link resources
  private_dns_zones = {
    keyvault = {
      zone_name = "privatelink.vaultcore.azure.net"
    }
    database = {
      zone_name = "privatelink.postgres.database.azure.com"
    }
  }

  # NAT Gateway for controlled egress
  nat_gateway_config = {
    private_egress = {
      name                        = "private-natgw"
      subnets                     = ["app", "database"]
      idle_timeout_in_minutes     = 4
    }
  }

  # NSG flow logs to Log Analytics
  enable_nsg_flow_logs       = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  # DDoS protection
  enable_ddos_protection = true  # Requires DDoS Standard plan

  # Management locks (production readiness)
  management_lock_level = "CanNotDelete"  # or "ReadOnly"

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
```

## Outputs

- `vnet_id` — VNet resource ID
- `vnet_name` — VNet name
- `subnet_ids` — Map of subnet name → subnet ID
- `subnet_trust_tiers` — Map of subnet name → trust tier
- `nsg_ids` — Map of NSG name → NSG ID
- `private_dns_zone_ids` — Map of DNS zone key → zone ID
- `route_table_ids` — Map of route table key → route table ID
- `nat_gateway_ids` — Map of NAT Gateway key → NAT Gateway ID
- `nat_gateway_public_ips` — Map of NAT Gateway key → public IP address (egress IP for subnets)
- `cross_tier_deny_rules_summary` — Audit summary of enforced cross-tier deny rules
- `management_locks_enabled` — Boolean indicating if resource locks are applied

## Trust Tier Classification

| Tier | Use Case | Default Policies |
|------|----------|------------------|
| **untrusted** | Public ingress, unvalidated traffic (DMZ, API gateways, public load balancers) | Explicit allow inbound only; blocked from initiating to `trusted` |
| **trusted** | Internal services, databases, caches, private endpoints | Implicit allow from management/system paths; blocked from untrusted inbound |
| **management** | Bastion, jump hosts, admin workstations | Restricted inbound (from corp ranges); outbound to all tiers |

## Security Best Practices

1. **Always use `cross_tier_deny_rules`** to prevent lateral movement between zones
2. **Enable NSG flow logs** in non-dev environments for audit and incident investigation
3. **Apply `management_lock_level = "CanNotDelete"`** to production VNets and NSGs
4. **Use NAT Gateway** for subnets that require outbound internet (audit-able egress IPs)
5. **Disable VNet public IPs** on resources; use Private Endpoints instead
6. **Link Private DNS zones** for all Private Link services to avoid IP/FQDN lookups across VNets

## Environment-Specific Overrides

### Development
```hcl
enable_nsg_flow_logs     = true   # Cost-effective logging
management_lock_level    = null   # Flexibility for experimentation
enable_ddos_protection   = false  # Not needed in dev
```

### Production
```hcl
enable_nsg_flow_logs     = true   # Mandatory for compliance
management_lock_level    = "CanNotDelete"  # Prevent accidental deletion
enable_ddos_protection   = true   # Mitigate DDoS attacks
nat_gateway_config       = {...}  # Control egress IPs
```

## Roadmap (Future Enhancements)

- [ ] Hub-and-spoke VNet peering with gateway transit
- [ ] Multi-CIDR subnet support (currently uses first prefix only)
- [ ] Azure Firewall integration scaffold
- [ ] VNet service endpoints policies per subnet
- [ ] Network watcher flow capture integration

