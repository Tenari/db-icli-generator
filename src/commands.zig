const std = @import("std");
const types = @import("types.zig");
const render = @import("render.zig");
const zqlite = @import("zqlite");

pub fn read(comptime T: type, allocator: std.mem.Allocator, db: zqlite.Conn, output: []u8, noun: types.Noun, term: render.TermSizeAndLoc) !void {
    std.debug.assert(output.len > 0);
    var mini_buf = [_]u8 { ' ' } ** 512;
    const read_statement = try std.fmt.bufPrint(&mini_buf, "select * from {s}s order by updated_at desc LIMIT 100;", .{ @tagName(noun) });

    var rows = db.rows(read_statement, .{}) catch |e| {
        std.log.err("{s}", .{ read_statement });
        std.log.err("{s}", .{ db.lastError() });
        std.log.err("Failed to execute statement: {s}\n{?any}", .{@errorName(e), @errorReturnTrace()});
        return e;
    };
    defer rows.deinit();
    var row_mem = try allocator.alloc(T, 100);
    var i: usize = 0;
    while (rows.next()) |row| {
        // TODO move the rows into []T
        var inner: usize = 0;
        inline for (@typeInfo(T).@"struct".fields) |f| {
            switch (@typeInfo(f.@"type")) {
                .@"enum" => {
                    @field(row_mem[i], f.name) = @enumFromInt(0);//row.get(f.@"type", inner);
                },
                else => {
                    @field(row_mem[i], f.name) = row.get(f.@"type", inner);
                },
            }
            inner += 1;
        }
        i += 1;
    }
    row_mem.len = i;

    try render.drawTable(T, output, term, row_mem);
}
