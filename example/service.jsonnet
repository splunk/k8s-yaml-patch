local patchlib = import '../patch.libsonnet';  // the patch library

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
