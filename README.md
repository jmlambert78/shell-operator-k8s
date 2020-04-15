# shell-operator-k8s
Usage of shell-operator for custom setup of RBAC in namespaces
Based on https://github.com/flant/shell-operator 
* Fix some typo
* Add SLES image construction
* Replace image rebuild by ConfigMap containing the Event driven scripts

```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: hooks-operator
  namespace: monitor-namespaces-bot-ns
data:
### this 1st hook binds a clusterrole to a group of users k8s-users
  ns-hook.sh: |+
    #!/bin/bash
    if [[ $1 == "--config" ]] ; then
      # configuration
      cat <<EOF
    {
      "onKubernetesEvent": [
        {
          "kind": "namespace",
          "event": [ "add" ]
        }
      ]
    }
    EOF
    else
      # response:
      # find out what namespace has emerged
      createdNamespace=$(jq -r '.[0].resourceName' $BINDING_CONTEXT_PATH)
      # create the appropriate authorization in it (here k8s-users group to receive admin clusterrole)
      kubectl create -n ${createdNamespace} rolebinding  ns-users --clusterrole=admin --group=k8s-users
    fi
### this 2nd hook is just for demo, it traps namespace deletion and write a msg in the logs.
  ns-hook-2.sh: |+
    #!/bin/bash
    if [[ $1 == "--config" ]] ; then
      # configuration
      cat <<EOF
    {
      "onKubernetesEvent": [
        {
          "kind": "namespace",
          "event": [ "delete" ]
        }
      ]
    }
    EOF
    else
      # response:
      # find out what namespace
      deletedNamespace=$(jq -r '.[0].resourceName' $BINDING_CONTEXT_PATH)
      echo "Namespace ${deletedNamespace} just deleted !"
    fi
```
