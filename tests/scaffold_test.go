package tests

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"path/filepath"
	"strings"
	"testing"

	gdyaml "github.com/ghodss/yaml"
	"github.com/google/go-jsonnet"
	"github.com/google/go-jsonnet/ast"
	"github.com/pmezard/go-difflib/difflib"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"k8s.io/apimachinery/pkg/util/yaml"
)

// registerNativeFuncs registers native functions used by tests
func registerNativeFuncs(vm *jsonnet.VM) {
	vm.NativeFunction(&jsonnet.NativeFunction{
		Name:   "parseYaml",
		Params: []ast.Identifier{"yaml"},
		Func: func(args []interface{}) (res interface{}, err error) {
			ret := []interface{}{}
			data := []byte(args[0].(string))
			d := yaml.NewYAMLToJSONDecoder(bytes.NewReader(data))
			for {
				var doc interface{}
				if err := d.Decode(&doc); err != nil {
					if err == io.EOF {
						break
					}
					return nil, err
				}
				ret = append(ret, doc)
			}
			return ret, nil
		},
	})
}

type scaffold struct {
	t  *testing.T
	vm *jsonnet.VM
}

func newScaffold(t *testing.T) *scaffold {
	vm := makeVM()
	return &scaffold{t: t, vm: vm}
}

// writeYAMLDoc writes a single YAML document to the supplied writer.
func (s *scaffold) writeYAMLDoc(w io.Writer, data interface{}) {
	b, err := gdyaml.Marshal(data)
	require.Nil(s.t, err, "yaml marshal error: %v", err)
	_, err = io.WriteString(w, "---\n")
	require.Nil(s.t, err, "i/o error: %v", err)
	_, err = w.Write(b)
	require.Nil(s.t, err, "i/o error: %v", err)
}

// evalInternal evaluates the supplied script as the supplied file name.
func (s *scaffold) evalInternal(file, script string) (string, error) {
	return s.vm.EvaluateSnippet(file, script)
}

// eval evaluates the supplied jsonnet file and returns its json result as a string.
func (s *scaffold) eval(file string) (string, error) {
	contents, err := ioutil.ReadFile(file)
	require.Nil(s.t, err, "unable to read %s, %v", file, err)
	return s.evalInternal(file, string(contents))
}

// jsonStringToYAML turns the supplied JSON string into a YAML stream of documents
// based on whether the top level object is an array. If the top-level object is
// not an array, it writes a single YAML document.
func (s *scaffold) jsonStringToYAML(ctx, jsonStr string) string {
	var data interface{}
	err := json.Unmarshal([]byte(jsonStr), &data)
	require.Nil(s.t, err, "unexpected unmarshal error for %s, %v", ctx, err)
	var out bytes.Buffer
	switch kind := data.(type) {
	case []interface{}:
		for _, o := range kind {
			s.writeYAMLDoc(&out, o)
		}
	default:
		s.writeYAMLDoc(&out, data)
	}
	return out.String()
}

// evalAsYAML evaluates the jsonnet file and returns its result as YAML.
func (s *scaffold) evalAsYAML(file string) string {
	jsonStr, err := s.eval(file)
	require.Nil(s.t, err, "unexpected eval failure for %s, %v", file, err)
	return s.jsonStringToYAML(file, jsonStr)
}

const yamlLoaderScript = `
local patchlib = import 'patch.libsonnet';
patchlib.parseYaml(importstr '%s')
`

// canonicalYAML load a (possiby user-written) YAML file and rewrites it in canonical form
// with sorted keys, normalized whitespace etc.
func (s *scaffold) canonicalYAML(file string) string {
	base := filepath.Base(file)
	script := fmt.Sprintf(yamlLoaderScript, base)
	ctx := file + ".jsonnet"
	jsonStr, err := s.evalInternal(ctx, script)
	require.Nil(s.t, err, "unexpected eval failure for %s, %v", file, err)
	return s.jsonStringToYAML(file, jsonStr)
}

// diffStrings diffs two documents represented as strings and returns a compact
// unified diff is a format where leading minus signs are turned into [L] and
// leading plus signs are turned into [R]. This is so that diffs of diffs do not end up
// as a super-confusing mess.
func (s *scaffold) diffStrings(left, right string) string {
	ud := difflib.UnifiedDiff{
		A:       difflib.SplitLines(left),
		B:       difflib.SplitLines(right),
		Context: 0,
	}
	str, err := difflib.GetUnifiedDiffString(ud)
	require.Nil(s.t, err, "diff error: %v", err)

	lines := strings.Split(str, "\n")
	var ret []string
	for _, l := range lines {
		if strings.HasPrefix(l, "@@") {
			continue
		}
		if strings.HasPrefix(l, "-") {
			l = "[L]" + l[1:]
		}
		if strings.HasPrefix(l, "+") {
			l = "[R]" + l[1:]
		}
		ret = append(ret, l)
	}
	return strings.Join(ret, "\n")
}

// assertDiff asserts that the expected and actual diffs are the same.
func (s *scaffold) assertDiff(expected, actual string) {
	expected = strings.Trim(expected, "\n")
	actual = strings.Trim(actual, "\n")
	fmt.Println(actual)
	assert.Equal(s.t, expected, actual)
}

// makeVM returns a new jsonnet VM with native functions registered, and the patch library path
// added to the import path.
func makeVM() *jsonnet.VM {
	vm := jsonnet.MakeVM()
	registerNativeFuncs(vm)
	absDir, err := filepath.Abs("./..")
	if err != nil {
		panic(err)
	}
	vm.Importer(&jsonnet.FileImporter{
		JPaths: []string{absDir},
	})
	return vm
}
