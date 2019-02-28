/*
   Copyright 2019 Splunk Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

// withTrace prints the object's JSON representation with the supplied prefix and returns the object
local withTrace(prefix, obj) = std.trace(prefix + ':' + std.manifestJson(obj), obj);

// parseYaml parses the input string as YAML and returns an array of objects (even if there is only one YAML document in the input)
// It relies on the parseYaml native extension that can parse a YAML document to an array of objects.
local parseYaml(str) = {
    local parser = std.native('parseYaml'),
    local array = parser(str),
    filtered: std.filter(function(e) e != null, array),  // the filtering is usually required when people add a trailing "---" in the YAML file
}.filtered;

// patchVolume patches the volume spec for a named volume for the pod template of the specified deployment or daemonset
// and returns a patched deployment or daemonset.
local patchVolume(this, volumeName, volumePatch) = {
    local baseVolumes = this.getVolumes(),
    local filtered = std.filter(function(c) c.name == volumeName, baseVolumes),
    local check = if std.length(filtered) > 0 then filtered else error 'Volume with name ' + volumeName + ' not found',
    local check2 = if std.length(check) < 2 then filtered else error 'Volume with name ' + volumeName + ' multiply defined',
    local newVolume = check2[0] + volumePatch,
    local volumes = if newVolume != null then std.map(function(c) if c.name == volumeName then newVolume else c, baseVolumes),
    output: this.setVolumes(volumes),
}.output;

// patchVolumes patches multiple volumes by name for a container. The vols object is a map of
// volume names to volume patches.
local patchVolumes(this, vols) = {
    local names = std.objectFields(vols),
    output: std.foldl(function(prev, name) patchVolume(prev, name, vols[name]), names, this),
}.output;

// containerByName returns the container from the pod template of a deployment or a daemonset by name.
local containerByName(this, containerName) = {
    local baseContainers = this.getContainers(),
    local filtered = std.filter(function(c) c.name == containerName, baseContainers),
    local check1 = if std.length(filtered) > 0 then filtered else error 'Container with name ' + containerName + ' not found',
    local check2 = if std.length(check1) < 2 then check1 else error 'Container with name ' + containerName + ' multiply defined',
    output: check2[0],
}.output;

// patchContainer patches the container spec for a named container for the specified deployment or daemonset
// and returns a patched deployment or daemonset.
local patchContainer(this, containerName, containerPatch) = {
    local baseContainers = this.getContainers(),
    local containerToPatch = containerByName(this, containerName),
    local patched = containerToPatch + containerPatch,
    local containers = if patched != null then std.map(function(c) if c.name == containerName then patched else c, baseContainers),
    output: this.setContainers(containers),
}.output;

// patchImage patches the image for a named container for the specified deployment or daemonset
// and returns a patched deployment or daemonset.
local patchImage(this, containerName, imageName) = patchContainer(this, containerName, { image: imageName });

// patchEnvVar patches a single environment variable by name. The envObj supplied should either be a string value,
// or an object that represents the value without the name key (e.g. "bar", {value: "bar"}, { valueFrom: ... } etc.)
local patchEnvVar(this, containerName, envName, envObj) = {
    local val = if std.type(envObj) == 'string' then { value: envObj } else envObj,
    local containerToPatch = containerByName(this, containerName),
    local env = containerToPatch.env,
    local filtered = std.filter(function(c) c.name == envName, env),
    local check1 = if std.length(filtered) > 0 then filtered else error 'Env with name ' + envName + ' not found',
    local check2 = if std.length(check1) < 2 then check1 else error 'Env with name ' + envName + ' multiply defined',
    local newEnv = val { name: check2[0].name },
    local patchedEnv = if newEnv.name == envName then std.map(function(c) if c.name == envName then newEnv else c, env),
    local containerPatch = { env: patchedEnv },
    output: patchContainer(this, containerName, containerPatch),
}.output;

// patchEnvVars patches multiple environment variables by name for a container. The envs object is a map of
// env variable names each having a value as descibed for the patchEnvVar method.
local patchEnvVars(this, containerName, envs) = {
    local names = std.objectFields(envs),
    output: std.foldl(function(prev, name) patchEnvVar(prev, containerName, name, envs[name]), names, this),
}.output;

// patchResources patches a container for resource requests and limits. Either or these can be null in
// which case that particular attribute is not set.
local patchResources(this, containerName, requests, limits) = {
    local containerPatch = {
        resources+: (if requests != null then { requests+: requests } else {}) +
                    (if limits != null then { limits+: limits } else {}),
    },
    output: patchContainer(this, containerName, containerPatch),
}.output;

// keyed is an object for which a k8s key (name.kind) can be constructed
local keyed(object) = object {
    local meta = if std.objectHas(self, 'metadata') then self.metadata else error 'No metadata attribute for keyed object: ' + std.toString(object),
    local name = if std.objectHas(meta, 'name') then meta.name else error 'No name attribute in metadata for keyed object:' + std.toString(object),
    local kind = if std.objectHas(self, 'kind') then self.kind else error 'No kind attribute for keyed object:' + std.toString(object),
    key:: name + '.' + kind,
};

// daemonset adds "methods" to a daemonset-like object to allow chained patches to container,
// volumes, env vars.
local daemonset(ds, base) = base(ds) + {
    patchPod(podPatch):: self + { spec+: { template+: { spec+: podPatch } } },
    getContainers():: self.spec.template.spec.containers,
    setContainers(containers):: self + { spec+: { template+: { spec+: { containers: containers } } } },
    getVolumes():: self.spec.template.spec.volumes,
    setVolumes(volumes):: self + { spec+: { template+: { spec+: { volumes: volumes } } } },

    patchContainer(containerName, containerPatch):: patchContainer(self, containerName, containerPatch),
    patchImage(containerName, imageName):: patchImage(self, containerName, imageName),
    patchEnvVar(containerName, envName, envObj):: patchEnvVar(self, containerName, envName, envObj),
    patchEnvVars(containerName, envs):: patchEnvVars(self, containerName, envs),
    patchVolume(volName, volPatch):: patchVolume(self, volName, volPatch),
    patchVolumes(vols):: patchVolumes(self, vols),
    patchResources(containerName, requests, limits):: patchResources(self, containerName, requests, limits),
};

// cronjob adds methods to a cron-job object to allow chained patches to containers, volumes, env vars.
local cronjob(cj, base) = base(cj) + {
    patchPod(podPatch):: self + { spec+: { jobTemplate+: { spec+: { template+: { spec+: podPatch } } } } },
    getContainers():: self.spec.jobTemplate.spec.template.spec.containers,
    setContainers(containers):: self + { spec+: { jobTemplate+: { spec+: { template+: { spec+: { containers: containers } } } } } },
    getVolumes():: self.spec.jobTemplate.spec.template.spec.volumes,
    setVolumes(volumes):: self + { spec+: { jobTemplate+: { spec+: { template+: { spec+: { volumes: volumes } } } } } },
};

// deployment adds "methods" to a deployment-like object to allow chained patches to container,
// volumes, env vars, replicas etc.
local deployment(deploy, base) = base(deploy) {
    patchReplicas(count):: self + { spec+: { replicas: count } },
    containerByName(containerName):: containerByName(self, containerName),
};

// patchDataValue adds or updates the value of the supplied key in a data-like object (configMap or secret)
local patchDataValue(configMap, key, value) = configMap {
    data+: {
        [key]: value,
    },
};

// patchDataValues adds or updates the keys and values supplied in the data object for a config map or secret.
local patchDataValues(configMap, dataObject) = configMap {
    data+: dataObject,
};

// configmap adds method to a config map to be able to patch keys.
local configmap(cm, base) = base(cm) + {
    patchDataValue(name, value):: patchDataValue(self, name, value),
    patchDataValues(obj):: patchDataValues(self, obj),
};

// secret adds method to a secret to be able to patch keys. Note that it is the caller's responsibility
// to provide base64 encoded values for secrets.
local secret(cm, base) = base(cm);

local wrapper = {
    keyed:: keyed,
    daemonset(obj):: daemonset(obj, self.keyed),
    deployment(obj):: deployment(obj, self.daemonset),
    cronjob(obj):: cronjob(obj, self.daemonset),
    configmap(obj):: configmap(obj, self.keyed),
    secret(obj):: secret(obj, self.configmap),
};

// k8sMapToList reverses a k8sListToMap operation and returns the list of values from the supplied object in input order.
// It assumes that no extra keys have been added to the map after creation (these will not be returned).
local k8sMapToList(map) = std.map(function(name) map[name], map.orderedKeys);

// k8sMap adds methods to a map of k8s objects keyed by name + kind to produce deployments, config maps etc.
local k8sMap(object, wrapper) = { orderedKeys:: [] } + object {
    getObj(key):: if std.objectHas(self, key) then self[key] else error 'Invalid key %s for k8s map' % key,
    list:: k8sMapToList(self),
} + std.foldl(
    function(prev, k) (prev { [k](key):: wrapper[k](self.getObj(key)) }),
    std.objectFieldsAll(wrapper),
    {}
);

local foldFunc = function(prev, obj) (
    local key = keyed(obj).key;
    local checkedKey = if std.objectHas(prev, key) then error 'Duplicate element %s in list' % key else key;
    prev { [checkedKey]: obj, orderedKeys+:: [checkedKey] }
);

// k8sListToMap takes an input list of k8s objects and returns a single object that has values that are the original objects
// keyed by <name>.<kind> (e.g. foobar.ClusterRole, foo.Service). The key explicitly does not contain namespace, which means that
// you cannot use this function if the list contains two objects of the same kind and name in different namespaces.
// This allows you to load a list of yaml documents from a file, turn it into a map and selectively patch individual objects
// by name.
local k8sListToMap(list, wrapper) = k8sMap(std.foldl(foldFunc, list, {}), wrapper);

{
    parseYaml:: parseYaml,
    parseYamlAsMap(str):: k8sListToMap(parseYaml(str), self.wrapper),
    k8sListToMap(list):: k8sListToMap(list, self.wrapper),
    wrapper:: wrapper,
    emptyMap:: k8sMap({}, self.wrapper),
    withTrace:: withTrace,
}
