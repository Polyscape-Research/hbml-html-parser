const std = @import("std");
const stack = @import("stack.zig");
const sb = @import("string_builder.zig");

const Token = packed struct {
    token: u8,
    term_token: u8,

    pub fn eql(self: *Token, char: u8) bool {
        return self.token == char;
    }

    pub fn eql_term(self: *Token, char: u8) bool {
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
    string_builder: sb.StringBuilder,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StateMachine {
        return .{
            .allocator = allocator,
            .string_builder = sb.StringBuilder.init(allocator, "", .multi, null),
        };
    }

    pub fn emit_whitespace(self: *StateMachine) bool {
        return !self.text_block and !self.element_decleration and !self.attrabute_decleration and !self.element_block;
    }

    pub fn emit_element(self: *StateMachine, current_element: *stack.Element) stack.Element {
        const element = try self.string_builder.to_string();
        self.string_builder.clear();
        const child = try current_element.init_child(element, current_element);
        current_element.push_child(child);
        return child;
    }

    pub fn emit_attrabute(self: *StateMachine) stack.Attrabute {
        const attrabute = try self.string_builder.to_string();
        self.string_builder.clear();
        return .{ .identifier = attrabute, .value_text = "" };
    }

    pub fn allowed_char(char: u8) bool {
        // a-zA-Z
        return (char >= 0x41 and char <= 0x5A) or (char >= 0x61 and char <= 0x7A);
    }
};

pub fn parseHtml(file_bytes: []const u8, allocator: std.mem.Allocator) !stack.Element {
    var dom = try stack.Element.init(allocator, "dom", null);

    //const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    //defer file.close();

    //const file_len = try file.getEndPos();
    //const file_bytes: []const u8 = try file.readToEndAlloc(allocator, @intCast(file_len));
    //defer allocator.free(file_bytes);

    var state_machine = StateMachine{};

    var prev_char: ?u8 = undefined;

    var current_element: *stack.Element = &dom;
    var current_attrabute: ?stack.Attrabute = null;

    for (file_bytes, 0..) |char, index| {
        _ = index;

        const allowed_char = state_machine.allowed_char(char);

        if (state_machine.emit_whitespace()) {
            @branchHint(.likely);
            continue;
        }

        if (!state_machine.element_block and Token.Tokens[0].eql(char)) {
            @branchHint(.likely);
            state_machine.element_block = true;
            state_machine.element_decleration = true;
            continue;
        }

        if (state_machine.element_block and Token.Tokens[0].eql_term(char)) {
            @branchHint(.likely);

            if (state_machine.element_decleration) {
                current_element = state_machine.emit_element(&current_element);
            } else if (state_machine.attrabute_decleration) {
                current_attrabute = state_machine.emit_attrabute();
                current_element.push_attrabute(current_attrabute);
            }

            state_machine.element_block = false;
            state_machine.attrabute_decleration = false;
            state_machine.element_decleration = false;
            continue;
        }

        // Elements

        if (state_machine.element_block and !state_machine.element_decleration and char == '/') {
            current_element.terminated = true;
            current_element = current_element.parent;
        }

        if (state_machine.element_block and state_machine.element_decleration and allowed_char) {
            state_machine.string_builder.concat_byte(char);
            continue;
        }

        if (state_machine.element_decleration and !allowed_char) {
            current_element = state_machine.emit_element(&current_element);
            state_machine.element_decleration = false;
        }

        // Attrabutes

        if ((state_machine.attrabute_decleration and allowed_char) or (state_machine.element_block and !state_machine.element_decleration and allowed_char)) {
            state_machine.attrabute_decleration = true;
            state_machine.string_builder.concat_byte(char);
        }

        if (state_machine.attrabute_decleration and char == '=') {}

        prev_char = char;
    }
}
