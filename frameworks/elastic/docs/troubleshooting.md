---
post_title: Troubleshooting
menu_order: 46
feature_maturity: experimental
enterprise: 'no'
---

# Replacing a Permanently Failed Node
The DC/OS Elastic Service is resilient to temporary node failures. However, if a DC/OS agent hosting an Elastic node is permanently lost, manual intervention is required to replace the failed node. The following command should be used to replace the node residing on the failed server.

```bash
$ dcos elastic --name=<service-name> pods replace <node_id>
```

# Restarting a Node
If you must forcibly restart a node, use the following command to restart the node on the same agent node where it currently resides. This will not result in an outage or loss of data.

```bash
$ dcos elastic --name=<service-name> pods restart <node_id>
```
