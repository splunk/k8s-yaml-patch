local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './daemonset.yaml');
local ds = map.daemonset('ds1.DaemonSet');

local componentMap = map {
    [ds.key]: ds.patchEnvVars('main', { foo: 'bar2', bar: { valueFrom: { configMapkeyRef: { name: 'env-config', key: 'foo' } } } })  //set multiple env vars
              .patchVolumes({ content: { configMap: { name: 'content-config' } } }),  // use plural version
};

componentMap.list
