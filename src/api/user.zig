const std = @import("std");

alloc: std.mem.Allocator = undefined,
users: std.AutoHashMap(usize, InternalUser) = undefined,
lock: std.Thread.Mutex = undefined,
count: usize = 0,

pub const Self = @This();

const InternalUser = struct {
    id: usize = 0,
    firstnamebuf: [64]u8,
    firstnamelen: usize,
    lastnamebuf: [64]u8,
    lastnamelen: usize,
};

pub const User = struct {
    id: usize = 0,
    first_name: []const u8,
    last_name: []const u8,
};

pub fn init(a: std.mem.Allocator) Self {
    return .{
        .alloc = a,
        .users = std.AutoHashMap(usize, InternalUser).init(a),
        .lock = std.Thread.Mutex{},
    };
}

pub fn deinit(self: *Self) void {
    self.users.deinit();
}

pub fn get(self: *Self, id: usize) ?User {
    // we don't care about locking here, as our usage-pattern is unlikely to
    // get a user by id that is not known yet
    if (self.users.getPtr(id)) |pUser| {
        return .{
            .id = pUser.id,
            .first_name = pUser.firstnamebuf[0..pUser.firstnamelen],
            .last_name = pUser.lastnamebuf[0..pUser.lastnamelen],
        };
    }
    std.debug.print("Else part, didnt get user pointer.\n", .{});
    return null;
}

pub fn toJSON(self: *Self) ![]const u8 {
    self.lock.lock();
    defer self.lock.unlock();

    // We create a User list that's JSON-friendly
    // NOTE: we could also implement the whole JSON writing ourselves here,
    // working directly with InternalUser elements of the users hashmap.
    // might actually save some memory
    // TODO: maybe do it directly with the user.items
    var l: std.ArrayList(User) = std.ArrayList(User).init(self.alloc);
    defer l.deinit();

    // the potential race condition is fixed by jsonifying with the mutex locked
    var it = JsonUserIteratorWithRaceCondition.init(&self.users);
    while (it.next()) |user| {
        try l.append(user);
    }
    std.debug.assert(self.users.count() == l.items.len);
    std.debug.assert(self.count == l.items.len);
    return std.json.stringifyAlloc(self.alloc, l.items, .{});
}

const JsonUserIteratorWithRaceCondition = struct {
    it: std.AutoHashMap(usize, InternalUser).ValueIterator = undefined,
    const This = @This();

    // careful:
    // - Self refers to the file's struct
    // - This refers to the JsonUserIterator struct
    pub fn init(internal_users: *std.AutoHashMap(usize, InternalUser)) This {
        return .{
            .it = internal_users.valueIterator(),
        };
    }

    pub fn next(this: *This) ?User {
        if (this.it.next()) |pUser| {
            // we get a pointer to the internal user. so it should be safe to
            // create slices from its first and last name buffers
            //
            // SEE ABOVE NOTE regarding race condition why this is can be problematic
            var user: User = .{
                // we don't need .* syntax but want to make it obvious
                .id = pUser.*.id,
                .first_name = pUser.*.firstnamebuf[0..pUser.*.firstnamelen],
                .last_name = pUser.*.lastnamebuf[0..pUser.*.lastnamelen],
            };
            if (pUser.*.firstnamelen == 0) {
                user.first_name = "";
            }
            if (pUser.*.lastnamelen == 0) {
                user.last_name = "";
            }
            return user;
        }
        return null;
    }
};