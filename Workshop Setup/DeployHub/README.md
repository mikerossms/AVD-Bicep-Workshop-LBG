# Hub

The hub provides a place that the students can peer to which then allows onward connectivity to other services such as any DNS servers and the Entra Domain Services

It consists of a vnet and an NVA, in this case a simple Azure Firewall with each hub routing to that firewall.  Doing this protects the other pre-configured resources while allowing the students to peer.

## NOTE

For the FSLogix piece to work, a GPO must be set up in Entra DS for the VM's in question.  It is recommended that the VMs are added to their own OU and that the policy GPO is applied there.  [REF: FSLogix GPO](https://learn.microsoft.com/en-us/fslogix/how-to-use-group-policy-templates)

This needs to be done BEFORE the AVD is deployed.