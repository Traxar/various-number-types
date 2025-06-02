const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

/// returns a wrapper around a float
pub fn Type(F: type) type {
    if (@typeInfo(F) != .float) @compileError("`Float` must be a float type");
    return struct {
        const Float = @This();

        value: F,

        pub const zero = from(0);
        pub const one = from(1);
        pub const epsilon_relative = from(std.math.pow(F, 2, -mantissa_bits));
        pub const epsilon_absolute = zero; //from(std.math.floatMin(F));

        const mantissa_bits = switch (F) {
            f16 => 10,
            f32 => 23,
            f64 => 52,
            f80 => 64,
            f128 => 112,
            else => @compileError("unknown float type"),
        };

        /// initialized relative error to max rounding error
        pub fn from(value: F) Float {
            return .{ .value = value };
        }

        pub fn abs(a: Float) Float {
            return .{ .value = @abs(a.value) };
        }

        pub fn neg(a: Float) Float {
            return .{ .value = -a.value };
        }

        pub fn inv(a: Float) Float {
            return .{ .value = 1 / a.value };
        }

        pub fn add(a: Float, b: Float) Float {
            return .{ .value = a.value + b.value };
        }

        pub fn sub(a: Float, b: Float) Float {
            return .{ .value = a.value - b.value };
        }

        pub fn mul(a: Float, b: Float) Float {
            return .{ .value = a.value * b.value };
        }

        pub fn div(a: Float, b: Float) Float {
            return .{ .value = a.value / b.value };
        }

        pub fn min(a: Float, b: Float) Float {
            return if (a.lt(b)) a else b;
        }

        pub fn max(a: Float, b: Float) Float {
            return if (a.lt(b)) b else a;
        }

        pub fn eq(a: Float, b: Float) bool {
            return a.value == b.value;
        }

        pub fn lt(a: Float, b: Float) bool {
            return a.value < b.value;
        }
    };
}
