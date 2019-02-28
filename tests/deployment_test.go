package tests

import (
	"testing"
)

// deployment just provides an additional method to patch replicas in addition to all the daemonset methods
func TestDeploymentSimplePatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/deployment/deployment.yaml")
	outYAML := s.evalAsYAML("testdata/deployment/patch-simple.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[L]  replicas: 1
[R]  replicas: 3
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
[L]          name: d1-config
[R]          name: content-config
`
	s.assertDiff(expectedDiff, diff)
}
