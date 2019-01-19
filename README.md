# nodes-in-group

Get a list of nodes belonging to a specific node group in Puppet Enterprise

# Requirements

* Bash >= 4.0
* jq >= 1.5

# Usage

`./get_nodes_in_group.sh <group name>`

# Example

```
root@pe-201901-master:~# ./get_nodes_in_group.sh "Agent-specified environment"
"pe-201901-agent.puppetdebug.vlan"
```
