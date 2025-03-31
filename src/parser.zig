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
    current_value_delimiter: u8 = 0x0,
    value_string_builder: sb.StringBuilder,
    string_builder: sb.StringBuilder,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !StateMachine {
        return .{
            .allocator = allocator,
            .string_builder = try sb.StringBuilder.init(allocator, "", .multi, null),
            .value_string_builder = try sb.StringBuilder.init(allocator, "", .multi, null),
        };
    }

    pub fn deinit(self: *StateMachine) void {
        self.string_builder.deinit();
        self.value_string_builder.deinit();
    }

    pub fn emit_whitespace(self: *StateMachine) bool {
        return !self.text_block and !self.expect_value and !self.element_decleration and !self.attrabute_decleration and !self.attrabute_value_decleration and !self.element_block;
    }

    pub fn emit_element(self: *StateMachine, current_element: *stack.Element) !stack.Element {
        const element = try self.string_builder.to_string();
        std.debug.print("current_element: {s} changing to: {s}\n", .{ current_element.identifier, element });
        const child = try stack.Element.init_child(element, current_element);
        self.string_builder.clear();
        return child;
    }

    pub fn emit_attrabute(self: *StateMachine) !stack.Attrabute {
        const attrabute = try self.string_builder.to_string();
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
            const string: []const u8 = try self.value_string_builder.to_string();
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

pub fn parseHtml(file_bytes: []const u8, state_machine: *StateMachine, allocator: std.mem.Allocator) !stack.Element {
    var dom = try stack.Element.init(allocator, "dom", null);

    //const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    //defer file.close();

    //const file_len = try file.getEndPos();
    //const file_bytes: []const u8 = try file.readToEndAlloc(allocator, @intCast(file_len));
    //defer allocator.free(file_bytes);

    var prev_char: ?u8 = undefined;

    var current_element: *stack.Element = &dom;
    var current_attrabute: ?stack.Attrabute = null;

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
                var element = try state_machine.emit_element(current_element);
                try current_element.push_child(element);
                current_element = &element;
            } else if (state_machine.attrabute_decleration) {
                current_attrabute = try state_machine.emit_attrabute();
                if (current_attrabute != null) {
                    //try current_element.push_attrabute(current_attrabute.?);
                }
            }

            state_machine.element_block = false;
            state_machine.attrabute_decleration = false;
            state_machine.element_decleration = false;
            continue;
        }

        // Elements
        if (state_machine.element_block and !state_machine.element_decleration and char == '/') {
            current_element.terminated = true;
            if (current_element.parent) |parent| {
                current_element = parent;
            }
            continue;
        }

        if (state_machine.element_block and state_machine.element_decleration and allowed_char) {
            try state_machine.string_builder.concat_byte(char);
            continue;
        }

        if (state_machine.element_decleration and !allowed_char) {
            var element = try state_machine.emit_element(current_element);
            try current_element.push_child(element);
            current_element = &element;
            state_machine.element_decleration = false;
            continue;
        }

        // Attrabutes

        if ((state_machine.attrabute_decleration and allowed_char) or (state_machine.element_block and !state_machine.element_decleration and allowed_char)) {
            state_machine.attrabute_decleration = true;
            try state_machine.string_builder.concat_byte(char);
        }

        if (state_machine.attrabute_decleration and char == '=') {
            current_attrabute = stack.Attrabute{ .identifier = try state_machine.string_builder.to_string(), .value_text = "" };
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
            current_attrabute = try state_machine.emit_attrabute_value(current_attrabute);

            if (current_attrabute) |attrabute| {
                try current_element.push_attrabute(attrabute);
            }

            continue;
        }

        if (state_machine.emit_whitespace()) {
            @branchHint(.likely);
            continue;
        }

        prev_char = char;
    }

    dom.terminated = true;

    return dom;
}

test "Basic Entry Element Parse" {
    const ts_allocator = std.testing.allocator;

    var state_machine = try StateMachine.init(ts_allocator);
    defer state_machine.deinit();

    var parsedDom = try parseHtml("<tb><p>", &state_machine, ts_allocator);
    defer parsedDom.deinit();

    try std.testing.expect(std.mem.eql(u8, "dom", parsedDom.identifier));

    try std.testing.expect(parsedDom.children.items.len > 0);

    const div = parsedDom.find_bottom_nt();
    std.debug.print("Parent: {s}\n", .{div.parent.?.identifier});
    std.debug.print("Bottom: {s}\n", .{div.identifier});
    try std.testing.expect(std.mem.eql(u8, div.identifier, "div"));
}
