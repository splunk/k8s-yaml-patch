local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './daemonset.yaml');
local ds = map.daemonset('ds1.DaemonSet');

local componentMap = map {
    [ds.key]: ds.patchVolume('content2', { configMap: { name: 'content-config' } }),  // no volume with that name
};

componentMap.list
