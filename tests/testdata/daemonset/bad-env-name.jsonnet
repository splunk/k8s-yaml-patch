local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './daemonset.yaml');
local ds = map.daemonset('ds1.DaemonSet');

local componentMap = map {
    [ds.key]: ds.patchEnvVar('main', 'foo2', 'bar2'),  // foo2 env var not declared
};

componentMap.list
