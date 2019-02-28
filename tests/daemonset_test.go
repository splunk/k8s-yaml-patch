package tests

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDaemonsetSimplePatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/daemonset/daemonset.yaml")
	outYAML := s.evalAsYAML("testdata/daemonset/patch-simple.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[L]          value: bar
[R]          value: bar2
[L]          value: baz
[L]        image: nginx:latest
[R]          valueFrom:
[R]            configMapkeyRef:
[R]              key: foo
[R]              name: env-config
[R]        image: nginx:stable
[R]        resources:
[R]          requests:
[R]            cpu: 100m
[L]          name: ds1-config
[R]          name: content-config
`
	s.assertDiff(expectedDiff, diff)
}

func TestDaemonsetPluralPatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/daemonset/daemonset.yaml")
	outYAML := s.evalAsYAML("testdata/daemonset/patch-plurals.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[L]          value: bar
[R]          value: bar2
[L]          value: baz
[R]          valueFrom:
[R]            configMapkeyRef:
[R]              key: foo
[R]              name: env-config
[L]          name: ds1-config
[R]          name: content-config
`
	s.assertDiff(expectedDiff, diff)
}

func TestDaemonsetObjectPatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/daemonset/daemonset.yaml")
	outYAML := s.evalAsYAML("testdata/daemonset/patch-objects.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[R]        resources:
[R]          requests:
[R]            cpu: 100m
[R]      nodeSelector:
[R]        monitoring: "true"`
	s.assertDiff(expectedDiff, diff)
}

func TestDaemonsetNegative(t *testing.T) {
	baseDir := "testdata/daemonset"
	tests := []struct {
		file string
		msg  string
	}{
		{
			file: "bad-container-name.jsonnet",
			msg:  "Container with name main2 not found",
		},
		{
			file: "bad-env-name.jsonnet",
			msg:  "Env with name foo2 not found",
		},
		{
			file: "bad-volume-name.jsonnet",
			msg:  "Volume with name content2 not found",
		},
	}
	for _, test := range tests {
		name := strings.TrimSuffix(test.file, ".jsonnet")
		t.Run(name, func(t *testing.T) {
			s := newScaffold(t)
			_, err := s.eval(filepath.Join(baseDir, test.file))
			require.NotNil(t, err)
			assert.Contains(t, err.Error(), test.msg)
		})
	}
}
