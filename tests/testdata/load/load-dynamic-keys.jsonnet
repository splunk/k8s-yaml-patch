local patchlib = import 'patch.libsonnet';
local map = patchlib.parseYamlAsMap(importstr './load.yaml');
local secret = map.keyed('foo.Secret');
local patchedSecret = secret + { metadata +: { name: "bar" } };
local componentMap = map {
    [secret.key]: null,
    'bar.Secret': patchedSecret,
};

componentMap.list
