pub const Rules = struct {
    // edge falling device/name/attribute
    //
    //   do <complex target>
    //   set <device> [verb] <noun>
    // when office/mmw0/presence goes false set office/lights off
    // when office/mmw0/presence goes true  set office/lights on
    //
    // sequence
    //
    //

    pub const Rule = struct {
        rule: Kind,
        target: []const u8,
        action: Action = .{},

        pub const Kind = union(enum) {
            edge: Direction,
            slope: struct {
                direction: Direction,
                vect: f64,
            },
        };

        pub const Direction = enum {
            falling,
            rising,
        };

        pub const Action = struct {};
    };

    pub fn parse(a: Allocator, str: []const u8) ![]Rule {
        var list = std.ArrayList(Rule).init(a);
        errdefer list.deinit();
        var tokens = std.mem.tokenizeScalar(u8, str, ' ');

        while (tokens.next()) |next| {
            if (eqlAny(next, "edge")) {
                const peek = tokens.peek() orelse return error.InvalidSyntax;

                if (eqlAny(peek, "falling")) {
                    try list.append(.{
                        .rule = .{ .edge = .falling },
                        .target = "",
                    });
                    _ = tokens.next();
                } else {
                    try list.append(.{
                        .rule = .{ .edge = .rising },
                        .target = "",
                    });
                    _ = tokens.next();
                }
            }
        }
        return try list.toOwnedSlice();
    }

    test parse {
        const a = std.testing.allocator;

        const empty = try parse(a, "");
        try std.testing.expectEqual(&[0]Rule{}, empty);

        const one = try parse(a, "edge falling");
        defer a.free(one);
        try std.testing.expectEqualDeep(&[1]Rule{.{
            .rule = .{ .edge = .falling },
            .target = "",
        }}, one);

        const one_ri = try parse(a, "edge rising");
        defer a.free(one_ri);
        try std.testing.expectEqualDeep(&[1]Rule{.{
            .rule = .{ .edge = .rising },
            .target = "",
        }}, one_ri);
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const eqlAny = std.ascii.eqlIgnoreCase;
