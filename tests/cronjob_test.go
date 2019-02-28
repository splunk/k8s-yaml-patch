package tests

import (
	"testing"
)

// cronjob provides the same methods as a daemonset (for now) but patches things in the correct place in the spec
func TestCronjobSimplePatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/cronjob/cronjob.yaml")
	outYAML := s.evalAsYAML("testdata/cronjob/patch-simple.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[L]              value: bar
[R]              value: bar2
[L]              value: baz
[L]            image: nginx:latest
[R]              valueFrom:
[R]                configMapkeyRef:
[R]                  key: foo
[R]                  name: env-config
[R]            image: nginx:stable
[R]            resources:
[R]              requests:
[R]                cpu: 100m
[L]              name: c1-config
[R]              name: content-config
`
	s.assertDiff(expectedDiff, diff)
}
