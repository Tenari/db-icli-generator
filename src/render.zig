const std = @import("std");
// ansi codes
const clear = "\x1B[1J"; //https://github.com/ziglibs/ansi_term/blob/master/src/clear.zig
const highlightpre = "\x1B[47;30m";
const highlightpost = "\x1B[0m";

// Terminal size dimensions
pub const TermSizeAndLoc = struct {
    // Terminal width as measured number of characters that fit into a terminal horizontally
    width: u16,
    // terminal height as measured number of characters that fit into terminal vertically
    height: u16,
    cursor_x: u16 = 14,
    cursor_y: u16 = 1,
};

pub fn init(out: std.fs.File, terminal_size: *TermSizeAndLoc) !void {
    try out.writeAll("\x1B[?1049h"); // go to alternate buffer
    // prevent terminal echoing characters
    var term = try std.posix.tcgetattr(out.handle);
    term.lflag.ECHO = false;
    term.lflag.ICANON = false;
    try std.posix.tcsetattr(out.handle, std.posix.TCSA.NOW, term);
    try testAndUpdateTerminalSize(out, terminal_size);
}

pub fn deinit(out: std.fs.File) void {
    out.writeAll("\x1B[?1049l\x1B[?25h") catch unreachable; // return from alternate buffer and show cursor
}

fn testAndUpdateTerminalSize(terminal: std.fs.File, terminal_size: *TermSizeAndLoc) !void {
    _ = terminal.getOrEnableAnsiEscapeSupport();
    var buf: std.posix.system.winsize = undefined;
    switch (std.posix.errno(
        std.posix.system.ioctl(
            terminal.handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&buf),
        ),
    )) {
        .SUCCESS => {
            terminal_size.width = buf.col;
            terminal_size.height = buf.row;
        },
        else => return error.IoctlError,
    }
}

pub fn render(terminal: std.fs.File, buffer: []u8, terminal_size: *TermSizeAndLoc) !void {
    // test terminal size
    try testAndUpdateTerminalSize(terminal, terminal_size);
    // clear screen
    try terminal.writeAll(clear);
    // move to 0,0
    try terminal.writeAll("\x1B[1;1H");
    // render the buffer
    try terminal.writeAll(buffer[0..(terminal_size.width*terminal_size.height)]);
    // move to current cursor position
    try terminal.writer().print("\x1B[{};{}H", .{terminal_size.cursor_y + 1, terminal_size.cursor_x + 1});
}

// centers within terminal_size.width, or TODO truncates columns
pub fn drawTable(
    comptime T: type,
    buffer: []u8,
    terminal_size: TermSizeAndLoc,
    rows: []T
) !void {
    var pos: usize = 0;
    var table_width: usize = 0;
    inline for (@typeInfo(T).@"struct".fields) |f| {
        table_width += 2 + f.name.len;
    }
    const margin = (terminal_size.width - table_width) / 2;

    // print the headers
    pos += margin;
    inline for (@typeInfo(T).@"struct".fields) |f| {
        @memcpy(buffer[pos..(f.name.len+pos)], f.name);
        pos += f.name.len + 1;
        buffer[pos] = '|';
        pos += 1;
    }
    pos = movePosToNextLine(pos, terminal_size.width);
    for (rows) |row| {
        if (pos < buffer.len - 1 and pos / terminal_size.height < terminal_size.height - 1) {
            pos += margin;
            inline for (@typeInfo(T).@"struct".fields) |f| {
                var mini_buf = [_]u8 { ' ' } ** 1024;
                switch (@typeInfo(f.@"type")) {
                    .pointer => {
                        _ = try std.fmt.bufPrint(&mini_buf, "{?s}", .{ @field(row, f.name) });
                    },
                    .optional => |opt| {
                        if (@field(row, f.name)) |prop| {
                            switch (@typeInfo(opt.child)) {
                                .pointer => {
                                    _ = try std.fmt.bufPrint(&mini_buf, "{s}", .{ prop });
                                },
                                else => {
                                    _ = try std.fmt.bufPrint(&mini_buf, "{}", .{ prop });
                                }
                            }
                        }
                    },
                    .@"enum" => {
                        _ = try std.fmt.bufPrint(&mini_buf, "{}", .{ @field(row, f.name) });
                    },
                    else => {
                        _ = try std.fmt.bufPrint(&mini_buf, "{}", .{ @field(row, f.name) });
                    },
                }
                @memcpy(buffer[pos..(f.name.len+pos)], mini_buf[0..f.name.len]);
                pos += f.name.len + 1;
                buffer[pos] = '|';
                pos += 1;
            }
            pos = movePosToNextLine(pos, terminal_size.width);
        }
    }
}

pub fn movePosToNextLine(pos: usize, width: u16) usize {
    if (width == 0) {
        return pos;
    } 
    return pos + (width - (pos % width));
}

