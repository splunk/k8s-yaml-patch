package tests

import (
	"testing"
)

func TestConfigMapSimplePatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/configmap/configmap.yaml")
	outYAML := s.evalAsYAML("testdata/configmap/patch-simple.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[L]  foo: bar
[R]  bar: baz
[R]  foo: bar2
[R]  one: "1"
[R]  two: "2"
`
	s.assertDiff(expectedDiff, diff)
}
