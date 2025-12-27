//! OSデフォルトブラウザでURLを開く

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // プログラム名をスキップ
    const url = args.next();

    if (url == null) {
        return;
    }

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, "cmd");
    try argv.append(allocator, "/c");
    try argv.append(allocator, "start");
    try argv.append(allocator, "");
    try argv.append(allocator, url.?);

    var child = std.process.Child.init(argv.items, allocator);
    _ = try child.spawn();
}
