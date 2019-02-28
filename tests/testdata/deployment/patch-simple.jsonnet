local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './deployment.yaml');
local ds = map.deployment('d1.Deployment');

local componentMap = map {
    [ds.key]: ds.patchReplicas(3)
              .patchImage('main', 'nginx:stable')  // patch image name for main container
              .patchEnvVar('main', 'foo', 'bar2')  // set the foo env var to a different value
              .patchEnvVar('main', 'bar', { valueFrom: { configMapkeyRef: { name: 'env-config', key: 'foo' } } })  // set the bar env var to be pulled from a config map
              .patchResources('main', { cpu: '100m' }, null)  // set container request and no limit
              .patchVolume('content', { configMap: { name: 'content-config' } }),  // get content from a different config map
};

componentMap.list
