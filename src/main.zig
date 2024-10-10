const std = @import("std");
const zap = @import("zap");
const print = std.debug.print;
const UserEndpoints = @import("api/userendpoints.zig");
const customRouter = @import("api/router.zig");


pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();

    {
        var router = zap.Router.init(allocator, .{
            .not_found = customRouter.not_found,
        });
        defer router.deinit();

        var somePackage = customRouter.SomePackage.init(allocator, 1, 2);

        try router.handle_func_unbound("/", customRouter.on_request_verbose);
        try router.handle_func("/geta", &somePackage, &customRouter.SomePackage.getA);

        var listener = zap.HttpListener.init(.{
            .port = 3000,
            .on_request = router.on_request_handler(),
            .log = true,
            .max_clients = 100000,
        });

        //try listener.register(userendpoints.endpoint());
        try listener.listen();

        Print("Listening on 0.0.0.0:3000", "");
        Print("Web server Running!", "");

        zap.start(.{
            .threads = 2,
            .workers = 2
        });
    }

    const has_leaked = gpa.detectLeaks();
    std.log.debug("Has leaked: {}\n", .{has_leaked});
}


fn static_site(r: zap.Request) void {
    r.sendBody("<html><body><h1>Hello from STATIC ZAP!</h1></body></html>") catch return;
}

var dynamic_counter: i32 = 0;
fn dynamic_site(r: zap.Request) void {
    dynamic_counter += 1;
    var buf: [128]u8 = undefined;
    const filled_buf = std.fmt.bufPrintZ(
        &buf,
        "<html><body><h1>Hello # {d} from DYNAMIC ZAPPP!!!</h1></body></html>",
        .{dynamic_counter},
    ) catch "ERROR";
    r.sendBody(filled_buf) catch return;
}

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.HttpRequestFn).init(a);
    try routes.put("/static", static_site);
    try routes.put("/dynamic", dynamic_site);
}

var routes: std.StringHashMap(zap.HttpRequestFn) = undefined;


pub fn Print(comptime message: []const u8, value: anytype) void {
    if (@TypeOf(value) == ?i32) {
        print("{s} {?}\n", .{ message, value });
    } else if (@TypeOf(value) == []const u8) {
        print("{s} {s}\n", .{ message, value });
    } else {
        print("{s} {any}\n", .{ message, value });
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
