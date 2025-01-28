alloc: Allocator,
client: *mqtt.Client,
devices: std.ArrayList(Device),

const Zigbee = @This();

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

pub const Device = @import("Device.zig");

const Z2m = @import("z2m-data.zig").Z2m;
const mqtt = @import("mqtt");

const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const eqlAny = std.ascii.eqlIgnoreCase;
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const log = std.log.scoped(.zigbee);
const AnyReader = std.io.AnyReader;
const AnyWriter = std.io.AnyWriter;
