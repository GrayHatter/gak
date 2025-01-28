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
                if (startsWith(u8, publ.topic_name, "zigbee2mqtt")) {
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
                log.err("", .{});
                log.err("", .{});
                log.err("", .{});
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

pub const Device = @import("Device.zig");
pub const Zigbee = @import("Zigbee.zig");

test "main" {
    _ = &sun;
    _ = &Rules;
    _ = &Device;
    _ = &Zigbee;
}

const mqtt = @import("mqtt");
const Rules = @import("rules.zig");
const Z2m = @import("z2m-data.zig").Z2m;

const std = @import("std");
const log = std.log.scoped(.zigbee);
const startsWith = std.mem.startsWith;
