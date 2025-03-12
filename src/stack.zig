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
        for (0..self.children.items.len) |index| {
            var child = self.children.items[index];
            child.deinit();
        }

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

    /// Finds the bottom of the tree without regards to termination
    /// e.g. <div><p> </p></div> would find <p> as div hasnt been terminated yet
    pub fn find_bottom_nt(self: *Element) *Element {
        if (self.children.items.len == 0) {
            return self;
        }

        const bottom: *Element = self.children.items[self.children.items.len - 1].find_bottom();

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

test "Find bottom 1" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    defer element.deinit();

    var div = try Element.init_child("div", &element);
    const p = try Element.init_child("p", &div);

    try div.push_child(p);
    try element.push_child(div);

    const bottom = element.find_bottom();
    try std.testing.expectEqual("p", bottom.identifier);
}

test "Find bottom 2" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    defer element.deinit();

    var div = try Element.init_child("div", &element);
    var p = try Element.init_child("p", &div);
    p.terminated = true;

    try div.push_child(p);
    try element.push_child(div);

    const bottom = element.find_bottom();
    try std.testing.expectEqual("div", bottom.identifier);
}

test "Find bottom 3" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    defer element.deinit();

    var div = try Element.init_child("div", &element);
    var p = try Element.init_child("p", &div);
    p.terminated = true;

    const span = try Element.init_child("span", &div);

    try div.push_child(p);
    try div.push_child(span);
    try element.push_child(div);

    const bottom = element.find_bottom();
    try std.testing.expectEqual("span", bottom.identifier);
}

test "Find bottom nt 1" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    defer element.deinit();

    var div = try Element.init_child("div", &element);
    var p = try Element.init_child("p", &div);
    p.terminated = true;

    try div.push_child(p);
    try element.push_child(div);

    const bottom = element.find_bottom_nt();
    std.debug.print("bottom: {s}\n", .{bottom.identifier});
    try std.testing.expectEqual("p", bottom.identifier);
}
