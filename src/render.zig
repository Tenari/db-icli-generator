const std = @import("std");
const clear = "\x1B[1J"; //https://github.com/ziglibs/ansi_term/blob/master/src/clear.zig

var display: [1024 * 4]u8 = undefined;
var cursor_x: u16 = 0;
var cursor_y: u16 = 0;

// Terminal size dimensions
const TermSize = struct {
    // Terminal width as measured number of characters that fit into a terminal horizontally
    width: u16,
    // terminal height as measured number of characters that fit into terminal vertically
    height: u16,
};

var terminal_size = TermSize {
    .width = 80,
    .height = 20,
};

// the fundamental unit of rendering. The caller hands us a Page, and we render it.
// when the user does something, we send back events for something else to manage state.
pub const Page = []Node;

pub const Node = struct {
    as: NodeType,
    menu: ?Menu = null,
    text: ?[]const u8 = null,
    input: ?[]Input = null,
};

pub const NodeType = enum {
    menu,
    text,
    input
};

pub const Menu = struct {
    options: []MenuOption,
    selectedindex: usize = 0,
};

pub const MenuOption = struct {
    name: []const u8,
    changepage: ?u64 = null,
    quit: bool = false,
};

pub const Input = struct {
    label: []const u8,
    len: u16,
    value: []u8,
};

pub fn init(out: std.fs.File) !void {
    try out.writeAll("\x1B[?1049h\x1B[?25l"); // go to alternate buffer, and hide cursor
    // prevent terminal echoing characters
    var term = try std.posix.tcgetattr(out.handle);
    term.lflag.ECHO = false;
    term.lflag.ICANON = false;
    try std.posix.tcsetattr(out.handle, std.posix.TCSA.NOW, term);
}

pub fn deinit(out: std.fs.File) void {
    out.writeAll("\x1B[?1049l\x1B[?25h") catch unreachable; // return from alternate buffer and show cursor
}

pub fn render(terminal: std.fs.File, page: Page) !void {
    // test terminal size
    {
        _ = terminal.getOrEnableAnsiEscapeSupport();
        var buf: std.posix.system.winsize = undefined;
        terminal_size = switch (std.posix.errno(
            std.posix.system.ioctl(
                terminal.handle,
                std.posix.T.IOCGWINSZ,
                @intFromPtr(&buf),
            ),
        )) {
            .SUCCESS => TermSize{
                .width = buf.col,
                .height = buf.row,
            },
            else => return error.IoctlError,
        };
    }
    // clear the display buffer
    display = [_]u8{ ' ' } ** (1024*4);
    var buffer_pos: usize = 0;
    for (page) |node| {
        switch (node.as) {
            .menu => {
                buffer_pos = renderMenuToBuffer(&display, node.menu.?, buffer_pos);
            },
            .text => {
                buffer_pos = renderTextToBuffer(&display, node.text.?, buffer_pos);
            },
            .input => {
            },
        }
    }

    // clear screen
    try terminal.writeAll(clear);
    // move to 0,0
    try terminal.writeAll("\x1B[1;1H");
    // render the buffer
    try terminal.writeAll(&display);
    // move to current cursor position
    try terminal.writer().print("\x1B[{};{}H", .{cursor_y + 1, cursor_x + 1});
}

const highlightpre = "\x1B[47;30m";
const highlightpost = "\x1B[0m";
fn renderMenuToBuffer(buffer: []u8, menu: Menu, start_pos: usize) usize {
    var pos = start_pos;
    for (menu.options, 0..) |option, i| {
        buffer[pos] = ' ';
        pos += 1;
        buffer[pos] = ' ';
        pos += 1;
        buffer[pos] = @intCast(49+i);
        pos += 1;
        buffer[pos] = '.';
        pos += 1;
        buffer[pos] = ' ';
        pos += 1;
        if (i == menu.selectedindex) {
            @memcpy(buffer[pos..(pos + highlightpre.len)], highlightpre);
            pos += highlightpre.len;
        }
        @memcpy(buffer[pos..(pos + option.name.len)], option.name);
        pos += option.name.len;
        if (i == menu.selectedindex) {
            @memcpy(buffer[pos..(pos + highlightpost.len)], highlightpost);
            pos += highlightpost.len;
        }
        for (0..(terminal_size.width - 5 - option.name.len)) |_| {
            buffer[pos] = ' ';
            pos += 1;
        }
    }
    return pos;
}

fn renderTextToBuffer(buffer: []u8, text: []const u8, pos: usize) usize {
    var final_pos = pos + text.len;
    @memcpy(buffer[pos..final_pos], text);
    // pad the remainder of the line
    for (0..(terminal_size.width - text.len)) |_| {
        buffer[final_pos] = ' ';
        final_pos += 1;
    }
    // print a new line
    for (0..terminal_size.width) |_| {
        buffer[final_pos] = ' ';
        final_pos += 1;
    }
    return final_pos;
}

const Direction = enum {up, down};
pub fn moveSelectedIndex(page: *Page, direction: Direction) void {
    for (page.*) |*node| {
        if (node.menu) |*menu| {
            switch (direction) {
                .down => {
                    if (menu.options.len-1 > menu.selectedindex) {
                        menu.selectedindex += 1;
                    } else {
                        menu.selectedindex = 0;
                    }
                },
                .up => {
                    if (menu.selectedindex == 0) {
                        menu.selectedindex = menu.options.len - 1;
                    } else {
                        menu.selectedindex -= 1;
                    }
                },
            }
        }
    }
}

pub fn currentMenu(page: Page) ?Menu {
    for (page) |node| {
        if (node.menu) |menu| {
            return menu;
        }
    }
    return null;
}
