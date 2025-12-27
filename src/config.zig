//! 設定ファイルの読み込み

const std = @import("std");
const fs = std.fs;
const json = std.json;

pub const Config = struct {
    default: ?[]const u8 = null,
    browsers: json.ArrayHashMap(Browser) = .{},

    pub const Browser = struct {
        path: []const u8,
    };
};

pub const Result = struct {
    source: []const u8,
    parsed: ?json.Parsed(Config),

    pub fn deinit(self: Result, allocator: std.mem.Allocator) void {
        if (self.parsed) |p| p.deinit();
        allocator.free(self.source);
    }
};

pub fn load(allocator: std.mem.Allocator) !?Result {
    const exe_dir = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const path = try fs.path.join(allocator, &.{ exe_dir, "config.json" });
    defer allocator.free(path);

    const file = try fs.openFileAbsolute(path, .{});
    defer file.close();

    const stat = try file.stat();
    const source = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(source);

    const bytes_read = try file.preadAll(source, 0);
    if (bytes_read != stat.size) return error.UnexpectedEof;

    const parsed = try json.parseFromSlice(Config, allocator, source, .{
        .allocate = .alloc_always,
    });

    return .{ .source = source, .parsed = parsed };
}
