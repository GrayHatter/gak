alloc: Allocator,
rules: std.ArrayList(Rule),

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

const Rules = @This();
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

pub fn init(a: Allocator) Rules {
    return .{
        .alloc = a,
        .rules = std.ArrayList(Rule).init(a),
    };
}

pub fn raze(r: *Rules) void {
    r.rules.deinit();
}

pub fn parseLine(str: []const u8) !Rule {
    var tokens = std.mem.tokenizeScalar(u8, str, ' ');

    while (tokens.next()) |next| {
        if (eqlAny(next, "edge")) {
            const peek = tokens.peek() orelse return error.InvalidSyntax;

            if (eqlAny(peek, "falling")) {
                return .{
                    .rule = .{ .edge = .falling },
                    .target = "",
                };
            } else {
                return .{
                    .rule = .{ .edge = .rising },
                    .target = "",
                };
            }
        }
    }
    return error.UnableToBuildRule;
}

pub fn parseFile(r: *Rules, str: []const u8) !void {
    var lines = std.mem.tokenizeScalar(u8, str, '\n');
    while (lines.next()) |line| {
        r.rules.append(try r.parseLine(line) catch |err| switch (err) {
            error.UnableToBuildRule => continue,
            else => return err,
        });
    }
}

test parseLine {
    const a = std.testing.allocator;
    var r = init(a);
    defer r.raze();

    const empty = parseLine("");
    try std.testing.expectError(error.UnableToBuildRule, empty);

    const rule_fall = try parseLine("edge falling");
    try std.testing.expectEqualDeep(Rule{
        .rule = .{ .edge = .falling },
        .target = "",
    }, rule_fall);

    const rule_rise = try parseLine("edge rising");
    try std.testing.expectEqualDeep(Rule{
        .rule = .{ .edge = .rising },
        .target = "",
    }, rule_rise);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const eqlAny = std.ascii.eqlIgnoreCase;
