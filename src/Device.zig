name: []const u8,
address: []const u8,

state: State = .{},

const Device = @This();

pub const State = struct {
    presence: ?bool = null,
    detection_delay: ?bool = null,
    fading_time: ?bool = null,
    illuminance_lux: ?bool = null,
    interval_time: ?bool = null,
    linkquality: ?usize = null,
    minimum_range: ?f64 = null,
    maximum_range: ?f64 = null,
    target_distance: ?f64 = null,
    sensitivity: ?usize = null,
    power_on_behavior: ?PowerOn = null,

    // button thingy
    battery: ?f64 = null,
    action: ?Many = null,

    // Power meter
    voltage: ?f64 = null,
    ac_frequency: ?usize = null,
    state: ?PowerOn = null,
    power: ?f64 = null,
    current: ?f64 = null,
    power_factor: ?f64 = null,
    energy: ?f64 = null,

    // Sensor thingy
    battery_low: ?bool = null,
    tamper: ?bool = null,
    occupancy: ?bool = null,

    // Color Lights
    @"color-hue": ?usize = null,
    @"color-h": ?usize = null,
    @"color-saturation": ?usize = null,
    @"color-s": ?usize = null,
    @"color-x": ?f64 = null,
    @"color-y": ?f64 = null,
    @"color-temp": ?usize = null,
    brightness: ?usize = null,
    color_temp_startup: ?usize = null,
    color_temp: ?usize = null,
    color_mode: ?ColorMode = null,
};

pub const ManyKind = enum {
    power,
    buttons,
};

pub const Many = union(ManyKind) {
    power: PowerOn,
    buttons: Buttons,
};

pub const PowerOn = enum {
    on,
    off,
    toggle,
    previous,
};

pub const Buttons = enum {
    @"1_single",
    @"1_double",
    @"1_hold",
    @"2_single",
    @"2_double",
    @"2_hold",
    @"3_single",
    @"3_double",
    @"3_hold",
    @"4_single",
    @"4_double",
    @"4_hold",
};

pub const ColorMode = enum {
    color_temp,
};

pub fn initZ2m(zb: *Zigbee, z2m_bd: Z2m.bridge.devices) !Device {
    return .{
        .name = try zb.alloc.dupe(u8, z2m_bd.friendly_name orelse return error.InvalidDevice),
        .address = try zb.alloc.dupe(u8, z2m_bd.ieee_address orelse return error.InvalidDevice),
    };
}

pub fn updateTyped(d: *Device, T: type, comptime fname: []const u8, payload: []const u8) bool {
    const field: *T = &@field(d.state, fname);
    switch (T) {
        ?bool => {
            const next = if (eql(u8, payload, "true")) true else false;
            const edge = field.* == null or field.*.? != next;
            field.* = next;
            return edge;
        },
        ?usize => {
            const next: ?usize = parseInt(usize, payload, 0) catch |err| brk: {
                log.err(
                    "unable to parseInt on {s} with [{s}]{any} because {}",
                    .{ fname, payload, payload, err },
                );
                break :brk null;
            };

            if (next) |nxt| {
                const edge = field.* == null or field.*.? != nxt;
                field.* = nxt;
                return edge;
            } else {
                const edge = field.* != null;
                field.* = null;
                return edge;
            }
        },
        ?f64 => {
            const next: ?f64 = parseFloat(f64, payload) catch |err| brk: {
                log.err(
                    "unable to parseFloat on {s} with [{s}]{any} because {}",
                    .{ fname, payload, payload, err },
                );
                break :brk null;
            };

            if (next) |nxt| {
                const edge = field.* == null or field.*.? != nxt;
                field.* = nxt;
                return edge;
            } else {
                const edge = field.* != null;
                field.* = null;
                return edge;
            }
        },
        ?PowerOn, ?Buttons, ?ColorMode => {
            if (payload.len == 0) {
                defer field.* = null;
                return field.* != null;
            }
            inline for (@typeInfo(@typeInfo(T).optional.child).@"enum".fields) |en| {
                if (eqlAny(en.name, payload)) {
                    defer field.* = @enumFromInt(en.value);
                    return field.* == null or field.*.? != @as(T, @enumFromInt(en.value));
                }
            } else {
                log.err(
                    "unable to parse enum on {s} with [{s}]{any} for {s}",
                    .{ fname, payload, payload, d.name },
                );
                return false;
            }
        },
        ?Many => {
            if (payload.len == 0) {
                defer field.* = null;
                return field.* != null;
            }
            const prev_v = field.*;
            inline for (@typeInfo(@typeInfo(T).optional.child).@"union".fields) |un| {
                //const prev_t = field.* != null and field.* == un;
                inline for (@typeInfo(un.type).@"enum".fields) |en| {
                    if (eqlAny(en.name, payload)) {
                        const next = @unionInit(Many, un.name, @as(un.type, @enumFromInt(en.value)));
                        defer field.* = next;
                        return prev_v == null or @TypeOf(prev_v) != @TypeOf(next);
                    }
                }
            } else {
                log.err(
                    "unable to parse union on {s} with [{s}]{any} for {s}",
                    .{ fname, payload, payload, d.name },
                );
                return false;
            }
        },
        else => comptime unreachable,
    }
}

pub fn update(d: *Device, zb: *Zigbee, name: []const u8, payload: []const u8) !void {
    const target = name[d.name.len..];
    if (target.len == 0) return;
    inline for (@typeInfo(State).@"struct".fields) |field| {
        if (eql(u8, target[1..], field.name)) {
            if (d.updateTyped(field.type, field.name, payload)) {
                if (eql(u8, "office/mmw0", d.name) and eql(u8, target, "/presence")) {
                    log.err("sendable because {any}", .{payload});
                    try zb.client.send(mqtt.Publish{
                        .topic_name = "zigbee2mqtt/office/lights/set",
                        .packet_ident = null,
                        .properties = "",
                        .payload = if (d.state.presence.?) "ON" else "OFF",
                    });
                }
                if (!eql(u8, target, "/linkquality")) {
                    log.err("edge on [{s}] at {s} with {s}", .{ d.name, target, payload });
                }
            }
            return;
        }
    }
    // Sorry, trying to filter messages
    if (startsWith(u8, target, "/update")) {
        if (target.len > 7 and (target[7] == '-' or target[7] == '_')) {
            return;
        }
    }
    log.warn("device({s}) unsupported field {s} [{s}]-{any}", .{ d.name, target, payload, payload });
}

pub const Zigbee = @import("Zigbee.zig");
const Z2m = @import("z2m-data.zig").Z2m;

const mqtt = @import("mqtt");

const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const eqlAny = std.ascii.eqlIgnoreCase;
const startsWith = std.mem.startsWith;
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const log = std.log.scoped(.zigbee);
