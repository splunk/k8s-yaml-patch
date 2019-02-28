package tests

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ensure simple yaml doc can be loaded into an array filtering out null docs
func TestLoadSimple(t *testing.T) {
	s := newScaffold(t)
	jsonString, err := s.eval("testdata/load/load.jsonnet")
	require.Nil(t, err)
	var data interface{}
	err = json.Unmarshal([]byte(jsonString), &data)
	require.Nil(t, err)
	arr, ok := data.([]interface{})
	require.True(t, ok)
	require.Equal(t, 2, len(arr))
}

const yamlDupKeys = `
apiVersion: v1
kind: ConfigMap
metadata:
    name: cm
data:
  foo: bar
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm
data:
  foo: YmFy
`

const yamlNoMetadata = `
apiVersion: v1
kind: ConfigMap
data:
  foo: bar
`

const yamlNoName = `
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: foo
data:
  foo: bar
`

const yamlNoKind = `
apiVersion: v1
metadata:
  name: foo
data:
  foo: bar
`

func TestLoadNegative(t *testing.T) {
	tests := []struct {
		name string
		yaml string
		msg  string
	}{
		{
			name: "dup-keys",
			yaml: yamlDupKeys,
			msg:  "Duplicate element cm.ConfigMap in list",
		},
		{
			name: "no-meta",
			yaml: yamlNoMetadata,
			msg:  "No metadata attribute for keyed object",
		},
		{
			name: "no-name",
			yaml: yamlNoName,
			msg:  "No name attribute in metadata for keyed object",
		},
		{
			name: "no-kind",
			yaml: yamlNoKind,
			msg:  "No kind attribute for keyed object",
		},
	}

	script := `
local patchlib = import 'patch.libsonnet';
patchlib.parseYamlAsMap(std.extVar('yaml')).list
`
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			s := newScaffold(t)
			s.vm.ExtVar("yaml", test.yaml)
			_, err := s.evalInternal(test.name+".jsonnet", script)
			require.NotNil(t, err)
			assert.Contains(t, err.Error(), test.msg)
		})
	}
}
