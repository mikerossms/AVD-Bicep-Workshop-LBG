# Hub

The hub provides a place that the students can peer to which then allows onward connectivity to other services such as any DNS servers and the Entra Domain Services

It consists of a vnet and an NVA, in this case a simple Azure Firewall with each hub routing to that firewall.  Doing this protects the other pre-configured resources while allowing the students to peer.