package tests

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEmptyMap(t *testing.T) {
	s := newScaffold(t)
	jsonString, err := s.evalInternal("empty-map.jsonnet", `
local patchlib = import 'patch.libsonnet';
patchlib.emptyMap.list
`)
	require.Nil(t, err)
	assert.Equal(t, "[ ]\n", jsonString)
}
