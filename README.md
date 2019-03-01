k8s-yaml-patch
===

[![Build Status](https://travis-ci.org/splunk/k8s-yaml-patch.svg?branch=master)](https://travis-ci.org/splunk/k8s-yaml-patch)

_ashes to ashes, dust to dust, YAML to YAML..._

k8s-yaml-patch is a jsonnet library that can patch Kubernetes objects loaded from YAML documents for environment-specific
runtime configurations.

Conventional wisdom tells us that there are exactly two ways to create K8s objects using jsonnet:

* Load a JSON or YAML file as-is with no modifications.
* Create an object from scratch using jsonnet and env-specific params, perhaps using helper libraries like `ksonnet-lib`.

This library does it the third way by loading YAML documents and patching them for environment specific parameters.
The rationale is that developers get used to the YAML syntax when using `kubectl` for debugging anyway and hiding the 
YAML in favor of a DSL does more harm than good.

It is not _elegant_ (it makes some assumptions that can offend purists) or _complete_
(does not have a full set of mutating operations for all possible attributes) but we have found it to be
_useful_. It supports common mutations to common objects with specialized methods and trusts the
user to apply jsonnet object transforms for the more complex use-cases. It can be easily extended for types and methods.

A simple example
---

* YAML file: `service.yaml`

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
    name: svc1
---
apiVersion: v1
kind: ConfigMap
metadata:
    name: svc1-config
data:
    index.html: insert-real-value-here
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: svc1
  name: svc1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: svc1
    spec:
      containers:
      - image: nginx:latest
        imagePullPolicy: Always
        name: main
        ports:
        - containerPort: 8080
        volumeMounts:
        - mountPath: /web
          name: content
          readOnly: true
      serviceAccountName: svc1
      volumes:
      - name: content
        configMap:
          name: svc1-config
```

* jsonnet file `service.jsonnet`

```jsonnet

local patchlib = import 'patch.libsonnet'; // the patch library

// parse the YAML string loaded from the file as a map
// Objects are keyed by <name><dot><kind>
local map = patchlib.parseYamlAsMap(importstr './service.yaml');

// extract the configmap and deployment objects
local cm = map.configmap('svc1-config.ConfigMap');
local deploy = map.deployment('svc1.Deployment');

// get runtime params from somewhere
local params = {
    replicas: 2,
    image: 'nginx:stable',
    indexContent: '<h1>Hello world</h1>',
};

// patch objects that you want, every object has a "key" attribute that is the
// object key.
local componentMap = map {
    [cm.key]: cm.patchDataValue('index.html', params.indexContent),
    [deploy.key]: deploy.patchImage('main', params.image)
                        .patchReplicas(params.replicas),
};

// turn the map back to a list and emit it
componentMap.list
```

Main ideas
---

* Turn a YAML containing multiple documents into a map so that you can pick individual objects
  for patching. The keys in this map are of the form `<object-name>.<kind>`. Specifically, the key does not
  include namespace or API version. This strategy makes cluster and namespaced objects look uniform,
  allows the namespace to be unspecified in the YAML for default processing and does not depend on 
  API version that can change over time when upgrading k8s. 
  
  This sets the limitation that you cannot load a file that contains two objects with the same name and
  kind, differing only in namespace. You'll probably never hit this issue in practice. If you do, just
  load two files into separate objects and concatenate the results in the end.

* Specialized type wrappers for common objects (e.g. deployment, daemonset, configmap, secret etc.)
  can be gotten from the map. Objects of a type for which no specialization exists can be accessed
  via the `keyed` method. Such objects have an extra `key` attribute that replays their key.

* Most methods center around fixing up the pod and container templates since this is the 90% use-case.

* Many methods require a named entity that is being patched to be already part of the YAML to
  guard against accidental typos.

* The library is extensible for addition of methods to specific types that you may need as well
  as addition of new types that do not have any specializations defined.

This way most objects are fully specified in the YAML and the patching code clearly shows the runtime
attributes that are being customized.

Available types and methods
---

The `jsonnet` files under [tests/testdata](tests/testdata) contain examples of all types and methods supported for 
each one. It also has an example of how to extend the library, in the `extending` subdirectory.

