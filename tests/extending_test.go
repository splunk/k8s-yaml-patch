package tests

import (
	"testing"
)

func TestExtendingSimplePatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/extending/objects.yaml")
	outYAML := s.evalAsYAML("testdata/extending/patch-simple.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[R]  annotations:
[R]    iam.amazonaws.com/allowed-roles: '["foo", "bar"]'
[R]      annotations:
[R]        iam.amazonaws.com/role: foo
`
	s.assertDiff(expectedDiff, diff)
}
