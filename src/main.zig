const std = @import("std");
const render = @import("render.zig");
const types = @import("types.zig");
const Noun = types.Noun;

const ASCII_DELETE = 127;
const ASCII_BACKSPACE = 8;

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
    characters: [64]u8 = [_]u8 { ' ' } ** 64,
};

var state = State {};

pub fn main() !void {
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut();

    try render.init(out, &state.term);
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

        if (isDigitCharacter(byte)) {
            if (state.command.verb == null) {
                state.command.verb = @enumFromInt(byte - 49);
                state.term.cursor_x += @intCast(enumLen(Verb, state.command.verb.?));
            } else {
                if (state.command.noun == null) {
                    state.command.noun = @enumFromInt(byte - 49);
                    state.term.cursor_x += @intCast(enumLen(Noun, state.command.noun.?));
                }
            }
            @memset(&state.command.characters, ' ');
        }

        if (isAllowedCommandCharacter(byte)) {
            var placed: bool = false;
            for (&state.command.characters) |*char| {
                if (!placed and char.* == ' ') {
                    char.* = byte;
                    placed = true;
                    state.term.cursor_x += 1;
                }
            }
        }
        // backspace or delete
        if (byte == ASCII_BACKSPACE or byte == ASCII_DELETE) {
            var deleted: bool = false;
            // loop through backwards
            for (0..state.command.characters.len) |i| {
                const j = state.command.characters.len - i - 1;
                if (!deleted and state.command.characters[j] != ' ') {
                    state.command.characters[j] = ' ';
                    deleted = true;
                    state.term.cursor_x -= 1;
                }
            }
        }
        if (byte == '\t') {
            const typed_characters = currentPartialCommandCharacters();
            var completed: bool = false;
            if (state.command.verb == null) {
                inline for (@typeInfo(Verb).@"enum".fields) |f| {
                    if (!completed and std.mem.startsWith(u8, f.name, typed_characters)) {
                        state.command.verb = @enumFromInt(f.value);
                        state.term.cursor_x += f.name.len;
                        completed = true;
                    }
                }
            } else {
                if (state.command.noun == null) {
                    inline for (@typeInfo(Noun).@"enum".fields) |f| {
                        if (!completed and std.mem.startsWith(u8, f.name, typed_characters)) {
                            state.command.noun = @enumFromInt(f.value);
                            state.term.cursor_x += f.name.len;
                            completed = true;
                        }
                    }
                }
            }
            if (completed) {
                state.term.cursor_x -= @intCast(typed_characters.len);
                state.term.cursor_x += 1;
                @memset(&state.command.characters, ' ');
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

fn isAllowedCommandCharacter(byte: u8) bool {
    return (byte >= 97 and byte <= 122) or (byte == '=') or (byte == '-');
}
fn isDigitCharacter(byte: u8) bool {
    return (byte >= '0' and byte <= '9');
}

fn enumLen(comptime T: type, en: T) usize {
    inline for (@typeInfo(T).@"enum".fields, 0..) |f, i| {
        if (i == @intFromEnum(en)) {
            return f.name.len + 1;
        }
    }
    return 0;
}

fn drawState(buffer: []u8) void {
    // draw the current version of the cli command
    var pos: usize = movePosToNextLine(0);
    pos += 4;
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
    pos += 1;
    // their hand-typed characters
    @memcpy(buffer[pos..(state.command.characters.len+pos)], &state.command.characters);
    pos += state.command.characters.len;
    pos = movePosToNextLine(pos);

    // draw the completion options
    pos += (7 + appname.len);
    const typed_characters = currentPartialCommandCharacters();
    if (state.command.verb == null) {
        inline for (@typeInfo(Verb).@"enum".fields) |f| {
            if (std.mem.startsWith(u8, f.name, typed_characters)) {
                buffer[pos] = @intCast(49+f.value);
                pos += 1;
                buffer[pos] = '.';
                pos += 1;
                buffer[pos] = ' ';
                pos += 1;
                @memcpy(buffer[pos..(f.name.len+pos)], f.name);
                pos += f.name.len;
                pos = movePosToNextLine(pos);
                pos += (7 + appname.len);
            }
        }
    } else {
        if (state.command.noun == null) {
            inline for (@typeInfo(Noun).@"enum".fields) |f| {
                if (std.mem.startsWith(u8, f.name, typed_characters)) {
                    pos += enumLen(Verb, state.command.verb.?);
                    buffer[pos] = @intCast(49+f.value);
                    pos += 1;
                    buffer[pos] = '.';
                    pos += 1;
                    buffer[pos] = ' ';
                    pos += 1;
                    @memcpy(buffer[pos..(f.name.len+pos)], f.name);
                    pos += f.name.len;
                    pos = movePosToNextLine(pos);
                    pos += (7 + appname.len);
                }
            }
        }
    }
}

fn currentPartialCommandCharacters() []u8 {
    const first_space_index = std.mem.indexOfScalar(u8, &state.command.characters, ' ') orelse 64;
    return state.command.characters[0..first_space_index];
}

fn movePosToNextLine(pos: usize) usize {
    return pos + (state.term.width - (pos % state.term.width));
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
