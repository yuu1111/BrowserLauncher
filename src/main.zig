//! ブラウザランチャー

const std = @import("std");
const config = @import("config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // コマンドライン引数をパース
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // プログラム名をスキップ

    var browser_arg: ?[]const u8 = null;
    var url_arg: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--browser")) {
            browser_arg = args.next() orelse {
                std.debug.print("エラー: -b/--browser には引数が必要です\n", .{});
                return;
            };
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            url_arg = arg;
        }
    }

    const url: ?[]const u8 = url_arg;

    // 設定ファイルを読み込む
    var cfg: ?config.Result = null;
    if (config.load(allocator)) |c| {
        cfg = c;
    } else |err| {
        if (err != error.FileNotFound) {
            std.debug.print("警告: 設定ファイルの読み込みに失敗しました\n", .{});
        }
    }
    defer if (cfg) |c| c.deinit(allocator);

    // ブラウザパスを決定
    const browser_path = determineBrowserPath(browser_arg, cfg);

    // ブラウザを起動
    if (browser_path) |path| {
        launchBrowser(allocator, path, url) catch |err| {
            std.debug.print("エラー: ブラウザの起動に失敗しました: {}\n", .{err});
        };
    } else {
        // OSデフォルトブラウザで開く
        launchWithSystemDefault(allocator, url) catch |err| {
            std.debug.print("エラー: デフォルトブラウザの起動に失敗しました: {}\n", .{err});
        };
    }
}

fn printHelp() void {
    const help =
        \\browser-launcher [options] [url]
        \\
        \\Options:
        \\  -b, --browser <name|path>  ブラウザ名またはexeのフルパス
        \\  -h, --help                 ヘルプを表示
        \\
        \\ブラウザ選択の優先順位:
        \\  1. -b/--browser で指定
        \\  2. config.json の default
        \\  3. OSのデフォルトブラウザ
        \\
    ;
    std.debug.print("{s}", .{help});
}

/// ブラウザパスを決定
fn determineBrowserPath(browser_arg: ?[]const u8, cfg: ?config.Result) ?[]const u8 {
    if (browser_arg) |arg| {
        // パス区切りまたは.exeが含まれていればパスとして扱う
        if (std.mem.indexOf(u8, arg, "\\") != null or
            std.mem.indexOf(u8, arg, "/") != null or
            std.mem.endsWith(u8, arg, ".exe"))
        {
            return arg;
        }
        // config.jsonから名前で解決
        if (cfg) |c| {
            if (c.parsed) |p| {
                if (p.value.browsers.map.get(arg)) |browser| {
                    return browser.path;
                }
            }
        }
        std.debug.print("警告: ブラウザ '{s}' が見つかりません\n", .{arg});
        return null;
    }

    // config.jsonのdefaultを使用
    if (cfg) |c| {
        if (c.parsed) |p| {
            if (p.value.default) |default_name| {
                if (p.value.browsers.map.get(default_name)) |browser| {
                    return browser.path;
                }
            }
        }
    }

    return null;
}

/// 指定されたブラウザでURLを開く
fn launchBrowser(allocator: std.mem.Allocator, browser_path: []const u8, url: ?[]const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);

    try argv.append(allocator, browser_path);
    if (url) |u| {
        try argv.append(allocator, u);
    }

    var child = std.process.Child.init(argv.items, allocator);
    _ = try child.spawn();
}

/// OSのデフォルトブラウザでURLを開く
fn launchWithSystemDefault(allocator: std.mem.Allocator, url: ?[]const u8) !void {
    if (@import("builtin").os.tag == .windows) {
        var argv: std.ArrayList([]const u8) = .empty;
        defer argv.deinit(allocator);

        try argv.append(allocator, "cmd");
        try argv.append(allocator, "/c");
        try argv.append(allocator, "start");
        try argv.append(allocator, "");
        if (url) |u| {
            try argv.append(allocator, u);
        }

        var child = std.process.Child.init(argv.items, allocator);
        _ = try child.spawn();
    } else {
        std.debug.print("エラー: このOSではデフォルトブラウザの起動はサポートされていません\n", .{});
    }
}
