const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("ez_turing_machine", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const test_runner = std.Build.Step.Compile.TestRunner{
        .mode = .simple,
        .path = b.path("test_runner.zig"),
    };
    const test_step = b.step("test", "Run tests");
    const mod_tests = b.addTest(.{ .root_module = mod, .test_runner = test_runner });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    test_step.dependOn(&run_mod_tests.step);

    // Build examples
    const Example = struct {
        path: []const u8,
        name: []const u8,
    };
    const examples = [_]Example{
        .{ .path = "examples/basic/main.zig", .name = "basic" },
    };

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "ez_turing_machine", .module = mod },
                },
            }),
        });

        const run_step = b.step("run_example_" ++ example.name, "Run example " ++ example.name);
        const run_exe = b.addRunArtifact(exe);
        run_step.dependOn(&run_exe.step);

        const example_tests = b.addTest(.{ .root_module = exe.root_module, .test_runner = test_runner });
        const run_example_tests = b.addRunArtifact(example_tests);
        test_step.dependOn(&run_example_tests.step);
    }
}
