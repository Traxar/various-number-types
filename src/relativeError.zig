const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

fn Options(Number: type) type {
    return struct {
        error_bound: ?Number = null, //if given assert this bound for each calculation
        reduce_error_error: bool = false, //pick slightly worse error bounds if they reduce the error of the error
    };
}

/// returns a float that keeps track of its own 1st order relative error estimate
/// assumes the result is always rounded to its closest representative
pub fn Type(Number: type, options: Options(Number)) type {
    return struct {
        const NumberAndError = @This();

        value: Number,
        relative_error: Number,

        pub const zero = NumberAndError{ .value = Number.zero, .relative_error = Number.zero };
        pub const one = NumberAndError{ .value = Number.one, .relative_error = Number.zero };
        pub const eps = NumberAndError{ .value = Number.eps, .relative_error = Number.zero }; //max rounding error

        /// initialized relative error to rounding error
        pub fn from(value: anytype) NumberAndError {
            return fromCalc(Number.from(value), Number.zero);
        }

        /// for now the denormalized case is ignored
        fn fromCalc(value: Number, calc_error: Number) NumberAndError {
            const err = calc_error.add(Number.eps);
            if (options.error_bound) |error_bound|
                assert(err.lt(error_bound)); //numerical error to big
            return .{ .value = value, .relative_error = err };
        }

        pub fn abs(a: NumberAndError) NumberAndError {
            return .{ .value = a.value.abs(), .relative_error = a.relative_error };
        }

        pub fn neg(a: NumberAndError) NumberAndError {
            return .{ .value = a.value.neg(), .relative_error = a.relative_error };
        }

        pub fn inv(a: NumberAndError) NumberAndError {
            return fromCalc(a.value.inv(), a.relative_error);
        }

        pub fn add(a: NumberAndError, b: NumberAndError) NumberAndError {
            const c = a.value.add(b.value);
            const err =
                if (a.relative_error.eq(Number.zero) and b.relative_error.eq(Number.zero))
                    Number.zero
                else if (options.reduce_error_error and (Number.zero.lt(a.value.mul(b.value))))
                    a.relative_error.max(b.relative_error)
                else
                    a.relative_error.mul(a.value.abs()).add(b.relative_error.mul(b.value.abs())).div(c.abs());
            return fromCalc(c, err);
        }

        pub fn sub(a: NumberAndError, b: NumberAndError) NumberAndError {
            return a.add(b.neg());
        }

        pub fn mul(a: NumberAndError, b: NumberAndError) NumberAndError {
            const c = a.value.mul(b.value);
            const err = a.relative_error.add(b.relative_error);
            return fromCalc(c, err);
        }

        pub fn div(a: NumberAndError, b: NumberAndError) NumberAndError {
            const c = a.value.div(b.value);
            const err = a.relative_error.add(b.relative_error);
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

test "error estimate" {
    const log = Log(false);
    log("automatic error estimate:\n", .{});
    const F = @import("float.zig").Type(f32);
    const D = Type(F, .{ .error_bound = .from(1) });
    const n = 1e6;
    const a = 1.3;

    var sum = D.zero;
    for (0..n) |_| {
        sum = sum.add(D.from(a));
    }
    log("  sum = {}\n", .{sum.value});
    log("  error ~= {}\n", .{sum.relative_error});

    const err = F.from(a).mul(F.from(n)).sub(sum.value).div(sum.value).abs();
    log("  actual error = {}\n", .{err});
}

test "error error estimate" {
    const log = Log(false);
    log("automatic (automatic error estimate) error estimate:\n", .{});
    const F = Type(@import("float.zig").Type(f32), .{});
    const D = Type(F, .{ .reduce_error_error = false, .error_bound = .one });
    const n = 1e6;
    const a = 1.3;

    var sum = D.zero;
    for (0..n) |_| {
        sum = sum.add(D.from(a));
    }
    log("  sum = {}\n", .{sum.value.value});
    log("  error ~= {}\n", .{sum.relative_error.value});
    log("  error error ~= {}\n", .{sum.relative_error.relative_error});

    const sum_ = F.from(sum.value.value.value);
    const err = F.from(a).mul(F.from(n)).sub(sum_).div(sum_).abs();
    log("  actual error ~= {}\n", .{err.value});
    log("  (actual error) error ~= {}\n", .{err.relative_error});
}

fn Log(comptime do: bool) fn (comptime fmt: []const u8, args: anytype) void {
    return if (do) std.debug.print else struct {
        fn dont(comptime fmt: []const u8, args: anytype) void {
            _ = fmt;
            _ = args;
        }
    }.dont;
}
