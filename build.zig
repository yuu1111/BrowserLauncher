//! BrowserLauncher ビルド設定
//!
//! 使用方法:
//! - `zig build` - ビルドして zig-out/bin に出力
//! - `zig build run` - ビルドして実行
//! - `zig build run -- https://example.com` - 引数付きで実行
//! - `zig build test` - テストを実行

const std = @import("std");

/// ビルドグラフを構築する
///
/// Zigビルドシステムはこの関数を呼び出してビルドステップを定義する。
/// 実際のビルドは外部ランナーが実行する。
pub fn build(b: *std.Build) void {
    // ターゲットと最適化オプション
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 実行ファイルを定義
    const exe = b.addExecutable(.{
        .name = "BrowserLauncher",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // zig-out/bin にインストール
    b.installArtifact(exe);

    // `zig build run` で実行
    const run_step = b.step("run", "アプリを実行");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // コマンドライン引数を渡す: `zig build run -- arg1 arg2`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // `zig build test` でテスト実行
    const test_step = b.step("test", "テストを実行");
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
