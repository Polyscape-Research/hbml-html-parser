const std = @import("std");

pub const StringBuilderAlloc = enum {
    multi,
    inc,
};

pub const StringBuilder = struct {
    alloc_option: StringBuilderAlloc,
    position: usize,
    expand_len: usize = 128,
    string: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, starting_string: []const u8, alloc_option: StringBuilderAlloc, expand_len: ?usize) !StringBuilder {
        var position: usize = 0;
        const string_alloc = try allocator.alloc(u8, @max(expand_len orelse 128, starting_string.len));

        if (string_alloc.len == starting_string.len) {
            @branchHint(.unlikely);
            @memcpy(string_alloc, starting_string);
            position = string_alloc.len;
        } else {
            @branchHint(.likely);
            @memset(string_alloc, 0x0);

            for (starting_string, 0..) |byte, index| {
                string_alloc[index] = byte;
                position += 1;
            }
        }

        return .{
            .alloc_option = alloc_option,
            .string = string_alloc,
            .allocator = allocator,
            .position = position,
            .expand_len = expand_len orelse 128,
        };
    }

    pub fn deinit(self: *StringBuilder) void {
        self.allocator.free(self.string);
    }

    pub fn expand(self: *StringBuilder, amount_needed: ?usize) !void {
        var string_alloc: []u8 = undefined;

        if (self.alloc_option == .inc) {
            string_alloc =
                try self.allocator.alloc(u8, @max(amount_needed orelse 0, self.expand_len) + self.string.len);
        } else {
            var amount = (amount_needed orelse 0) + self.string.len;
            const muli_amount = self.string.len * 2;

            if (amount < muli_amount) {
                @branchHint(.likely);
                amount = muli_amount;
            }

            string_alloc = try self.allocator.alloc(u8, amount);
        }

        for (string_alloc, 0..) |_, index| {
            if (index < self.string.len) {
                string_alloc[index] = self.string[index];
            } else {
                string_alloc[index] = 0x0;
            }
        }

        self.allocator.free(self.string);
        self.string = string_alloc;
    }

    pub fn concat_string(self: *StringBuilder, string: []const u8) !void {
        if (string.len + self.position >= self.string.len) {
            @branchHint(.likely);
            try expand(self, string.len);
        }

        for (string) |byte| {
            self.string[self.position] = byte;
            self.position += 1;
        }
    }

    pub fn concat_byte(self: *StringBuilder, byte: u8) !void {
        if (self.position + 1 >= self.string.len) {
            @branchHint(.unlikely);
            try expand(self, 1);
        }

        self.string[self.position] = byte;
        self.position += 1;
    }

    pub fn clear(self: *StringBuilder) void {
        self.position = 0;
    }

    pub fn to_string(self: *StringBuilder) ![]const u8 {
        return self.string[0..self.position];
    }
};

test "init StringBuilder" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "hello", .inc, null);
    defer sb.deinit();

    const eql = std.mem.eql(u8, "hello", try sb.to_string());
    try std.testing.expectEqual(eql, true);
}

test "expand StringBuilder" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "hello", .inc, null);
    defer sb.deinit();

    try sb.expand(null);

    const eql = std.mem.eql(u8, "hello", try sb.to_string());
    try std.testing.expectEqual(eql, true);
}

test "concat_string StringBuilder" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "hello", .inc, null);
    defer sb.deinit();

    try sb.concat_string("hello2");

    const eql = std.mem.eql(u8, "hellohello2", try sb.to_string());
    try std.testing.expectEqual(eql, true);
}

test "concat_string with expand StringBuilder" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "hello", .inc, 5);
    defer sb.deinit();

    try sb.concat_string("hello2");

    const eql = std.mem.eql(u8, "hellohello2", try sb.to_string());
    try std.testing.expectEqual(eql, true);
}

test "concat_string with multi expands" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "hello", .inc, 5);
    defer sb.deinit();
    const start = std.time.milliTimestamp();

    try sb.concat_string("hello2");
    try sb.concat_string("hello3");
    try sb.concat_string("hello4");
    try sb.concat_string("hello5");

    const eql = std.mem.eql(u8, "hellohello2hello3hello4hello5", try sb.to_string());
    const end = std.time.milliTimestamp() - start;
    std.debug.print("time taken: {d}ms\n", .{end});
    try std.testing.expectEqual(eql, true);
}

test "concat_string with large strings" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "hello", .multi, 1000);
    defer sb.deinit();

    // number 1 ascii code
    const x: [1000]u8 = @splat(0x31);

    const start = std.time.milliTimestamp();

    try sb.concat_string(&x);
    try sb.concat_string(&x);
    try sb.concat_string(&x);
    try sb.concat_string(&x);
    try sb.concat_string(&x);
    try sb.concat_string(&x);
    try sb.concat_string(&x);
    try sb.concat_string(&x);

    const string = try sb.to_string();

    const end = std.time.milliTimestamp() - start;
    std.debug.print("time taken: {d}ms\n", .{end});

    const eql = std.mem.eql(u8, "hello" ++ x ++ x ++ x ++ x ++ x ++ x ++ x ++ x, string);
    try std.testing.expectEqual(eql, true);
}

test "concat_byte StringBuilder" {
    const t_alloc = std.testing.allocator;

    var sb =
        try StringBuilder.init(t_alloc, "", .inc, 5);
    defer sb.deinit();
    const start = std.time.milliTimestamp();

    try sb.concat_byte('1');
    try sb.concat_byte('2');
    try sb.concat_byte('3');
    try sb.concat_byte('4');
    try sb.concat_byte('5');
    try sb.concat_byte('6');

    const eql = std.mem.eql(u8, "123456", try sb.to_string());
    const end = std.time.milliTimestamp() - start;
    std.debug.print("time taken: {d}ms\n", .{end});
    try std.testing.expectEqual(eql, true);
}
