local patchlib = import 'patch.libsonnet';

// patchAllowedIamRoles patches a namespace for allowed IAM roles. The allowedRoles argument can be a single
// role or an array of roles.
local patchAllowedIamRoles(namespace, allowedRoles) = {
    local roles = if std.type(allowedRoles) == 'string' then [allowedRoles] else allowedRoles,
    output: namespace {
        metadata+: {
            annotations+: {
                'iam.amazonaws.com/allowed-roles': std.toString(roles),
            },
        },
    },
}.output;

local wrapper = patchlib.wrapper;

// namespace adds methods to a namespace object for IAM roles etc.
local namespace(ns) = wrapper.keyed(ns) + {
    patchAllowedIamRoles(roles):: patchAllowedIamRoles(self, roles),
};

local daemonset = patchlib.wrapper.daemonset;

patchlib {
    wrapper+:: {
        daemonset(obj):: daemonset(obj) {
            patchIamRole(iamRole):: self + { spec+: { template+: { metadata+: { annotations+: { 'iam.amazonaws.com/role': iamRole } } } } },
        },
        namespace(obj):: namespace(obj),
    },
}
