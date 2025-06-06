const std = @import("std");
const render = @import("render.zig");
const types = @import("types.zig");
const Noun = types.Noun;
const commands = @import("commands.zig");
const zqlite = @import("zqlite");

const ASCII_DELETE = 127;
const ASCII_BACKSPACE = 8;
const ASCII_ENTER = 10;

const appname = "rabbits";
const prompt_start_x = 7 + appname.len;
const create_sql_size = 1362;

const State = struct {
    command: Command = .{},
    running: bool = true,
    term: render.TermSizeAndLoc = render.TermSizeAndLoc {
        .width = 80, .height = 10,
    },
    current_menu: ?Menu = null,

    fn resetMenu(self: *State) void {
        self.current_menu = null;
        self.term.cursor_y = 1;
    }
};

const Menu = struct {
    selection_index: usize = 0,
    len: usize,

    fn move(self: *Menu, direction: ArrowDirection) void {
        switch (direction) {
            .down => if (self.selection_index < self.len - 1) {
                self.selection_index += 1;
            } else {
                self.selection_index = 0;
            },
            .up => if (self.selection_index == 0) {
                self.selection_index = self.len - 1;
            } else {
                self.selection_index -= 1;
            },
            else => unreachable,
        }
    }
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
    var gpa = std.heap.GeneralPurposeAllocator(.{.thread_safe=true}){};
    const gpa_allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory leak", .{});
    };
    // for now just guessing that we only need 1MB
    const memory: []u8 = gpa_allocator.alloc(u8, 1024*1024) catch |err| {
        std.log.err("Could not alloc from heap: {s}", .{ @errorName(err) });
        return;
    };
    defer gpa_allocator.free(memory);
    var fba = std.heap.FixedBufferAllocator.init(memory);
    const allocator = fba.threadSafeAllocator();

    const flags =  zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;
    var db = try zqlite.open("./rabbits.sqlite", flags);
    defer db.close();
    // prep db if not exists. run create table statements
    {
        const file = std.fs.cwd().openFile("./rabbits/rabbits.sql", .{}) catch |err| {
            std.log.err("Failed to open file: {s}", .{@errorName(err)});
            return;
        };
        defer file.close();

        var create_statements = [_:0]u8 {0} ** create_sql_size;
        const read_size = file.reader().readAll(&create_statements) catch |err| {
            std.log.err("Failed to read ./rabbits/rabbits.sql: {s}", .{@errorName(err)});
            return;
        };
        std.debug.assert(read_size == create_sql_size);

        db.execNoArgs(&create_statements) catch |err| {
            std.log.err("{s}", .{ db.lastError() });
            std.log.err("Failed to execute statement: {s}\n{?any}", .{@errorName(err), @errorReturnTrace()});
            return;
        };
    }
    // TODO if they passed in (valid) cli args, just do the command and output
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut();

    try render.init(out, &state.term);
    defer render.deinit(out);

    var input: [32]u8 = undefined;
    var display_buffer = try allocator.alloc(u8, 64*256);
    @memset(display_buffer, ' ');
    while (state.running) {
        drawState(display_buffer);
        try render.render(out, display_buffer, &state.term);
        // get user input
        input = [_]u8{ 0 } ** 32;
        _ = try in.read(&input);
        const byte = input[0];

        // update state based on input

        //if (byte > 33 and byte < 127) {
        //    display_buffer[0] = byte;
        //}

        // Q
        if (byte == 81) {
            state.running = false;
        }
        // ENTER/return
        if (byte == ASCII_ENTER) {
            //display_buffer[0] = '\\';
            //display_buffer[1] = 'n';
            std.log.err("enter pressed", .{});
            if (state.current_menu) |menu| {
                if (state.command.verb == null) {
                    state.command.verb = @enumFromInt(menu.selection_index);
                    state.resetMenu();
                } else {
                    if (state.command.noun == null) {
                        state.command.noun = @enumFromInt(menu.selection_index);
                        state.resetMenu();
                    }
                }
            } else {
                if (state.command.noun) |noun| {
                    // TODO: parse the command and do the thing
                    // for read: set `state.table = RESULTS FROM SQLite matching `
                    if (state.command.verb == .read) {
                        var arena = std.heap.ArenaAllocator.init(allocator);
                        defer arena.deinit();
                        const alloc = arena.allocator();
                        std.log.err("trying to run read() command", .{});
                        const start_pos = state.term.width * 7;
                        switch (noun) {
                            .breed => try commands.read(types.Breed, alloc, db, display_buffer[start_pos..], noun, state.term),
                            .animal => try commands.read(types.Animal, alloc, db, display_buffer[start_pos..], noun, state.term),
                            .weight => try commands.read(types.Weight, alloc, db, display_buffer[start_pos..], noun, state.term),
                            .event => try commands.read(types.Event, alloc, db, display_buffer[start_pos..], noun, state.term),
                        }
                        state.command.verb = null;
                        state.command.noun = null;
                        @memset(&state.command.characters, ' ');
                    }
                }
            }
        }

        if (isDigitCharacter(byte)) {
            if (state.command.verb == null) {
                state.command.verb = @enumFromInt(byte - 49);
            } else {
                if (state.command.noun == null) {
                    state.command.noun = @enumFromInt(byte - 49);
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
                }
            }
            if (!deleted) {
                if (state.command.noun != null) {
                    state.command.noun = null;
                } else if (state.command.verb != null) {
                    state.command.verb = null;
                }
            }
        }
        if (byte == '\t') {
            var completed: bool = false;
            const typed_characters = currentPartialCommandCharacters();
            if (state.command.verb == null) {
                inline for (@typeInfo(Verb).@"enum".fields) |f| {
                    if (!completed and std.mem.startsWith(u8, f.name, typed_characters)) {
                        state.command.verb = @enumFromInt(f.value);
                        completed = true;
                    }
                }
            } else {
                if (state.command.noun == null) {
                    inline for (@typeInfo(Noun).@"enum".fields) |f| {
                        if (!completed and std.mem.startsWith(u8, f.name, typed_characters)) {
                            state.command.noun = @enumFromInt(f.value);
                            completed = true;
                        }
                    }
                }
            }
            if (completed) {
                @memset(&state.command.characters, ' ');
                state.resetMenu();
            }
        }

        if (isUpOrDownArrow(input[0..3])) {
            if (state.current_menu) |*menu| {
                const direction = inputToArrowDirectionEnum(input[0..3]) catch unreachable;
                menu.move(direction);
            } else {
                attemptToInitMenu();
            }
        }

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
fn isUpOrDownArrow(input: *[3]u8) bool {
    const direction = inputToArrowDirectionEnum(input) catch return false;
    return direction == ArrowDirection.up or direction == ArrowDirection.down;
}
fn inputToArrowDirectionEnum(input: *[3]u8) !ArrowDirection {
    if (std.mem.eql(u8, input, "\x1B[A")) {
        return .up;
    } else if (std.mem.eql(u8, input, "\x1B[B")) {
        return .down;
    } else if (std.mem.eql(u8, input, "\x1B[C")) {
        return .right;
    } else if (std.mem.eql(u8, input, "\x1B[D")) {
        return .left;
    } else {
        return error.InputNotAnArrowKey;
    }
}

const ArrowDirection = enum {
    up, down, right, left
};

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
    var pos: usize = movePosToAndClearNextLine(0, buffer);
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
    pos = movePosToAndClearNextLine(pos, buffer);

    // draw the completion options
    pos += prompt_start_x;
    const typed_characters = currentPartialCommandCharacters();
    var menu_draw_start_pos = pos;
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
                pos = movePosToAndClearNextLine(pos, buffer);
                pos += prompt_start_x;
            }
        }
    } else {
        if (state.command.noun == null) {
            var first: bool = true;
            inline for (@typeInfo(Noun).@"enum".fields) |f| {
                if (std.mem.startsWith(u8, f.name, typed_characters)) {
                    if (first) {
                        first = false;
                        menu_draw_start_pos += enumLen(Verb, state.command.verb.?);
                    }
                    pos += enumLen(Verb, state.command.verb.?);
                    buffer[pos] = @intCast(49+f.value);
                    pos += 1;
                    buffer[pos] = '.';
                    pos += 1;
                    buffer[pos] = ' ';
                    pos += 1;
                    @memcpy(buffer[pos..(f.name.len+pos)], f.name);
                    pos += f.name.len;
                    pos = movePosToAndClearNextLine(pos, buffer);
                    pos += prompt_start_x;
                }
            }
        }
    }
    while (pos / state.term.width < 5) {
        pos = movePosToAndClearNextLine(pos, buffer);
    }

    // handle cursor position
    // either in the menu
    if (state.current_menu) |menu| {
        state.term.cursor_x = @truncate(menu_draw_start_pos % state.term.width);
        const extra_menu_index_y_bump: u16 = @truncate(menu.selection_index);
        const draw_menu_start_y: u16 = @truncate(menu_draw_start_pos / state.term.width);
        state.term.cursor_y = draw_menu_start_y + extra_menu_index_y_bump;
    } else { // or on the command prompt line
        const first_space_index: u16 = @intCast(std.mem.indexOfScalar(u8, &state.command.characters, ' ') orelse 64);
        state.term.cursor_y = 1;
        state.term.cursor_x = @intCast(prompt_start_x + first_space_index);
        if (state.command.verb) |v| {
            state.term.cursor_x += @intCast(enumLen(Verb, v));
            if (state.command.noun) |n| {
                state.term.cursor_x += @intCast(enumLen(Noun, n));
            }
        }
    }
}

fn currentPartialCommandCharacters() []u8 {
    const first_space_index = std.mem.indexOfScalar(u8, &state.command.characters, ' ') orelse 64;
    return state.command.characters[0..first_space_index];
}

fn attemptToInitMenu() void {
    const typed_characters = currentPartialCommandCharacters();
    // recompute state
    if (state.command.verb == null) {
        var menu_option_count: usize = 0;
        inline for (@typeInfo(Verb).@"enum".fields) |f| {
            if (std.mem.startsWith(u8, f.name, typed_characters)) {
                menu_option_count += 1;
            }
        }
        if (menu_option_count == 0) {
            state.resetMenu();
        } else {
            if (state.current_menu) |*menu| {
                menu.len = menu_option_count;
                if (menu.selection_index >= menu.len) {
                    menu.selection_index = menu.len - 1;
                }
            } else {
                state.current_menu = Menu {
                    .len = menu_option_count,
                };
            }
        }
    } else {
        if (state.command.noun == null) {
            var menu_option_count: usize = 0;
            inline for (@typeInfo(Noun).@"enum".fields) |f| {
                if (std.mem.startsWith(u8, f.name, typed_characters)) {
                    menu_option_count += 1;
                }
            }
            if (menu_option_count == 0) {
                state.resetMenu();
            } else {
                if (state.current_menu) |*menu| {
                    menu.len = menu_option_count;
                    if (menu.selection_index >= menu.len) {
                        menu.selection_index = menu.len - 1;
                    }
                } else {
                    state.current_menu = Menu {
                        .len = menu_option_count,
                    };
                }
            }
        }
    }
}

fn movePosToAndClearNextLine(pos: usize, buffer: []u8) usize {
    const new_pos = render.movePosToNextLine(pos, state.term.width);
    @memset(buffer[new_pos..(new_pos+state.term.width)], ' ');
    return new_pos;
}
