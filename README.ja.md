# minhtmltk — Tcl/Tk 用のミニマルな HTML ビューアウィジェット

minhtmltk は [Tkhtml 3](http://tkhtml.tcl.tk/) の上に作られた最小限の
webview ライブラリで、モダンな Tcl(snit メガウィジェット)から
Tkhtml3 を使う方法を示すサンプルコードとして書かれています。静的な
HTML/CSS の描画、リンク・フォーム・画像・テキスト選択の処理、簡単な
location/history 管理を備えています。ナビゲーションは、ローカルファイル
は最初から、http/https はオプトインで対応します。

意図的に小さく作られています: JavaScript なし、逐次読み込みなし、
キャッシュなし。本物のブラウザが必要なら
[hv3](http://tkhtml.tcl.tk/hv3.html) を、Tkhtml3 組み込みの読みやすい
サンプルコードが欲しいならこのプロジェクトをどうぞ。

## 必要なもの

- Tcl/Tk 8.6 以降(開発は 9.0 で行っています)
- Tkhtml 3
- tcllib (`snit`)
- tklib (`widget::scrolledwindow`)
- tcltls — 任意。`https:` を使う場合のみ必要

## コマンド行からの使い方

`minhtmltk0.tcl` は *modulino* です: ライブラリとして `source` する
ことも、`wish` で直接実行することもできます。

```sh
# ローカルファイルを表示する
wish minhtmltk0.tcl --file=tests/html/001.html

# HTML 文字列をそのまま描画する
wish minhtmltk0.tcl --html='<h1>Hello, world!</h1>'

# web を閲覧する(http/https には --navigator=webnav が必要)
wish minhtmltk0.tcl --navigator=webnav --uri=https://example.com/
```

コマンド行オプションは POSIX long option 形式で統一しています:
`--name=value`、フラグの場合は `--name` だけ(`--name=1` の意味)。
各 `--name` はウィジェットオプション `-name` に対応します。

残りの引数はウィジェットのメソッド呼び出しとして実行され、結果が表示
されます。`Open` メソッド(コマンド行モード専用の便宜メソッド)は
指定 URI へ遷移します:

```sh
wish minhtmltk0.tcl --navigator=webnav Open http://localhost:8000/index.html
```

### キーバインド

| キー | 動作 |
|---|---|
| Up / Down / Left / Right | 1 行(単位)ずつスクロール |
| space / Next (PageDown) | 1 ページ下へスクロール |
| Prior (PageUp) | 1 ページ上へスクロール |
| Alt-Left / Alt-Right | 履歴を戻る / 進む |
| `<<Copy>>`(通常は Ctrl-C) | 選択テキストをコピー |

テキストはマウスで選択できます(クリック可能な要素の上を除く)。

## Tcl/Tk スクリプトからの使い方

`minhtmltk0.tcl` を `source` してウィジェットを作ります。package
index はないので、ソースを置いたパスをそのまま指定してください。

```tcl
package require Tk
source /path/to/minhtmltk/minhtmltk0.tcl

pack [minhtmltk .browser -file index.html] -fill both -expand yes
```

相対パスの `-file`/`-uri` は `[pwd]` を基準に解決されます。

### コンテンツの読み込み

```tcl
.browser configure -html {<h1>Hello, world!</h1>}  ;# HTML 文字列
.browser nav loadURI other.html                    ;# ナビゲーション(取得+差し替え+履歴)
.browser load $uri $html                           ;# 低レベル: 差し替えのみ
```

### http/https の閲覧

デフォルトの navigator(`localnav`)はローカルファイル専用です。
`-navigator webnav` を渡すと http/https が有効になり、ページから参照
される stylesheet や画像も http 経由で取得されるようになります。

```tcl
pack [minhtmltk .browser -navigator webnav \
          -uri https://example.com/] -fill both -expand yes
```

`-navigator` には navigator の type 名(`localnav`, `webnav`)か、
自分で構築した navigator オブジェクト(例:
`[::minhtmltk::navigator::webnav %AUTO%]`)を渡せます。`https:` には
tcltls パッケージが必要で、初回使用時に読み込まれます。

### 主なオプション

| オプション | 意味 |
|---|---|
| `-file`, `-uri` | 読み込む URI(どちらも navigator の `-uri` の別名) |
| `-home` | 何も読み込まれていないときに読み込む URI |
| `-html` | 描画する HTML 文字列 |
| `-navigator` | navigator の type 名またはオブジェクト(生成時のみ) |
| `-scrollbar` | `widget::scrolledwindow` に渡される(`both`, `vertical`, ...; 生成時のみ) |
| `-script-type` | どの `<script type=...>` を Tcl として実行するか(後述) |
| `-allow-script` | 文書中の Tcl 実行を許可するか。デフォルトは `-navigator` に依存(後述) |
| `-debug` | 真にすると logger の記録を stderr(`-debug-fh`)にも出力 |

### ドキュメントの読み取り

`search` は CSS セレクタに対応する Tkhtml のノードハンドルを返します。
その先は通常の Tkhtml ノード API です。未知のウィジェットサブコマンド
は下層の Tkhtml ウィジェットに転送されます。

```tcl
set node [.browser search h2]           ;# CSS セレクタ -> ノード
[$node children] text                   ;# テキスト内容
$node property background-color         ;# 計算済みスタイル
.browser location get                   ;# 現在の URI
.browser nav history list               ;# 訪問した URI の一覧
.browser nav history go-offset -1       ;# 戻る
.browser state parameter get q          ;# 現在 URI のクエリパラメータ
```

### イベント

ハンドラは全体にもノード単位にも登録できます。ハンドラ本体は `apply`
経由で実行され、`self`, `win`, `node`(別名 `this`)、`args` が使え
ます。

```tcl
.browser on ready  { puts "document ready" }
.browser on click  { puts "clicked $node" }
.browser node event on $node click { puts "clicked exactly $node" }
```

イベント名は `ready`, `click`, `mousedown`, `mouseup`, `mouseover`,
`mouseout`, `mousemove`, `change`, `submit` などが使えます。

### 文書中のスクリプトと `-allow-script`

ドキュメントは Tcl コードを含むことができます:
`<script type="tcl">...</script>` は `$self`/`$win` をウィジェットに
束縛した状態で実行され、`on<event>` 属性(`onclick`, `onchange`, ...)
はイベントハンドラとして登録されます。これらはインタプリタへのフル
アクセス権で動くため、`-allow-script` オプションで制御されます:

- 指定しなかった場合、デフォルトの navigator(ローカルファイル専用)
  を使うウィジェットでは従来通り `yes`、`-navigator` を明示的に渡した
  場合は `no` になります — `webnav` で取得したリモート文書は信用でき
  ないためです。
- 明示的な `-allow-script yes`/`no` は常に優先されます。たとえば信頼
  できるスクリプト入りアプリを http で閲覧するには:

```sh
wish minhtmltk0.tcl --navigator=webnav --allow-script \
    --uri=http://localhost:8000/trusted-app.html
```

無視されたスクリプトは logger に記録されます(`--debug=1` で stderr
に表示されます)。

`<script type="tcl">` のハンドラ本体は `include/script-tag.tcl` に
あります。コマンド行から起動した場合は自動で読み込まれます。ライブラリ
として使う場合に必要なら、include ファイルを自分で source してください:

```tcl
foreach inc [glob /path/to/minhtmltk/include/*.tcl] { source $inc }
```

どの `type=` 値を Tcl と見なすかは `-script-type` で、スクリプトに
公開するオブジェクトの差し替えは `-script-self` で指定します。

## Navigator API — read / load 規約

scheme 機構は「取得」と「差し替え」を分離しています:

- **`read`** = 取得のみ。browser への副作用なし。各 scheme handler は
  `scheme <name> read $uriObj ?args?` を実装し、`uri`(redirect 追跡
  後の実効 URI)、`content-type`(不明なら `""`)、`body` をキーに持つ
  response dict を返します(http は `status` も追加)。
- **`load`** = ウィジェット側のコンテンツ差し替え
  (`.browser load $uri $html`)。location/history の更新も行います。
- **`nav loadURI`** = 両者を合成したナビゲーションの入口。

`read` は直接使うこともできます。navigator が対応している scheme を
問わずバイト列を取得する例:

```tcl
set res [.browser nav read logo.png -mode binary]
dict get $res content-type   ;# => image/png
```

新しい scheme に対応するには、`scheme <name> read` を定義する
`snit::macro` を書き(`navigator/scheme/http.tcl` 参照)、それを
navigator type に合成します(`navigator/webnav.tcl` 参照)。
`navigator/samplenav.tcl` は `localnav` の注釈付きコピーです。

## テストの実行

```sh
cd tests
tclsh all.tcl                 # X ディスプレイが必要
# ヘッドレスなら:
xvfb-run -a tclsh all.tcl
```

## ライセンス

BSD スタイル。[LICENSE](LICENSE) を参照してください。
