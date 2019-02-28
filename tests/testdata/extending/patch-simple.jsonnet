local patchlib = import './mypatchlib.libsonnet';

local map = patchlib.parseYamlAsMap(importstr './objects.yaml');
local ns = map.namespace('foo.Namespace');
local ds = map.deployment('d1.Deployment');

local componentMap = map {
    [ns.key]: ns.patchAllowedIamRoles(['foo', 'bar']), 
    [ds.key]: ds.patchIamRole("foo"),
};

componentMap.list
