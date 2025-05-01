const std = @import("std");
//const c = @cImport({
//    @cInclude("c/simd.h");
//});

const vector_size_bool = 16;
const comp_vector_btm: @Vector(vector_size_bool, u8) = @splat(0);

pub const Attrabute = struct {
    identifier: []const u8,
    value_text: []const u8,
};

pub const Dom = struct {
    elements: std.MultiArrayList(Element_),
    // 1: Index of element | 2: Attrabute
    attrabutes: std.AutoHashMap(u32, Attrabute),
    // 1: Index of element | 2: TextAllocation
    text_allocations: std.AutoHashMap(u32, TextAllocation),
    // 1: Index of element | 2: Identifier String
    identifiers: std.AutoHashMap(u32, []const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Dom {
        return .{ .elements = std.MultiArrayList(Element_){}, .attrabutes = std.AutoHashMap(u32, Attrabute).init(allocator), .text_allocations = std.AutoHashMap(u32, TextAllocation).init(allocator), .identifiers = std.AutoHashMap(u32, []const u8).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Dom) void {
        self.attrabutes.deinit();
        self.text_allocations.deinit();
        self.identifiers.deinit();
        self.elements.deinit(self.allocator);
    }

    pub fn appendTopElement(self: *Dom, element: *Element_, identifier: []const u8) !void {
        const next_index: u32 = @intCast(self.elements.len);

        element.element_index = next_index;
        try self.elements.append(self.allocator, element.*);
        try self.identifiers.put(next_index, identifier);
    }

    pub fn appendElement(self: *Dom, element: *Element_, identifier: []const u8) !u32 {
        // get new index
        const next_index: u32 = @intCast(self.elements.len);
        try element.children_index.append(next_index);

        try self.elements.append(self.allocator, .{ .terminated = false, .parent_index = element.element_index, .element_index = next_index, .children_index = std.ArrayList(u32).init(self.allocator) });

        try self.identifiers.put(next_index, identifier);

        return next_index;
    }

    pub fn appendAttrabute(self: *Dom, attrabute: Attrabute, element_index: u32) !void {
        try self.attrabutes.put(element_index, attrabute);
    }

    pub fn find_bottom(self: *Dom) Element_ {
        const items = self.elements.items(.terminated);

        var index: usize = 0;

        // 16 bytes is 128 bits and 1 bool is 1 byte
        if (items.len < vector_size_bool) {
            @branchHint(.unlikely);
            for (items, 0..) |value, idx| {
                if (value == false) index = idx;
            }
        } else {
            const mod = items.len % vector_size_bool;
            const batch = items.len / vector_size_bool;
            var i: usize = 0;

            while (i < batch) : (i += 1) {
                const offset = i * vector_size_bool;

                var input_vector: @Vector(vector_size_bool, u8) = undefined;

                // TODO seg fault on mac os when running this at address 0x0 most likly something to do with the simd registers and the aligned bytes
                // Not sure if this is fixed yet
                const input_v_ptr: *[vector_size_bool]u8 = @ptrCast(@alignCast(&input_vector));
                const input_d_ptr: *[vector_size_bool]u8 = @ptrCast(@alignCast(items.ptr + offset));

                // Should copy the memory  in one instruction so for each 16 comparisions there is the SIMD instruction and the copy instruction
                // Though this might need some beanchmarking still
                @memcpy(input_v_ptr, input_d_ptr);

                const match: @Vector(vector_size_bool, bool) = input_vector == comp_vector_btm;

                index = @intCast(std.simd.lastTrue(match) orelse index);
                index += offset;
            }

            // goes over remainders
            if (mod > 0) {
                for (batch * vector_size_bool..items.len) |idx| {
                    if (items[idx] == false) index = idx;
                }
            }
        }

        return self.elements.get(index);
    }

    pub fn set_element(self: *Dom, element: Element_) !void {
        self.elements.set(element.element_index, element);
    }

    pub fn set_terminated(self: *Dom, element: *Element_) !void {
        element.terminated = true;
        self.elements.set(element.element_index, element.*);
    }
};

pub const Element_ = struct {
    // no padding as we are using a MultiArrayList
    terminated: bool, // 1
    parent_index: u32, // 4
    element_index: u32, // 4
    // is there a way to remove this list?
    children_index: std.ArrayList(u32), // ?,
};

test "Find bottom (dod + simd) 1" {
    const allocator = std.testing.allocator;

    //    const a: c_int = 2;
    //    const b: c_int = 2;
    //
    //    const add: c_int = c.find_bottom_simd(a, b);
    //    std.debug.print("{d}", .{add});

    var dom = Dom.init(allocator);
    defer dom.deinit();

    var div: Element_ = .{ .children_index = std.ArrayList(u32).init(allocator), .element_index = 0, .parent_index = 0, .terminated = true };
    defer div.children_index.deinit();

    try dom.appendTopElement(&div, "div");
    for (0..16) |_| {
        _ = try dom.appendElement(&div, "p");
    }

    var last = dom.elements.get(dom.elements.len - 1);
    try dom.set_terminated(&last);
    const element = dom.find_bottom();

    const id = dom.identifiers.get(element.element_index).?;
    try std.testing.expect(element.element_index == 15);
    try std.testing.expect(std.mem.eql(u8, "p", id));
}

test "Find bottom (dod + simd) 2" {
    const allocator = std.testing.allocator;

    var dom = Dom.init(allocator);
    defer dom.deinit();

    var div: Element_ = .{ .children_index = std.ArrayList(u32).init(allocator), .element_index = 0, .parent_index = 0, .terminated = true };
    defer div.children_index.deinit();

    try dom.appendTopElement(&div, "div");
    const p_index = try dom.appendElement(&div, "p");

    var p_element = dom.elements.get(p_index);
    _ = try dom.appendElement(&p_element, "span");
    defer p_element.children_index.deinit();

    const element = dom.find_bottom();

    const id = dom.identifiers.get(element.element_index).?;
    //try std.testing.expect(element.element_index == 15);
    try std.testing.expect(std.mem.eql(u8, "span", id));
}

pub const Element = struct {
    identifier: []const u8,
    terminated: bool,
    text: std.ArrayList(TextAllocation),
    parent: ?*Element,
    children: std.ArrayList(Element),
    attrabutes: std.ArrayList(Attrabute),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, identifier: []const u8, parent: ?*Element) !Element {
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

    pub fn init_child(identifier: []const u8, parent: *Element) !Element {
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
        //if (self.strings_allocated) {
        //    if (self.identifier.len > 0) {
        //        self.allocator.free(self.identifier);
        //    }

        //    for (0..self.attrabutes.items.len) |index| {
        //        self.allocator.free(self.attrabutes.items[index].identifier);
        //        self.allocator.free(self.attrabutes.items[index].value_text);
        //    }

        //    for (0..self.text.items.len) |index| {
        //        self.allocator.free(self.text.items[index].text);
        //    }
        //}

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
    /// e.g. <div><p> </p></div> would find <p> as its the bottom of the node tree
    pub fn find_bottom_nt(self: *Element) *Element {
        if (self.children.items.len == 0) {
            return self;
        }

        const bottom: *Element = self.children.items[self.children.items.len - 1].find_bottom_nt();

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

// TODO look into if we really need allocated_index or if it can be calculated
pub const TextAllocation = struct {
    text: []const u8,
    allocated_index: u32,
};

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
    try std.testing.expectEqual("p", bottom.identifier);
}

test "Find bottom nt 2" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    defer element.deinit();

    var div = try Element.init_child("div", &element);
    var p = try Element.init_child("p", &div);
    p.terminated = true;

    const p2 = try Element.init_child("p2", &div);

    try div.push_child(p);
    try div.push_child(p2);
    try element.push_child(div);

    const bottom = element.find_bottom_nt();
    try std.testing.expectEqual("p2", bottom.identifier);
}

test "Find Top 1" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "dom", null);
    defer element.deinit();

    var div = try Element.init_child("div", &element);
    var span = try Element.init_child("span", &div);
    var p = try Element.init_child("p", &span);

    try span.push_child(p);
    try div.push_child(span);
    try element.push_child(div);

    const top1 = p.find_top();
    try std.testing.expectEqual("dom", top1.identifier);

    const top2 = span.find_top();
    try std.testing.expectEqual("dom", top2.identifier);
}
