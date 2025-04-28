const std = @import("std");
const render = @import("render.zig");
const types = @import("types.zig");
const Noun = types.Noun;

const appname = "rabbits";

const State = struct {
    command: Command = .{},
    //options: ?[]MenuOption = null,
    running: bool = true,
    term: render.TermSizeAndLoc = render.TermSizeAndLoc {
        .width = 80, .height = 10,
    },
};

const Verb = enum {
    create, read, update, delete
};

const Command = struct {
    verb: ?Verb = null,
    noun: ?Noun = null,
};

var state = State {};

pub fn main() !void {
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut();

    try render.init(out);
    defer render.deinit(out);

    var input: [32]u8 = undefined;
    while (state.running) {
        var display_buffer = [_]u8 { ' ' } ** (1024*4);
        drawState(&display_buffer);
        try render.render(out, &display_buffer, &state.term);
        // get user input
        input = [_]u8{ 0 } ** 32;
        _ = try in.read(&input);
        const byte = input[0];
        // Q
        if (byte == 81) {
            state.running = false;
        }
        // ENTER/return
        //if (byte == 10) {
        //    handleSelection(null);
        //}
        // digit selection
        if (byte > 48 and byte < 58) {
            if (state.command.verb == null) {
                state.command.verb = @enumFromInt(byte - 49);
                state.term.cursor_x += @intCast(verbLen(state.command.verb.?));
            } else {
                if (state.command.noun == null) {
                    state.command.noun = @enumFromInt(byte - 49);
                    state.term.cursor_x += @intCast(nounLen(state.command.noun.?));
                }
            }
        }
        // up
        //if (byte == 'k' or std.mem.eql(u8, input[0..3], "\x1B[A")) {
        //    render.moveSelectedIndex(&current_page, .up);
        //}
        //// down
        //if (byte == 'j' or std.mem.eql(u8, input[0..3], "\x1B[B")) {
        //    render.moveSelectedIndex(&current_page, .down);
        //}
        //// right
        //if (byte == 'l' or std.mem.eql(u8, input[0..3], "\x1B[C")) {
        //    cursor_x += 1;
        //}
        //// left
        //if ((byte == 'h' or std.mem.eql(u8, input[0..3], "\x1B[D")) and cursor_x > 0) {
        //    cursor_x -= 1;
        //}
    }
    std.debug.print("bye!", .{});

    //var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    //const allocator = gpa.allocator();
    //var args = try std.process.argsWithAllocator(allocator);
    //_ = args.skip(); // ignore program name
    //const first_arg = args.next();
    //std.debug.print("first_arg: {s}\n", .{first_arg.?});
    //while (args.next()) |arg| {
    //    std.debug.print("arg: {s}\n", .{arg});
    //    if (std.mem.eql(u8, arg, "fuck")) {
    //        std.debug.print("no, fuck you\n", .{});
    //    }
    //}
}

fn verbLen(verb: Verb) usize {
    //return @typeInfo(Verb).@"enum".fields[@intFromEnum(verb)].name.len;
    inline for (@typeInfo(Verb).@"enum".fields, 0..) |f, i| {
        if (i == @intFromEnum(verb)) {
            return f.name.len + 1;
        }
    }
    return 0;
}
fn nounLen(noun: Noun) usize {
    inline for (@typeInfo(Noun).@"enum".fields, 0..) |f, i| {
        if (i == @intFromEnum(noun)) {
            return f.name.len + 1;
        }
    }
    return 0;
}

fn drawState(buffer: []u8) void {
    var pos: usize = 0;
    buffer[pos] = '\n';
    pos += 5;
    buffer[pos] = '$';
    pos += 2;
    @memcpy(buffer[pos..(appname.len+pos)], appname);
    pos += appname.len;
    if (state.command.verb) |v| {
        pos += 1;
        const verb_name = @tagName(v);
        @memcpy(buffer[pos..(verb_name.len+pos)], verb_name);
        pos += verb_name.len;
    }
    if (state.command.noun) |n| {
        pos += 1;
        const name = @tagName(n);
        @memcpy(buffer[pos..(name.len+pos)], name);
        pos += name.len;
    }
    buffer[pos] = '\n';
    pos += (8 + appname.len);
    if (state.command.verb == null) {
        inline for (@typeInfo(Verb).@"enum".fields) |f| {
            buffer[pos] = @intCast(49+f.value);
            pos += 1;
            buffer[pos] = '.';
            pos += 1;
            buffer[pos] = ' ';
            pos += 1;
            @memcpy(buffer[pos..(f.name.len+pos)], f.name);
            pos += f.name.len;
            buffer[pos] = '\n';
            pos += (8 + appname.len);
        }
    } else {
        if (state.command.noun == null) {
            inline for (@typeInfo(Noun).@"enum".fields) |f| {
                pos += verbLen(state.command.verb.?);
                buffer[pos] = @intCast(49+f.value);
                pos += 1;
                buffer[pos] = '.';
                pos += 1;
                buffer[pos] = ' ';
                pos += 1;
                @memcpy(buffer[pos..(f.name.len+pos)], f.name);
                pos += f.name.len;
                buffer[pos] = '\n';
                pos += (8 + appname.len);
            }
        }
    }
}

//fn handleSelection(index: ?usize) void {
//    if (render.currentMenu(current_page)) |menu| {
//        const option = menu.options[index orelse menu.selectedindex];
//        if (option.quit) {
//            running = false;
//        } else if (option.changepage) |pg| {
//            const named: NamedPage = @enumFromInt(pg);
//            current_page = switch (named) {
//                .main => &mainpage,
//                .animals => &animalspage,
//                .events => &eventspage,
//                else => &mainpage,
//            };
//        }
//    }
//}
