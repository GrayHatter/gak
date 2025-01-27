pub const sun = @import("sun.zig");

pub fn main() !void {
    log.err("startup", .{});
    const a = std.heap.page_allocator;

    var client = mqtt.Client.init(a, "localhost", 1883, .{}) catch |e| {
        log.err("unable to connect to host", .{});
        return e;
    };

    if (try client.connect()) {
        try client.send(mqtt.Subscribe{ .channels = &.{"zigbee2mqtt/#"} });
    } else {
        log.err("Unable to connect", .{});
        @panic("not possible");
    }

    var zigbee = Zigbee.init(a, &client);

    while (client.recv()) |pkt| {
        switch (pkt) {
            .connack => {
                log.err("loop", .{});
                log.err("CONNACK", .{});
            },
            .publish => |publ| {
                //log.err("PUBLISH [{s}]", .{publ.topic_name});
                if (std.mem.startsWith(u8, publ.topic_name, "zigbee2mqtt")) {
                    try zigbee.publish(publ);
                }
            },
            .suback => {
                log.err("SUBACK ", .{});
            },
            else => |tag| {
                log.err("", .{});
                log.err("", .{});
                log.err("", .{});
                log.err("read [{s}]", .{@tagName(tag)});
                //log.err("discarding {}", .{@min(ready, reported)});
                log.err("", .{});
                log.err("", .{});
                log.err("", .{});
                //fifo.discard(@min(ready, reported));
            },
        }
    } else |err| {
        log.err("", .{});
        log.err("", .{});
        log.err("", .{});
        log.err("recv error [{any}]", .{err});
    }

    log.err("end going to exit", .{});
}

pub const Device = struct {
    name: []const u8,
    address: []const u8,

    state: State = .{},

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
        @"color-x": ?usize = null,
        @"color-y": ?usize = null,
        @"color-temp": ?usize = null,
        brightness: ?usize = null,
        color_temp_startup: ?usize = null,
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
            ?PowerOn, ?Buttons => {
                if (payload.len == 0) {
                    defer field.* = null;
                    return field.* != null;
                }
                inline for (@typeInfo(@typeInfo(T).Optional.child).Enum.fields) |en| {
                    if (eqlAny(en.name, payload)) {
                        defer field.* = @enumFromInt(en.value);
                        return field.* != null and field.*.? != @as(T, @enumFromInt(en.value));
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
                inline for (@typeInfo(@typeInfo(T).Optional.child).Union.fields) |un| {
                    //const prev_t = field.* != null and field.* == un;
                    inline for (@typeInfo(un.type).Enum.fields) |en| {
                        if (eqlAny(en.name, payload)) {
                            const next = @unionInit(Many, un.name, @as(un.type, @enumFromInt(en.value)));
                            defer field.* = next;
                            return prev_v != null and @TypeOf(prev_v) == @TypeOf(next);
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
        inline for (@typeInfo(State).Struct.fields) |field| {
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
        if (std.mem.startsWith(u8, target, "/update")) {
            if (target.len > 7 and (target[7] == '-' or target[7] == '_')) {
                return;
            }
        }
        log.warn("device({s}) unsupported field {s} [{s}]-{any}", .{ d.name, target, payload, payload });
    }
};

pub const Zigbee = struct {
    alloc: Allocator,
    client: *mqtt.Client,
    devices: std.ArrayList(Device),

    pub fn init(a: Allocator, client: *mqtt.Client) Zigbee {
        return .{
            .alloc = a,
            .client = client,
            .devices = std.ArrayList(Device).init(a),
        };
    }

    pub fn publish(zb: *Zigbee, p: mqtt.Publish) !void {
        if (std.mem.startsWith(u8, p.topic_name[11..], "/bridge")) {
            try zb.bridge(p);
        } else if (std.mem.startsWith(u8, p.topic_name[11..], "/bridge")) {} else {
            for (zb.devices.items) |*item| {
                if (std.mem.startsWith(u8, p.topic_name[12..], item.name)) {
                    //log.err("zigbee updating {s}", .{p.topic_name[12..]});
                    try item.update(zb, p.topic_name[12..], p.payload);
                    break;
                }
            } else {
                log.err("zigbee (maybe device?) {s} && {s}", .{ p.topic_name[11..], p.payload });
            }
        }
    }

    pub fn bridge(zb: *Zigbee, p: mqtt.Publish) !void {
        if (std.mem.startsWith(u8, p.topic_name[18..], "/info")) {
            const res = try std.json.parseFromSlice(
                Z2m.bridge.info,
                std.heap.page_allocator,
                p.payload,
                .{ .ignore_unknown_fields = true },
            );

            log.err("info {any}", .{res.value});
            log.err("info payload {s}", .{p.payload});
        } else if (std.mem.startsWith(u8, p.topic_name[18..], "/devices")) {
            const res = try std.json.parseFromSlice(
                []Z2m.bridge.devices,
                std.heap.page_allocator,
                p.payload,
                .{ .ignore_unknown_fields = true },
            );

            for (res.value) |r| {
                log.err("devices {s}", .{r.friendly_name orelse "name is empty"});
                try zb.devices.append(try Device.initZ2m(zb, r));
                if (r.definition) |def| {
                    if (def.exposes) |exps| for (exps) |exp| {
                        if (exp.name) |name| log.err("     exp {s}", .{name});
                    };
                }
            }
        } else if (std.mem.startsWith(u8, p.topic_name[18..], "/groups")) {
            const res = try std.json.parseFromSlice(
                []Z2m.bridge.groups,
                std.heap.page_allocator,
                p.payload,
                .{ .ignore_unknown_fields = true },
            );
            for (res.value) |r| {
                log.err("{}", .{r});
            }
        } else if (std.mem.startsWith(u8, p.topic_name[18..], "/definitions")) {
            const res = std.json.parseFromSlice(
                Z2m.bridge.definitions,
                std.heap.page_allocator,
                p.payload,
                .{ .ignore_unknown_fields = true },
            ) catch {
                log.err("ERROR FOR {s}", .{p.topic_name[18..]});
                log.err("DUMP {s}", .{p.payload[0..]});
                return;
            };
            log.err("{}", .{res.value});
        } else if (std.mem.startsWith(u8, p.topic_name[18..], "/extensions")) {
            const res = try std.json.parseFromSlice(
                []Z2m.bridge.extensions,
                std.heap.page_allocator,
                p.payload,
                .{ .ignore_unknown_fields = false },
            );
            for (res.value) |r| {
                log.err("{}", .{r});
            }
        } else if (std.mem.startsWith(u8, p.topic_name[18..], "/logging")) {
            const res = try std.json.parseFromSlice(
                Z2m.bridge.logging,
                std.heap.page_allocator,
                p.payload,
                .{ .ignore_unknown_fields = false },
            );
            _ = res;
            //log.warn("[{s}] -- {s}", .{ res.value.level, res.value.message });
        } else {
            log.err("skipped {s}", .{p.topic_name[18..]});
            log.err("pre {s}", .{p.payload[0..]});
        }
    }
};

test "main" {
    std.testing.refAllDecls(@This());
    _ = &sun;
}

const mqtt = @import("mqtt");
const Rules = @import("rules.zig");
const Z2m = @import("z2m-data.zig").Z2m;

const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const eqlAny = std.ascii.eqlIgnoreCase;
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const log = std.log.scoped(.zigbee);
const AnyReader = std.io.AnyReader;
const AnyWriter = std.io.AnyWriter;
