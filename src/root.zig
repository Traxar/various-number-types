pub const Float = @import("float.zig").Type;
pub const RelativeError = @import("relativeError.zig").Type;
pub const AbsoluteError = @import("absoluteError.zig").Type;

test {
    @import("std").testing.refAllDecls(@This());
}
