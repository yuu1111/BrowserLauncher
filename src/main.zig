const std = @import("std");
const fs = std.fs;
const json = std.json;
const process = std.process;

const Config = struct {
    default: ?[]const u8 = null,
    browsers: json.ArrayHashMap(Browser) = .{},

    const Browser = struct {
        path: []const u8,
    };
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // コマンドライン引数をパース
    var args = try process.argsWithAllocator(allocator);
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
    var config: ?ConfigResult = null;
    if (loadConfig(allocator)) |c| {
        config = c;
    } else |err| {
        if (err != error.FileNotFound) {
            std.debug.print("警告: 設定ファイルの読み込みに失敗しました\n", .{});
        }
    }
    defer if (config) |c| {
        if (c.parsed) |p| p.deinit();
        allocator.free(c.source);
    };

    // ブラウザパスを決定
    const browser_path = determineBrowserPath(browser_arg, config);

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

const ConfigResult = struct {
    source: []const u8,
    parsed: ?json.Parsed(Config),
};

fn loadConfig(allocator: std.mem.Allocator) !?ConfigResult {
    // exe横のconfig.jsonを探す
    const exe_dir = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const config_path = try fs.path.join(allocator, &.{ exe_dir, "config.json" });
    defer allocator.free(config_path);

    const file = try fs.openFileAbsolute(config_path, .{});
    defer file.close();

    // ファイルサイズを取得して読み込む
    const stat = try file.stat();
    const source = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(source);

    const bytes_read = try file.preadAll(source, 0);
    if (bytes_read != stat.size) {
        return error.UnexpectedEof;
    }

    const parsed = try json.parseFromSlice(Config, allocator, source, .{
        .allocate = .alloc_always,
    });

    return .{
        .source = source,
        .parsed = parsed,
    };
}

fn determineBrowserPath(browser_arg: ?[]const u8, config: ?ConfigResult) ?[]const u8 {
    if (browser_arg) |arg| {
        // パス区切りまたは.exeが含まれていればパスとして扱う
        if (std.mem.indexOf(u8, arg, "\\") != null or
            std.mem.indexOf(u8, arg, "/") != null or
            std.mem.endsWith(u8, arg, ".exe"))
        {
            return arg;
        }
        // config.jsonから名前で解決
        if (config) |c| {
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
    if (config) |c| {
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
