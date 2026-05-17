# Network Device Configuration

## Cilium BGP

`cilium-bgp.conf` is the FRR BGP configuration uploaded to the UniFi
UDM-SE. It peers with the Cilium BGP control plane on the Talos node subnet and
only accepts the explicitly versioned Kubernetes LoadBalancer VIPs.

Current accepted VIPs:

- `10.0.20.80/32` - Envoy internal gateway
- `10.0.25.80/32` - Envoy external/DMZ gateway
- `10.0.20.21/32` - Gluetun alfa proxy
- `10.0.20.22/32` - Gluetun bravo proxy

Keep this file in sync with Kubernetes LoadBalancer services labelled
`io.cilium/bgp-advertise: "true"`.
