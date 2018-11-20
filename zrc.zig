const std = @import("std");
const assert = std.debug.assert;

pub fn Rc(comptime T: type) type {
    return struct {
        const refSize = u16;
        refs: std.atomic.Int(refSize),
        ptr: ?*T,
        allocator: *std.mem.Allocator,

        pub const Self = @This();

        pub fn init(alloc: *std.mem.Allocator) !Self {
            var data = try alloc.createOne(T);
            return Self { 
                .refs = std.atomic.Int(refSize).init(1),
                .ptr = data, 
                .allocator = alloc,
            };
        }

        pub fn incRef(self: *Self) void {
            if (self.ptr != null) {
                _ = self.refs.incr();
            }
        }

        pub fn decRef(self: *Self) void {
            if (self.ptr != null) {
                const val = self.refs.decr();
                if (val == 1){
                    self.deinit();
                }
            }
        }

        pub fn deinit(self: *Self) void {
            _ = self.refs.xchg(0);
            self.allocator.destroy(self.ptr);
            self.ptr = null;
        }


        pub fn countRef(self: *Self) refSize {
            return self.refs.get();
        }

    };
}


test "Test Rc" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    var all = &da.allocator;
    //var all = std.heap.c_allocator;

    var rcint = try Rc(i32).init(all);   
    assert(rcint.ptr != null);

    // reference adjustments
    rcint.incRef();
    assert(rcint.countRef() == 2);
    rcint.decRef();

    // assignment
    rcint.ptr.?.* = 0;
    assert(rcint.ptr.?.* == 0);

    // auto free
    rcint.decRef();
    assert(rcint.ptr == null);
}
