# BrowserLauncher - Zig製ブラウザ起動ラッパー

## 概要
ブラウザのexeを直接叩いて起動する場合のラッパー。
新しいブラウザへの移行を容易にするため、設定ファイルでブラウザを管理する。

## 要件
- 設定ファイル(JSON) + コマンドライン引数でオーバーライド可能
- URLは引数優先、なければ標準入力を確認
- シンプルな実装

## 設定ファイル (config.json)
exe横に配置。

```json
{
  "default": "chrome",
  "browsers": {
    "chrome": {
      "path": "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
    },
    "firefox": {
      "path": "C:\\Program Files\\Mozilla Firefox\\firefox.exe"
    },
    "edge": {
      "path": "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
    }
  }
}
```

## CLI仕様
```
browser-launcher [options] [url]

Options:
  -b, --browser <name|path>  ブラウザ名(config.jsonのキー)またはexeのフルパス
  -h, --help                 ヘルプを表示

ブラウザ選択の優先順位:
  1. -b/--browser で指定 (パスならそのまま使用、名前ならconfig.jsonから解決)
  2. config.json の default で指定されたブラウザ
  3. OSのデフォルトブラウザ (config.jsonがない場合や-bなしの場合)

Examples:
  browser-launcher https://example.com           # config.jsonのdefault or OSデフォルト
  browser-launcher -b firefox https://example.com # config.jsonのfirefoxで開く
  browser-launcher -b "C:\Program Files\Mozilla Firefox\firefox.exe" https://example.com  # フルパス指定
  browser-launcher                                # URLなし: OSデフォルトブラウザを起動
  echo "https://example.com" | browser-launcher  # 標準入力からURL
```

## ファイル構成
```
BrowserLauncher/
├── src/
│   └── main.zig       # メイン実装
├── build.zig          # ビルド設定
└── config.json        # サンプル設定
```

## 実装ステップ

### Step 1: プロジェクト初期化
- `zig init` でプロジェクト作成
- build.zig の設定

### Step 2: main.zig 実装
1. **設定ファイル読み込み**
   - exe横のconfig.jsonを読み込む
   - JSONパースしてブラウザ情報を取得

2. **コマンドライン引数パース**
   - -b/--browser オプション
   - -h/--help オプション
   - URLの取得

3. **URL取得ロジック**
   - 引数にURLがあればそれを使用
   - なければ標準入力をノンブロッキングで確認

4. **ブラウザ起動**
   - 選択されたブラウザのパスを取得
   - std.ChildProcessで起動

### Step 3: サンプル設定ファイル
- config.json のサンプルを作成

## 技術的な考慮事項
- Zig 0.16.0-dev (C:\zig\zig.exe) を使用
- std.json でJSONパース
- std.process.Child でプロセス起動
- OSデフォルトブラウザ: Windows では `cmd /c start "" "URL"` を使用
- エラーメッセージは日本語で出力
