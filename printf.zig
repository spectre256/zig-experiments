const std = @import("std");
const expectEqual = std.testing.expectEqual;

fn printfArgNum(comptime fmt: []const u8) comptime_int {
    var seen_perc = false;
    var len = 0;

    inline for (fmt) |c| {
        if (seen_perc) {
            if (c != '%') len += 1;
            seen_perc = false;
            continue;
        }
        seen_perc = c == '%';
    }

    return len;
}

fn PrintfArgs(comptime fmt: []const u8) type {
    const len = comptime printfArgNum(fmt);

    var types: [len]type = .{undefined} ** len;
    var types_i = 0;
    var seen_perc = false;
    inline for (fmt) |c| {
        if (!seen_perc) {
            seen_perc = c == '%';
            continue;
        }

        if (c != '%') {
            const ty: type = switch (c) {
                's' => []const u8,
                'c' => u8,
                'd' => i64,
                'f' => f64,
                else => @compileError("Invalid format type '" ++ [_]u8{c} ++ "' in format string '" ++ fmt ++ "'"),
            };

            types[types_i] = ty;
            types_i += 1;
        }
        seen_perc = false;
    }

    return std.meta.Tuple(&types);
}

test "printf args" {
    const fmt = "%s (%d s) %% %f %f";
    try expectEqual(4, printfArgNum(fmt));
    try expectEqual(std.meta.Tuple(&.{ []const u8, i64, f64, f64 }), PrintfArgs(fmt));
}

fn printf(comptime fmt: []const u8, args: PrintfArgs(fmt)) !void {
    const stdout = std.io.getStdOut();
    var buf = std.io.bufferedWriter(stdout.writer());
    defer buf.flush() catch unreachable;
    var writer = buf.writer();

    comptime var seen_perc = false;
    comptime var arg_i = 0;

    inline for (fmt) |c| {
        if (!seen_perc and c == '%') {
            seen_perc = true;
            continue;
        }

        if (seen_perc and c != '%') {
            const arg = args[arg_i];

            const fmt_str = switch (@TypeOf(arg)) {
                []const u8 => "{s}",
                u8 => "{c}",
                i64, f64 => "{d}",
                else => "{any}",
            };
            try writer.print(fmt_str, .{arg});

            arg_i += 1;
        } else {
            try writer.print("{c}", .{c});
        }
        seen_perc = false;
    }
}

test "printf" {
    try printf("\n", .{}); // For better formatting
    try printf("Hello, %s!\n", .{"World"});
    try printf("%d / %d = %f. \n", .{ 3, 5, 0.6 });
    try printf("This is 100%% %s\n", .{if (true) "correct" else "incorrect"}); // If "true" was replaced with a runtime value, this would still work
    // The only caveat is that the format string must be available at compile time
}
