# API設計

> 章番号は designs/ 全体の通し番号（元の統合議事録の章番号のまま）。文中の「本書X章」「本書X-Y」は、次のファイルの該当する章を指す。
>
> - 0章（位置づけ・用語）、2章、4章、12章：[サービス概要_コンセプト.md](サービス概要_コンセプト.md)
> - 1章、事前調査、15章：[前提_調査まとめ.md](前提_調査まとめ.md)
> - 3章、9章：[技術構成.md](技術構成.md)
> - 5章、13章、0-1（AIへの依頼方針）：[その他決め事.md](その他決め事.md)
> - 6章：[ページ設計.md](ページ設計.md)
> - 7章：[処理設計_類似度.md](処理設計_類似度.md)
> - 8章：[データベース.md](データベース.md)
> - 10章、11章、14章：[未決内容.md](未決内容.md)
> - 16章：[API設計.md](API設計.md)
> - 17章：[権限_バリデーション.md](権限_バリデーション.md)
> - 18章：[開発環境.md](開発環境.md)

## 16. API設計（Phase 4-0・4-1）

- 16-1：すべての API（エーピーアイ）に共通する決まり（Phase 4-0）
- 16-2：画面ごとの URL 一覧（画面の URL と、その画面で呼ぶ API。Phase 4-1）
- 16-3：窓口（エンドポイント）ごとの詳細（Phase 4-1）
- 権限、状態遷移、エラーとバリデーションの細部は本書17章

### 16-1. 共通ルール（Phase 4-0）

#### 16-1-1. データを取る場所

- ログイン後の画面では、データの取得・送信をすべてブラウザ側（クライアントコンポーネント）で行う
  - 経路は本書3-1 A-2 のとおり：ブラウザ → Next.js（rewrites（リライト））→ Rails
  - Next.js のサーバー側（サーバーコンポーネントなど）から Rails の API を呼ばない
- 理由
  - ブラウザが Cookie（クッキー）を自動で付けるので、本書3-1 の Cookie＋セッション、CSRF（シーエスアールエフ）対策の設計がそのまま使える
  - Next.js のサーバー側から呼ぶと rewrites を通らないため、Cookie の付け直しや別の CSRF 対策が必要になり、認証の流れが2通りになる
  - ログイン後の画面は検索エンジンに載せないので、サーバー側で取る利点（SEO（エスイーオー）、最初の表示の速さ）がほとんどない
- 割り切り：画面を開いた直後に、一瞬「読み込み中」の表示が出る
- API サーバーを別に持ち、ログイン後の画面が中心のアプリでは一般的な形（SPA（エスピーエー）と同じ考え方）

#### 16-1-2. 基本の形

- REST（レスト）＋JSON（ジェイソン）で作る。「何を」を URL で、「どうする」を HTTP（エイチティーティーピー）メソッドで表す

| HTTP メソッド | 意味 | 例 |
| --- | --- | --- |
| GET | 読む | GET /api/company/job_postings（自社の募集の一覧） |
| POST | 作る・操作する | POST /api/company/job_postings（募集を作る） |
| PATCH | 一部を書き換えて保存する | PATCH /api/company/job_postings/12 |
| DELETE | 消す | DELETE /api/session（ログアウト） |

- URL の先頭は `/api/`。バージョン（`/api/v1/` など）は付けない
  - Next.js の rewrites で、`/api/` で始まるものと、アイコンの `/rails/active_storage/…` を Rails へ、それ以外を Next.js の画面へ振り分ける（本書3-1 の注意点5、9-3）
  - バージョンは、自分では直せない利用者がいる公開 API のためのもの。今回の利用者は同じリポジトリの Next.js だけで、同時に直せるので不要
- Next.js の Route Handlers（ルートハンドラー。Next.js 自身の `/api` の機能）は使わない

#### 16-1-3. 入口の分け方

| 入口 | 使える人 | 置くもの |
| --- | --- | --- |
| `/api/...`（共通） | 誰でも（ログイン前も） | ログイン、ログアウト、ログイン中の人、新規登録、選択肢 |
| `/api/company/...` | 企業アカウントだけ | 企業の画面（C1〜C7、C10）で使う窓口 |
| `/api/student/...` | 学生アカウントだけ | 学生の画面（S1〜S7）で使う窓口 |

- 理由
  - 同じ募集でも、企業と学生で見せる範囲と項目が違う（目的・採用につながる可能性・求める人材は学生に見せない。学生には掲載中の募集だけを見せる）。入口ごとに返す形を別に作ることで、学生向けの返事に見せない項目がまぎれ込む事故を防ぐ
  - 種別の確認を、入口の共通部分で1回だけ行えばよい
  - 画面の C・S の区分と、そのまま対応する
- 割り切り：募集の表示など、似た処理が企業用・学生用の2か所に出ることがある

#### 16-1-4. URL の付け方

- 名詞の複数形にし、単語の区切りは `_`（snake_case（スネークケース））。テーブル名と同じ単語を使う。例：`/api/company/job_postings/12`
- 自分に1つしかないもの（ログイン中のセッション、自社・自分のプロフィール、相手とのスレッド）は、番号を付けない単数形にする（Rails の resource）。例：`/api/session`、`/api/company/profile`、`/api/company/students/5/message_thread`
- URL の中の番号は、データベースの id をそのまま使う。見てよい範囲の外の番号は 404 で断る（16-1-10）
  - 学生の番号は student_profiles の id、企業の番号は company_profiles の id を使う
- 状態を変える操作は、操作ごとに専用の URL（POST）にする
  - 例：`POST /api/company/candidacies/34/match`（応募にマッチする）、`POST /api/company/candidacies/34/decline`（見送る）
  - 「status を書き換える」汎用の窓口は作らない。1つの窓口で「今の状態」「募集が掲載中か」「誰が押したか」の組み合わせを判定すると、許されない移り変わりを通す穴ができやすいため
  - 操作ごとに分けることで、本書17-2 の状態遷移表の1行が URL 1本に対応する
  - Rails の member ルート（メンバールート）で書く
- 例外：募集の状態は、専用の URL にせず、募集の保存（16-3 ⑬⑭）で他の項目と一緒に保存する
  - 理由：募集の3つの状態は自由に行き来でき（本書17-2-2）、やりとりのように「誰が押したか」「相手の状態」が絡まないので、組み合わせの判定漏れが起きにくい。画面C3 のフォームの1項目とそのまま対応し、保存が1回で済む
  - 状態の確認は、モデルの検証として1か所に書く
- GET は読むだけに使う。データを変える操作は、必ず POST・PATCH・DELETE にする（CSRF 対策は GET 以外にかかるため）
  - 読むだけでも、メールアドレスのように URL に載せたくない値を送るときは POST にする（16-3 ④）

#### 16-1-5. ログインまわりの窓口

| 窓口 | 役割 |
| --- | --- |
| POST /api/session | ログイン。成功すると Cookie にセッションが入る |
| DELETE /api/session | ログアウト |
| GET /api/me | 今ログインしている人の情報。ログインしていなければ 401 |

- /api/me は、ヘッダーに必要な情報（名前、アイコン、企業なら未読の通知の件数）をまとめて返す（16-3 ③）
- ログイン（POST /api/session）の返事も /api/me と同じ形にする。画面側は role を見て、種別ごとのホームへ振り分ける（企業用のログイン画面から学生がログインしたら S2 へ、など。本書6-5 C8）
- ログインは、ログアウトするまで続く（Rails 8 の認証ジェネレーターの標準のまま）

#### 16-1-6. ログインの確認と振り分け

- 守り（Rails）：すべての API で、ログインしているか、種別が入口に合っているかを確認し、だめなら断る（未ログインは 401、種別が違えば 403。16-1-10）
- 振り分け（Next.js）：見た目のためだけに行う。画面側のプログラムは利用者がいじれるので、守りには使わない
- 画面のフォルダを、Route Groups（ルートグループ。URL に出ないフォルダの区切り）で「ログイン前（auth）」と「ログイン後（main）」に分け、それぞれの共通部分（レイアウト）で次の確認を行う

| フォルダ | 入る画面 | 画面を開いたときの確認 |
| --- | --- | --- |
| `app/page.tsx`（`/`） | トップ（振り分けだけ） | ログイン中なら種別ごとのホームへ、未ログインなら S8 へ |
| `app/company/(auth)/` | C8、C9 | ログイン済みなら種別ごとのホームへ。未ログインならそのまま表示 |
| `app/company/(main)/` | C1〜C7、C10 | 未ログインなら C8 へ、学生なら S2 へ |
| `app/student/(auth)/` | S8、S9 | ログイン済みなら種別ごとのホームへ。未ログインならそのまま表示 |
| `app/student/(main)/` | S1〜S7 | 未ログインなら S8 へ、企業なら C2 へ |

- どちらの側でも、画面を開いたら最初に /api/me を呼ぶ（16-1-7 の合言葉をそろえるため）。違うのは結果の扱いだけ
- ログイン画面へ移すときは、開こうとしていたページを `?return_to=/company/students/5` のように付け、ログイン後にそこへ戻す
  - return_to は、**ログインした人の種別と先頭が合っているときだけ使う**（企業なら `/company/`、学生なら `/student/`）。合わなければ捨てて、種別ごとのホームへ送る
    - この確かめで、「`/` で始まるアプリ内のパスだけ」の決まりも同時に満たす。「//別のサイト」も `/` で始まるが、どちらの種別の先頭でもないので捨てられる
    - 画面側の確かめは1つの関数（`lib/auth.ts` の `isAppPathFor`）にまとめ、C10 の通知のリンク（本書6-5 C10）でも使う（PR326）
    - return_to は URL の `?` の後ろなので、利用者が自由に書き換えられる。行き先は「書かれていたパス」ではなく「ログインした人の種別」から決める
    - これは見た目のための処理。書き換えられても他人のデータは見えない（Rails が 403 で断る）
- main 側の画面では、どの API から 401 が返ってきても、ログイン画面へ移す（別のタブでログアウトした場合など）
  - auth 側では、401 は「未ログインという普通の状態」として扱い、移動しない。ログイン画面へ移す処理がログイン画面自身にかかり、移動が繰り返されるのを防ぐため
- Next.js のミドルウェア（ページを開く前に割り込む仕組み）は使わない。Cookie があるかしか分からず、正しくログインしているかは結局 Rails に聞く必要があるため

#### 16-1-7. CSRF 対策

- Django で JavaScript から送るときと同じ形（Cookie で受け取り、ヘッダーで送り返す）にする
  1. Rails は、返事のたびに合言葉（CSRF トークン）を `CSRF-TOKEN` という Cookie に入れる。ログインしていない人への返事（/api/me の 401 など）にも入れる
     - この Cookie だけは、画面側のプログラムから読める設定にする。ログイン用の Cookie は読めないまま
  2. Next.js は、GET 以外を送るときに、その Cookie を読んで `X-CSRF-Token` ヘッダーに入れる。API を呼ぶ共通の関数1か所で行う
  3. Rails は、合言葉がない送信や、合言葉が違う送信を 403 で断る
- 画面を開くと最初に /api/me を呼ぶ（16-1-6）ので、ログイン画面でも、最初の送信の前に合言葉がそろう
- 実装の注意：合言葉の Cookie は、後処理（after_action（アフターアクション））ではなく、ログインの確認より前の前処理（before_action（ビフォーアクション））で付ける
  - Rails では、前処理が返事を返して処理を打ち切ると、後処理は動かない。後処理で付けると、未ログインで断った返事（401）に合言葉が付かず、ログイン画面から最初にログインしようとしたときに 403 で失敗する（誰もログインできなくなる）
  - 前処理の途中で付けた Cookie は、どこで打ち切られても返事に載る。そのため、401 以外のエラーの返事にも付く
  - Django の `@ensure_csrf_cookie`（合言葉の Cookie を必ず付ける指定）と同じ意図
- テスト（本書3-3 D-1）：「未ログインで /api/me を呼ぶ → 401 と一緒に CSRF-TOKEN の Cookie が返る → その合言葉を付けてログインすると成功する」を1本入れる
- Rails を API 専用で作ると、CSRF 対策が外れた状態で始まる。これを有効に戻す（本書3-1 A-2 の注意点2）

#### 16-1-8. JSON の書き方

| 項目 | 決まり | 例 |
| --- | --- | --- |
| キー名 | snake_case のまま（データベースの列名と同じ） | `"hourly_wage"` |
| 日時 | ISO 8601（アイエスオー）形式で、日本時間の時差付き（Rails の標準） | `"2026-09-22T15:30:00.000+09:00"` |
| 日付だけの項目 | 年-月-日 | `"2026-09-22"` |
| 空欄 | キーを省かず、null（ヌル）を入れる | `"growth": null` |
| 選択肢（enum（イーナム）） | 番号ではなく、英語の名前で返す（名前は本書8-5） | `"status": "published"` |
| 小数（decimal） | 数値に直して返す | `"years": 1.5` |

- キー名：データベース・Rails・設計書の名前と1対1で対応させ、名前の変換をはさまない。JavaScript で普通の camelCase（キャメルケース）とは見た目がそろわないが、変換のミスが起きないことを優先する
- 日時：「3時間前」「9月20日」のような表示用の加工は、画面側で行う
- 空欄：画面側が「キーがあるか」を気にしなくて済み、「未入力」と表示するルール（本書5-10）とそのまま対応する
- 選択肢：番号で返すと、画面側にも番号の対応表が要り、食い違いの原因になるため
- 小数：Rails の標準では、小数の列は `"1.5"` という文字列で JSON になる。画面側で計算を誤らないよう、数値に直す
- 送るとき、未入力の項目は省いてよい。省いた項目は空欄か既定値になる
- 画像（アイコン）だけは、JSON ではなく multipart/form-data（マルチパート・フォームデータ。HTML のフォームでファイルを送るときの形式）で、専用の窓口に送る（16-3 ⑩・⑰）

#### 16-1-9. 選択肢・表示名と、判定の置き場所

- 選択肢（enum の値、稼働条件の選択肢）と日本語の表示名、性格・カルチャーの5軸の名前と両端の説明は、Rails の1か所で持つ（本書9-1）
- これらは、選択肢の窓口（16-3 ⑦ GET /api/options）で、マスタ（職種・工程・技術・業界・事業形態・都道府県・大学・学部・学科）と一緒に1回で返す
- 画面側は、これを使ってフォームの選択肢を作り、データの中の名前（`"published"`）を日本語（「掲載中」）に直して表示する。画面側に選択肢の表を手で書かない
- 判定も Rails で行い、結果を返す。画面側に同じ判定を書かない
  - 学生と募集の比較：業界・職種・使用技術の重なりと、稼働条件の一致（16-3 ㉓）。カルチャーは判定しない（値を返し、画面は2つの点を重ねて描くだけ。PR258・PR259）
  - 今押せる操作（16-3 ㉓ の available_actions）、メッセージを送れるか（16-3 ㊲ の can_send）
  - やりとりの状態のタグ（16-3 ㉑・㉒・形D の tag）、学生から見た状態（形E の my_status）
- **迷ったときは Rails 側で計算して返す。画面側では計算しない**
  - Rails と Next.js は言語が違うので、同じ判定を両方に書くと必ず2通りの実装になり、型でも守られない
  - 特に「複数の列の組み合わせに付けた名前」（例：発生元が応募 × 状態が未マッチ ＝「未対応応募」）は、どの選択肢にも存在しない言葉なので、必ず Rails が計算して返す
- 理由：画面側にも同じ表や判定を書くと、片方だけ直して食い違う（例：継続期間に選択肢を足したのに画面に出てこない、押せるのにエラーになるボタンができる）ため
- 割り切り：画面を開くときに、取りに行く回数が1回増える。選択肢はほとんど変わらないデータなので、一度取ったら使い回す

#### 16-1-10. HTTP ステータスとエラーの形

HTTP ステータス（返事の最初に付く3桁の番号）の使い分け

| 番号 | 意味 | 使う場面 | 画面側の動き |
| --- | --- | --- | --- |
| 200 | 成功 | 読む・保存・操作が成功した | そのまま表示 |
| 201 | 作った | 新規登録、募集の作成、応募、スカウト、メッセージの送信 | 同上 |
| 204 | 成功（返す中身なし） | ログアウト、メールアドレスの確認、通知の既読 | 同上 |
| 401 | ログインしていない | 未ログインで API を呼んだ。ログインに失敗した | main 側の画面ならログイン画面へ移す（16-1-6。message は「ログインしてください」）。ログインの窓口では移さず、「ログインができません」を表示 |
| 403 | してはいけない | 種別が違う入口を呼んだ。CSRF の合言葉がない・違う | 「この操作はできません」 |
| 404 | 見つからない | 存在しない番号。見てよい範囲の外の番号（下の決まり） | 「見つかりません」 |
| 409 | 今の状態ではできない | 掲載中でない募集へのスカウト。応募済みの募集への応募。マッチしていない相手へのメッセージ | 「この操作は今はできません」と出し、最新の状態を読み直す |
| 422 | 入力が正しくない | 必須の項目が未入力。パスワードが短い。登録済みのメールアドレス。**必須のパラメータがない**（㉒でおすすめ順なのに募集の番号がない、など） | 項目ごとにエラーを表示 |
| 429 | 回数が多すぎる | ログインの回数制限（本書3-3 D-2） | 「しばらくしてからお試しください」 |
| 500 | サーバーの不具合 | 想定外のエラー | 「エラーが起きました」 |

エラーの中身の形

```json
{
  "message": "入力内容を確認してください",
  "errors": {
    "email": ["このメールアドレスは登録済みです"],
    "password": ["8文字以上で入力してください"]
  }
}
```

- message は、どのエラーにも付ける（画面の上部に出す一言）
- errors は、422 のときだけ付ける（各項目の下に出す）
- 文言は Rails が日本語で作り、画面はそのまま出す。文言の中身は本書17-3
- 理由
  - 番号で大きく分けておくと、画面側の「エラーのときの動き」を共通の関数1か所にまとめられる
  - 422（入力の誤り）と 409（状態の問題）を分けるのは、画面側の動きが違うため。422 は項目の横にエラーを出して直してもらい、409 は画面を読み直す（別のタブで状態が変わった場合などが多い）
  - errors の形は、Rails がエラーを持つ形（項目ごとの一覧）そのままなので、変換がほぼ要らない
- 409 の返し方：モデルの処理（応募・マッチなど）が「今の状態ではできない」エラー（`ConflictError`。`app/errors/conflict_error.rb`）を投げ、エラーの返事の共通の部品（`concerns/error_responses.rb`）が1か所で 409 に変える。404（見つからない）と同じ仕組みにし、窓口ごとに 409 の分かれ道を書かない（PR205）
  - 窓口は、成功と 422 のことだけを書く。409 の文言も1か所で決まる（本書17-3-6）
  - 同時に2回押されてデータベースの「1件だけ」の決まり（UNIQUE）に弾かれたときも、同じエラーにして 409 で返す

番号の探し方の決まり

- 窓口が受け取る番号は、パスの `:id` でも、job_posting_id のようなパラメータでも、その人が見てよい範囲の中から探す。範囲外の番号は 404 にする

| 番号の種類 | 企業から見てよい範囲 | 学生から見てよい範囲 |
| --- | --- | --- |
| 募集 | 自社の募集（状態は問わない） | 掲載中の募集と、自分とやりとりがある募集（一度も掲載していない募集は不可） |
| やりとり | 自社の募集のやりとり | 自分のやりとり |
| 学生 | すべての学生 | ― |
| 企業 | ― | すべての企業 |
| 通知 | 自社宛ての通知 | ― |
| プチ職業体験の講座・ハードル | すべての講座（㊾） | すべての講座（㊻㊼㊽） |
| 自己分析 | 学生詳細（㉓）の中で、その学生の分をすべて読む。番号で直接は探さない | 自分の分だけ（㊻㊽。講座の番号で探す） |

- 理由
  - 「自社の募集の中から番号で探す」形で書くと、Rails では見つからないときに自然に 404 になる。わざわざ 403 を返す仕組みを作るより単純
  - 読むだけの窓口でも、他社の募集番号が通ると、他社でのやりとりが見えてしまう（例：学生検索のタグに、その学生と他社の募集とのやりとりが出る）。本書5-12 で避けると決めた「他社での行動を見せる」に直結するため
- テスト（本書3-3 D-1）に、少なくとも次を入れる
  - 他社の募集の番号を job_posting_id に入れて、16-3 ㉑・㉒・㉕ を呼ぶと 404 になる
  - 関係のない学生が、非公開・終了の募集の番号で 16-3 ⑲・㉝ を呼ぶと 404 になる

#### 16-1-11. ページ分け

- ページ番号で指定する。例：`GET /api/student/job_postings?page=2`
- 1ページは20件で固定する（利用者は変えられない）
- ページ分けする一覧の返事は、次の形にそろえる

```json
{
  "items": [],
  "pagination": { "page": 2, "per_page": 20, "total_count": 135, "total_pages": 7 }
}
```

- 検索の窓口（⑱ 募集検索・㉒ 学生検索）だけは、条件に合う件数も返す。条件で結果を減らさず、合致／合致外の2群に分けて並べるため（本書7-3）

```json
{
  "items": [{ "matched": true }],
  "pagination": { "page": 1, "per_page": 20, "total_count": 1240, "matched_count": 38, "total_pages": 62 }
}
```

- matched：その1件が、指定した条件を**全部**満たしていれば true。判定は Rails が行う（本書16-1-9）
- matched_count：条件に合う件数。画面は「条件に合う38件／全1,240件」のように出す
- 並び順は、合致（matched が true）の群がすべて先、そのあとに合致外の群。どちらの群も、画面で選んだ並び順で並ぶ
- ページ分けは2つの群を通して振る。画面は、matched が true から false に変わるところに「ここから条件に合いません」の区切りを出す（合致が0件なら、区切りが先頭に来る）
- ページ分けしない一覧も `items` で包んで返す（`pagination` は付けない）
- ページ分けする一覧：16-3 ⑱（募集検索）、㉑（候補者）、㉒（学生検索）、㉞（募集管理）、㉟（スカウト管理）、㊱・㊴（スレッド一覧）、㊷（通知）
- ページ分けしない一覧：16-3 ⑪（自社の募集）、⑳ の募集、ポップアップ（㉕・㉝。最大5件）、㊲・㊵ のメッセージ
- 理由
  - 画面に「1 2 3 … 次へ」を出せて分かりやすい（Django の Paginator（ページネーター）と同じ考え方）
  - 一覧の形を1つにそろえると、画面側のページ送りの部品を使い回せる
  - 「続きから読む方式（カーソル方式）」は無限スクロールや大量のデータ向けで、今回は不要

#### 16-1-12. 日付の基準と「ログイン中の操作」

- アプリは日本時間（Asia/Tokyo）で動かす
  - データベースには、Rails の標準どおり世界標準時（UTC（ユーティーシー））で保存し、読み書きのときに Rails が日本時間に直す
  - 最終活動日の「その日」、「30日以上」、募集の開始月が「今月より前」か（本書5-6）は、すべて日本時間で数える
  - Django の `TIME_ZONE = 'Asia/Tokyo'`、`USE_TZ = True` と同じ考え方
- 「ログイン中の操作」（本書5-4 の最終活動日）は、ログインした状態での API の呼び出しすべてとする。画面を開いたときの /api/me も含む
  - 記録する場所が Rails の共通部分1か所で済み、画面を開いただけでも「使っている」と言えるため

#### 16-1-13. 画面の URL

決まり

- 企業用は `/company/…`、学生用は `/student/…` で始める（16-1-3 の API の入口と対応）
- 単語は API と同じ名前（snake_case）にする
- 「何を見るか」はパス（`/` で区切る部分）で表し、「どう見るか」（タブ、絞り込み、並び順、ページ）は `?` の後ろ（クエリ）で表す
  - 例：C5 で募集12を選んだ状態 → `/company/students?job_posting_id=12`
  - 検索条件が URL に残るので、ブラウザの「戻る」で検索結果に戻れる
- `/`（トップ）は、ログイン中なら種別ごとのホーム（C2・S2）へ、未ログインなら S8 へ移す
- 画面のフォルダの分け方（ログイン前・ログイン後）は 16-1-6

企業側

| 画面 | URL |
| --- | --- |
| C1 企業プロフィール編集 | `/company/profile` |
| C2 募集一覧 | `/company/job_postings` |
| C3 募集詳細編集（新規） | `/company/job_postings/new` |
| C3 募集詳細編集（編集） | `/company/job_postings/[id]/edit` |
| C4 候補者一覧 | `/company/candidacies`（募集別のタブ：`?job_posting_id=12`、見送り・合格・不合格も表示：`?show_all=true`） |
| C5 学生検索 | `/company/students`（募集を選んだ状態：`?job_posting_id=12`） |
| C6 学生詳細 | `/company/students/[id]`（選んだ募集：`?job_posting_id=12`） |
| C7 メッセージ管理 | `/company/messages`（学生のスレッドを開いた状態：`?student_id=5`） |
| C8 ログイン | `/company/login` |
| C9 新規登録 | `/company/signup` |
| C10 通知 | `/company/notifications` |
| C11 プチ職業体験の内容 | `/company/job_trials/[id]` |

学生側

| 画面 | URL |
| --- | --- |
| S1 マイページ | `/student/profile` |
| S2 募集一覧 | `/student/job_postings` |
| S3 募集管理 | `/student/candidacies`（タグで絞る：`?status=applied`） |
| S4 スカウト管理 | `/student/scouts` |
| S5 メッセージ管理 | `/student/messages`（企業のスレッドを開いた状態：`?company_id=3`） |
| S6 募集詳細 | `/student/job_postings/[id]` |
| S7 企業詳細 | `/student/companies/[id]` |
| S8 ログイン | `/student/login` |
| S9 新規登録 | `/student/signup` |
| S11 プチ職業体験一覧 | `/student/job_trials` |
| S12 プチ職業体験 | `/student/job_trials/[id]`（講座と自己分析を1つの URL の中のステップで進む。PR388） |

- `[id]` の部分には番号が入る（例：`/company/students/5`）
- 通知の移動先（notifications.link_path）は、通知先の募集のタブを選んだ状態の C6 にする。例：`/company/students/5?job_posting_id=12`
- 理由
  - 先頭を種別で分けると、ログインと種別の確認（16-1-6）を、フォルダ1つの共通部分に置くだけで、その種別の全画面に効かせられる
  - API と同じ単語にすると、画面と API の対応が一目で分かる
  - C7・S5 のスレッドは「企業×学生で1本」なので、相手が決まればスレッドが決まる。C4・C6 から来るときは相手の番号を持っているので、それをそのまま使える
  - S3 を candidacies としたのは、テーブル名（やりとり）に合わせたため。見た目の自然さより、対応の分かりやすさを優先した

#### 16-1-14. Phase 4-0 では決めないもの（Phase 5・6 で選ぶ）

| 道具 | 選ぶ時期 |
| --- | --- |
| Rails で JSON を作る道具 | **jbuilder（ジェイビルダー）に決定**（Phase 5 のステップ5）。Rails の公式の部品で、`rails new` の Gemfile にも候補として書かれており、最も一般的なため。形A〜E のような繰り返し出てくる形は、部品化（partial（パーシャル））して使い回す。候補だった Alba（アルバ）は、速さを重視した部品だが、1ページ20件の規模では差が出ないため採らない |
| 画面側でデータを取るときの補助の部品 | **SWR（エスダブリューアール）に決定**（Phase 6 の順2）。Next.js を作っている Vercel（ヴァーセル）社の部品で、`useSWR(URL, 取る関数)` の1行で「取った結果を覚えて使い回す」「画面を開き直したら裏で取り直す」「読み込み中・失敗の状態」を扱える。**画面のデータの取得（GET）はすべて SWR で行い、取り方を1通りにそろえる**（順1 で手作りした選択肢の取り置きと、C1 の⑧の取得も置き換える）。保存（POST・PATCH など）は、今までどおり API を呼ぶ共通の関数で送る。**ログインの確認（③ /api/me）は SWR にせず、共通の枠が画面を移るたびに呼ぶ今の仕組みのままにする**（画面のデータではなく「画面を見せてよいか」の門番で、覚えている内容を使わず毎回呼ぶ必要があるため。16-1-6）。ログイン後の画面で SWR の取得が 401 になったら、ログイン画面へ移す（共通の枠に1か所で設定する）。候補だった TanStack Query（タンスタック・クエリ）は、利用者は多いが保存の処理まで扱う機能が豊富なぶん覚えることが多く、保存を共通の関数で送る今回の形には SWR で足りるため採らない |
| ページ分けの部品 | **Pagy（パギー）に決定**（Phase 6 の順4。最初にページ分けする一覧である⑱ 募集検索を作るとき）。データベースの結果も Ruby で並べた結果（配列）も、同じ書き方 `pagy(:offset, 一覧)` でページに分けられる。**おすすめ順も、上位100件の並びを SQL の並べ替えに入れてデータベースで並べるので、新着順と同じくデータベースの結果を分ける**（順13。PR295。本書7-5、9-1-1）。手入れが活発（43.6.3、2026年9月）。大きな版が上がったときに書き方が変わった前例があるので、Gemfile で 43 系に固定する。1ページの件数（20件）と、分けたページの行に関連をまとめて読み込む処理は、コントローラーの共通の部品（`concerns/pagination.rb`）1か所に置く。範囲外のページは空の一覧、数でないページ番号は1ページ目になる（Pagy の標準のまま）。候補だった Kaminari（カミナリ）は、利用者は多いが2021年12月から更新が止まっているため採らない |

- いずれも道具選びで、16-1 の決まりに従っていれば、どれを選んでも API の形は変わらない

### 16-2. 画面ごとの URL 一覧

- 画面ごとに、画面の URL（Next.js のページ）と、その画面で呼ぶ API（`/api/`）を、タイミングの順に並べる
- すべての画面で、開いたときに ③ GET /api/me を呼ぶ（16-1-6）。下の表では、トップとログイン画面以外は省く
- ⑦ GET /api/options は、一度取ったら使い回す（まだ取っていなければ呼ぶ）
- ①〜㊾ は 16-3 の窓口の番号。「→」は成功したあとに移る画面

#### 16-2-1. 共通

| 画面 | タイミング | URL | 概要 |
| --- | --- | --- | --- |
| トップ | 画面の URL | `/` | 振り分けだけの画面 |
| | 開いたとき | ③ GET /api/me | ログイン中なら種別ごとのホーム、未ログインなら `/student/login` へ移る |
| 企業のヘッダー | タブ | `/company/profile`、`/company/job_postings`、`/company/candidacies`、`/company/students`、`/company/messages` | 会社情報、募集管理、候補者管理、学生検索、メッセージ |
| | ベルのアイコン | `/company/notifications` | 未読件数は ③ の unread_notifications_count |
| | ログアウト | ② DELETE /api/session | → `/company/login` |
| 学生のヘッダー | タブ | `/student/profile`、`/student/job_postings`、`/student/job_trials`、`/student/candidacies`、`/student/scouts`、`/student/messages` | マイページ、募集検索、プチ職業体験、募集管理、スカウト管理、メッセージ（プチ職業体験は順18。PR385） |
| | ログアウト | ② DELETE /api/session | → `/student/login` |

#### 16-2-2. 企業側

| 画面 | タイミング | URL | 概要 |
| --- | --- | --- | --- |
| C1 企業プロフィール編集 | 画面の URL | `/company/profile` | |
| | 開いたとき | ⑦ GET /api/options | 業界・事業形態・人数の選択肢 |
| | 開いたとき | ⑧ GET /api/company/profile | 自社のプロフィール |
| | 保存 | ⑨ PATCH /api/company/profile | 本体を保存 |
| | 保存（アイコンを変えたとき） | ⑩ POST /api/company/profile/icon | ⑨の成功後に続けて送る |
| C2 募集一覧 | 画面の URL | `/company/job_postings` | 企業のホーム |
| | 開いたとき | ⑪ GET /api/company/job_postings | 自社の全募集 |
| | 募集新規作成 | `/company/job_postings/new` | 画面の移動だけ |
| | 編集する | `/company/job_postings/[id]/edit` | 画面の移動だけ |
| | この募集の候補者を見る | `/company/candidacies?job_posting_id=[id]` | 画面の移動だけ |
| | この募集でスカウト先を探す | `/company/students?job_posting_id=[id]` | 画面の移動だけ。その募集を選んだ状態（「○○」におすすめ順）で開く。条件は入れない（PR303） |
| C3 募集詳細編集（新規） | 画面の URL | `/company/job_postings/new` | |
| | 開いたとき | ⑦ GET /api/options | 職種・工程・技術などの選択肢 |
| | 開いたとき | ⑧ GET /api/company/profile | 会社名と、空欄のときの既定値 |
| | 保存 | ⑬ POST /api/company/job_postings | → `/company/job_postings` |
| C3 募集詳細編集（編集） | 画面の URL | `/company/job_postings/[id]/edit` | |
| | 開いたとき | ⑦ GET /api/options | 同上 |
| | 開いたとき | ⑧ GET /api/company/profile | 同上 |
| | 開いたとき | ⑫ GET /api/company/job_postings/:id | 募集の全項目 |
| | 保存 | ⑭ PATCH /api/company/job_postings/:id | → `/company/job_postings` |
| C3 募集詳細編集（新規・編集とも） | この募集に近いプチ職業体験の講座名 | `/company/job_trials/[id]` | 新しいタブで開く（順19）。講座の選択肢は ⑦ の masters.job_trials |
| C4 候補者一覧 | 画面の URL | `/company/candidacies` | `?job_posting_id=`（タブ）、`?show_all=true`（見送り・合格・不合格も表示） |
| | 開いたとき | ⑪ GET /api/company/job_postings | タブに出す募集の名前 |
| | 開いたとき・タブや表示の切り替え・ページ送り | ㉑ GET /api/company/candidacies | やりとりの一覧 |
| | 詳細を見る | `/company/students/[学生id]?job_posting_id=[募集id]` | 画面の移動だけ |
| | メッセージ（㉑ の after_match が true の行だけ。PR209・PR224） | `/company/messages?student_id=[学生id]` | 画面の移動だけ |
| C5 学生検索 | 画面の URL | `/company/students` | `?job_posting_id=` と検索条件 |
| | 開いたとき | ⑦ GET /api/options | 条件の選択肢 |
| | 開いたとき | ⑪ GET /api/company/job_postings | 募集の選択肢 |
| | 募集を選んだとき | ⑫ GET /api/company/job_postings/:id | その募集の稼働条件を取っておく。稼働条件のポップアップの「この募集の稼働条件で選ぶ」を押したときだけ、条件のボタン（下書き）に入れる（推薦検索。PR302）。募集を選んだだけでは条件は変わらない |
| | 開いたとき・条件や並び順の変更・ページ送り | ㉒ GET /api/company/students | 学生の一覧 |
| | 詳細を見る | `/company/students/[id]?job_posting_id=[選んだ募集id]` | 画面の移動だけ |
| C6 学生詳細 | 画面の URL | `/company/students/[id]` | `?job_posting_id=`（募集の選択欄で選ぶ募集。選び直すと履歴に積まずに書き換える。PR267） |
| | 開いたとき | ⑦ GET /api/options | 表示名、5軸の説明 |
| | 開いたとき | ㉓ GET /api/company/students/:id | 学生のプロフィールと、自社の全募集ぶんの状態・比較 |
| | スカウトをする（文面を入力して送信） | ㉔ POST /api/company/scouts | スカウトを送る |
| | スカウトの送信後 | ㉕ GET /api/company/students/:id/similar_students | 「スカウトを送りました」のポップアップの「この学生に似た学生」（PR320）。ポップアップを開いているときだけ取る |
| | ポップアップの学生 | `/company/students/[その学生id]?job_posting_id=[スカウトに使った募集id]` | 画面の移動だけ。スカウトに使った募集を選んだ状態で開く（PR315）。移る前にポップアップを閉じる |
| | マッチする | ㉖ POST /api/company/candidacies/:id/match | 応募にマッチする |
| | 見送る | ㉗ POST /api/company/candidacies/:id/decline | 見送る |
| | 見送りを取り消す | ㉘ POST /api/company/candidacies/:id/undo_decline | 見送りを未マッチに戻す（応募由来・スカウト由来とも） |
| | 合格として保存 | ㉙ POST /api/company/candidacies/:id/pass | |
| | 不合格として保存 | ㉚ POST /api/company/candidacies/:id/fail | |
| | この学生とのメッセージ（㉓ の has_message_thread が true のとき） | `/company/messages?student_id=[id]` | 画面の移動だけ。募集の選択欄の外に置く |
| | 修了したプチ職業体験を押す | （窓口なし） | 自己分析のポップアップを開く。中身は ㉓ の self_analyses に入っている（順19） |
| | ポップアップの「講座の内容を見る」 | `/company/job_trials/[id]` | 新しいタブで開く（順19） |
| C7 メッセージ管理 | 画面の URL | `/company/messages` | `?student_id=`（開くスレッド）、`?page=`（スレッド一覧のページ） |
| | 開いたとき・ページ送り | ㊱ GET /api/company/message_threads | スレッド一覧 |
| | 開いたとき（student_id があるとき）・スレッドを選んだとき | ㊲ GET /api/company/students/:id/message_thread | その学生とのチャット |
| | 送信 | ㊳ POST /api/company/students/:id/message_thread/messages | メッセージを送る |
| | 学生名・アイコン（【仕上げ】） | `/company/students/[id]` | 画面の移動だけ |
| C8 ログイン | 画面の URL | `/company/login` | |
| | 開いたとき | ③ GET /api/me | ログイン済みなら種別ごとのホームへ。未ログインでも合言葉の Cookie がそろう |
| | ログイン | ① POST /api/session | → return_to、なければ `/company/job_postings`（学生アカウントなら `/student/job_postings`） |
| | 新規登録はこちら | `/company/signup` | 画面の移動だけ |
| | 学生の方はこちら | `/student/login` | 画面の移動だけ |
| C9 新規登録 | 画面の URL | `/company/signup` | |
| | 開いたとき | ⑦ GET /api/options | 業界・事業形態・人数の選択肢 |
| | ステップ1から進むとき | ④ POST /api/email_checks | メールアドレスの重複を確認 |
| | 登録する | ⑤ POST /api/company_registrations | アカウントとプロフィールを作り、自動でログイン |
| | 登録の直後（アイコンを選んでいたとき） | ⑩ POST /api/company/profile/icon | → `/company/job_postings` |
| | すでにアカウントをお持ちの方はこちら | `/company/login` | 画面の移動だけ |
| C10 通知 | 画面の URL | `/company/notifications` | `?page=` |
| | 開いたとき・ページ送り | ㊷ GET /api/company/notifications | 自社宛ての通知 |
| | 通知を押す | ㊸ POST /api/company/notifications/:id/read | → link_path（`/company/students/[id]?job_posting_id=[id]`） |
| | すべて既読にする | ㊹ POST /api/company/notifications/read_all | |
| C11 プチ職業体験の内容 | 画面の URL | `/company/job_trials/[id]` | 順19 |
| | 開いたとき | ⑦ GET /api/options | 中分類・工程の名前、理由の種類の表示名 |
| | 開いたとき | ㊾ GET /api/company/job_trials/:id | 講座の中身（正解と解説を含む） |

#### 16-2-3. 学生側

| 画面 | タイミング | URL | 概要 |
| --- | --- | --- | --- |
| S1 マイページ | 画面の URL | `/student/profile` | |
| | 開いたとき | ⑦ GET /api/options | 選択肢、5軸の説明 |
| | 開いたとき | ⑮ GET /api/student/profile | 自分のプロフィール |
| | 保存 | ⑯ PATCH /api/student/profile | 本体を保存 |
| | 保存（アイコンを変えたとき） | ⑰ POST /api/student/profile/icon | ⑯の成功後に続けて送る |
| S2 募集一覧 | 画面の URL | `/student/job_postings` | 学生のホーム。検索条件、`?sort=`、`?page=` |
| | 開いたとき | ⑦ GET /api/options | 条件の選択肢 |
| | 開いたとき | ⑮ GET /api/student/profile | 自分の稼働条件を取っておく。稼働条件のポップアップの「自分の稼働条件で選ぶ」を押したときだけ、稼働条件と勤務地のボタン（下書き）に入れる（PR302・PR304） |
| | 開いたとき・「検索する」・並び順の変更・ページ送り | ⑱ GET /api/student/job_postings | 募集の一覧。画面の URL の `?` の後ろ（条件・並び順・ページ）を、そのまま渡す。並び順を変えても、条件は変わらない（PR302） |
| | 詳細を見る | `/student/job_postings/[id]` | 画面の移動だけ |
| S3 募集管理 | 画面の URL | `/student/candidacies` | `?status=`（タグで絞る） |
| | 開いたとき・タグで絞る・ページ送り | ㉞ GET /api/student/candidacies | 応募済み・マッチ済みの募集 |
| | 詳細を見る | `/student/job_postings/[id]` | 画面の移動だけ |
| S4 スカウト管理 | 画面の URL | `/student/scouts` | |
| | 開いたとき・ページ送り | ㉟ GET /api/student/scouts | まだマッチしていないスカウト |
| | 詳細を見る | `/student/job_postings/[id]` | 画面の移動だけ |
| S5 メッセージ管理 | 画面の URL | `/student/messages` | `?company_id=`（開くスレッド）、`?page=`（スレッド一覧のページ） |
| | 開いたとき・ページ送り | ㊴ GET /api/student/message_threads | スレッド一覧 |
| | 開いたとき（company_id があるとき）・スレッドを選んだとき | ㊵ GET /api/student/companies/:id/message_thread | その企業とのチャット |
| | マッチできるスカウトがあるとき | ⑦ GET /api/options | 応募理由の選択肢 |
| | マッチする（㊵ の matchable_scouts の行ごと。マッチ理由を選ぶ） | ㉜ POST /api/student/candidacies/:id/match | スカウトにマッチする（PR222・PR223）。終わったら㊵を取り直す |
| | 送信 | ㊶ POST /api/student/companies/:id/message_thread/messages | メッセージを送る |
| | 企業名・アイコン（【仕上げ】） | `/student/companies/[id]` | 画面の移動だけ |
| S6 募集詳細 | 画面の URL | `/student/job_postings/[id]` | |
| | 開いたとき | ⑦ GET /api/options | 表示名、応募理由の選択肢、5軸の説明 |
| | 開いたとき | ⑲ GET /api/student/job_postings/:id | 募集の中身、自分の状態、自分の働き方の好み（カルチャーグラフに重ねる） |
| | 応募する（応募理由を選ぶ） | ㉛ POST /api/student/candidacies | 応募する |
| | 応募の完了後 | ㉝ GET /api/student/job_postings/:id/similar_job_postings | 「応募が完了しました」のポップアップの「この募集に似た募集」。ポップアップを開いているときだけ取る。スカウトへのマッチでは開かない |
| | ポップアップの募集 | `/student/job_postings/[その募集id]` | 画面の移動だけ。移る前にポップアップを閉じる |
| | マッチする（マッチ理由を選ぶ） | ㉜ POST /api/student/candidacies/:id/match | スカウトにマッチする |
| | この企業とのメッセージ（⑲ の has_message_thread が true のとき） | `/student/messages?company_id=[id]` | 画面の移動だけ |
| | 会社名 | `/student/companies/[id]` | 画面の移動だけ |
| | この募集に近いプチ職業体験の講座名 | `/student/job_trials/[id]` | 画面の移動だけ（順19。中身は ⑲ の job_trials） |
| S7 企業詳細 | 画面の URL | `/student/companies/[id]` | |
| | 開いたとき | ⑦ GET /api/options | 業界・事業形態・人数の表示名 |
| | 開いたとき | ⑳ GET /api/student/companies/:id | 企業のプロフィールと掲載中の募集 |
| | 募集を押す | `/student/job_postings/[id]` | 画面の移動だけ |
| | この企業とのメッセージ（⑳ の has_message_thread が true のとき） | `/student/messages?company_id=[id]` | 画面の移動だけ |
| S8 ログイン | 画面の URL | `/student/login` | |
| | 開いたとき | ③ GET /api/me | C8 と同じ |
| | ログイン | ① POST /api/session | → return_to、なければ `/student/job_postings`（企業アカウントなら `/company/job_postings`） |
| | 新規登録はこちら | `/student/signup` | 画面の移動だけ |
| | 企業の方はこちら | `/company/login` | 画面の移動だけ |
| S9 新規登録 | 画面の URL | `/student/signup` | |
| | 開いたとき | ⑦ GET /api/options | 選択肢、5軸の説明 |
| | ステップ1から進むとき | ④ POST /api/email_checks | メールアドレスの重複を確認 |
| | 登録する | ⑥ POST /api/student_registrations | アカウントとプロフィールを作り、自動でログイン |
| | 登録の直後（アイコンを選んでいたとき） | ⑰ POST /api/student/profile/icon | → `/student/job_postings` |
| | すでにアカウントをお持ちの方はこちら | `/student/login` | 画面の移動だけ |
| S11 プチ職業体験一覧 | 画面の URL | `/student/job_trials` | 順18 |
| | 開いたとき | ⑦ GET /api/options | 中分類・工程の名前 |
| | 開いたとき | ㊺ GET /api/student/job_trials | 講座の一覧と、自分が修了済みか |
| | 講座を押す | `/student/job_trials/[id]` | 画面の移動だけ |
| S12 プチ職業体験 | 画面の URL | `/student/job_trials/[id]` | 順18。講座と自己分析を1つの URL の中のステップで進む（PR388） |
| | 開いたとき | ⑦ GET /api/options | 中分類・工程の名前、理由の種類の表示名 |
| | 開いたとき | ㊻ GET /api/student/job_trials/:id | 講座の中身（正解と解説は含まない）と、自分の自己分析（なければ null） |
| | 問題に答える | ㊼ POST /api/student/job_trial_hurdles/:id/check | 正否と、選んだ選択肢の解説。正解なら「次へ」を押せるようにする |
| | 自己分析を送る | ㊽ PUT /api/student/job_trials/:id/self_analysis | → `/student/job_trials` |

### 16-3. 窓口ごとの詳細

#### 16-3-1. 窓口の一覧

| # | メソッド | URL | 使える人 | 画面・操作 | 段階タグ |
| --- | --- | --- | --- | --- | --- |
| ① | POST | /api/session | 誰でも | C8・S8 ログイン | コア（回数制限は仕上げ） |
| ② | DELETE | /api/session | 誰でも | ヘッダー ログアウト | コア |
| ③ | GET | /api/me | 誰でも（未ログインは 401） | 全画面 ログインの確認、ヘッダー | コア（未読件数は強み） |
| ④ | POST | /api/email_checks | 誰でも | C9・S9 メールアドレスの確認 | コア |
| ⑤ | POST | /api/company_registrations | 誰でも | C9 登録する | コア |
| ⑥ | POST | /api/student_registrations | 誰でも | S9 登録する | コア |
| ⑦ | GET | /api/options | 誰でも | 選択肢とマスタ | コア |
| ⑧ | GET | /api/company/profile | 企業 | C1 表示、C3 | コア |
| ⑨ | PATCH | /api/company/profile | 企業 | C1 保存 | コア |
| ⑩ | POST | /api/company/profile/icon | 企業 | C1・C9 アイコン | コア |
| ⑪ | GET | /api/company/job_postings | 企業 | C2 表示、C4・C5 の募集の名前 | コア（件数は仕上げ） |
| ⑫ | GET | /api/company/job_postings/:id | 企業 | C3 表示、C5 募集を選んだとき | コア |
| ⑬ | POST | /api/company/job_postings | 企業 | C3 保存（新規） | コア |
| ⑭ | PATCH | /api/company/job_postings/:id | 企業 | C3 保存（編集・状態の変更） | コア |
| ⑮ | GET | /api/student/profile | 学生 | S1 表示、S2 | コア |
| ⑯ | PATCH | /api/student/profile | 学生 | S1 保存 | コア |
| ⑰ | POST | /api/student/profile/icon | 学生 | S1・S9 アイコン | タグ未付与 |
| ⑱ | GET | /api/student/job_postings | 学生 | S2 検索 | コア（おすすめ順は強み） |
| ⑲ | GET | /api/student/job_postings/:id | 学生 | S6 表示 | コア（自分の働き方の好みは強み） |
| ⑳ | GET | /api/student/companies/:id | 学生 | S7 表示 | コア |
| ㉑ | GET | /api/company/candidacies | 企業 | C4 表示 | コア（隠す切り替えは強み、未返信タグは仕上げ） |
| ㉒ | GET | /api/company/students | 企業 | C5 検索 | コア（推薦検索・おすすめ順は強み、タグと最終活動の目安は仕上げ） |
| ㉓ | GET | /api/company/students/:id | 企業 | C6 表示 | コア（比較・応募理由は強み、最終活動の目安は仕上げ） |
| ㉔ | POST | /api/company/scouts | 企業 | C6 スカウトをする | コア |
| ㉕ | GET | /api/company/students/:id/similar_students | 企業 | C6 スカウト後のポップアップ | 強み |
| ㉖ | POST | /api/company/candidacies/:id/match | 企業 | C6 マッチする | コア |
| ㉗ | POST | /api/company/candidacies/:id/decline | 企業 | C6 見送る | 強み |
| ㉘ | POST | /api/company/candidacies/:id/undo_decline | 企業 | C6 見送りを取り消す | 強み |
| ㉙ | POST | /api/company/candidacies/:id/pass | 企業 | C6 合格として保存 | 強み |
| ㉚ | POST | /api/company/candidacies/:id/fail | 企業 | C6 不合格として保存 | 強み |
| ㉛ | POST | /api/student/candidacies | 学生 | S6 応募する | コア |
| ㉜ | POST | /api/student/candidacies/:id/match | 学生 | S6 マッチする | コア |
| ㉝ | GET | /api/student/job_postings/:id/similar_job_postings | 学生 | S6 応募完了のポップアップ | 強み |
| ㉞ | GET | /api/student/candidacies | 学生 | S3 表示 | コア（タグでの絞り込みは仕上げ） |
| ㉟ | GET | /api/student/scouts | 学生 | S4 表示 | コア |
| ㊱ | GET | /api/company/message_threads | 企業 | C7 スレッド一覧 | コア |
| ㊲ | GET | /api/company/students/:id/message_thread | 企業 | C7 チャット | コア（マッチしている募集は仕上げ） |
| ㊳ | POST | /api/company/students/:id/message_thread/messages | 企業 | C7 送信 | コア |
| ㊴ | GET | /api/student/message_threads | 学生 | S5 スレッド一覧 | コア |
| ㊵ | GET | /api/student/companies/:id/message_thread | 学生 | S5 チャット | コア（マッチしている募集は仕上げ） |
| ㊶ | POST | /api/student/companies/:id/message_thread/messages | 学生 | S5 送信 | コア |
| ㊷ | GET | /api/company/notifications | 企業 | C10 表示 | 強み |
| ㊸ | POST | /api/company/notifications/:id/read | 企業 | C10 通知を押す | 強み |
| ㊹ | POST | /api/company/notifications/read_all | 企業 | C10 すべて既読にする | 強み |
| ㊺ | GET | /api/student/job_trials | 学生 | S11 表示 | 後付け |
| ㊻ | GET | /api/student/job_trials/:id | 学生 | S12 表示 | 後付け |
| ㊼ | POST | /api/student/job_trial_hurdles/:id/check | 学生 | S12 問題に答える | 後付け |
| ㊽ | PUT | /api/student/job_trials/:id/self_analysis | 学生 | S12 自己分析を送る | 後付け |
| ㊾ | GET | /api/company/job_trials/:id | 企業 | C11 表示 | 後付け |

#### 16-3-2. 共通の決まりと、繰り返し出てくる形

すべての窓口に共通するエラー（各窓口の「主なエラー」では省く）

- GET 以外：403（CSRF の合言葉がない・違う。16-1-7）
- `/api/company/`・`/api/student/` の窓口：401（未ログイン）、403（種別が違う）
- 見てよい範囲の外の番号：404（16-1-10）

**形A：ログイン中の人**（③の返事。①・⑤・⑥の返事も同じ）

```json
{
  "id": 1,
  "role": "company",
  "name": "株式会社サンプル",
  "icon_url": "/rails/active_storage/blobs/.../icon.png",
  "unread_notifications_count": 3
}
```

| 項目 | 説明 |
| --- | --- |
| id | ログイン情報（users）の番号 |
| role | `"company"` または `"student"` |
| name | 企業なら会社名、学生なら名前 |
| icon_url | アイコンの URL。未登録なら null（画面側で既定の画像を出す） |
| unread_notifications_count | 企業なら未読の通知の件数（自分宛ての read_at が空の通知の数。未読がなければ 0）。学生なら null（学生には通知がないため）。数え方は `User#unread_notifications_count` の1か所で、ログイン（①）・新規登録（⑤⑥）の返事にも入る（順15） |

**形B：学生向けの募集の行**（⑱・⑳・㉝・㉞・㉟）

```json
{
  "id": 12,
  "title": "自社サービスのバックエンド開発インターン",
  "is_open": true,
  "company": { "id": 3, "name": "株式会社サンプル", "icon_url": null },
  "industry_ids": [1],
  "business_type_ids": [2],
  "main_job_middle_category_ids": [2],
  "related_job_middle_category_ids": [3],
  "main_work_process_ids": [5],
  "involved_work_process_ids": [1, 2],
  "prefecture_id": 13,
  "work_style": "partial_remote",
  "hourly_wage": 1500,
  "min_work_days_per_week": 2,
  "min_work_hours_per_day": 4,
  "min_duration_months": 3,
  "published_at": "2026-09-20T10:00:00.000+09:00"
}
```

- is_open：掲載中なら true。false なら、画面は「募集終了」と表示する（非公開か終了かの区別は、学生に見せない）
- industry_ids・business_type_ids：**その募集の**業界・事業形態。企業プロフィールの値は返さず、募集が空欄なら空の配列（本書5-8）
- company.icon_url も返す。どの画面でアイコンを出すかは Phase 6 で決める（本書10-2）
- industry_ids・business_type_ids・main_work_process_ids・involved_work_process_ids は、順9 で足した（順4 では返していなかった）
- Rails では部品（partial。`app/views/api/student/job_postings/_job_posting.json.jbuilder`）1つにまとめ、使う窓口すべてで使い回す
  - 行の関連（会社とアイコン、職種、工程、業界、事業形態）は、呼ぶ側が `Api::Student::JobPostingsController::ROW_ASSOCIATIONS` でまとめて読んでおく（N+1問題を避けるため）

**形C：企業向けの学生の行**（㉒・㉕）

```json
{
  "id": 5,
  "name": "山田 太郎",
  "icon_url": null,
  "grade": "undergrad_3",
  "graduation_year": 2028,
  "activity_status": "job_hunting",
  "interested_job_middle_category_ids": [2, 3],
  "skills": [{ "technology_id": 5, "other_name": null, "level": "v2" }],
  "work_days_per_week": 3,
  "work_hours_per_day": 4,
  "duration_months": 6,
  "last_active_range": "within_3_days"
}
```

- last_active_range：最終活動の目安。`within_3_days`（3日以内）、`within_7_days`（7日以内）、`within_30_days`（30日以内）、`over_30_days`（30日より前。C6 だけで使う）のどれか
  - 日付そのものは返さない。設計が「目安」を出す形であり、学生の行動を細かく見せすぎないため
- 行には、スカウトするかどうかの判断に使う情報を絞って載せる。大学名などは C6 で見る
  - 最終活動日が空（一度もログインしていない）学生は null。「30日より前」と返すと、以前は活動していたように読めるため。画面は null なら何も出さない（PR335）。㉒・㉕ は30日以内に活動した学生だけを出すので、実際に null や over_30_days が来るのは㉓ だけ
  - 計算は `StudentProfile#last_active_range`（境目の日数は `StudentProfile::LAST_ACTIVE_RANGES`）。ちょうど3日前は「3日以内」、ちょうど30日前は「30日以内」（検索の対象の境目とそろえる。PR216）。表示名は⑦ の enums.last_active_range
  - ログイン情報（users）を読むので、呼ぶ側が `Api::Company::StudentsController::ROW_ASSOCIATIONS`（`:user` を含む）でまとめて読んでおく
- Rails では部品（partial。`app/views/api/company/students/_row.json.jbuilder`）1つにまとめる
- 作る順：順6 で、last_active_range 以外を作った。last_active_range は【仕上げ】の順16 で足した

**形D：企業から見た、募集ごとのやりとりの状態**（㉓の job_postings の要素（㉓ ではこれに comparison を加える）。㉔・㉖〜㉚の返事）

```json
{
  "id": 12,
  "title": "自社サービスのバックエンド開発インターン",
  "status": "published",
  "candidacy": {
    "id": 34, "origin": "application", "status": "unmatched",
    "tag": "pending_application",
    "reasons": ["business", "culture"], "matched_at": null
  },
  "available_actions": ["match", "decline"]
}
```

- candidacy：その学生とのやりとり。なければ null
- candidacy.reasons：応募理由・マッチ理由（C6 の12個の一覧で、選んだ理由に ✓ を付けるのに使う。PR255）。値は応募理由の英語の名前（本書8-5 candidacy_reasons）。スカウトしただけでまだマッチしていなければ空の配列（マッチ理由は学生がマッチしたときに選ぶ）
  - 順10 で足した。㉓ では、やりとりと一緒に応募理由をまとめて読む（N+1問題を避ける）
- candidacy.tag：やりとりの状態のタグ。**Rails が計算する**。`pending_application`（未対応応募）、`scouted`（スカウト済み）、`matched`（マッチ）、`declined`（見送り）、`passed`（合格）、`failed`（不合格）のどれか
  - 日本語は⑦の enums の candidacy_tag。㉑・㉒ と同じ値を使う
  - 「未対応応募」は発生元と状態の組み合わせに付けた名前で、どの選択肢にも存在しない言葉なので、画面側では組み立てない（16-1-9）
- available_actions：今この募集で押せるボタン。`scout`、`match`、`decline`、`undo_decline`、`pass`、`fail` のどれか
  - 画面は、ここに入っているボタンだけを出す。判定は Rails の1か所（`Candidacy.available_actions_for`）で行う。**正は本書17-2-1 の状態遷移表**（窓口ごとの条件は16-3-6）
  - 窓口ができている操作だけを返す（PR202）。順5 で match、順6 で scout（判定は `Candidacy.can_scout?`。やりとりがなく、募集が掲載中）、順11 で decline・undo_decline・pass・fail を足した（判定は `can_decline?`・`can_undo_decline?`・`can_mark_passed?`・`can_mark_failed?`）。並びは上の6つの順
  - 例：未対応応募（掲載中）は `["match", "decline"]`、スカウト済みは `["decline"]`、見送り（応募由来・掲載中）は `["match", "undo_decline"]`、マッチは `["pass", "fail"]`、合格は `["fail"]`、不合格は `["pass"]`
  - メッセージのボタンは募集ごとではなく相手ごとなので、ここには入れない。㉓ の has_message_thread を使う（本書17-2-3）

**形E：学生から見た、募集とのやりとりの状態**（⑲の一部。㉛・㉜の返事）

```json
{ "my_status": "applied", "my_candidacy_id": 34 }
```

- my_status：`none`（関係なし）、`applied`（応募済み）、`scouted`（スカウトあり）、`matched`（マッチ済み）のどれか。**Rails が計算する**。本書8-7 の計算のとおり（見送り・合格・不合格は見せない）
  - 日本語は⑦の enums の my_status
- my_candidacy_id：やりとりの番号。関係がなければ null

#### 16-3-3. まとまり1：共通（ログイン、新規登録、選択肢）

**① POST /api/session（ログイン）**

- 画面・操作：C8・S8 のログイン
- 使える人：誰でも

| 送るもの | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| email | 文字列 | ○ | 前後の空白を除き、小文字にそろえてから照合する（保存するときと同じ扱い。本書8-5 users） |
| password | 文字列 | ○ | |

- 返すもの：200、形A。Cookie にセッションが入る
- 主なエラー
  - 401「ログインができません」（どちらが違うかは出さない。本書17-3-1）
  - 429「しばらくしてからお試しください」（3分間に10回まで。Rails 8 の認証ジェネレーターに最初から入っている設定）
- 段階タグ：【コア】（429 は【仕上げ】）

**② DELETE /api/session（ログアウト）**

- 画面・操作：ヘッダーのログアウト
- 使える人：誰でも
- 送るもの：なし
- 返すもの：204。セッションを消す
  - ログインしていなくても 204 を返す（何度押しても同じ結果にし、画面側でエラーを考えなくて済むようにする）
- 画面側：成功したら、その種別のログイン画面（C8・S8）へ移る
- 段階タグ：【コア】

**③ GET /api/me（ログイン中の人）**

- 画面・操作：全画面を開いたとき（16-1-6）、ヘッダーの表示
- 使える人：誰でも
- 返すもの：200、形A
- 主なエラー：401（未ログイン。auth 側の画面では普通の状態として扱う）
- 401 の返事にも CSRF-TOKEN の Cookie を付ける（16-1-7）
- ログイン中なら、この呼び出しでも最終活動日を記録する（16-1-12）
- 段階タグ：【コア】（unread_notifications_count は C10 と同じ【強み】）

**④ POST /api/email_checks（メールアドレスの確認）**

- 画面・操作：C9・S9 のステップ1から進むとき
- 使える人：誰でも
- 送るもの：email（文字列、必須）
- 返すもの：204（使えるメールアドレスのとき）
- 主なエラー：422（空、形式が正しくない、または登録済み）。例：`"errors": { "email": ["メールアドレスはすでに登録されています"] }`
- 読むだけの処理だが、POST にする。GET だとメールアドレスが URL に載り、サーバーの記録に残りやすいため
- この窓口で確かめるのはメールアドレスだけ。パスワードの長さや確認用との一致は、画面側がその場で確かめ、最後の「登録する」で Rails が改めて確認する（本書17-3-2）
- 判定は、アカウントのモデル（User）の決まりをそのまま使う。アカウントを組み立てて（保存しない）検証し、メールアドレスの誤りだけを返す（大文字や前後の空白をそろえてから比べるのも、保存するときと同じ）
- 企業・学生のどちらのアカウントとも重ならないメールアドレスだけが使える（users は種別をまたいで1つの表）
- 段階タグ：【コア】

**⑤ POST /api/company_registrations（企業の新規登録）**

- 画面・操作：C9 の最後の「登録する」
- 使える人：誰でも
- 送るもの：全ステップの入力を1つの JSON にまとめる。項目の名前はテーブルの列名（本書8-5）と同じ

| ステップ | 項目 | 型 | 必須 |
| --- | --- | --- | --- |
| 1 | email | 文字列 | ○ |
| 1 | password | 文字列 | ○（本書5-11） |
| 1 | password_confirmation | 文字列 | ○（password と一致すること） |
| 1 | name（会社名） | 文字列 | ○ |
| 1 | terms_agreed（利用規約・プライバシーポリシーへの同意） | 真偽値 | ○（true であること。保存はしない） |
| 2 | industry_ids（業界） | 数値の配列 | |
| 2 | business_type_ids（事業形態） | 数値の配列 | |
| 2 | employee_size（人数） | 選択肢の名前 | |
| 2 | business_description（事業内容） | 文字列 | |
| 2 | about（どんな会社か） | 文字列 | |

- 必須の○は、データベースで空欄を許さない項目と、登録に欠かせない項目だけ。ステップ2は空欄のまま登録できる（本書17-3-5）
- 受け取ってよい項目：アカウントの3つ（email、password、password_confirmation）と、⑨ 企業プロフィールの保存と同じ一覧。role（種別）や user_id などを送られても捨てる（この窓口で学生のアカウントは作れない）
  - 一覧は⑨のコントローラーの定数（`PERMITTED_PARAMS`）1か所に書き、⑤もそれを使う。項目を足したときに、登録の側だけ足し忘れないようにするため
  - password_confirmation が送られていなければ、空として扱い「パスワード（確認）とパスワードの入力が一致しません」にする
- 返すもの：201、形A（①ログインと同じテンプレート）。自動でログインした状態になる
- 主なエラー：422（項目ごと。登録済みのメールアドレスを含む。アカウントとプロフィールの誤りを一度にすべて返す）。画面側は、エラーのある項目を含む最初のステップに戻して表示する
- 処理：users、sessions（自動でログインした状態にする）、company_profiles、company_industries、company_business_types を1つのトランザクションで作る
  - 処理は登録のモデル（フォームオブジェクト。`CompanyRegistration`、親は `Registration`）にまとめる（PR226。本書9-2）
  - アイコンは含めない。登録が成功した直後に、画面が⑩へ送る
  - アイコンの保存に失敗しても、登録は取り消さない。画面は「アイコンを保存できませんでした。あとで会社情報から登録してください」と［募集一覧へ進む］を出す（PR229。本書6-5 C9）
- 裏側のジョブ：なし
- 段階タグ：【コア】（terms_agreed の確認は【仕上げ】）
- 作る順：順8 で、terms_agreed 以外を作った。terms_agreed は【仕上げ】だが、同意チェックの画面と一緒に、今回の開発では作らない（議事録28。PR333。⑥ も同じ）

**⑥ POST /api/student_registrations（学生の新規登録）**

- 画面・操作：S9 の最後の「登録する」
- 使える人：誰でも
- 送るもの：全ステップの入力を1つにまとめる。student_profiles の列はそのままの名前で、付属テーブルは次の名前の配列で送る

| ステップ | 項目 | 必須 |
| --- | --- | --- |
| 1 | email、password、password_confirmation、terms_agreed（ここまで⑤と同じ）、name（氏名） | ○（すべて） |
| 2 | **activity_status（活動状況）** | **○** |
| 2 | university_id、university_other_name（一覧にない大学の名前）、faculty_id、department_id、grade、graduation_year、prefecture_id | |
| 3 | interested_industry_ids（興味のある業界）、interested_job_middle_category_ids（興味のある職種）、job_hunting_prefecture_ids（就活希望エリア） | |
| 4 | skills（プログラミング歴）、links（外部リンク）、certifications（資格） | |
| 5 | work_days_per_week、work_hours_per_day、duration_months、available_from、can_full_remote、can_partial_remote、can_onsite、commutable_prefecture_ids（出社できる都道府県）、work_note | |
| 6 | personality_pace、personality_novelty、personality_collaboration、personality_decision、personality_atmosphere | |
| 7 | self_pr_strength、self_pr_weakness、self_pr_future | |

送り方の例（一部）

```json
{
  "email": "taro@example.com",
  "password": "********",
  "password_confirmation": "********",
  "terms_agreed": true,
  "name": "山田 太郎",
  "grade": "undergrad_3",
  "interested_job_middle_category_ids": [2, 3],
  "skills": [
    { "technology_id": 5, "other_name": null, "years": 1.5, "level": "v2" },
    { "technology_id": null, "other_name": "Elm", "years": 0.5, "level": "v1" }
  ],
  "links": [{ "url": "https://github.com/example", "title": "GitHub" }],
  "certifications": ["基本情報技術者"],
  "available_from": "2026-10-01",
  "can_onsite": false,
  "personality_pace": -1
}
```

- 決まり
  - **必須はステップ1のすべてと、ステップ2の activity_status（活動状況）だけ**（本書17-3-5）。これ以外は省いてよい
  - 省いた項目は空欄か既定値（勤務形態の3つは true、働き方の好み（性格）は 0）になる
  - skills の各要素は、technology_id か other_name のどちらか一方だけ（本書8-5 の CHECK と同じ）。level は必須
  - university_id と university_other_name は、両方同時には送れない（どちらか一方か、どちらも空。本書8-5 の CHECK と同じ）
  - available_from は、月の1日の日付で送る
  - 数値や選択肢の範囲は、テーブル定義（本書8-5）と⑦に従う
- 返すもの・主なエラー：⑤と同じ
- 受け取ってよい項目：アカウントの3つと、⑯ 学生プロフィールの保存と同じ一覧（⑯のコントローラーの定数 `PERMITTED_PARAMS`。⑤と同じ考え方）。プログラミング歴の行の誤りは、⑯と同じ名前（skills[0].years）と文で返す
- 処理：users、sessions（自動でログインした状態にする）、student_profiles、付属テーブル7つを1つのトランザクションで作る。処理は `StudentRegistration`（親は `Registration`）。アイコンは⑤と同じ扱いで、⑰へ送る
- 推薦の集計：同じトランザクションで、その学生の student_recommendation_stats の行（件数0と項目数）を作る。裏側のジョブはない（本書7-5）【強み】
- 段階タグ：【コア】
- 作る順：順8 で、今ある列とテーブルの項目（⑯と同じ）を作った
  - personality_ の5つは、列を作った順9 で足した（⑯ の `PERMITTED_PARAMS` に足したので、この窓口も受け取る。S9 のステップ6 もそのとき差し込んだ。PR225）
  - interested_industry_ids は、表を順10 で前倒しして作ったときに足した（⑯ の `PERMITTED_PARAMS` に足したので、この窓口も受け取る。PR254）
  - job_hunting_prefecture_ids、links、certifications は、表を作った【仕上げ】の順17 で足した（⑯ の `PERMITTED_PARAMS` に足したので、この窓口も受け取る）。terms_agreed は今回の開発では作らない（⑤ と同じ）
  - 推薦の集計の行を作る処理は順12 で足した（書き込みの `StudentProfile#write_profile!` の中。⑯ の保存と同じ場所）

**⑦ GET /api/options（選択肢とマスタ）**

- 画面・操作：選択肢や表示名を使うすべての画面（16-2）
- 使える人：誰でも（ログイン前の登録画面でも使うため）
- ページ分けしない。並び順は、マスタの position（表示順）のとおり。都道府県は position を持たず、番号（JIS コード。北から南の順になる）の順。大学も position を持たず、学校コードの順（コードは「F1＋都道府県番号＋設置区分（1国・2公・3私）…」の形なので、北から南へ、同じ都道府県の中では国立→公立→私立の順になる）

| まとまり | 中身 |
| --- | --- |
| enums | 画面に出す選択肢すべて：grade、activity_status、employee_size、skill_level、job_posting_status、work_style、purpose、hiring_possibility、candidacy_reason、candidacy_status、**candidacy_tag**、**my_status**、technology_category、last_active_range、growth_reason |
| work_conditions | 稼働条件の数値の選択肢（週の日数、1日の時間、継続期間。本書5-6） |
| culture_axes | 性格・カルチャーの5軸の名前と、両端の短い名前・説明（本書5-5） |
| masters | 職種（大分類の中に中分類）、工程、技術、業界、事業形態、都道府県、大学、学部（中に学科）、プチ職業体験の講座（job_trials） |

```json
{
  "enums": {
    "grade": [
      { "value": "undergrad_1", "label": "学部1年" },
      { "value": "undergrad_2", "label": "学部2年" }
    ]
  },
  "work_conditions": {
    "work_days_per_week": [1, 2, 3, 4, 5],
    "work_hours_per_day": [2, 3, 4, 5, 6, 8],
    "duration_months": [1, 3, 6, 9, 12]
  },
  "culture_axes": [
    {
      "key": "pace", "name": "進め方",
      "left_label": "スピード", "left_description": "まず動くものを作って見せ、直しながら進める",
      "right_label": "緻密さ", "right_description": "仕様や設計を固めてから作り始める"
    }
  ],
  "masters": {
    "job_major_categories": [
      {
        "id": 1, "code": "1", "name": "Web・アプリ開発", "description": "…",
        "job_middle_categories": [
          { "id": 1, "code": "1-1", "name": "フロントエンド", "description": "…" }
        ]
      }
    ],
    "work_processes": [
      { "id": 1, "name": "企画・要件定義" }
    ],
    "technologies": [{ "id": 1, "name": "Ruby", "category": "language" }],
    "industries": [{ "id": 1, "name": "EC・小売" }],
    "business_types": [{ "id": 1, "name": "自社サービス（個人向け）" }],
    "prefectures": [{ "id": 13, "name": "東京都" }],
    "universities": [{ "id": 1, "name": "〇〇大学" }],
    "faculties": [
      { "id": 1, "name": "工学部", "departments": [{ "id": 1, "name": "情報工学科" }] }
    ]
  }
}
```

- 大学を全件入れても数十KB程度。大学が多くて選びにくい場合は、画面側で文字を入れて絞り込む（全件を持っているので画面側だけでできる）
- 学生に見せない項目の選択肢（purpose、hiring_possibility、candidacy_status の declined／passed／failed）も含まれるが、**値そのものは返さない**ので問題にならない。窓口を種別ごとに分けないのは、「一度取ったら使い回す」（16-1-9）を保つため
- 段階タグ：【コア】
- 作る順：中身は、使う機能を作る順で足していく
  - 順1〜順4：人数・業界・事業形態、募集に使うもの（職種・技術・都道府県・稼働条件の数値・募集状態・勤務形態・技術の区分）、学生プロフィールに使うもの（学年・活動状況・プログラミング歴のレベル・大学・学部と学科）
  - 順5（応募 → 企業がマッチ）：candidacy_reason（12個。画面に出す順）、my_status（4つ）、candidacy_tag（6つ）。candidacy_status は、状態そのものを表示する画面ができたときに足す
  - 順9（性格・カルチャー・工程の入力）：culture_axes（5軸）、masters の work_processes（番号と名前だけ。上流 → 下流の表示順）
  - 順16（【仕上げ】）：last_active_range（4つ。値の一覧は `StudentProfile::LAST_ACTIVE_RANGE_VALUES`、表示名は `config/locales/ja.yml` の `enums.student_profile.last_active_range`）
  - 順18（プチ職業体験）：growth_reason（自己分析の2-2 の理由の種類。5つ。本書12-4）、masters の job_trials（講座の一覧。`{ "id": 1, "title": "テスト設計", "job_middle_category_id": 16 }` の形で、表示順）。講座もマスタなので、業界や技術と同じくここで配る。C3 の選ぶ欄（順19）でも使う
    - growth_reason だけ、value・label に加えて detail_question（その理由を選んだときの 2-3 の深掘りの問い）を返す：`{ "value": "curiosity", "label": "もっと深く知りたくなった、…", "detail_question": "そのハードルの楽しさは、…" }`。問いの文は理由の種類ごとに決まるので、画面側に対応表を持たせない。S12 の入力、C6 のポップアップの小見出し、C11 の問いの一覧で使う（PR397）。文言は `config/locales/ja.yml` の `self_analysis.detail_questions`
- culture_axes
  - 軸の並びは、Rails の検証と同じ定数（`app/models/concerns/culture_axes.rb` の `CultureAxes::AXES`）から作る。軸の名前・両端の短い名前・説明の文言は `config/locales/ja.yml` の `culture_axes`（本書5-5 の文をそのまま）
  - 学生の働き方の好み（S1・S9）と、募集のカルチャーグラフ（C3・S6）で共通。画面側は軸ごとの文言を持たない
- work_processes：共通段階・職種の大分類との対応・「企画・設計から関われる」の印は返さない（データベースに持たない。本書8-5 G。PR239・PR240・PR252）

#### 16-3-4. まとまり2：企業のプロフィールと募集

**⑧ GET /api/company/profile（自社のプロフィール）**

- 画面・操作：C1 の表示。C3 の会社名と、空欄のときの既定値
- 使える人：企業

```json
{
  "name": "株式会社サンプル",
  "industry_ids": [1, 3],
  "business_type_ids": [2, 3],
  "employee_size": "size_10_49",
  "business_description": "受託開発と自社サービスの運営",
  "about": "エンジニアが半数を占める、30人ほどの会社です",
  "icon_url": null
}
```

- 段階タグ：【コア】

**⑨ PATCH /api/company/profile（自社のプロフィールの保存）**

- 画面・操作：C1 の保存
- 送るもの：⑧と同じ項目（icon_url は除く）。フォームの全項目を送る。industry_ids・business_type_ids は、送った内容でまるごと置き換える
- 必須：name だけ（本書5-9。ほかはすべて任意）
- 処理：company_profiles、company_industries、company_business_types を1つのトランザクションで保存する（本書9-2）
- 返すもの：200、⑧と同じ形
- 主なエラー：422
- 推薦の処理：なし。企業プロフィールの業界・事業形態は近さの計算に使わないため（本書7-5）
- 段階タグ：【コア】

**⑩ POST /api/company/profile/icon（企業のアイコン）**

- 画面・操作：C1 のアイコンの登録・差し替え（保存のとき、⑨の成功後に続けて送る）。C9 の登録の直後
- 送るもの：multipart/form-data の `icon`（ファイル1つ）
- 受け付ける形式：PNG・JPEG・WebP で、2MB まで（本書9-3）
- 返すもの：200。`{ "icon_url": "..." }`
- 主なエラー：422（形式やサイズが合わない）
- 差し替える前の画像は消す（Active Storage の標準の動き）
- アイコンを消して「なし」に戻す窓口は作らない（差し替えはできる）
- 段階タグ：【コア】（C1 の全項目と同じ）

**⑪ GET /api/company/job_postings（自社の募集の一覧）**

- 画面・操作：C2 の表示。C4 のタブ、C5 の募集の選択肢で、募集の名前を並べるときにも使う
- 自社の全募集（非公開・終了も含む）を返す。ページ分けしない
- 並び順：最終更新の新しい順

```json
{
  "items": [
    {
      "id": 12,
      "title": "自社サービスのバックエンド開発インターン",
      "status": "published",
      "published_at": "2026-09-20T10:00:00.000+09:00",
      "updated_at": "2026-09-21T18:00:00.000+09:00",
      "pending_application_count": 3
    }
  ]
}
```

| 項目 | 画面に出すもの |
| --- | --- |
| title、status | タイトル、状態（非公開／掲載中／終了） |
| published_at | 最初に掲載した日（一度も掲載していなければ null） |
| updated_at | 最終更新日。企業が最後に保存した日時（⑬⑭で保存に成功したら、中身が変わっていなくても更新する） |
| pending_application_count | 未対応の応募の件数。発生元が応募で、状態が未マッチのやりとりを数える（C4 の「未対応応募」タグと同じ数え方） |

- 理由
  - 行に出す情報は、企業が一覧で判断したいこと（どの募集が公開中か、どこに対応待ちがあるか）に絞った
  - 件数を「未対応の応募」1つにしたのは、「次に何をすべきか」に直結するため。総応募数や返信率などは、後付けの企業ダッシュボード（本書4-4）で扱う
  - 1社の募集は多くても数十件で、C4・C5・C6 でも全件の名前が必要なため、ページ分けしない
- 段階タグ：【コア】（pending_application_count は【仕上げ】）
  - title、status、published_at、updated_at は【コア】で返す（Phase 6 の順2）。列をそのまま返すだけで手間がかからず、状態が見えないとどれが掲載中か分からず一覧として使えないため
  - pending_application_count は、【仕上げ】の順16 で足した。数え方は `Candidacy.pending_application`（形D・㉑ の tag の `pending_application` と同じ条件）。全募集ぶんを募集の番号ごとに1回の問い合わせで数え、0件の募集は 0 を返す

**⑫ GET /api/company/job_postings/:id（自社の募集1件）**

- 画面・操作：C3 の表示（編集）。C5 で募集を選んだとき（稼働条件を取る）
- 返すもの：テーブル定義（本書8-5 job_postings）の列を、学生に見せない項目も含めてすべて返す（company_profile_id は除く）。例（一部）：

```json
{
  "id": 12,
  "status": "published",
  "published_at": "2026-09-20T10:00:00.000+09:00",
  "title": "自社サービスのバックエンド開発インターン",
  "about": null,
  "internship_details": "…",
  "min_work_days_per_week": 2,
  "start_month": null,
  "work_style": "partial_remote",
  "hourly_wage": 1500,
  "culture_pace": -1,
  "requirements": "…",
  "purpose": "both",
  "hiring_possibility": "possible",
  "target_grades": ["undergrad_3", "undergrad_4"],
  "target_graduation_year_from": 2027,
  "target_graduation_year_to": 2029,
  "target_other": null,
  "main_job_middle_category_ids": [2],
  "related_job_middle_category_ids": [3],
  "main_work_process_ids": [5],
  "involved_work_process_ids": [1, 2],
  "technology_ids": [1, 7],
  "industry_ids": [1],
  "business_type_ids": [2],
  "job_trial_ids": [1],
  "updated_at": "2026-09-21T18:00:00.000+09:00"
}
```

- 職種と工程は、「主な／関連する」「メインで担当する／関われる」で配列を分けて返す（Rails とのやりとりの形。画面は1つの一覧に直して見せ、チェックを入れた項目ごとにメイン／サブを選ぶ。本書6-5 C3。PR234・PR235）
- about・business_description が空欄なら、null のまま返す。画面側は、⑧の企業プロフィールの値を薄く表示する
- industry_ids・business_type_ids：この募集の業界・事業形態（任意）。企業プロフィールの値とは別に持つ（本書5-8）
- job_trial_ids：この募集に近いプチ職業体験の講座（任意、複数。S6 の枠に出す。PR374）。講座の表示順で返す（送った順ではない。⑬⑭ の返事でも同じ）。送られなければ今の内容のまま、空の配列なら全部外す。順19 で足した
- culture_ の5つ：カルチャーグラフ。−2〜2 の数値（空欄にはならない）
- 作る順：工程・業界・事業形態・カルチャーは順9 で足した。目的・求める人材は【仕上げ】だが、今回の開発では作らない（議事録28。PR333）
- 求める人材（学生には見せない）
  - target_grades：求める学年。grade の選択肢の名前の配列（複数選択、任意）
  - target_graduation_year_from／target_graduation_year_to：求める卒業年度の範囲。片方だけの指定もできる（本書17-3-4）
  - target_other：その他の特徴（文章、任意）
- 段階タグ：【コア】

**⑬ POST /api/company/job_postings（募集の新規作成）**

- 画面・操作：C3 の保存（新規）
- 送るもの：⑫と同じ項目（id、published_at、updated_at は除く）
- 新規作成のときは、非公開か掲載中を選ぶ（本書17-2-2）
- 返すもの：201、⑫と同じ形
- 処理：job_postings と中間テーブル5つ（職種・工程・使用技術・業界・事業形態）を、1つのトランザクションで作る。状態が掲載中なら published_at を記録する。順19 で、募集に近い講座（job_posting_job_trials）も同じトランザクションで作るようにした（知らない講座の番号・重複は 422。「この募集に近いプチ職業体験に選べない値が含まれています」など、業界と同じ文言の形）
- 主なエラー：422（必須の項目（本書5-9。インターンですること・時給は、状態が掲載中のときだけ必須）、選択肢の範囲、主と関連に同じ中分類がある、メインと関われるに同じ工程がある（PR242）、カルチャーが −2〜2 の整数でない、状態の誤り、など）
- 処理の置き場所：モデルの `JobPosting#save_posting`（先に全部確かめてから、トランザクションの中で書き込む。本書9-2）。工程は職種と同じく、メインか関われるのどちらかが送られたら置き換え、送られなかった側は今の内容のままにする
- 推薦の集計：同じトランザクションで、その募集の job_posting_recommendation_stats の項目数を保存し直す（新しく作ったときは行を作る）。裏側のジョブはない（本書7-5）【強み】。順12 で `JobPosting#save_posting` の中に足した
- 段階タグ：【コア】

**⑭ PATCH /api/company/job_postings/:id（募集の保存・状態の変更）**

- 画面・操作：C3 の保存（編集・状態の変更）
- 送るもの：⑬と同じ。フォームの全項目を送り、配列は送った内容でまるごと置き換える
- 状態は、この窓口で他の項目と一緒に保存する（16-1-4 の例外）。3つの状態は自由に行き来できる（本書17-2-2）。初めて掲載したときだけ、最初に掲載した日を記録する
- 返すもの：200、⑫と同じ形
- 処理：初めて掲載中にしたときだけ published_at を記録する。保存に成功したら、中身が変わっていなくても updated_at を今にする（職種・使用技術など中間テーブルだけを直した場合も、⑪ の最終更新日と並び順に反映させるため。Rails の標準では、本体の列が変わったときしか updated_at が変わらない）
- 主なエラー：422（⑬と同じもの、状態の移り変わりの誤り）
- 推薦の集計：⑬と同じく、同じトランザクションで項目数を保存し直す。裏側のジョブはない（本書7-5）
- 募集を消す窓口は作らない（募集は消さず、状態で管理する。本書8-6）
- 段階タグ：【コア】（工程・業界・事業形態・カルチャーは【強み】で、順9 で足した。目的・求める人材は【仕上げ】。本書6-5 C3）

#### 16-3-5. まとまり3：学生のプロフィールと募集検索

**⑮ GET /api/student/profile（自分のプロフィール）**

- 画面・操作：S1 の表示。S2 で、稼働条件のポップアップの「自分の稼働条件で選ぶ」に使う（PR302）
- 使える人：学生
- 返すもの：項目の名前と形は、⑥で送るものと同じ（email、password などアカウントの項目は除く）。icon_url を加える
  - skills の years（年数）は数値で返す（16-1-8）
- 段階タグ：【コア】

**⑯ PATCH /api/student/profile（自分のプロフィールの保存）**

- 画面・操作：S1 の保存
- 送るもの：⑮と同じ項目（icon_url は除く）。フォームの全項目を送る
- 配列（興味のある職種などの id の配列、skills、links、certifications）は、送った内容でまるごと置き換える
  - skills・links・certifications は、1行ずつ書き換えるのではなく、消して作り直す
- 必須：name、activity_status（本書5-9）
- 返すもの：200、⑮と同じ形
- 主なエラー：422
  - skills の行ごとの誤りは、行の番号（0から数える）を付けた名前で返す。例：`"skills[0].years": ["年数は50以下の値にしてください"]`。画面はその行の下に出す
    - links・certifications も同じ形で返す。例：`"links[0].url": ["URLはhttp://かhttps://で始まる形で入力してください"]`、`"certifications[1].name": ["資格名を入力してください"]`（順17）
    - certifications は資格名の文字の配列で送るが、誤りの名前は1行分のモデルの項目名（name）を付けた形にそろえる
  - 行の数の上限や、同じ技術が2行あるなど、欄全体の誤りは `skills` の名前で返す
- 処理：student_profiles と付属テーブル7つを、1つのトランザクションで保存する（【コア】の順3 で作った付属テーブルは、プログラミング歴・興味のある職種・出社できる都道府県の3つ。興味のある業界は順10 で前倒しして作った（PR254）。残りは【仕上げ】で足す）
- 推薦の集計：同じトランザクションで、その学生の student_recommendation_stats の項目数を保存し直す。裏側のジョブはない（本書7-5）【強み】。順12 で、書き込みの `StudentProfile#write_profile!` の中に足した（⑥ の新規登録も同じ場所を通る）
- 段階タグ：【コア】（働き方の好み（性格）の5軸は【強み】で、順9 で足した。興味のある業界（interested_industry_ids）は【仕上げ】だったが、㉓ の比較に使うので順10 で足した。外部リンク・資格・就活希望エリアは【仕上げ】で、順17 で足した。本書6-6 S1）
- 行ごとの付属情報（skills・links・certifications）の確かめと作り直しは、`StudentProfile` の共通の処理（`build_rows`・`replace_rows`）で行う。1行分のモデルは `StudentSkill`・`StudentLink`・`StudentCertification`
- 働き方の好みの5軸（personality_ の5つ）：−2〜2 の整数。範囲の外や小数は 422（「働き方の好み（進め方）は2以下の値にしてください」など）。確かめは、募集のカルチャーと同じ部品（`app/models/concerns/culture_axes.rb`）
- ⑮⑯ の項目は、㉓ 学生詳細（企業が見る）でも同じ部品で返す（`app/views/api/shared/_student_profile.json.jbuilder`）。働き方の好みも、マッチ前から企業に見せる（本書6-6 S1「入力した情報は、マッチ前でも企業にすべて見せる」）

**⑰ POST /api/student/profile/icon（学生のアイコン）**

- 画面・操作：S1 のアイコンの登録・差し替え（保存のとき、⑯の成功後に続けて送る）。S9 の登録の直後
- 中身は⑩と同じ（multipart/form-data の `icon`、PNG・JPEG・WebP で 2MB まで、返すものは `{ "icon_url": "..." }`）
- 段階タグ：タグ未付与（S1 のアイコンと同じ）

**⑱ GET /api/student/job_postings（募集検索）**

- 画面・操作：S2 の表示、条件・並び順の変更、ページ送り
- 使える人：学生

| 送るもの | 型 | 画面の条件 | 合致の決まり（これを満たせば matched が true） |
| --- | --- | --- | --- |
| q | 文字列 | ① フリーワード | 次のどこかに、部分一致で含まれる募集。**募集詳細（⑲）の画面に出る文章すべて**：タイトル、どんな会社か、事業内容、インターンですること、成長イメージ、必須要件、歓迎要件、使用技術の補足、勤務形態の補足、最寄り駅など、稼働の備考。**名前**：会社名、使用技術の名前、職種の名前（募集が主・関連に持つ中分類の名前と、その大分類の名前。説明文は対象外）。どんな会社か・事業内容は画面に出ている方で探す（募集が空欄なら企業プロフィールの文章、募集に書いてあれば募集の文章だけ）。都道府県と勤務形態の名前は対象外（②③の専用の条件で探す）。空白（全角も）で区切ると「すべてを含む」。大文字と小文字は区別しない。実装は SQL の ILIKE（本書9-6） |
| prefecture_ids[] | 数値の配列 | ② 勤務地 | 勤務地がどれかに当てはまる募集。フルリモートの募集は、勤務地に関係なく含める |
| work_days_per_week | 数値 | ③ 週の日数 | 募集の「週○日以上」が、この値以下 |
| work_hours_per_day | 数値 | ③ 1日の時間 | 募集の「1日○時間以上」が、この値以下 |
| duration_months | 数値 | ③ 継続期間 | 募集の「最低○ヶ月以上」が、この値以下 |
| available_from | 日付 | ③ 開始時期 | 募集が随時（空欄）か、**募集の開始月が今月より前**か、募集の開始月がこの日以降（本書5-6） |
| work_styles[] | 選択肢の名前の配列 | ③ 勤務形態 | 募集の勤務形態が、この中に含まれる |
| weekend_ok | 真偽値 | ③ 土日OK | true なら、土日OK の募集だけ |
| industry_ids[] | 数値の配列 | ④ 業界 | 募集の業界のどれか1つが一致（企業プロフィールの値は使わない。本書5-8） |
| business_type_ids[] | 数値の配列 | ④ 事業形態 | 募集の事業形態のどれか1つが一致（同上） |
| job_major_category_ids[] | 数値の配列 | ④ 職種（大分類だけ選んだとき） | その大分類に属する中分類を、主・関連のどちらかに持つ募集 |
| job_middle_category_ids[] | 数値の配列 | ④ 職種（中分類） | 主・関連のどれか1つが一致。フロントエンド・バックエンドを選んだときは、フルスタックの募集も含める（【仕上げ】。今回の開発では作らない。PR333） |
| technology_ids[] | 数値の配列 | ④ 使用技術 | 選んだ技術の**どれか1つ**を使用技術に持つ募集。フリーワードでは拾えない表記の揺れ（「JS」と「JavaScript」など）を、マスタから選んで探せるようにするため |
| work_process_ids[] | 数値の配列 | ④ 工程 | 選んだ工程の**どれか1つ**を、メインか関われるのどちらかに持つ募集（使用技術と同じ形。PR251）。「設計から関わりたい」のように、関わりたい段階で探せるようにする（職種から SE を外し、工程で表すことにしたため。本書5-8） |
| sort | `recommended`／`newest` | 並び順 | 省略時は recommended |
| page | 数値 | ページ | 省略時は1 |

- 出すのは、掲載中の募集のうち、**自分の募集管理（S3）に載っている募集（自分が応募した募集と、マッチした募集）を除いたもの**（どちらも除外。利用者が指定した条件ではないため。本書7-3。PR253）
  - 除く決まりは、㉞ 募集管理の一覧と同じスコープ（`Candidacy.listed_in_student_candidacies`）を使う。「どちらにも出ない」「両方に出る」を起こさないため
  - 企業に見送られた応募も除く（学生には「応募済み」に見えるため）
  - スカウトが届いてまだマッチしていない募集は残す（学生がまだ応えていないので、探す中で見つけて応じられるように）。企業側の学生検索で「未対応の応募は残す」（PR220）と左右対称の決まり
- **条件で結果を減らさない。** 指定した条件を全部満たすものが matched＝true、1つでも外れたら false。どちらも返す（本書7-3）
  - 条件を指定した項目が未入力の募集は、matched＝false にする（結果には出る。本書5-10）
  - 開始時期の空欄は「随時」として常に合致させる
  - 条件を1つも指定しなければ、すべて matched＝true
  - 数でない・日付でない・知らない名前などの値は、その条件を「指定なし」として扱う（422 にしない）。並び順・ページ番号と同じゆるさにそろえる。条件は画面の URL に入るので、手で書き換えられても画面が壊れないようにするため
- 並び順
  - recommended（おすすめ順）：群ごとに、f(募集, 学生) の上位100件を高い順、101件目以降を新着順（本書7-3・7-5。PR280）。点数が同じなら新着順。プロフィールがほとんど空の学生でも分岐せず、そのままおすすめ順で出す
    - 上位の選び方は、検索の処理から切り離した部品（`JobPostingRecommender.ranked_ids(学生, [合う群, 合わない群])`）に置く。返すのは、群ごとの上位100件の番号の並びだけ（本書9-4。PR295）
    - 検索の本体は、その並びを SQL の並べ替えに入れ、群 → 上位の中の順位（入っていなければ後ろ）→ 新着順 → 番号の順に、データベースで並べてページに分ける（本書7-5）
  - newest（新着順）：最初に掲載した日時の新しい順。SQL で並べる
  - 省略時と、知らない値のときは recommended
  - 並び順やページを変えるたびに、Rails は一から計算し直す（前回の結果を覚えない）。おすすめ順の重さは本書9-4-1 で実測してから、対策が要るかを決める
  - 並び順に関係なく、matched＝true の群がすべて先、そのあとに false の群。どちらの群の中も、この並び順で並べる
  - 合致外の群を「何個の条件に合っていたか」で並べ替えることはしない（作りを単純にするため。本書7-3）
- 画面側の動き（S2 の稼働条件のボタン）
  - 並び順と条件は切り離す。おすすめ順は並び順だけを変え、条件は画面で選んだものだけを使う。並び順を変えても、条件は変わらない（PR302）
  - 稼働条件のポップアップの一番上に「自分の稼働条件で選ぶ」ボタンを置く。押すと、⑮の稼働条件の入力済みの項目で、ポップアップの中身（週の日数、1日の時間、継続期間、開始時期、勤務形態）を置き換える。未入力の項目はオフになる
    - 勤務形態は、3つとも可能なら選ばない（「未入力」と「すべて可能」は区別しない。本書5-6）
    - 土日OK はプロフィールにない項目なので、今の選択のまま
    - 出社できる都道府県も稼働条件の一部なので、勤務地のポップアップも一緒に置き換える（PR304）
    - 変わるのは下書きだけで、「検索する」を押すまで結果は変わらない（PR192）
  - ボタンの選択肢は、稼働条件の共通形式（本書5-6）と同じ
- 返すもの：200。items は形B に `matched`（真偽値）を加えたもの、pagination に matched_count あり（16-1-11）
- 段階タグ：【コア】（おすすめ順の本物の点数と「自分の稼働条件で選ぶ」、工程は【強み】。フルスタックのルールは【仕上げ】だが、今回の開発では作らない。議事録28。PR333）
  - 順4 で作ったもの：q、prefecture_ids、職種、technology_ids、稼働条件（手動の選択）と土日OK、sort（おすすめ順は仮の点数）、page。稼働条件の手動の選択と土日OK は【仕上げ】から前倒しした
  - 順9 で作ったもの：work_process_ids、応募済み・マッチ済みの募集の除外（PR253）
  - 順13 で作ったもの：おすすめ順の本物の計算と通り道の作り替え（PR295）、「自分の稼働条件で選ぶ」（PR302・PR304）、industry_ids・business_type_ids（【仕上げ】から前倒し。PR299）

**⑲ GET /api/student/job_postings/:id（募集詳細）**

- 画面・操作：S6 の表示
- 使える人：学生。見られる範囲は、掲載中の募集と、自分とやりとりがある募集（非公開・終了なら is_open が false）。一度も掲載していない募集と、関係のない非公開・終了の募集は 404（16-1-10）

```json
{
  "id": 12,
  "title": "自社サービスのバックエンド開発インターン",
  "is_open": true,
  "company": { "id": 3, "name": "株式会社サンプル", "icon_url": null },
  "industry_ids": [1],
  "business_type_ids": [2],
  "about": "エンジニアが半数を占める、30人ほどの会社です",
  "business_description": "受託開発と自社サービスの運営",
  "internship_details": "…",
  "growth": null,
  "culture_pace": -1,
  "my_personality_pace": 1,
  "my_personality_novelty": 0,
  "my_status": "scouted",
  "my_candidacy_id": 34,
  "has_message_thread": true,
  "job_trials": [{ "id": 1, "title": "テスト設計", "completed": false }]
}
```

- 上の例のほかに、⑫と同じ名前で次の項目も返す：稼働条件（min_work_days_per_week、min_work_hours_per_day、min_duration_months、start_month、work_style、work_style_note、prefecture_id、work_location_note、weekend_ok、work_note）、hourly_wage、culture_ の5つ、requirements、preferred_requirements、technology_note、職種・工程・使用技術の配列、published_at
- 返さない項目：status（代わりに is_open）、purpose、hiring_possibility、target_grades、target_graduation_year_from、target_graduation_year_to、target_other（学生に見せない項目）
- about・business_description：募集側が空欄なら、企業プロフィールの値を入れて返す（学生の画面では区別が要らないため）
- industry_ids・business_type_ids：その募集の値だけを返す。about などと違い、空欄でも企業プロフィールの値で補わない（本書5-8）
- my_personality_ の5つ（my_personality_pace、my_personality_novelty、my_personality_collaboration、my_personality_decision、my_personality_atmosphere）：自分の働き方の好み（−2〜2）。画面はカルチャーグラフに黒丸で重ねる（PR258）
  - 名前に my_ を付けて、募集のカルチャー（culture_）と区別する（my_status と同じ付け方）。並びは `CultureAxes::AXES` から作る
  - 一致・ずれの判定は返さない。自分で答えた値なので、重ねて見れば比べられるため（PR258）
- my_status・my_candidacy_id：形E
- has_message_thread：**その企業とのスレッドがあるか**。true なら画面に「この企業とのメッセージ」のボタンを出す（本書17-2-3）
  - 送れるかどうか（can_send）とは別。スカウトが届いてまだマッチしていない相手でも、スカウト文を読みに行けるようにするため
  - スレッドができるのは「スカウトを受けたとき」か「応募がマッチしたとき」（本書5-2）
- job_trials：企業が選んだ、この募集に近いプチ職業体験の講座（講座の表示順）。completed は、自分がその講座の自己分析を送っているか（修了済み。判定は Rails）。1つもなければ空の配列（PR374）
- 段階タグ：【コア】（my_personality_ の5つは【強み】、job_trials は【後付け】）
- 作る順：項目は、元になるテーブルや列ができる順で足していく
  - 順4（募集を探す）：上の例と説明のうち、次の順で足すもの以外。見られる範囲は掲載中の募集だけ
  - 順5（応募 → 企業がマッチ）：my_status、my_candidacy_id。見られる範囲に「自分とやりとりがある募集」を足す
  - 順6（スカウト → 学生がマッチ）：has_message_thread（`MessageThread.exists_between?`）。「この企業とのメッセージ」のボタンは、行き先の S5 ができた順7 で画面に足した（PR213）
  - 順9（性格・カルチャー・工程の入力）：industry_ids、business_type_ids、職種と並ぶ工程の配列（main_work_process_ids、involved_work_process_ids）、culture_ の5つ（済み）。順10（比較の表示）：my_personality_ の5つ（済み）
  - 順19（プチ職業体験の企業の側）：job_trials
  - 仮の値（常に「関係なし」など）を先に返すことはしない。仮の値が残ったままになるのを防ぐため

**⑳ GET /api/student/companies/:id（企業詳細）**

- 画面・操作：S7 の表示
- 使える人：学生（すべての企業を見られる）

```json
{
  "id": 3,
  "name": "株式会社サンプル",
  "industry_ids": [1],
  "business_type_ids": [2, 3],
  "employee_size": "size_10_49",
  "business_description": "受託開発と自社サービスの運営",
  "about": "エンジニアが半数を占める、30人ほどの会社です",
  "icon_url": null,
  "has_message_thread": false,
  "job_postings": []
}
```

- industry_ids・business_type_ids：企業プロフィールの業界・事業形態（会社の紹介として表示する）
- job_postings：その企業の掲載中の募集。形B で、ページ分けしない。**最初に掲載した日時の新しい順**（募集検索の新着順とそろえる）
- has_message_thread：その企業とのスレッドがあるか。true なら「この企業とのメッセージ」のボタンを出す（⑲と同じ判定。本書17-2-3）
- 段階タグ：【コア】
- 作る順：has_message_thread は順6（スカウト → 学生がマッチ）で足し、ボタンは順7 で画面に足した（⑲と同じ。PR213）。形B の業界・事業形態・工程は順9 で足した（⑲と同じ考え方）

#### 16-3-6. まとまり4：学生検索・候補者・スカウト・応募・マッチ

**㉑ GET /api/company/candidacies（候補者一覧）**

- 画面・操作：C4 の表示、タブ・表示の切り替え、ページ送り
- 送るもの：job_posting_id（募集別のタブ。省略すると「すべて」）、show_all（true なら見送り・合格・不合格も表示）、page
- 並び順：やりとりが始まった日（応募日・スカウト日）の新しい順

```json
{
  "items": [
    {
      "id": 34,
      "job_posting": { "id": 12, "title": "自社サービスのバックエンド開発インターン", "status": "published" },
      "student": {
        "id": 5, "name": "山田 太郎", "icon_url": null,
        "grade": "undergrad_3", "graduation_year": 2028, "activity_status": "job_hunting"
      },
      "origin": "application",
      "status": "unmatched",
      "tag": "pending_application",
      "after_match": false,
      "unreplied": false,
      "created_at": "2026-09-21T09:00:00.000+09:00",
      "matched_at": null
    }
  ],
  "pagination": { "page": 1, "per_page": 20, "total_count": 8, "total_pages": 1 }
}
```

- tag（Rails が計算する）：やりとりの状態のタグ。値は6つ。㉒・形D と同じものを使い、日本語は⑦の enums の candidacy_tag で引く
  - `pending_application`（未対応応募）：応募で、未マッチ
  - `scouted`（スカウト済み）：スカウトで、未マッチ
  - `matched`（マッチ）／`declined`（見送り）／`passed`（合格）／`failed`（不合格）：状態そのまま
- after_match（Rails が計算する）：その行がマッチ以降（マッチ・合格・不合格）なら true。画面は true の行に「メッセージ」のボタンを出す（PR224）
  - 画面が status から「マッチ以降か」を組み立てると、メッセージを送れるかの判定（17-2-3）と同じ判定が2か所になるため、Rails が返す（16-1-9）。判定は `Candidacy#after_match?`（絞り込みの `after_match` と同じ状態の一覧を使う）
- unreplied（Rails が計算する）：マッチ以降で、スレッドの最後の送信者が学生なら true
  - 状態とは別の軸（返事をしたかどうか）なので、tag に混ぜず項目を分ける
  - スレッドは企業×学生で1本なので、同じ学生のマッチ以降の行が2つあれば両方に付く。メッセージがまだないスレッドは false
  - 1ページ分の学生について、スレッドごとの最後のメッセージを PostgreSQL の DISTINCT ON で1回で取り出して判定する（`MessageThread.awaiting_reply_student_ids`。行ごとに問い合わせない）。同じ日時のメッセージは、番号の大きい方を最後とみなす
- 理由：行には「誰が、どの段階か」が分かる最低限を載せる。並び順は単純で予想しやすい形にし、「対応が必要なものを上に並べる」は、タグで見分けられるので作らない
- job_posting_id は、自社の募集の中から探す。他社の募集や存在しない番号なら 404（16-1-10）
- 段階タグ：【コア】（show_all は【強み】、unreplied は【仕上げ】）。行の学生情報と並び順は【仕上げ】だったが、順5 で前倒しして作った。名前がないと誰の行か分からず、【コア】の段階でも画面が使えないため（PR207）
- show_all（順11）：`"true"` や `"1"` を true として読む（⑱ の weekend_ok と同じ読み方）。true でなければ、状態が未マッチ・マッチのやりとりだけを返す（`Candidacy.listed_in_company_candidacies`）。絞り込みはデータベースで行うので、pagination の件数も隠したあとの行で数える
- 作る順：順5 で、show_all・unreplied・after_match 以外を作った。after_match は、メッセージのボタンを作る順7 で足した（PR224）。show_all は順11（見送りの扱い）で足した。unreplied は【仕上げ】の順16 で足した

**㉒ GET /api/company/students（学生検索）**

- 画面・操作：C5 の表示、条件・並び順の変更、ページ送り

| 送るもの | 画面の条件 | 合致の決まり（これを満たせば matched が true） |
| --- | --- | --- |
| job_posting_id | 募集の選択 | 除外・タグの基準と、おすすめ順に使う。これ自体は合致の条件ではない。自社の募集なら、掲載中以外も選べる。選んでも条件は変わらない。画面は、稼働条件のポップアップの「この募集の稼働条件で選ぶ」を押したときだけ、その募集の稼働条件（入力済みの項目）で条件のボタンを選ぶ（推薦検索。⑫で取る。PR302） |
| q | フリーワード | 自己PR（3つの問い）、資格名、プログラミング歴の「その他」の名前に、部分一致で含まれる。空白で区切ると「すべてを含む」。名前と大学名は対象にしない。実装は SQL の LIKE（本書9-6） |
| work_days_per_week | 週の日数 | 学生の「週○日まで」が、この値以上 |
| work_hours_per_day | 1日の時間 | 学生の「1日○時間まで」が、この値以上 |
| duration_months | 継続期間 | 学生の「○ヶ月以上続けられる」が、この値以上 |
| start_month | 開始時期 | 学生の開始可能月が、この月以前。**この月が今月より前なら、条件として使わない**（全員合致。本書5-6） |
| work_style | 勤務形態 | 学生がその勤務形態を「可能」にしている |
| prefecture_id | 勤務地 | 学生の出社できる都道府県に含まれる（勤務形態がフルリモートのときは使わない） |
| technology_ids[] | 使用技術 | 選んだ技術を、すべてプログラミング歴に持っている |
| min_level | 技術のレベル | technology_ids と一緒に使う。選んだ技術すべてが、このレベル以上 |
| job_middle_category_ids[]（大分類だけなら job_major_category_ids[]） | 職種 | 興味のある職種のどれか1つが一致 |
| grades[] | 学年 | どれかに当てはまる |
| graduation_years[] | 卒業年度 | どれかに当てはまる |
| activity_statuses[] | 活動状況 | どれかに当てはまる |
| sort | 並び順 | `recommended`（選んだ募集におすすめ順。job_posting_id が必要）か `last_active`（最終活動が新しい順）。省略時は、募集を選んでいれば recommended、なければ last_active |
| page | ページ | 1ページ20件 |

- 共通の決まり
  - 最終活動日が30日より前の学生は出さない（本書5-4）。最終活動日が空の学生（一度もログインしていない）も外し、ちょうど30日前に活動した学生は出す（企業に見せる最終活動の目安の「30日以内」とそろえる。PR216）。これは除外。利用者が指定した条件ではなく、全員に同じ基準が当たる区分のため（本書7-3・5-12）。活動状況が「今は探していない」の学生は外さない
  - **もうスカウトした・見送った・マッチした学生も出さない**（PR220）。検索はスカウトする相手を探すためのもので、残しても邪魔になり、おすすめ順にも既存の学生がたまるため。30日の除外と同じく、全員に同じ基準が当たるシステムの除外として扱う
    - 募集を選んだとき：その募集とのやりとりが、スカウト済み、見送り（応募・スカウトとも）、マッチ以降（マッチ・合格・不合格）の学生を出さない。**未対応応募だけは残す**
    - 募集を選んでいないとき：自社の**掲載中の募集すべて**と、上のどれかのやりとりがある学生（どの募集でも、もうスカウトできない学生）を出さない。掲載中の募集が1件もない会社では、誰も除かない
  - 除外は Rails の検索の本体（`app/services/student_search.rb`）の「対象の学生」で行う。人数・合致の群と合致外の群・ページ分け・おすすめ順が、除いた後の学生で計算される。画面側で消すと、ページごとの人数と件数が合わなくなるため
  - 除いた学生は、候補者一覧（C4）から学生詳細を開ける
  - **条件で結果を減らさない。** 指定した条件を全部満たすものが matched＝true、1つでも外れたら false。どちらも返す（本書7-3）
    - 条件を指定した項目が未入力の学生は、matched＝false にする（結果には出る。本書5-10）
    - 条件を1つも指定しなければ、すべて matched＝true
  - 並び順に関係なく、matched＝true の群がすべて先、そのあとに false の群
  - 性格は、合致の判定に使わない（本書2-4）
  - おすすめ順は、群ごとに、f(募集, 学生) の上位100人を高い順、101人目以降を最終活動が新しい順に並べる（本書7-3・7-5。PR280）
    - 上位の選び方は `StudentRecommender.ranked_ids(募集, [合う群, 合わない群])`（上位100人の番号の並びだけを返す）。並べ替えとページ分けはデータベースで行う（⑱と同じ形。PR295）
  - おすすめ順以外の並び順を「最終活動が新しい順」にするのは、最近使っている学生ほど返信が来やすいため（本書2-3 の V3）
  - sort が recommended なのに job_posting_id がないときは 422（16-1-10）
- 返すもの：200。items は形C に次の3つを加えたもの、pagination に matched_count あり（16-1-11）
  - matched：指定した条件を全部満たすか（真偽値）
  - candidacy：募集を選んだときの、その募集とのやりとり（`{ "id", "origin", "status", "tag" }`。なければ null）。募集を選ばないときは常に null
  - candidacy_count：自社の募集とのやりとりの件数（募集を選ばないときのタグ用。他社の分は数えない）
- タグ（画面の表示）
  - 募集を選んだとき：**candidacy.tag をそのまま出す**（⑦の candidacy_tag で日本語にする）。㉑・形D と同じ値で、画面側では組み立てない（16-1-9）。除外のあとなので、出るのは「未対応応募」だけ
  - 募集を選ばないとき：candidacy_count が1以上なら「やりとりあり」のタグを出す
  - 未対応応募の学生にタグを出すのは、同じ募集にすでに応募している学生にスカウトしようとすると、エラー（1つの募集×学生でやりとりは1件だけ）になるため
- 段階タグ：【コア】（推薦検索・おすすめ順の本物の点数は【強み】、最終活動の目安は【仕上げ】）。タグは【仕上げ】だったが、順6 で前倒しした（PR219）
- 作る順
  - 順6（スカウト → 学生がマッチ）：上の送るもの・返すものすべてと、除外（PR216・PR220）。フリーワードの資格名を除く
    - おすすめ順は、通り道と仮の点数で作った（PR214）
  - 順13：おすすめ順の本物の計算と通り道の作り替え（PR295）。推薦検索（稼働条件のポップアップの「この募集の稼働条件で選ぶ」。PR294・PR302）
  - 資格名は、資格の表を作った【仕上げ】の順17 で足した（プログラミング歴の「その他」と同じく、表を結合せずサブクエリで探す。資格を複数持つ学生が何行にも増えないように）。最終活動の目安（形C の last_active_range）は【仕上げ】の順16 で足した

**㉓ GET /api/company/students/:id（学生詳細）**

- 画面・操作：C6 の表示
- 使える人：企業（すべての学生を見られる。30日以上活動のない学生も、C4 や通知から開けるように、ここでは外さない）

```json
{
  "student": { "…⑮と同じ項目…": "…", "icon_url": null, "last_active_range": "within_7_days" },
  "has_message_thread": true,
  "self_analyses": [
    {
      "job_trial": {
        "id": 1, "title": "テスト設計", "job_middle_category_id": 16, "work_process_ids": [4, 9],
        "summary": "テスト設計では、作られた機能が仕様通りに動くかを確かめます。",
        "hurdles": [
          {
            "id": 1, "name": "理解する",
            "skill": "情報を整理する力",
            "skill_description": "仕様書や実際の画面から、…",
            "skill_point": "情報を整理し、分からない点を見つける力"
          }
        ]
      },
      "strength_hurdle": { "id": 1, "name": "理解する" },
      "strength_reason": "…",
      "growth_hurdle": { "id": 4, "name": "判断する" },
      "growth_reason": "curiosity",
      "growth_detail": "…",
      "next_step": "…",
      "same_hurdle": false,
      "created_at": "2026-09-29T10:00:00.000+09:00",
      "updated_at": "2026-09-29T10:00:00.000+09:00"
    }
  ],
  "job_postings": [
    {
      "id": 12, "title": "自社サービスのバックエンド開発インターン", "status": "published",
      "candidacy": {
        "id": 34, "origin": "application", "status": "unmatched",
        "tag": "pending_application",
        "reasons": ["business", "culture"], "matched_at": null
      },
      "available_actions": ["match", "decline"],
      "comparison": {
        "job_posting": {
          "industry_ids": [1, 3], "job_middle_category_ids": [2, 5], "technology_ids": [1],
          "min_work_days_per_week": 2, "min_work_hours_per_day": 4, "min_duration_months": 3,
          "start_month": null, "work_style": "onsite", "prefecture_id": 13,
          "culture_pace": -2, "culture_novelty": 0, "culture_collaboration": 1,
          "culture_decision": 0, "culture_atmosphere": -1
        },
        "industry_ids": { "matched": [1] },
        "job_middle_category_ids": null,
        "technology_ids": { "matched": [] },
        "work_conditions": [
          { "item": "work_days_per_week", "result": "match" },
          { "item": "work_hours_per_day", "result": "mismatch" },
          { "item": "duration_months", "result": "not_judged" },
          { "item": "start_month", "result": "match" },
          { "item": "work_style", "result": "match" },
          { "item": "work_location", "result": "not_judged" }
        ]
      }
    }
  ]
}
```

- student：学生のプロフィールの全項目（マッチ前でもすべて見せる）に、最終活動の目安（last_active_range）を加えたもの
  - last_active_range は形C と同じ値。この窓口だけ `over_30_days` も返り、一度もログインしていない学生は null（PR335）
- has_message_thread：**その学生とのスレッドがあるか**。募集ごとではなく学生ごとの値なので、job_postings の中ではなく外に置く
  - true なら、どの募集を選んでいても「この学生とのメッセージ」のボタンを出す（本書17-2-3、6-5 C6）
  - 送れるかどうか（can_send）とは別。自分が送ったスカウト文を読み直せるようにするため
- self_analyses：その学生の自己分析（修了したプチ職業体験）のすべて。修了した日（created_at）の新しい順。なければ空の配列（本書6-5 C6。PR372）
  - 学生ごとの値なので、job_postings の中ではなく外に置く
  - same_hurdle：1-1 と 2-1 が同じハードルか（「得意を伸ばしたい」と添えるか）。判定は Rails（PR360）
  - 学生の自己分析は数件なので、ポップアップを開くたびに取りに行かず、ここに全部入れる（PR386）。ハードルの名前は、C6 が講座の中身を持たないので、ここに入れて返す
  - job_trial：ポップアップで「この講座と各ハードルで何を見ているか」を先に出すための講座の中身（PR403）。中分類・工程の番号、講座の説明（summary）、講座の中の順番のハードルの一覧（名前と、力 skill・その説明 skill_description・まとめ skill_point）
    - summary と skill などは、データベースではなく講座の YAML の `guide` から入れる（`JobTrialGuide`。1回の返事の中で講座のファイルを1回だけ読む。PR407）。書かれていない講座・ハードルは null。画面は null の部分を出さない
  - 講座・ハードル・工程は最初にまとめて読み込み、自己分析の数だけ問い合わせを増やさない
- job_postings：自社の全募集（掲載中以外も含む）。各要素は形D に comparison を加えたもの。並び順は⑪と同じ。最初に選ぶ募集は画面側が決める（遷移元の job_posting_id、なければ先頭）
- comparison（学生と、その募集の比較。順10）
  - この窓口だけに入れる。形D を返すスカウト・マッチの返事（㉔㉖）には入れない。スカウトやマッチをしても比較は変わらないため。画面は、返事を元の中身に重ねて書き換える
  - job_posting：右の列に出す募集の値。左の列（学生の値）は student をそのまま使う
    - job_middle_category_ids は、メインとサブを1つにまとめた一覧（学生の興味のある職種にもメイン・サブがなく、並べやすいため）
    - culture_ の5つは、学生の働き方の好み（黒丸）と重ねる白丸に使う。距離や「近いかどうか」は返さない（画面は背景を塗らず、2点の間に線を引くだけ。PR259）
  - industry_ids・job_middle_category_ids・technology_ids：`{ "matched": 両方にある番号の一覧 }`。どちらかが空なら null（画面は「未入力」と出す）。両方入っていて重なりがなければ空の配列
    - industry_ids は、募集の業界と学生の興味のある業界を比べる（企業プロフィールの値は使わない。本書5-8）
    - job_middle_category_ids の募集側は、メインとサブの両方
    - technology_ids の学生側は、プログラミング歴のうちマスタから選んだ技術だけ（「その他」の行は番号がないので比べない）
  - work_conditions：稼働条件の6項目（work_days_per_week、work_hours_per_day、duration_months、start_month、work_style、work_location）を、この順で、`match`（一致）／`mismatch`（不一致）／`not_judged`（どちらかが未入力）で返す。照合のルールは本書5-6
    - start_month：募集が随時か、開始月が今月より前なら、学生が空でも match
    - work_style：募集が空なら not_judged（学生の勤務形態は、未入力と「すべて可能」を区別しないので、学生側の空はない）
    - work_location：募集がフルリモートなら match。募集の都道府県が空、または学生の出社できる都道府県が空なら not_judged（通えないのではなく、答えていないだけのため。PR257）。検索（⑱㉒）では、未入力は今のまま合致外（PR261）
  - 判定は `app/services/student_job_posting_comparison.rb`（`StudentJobPostingComparison`）の1か所。形は `app/views/api/company/students/_comparison.json.jbuilder`
  - 比較に使う関連（学生の興味のある業界・興味のある職種・プログラミング歴・出社できる都道府県、募集の業界・職種・使用技術）は、最初にまとめて読み込む。募集が何件あっても、問い合わせの回数は増えない
- 段階タグ：【コア】（comparison と reasons は【強み】、last_active_range は【仕上げ】、self_analyses は【後付け】）
- 作る順：⑲と同じく、項目は元になるものができる順で足していく
  - 順5（応募 → 企業がマッチ）：student、job_postings（形D の candidacy のうち reasons 以外と、available_actions）。available_actions は、窓口ができている操作だけを返す（順5 は match だけ。scout は順6、decline・undo_decline・pass・fail は順11 で足した）
  - 順6（スカウト → 学生がマッチ）：has_message_thread。スレッドは順5 のマッチでもできるが、⑲⑳の has_message_thread と同じ順でそろえる。available_actions に scout を足す。「この学生とのメッセージ」のボタンは、行き先の C7 ができた順7 で画面に足した（PR213）
  - 順10（比較の表示）：comparison、candidacy.reasons
  - 順16（【仕上げ】）：last_active_range
  - 順19（プチ職業体験の企業の側）：self_analyses

**状態を変える操作（㉔・㉖〜㉜）の共通の決まり**

- 返すもの
  - 企業側の操作：200（スカウトは 201）。形D（その募集の分）を返す。画面を読み直さずにボタンを出し直せる
  - 学生側の操作：200（応募は 201）。形E を返す
- 今の状態ではできない操作は 409（例：企業がスカウトに「マッチする」を押した、掲載中でない募集に応募した）。返し方は16-1-10（PR205）
- 確かめる順番は「番号（404）→ 状態（409）→ 入力（422）」。終了した募集への応募は、理由を直しても通らないので、先に「できない」と返す
- 処理は、やりとりのモデル（Candidacy）のメソッドにまとめ、窓口はそれを呼ぶだけにする（本書9-1-1 の4、PR204）。まだないやりとりを作る操作（㉛ 応募の `Candidacy.apply`、㉔ スカウトの `Candidacy.send_scout`）はクラスメソッド、今あるやりとりを変える操作（㉖ 企業のマッチの `candidacy.match`、㉗〜㉚ の `candidacy.decline`・`undo_decline`・`mark_passed`・`mark_failed`、㉜ 学生のマッチの `candidacy.match_by_student`）はインスタンスメソッドにする
  - スカウトのメソッドを `Candidacy.scout` としないのは、enum が自動で作る「発生元がスカウトのものに絞る」`Candidacy.scout` を上書きしてしまうため（PR215）。enum の値と同じ名前のメソッドは作らない
  - 合格・不合格のメソッドを `pass`・`fail` としないのも同じ考え方。`fail` は Ruby に最初からある命令（raise の別名）で、上書きすると思わぬ動きになるため、`mark_passed`・`mark_failed` にする。コントローラーのメソッドも同じ名前にし、URL の `/pass`・`/fail` をつなぐ（`post :fail, action: :mark_failed`。PR269）
- 企業側の操作（㉖〜㉚）の返事は、1つのテンプレート `app/views/api/company/candidacies/state.json.jbuilder` を共通で使う（5つとも同じ形D を返すため。PR270）。やりとりを探す処理も前処理（`before_action :set_candidacy`）の1か所にまとめる
- available_actions（形D）の判定と、操作するときの「できる状態」の確かめは、同じメソッドを使う。「ボタンは出ているのに押すと 409」という食い違いを起こさないため
- 裏側のジョブは、トランザクションが確定したあとに動かす（本書7-5）。すべてのジョブの親（`ApplicationJob`）で、確定するまで積まない設定にしている（本書9-2）
- 「できる状態」は、本書17-2-1 の状態遷移表を窓口ごとに並べ直したもの。**正は17-2-1**（食い違ったら17-2-1 に合わせる）

| 窓口 | 送るもの | できる状態（正は17-2-1） | 1つのトランザクションで行うこと | 裏側のジョブ |
| --- | --- | --- | --- | --- |
| ㉔ POST /api/company/scouts（スカウト） | job_posting_id、student_profile_id、body（スカウト文） | 募集が掲載中で、その募集×学生のやりとりがまだない | やりとり（スカウト・未マッチ）、スレッド（なければ）、メッセージ、スカウトメッセージを作る。スレッドの last_message_at を更新 | なし |
| ㉖ POST /api/company/candidacies/:id/match（マッチ） | なし | 発生元が応募で、状態が未マッチか見送り。募集が掲載中 | 状態をマッチにし、matched_at を記録。スレッドを作る（なければ） | なし |
| ㉗ POST /api/company/candidacies/:id/decline（見送り） | なし | 状態が未マッチ（発生元・募集の状態は問わない） | 状態を見送りにする | なし（通知のきっかけにしない。PR272） |
| ㉘ POST /api/company/candidacies/:id/undo_decline（見送りの取り消し） | なし | 状態が見送り（**発生元は問わない**。募集の状態も問わない） | 状態を未マッチに戻す | なし |
| ㉙ POST /api/company/candidacies/:id/pass（合格） | なし | 状態がマッチか不合格（募集の状態は問わない） | 状態を合格にする（matched_at は残す） | なし |
| ㉚ POST /api/company/candidacies/:id/fail（不合格） | なし | 状態がマッチか合格（募集の状態は問わない） | 状態を不合格にする（matched_at は残す） | なし |
| ㉛ POST /api/student/candidacies（応募） | job_posting_id、reasons（配列、最低1つ） | 募集が掲載中で、その募集とのやりとりがまだない | やりとり（応募・未マッチ）、応募理由、reason_mask を作る | 推薦の更新（本書7-5 の応募・マッチ時の手順）と、似た募集を持つ他社への通知（本書6-5 C10。PR272） |
| ㉜ POST /api/student/candidacies/:id/match（マッチ） | reasons（配列、最低1つ） | 発生元がスカウトで、状態が未マッチか見送り。募集が掲載中 | 状態をマッチにし、matched_at、応募理由、reason_mask を保存 | 推薦の更新と通知（同上） |

- reasons の値：business、industry、job_major_category、job_middle_category、business_type、work_process、internship_details、growth、culture、hourly_wage、work_conditions、technologies の12個（本書8-5 candidacy_reasons）
  - Rails は、はじめから12個すべてを受け付ける。S6 のポップアップに出す項目は、募集詳細に出ている項目だけにする（本書6-6 S6。PR203）
- 主なエラー：404（他社・他人のやりとり、見てよい範囲の外の募集）、409（上の「できる状態」でない）、422（スカウト文が空、応募理由が0個・知らない値・重複、job_posting_id がない、など。長さの上限は本書17-3-4）
- ㉖ のスレッドは企業×学生で1本なので、同じ企業の別の募集で先にできていれば、それを使う（同時に2つマッチされても重複させない）
- ㉔ の student_profile_id は、すべての学生を指定できる
- ㉔ の body（スカウト文）は、メッセージの本文の決まり（空不可・2,000文字まで。本書17-3-4）で確かめ、エラーの項目名だけ「スカウト文」にする（「スカウト文を入力してください」）。空でも同じ文言にするため、必須のパラメータ（ないと 422 の job_posting_id など）の扱いにはしない
  - スカウト文のメッセージの送り手は、その募集の企業のアカウント（今は1社1アカウント）
- ㉜ では、スレッドを作らない。スカウトを送ったときにもうできているため
- ㉗〜㉚ は、状態を1つ書き換えるだけで、ほかの表は触らないので、トランザクションで囲まない。企業が一覧を整理するための操作なので、終了した募集のやりとりでもできる
- 段階タグ：㉔・㉖・㉛・㉜は【コア】、㉗〜㉚は【強み】
- 作る順：㉗〜㉚ は順11 で作った。㉛・㉜ の裏側のジョブは、推薦の更新を順12 で足した（`InterestRecordedJob`。`Candidacy.apply` と `candidacy.match_by_student` のトランザクションのあとに積む）。通知は順15 で同じジョブの最後（数え直しのあと）に足した（`RecommendedStudentNotifications.create_for`。本書7-5）

**㉕ GET /api/company/students/:id/similar_students（この学生に似た学生）**

- 画面・操作：C6 のスカウト送信後のポップアップ
- 送るもの：job_posting_id（必須。スカウトに使った募集）。なければ 422（16-1-10）
- 返すもの：200。最大5人の形C（items で包む。ページ分けしない）。matched は付けない（ポップアップに合う・合わないの区切りを出さないため）。似た学生がいなければ空の items
- 確かめる順：job_posting_id がない（422）→ 他社の募集の番号（404）→ 存在しない学生の番号（404）。学生はすべての学生の中から探す（C6 と同じ。30日以上活動のない学生でも開ける）
- 選び方（本書7-3・7-5）
  1. 学生すべてについて、その学生との近さ f(学生, 学生) をその場で計算する
  2. 次の学生を**外す**：30日以上活動のない学生／その募集とやりとりがある学生／その学生本人
  3. 残りのうち、その募集の稼働条件（入力済みの項目）に**合う学生から f の高い順に取る**。「合う」は、C5 の「この募集の稼働条件で選ぶ」と同じ条件で判定する（PR313）
  4. 5人に満たなければ、**合わない学生からも f の高い順に補充して**5人にする
  5. それでも足りなければ、ある分だけ
  - f が同じなら、最終活動が新しい順 → 番号の大きい順（PR317）
- 稼働条件で絞り切らないのは、学生が稼働条件を埋めていないことが多く、絞ると毎回同じ少数の相手しか出てこなくなるため（本書7-3）
- Rails では、選び方を `SimilarStudents.ids`（`app/services/similar_students.rb`）にまとめ、窓口は番号を確かめて呼ぶだけ。窓口は学生の下の別の一覧として、コントローラーを分ける（`Api::Company::SimilarStudentsController#index`。ルーティングは `resources :students` の中の `resources :similar_students, only: :index` で、パスの番号の名前は `:student_id`）。返ってきた番号の順（`in_order_of`）に、形C の関連（`StudentsController::ROW_ASSOCIATIONS`）もまとめて読む
- 段階タグ：【強み】
- 作る順：順14

**㉝ GET /api/student/job_postings/:id/similar_job_postings（この募集に似た募集）**

- 画面・操作：S6 の応募完了のポップアップ
- 返すもの：200。最大5件の形B（items で包む。ページ分けしない）。matched は付けない。似た募集がなければ空の items
- 番号は、学生から見てよい募集（⑲ と同じ。掲載中と、自分とやりとりがある募集）の中から探す。範囲外は 404。応募の直後なら、その間に募集が終了しても開ける
- 選び方（㉕ と同じ形）
  1. 募集すべてについて、その募集との近さ f(募集, 募集) をその場で計算する
  2. 次の募集を**外す**：掲載中以外の募集／自分とやりとりがある募集／その募集自身
  3. 残りのうち、学生の入力済みの稼働条件に**合う募集から f の高い順に取る**。「合う」は、S2 の「自分の稼働条件で選ぶ」と同じ条件で判定する（PR313）
  4. 5件に満たなければ、**合わない募集からも f の高い順に補充して**5件にする
  5. それでも足りなければ、ある分だけ
  - f が同じなら、新着順 → 番号の大きい順（PR317）
- Rails では、選び方を `SimilarJobPostings.ids`（`app/services/similar_job_postings.rb`）にまとめる。窓口は `Api::Student::SimilarJobPostingsController#index`（`resources :job_postings` の中の `resources :similar_job_postings, only: :index`。パスの番号の名前は `:job_posting_id`）。行は形B の部品と `JobPostingsController::ROW_ASSOCIATIONS` を使い回す
- 段階タグ：【強み】
- 作る順：順14

**㉞ GET /api/student/candidacies（募集管理）**

- 画面・操作：S3 の表示、タグでの絞り込み、ページ送り
- 出すもの（本書8-7）：発生元が応募のもの（状態は問わない）と、発生元がスカウトで状態がマッチ・合格・不合格のもの
- 送るもの：status（`applied` か `matched`。省略するとすべて）、page
- 返すもの：200。items は形B に candidacy_id と my_status（`applied`／`matched`）を加えたもの、pagination あり
- 並び順：やりとりが始まった日の新しい順
- 段階タグ：【コア】（status での絞り込みは【仕上げ】。今回の開発では作らない。議事録28。PR333）

**㉟ GET /api/student/scouts（スカウト管理）**

- 画面・操作：S4 の表示、ページ送り
- 出すもの：発生元がスカウトで、状態が未マッチ・見送りのもの
- 返すもの：200。㉞と同じ形（my_status は常に `scouted`）、pagination あり
- 並び順：スカウトが届いた日の新しい順
- 段階タグ：【コア】

#### 16-3-7. まとまり5：メッセージ

- チャットと送信は、相手の番号で指定する。スレッドは「企業×学生で1本」なので、相手が決まればスレッドも1つに決まるため。`message_thread` は単数形で、相手（学生・企業）の下に置く
- リアルタイム更新はしない。送信の返事で作ったメッセージを返し、画面はそれを会話の末尾に足す。相手からの新しいメッセージは、画面を開き直したとき（または再読み込み）に取る

**㊱ GET /api/company/message_threads・㊴ GET /api/student/message_threads（スレッド一覧）**

- 画面・操作：C7・S5 の表示、ページ送り

```json
{
  "items": [
    {
      "id": 7,
      "partner": { "id": 5, "name": "山田 太郎", "icon_url": null },
      "last_message_at": "2026-09-22T10:00:00.000+09:00"
    }
  ],
  "pagination": { "page": 1, "per_page": 20, "total_count": 3, "total_pages": 1 }
}
```

- partner：相手（企業から見れば学生、学生から見れば企業）。企業・学生で同じ部品（`app/views/api/shared/_partner.json.jbuilder`）
- last_message_at：最後のメッセージの日時。応募に企業がマッチしただけのスレッドは、メッセージがまだないので null
- 並び順：最後のメッセージの新しい順。**last_message_at が null のスレッドは、スレッドを作った日時で代わりに比べる**（PR221。`MessageThread.recent_first`）
  - null のまま新しい順に並べると、PostgreSQL では null が先頭に来て、何か月たっても先頭に居座るため
  - マッチしたときに last_message_at を入れる案は、列の意味（最後のメッセージの日時）とずれるので採らない
- 見てよい範囲：自社・自分のスレッドだけ（16-1-10）
- 段階タグ：【コア】

**㊲ GET /api/company/students/:id/message_thread・㊵ GET /api/student/companies/:id/message_thread（チャット）**

- 画面・操作：C7・S5 のスレッドを開いたとき

```json
{
  "partner": { "id": 5, "name": "山田 太郎", "icon_url": null },
  "can_send": true,
  "matched_job_postings": [{ "id": 12, "title": "自社サービスのバックエンド開発インターン" }],
  "messages": [
    {
      "id": 101,
      "is_mine": true,
      "body": "はじめまして。〇〇株式会社です。…",
      "created_at": "2026-09-20T10:00:00.000+09:00",
      "scout": { "job_posting": { "id": 12, "title": "自社サービスのバックエンド開発インターン" } }
    }
  ],
  "matchable_scouts": [
    { "candidacy_id": 35, "job_posting": { "id": 13, "title": "フロントエンド開発インターン" } }
  ]
}
```

- messages：古い順に全件返す。1組の会話は短い想定なので、ページ分けしない（Phase 8 の重さの点検で見直す）
- is_mine：自分が送ったメッセージなら true（画面で左右に分けて出すため）
  - メッセージ1件ずつにアイコンは持たせない。1対1の会話なので、自分のアイコンは③、相手のアイコンは partner.icon_url から取れる
  - 学生から見ると、スカウト文は企業が送ったものなので false
- scout：スカウト文のときだけ、どの募集のスカウトかを入れる（ふつうのメッセージなら null）
- メッセージ1件の形は、企業・学生と送信（㊳㊶）で同じ部品（`app/views/api/shared/_message.json.jbuilder`）。is_mine は、今ログインしている人（`Current.user`）と送った人を比べる
- can_send：今送れるか。Rails が本書5-2 のルール（その企業×学生のやりとりに、マッチ・合格・不合格が1つでもあるか）で判定する（`MessageThread#can_send?`）。募集の状態は見ない。画面は、false なら入力欄とボタンを使えなくする
- matchable_scouts（**㊵ 学生側だけ**）：その企業からのスカウトのうち、学生が今マッチできるもの（`{ "candidacy_id", "job_posting": { "id", "title" } }`。古い順。なければ空の配列）（PR222）
  - 学生がメッセージ管理でスカウト文を読んだその場で「マッチする」を押せるようにするため。画面は、ここにある分だけ「マッチする」を出し、押したら㉜に candidacy_id を送る
  - 同じ企業から複数の募集でスカウトが来ていれば、募集ごとにすべて入る（マッチはやりとりごとの操作なので、まとめてマッチはしない。PR223）
  - 判定は㉜の「できる状態」と同じ `can_match_by_student?`（スカウトから始まり、未マッチか見送りで、募集が掲載中）。「ボタンは出ているのに押すと 409」を起こさない（`MessageThread#matchable_scouts`）
  - 企業側（㊲）には返さない
- matched_job_postings：その相手とマッチしている募集（マッチ・合格・不合格のもの）。学生側にも同じ形で返し、合格・不合格の区別は見せない
  - 画面の上部に名前を並べるだけで、**そこから学生詳細・募集詳細へ飛ぶ導線は作らない**（本書6-5 C7・6-6 S5）
  - 並びはマッチした日の古い順（同じなら番号の順）。まだマッチしていなければ空の配列
  - 取り出しは `MessageThread#matched_job_postings`（送れるかの判定 can_send? と同じ「マッチ以降」の絞り込み `Candidacy.after_match` を使う）
- スレッドは、自社・自分のスレッドの中から相手の番号で探す。主なエラー：404（相手が存在しない、まだスレッドがない、ほかの企業・学生とその相手のスレッドしかない）
- 段階タグ：【コア】（matched_job_postings は【仕上げ】）
- 作る順：順7 で、matched_job_postings 以外を作った。matched_job_postings は【仕上げ】の順16 で足した

**㊳ POST /api/company/students/:id/message_thread/messages・㊶ POST /api/student/companies/:id/message_thread/messages（送信）**

- 画面・操作：C7・S5 の送信
- 送るもの：body（本文、必須。長さの上限は本書17-3-4）
  - 必須のパラメータ（ないと 422 の job_posting_id など）の扱いにはしない。送られていなくても「本文を入力してください」と出すため（㉔のスカウト文と同じ）
- 返すもの：201。作ったメッセージ1件を、㊲の messages の1要素と同じ形で返す
- 処理：メッセージを作り、スレッドの last_message_at を更新する（1つのトランザクション）。処理はモデルの `MessageThread#post_message` にまとめ、窓口はそれを呼ぶだけにする
- 確かめる順番は、状態を変える操作（16-3-6）と同じく「番号（404）→ 状態（409）→ 入力（422）」。送れるかの確かめは、can_send と同じ `can_send?` を使う
- 主なエラー：404（スレッドがない）、409（can_send が false）、422（本文が空）
- 段階タグ：【コア】

#### 16-3-8. まとまり6：通知

- ヘッダーの未読件数は、③の unread_notifications_count を使う。通知用の窓口は増やさない
- 通知を作るのは、学生の応募（㉛）とスカウトへのマッチ（㉜）のあとの裏側のジョブ（本書7-5。PR272）。通知を作る窓口はない

**㊷ GET /api/company/notifications（通知の一覧）**

- 画面・操作：C10 の表示、ページ送り

```json
{
  "items": [
    {
      "id": 9,
      "kind": "recommended_student",
      "body": "自社サービスのバックエンド開発インターンに合いそうな学生がいます",
      "link_path": "/company/students/5?job_posting_id=12",
      "read_at": null,
      "created_at": "2026-09-22T09:00:00.000+09:00"
    }
  ],
  "pagination": { "page": 1, "per_page": 20, "total_count": 1, "total_pages": 1 }
}
```

- 自社宛ての通知だけを、新しい順（同じ時刻なら番号の大きい順）に返す
- read_at が null なら未読（画面は背景色と未読マークで区別する）
- 通知の表の対象の学生（student_profile_id）は、通知先を選ぶためにだけ使うので返さない
- link_path が企業の画面のパス（`/company/` で始まる）のときだけ移動する確認は、画面側で行う（本書6-5 C10。PR326）
- 段階タグ：【強み】

**㊸ POST /api/company/notifications/:id/read・㊹ POST /api/company/notifications/read_all（既読にする）**

- 画面・操作：C10 の通知を押したとき（㊸）、「すべて既読にする」（㊹）
- 送るもの：なし
- 返すもの：204。すでに既読でも 204（何度押しても同じ結果）。㊸ は、すでに既読なら最初に読んだ日時を残す。㊹ は、未読がなくても 204
- 確かめる順：㊸ は、自分宛ての通知の中から番号で探す。他社宛ての通知や、ない番号は 404（16-1-10）
- 画面側の動き：㊸が終わったら link_path へ移る。移った先の画面で③が呼ばれるので、ヘッダーの未読件数もそこで新しくなる。㊹ は画面を移らないので、終わったら一覧と③を取り直す
- 段階タグ：【強み】

**Rails での作り（順15）**

- 窓口は `Api::Company::NotificationsController`（企業の窓口の親を継ぐので、学生なら 403）。道順は `resources :notifications, only: :index` に、`post :read, on: :member`（1件ごとの操作）と `post :read_all, on: :collection`（全体への操作）
- 通知は会社ではなくアカウント（user_id）宛てなので、「今の会社」のヘルパーではなく、ログイン中の人の通知（`current_user.notifications`）から探す。1社のアカウントは1つなので、自社宛てと同じ意味になる
- 既読にする処理はモデルに置く：1件は `Notification#mark_read!`（未読のときだけ read_at を入れる）、まとめては `Notification.mark_all_read!`（未読をまとめて1本の UPDATE で既読にする）
- 通知を作る処理（通知先の選び方、本文、移動先）は本書7-3・7-5 と 6-5 C10

#### 16-3-9. まとまり7：プチ職業体験（Phase 7。本書12章）

- 講座の中身の形は、学生（㊻）と企業（㊾）で同じ。違うのは、学生には正解と選択肢ごとの解説を返さず（㊼で答えるたびに返す。PR377）、企業には最初から返すこと（PR373）
  - 形は `app/views/api/shared/_job_trial.json.jbuilder` の1か所で作り、正解と解説を入れるか（with_answers）だけを切り替える。片方だけ項目が増える食い違いを防ぐため
- 企業向けの説明（講座の説明とハードルの力）は ㉓ だけで返す。㊺㊻㊾ には入れない（学生の画面には出さない。PR405・PR406 は今は見送り）
- 解説・問題の文は Markdown のまま返し、画面で表示する（PR382）
- 学生の窓口（㊺〜㊽）は順18、企業の窓口（㊾）と、今ある窓口に足すもの（⑫⑬⑭⑲㉓）は順19 で作る（PR389）
- 段階タグ：【後付け】

**㊺ GET /api/student/job_trials（講座の一覧）**

- 画面・操作：S11 の表示

```json
{
  "items": [
    {
      "id": 1,
      "title": "テスト設計",
      "job_middle_category_id": 16,
      "work_process_ids": [4, 11],
      "completed": true
    }
  ]
}
```

- すべての講座を、講座の表示順（position）で返す。ページ分けしない（講座は数本の想定）
- completed：自分がその講座の自己分析を送っているか（修了済み。PR369）。自分の自己分析は1回の問い合わせでまとめて調べる
- 中分類・工程の名前は、⑦ の masters から画面が引く

**㊻ GET /api/student/job_trials/:id（講座の中身と、自分の自己分析）**

- 画面・操作：S12 の表示（講座と自己分析の両方のステップで使う）
- 番号は、すべての講座の中から探す。なければ 404

```json
{
  "id": 1,
  "title": "テスト設計",
  "job_middle_category_id": 16,
  "work_process_ids": [4, 11],
  "intro": "アプリの新しい機能は、…（Markdown）",
  "hurdles": [
    {
      "id": 1,
      "name": "理解する",
      "overview": "…", "difficulty": "…", "tips": "…", "example": "…", "goal": "…",
      "question": "…",
      "choices": [
        { "key": "A", "body": "すべてのユーザーが、いつでも…" },
        { "key": "B", "body": "クーポンの発行から30日以内の…" }
      ]
    }
  ],
  "self_analysis": null
}
```

- hurdles：講座の中の順番（position）で返す。choices には key と body だけを入れ、正解（correct）と解説（explanation）は入れない
- self_analysis：自分の自己分析。なければ null。あれば ㊽ の返事と同じ形。画面は、null でなければ「自己分析を書き直す」のボタンを出す（PR388）

**㊼ POST /api/student/job_trial_hurdles/:id/check（問題の正否の判定）**

- 画面・操作：S12 で選択肢を選んで「答える」を押したとき（PR398）
- 送るもの：`{ "choice": "B" }`（選んだ選択肢の key）
- 返すもの：200

```json
{ "correct": false, "explanation": "送料を含むかどうかは、まだ決まっていません" }
```

- correct：正解か。explanation：選んだ選択肢の解説。間違えたときも、正解の選択肢は返さない（正解するまで選び直す形のため）
- 何も記録しない（正否・やり直しの回数・講座の進み具合。PR355）
- 番号は、すべての講座のハードルの中から探す。なければ 404。ハードルの番号だけで一意に決まるので、講座の番号はパスに入れない（PR386）
- 主なエラー：422（choice がない、その問題にない key）。その問題にない key のときは `{ "choice": ["選択肢は、この問題の選択肢から選んでください"] }`（PR395。普通に画面を使う限りは出ない）
- 判定はモデルに置く（`JobTrialHurdle#check(key)`。正否と解説を返し、その問題にない key なら nil）

**㊽ PUT /api/student/job_trials/:id/self_analysis（自己分析の保存）**

- 画面・操作：S12 の自己分析の送信
- 送るもの：

```json
{
  "strength_hurdle_id": 1,
  "strength_reason": "…",
  "growth_hurdle_id": 4,
  "growth_reason": "curiosity",
  "growth_detail": "…",
  "next_step": "…"
}
```

- 返すもの：200。保存した自己分析

```json
{
  "job_trial_id": 1,
  "strength_hurdle_id": 1,
  "strength_reason": "…",
  "growth_hurdle_id": 4,
  "growth_reason": "curiosity",
  "growth_detail": "…",
  "next_step": "…",
  "same_hurdle": false,
  "created_at": "2026-09-29T10:00:00.000+09:00",
  "updated_at": "2026-09-29T10:00:00.000+09:00"
}
```

- 処理：自分のその講座の自己分析があれば上書きし、なければ作る（1人×1講座に1件。PR371）。初めて作ったときも 200 にする（作る・上書きを1つの窓口で行うため）
- 同時に2回押されて「1人×1講座に1件」の決まり（UNIQUE）に弾かれたときは、ほかの窓口と同じく 409（16-1-10）。モデルの `SelfAnalysis.save_for` が、応募と同じく ConflictError に変える
- 番号は、すべての講座の中から探す。なければ 404
- 受け取るのは上の6つだけ。学生や講座の番号を送られても無視する（自分のこの講座の自己分析として保存する）
- 主なエラー：422（選んだハードルがその講座のものでない、growth_reason が知らない値、必須の項目がない、400文字より長い）。6つすべて必須、記述3つは400文字まで（PR391。本書17-3-4）。エラーの項目名は送る名前（strength_hurdle_id など）
- 講座を最後まで通ったかは確かめない（PR387）
- same_hurdle：1-1 と 2-1 が同じハードルか（判定は Rails。PR360）

**㊾ GET /api/company/job_trials/:id（企業向けの講座の中身）**

- 画面・操作：C11 の表示
- 番号は、すべての講座の中から探す。なければ 404
- 返すもの：㊻ と同じ形から self_analysis を除き、choices に correct と explanation を加えたもの

```json
{ "key": "B", "body": "…", "correct": true, "explanation": "境目の、すぐ前とちょうどを確かめます" }
```
