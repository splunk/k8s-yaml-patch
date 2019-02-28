package tests

import (
	"testing"
)

func TestSecretSimplePatch(t *testing.T) {
	s := newScaffold(t)
	inYAML := s.canonicalYAML("testdata/secret/secret.yaml")
	outYAML := s.evalAsYAML("testdata/secret/patch-simple.jsonnet")
	diff := s.diffStrings(inYAML, outYAML)
	expectedDiff := `
[L]  foo: LWIgYmFyCg==
[R]  bar: YmF6
[R]  foo: YmFyMg==
[R]  one: MQ==
[R]  two: Mg==
`
	s.assertDiff(expectedDiff, diff)
}
