const std = @import("std");
const render = @import("render.zig");

var mainoptions = [_]render.MenuOption {
    render.MenuOption { .name = "View Animals", .changepage = @intFromEnum(NamedPage.animals)},
    render.MenuOption { .name = "View Events", .changepage = @intFromEnum(NamedPage.events)},
    render.MenuOption { .name = "<Quit>", .quit = true },
};
var mainpage = [_]render.Node {
    render.Node {.as = .text, .text = "Welcome:"},
    render.Node { .as = .menu, .menu = render.Menu { .options = &mainoptions } },
};

var animalsoptions = [_]render.MenuOption {
    render.MenuOption { .name = "Miss Rabbit"},
    render.MenuOption { .name = "Mr Rabbit"},
    render.MenuOption { .name = "<- Back", .changepage = @intFromEnum(NamedPage.main) },
    render.MenuOption { .name = "<Quit>", .quit = true },
};
var animalspage = [_]render.Node {
    render.Node {.as = .text, .text = "Animals listing:"},
    render.Node { .as = .menu, .menu = render.Menu { .options = &animalsoptions } },
};

var eventsoptions = [_]render.MenuOption {
    render.MenuOption { .name = "Litter #1 Born"},
    render.MenuOption { .name = "Mating attempted"},
    render.MenuOption { .name = "<- Back", .changepage = @intFromEnum(NamedPage.main) },
    render.MenuOption { .name = "<Quit>", .quit = true },
};
var eventspage = [_]render.Node {
    render.Node {.as = .text, .text = "Events listing:"},
    render.Node { .as = .menu, .menu = render.Menu { .options = &eventsoptions } },
};


const NamedPage = enum(u64) {
    main,
    animals,
    events,
    animal,
    event,
    newanimal,
    newevent,
};

var current_page: render.Page = undefined;

var running = true;

pub fn main() !void {
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    current_page = mainpage[runtime_zero..];
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut();

    try render.init(out);
    defer render.deinit(out);

    var input: [32]u8 = undefined;
    while (running) {
        try render.render(out, current_page);
        // get user input
        input = [_]u8{ 0 } ** 32;
        _ = try in.read(&input);
        const byte = input[0];
        // Q
        if (byte == 81) {
            running = false;
        }
        // ENTER/return
        if (byte == 10) {
            handleSelection(null);
        }
        // digit selection
        if (byte > 48 and byte < 58) {
            handleSelection(@intCast(byte - 49));
        }
        // up
        if (byte == 'k' or std.mem.eql(u8, input[0..3], "\x1B[A")) {
            render.moveSelectedIndex(&current_page, .up);
        }
        // down
        if (byte == 'j' or std.mem.eql(u8, input[0..3], "\x1B[B")) {
            render.moveSelectedIndex(&current_page, .down);
        }
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

fn handleSelection(index: ?usize) void {
    if (render.currentMenu(current_page)) |menu| {
        const option = menu.options[index orelse menu.selectedindex];
        if (option.quit) {
            running = false;
        } else if (option.changepage) |pg| {
            const named: NamedPage = @enumFromInt(pg);
            current_page = switch (named) {
                .main => &mainpage,
                .animals => &animalspage,
                .events => &eventspage,
                else => &mainpage,
            };
        }
    }
}

const Animal = struct {
    id: u32,
    breed: ?Breed, // null = unknown
    father_id: ?u32,
    mother_id: ?u32,
    weight: u16, // in grams
    death: ?i64, // null = still alive
    birth: i64, // unix epoch

    // result in seconds
    fn age(self: Animal) i64 {
        return std.time.timestamp() - self.birth;
    }
};

const Breed = enum {
    new_zealand,
    californian,
    nz_x_cali,
    tamuk,
};

const Event = struct {
    id: u64,
    animal_id: u32,
};

const EventType = enum {
    birth,
    natural_death,
    slaughter,
    cull,
    purchase,
    sale,
    breed_attempt,
    pregnancy_test,
    kindling,
};
