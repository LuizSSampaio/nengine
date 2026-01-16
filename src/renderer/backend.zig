const std = @import("std");
const Backend = @import("root.zig").Backend;

pub fn VTable(comptime Impl: type) type {
    return struct {
        pub const backend = Backend{
            .init = wrapFallible(Impl, "init"),
            .deinit = wrapVoid(Impl, "deinit"),
            .beginFrame = wrapFallible(Impl, "beginFrame"),
            .endFrame = wrapFallible(Impl, "endFrame"),

            .clearColor = wrapFallible(Impl, "clearColor"),
            .clearDepth = wrapFallible(Impl, "clearDepth"),
            .clearStencil = wrapFallible(Impl, "clearStencil"),
        };
    };
}

fn wrapFallible(comptime Impl: type, comptime name: []const u8) WrapperFnPtr(Impl, name, true) {
    const impl_fn = @field(Impl, name);
    const ImplFn = @TypeOf(impl_fn);
    const impl_fn_info = @typeInfo(ImplFn).@"fn";
    const num_extra = impl_fn_info.params.len - 1;

    return switch (num_extra) {
        0 => struct {
            fn call(ctx: *anyopaque) anyerror!void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                try @call(.auto, impl_fn, .{self});
            }
        }.call,
        1 => struct {
            fn call(ctx: *anyopaque, a0: ExtraParamType(impl_fn_info, 0)) anyerror!void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                try @call(.auto, impl_fn, .{ self, a0 });
            }
        }.call,
        2 => struct {
            fn call(ctx: *anyopaque, a0: ExtraParamType(impl_fn_info, 0), a1: ExtraParamType(impl_fn_info, 1)) anyerror!void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                try @call(.auto, impl_fn, .{ self, a0, a1 });
            }
        }.call,
        3 => struct {
            fn call(ctx: *anyopaque, a0: ExtraParamType(impl_fn_info, 0), a1: ExtraParamType(impl_fn_info, 1), a2: ExtraParamType(impl_fn_info, 2)) anyerror!void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                try @call(.auto, impl_fn, .{ self, a0, a1, a2 });
            }
        }.call,
        else => @compileError("Too many parameters for wrapFallible (max 3 extra params supported)"),
    };
}

fn wrapVoid(comptime Impl: type, comptime name: []const u8) WrapperFnPtr(Impl, name, false) {
    const impl_fn = @field(Impl, name);
    const ImplFn = @TypeOf(impl_fn);
    const impl_fn_info = @typeInfo(ImplFn).@"fn";
    const num_extra = impl_fn_info.params.len - 1;

    return switch (num_extra) {
        0 => struct {
            fn call(ctx: *anyopaque) void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                @call(.auto, impl_fn, .{self});
            }
        }.call,
        1 => struct {
            fn call(ctx: *anyopaque, a0: ExtraParamType(impl_fn_info, 0)) void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                @call(.auto, impl_fn, .{ self, a0 });
            }
        }.call,
        2 => struct {
            fn call(ctx: *anyopaque, a0: ExtraParamType(impl_fn_info, 0), a1: ExtraParamType(impl_fn_info, 1)) void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                @call(.auto, impl_fn, .{ self, a0, a1 });
            }
        }.call,
        3 => struct {
            fn call(ctx: *anyopaque, a0: ExtraParamType(impl_fn_info, 0), a1: ExtraParamType(impl_fn_info, 1), a2: ExtraParamType(impl_fn_info, 2)) void {
                const self: *Impl = @ptrCast(@alignCast(ctx));
                @call(.auto, impl_fn, .{ self, a0, a1, a2 });
            }
        }.call,
        else => @compileError("Too many parameters for wrapVoid (max 3 extra params supported)"),
    };
}

fn ExtraParamType(comptime fn_info: std.builtin.Type.Fn, comptime idx: usize) type {
    return fn_info.params[idx + 1].type.?;
}

fn WrapperFnPtr(comptime Impl: type, comptime name: []const u8, comptime is_fallible: bool) type {
    const impl_fn = @field(Impl, name);
    const ImplFn = @TypeOf(impl_fn);
    const impl_fn_info = @typeInfo(ImplFn).@"fn";
    const impl_params = impl_fn_info.params;

    const ParamAttrs = std.builtin.Type.Fn.Param.Attributes;
    const FnAttrs = std.builtin.Type.Fn.Attributes;

    var param_types: [impl_params.len]type = undefined;
    param_types[0] = *anyopaque;
    for (impl_params[1..], 1..) |p, i| {
        param_types[i] = p.type.?;
    }

    var param_attrs: [impl_params.len]ParamAttrs = undefined;
    for (0..impl_params.len) |i| {
        param_attrs[i] = .{};
    }

    const ReturnType = if (is_fallible) anyerror!void else void;

    return *const @Fn(&param_types, &param_attrs, ReturnType, FnAttrs{});
}
