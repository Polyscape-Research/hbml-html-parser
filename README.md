# hbml-html-parser

A fork of rem is an HTML5 parser written in [Zig](https://ziglang.org).

This fork is for the HBML compiler 


## How to use the parser:
```zig
const std = @import("std");
const rem = @import("html_parser");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // This is the text that will be read by the parser.
    // Since the parser accepts Unicode codepoints, the text must be decoded before it can be used.
    const input = "<!doctype html><html><h1 style=bold>Your text goes here!</h1>";
    const decoded_input = &rem.util.utf8DecodeStringComptime(input);

    // Create the DOM in which the parsed Document will be created.
    var dom = rem.dom.Dom{ .allocator = allocator };
    defer dom.deinit();

    // Create the HTML parser.
    var parser = try rem.Parser.init(&dom, decoded_input, allocator, .report, false);
    defer parser.deinit();

    // This causes the parser to read the input and produce a Document.
    try parser.run();

    // `errors` returns the list of parse errors that were encountered while parsing.
    // Since we know that our input was well-formed HTML, we expect there to be 0 parse errors.
    const errors = parser.errors();
    std.debug.assert(errors.len == 0);

    // We can now print the resulting Document to the console.
    const stdout = std.io.getStdOut().writer();
    const document = parser.getDocument();
    try rem.util.printDocument(stdout, document, &dom, allocator);
}
```

## Test the code
rem uses [html5lib-tests](https://github.com/html5lib/html5lib-tests) as a test suite. Specifically, it tests against the 'tokenizer' and 'tree-construction' tests from that suite. 

`zig build test-tokenizer` will run the 'tokenizer' tests.
`zig build test-tree-construction` will run the 'tree-construction' tests in 2 ways: with scripting disabled, then with scripting enabled.
The expected results are as follows:
- tokenizer: All tests pass.
- tree-construction (scripting disabled): Some tests are skipped because they rely on HTML features that aren't yet implemented in this library (specifically, templates). All other tests pass.
- tree-construction (scripting enabled): Similar to testing with scripting off, but in addition, some entire test files are skipped because they would cause panics.


## License
### GPL-3.0-only
Copyright (C) 2021-2023 Chadwain Holness

rem is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.

This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this library.  If not, see <https://www.gnu.org/licenses/>.

## References
[HTML Parsing Specification](https://html.spec.whatwg.org/multipage/parsing.html)

[DOM Specification](https://dom.spec.whatwg.org/)
