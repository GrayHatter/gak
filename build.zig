const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_mqtt = b.dependency("mqtt", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "herbomony",
        .root_source_file = b.path("src/zigbee.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mqtt", dep_mqtt.module("mqtt"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/zigbee.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("mqtt", dep_mqtt.module("mqtt"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
