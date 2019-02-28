local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './daemonset.yaml');
local ds = map.daemonset('ds1.DaemonSet');

local componentMap = map {
    [ds.key]: ds.patchContainer('main', {
        resources+: {
            requests+: {
                cpu: '100m',
            },
        },
    }).patchPod({
        nodeSelector: {
            monitoring: 'true',
        },
    }),
};

componentMap.list
