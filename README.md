# BrowserLauncher

設定ファイルまたはコマンドライン引数で指定されたブラウザを起動するラッパー。

## 使い方

```
browser-launcher [options] [url]

Options:
  -b, --browser <name|path>  ブラウザ名またはexeのフルパス
  -h, --help                 ヘルプを表示
```

### 例

```bash
# URLを開く
browser-launcher https://example.com

# 指定ブラウザで開く
browser-launcher -b firefox https://example.com

# exeパスを直接指定
browser-launcher -b "C:\Program Files\Mozilla Firefox\firefox.exe" https://example.com
```

## ブラウザ選択の優先順位

1. `-b/--browser` で指定
2. config.json の default
3. OSのデフォルトブラウザ

## 設定ファイル

exe横に `config.json` を配置:

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

## ビルド

Zig 0.16.0-dev 以上が必要。

```bash
zig build
```

成果物は `zig-out/bin/BrowserLauncher.exe` に出力される。
