local patchlib = import 'patch.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './secret.yaml');
local s = map.secret('cm.ConfigMap');

local componentMap = map {
    [s.key]: s.patchDataValue('foo', std.base64('bar2'))
              .patchDataValue('bar', std.base64('baz'))
              .patchDataValues({ one: std.base64("1"), two: std.base64("2") })
};

componentMap.list
