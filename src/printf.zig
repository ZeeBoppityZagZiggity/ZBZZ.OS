/// Calls print and then flushes the buffer.
pub fn printf(self: *OutStream, comptime format: []const u8, args: ...) anyerror!void {
    const State = enum {
        Start,
        OpenBrace,
        CloseBrace,
    };

    comptime var start_index: usize = 0;
    comptime var state = State.Start;
    comptime var next_arg: usize = 0;

    inline for (format) |c, i| {
        switch (state) {
            State.Start => switch (c) {
                '{' => {
                    if (start_index < i) try self.write(format[start_index..i]);
                    state = State.OpenBrace;
                },
                '}' => {
                    if (start_index < i) try self.write(format[start_index..i]);
                    state = State.CloseBrace;
                },
                else => {},
            },
            State.OpenBrace => switch (c) {
                '{' => {
                    state = State.Start;
                    start_index = i;
                },
                '}' => {
                    try self.printValue(args[next_arg]);
                    next_arg += 1;
                    state = State.Start;
                    start_index = i + 1;
                },
                else => @compileError("Unknown format character: " ++ c),
            },
            State.CloseBrace => switch (c) {
                '}' => {
                    state = State.Start;
                    start_index = i;
                },
                else => @compileError("Single '}' encountered in format string"),
            },
        }
    }
    comptime {
        if (args.len != next_arg) {
            @compileError("Unused arguments");
        }
        if (state != State.Start) {
            @compileError("Incomplete format string: " ++ format);
        }
    }
    if (start_index < format.len) {
        try self.write(format[start_index..format.len]);
    }
    try self.flush();
}

pub fn printValue(self: *OutStream, value: var) !void {
    const T = @typeOf(value);
    if (@isInteger(T)) {
        return self.printInt(T, value);
    } else if (@isFloat(T)) {
        return self.printFloat(T, value);
    } else {
        @compileError("Unable to print type '" ++ @typeName(T) ++ "'");
    }
}