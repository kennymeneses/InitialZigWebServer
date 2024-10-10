const std = @import("std");
const zap = @import("zap");
const Users = @import("user.zig");
const User = Users.User;

pub const Self = @This();
alloc: std.mem.Allocator = undefined,
ep: zap.Endpoint = undefined,
_users: Users = undefined,

pub fn init(
    a: std.mem.Allocator,
    user_path: []const u8,
) Self {
    return .{
        .alloc = a,
        ._users = Users.init(a),
        .ep = zap.Endpoint.init(.{
            .path = user_path,
            .get = getUser
        })
    };
}

pub fn deinit(self: *Self) void {
    self._users.deinit();
}

pub fn users(self: *Self) *Users {
    return &self._users;
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn userIdFromPath(self: *Self, path: []const u8) ?usize {
    if (path.len >= self.ep.settings.path.len + 2) {
        if (path[self.ep.settings.path.len] != '/') {
            return null;
        }
        const idstr = path[self.ep.settings.path.len + 1 ..];
        return std.fmt.parseUnsigned(usize, idstr, 10) catch null;
    }
    return null;
}

fn getUser(e: *zap.Endpoint, r: zap.Request) void
{
    const self: *Self = @fieldParentPtr("ep", e);

    if (r.path) |path| {
        // /users
        if (path.len == e.settings.path.len) {
            return self.listUsers(r);
        }
        var jsonbuf: [256]u8 = undefined;
        if (self.userIdFromPath(path)) |id| {
            if (self._users.get(id)) |user| {
                if (zap.stringifyBuf(&jsonbuf, user, .{})) |json| {
                    r.sendJson(json) catch return;
                }
            }
        } else {
            r.setStatusNumeric(404);
            r.sendBody("") catch return;
        }
    }
}

fn listUsers(self: *Self, r: zap.Request) void {
    if (self._users.toJSON()) |json| {
        defer self.alloc.free(json);
        r.sendJson(json) catch return;
    } else |err| {
        std.debug.print("LIST error: {}\n", .{err});
    }
}


fn optionsUser(e: *zap.Endpoint, r: zap.Request) void {
    _ = e;
    r.setHeader("Access-Control-Allow-Origin", "*") catch return;
    r.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS") catch return;
    r.setStatus(zap.StatusCode.no_content);
    r.markAsFinished(true);
}