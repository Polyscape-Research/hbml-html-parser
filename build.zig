const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const simd = b.option(bool, "simd", "Enables/disables support for SIMD algors") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "simd", simd);

    //    const lib_mod = b.createModule(.{
    //        .root_source_file = b.path("src/root.zig"),
    //        .target = target,
    //        .optimize = optimize,
    //    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    //    exe_mod.addImport("hbml_html_parser_lib", lib_mod);

    //   const lib = b.addLibrary(.{
    //       .linkage = .static,
    //        .name = "hbml_html_parser",
    //        .root_module = lib_mod,
    //    });

    //    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "hbml_html_parser",
        .root_module = exe_mod,
    });

    exe.root_module.addOptions("build_options", options);

    exe.addIncludePath(b.path("src"));

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const stack_tests = b.addTest(.{ .root_source_file = b.path("./src/stack.zig") });
    stack_tests.root_module.addOptions("build_options", options);
    stack_tests.addIncludePath(b.path("src"));
    const parser_tests = b.addTest(.{ .root_source_file = b.path("./src/parser.zig") });
    parser_tests.root_module.addOptions("build_options", options);
    parser_tests.addIncludePath(b.path("src"));

    const run_stack_tests = b.addRunArtifact(stack_tests);
    //const run_parser_tests = b.addRunArtifact(parser_tests);
    //    const lib_unit_tests = b.addTest(.{
    //        .root_module = lib_mod,
    //   });

    //    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    exe_unit_tests.root_module.addOptions("build_options", options);

    exe_unit_tests.addIncludePath(b.path("src"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_stack_tests.step);
    //    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
