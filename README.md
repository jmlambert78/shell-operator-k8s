# shell-operator-k8s
Usage of shell-operator for custom setup of RBAC in namespaces
Based on https://github.com/flant/shell-operator 
* Fix some typo
* Add SLES image construction
* Replace image rebuild by ConfigMap containing the Event driven scripts
# Problem to solve :
we consider that we have 3 usages of the platform
* Platform administrator 
  * Namespaces to be protected from Customer (trident, prometheus...)
* Customer Admins 
  * Need to be able to create a NS
  * Create Roles/RoleBindings inside this NS
  * Allocate a predefined Role to the relevant group(s) users to let them consume it.
* Customer Users
  * Are provisioned within the AD/LDAP
  * Are members of the set of relevant groups as said above.
This issue is not easy(possible?) to solve only with RBAC

# Solution based on shell-operator, event watching
* Principle :
	* user-admin creates a new Namespace
    *	An event of Namespace Creation is triggered
  * A BOT process this Namespace Creation event, by :
    *	adding the RoleBinding for admin ClusterRole to the k8s-group 
    * BOT runs under a Service Account authorized to make this binding
  * regular users will be able to consume the newly created Namespace
    * In this solution, the user-admin, is not allowed to grant access to PlatformAdmin protected NS

# Configuration of the operator :

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
## How to customise ?
* Edit the ConfigMap above with your specific events & scripts,you may have one or many .sh files there. 
* look at the original site for explanation on the syntax.https://github.com/flant/shell-operator
* For the default content, the event is based on Namespace creation.
  * kubectl create testnewns
  * check that the new ns testnewns contains some rolebinding that is injected by the Bot.
## How to deploy ?
```kubectl apply -f op-bot-allinone.yaml```
## How to test ?
* For the default content, the event is based on Namespace creation.
  * kubectl create testnewns
  * check that the new ns testnewns contains some rolebinding that is injected by the Bot.
  * You may have a look to the logs of the pod.

