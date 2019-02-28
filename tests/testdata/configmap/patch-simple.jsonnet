local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './configmap.yaml');
local c = map.configmap('cm.ConfigMap');

local componentMap = map {
    [c.key]: c.patchDataValue('foo', 'bar2')
              .patchDataValue('bar', 'baz')
              .patchDataValues({ one: "1", two: "2" })
};

componentMap.list
