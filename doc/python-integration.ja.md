# minhtmltk0 を Python (tkinter) から使う — 調査結果と設計案

## 概要

minhtmltk0 は Tkhtml3 のフォーム/リンク/イベント処理を Tcl (snit) で補う
ライブラリ。Python の tkinter は Tcl インタプリタを内蔵しているので、
`source minhtmltk0.tcl` すれば同じ widget が Python からも作れる。
問題は「フォーム入力やボタンのハンドラを Python の関数で書けるようにする」
部分で、現状のイベント機構は Tcl スクリプト本体 (`apply` の body) を前提に
している。本文書はそのギャップを埋めるための調査結果と、Tcl 側の最小限の
拡張 + Python 側ラッパーという設計案をまとめる。

前提(決定済み):
- Tcl 本体への汎用的な拡張は許容する
- 優先する利用スタイル: (a) Python 側でセレクタ指定してハンドラ登録、
  (b) `app:` スキームで Python がページを返す。文書内 Python は対象外
- Python パッケージはこのリポジトリの `python/` 配下に置く

調査日: 2026-09-22。行番号はその時点の `master` (9e53a61) のもの。

## 1. 環境(確認済み・追加インストール不要)

| 項目 | 値 |
|---|---|
| python3 | 3.14.7 (`/usr/bin/python3`), `_tkinter` は Tcl/Tk 9.0 ビルド |
| Python 内の Tcl | 9.0.2(`tkinter.Tcl().eval('info patchlevel')`) |
| Tkhtml | 3.0、`/usr/lib64/tcl9.0/Tkhtml3.0/libtcl9Tkhtml3.0.so`(自作 RPM `tkhtml3-3.0-10hk`) |
| Python の Tcl から `package require` | Tkhtml 3.0 / snit 2.3.4 / widget::scrolledwindow 1.2.1 / dicttool 1.2 / tooltip 2.0.1 / http / tls 全て OK |
| Python から `source minhtmltk0.tcl; minhtmltk .m` | 動作確認済み |
| tclsh8.6 | Tkhtml/snit なし(使わない) |
| 既存の Python ラッパー / tkinterweb | なし |
| CI | Ubuntu の `tk-html3`(Tcl 8.6 系)+ `xvfb-run tests/all.tcl` |

補足:
- Python から見える snit 型コマンドは `minhtmltk`(`minhtmltk0` ではない)。
  内側の Tkhtml widget は `$w html` または `$w.sw.html`。
- Tkhtml の `.so` は Python がリンクする Tcl とメジャーバージョンが一致して
  いる必要がある。この環境は両方 9.0 なので問題なし。配布時はここが最大の
  落とし穴(pip の tkinterweb 同梱バイナリは 8.6 用で使えない)。
- 非対話 `tclsh` に `package require Tkhtml` を食わせると Tk のイベント
  ループに入って戻らないので、検証スクリプトは末尾に `exit` を付ける。

## 2. 既存 API のうち Python 連携で使える要素

| 機能 | 場所 | Python 側から見た扱い |
|---|---|---|
| widget 生成 `minhtmltk .w -opt v` | `minhtmltk0.tcl:25` snit::widget | `tkinter.Widget.__init__(self, master, 'minhtmltk', cnf)` でそのまま作れる(hull は frame、class `Minhtmltk`)。**確認済み** |
| 文書ロード `load`, `nav loadURI`, `parse -final`, `-html` | `minhtmltk0.tcl:259,209,177` | `self.tk.call(self._w, ...)` |
| CSS セレクタ `search` | Tkhtml 委譲 | node handle 文字列 (`::tkhtml::node…`) が返る |
| グローバル/ノード別イベント `on`, `node event on` | `taghelper/mouseevent0.tcl:245,282` | ハンドラは `apply {self win selfns node this args} $cmd` の body (`:339`) |
| イベント種別 | `mouseevent0.tcl:222` | ready submit change mouseover mousemove mouseout click dblclick mousedown mouseup |
| submit 時の追加引数 `form $form name $name` | `taghelper/form.tcl:537` | `$args` に入る。`$form` は formstate オブジェクト。**Python 側で受信確認済み** |
| change の発火 | `formstate1.tcl:351-386` (変数 trace) | entry への入力・checkbox の invoke で Python に届くことを**確認済み** |
| フォーム値 `form get 0` / `@name`, `get_all`, `set`, `form dump`, `form restore` | `taghelper/form.tcl:113-141`, `formstate1.tcl:63,89` | flat な `name value …` リスト。multi (checkbox/select-multi) は値がリスト。`name dict get $name is_array` で区別 |
| ノードの Tk widget `$node replace` | Tkhtml | パス名が返る。tkinter の `nametowidget()` は **使えない**(Tcl 側で作られた widget は tkinter の children 辞書に無い)。`ttk.Entry` 等のサブクラスで `__init__` を差し替え `_w` を設定するプロキシで扱える(**確認済み**) |
| 文書内 Tcl `<script type=tcl>`, `on*` 属性 | `include/script-tag.tcl`, `form.tcl:192` | `-allow-script` で抑止可 |
| スキーム拡張 `scheme <name> read` | `navigator/common_macro.tcl:67`, `scheme/*.tcl` | snit method なので `snit::method` で後付け可能(**確認済み**、§4 B4) |
| `<<DocumentReady>>` 仮想イベント | `minhtmltk0.tcl:83,214` | Tk `bind` なので Reset で消えない |
| `_register` したコマンドの後始末 | tkinter | widget destroy 時に自動削除される(**確認済み**) |

## 3. 障害になる点と、調査中に見つかった既存バグ

### 3.1 設計上の障害

1. **ハンドラは Reset で全部消える。** `Reset` (`minhtmltk0.tcl:283`) は
   `state*` 変数を全て初期化し、`stateTriggerDict` も含まれる。
   `load` は先頭で Reset するので、`.w on click …` を登録した後に
   `nav loadURI` すると消える(`tests/mouseevent0.test:82` にも注記あり。
   Python から `load` 後に dump-handlers で消えることを確認済み)。
2. **ハンドラは Tcl コード片。** Python 関数を呼ぶには tkinter の
   `_register()` で作った Tcl コマンド名を body に埋め込む
   (`"pycmd click $node {*}$args"`)。イベント名は body 内で変数として
   見えない(`node event apply` の formals に `event` がない)ので、
   現状はイベントごとに body を組む必要がある。
3. **ハンドラ探索順はノード → タグ.class/タグ、ノード別が先勝ち。**
   `list-handlers` (`mouseevent0.tcl`): 同じノードにノード別
   ハンドラがあるとタグ別 (`a click` 等) は呼ばれない。
   (2026-09-22 の修正前はグローバルも「他が空の時だけ」だったが、
   現在はブラウザ流に常に 1 回発火する。)
   `<a id=x href=…>` にノード別 click を付けると既定のナビゲーションが
   走らない(location が空のまま)ことを**確認済み**。「このリンクだけ
   横取り」にはそのまま使える。
4. **`onsubmit` 属性は未対応。** `form add-for-node` は `node event configure`
   を呼ばない。submit は `<input type=submit>` の click から
   `node event trigger $node submit form … name …` で発生する。
5. **tkinter のオプション名変換。** tkinter は `allow_script=` を
   `-allow_script` にするので、ラッパーで `_` → `-` に変換して cnf 辞書で
   渡す。
6. **`change` の抑止モデルは「ユーザー操作までプログラム的変更扱い」。**
   `stateHandlingEventsList` は change ハンドラ実行時に立ち、KeyPress /
   Press / checkbutton の `-command` 等の `change allow` でしか下りない
   (`mouseevent0.tcl:424-445`)。Python からの `form set` は直前に
   ユーザー入力があれば change を発火し、なければしない(**確認済み**)。
   Python ラッパーの `Form.set()` は常に
   `$w node event change suppressing {…}` で包んで確定的にする。
   テストで `[$node replace] invoke` を使う時は先に
   `node event change allow` を呼ぶ(実操作なら `Press` が呼ぶ)。

### 3.2 既存バグ(Tcl 単体で再現確認済み)

7. **(修正済み 2026-09-22)** 同じキーに別イベントのハンドラを登録すると 2 つ目以降が消える。
   `node event on` (`mouseevent0.tcl:287`) の
   `dict with stateTriggerDict $node { lappend $ourEvDict($event) $command }` は、
   Tcl の `dict with` が「body 開始時に存在したキー」しか書き戻さないため、
   そのノードにまだ無いイベント名への `lappend` は捨てられる。
   再現: `.ht on click …; .ht on change …; .ht on ready …` → dump-handlers に
   `click` しか残らない。既存テストは 1 キー 1 イベントしか使っていないので
   顕在化していなかった。Python 連携では `on submit` と `on change` を同時に
   使うのが普通なので **最初に直すべき項目**。
   修正案: `dict with` をやめ、
   `dict set stateTriggerDict $node $event [list {*}[現在のリスト] $command]`
   にする(`dict lappend` はネストキー不可)。
8. **(修正済み 2026-09-22)** `return -code break` による伝播停止が動かない。 `handlelist`
   (`mouseevent0.tcl:316`) のコメントは「`return -code break` を使え」と
   言うが、既定の `-event-in-apply yes` では `apply` が返した break コードを
   `node event apply` メソッドが proc 境界で受けて
   `invoked "break" outside of a loop` エラーになる(rc=1 を確認)。
   つまり現状「後続ハンドラを止める」手段は無い(`return -level 2 -code break`
   なら動くが、呼び出し深さに依存する裏技なので API にはできない)。
9. **(修正済み 2026-09-22)** ノード別ハンドラが `trigger` 経路では class の数だけ重複実行される。
   `list-handlers` (`:377-405`) はノード別の判定を `foreach nspec` ループの
   内側で行うため、`<h2 class="a b">` にノード別 click を 1 つ付けて
   `node event trigger` すると同じ spec が 3 回返る(レビューで実測)。
   マウス経路 (`generatelist :345-358`) は `seen` で重複除去するので
   Press/Release は無事だが、`submit`/`change`/`mousemove`(Motion は
   `list-handlers` 直呼び)は影響を受ける。
10. **(修正済み 2026-09-22、ブラウザ流に変更)** グローバルハンドラはクリック 1 回につき祖先の数だけ発火する。
   `Release` (`:81-91`) は祖先ノード全部に click を生成し、グローバルの
   fallback (`:408-413`) はノードごとに評価されるため、`<div><h2>` の h2 を
   クリックすると `on click` が h2/div/body/html の 4 回呼ばれる
   (レビューで実測)。README の `.browser on click { puts "clicked $node" }`
   は 1 回を想定しているように読める。
11. 補足事実: `<button>` タグは未対応(`minhtmltk0.tcl:327` の "To be
   handled")。`<input type=button>` は既定 (`-use-tk-button no`) では Tk
   widget を持たず Tkhtml が描画し、widget 自身の Press/Release で click に
   なる(だから `node event on` で拾える)。`get_all` は押されたかに関係なく
   name 付き submit ボタンの値を含む (`form.tcl:525`)。

## 4. 提案する設計

方針: **Tcl 側には「Tcl 単体でも意味のある」小さな汎用拡張だけを入れ、
Python 固有のことは全て Python パッケージ側でやる。**
(minhtmltk0 は Tcl のサンプルコードなので、Python 依存のコードを
Tcl 側に入れない。)

### A. Tcl 側の変更(既存バグの修正 + 汎用拡張)

| # | 内容 | 変更箇所 | 既存テストへの影響 |
|---|---|---|---|
| A0 | **済**: バグ 7 修正(ついでに `node event add` の `$self $node event on` という typo も修正): `node event on` の `dict with` をやめ、`dict exists` で現在のリストを取り `dict set … $node $event [linsert $cur end $command]`。`node event remove` (`:267-280`) も event キー不在で落ちるので同様にガード | `mouseevent0.tcl:267-292` | なし。「`on ready` + `on submit` → dump-handlers に両方残る」テストを追加 |
| A2 | **`event` を handler に渡す**: `node event apply` (`:339`) の formals を `{self win selfns node this event args}` に。`node event configure` (`form.tcl:204`) は外側 formals を無視する二重 apply なので無影響 | `mouseevent0.tcl:339-343` | `mouseevent0.test:151-161` 「Visible parameters」の期待値に `event` を追加 |
| A3 | **済**: 伝播停止(バグ 8 修正): `node event apply` を `catch {apply …} result opts` で包み、rc==3 (break) なら `return -code break`(メソッド境界で改めて break を投げるので `handlelist` の `foreach` が止まり、戻り値 0 = 「全部は処理していない」が既定通りになる)、rc==4 (continue) は無視、それ以外は `return -options $opts $result`。`:319` のコメントを実態に合わせる | `mouseevent0.tcl:316-343` | なし。「2 つの h2 click、1 つ目が break → 2 つ目は走らない」テストを追加 |
| A3b | **済**: バグ 9 修正: `list-handlers` で startNode 自身にハンドラがあれば `nodeSpecList` をその 1 要素に潰し、ループ内は `$key` 側だけ見る(「ノード別がタグ別を隠す」意味は維持、重複だけ消える) | `mouseevent0.tcl:364-405` | なし。`<h2 class="a b">` で trigger → 1 回、のテスト追加 |
| A1 | **永続ハンドラ**: `state*` でない `myPersistentTriggerDict` を追加(snit がコンストラクタ前に初期化するので最初の Reset でも存在する)。`on` / `node event on` / `node event remove` / `node event clear` が先頭の `-persistent` を受け付け、永続側と `stateTriggerDict` の両方に入れる。キーは `""`・タグ・タグ.class に限定し `^::tkhtml::node` は拒否。`install-mouse-handlers` (`:451`) で **組込みタグハンドラ (`:462`) より先に** `stateTriggerDict` へコピーする — これで永続 `a click` が既定ナビゲーションより先に走り、A3 の break で prevent-default できる。`node event dump-persistent` をテスト用に追加 | `mouseevent0.tcl:236,245,282,451` | なし。「`on -persistent` → `load` 後も残る」「永続 `a click` が組込みより前」のテスト追加。`mouseevent0.test` は `.ht Reset` でハンドラが消える前提なので、永続テストの後始末で `clear -persistent` する |
| A4 | **未知スキームの委譲**: `common_macro.tcl` に `option -scheme-command ""`(`:8` 付近)。`read` (`:67`) で `scheme $scheme read` が無ければ `{*}$options(-scheme-command) $scheme $uriObj {*}$args` に委譲、それも無ければ従来の error。`minhtmltk0.tcl:62-64` に `delegate option -scheme-command to myURINavigator` を足して `$w configure -scheme-command …` でも使えるように。`loadURI`・画像 (`imagecmd.tcl:56`, `-mode binary`)・stylesheet (`style.tcl:69`) が自動で恩恵を受ける。`$uriObj` は呼び出し中だけ生きる(`:92-94` の scope guard)ので、受け側は `get/path/query` を即座に取り出して保持しない。相対リンク解決 (`tkhtml::uri`) のため `app:/path` の階層形式を推奨 | `common_macro.tcl:8,67-77`, `minhtmltk0.tcl:62` | なし。`tests/scheme-command.test` を新設(`apply` で dict を返す `-scheme-command` を設定 → `nav loadURI app:/x` → h2 テキストと location、`nav read app:/y -mode binary`) |
| A5 | **済(ブラウザ流を採用)**: グローバルは他のハンドラの有無に関係なく最内ノードで 1 回だけ発火する(fallback 意味論は廃止)。旧案: `generatelist` でグローバル fallback を各イベントの最内ノードに対してだけ評価する(`list-handlers` に `withGlobal` 引数を足し、先頭以外は 0)。Tcl 利用者にとって挙動変更だが、既存テストは祖先分の多重発火に依存していない。変えたくない場合は Python 側で「グローバル」を `html` タグ別として登録する(1 回だけ発火するが `node` が `html` になる)逃げ道がある。**推奨: 直す** | `mouseevent0.tcl:345-358,364` | なし。`<div><h2>` クリックで `on click` 1 回、のテスト追加 |
| A6 | (任意) `<form onsubmit>`: `form add-for-node` で `node event configure $node submit form $form`。ただし submit は input ノードで発火するので form ノードのハンドラには届かない。`add input submit` (`form.tcl:523`) で form ノードにも trigger するか、発火対象を form にするかは要判断(後者は既存テストの `$node tag` 期待値 `input` を変える) | `form.tcl:143,523` | 要判断。**Python 連携の必須要件ではない**ので後回し |

順序: ~~A0 → A2+A3(同じ hunk)→ A3b → A5~~(A0, A3, A3b, A5 は 2026-09-22 に実施済み)→ A2 → A1 → A4。
制約: CI は Ubuntu の `tk-html3`(Tcl 8.6)で走るので、Tcl 側の変更は
8.6 互換の構文に留める。

### B. Python パッケージ(`python/` 配下、新規)

```
python/
  minhtmltk/
    __init__.py      # HtmlView, Node, Form, Event
    _tcl.py          # Tcl 値 ⇔ Python 値変換、ForeignWidget プロキシ
  examples/
    form_demo.py     # フォーム + ボタンを Python 関数で処理するデモ
    app_scheme.py    # app: スキームで Python がページを返すデモ
  tests/
    test_htmlview.py # pytest (xvfb-run 前提)
  README.md
```

#### B1. `HtmlView(master, **opts)`

- `tkinter.Widget.__init__(self, master, 'minhtmltk', cnf)`。初回のみ
  `tk.eval('source <repo>/minhtmltk0.tcl')`(パスは `__file__` から
  `../../minhtmltk0.tcl` を既定とし、環境変数/引数で上書き可)。
  `include/*.tcl` は `allow_script=True` の時だけ source。
- `allow_script` の既定は **`no`**(Python でハンドラを書くのが目的なので
  文書内 Tcl は明示 opt-in)。
- メソッド: `load_html(html, uri='')`, `load_uri(uri, parameter=None)`,
  `search(selector, root=None) -> list[Node]`, `location`, `history()`,
  `back()/forward()`(`nav history go-offset ∓1`), `text()`
  (`[$w html] text text`), `see(node_or_selector)`, `parameter(name, default)`
  (`state parameter default`), `errors()/log()`(`error get`/`logger get`),
  `add_tcl_path(dir)`(`lappend auto_path`)。`emit_ready_immediately`
  オプションはテストの同期実行用に通す。
- `use_tk_button` オプション(`-use-tk-button`, `form.tcl:506`)も通す。
  既定ではボタンは Tkhtml が CSS で描画する。
- `HtmlView.bind()` は **`add=True` を既定にする**(または警告)。ライブラリの
  マウス処理は素の `bind $win <ButtonPress-1>` (`mouseevent0.tcl:453`) なので、
  tkinter の `view.bind('<Button-1>', f)` が次の Reset まで上書きしてしまう。
- ナビゲーションの失敗(未知スキーム、ファイル無し)は `load_uri` からは
  `TclError`、リンククリック起点なら `report_callback_exception` 経由で見える。
- README に書く注意点: Tk はメインスレッドから触る(ワーカーからは
  `after()` で戻す)。ハンドラ内の例外は報告されるが握りつぶされる。
  parse 中のタグハンドラのエラーは `logged` (`errorlogger.tcl:12`) が
  捕まえてログに入るだけで例外にならない。`<button>` 未対応。
  Python の Tcl と Tkhtml の Tcl メジャーバージョン一致が必須。

#### B2. イベント: `view.on(event, callback, selector=None)`

- `callback(ev: Event)` — `Event` は `name`, `node: Node`,
  `form: Form | None`, `args: dict`(submit の `name`、mousemove の
  `x`,`y`。`$args` は flat な kv リストなので `dict(zip(kv[::2], kv[1::2]))`、
  値は全て `str`)を持つ。callback が `True` を返したら後続ハンドラを止める
  (A3 前提で body を `if {[pycmd $event $node {*}$args]} {return -code break}`
  にする)。`Event.perform_default()` として組込みタグハンドラを明示的に
  呼ぶ手段(`$w node event tag a click $node`)も用意する(ノード別登録が
  組込みを隠すため)。
- 実装: `cmd = self._register(wrapper)`(destroy 時に tkinter が削除)。
  body は A2 後 `"{cmd} $event $node {*}$args"` の 1 種類。
  wrapper は **必ず `1`/`0` の int を返す**(Python の `None` は Tcl では
  文字列 `"None"` になり `if` で `expected boolean value` エラーになる)。
  callback 内の例外は wrapper で捕まえて報告し(`report_callback_exception`
  相当)、`0` を返す。
- イベント名は `mouseevent0.tcl:222` の固定リストで Python 側でも検証する
  (Tcl のエラーは `can't read "ourEvDict(x)"` で分かりにくい)。
- `selector` の扱い:
  - `None` → グローバル(`on -persistent`)。
  - タグ名 / `tag.class` → A1 の永続タグハンドラ。
  - それ以外の CSS セレクタ → `<<DocumentReady>>` の bind 内で `search`
    してノード別に `node event on`(文書ごとに再登録。Python 側で登録
    リストを保持)。ノード別登録は既定のタグハンドラを隠す(§3.1-3)ので
    「`a[href^="app:"]` だけ横取り」がこれだけで成立する。
- `<<DocumentReady>>` フック: hull の bindtags は
  `.w Snit::minhtmltk.w Minhtmltk . all`。snit の per-instance タグ
  (`<Destroy>` の後始末を担う)を壊さないよう、**index 1 に独自タグ
  `MinhtmltkPy<path>` を挿入**して、そこに `<<DocumentReady>>` を bind する
  (widget 自体への bind はユーザーの `view.bind(..., add=False)` で
  上書きされ得る)。このフックで文書世代番号を進め、セレクタ登録を
  再適用し、Python の `ready` コールバックを呼ぶ。クラス側の
  `%W trigger ready` (`minhtmltk0.tcl:83`) より先に走るので `on ready`
  の鶏卵問題は無い。`destroy()` で bind を外す。
- なぜ DocumentReady 再登録だけでは足りないか(A1 が要る理由):
  `parse` は `stateDocumentReady` を即座に立てるが `<<DocumentReady>>` は
  `after idle` (`minhtmltk0.tcl:219`) なので、その間に発生する `change` 等は
  Python ハンドラ不在で流れる。さらに DocumentReady 時の再登録は必ず
  組込み `a click` の **後**に並ぶので、タグ単位の prevent-default が
  できない。A1 は組込みより先にコピーするのでこれが解決する。
- 順序の注意: タグ `a` に Python ハンドラを足すと既定ナビゲーションと
  **両方**走る。止めたい場合は callback で `True` を返す(A1+A3)か、
  ノード別登録(組込みを隠す)+ 必要時 `perform_default()`。
  また submit ボタンは `form.tcl:537` でノード別 click を持つので、
  タグ別 `input click` は submit ボタンには届かない(submit イベントを使う)。

#### B3. フォーム: `view.forms()`, `view.form(index | '@name')`, `Form`

- `Form.get_all() -> dict[str, str | list[str]]`: `get_all` の flat
  リストを `tk.splitlist` し、`name dict get $n is_array` で list 化
  (tkinter の自動型変換に頼らない)。
- `Form.set(name, value)`: `node event change suppressing` で包む(§3.1-6)。
- `Form.names()`, `Form.action`(`cget -action`), `Form.name`, `Form.node`,
  `Form.nodes_of(name) -> list[Node]`。
- `Node`: `tag`, `attr(name, default=None)`, `attrs()`, `text()`,
  `children()`, `parent()`, `property()`, `bbox()`, `widget`
  (`$node replace` を ForeignWidget プロキシに包む)。handle は
  `::tkhtml::node<N>` で N は単調増加(再ロード後に同じ名前が別ノードを
  指すことはない)。再ロード後は `invalid command name` になるので `Node`
  は文書世代番号を持ち、古い世代なら `StaleNodeError` を先に投げる。
- ForeignWidget: `tkinter.Misc` 派生(または `ttk.Entry` 等のサブクラス)で
  `__init__` を差し替え `tk/_w/master/children={}` を設定するだけのプロキシ。
  `configure/bind/focus_set/insert/get` は `tk.call(self._w, …)` 経由なので
  そのまま動く(**確認済み**)。
- `view.form_dump()` / `view.form_restore(dump)` はそのまま委譲。

#### B4. `app:` スキーム: `view.register_scheme('app', handler)`

- A4 の `-scheme-command` に `_register` したコマンドを設定。ラッパーは
  `$uriObj` から `get/path/query/fragment` を即座に取り出して handler に渡す
  (uriObj は呼び出し中しか生きない)。handler は
  `(uri: str, mode: str) -> tuple[content_type, body]` を返し、`body` は
  `str` または `bytes`(`-mode binary` のとき。tkinter が bytes を Tcl の
  bytearray に変換するので画像もそのまま渡る。tkimg 無しなら PNG/GIF のみ)。
  ラッパーが `dict create uri … content-type … body …` に組み立てる。
  複数スキームは Python 側の辞書でディスパッチ。URI は `app:/path` の
  階層形式を推奨(相対リンク解決のため)。
- これで `<a href="app:page2">`、`<img src="app:chart.png">`(画像も
  `nav read` 経由なので自動対応)、`<form action="app:save">` が Python
  関数で処理できる。なおライブラリは form の `action` へ自動で遷移しない
  (submit はイベントを出すだけ)ので、遷移は Python 側で行う。
  `-scheme-command` は navigator インスタンス(= widget)ごとの設定なので、
  widget ごとに別の handler を持てる。submit は B2 の `on('submit', …)` で `Form.get_all()`
  を取り、`view.load_uri('app:result?…')` すれば「フォーム → 処理 →
  次ページ」の Web アプリ風構造になる。
- **Tcl を変えずに同じことをする逃げ道**(確認済み):
  `snit::method [$w nav info type] {scheme app read} {uriObj args} {pycmd [$uriObj get] {*}$args}`
  を `tk.eval` する。`nav loadURI app:first` → Python が HTML を返す →
  `<a href="app:next">` クリック → 既定の `a click` → 再び Python、
  history にも積まれる、まで動作した。ただし型全体に効き、ラッパーが
  Tcl 内部構造に依存するので本実装では A4 を使う。

#### B5. 対象外: 文書内 Python

`<script type="text/python">` / `onclick="py:…"` は今回の対象外
(ユーザー確認済み)。将来やるなら `snit::method ::minhtmltk {add script script}`
の差し替えで `-allow-script` のゲートを流用できる、とだけ記録しておく。

### C. 実装する場合の手順と検証

1. **Tcl 側 A0〜A5** を `taghelper/mouseevent0.tcl`, `navigator/common_macro.tcl`,
   `minhtmltk0.tcl` に入れ、`tests/mouseevent0.test` 更新と
   `tests/scheme-command.test` 新設。`cd tests && xvfb-run -a tclsh all.tcl`
   が通ること(この環境では xvfb-run で Python/wish とも動作確認済み。
   動かない環境では `DISPLAY=:0`)。
2. **Python パッケージ B1〜B4**。`xvfb-run -a python3 -m pytest python/tests`:
   - `HtmlView` 生成、`load_html`、`search`
   - `on('click', cb, selector='input[type=button]')` を `Press/Release`
     (`tests/mouse-test-util.tcl` の座標計算を Python で再現)で発火
   - `on('submit', …)` で `Form.get_all()` が dict で取れる
   - `on('change', …)` と `on('submit', …)` の併用(バグ 7 の回帰)
   - `register_scheme('app', …)` でリンク遷移が Python 関数を呼ぶ
   - 再ロード後もハンドラが有効(A1)
3. `python/examples/form_demo.py` を手で動かして確認。
4. README.md / README.ja.md に「Python から使う」節を追加。CI の
   ワークフローに `python3-tk` と pytest のステップを追加(Ubuntu の
   `tk-html3` は Tcl 8.6 用で、Ubuntu の python3 も 8.6 リンクなので
   CI でも噛み合う見込み。要確認)。
