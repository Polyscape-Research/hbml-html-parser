const std = @import("std");

pub const Attrabute = struct {
    identifier: [*:0]const u8,
    value_text: [*:0]const u8,
};

pub const Element = struct {
    identifier: [*:0]const u8,
    terminated: bool,
    text: std.ArrayList(TextAllocation),
    parent: ?*const Element,
    children: std.ArrayList(Element),
    attrabutes: std.ArrayList(Attrabute),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, identifier: [*:0]const u8, parent: ?*const Element) !Element {
        return .{
            .identifier = identifier,
            .terminated = false,
            .text = std.ArrayList(TextAllocation).init(allocator),
            .parent = parent,
            .children = std.ArrayList(Element).init(allocator),
            .attrabutes = std.ArrayList(Attrabute).init(allocator),
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
            .attrabutes = std.ArrayList(Attrabute).init(parent.allocator),
            .allocator = parent.allocator,
        };
    }

    pub fn deinit(self: *Element) void {
        self.children.deinit();
        self.text.deinit();
        self.attrabutes.deinit();
    }

    pub fn push_child(self: *Element, child: Element) !void {
        try self.children.append(child);
    }

    pub fn push_attrabute(self: *Element, attrabute: Attrabute) !void {
        try self.attrabutes.append(attrabute);
    }

    /// Finds the bottom of the tree that is terminated
    /// e.g. <div><p> </p> would find <div> as div hasnt been terminated yet
    pub fn find_bottom(self: *Element) *Element {
        if (self.children.items.len == 0) {
            return self;
        }

        const bottom: *Element = self.children.items[self.children.items.len - 1].find_bottom();

        if (bottom.terminated) {
            return self;
        }

        return bottom;
    }

    /// Finds the top of the tree
    pub fn find_top(self: *Element) *Element {
        if (self.parent != null) {
            return self.parent.?.find_top();
        }

        return self;
    }
};

pub const TextAllocation = struct { text: []const u8, allocated_index: i32 };

test "Find bottom" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    var div = try Element.init_child("div", &element);
    const p = try Element.init_child("p", &div);

    try element.push_child(div);
    try div.push_child(p);

    const bottom = element.find_bottom();
    try std.testing.expectEqual("p", bottom.identifier);
}
