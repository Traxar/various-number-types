const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

fn Options(Number: type) type {
    return struct {
        error_bound: ?Number = null, //if given assert this bound for each calculation
        reduce_error_error: bool = false, //pick slightly worse error bounds if they reduce the error of the error
    };
}

/// adds an 1st order relative error estimate error to the number type
/// assumes the result is always rounded to its closest representative
pub fn Type(Number: type, options: Options(Number)) type {
    return struct {
        const NumberAndError = @This();

        value: Number,
        double_error: Number,

        pub const zero = NumberAndError{ .value = Number.zero, .double_error = Number.zero };
        pub const one = NumberAndError{ .value = Number.one, .double_error = Number.zero };
        pub const epsilon_relative = NumberAndError{ .value = Number.epsilon_relative, .double_error = Number.zero };
        pub const epsilon_absolute = NumberAndError{ .value = Number.epsilon_absolute, .double_error = Number.zero };

        /// initialized relative error to rounding error
        pub fn from(value: anytype) NumberAndError {
            return fromCalc(Number.from(value), Number.zero);
        }

        fn fromCalc(value: Number, calc_error: Number) NumberAndError {
            const err = calc_error.add(Number.epsilon_relative.max(Number.epsilon_absolute.div(value.abs().max(.one))));
            if (options.error_bound) |error_bound|
                assert(err.lt(error_bound)); //numerical error to big
            return .{ .value = value, .double_error = err };
        }

        pub fn abs(a: NumberAndError) NumberAndError {
            return .{ .value = a.value.abs(), .double_error = a.double_error };
        }

        pub fn neg(a: NumberAndError) NumberAndError {
            return .{ .value = a.value.neg(), .double_error = a.double_error };
        }

        pub fn inv(a: NumberAndError) NumberAndError {
            return fromCalc(a.value.inv(), a.double_error);
        }

        pub fn add(a: NumberAndError, b: NumberAndError) NumberAndError {
            const c = a.value.add(b.value);
            const err =
                if (a.double_error.eq(Number.zero) and b.double_error.eq(Number.zero))
                    Number.zero
                else if (options.reduce_error_error and (Number.zero.lt(a.value.mul(b.value))))
                    a.double_error.max(b.double_error)
                else
                    a.double_error.mul(a.value.abs()).add(b.double_error.mul(b.value.abs())).div(c.abs());
            return fromCalc(c, err);
        }

        pub fn sub(a: NumberAndError, b: NumberAndError) NumberAndError {
            return a.add(b.neg());
        }

        pub fn mul(a: NumberAndError, b: NumberAndError) NumberAndError {
            const c = a.value.mul(b.value);
            const err = a.double_error.add(b.double_error);
            return fromCalc(c, err);
        }

        pub fn div(a: NumberAndError, b: NumberAndError) NumberAndError {
            const c = a.value.div(b.value);
            const err = a.double_error.add(b.double_error);
            return fromCalc(c, err);
        }

        pub fn min(a: NumberAndError, b: NumberAndError) NumberAndError {
            return if (a.lt(b)) a else b;
        }

        pub fn max(a: NumberAndError, b: NumberAndError) NumberAndError {
            return if (a.lt(b)) b else a;
        }

        pub fn eq(a: NumberAndError, b: NumberAndError) bool {
            return a.value.sub(b.value).eq(.zero);
        }

        pub fn lt(a: NumberAndError, b: NumberAndError) bool {
            return a.value.sub(b.value).lt(.zero);
        }
    };
}

test "relative error estimate" {
    const log = Log(false);
    log("relative error estimate\n", .{});
    const F = @import("float.zig").Type(f32);
    const D = Type(F, .{ .error_bound = .from(1) });
    const n = 1e6;
    const a = 1.3;

    var sum = D.zero;
    for (0..n) |_| {
        sum = sum.add(D.from(a));
    }
    log("  sum = {}\n", .{sum.value.value});
    log("  error ~= {}\n", .{sum.double_error.value / 2});

    const err = F.from(a).mul(F.from(n)).sub(sum.value).div(sum.value).abs();
    log("  actual error = {}\n", .{err.value});
}

test "relative error error estimate" {
    const log = Log(true);
    log("relative error error estimate:\n", .{});
    const F = Type(@import("float.zig").Type(f32), .{});
    const D = Type(F, .{ .reduce_error_error = true });
    const n = 1e6;
    const a = 1.3;

    var sum = D.zero;
    for (0..n) |_| {
        sum = sum.add(D.from(a));
    }
    log("  sum = {}\n", .{sum.value.value.value});
    log("  error ~= {}\n", .{sum.double_error.value.value / 2});
    log("  error error ~= {}\n", .{sum.double_error.double_error.value / 2});

    const sum_ = F.from(sum.value.value.value);
    const err = F.from(a).mul(F.from(n)).sub(sum_).div(sum_).abs();
    log("  actual error ~= {}\n", .{err.value.value});
    log("  (actual error) error ~= {}\n", .{err.double_error.value / 2});
}

fn Log(comptime do: bool) fn (comptime fmt: []const u8, args: anytype) void {
    return if (do) std.debug.print else struct {
        fn dont(comptime fmt: []const u8, args: anytype) void {
            _ = fmt;
            _ = args;
        }
    }.dont;
}
