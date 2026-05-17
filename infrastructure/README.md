# Infrastructure

Operational configuration that supports the lab outside of the Kubernetes cluster. These files are versioned as a source of truth, but they are not applied by Flux.

> Do not store secrets, passwords, private keys, tokens, or shared credentials in this directory.

Possible subdirectories:

- `backup/` - backup systems, retention policies, and restore procedures.
- `compute/` - host, hypervisor, and bare-metal configuration.
- `dns/` - DNS zones, resolvers, records, and split-horizon configuration.
- `identity/` - external identity providers, groups, and access mappings.
- `network/` - routers, switches, VLANs, routing, BGP, and firewall config.
- `observability/` - external monitoring, alerting, logging, and probes.
- `security/` - hardening notes, trust boundaries, and policy references.
- `storage/` - NAS, SAN, object storage, and replication configuration.
