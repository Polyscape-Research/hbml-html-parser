const std = @import("std");
const stack = @import("stack.zig");
const sb = @import("string_builder.zig");

const Token = packed struct {
    token: u8,
    term_token: u8,

    pub fn eql(self: *const Token, char: u8) bool {
        return self.token == char;
    }

    pub fn eql_term(self: *const Token, char: u8) bool {
        return self.term_token == char;
    }

    pub const Tokens = &[_]Token{
        .{ .token = '<', .term_token = '>' },
        .{ .token = '<', .term_token = '/' },
    };
};

const StateMachine = struct {
    text_block: bool = false,
    element_block: bool = false,
    element_decleration: bool = false,
    attrabute_decleration: bool = false,
    attrabute_value_decleration: bool = false,
    expect_value: bool = false,
    multi_block_decleration: bool = false,
    current_value_delimiter: u8 = 0x0,
    value_string_builder: sb.StringBuilder,
    string_builder: sb.StringBuilder,
    dom_node: stack.Element,
    current_element: *stack.Element = undefined,
    current_attrabute: ?stack.Attrabute = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !StateMachine {
        return .{
            .allocator = allocator,
            .string_builder = try sb.StringBuilder.init(allocator, "", .multi, null),
            .value_string_builder = try sb.StringBuilder.init(allocator, "", .multi, null),
            .dom_node = try stack.Element.init(allocator, "dom", null),
        };
    }

    pub fn deinit(self: *StateMachine) void {
        self.string_builder.deinit();
        self.value_string_builder.deinit();
    }

    pub fn emit_whitespace(self: *StateMachine) bool {
        return !self.text_block and !self.expect_value and !self.element_decleration and !self.attrabute_decleration and !self.attrabute_value_decleration and !self.element_block;
    }

    pub fn emit_element(self: *StateMachine) !stack.Element {
        const element = try self.string_builder.to_string_alloc();

        std.debug.print("current_element: {s} changing to: {s}\n", .{ self.dom_node.find_bottom_nt().identifier, element });

        var child = try stack.Element.init_child(element, self.dom_node.find_bottom_nt());
        child.strings_allocated = true;
        self.string_builder.clear();
        return child;
    }

    pub fn emit_attrabute(self: *StateMachine) !stack.Attrabute {
        const attrabute = try self.string_builder.to_string_alloc();
        self.string_builder.clear();
        return .{ .identifier = attrabute, .value_text = "" };
    }

    pub fn emit_attrabute_value(self: *StateMachine, current_attrabute: ?stack.Attrabute) !?stack.Attrabute {
        self.current_value_delimiter = 0x0;
        self.expect_value = false;
        self.attrabute_value_decleration = false;
        self.attrabute_decleration = false;

        var new_attrabute = current_attrabute;

        if (new_attrabute != null) {
            const string: []const u8 = try self.value_string_builder.to_string_alloc();
            new_attrabute.?.value_text = string;
            self.string_builder.clear();
        }

        return new_attrabute;
    }
};

fn allowed_char_check(char: u8) bool {
    // a-zA-Z
    return (char >= 0x41 and char <= 0x5A) or (char >= 0x61 and char <= 0x7A);
}

pub fn parseHtml(file_bytes: []const u8, state_machine: *StateMachine) !stack.Element {
    var prev_char: ?u8 = undefined;

    for (file_bytes, 0..) |char, index| {
        _ = index;

        const allowed_char = allowed_char_check(char);

        if (!state_machine.element_block and Token.Tokens[0].eql(char)) {
            @branchHint(.likely);
            state_machine.element_block = true;
            state_machine.element_decleration = true;
            continue;
        }

        if (state_machine.element_block and Token.Tokens[0].eql_term(char)) {
            @branchHint(.likely);

            if (state_machine.element_decleration) {
                const element = try state_machine.emit_element();
                if (!state_machine.multi_block_decleration) {
                    try state_machine.dom_node.find_bottom_nt().push_child(element);
                } else {
                    if (std.mem.eql(u8, element.identifier, state_machine.dom_node.find_bottom_nt().identifier)) {
                        state_machine.dom_node.find_bottom_nt().terminated = true;
                        state_machine.multi_block_decleration = false;
                    } else return error.InvalidBreakChar;
                }
            } else if (state_machine.attrabute_decleration) {
                state_machine.current_attrabute = try state_machine.emit_attrabute();
                if (state_machine.current_attrabute != null) {
                    try state_machine.dom_node.find_bottom_nt().push_attrabute(state_machine.current_attrabute.?);
                }
            }

            state_machine.element_block = false;
            state_machine.attrabute_decleration = false;
            state_machine.element_decleration = false;
            continue;
        }

        // Elements
        if (state_machine.element_block and !state_machine.element_decleration and char == '/') {
            state_machine.dom_node.find_bottom_nt().terminated = true;
            continue;
        }

        if (state_machine.element_block and state_machine.element_decleration and char == '/') {
            state_machine.multi_block_decleration = true;
            continue;
        }

        if (state_machine.element_block and state_machine.element_decleration and allowed_char) {
            try state_machine.string_builder.concat_byte(char);
            continue;
        }

        if (state_machine.element_decleration and !allowed_char) {
            const element = try state_machine.emit_element();
            if (!state_machine.multi_block_decleration) {
                try state_machine.dom_node.find_bottom_nt().push_child(element);
            } else {
                if (std.mem.eql(u8, element.identifier, state_machine.dom_node.find_bottom_nt().identifier)) {
                    state_machine.dom_node.find_bottom_nt().terminated = true;
                    state_machine.multi_block_decleration = false;
                } else return error.InvalidBreakChar;
            }

            state_machine.element_decleration = false;
            continue;
        }

        // Attrabutes

        if ((state_machine.attrabute_decleration and allowed_char) or (state_machine.element_block and !state_machine.element_decleration and allowed_char)) {
            state_machine.attrabute_decleration = true;
            try state_machine.string_builder.concat_byte(char);
        }

        if (state_machine.attrabute_decleration and char == '=') {
            state_machine.current_attrabute = stack.Attrabute{ .identifier = try state_machine.string_builder.to_string_alloc(), .value_text = "" };
            state_machine.string_builder.clear();
            state_machine.attrabute_value_decleration = true;
            continue;
        }

        if (state_machine.attrabute_value_decleration and !state_machine.expect_value and (char == '\'' or char == '"')) {
            state_machine.expect_value = true;
            state_machine.current_value_delimiter = char;
            continue;
        }

        if (state_machine.attrabute_value_decleration and state_machine.expect_value and (char != state_machine.current_value_delimiter)) {
            try state_machine.value_string_builder.concat_byte(char);
        }

        if (state_machine.attrabute_value_decleration and state_machine.expect_value and (char == state_machine.current_value_delimiter)) {
            state_machine.current_attrabute = try state_machine.emit_attrabute_value(state_machine.current_attrabute);

            if (state_machine.current_attrabute) |attrabute| {
                try state_machine.dom_node.find_bottom_nt().push_attrabute(attrabute);
            }

            continue;
        }

        if (state_machine.emit_whitespace()) {
            @branchHint(.likely);
            if (char != '\n' and char != '\t') {
                state_machine.text_block = true;
                state_machine.string_builder.concat_byte(char);
            }
            continue;
        }

        prev_char = char;
    }

    state_machine.dom_node.terminated = true;
    return state_machine.dom_node;
}

test "Basic Entry Element Parse" {
    const ts_allocator = std.testing.allocator;
    var arena = try ts_allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(ts_allocator);

    defer {
        arena.deinit();
        ts_allocator.destroy(arena);
    }

    const allocator = arena.allocator();
    var state_machine = try StateMachine.init(allocator);

    // TODO Work on how terminated values work and change find_bottom_nt to find_bottom within the parser

    var parsedDom = try parseHtml("<div><p id='a\"x'></p>", &state_machine);

    const div = parsedDom.find_bottom();
    const p = parsedDom.find_bottom_nt();

    try std.testing.expect(std.mem.eql(u8, "dom", parsedDom.identifier));
    try std.testing.expect(parsedDom.children.items.len > 0);
    try std.testing.expect(std.mem.eql(u8, div.identifier, "div"));
    try std.testing.expect(std.mem.eql(u8, p.identifier, "p"));
    try std.testing.expect(p.attrabutes.items.len > 0);
    try std.testing.expect(std.mem.eql(u8, p.attrabutes.items[0].value_text, "a\"x"));
    try std.testing.expect(std.mem.eql(u8, p.attrabutes.items[0].identifier, "id"));
}
