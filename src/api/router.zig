const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const Self = @This();
var _instance: *Self = undefined;

const BoundHandler = *fn (*const anyopaque, zap.Request) void;

pub fn on_request_verbose(r: zap.Request) void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }

    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }
    r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>") catch return;
}

pub fn on_request_handler(self: *Self) zap.HttpRequestFn {
    _instance = self;
    return zap_on_request;
}

pub const SomePackage = struct {
    const SelfPackage = @This();

    allocator: Allocator,
    a: i8,
    b: i8,

    pub fn init(allocator: Allocator, a: i8, b: i8) SelfPackage {
        return .{
            .allocator = allocator,
            .a = a,
            .b = b,
        };
    }

    pub fn getA(self: *SelfPackage, req: zap.Request) void {
        std.log.warn("get_a_requested", .{});

        const string = std.fmt.allocPrint(
            self.allocator,
            "A value is {d}\n",
            .{self.a},
        ) catch return;
        defer self.allocator.free(string);

        req.sendBody(string) catch return;
    }

    pub fn getB(self: *SelfPackage, req: zap.Request) void {
        std.log.warn("get_b_requested", .{});

        const string = std.fmt.allocPrint(
            self.allocator,
            "B value is {d}\n",
            .{self.b},
        ) catch return;
        defer self.allocator.free(string);

        req.sendBody(string) catch return;
    }

    pub fn incrementA(self: *SelfPackage, req: zap.Request) void {
        std.log.warn("increment_a_requested", .{});

        self.a += 1;

        req.sendBody("incremented A") catch return;
    }
};

pub fn not_found(req: zap.Request) void {
    std.debug.print("not found handler", .{});

    req.sendBody("Not found") catch return;
}

fn zap_on_request(r: zap.Request) void {
    return serve(_instance, r);
}

fn serve(self: *Self, r: zap.Request) void {
    const path = r.path orelse "/";

    if (self.routes.get(path)) |routeInfo| {
        switch (routeInfo) {
            .bound => |b| @call(.auto, @as(BoundHandler, @ptrFromInt(b.handler)), .{ @as(*anyopaque, @ptrFromInt(b.instance)), r }),
            .unbound => |h| h(r),
        }
    } else if (self.not_found) |handler| {
        // not found handler
        handler(r);
    } else {
        // default 404 output
        r.setStatus(.not_found);
        r.sendBody("404 Not Found") catch return;
    }
}