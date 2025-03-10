const std = @import("std");

pub const Element = struct {
    identifier: [*:0]const u8,
    terminated: bool,
    text: std.ArrayList(TextAllocation),
    parent: ?*const Element,
    children: std.ArrayList(Element),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, identifier: [*:0]const u8, parent: ?*const Element) !Element {
        return .{
            .identifier = identifier,
            .terminated = false,
            .text = std.ArrayList(TextAllocation).init(allocator),
            .parent = parent,
            .children = std.ArrayList(Element).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn init_child(identifier: [*:0]const u8, parent: *const Element) !Element {
        return .{
            .identifier = identifier,
            .terminated = false,
            .text = std.ArrayList(TextAllocation).init(parent.allocator),
            .parent = parent,
            .children = std.ArrayList(Element).init(parent.allocator),
            .allocator = parent.allocator,
        };
    }

    pub fn deinit(self: *Element) void {
        self.children.deinit();
        self.text.deinit();
    }

    pub fn push_child(self: *Element, identifier: [*:0]const u8) !void {
        const new_child = try init_child(identifier, self);
        try self.children.append(new_child);
    }
};

pub const TextAllocation = struct { text: []const u8, allocated_index: i32 };
