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
  - Next.js の rewrites で、`/api/` で始まるものは Rails へ、それ以外は Next.js の画面へ振り分ける
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
  - return_to は `/` で始まるアプリ内のパスだけ受け付ける（本書6-5 C10 の通知のリンクと同じ考え方）
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
- これらは、選択肢の窓口（16-3 ⑦ GET /api/options）で、マスタ（職種・工程・技術・業界・都道府県・大学・学部・学科）と一緒に1回で返す
- 画面側は、これを使ってフォームの選択肢を作り、データの中の名前（`"published"`）を日本語（「掲載中」）に直して表示する。画面側に選択肢の表を手で書かない
- 判定も Rails で行い、結果を返す。画面側に同じ判定を書かない
  - 稼働条件の一致、カルチャーの一致・ずれ・近さ（16-3 ⑲・㉓）
  - 今押せる操作（16-3 ㉓ の available_actions）、メッセージを送れるか（16-3 ㊲ の can_send）
- 理由：画面側にも同じ表や判定を書くと、片方だけ直して食い違う（例：継続期間に選択肢を足したのに画面に出てこない、押せるのにエラーになるボタンができる）ため
- 割り切り：画面を開くときに、取りに行く回数が1回増える。選択肢はほとんど変わらないデータなので、一度取ったら使い回す

#### 16-1-10. HTTP ステータスとエラーの形

HTTP ステータス（返事の最初に付く3桁の番号）の使い分け

| 番号 | 意味 | 使う場面 | 画面側の動き |
| --- | --- | --- | --- |
| 200 | 成功 | 読む・保存・操作が成功した | そのまま表示 |
| 201 | 作った | 新規登録、募集の作成、応募、スカウト、メッセージの送信 | 同上 |
| 204 | 成功（返す中身なし） | ログアウト、メールアドレスの確認、通知の既読 | 同上 |
| 401 | ログインしていない | 未ログインで API を呼んだ。ログインに失敗した | main 側の画面ならログイン画面へ移す（16-1-6）。ログインの窓口では移さず、「ログインができません」を表示 |
| 403 | してはいけない | 種別が違う入口を呼んだ。CSRF の合言葉がない・違う | 「この操作はできません」 |
| 404 | 見つからない | 存在しない番号。見てよい範囲の外の番号（下の決まり） | 「見つかりません」 |
| 409 | 今の状態ではできない | 掲載中でない募集へのスカウト。応募済みの募集への応募。マッチしていない相手へのメッセージ | 「この操作は今はできません」と出し、最新の状態を読み直す |
| 422 | 入力が正しくない | 必須の項目が未入力。パスワードが短い。登録済みのメールアドレス | 項目ごとにエラーを表示 |
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

番号の探し方の決まり

- 窓口が受け取る番号は、パスの `:id` でも、job_posting_id のようなパラメータでも、その人が見てよい範囲の中から探す。範囲外の番号は 404 にする

| 番号の種類 | 企業から見てよい範囲 | 学生から見てよい範囲 |
| --- | --- | --- |
| 募集 | 自社の募集（状態は問わない） | 掲載中の募集と、自分とやりとりがある募集（一度も掲載していない募集は不可） |
| やりとり | 自社の募集のやりとり | 自分のやりとり |
| 学生 | すべての学生 | ― |
| 企業 | ― | すべての企業 |
| 通知 | 自社宛ての通知 | ― |

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
  - 最終活動日の「その日」、「30日以上」、開始時期の「今月から12ヶ月先まで」は、すべて日本時間で数える
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
| C4 候補者一覧 | `/company/candidacies`（募集別のタブ：`?job_posting_id=12`、見送りなども表示：`?show_all=true`） |
| C5 学生検索 | `/company/students`（募集を選んだ状態：`?job_posting_id=12`） |
| C6 学生詳細 | `/company/students/[id]`（募集のタブ：`?job_posting_id=12`） |
| C7 メッセージ管理 | `/company/messages`（学生のスレッドを開いた状態：`?student_id=5`） |
| C8 ログイン | `/company/login` |
| C9 新規登録 | `/company/signup` |
| C10 通知 | `/company/notifications` |

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

- `[id]` の部分には番号が入る（例：`/company/students/5`）
- 通知の移動先（notifications.link_path）は、通知先の募集のタブを選んだ状態の C6 にする。例：`/company/students/5?job_posting_id=12`
- 理由
  - 先頭を種別で分けると、ログインと種別の確認（16-1-6）を、フォルダ1つの共通部分に置くだけで、その種別の全画面に効かせられる
  - API と同じ単語にすると、画面と API の対応が一目で分かる
  - C7・S5 のスレッドは「企業×学生で1本」なので、相手が決まればスレッドが決まる。C4・C6 から来るときは相手の番号を持っているので、それをそのまま使える
  - S3 を candidacies としたのは、テーブル名（やりとり）に合わせたため。見た目の自然さより、対応の分かりやすさを優先した

#### 16-1-14. Phase 4-0 では決めないもの（Phase 5 で選ぶ）

- Rails で JSON を作る道具（jbuilder（ジェイビルダー）など）
- 画面側でデータを取るときの補助の部品（SWR（エスダブリューアール）、TanStack Query（タンスタック・クエリ）など）
- ページ分けの部品（Pagy（パギー）、Kaminari（カミナリ）など）
- いずれも道具選びで、16-1 の決まりに従っていれば、どれを選んでも API の形は変わらない

### 16-2. 画面ごとの URL 一覧

- 画面ごとに、画面の URL（Next.js のページ）と、その画面で呼ぶ API（`/api/`）を、タイミングの順に並べる
- すべての画面で、開いたときに ③ GET /api/me を呼ぶ（16-1-6）。下の表では、トップとログイン画面以外は省く
- ⑦ GET /api/options は、一度取ったら使い回す（まだ取っていなければ呼ぶ）
- ①〜㊹ は 16-3 の窓口の番号。「→」は成功したあとに移る画面

#### 16-2-1. 共通

| 画面 | タイミング | URL | 概要 |
| --- | --- | --- | --- |
| トップ | 画面の URL | `/` | 振り分けだけの画面 |
| | 開いたとき | ③ GET /api/me | ログイン中なら種別ごとのホーム、未ログインなら `/student/login` へ移る |
| 企業のヘッダー | タブ | `/company/profile`、`/company/job_postings`、`/company/candidacies`、`/company/students`、`/company/messages` | 会社情報、募集管理、候補者管理、学生検索、メッセージ |
| | ベルのアイコン | `/company/notifications` | 未読件数は ③ の unread_notifications_count |
| | ログアウト | ② DELETE /api/session | → `/company/login` |
| 学生のヘッダー | タブ | `/student/profile`、`/student/job_postings`、`/student/candidacies`、`/student/scouts`、`/student/messages` | マイページ、募集検索、募集管理、スカウト管理、メッセージ |
| | ログアウト | ② DELETE /api/session | → `/student/login` |

#### 16-2-2. 企業側

| 画面 | タイミング | URL | 概要 |
| --- | --- | --- | --- |
| C1 企業プロフィール編集 | 画面の URL | `/company/profile` | |
| | 開いたとき | ⑦ GET /api/options | 業種・人数の選択肢 |
| | 開いたとき | ⑧ GET /api/company/profile | 自社のプロフィール |
| | 保存 | ⑨ PATCH /api/company/profile | 本体を保存 |
| | 保存（アイコンを変えたとき） | ⑩ POST /api/company/profile/icon | ⑨の成功後に続けて送る |
| C2 募集一覧 | 画面の URL | `/company/job_postings` | 企業のホーム |
| | 開いたとき | ⑪ GET /api/company/job_postings | 自社の全募集 |
| | 募集新規作成 | `/company/job_postings/new` | 画面の移動だけ |
| | 編集する | `/company/job_postings/[id]/edit` | 画面の移動だけ |
| | この募集の候補者を見る | `/company/candidacies?job_posting_id=[id]` | 画面の移動だけ |
| | この募集でスカウト先を探す | `/company/students?job_posting_id=[id]` | 画面の移動だけ |
| C3 募集詳細編集（新規） | 画面の URL | `/company/job_postings/new` | |
| | 開いたとき | ⑦ GET /api/options | 職種・工程・技術などの選択肢 |
| | 開いたとき | ⑧ GET /api/company/profile | 会社名と、空欄のときの既定値 |
| | 保存 | ⑬ POST /api/company/job_postings | → `/company/job_postings` |
| C3 募集詳細編集（編集） | 画面の URL | `/company/job_postings/[id]/edit` | |
| | 開いたとき | ⑦ GET /api/options | 同上 |
| | 開いたとき | ⑧ GET /api/company/profile | 同上 |
| | 開いたとき | ⑫ GET /api/company/job_postings/:id | 募集の全項目 |
| | 保存 | ⑭ PATCH /api/company/job_postings/:id | → `/company/job_postings` |
| C4 候補者一覧 | 画面の URL | `/company/candidacies` | `?job_posting_id=`（タブ）、`?show_all=true`（見送りなども表示） |
| | 開いたとき | ⑪ GET /api/company/job_postings | タブに出す募集の名前 |
| | 開いたとき・タブや表示の切り替え・ページ送り | ㉑ GET /api/company/candidacies | やりとりの一覧 |
| | 詳細を見る | `/company/students/[学生id]?job_posting_id=[募集id]` | 画面の移動だけ |
| | メッセージ（マッチ以降の行のみ） | `/company/messages?student_id=[学生id]` | 画面の移動だけ |
| C5 学生検索 | 画面の URL | `/company/students` | `?job_posting_id=` と検索条件 |
| | 開いたとき | ⑦ GET /api/options | 条件の選択肢 |
| | 開いたとき | ⑪ GET /api/company/job_postings | 募集の選択肢 |
| | 募集を選んだとき | ⑫ GET /api/company/job_postings/:id | その募集の稼働条件を取り、条件のボタンを自動で選ぶ（推薦検索） |
| | 開いたとき・条件や並び順の変更・ページ送り | ㉒ GET /api/company/students | 学生の一覧 |
| | 詳細を見る | `/company/students/[id]?job_posting_id=[選んだ募集id]` | 画面の移動だけ |
| C6 学生詳細 | 画面の URL | `/company/students/[id]` | `?job_posting_id=`（最初に選ぶタブ） |
| | 開いたとき | ⑦ GET /api/options | 表示名、5軸の説明 |
| | 開いたとき | ㉓ GET /api/company/students/:id | 学生のプロフィールと、自社の全募集ぶんの状態・比較 |
| | スカウトをする（文面を入力して送信） | ㉔ POST /api/company/scouts | スカウトを送る |
| | スカウトの送信後 | ㉕ GET /api/company/students/:id/similar_students | 「この学生に似た学生」のポップアップ |
| | ポップアップの学生 | `/company/students/[その学生id]?job_posting_id=[募集id]` | 画面の移動だけ |
| | マッチする | ㉖ POST /api/company/candidacies/:id/match | 応募にマッチする |
| | 見送る | ㉗ POST /api/company/candidacies/:id/decline | 見送る |
| | 見送りを取り消す | ㉘ POST /api/company/candidacies/:id/undo_decline | スカウト由来の見送りを戻す |
| | 合格として保存 | ㉙ POST /api/company/candidacies/:id/pass | |
| | 不合格として保存 | ㉚ POST /api/company/candidacies/:id/fail | |
| | メッセージを送る | `/company/messages?student_id=[id]` | 画面の移動だけ |
| C7 メッセージ管理 | 画面の URL | `/company/messages` | `?student_id=`（開くスレッド） |
| | 開いたとき・ページ送り | ㊱ GET /api/company/message_threads | スレッド一覧 |
| | 開いたとき（student_id があるとき）・スレッドを選んだとき | ㊲ GET /api/company/students/:id/message_thread | その学生とのチャット |
| | 送信 | ㊳ POST /api/company/students/:id/message_thread/messages | メッセージを送る |
| | 学生名・アイコン | `/company/students/[id]` | 画面の移動だけ |
| C8 ログイン | 画面の URL | `/company/login` | |
| | 開いたとき | ③ GET /api/me | ログイン済みなら種別ごとのホームへ。未ログインでも合言葉の Cookie がそろう |
| | ログイン | ① POST /api/session | → return_to、なければ `/company/job_postings`（学生アカウントなら `/student/job_postings`） |
| | 新規登録はこちら | `/company/signup` | 画面の移動だけ |
| | 学生の方はこちら | `/student/login` | 画面の移動だけ |
| C9 新規登録 | 画面の URL | `/company/signup` | |
| | 開いたとき | ⑦ GET /api/options | 業種・人数の選択肢 |
| | ステップ1から進むとき | ④ POST /api/email_checks | メールアドレスの重複を確認 |
| | 登録する | ⑤ POST /api/company_registrations | アカウントとプロフィールを作り、自動でログイン |
| | 登録の直後（アイコンを選んでいたとき） | ⑩ POST /api/company/profile/icon | → `/company/job_postings` |
| | すでにアカウントをお持ちの方はこちら | `/company/login` | 画面の移動だけ |
| C10 通知 | 画面の URL | `/company/notifications` | `?page=` |
| | 開いたとき・ページ送り | ㊷ GET /api/company/notifications | 自社宛ての通知 |
| | 通知を押す | ㊸ POST /api/company/notifications/:id/read | → link_path（`/company/students/[id]?job_posting_id=[id]`） |
| | すべて既読にする | ㊹ POST /api/company/notifications/read_all | |

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
| | 開いたとき | ⑮ GET /api/student/profile | おすすめ順のとき、稼働条件のボタンを自分の条件で自動で選ぶ |
| | 開いたとき・条件や並び順の変更・ページ送り | ⑱ GET /api/student/job_postings | 募集の一覧。新着順にしたら稼働条件のボタンはすべてオフ、おすすめ順に戻したら自動で選び直す |
| | 詳細を見る | `/student/job_postings/[id]` | 画面の移動だけ |
| S3 募集管理 | 画面の URL | `/student/candidacies` | `?status=`（タグで絞る） |
| | 開いたとき・タグで絞る・ページ送り | ㉞ GET /api/student/candidacies | 応募済み・マッチ済みの募集 |
| | 詳細を見る | `/student/job_postings/[id]` | 画面の移動だけ |
| S4 スカウト管理 | 画面の URL | `/student/scouts` | |
| | 開いたとき・ページ送り | ㉟ GET /api/student/scouts | まだマッチしていないスカウト |
| | 詳細を見る | `/student/job_postings/[id]` | 画面の移動だけ |
| S5 メッセージ管理 | 画面の URL | `/student/messages` | `?company_id=`（開くスレッド） |
| | 開いたとき・ページ送り | ㊴ GET /api/student/message_threads | スレッド一覧 |
| | 開いたとき（company_id があるとき）・スレッドを選んだとき | ㊵ GET /api/student/companies/:id/message_thread | その企業とのチャット |
| | 送信 | ㊶ POST /api/student/companies/:id/message_thread/messages | メッセージを送る |
| | 企業名・アイコン | `/student/companies/[id]` | 画面の移動だけ |
| S6 募集詳細 | 画面の URL | `/student/job_postings/[id]` | |
| | 開いたとき | ⑦ GET /api/options | 表示名、応募理由の選択肢、5軸の説明 |
| | 開いたとき | ⑲ GET /api/student/job_postings/:id | 募集の中身、自分の状態、カルチャーの比較 |
| | 応募する（応募理由を選ぶ） | ㉛ POST /api/student/candidacies | 応募する |
| | 応募の完了後 | ㉝ GET /api/student/job_postings/:id/similar_job_postings | 「この募集に似た募集」のポップアップ |
| | ポップアップの募集 | `/student/job_postings/[その募集id]` | 画面の移動だけ |
| | マッチする（マッチ理由を選ぶ） | ㉜ POST /api/student/candidacies/:id/match | スカウトにマッチする |
| | メッセージへ | `/student/messages?company_id=[id]` | 画面の移動だけ |
| | 会社名 | `/student/companies/[id]` | 画面の移動だけ |
| S7 企業詳細 | 画面の URL | `/student/companies/[id]` | |
| | 開いたとき | ⑦ GET /api/options | 業種・人数の表示名 |
| | 開いたとき | ⑳ GET /api/student/companies/:id | 企業のプロフィールと掲載中の募集 |
| | 募集を押す | `/student/job_postings/[id]` | 画面の移動だけ |
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
| ⑲ | GET | /api/student/job_postings/:id | 学生 | S6 表示 | コア（カルチャーの比較は強み） |
| ⑳ | GET | /api/student/companies/:id | 学生 | S7 表示 | コア |
| ㉑ | GET | /api/company/candidacies | 企業 | C4 表示 | コア（隠す切り替えは強み、未返信タグは仕上げ） |
| ㉒ | GET | /api/company/students | 企業 | C5 検索 | コア（推薦検索・おすすめ順は強み、タグと最終活動の目安は仕上げ） |
| ㉓ | GET | /api/company/students/:id | 企業 | C6 表示 | コア（比較・♥印は強み、最終活動の目安は仕上げ） |
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
| unread_notifications_count | 企業なら未読の通知の件数。学生なら null（学生には通知がないため） |

**形B：学生向けの募集の行**（⑱・⑳・㉝・㉞・㉟）

```json
{
  "id": 12,
  "title": "自社サービスのバックエンド開発インターン",
  "is_open": true,
  "company": { "id": 3, "name": "株式会社サンプル", "icon_url": null, "industry_ids": [1] },
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
- company.icon_url も返す。どの画面でアイコンを出すかは Phase 6 で決める（本書10-2）

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

**形D：企業から見た、募集ごとのやりとりの状態**（㉓の job_postings の要素。㉔・㉖〜㉚の返事）

```json
{
  "id": 12,
  "title": "自社サービスのバックエンド開発インターン",
  "status": "published",
  "candidacy": {
    "id": 34, "origin": "application", "status": "unmatched",
    "reasons": ["business", "culture"], "matched_at": null
  },
  "available_actions": ["match", "decline"]
}
```

- candidacy：その学生とのやりとり。なければ null
- candidacy.reasons：応募理由・マッチ理由（C6 の♥印に使う）。値は応募理由の英語の名前（本書8-5 candidacy_reasons）
- available_actions：今この募集で押せるボタン。`scout`、`match`、`decline`、`undo_decline`、`pass`、`fail`、`send_message` のどれか
  - 画面は、ここに入っているボタンだけを出す。判定は Rails の1か所で行い、本書17-2 の状態遷移表と同じ内容にする
  - 判定の案は、16-3-6 の「状態を変える操作」の表のとおり

**形E：学生から見た、募集とのやりとりの状態**（⑲の一部。㉛・㉜の返事）

```json
{ "my_status": "applied", "my_candidacy_id": 34 }
```

- my_status：`none`（関係なし）、`applied`（応募済み）、`scouted`（スカウトあり）、`matched`（マッチ済み）のどれか。本書8-7 の計算のとおり（見送り・合格・不合格は見せない）
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
- 主なエラー：422（形式が正しくない、または登録済み）。例：`"errors": { "email": ["このメールアドレスは登録済みです"] }`
- 読むだけの処理だが、POST にする。GET だとメールアドレスが URL に載り、サーバーの記録に残りやすいため
- この窓口で確かめるのはメールアドレスだけ。パスワードの長さや確認用との一致は、画面側がその場で確かめ、最後の「登録する」で Rails が改めて確認する（本書17-3-2）
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
| 2 | industry_ids（業種） | 数値の配列 | |
| 2 | employee_size（人数） | 選択肢の名前 | |
| 2 | business_description（事業内容） | 文字列 | |
| 2 | about（どんな会社か） | 文字列 | |

- 必須の○は、データベースで空欄を許さない項目と、登録に欠かせない項目だけ。ステップ2は「あとで入力する」で飛ばせる（本書17-3-5）
- 返すもの：201、形A。自動でログインした状態になる
- 主なエラー：422（項目ごと。登録済みのメールアドレスを含む）。画面側は、エラーのある項目を含む最初のステップに戻して表示する
- 処理：users、company_profiles、company_industries を1つのトランザクションで作る
  - アイコンは含めない。登録が成功した直後に、画面が⑩へ送る
  - アイコンの保存に失敗しても、登録は取り消さない。「アイコンを保存できませんでした。あとで会社情報から登録してください」と出して、ホームへ進む
- 裏側のジョブ：なし
- 段階タグ：【コア】（terms_agreed の確認は【仕上げ】）

**⑥ POST /api/student_registrations（学生の新規登録）**

- 画面・操作：S9 の最後の「登録する」
- 使える人：誰でも
- 送るもの：全ステップの入力を1つにまとめる。student_profiles の列はそのままの名前で、付属テーブルは次の名前の配列で送る

| ステップ | 項目 |
| --- | --- |
| 1 | email、password、password_confirmation、terms_agreed（ここまで⑤と同じ）、name（必須） |
| 2 | university_id、faculty_id、department_id、grade、graduation_year、prefecture_id、activity_status |
| 3 | interested_job_middle_category_ids（興味のある職種）、interested_industry_ids（興味のある業界）、job_hunting_prefecture_ids（就活希望エリア） |
| 4 | skills（プログラミング歴）、links（外部リンク）、certifications（資格） |
| 5 | work_days_per_week、work_hours_per_day、duration_months、available_from、can_full_remote、can_partial_remote、can_onsite、commutable_prefecture_ids（出社できる都道府県）、work_note |
| 6 | personality_pace、personality_novelty、personality_collaboration、personality_decision、personality_atmosphere |
| 7 | self_pr_strength、self_pr_weakness、self_pr_future |

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
  - 省いた項目は空欄か既定値（勤務形態の3つは true、性格は 0）になる
  - skills の各要素は、technology_id か other_name のどちらか一方だけ（本書8-5 の CHECK と同じ）。level は必須
  - available_from は、月の1日の日付で送る
  - 数値や選択肢の範囲は、テーブル定義（本書8-5）と⑦に従う
- 返すもの・主なエラー：⑤と同じ
- 処理：users、student_profiles、付属テーブル7つを1つのトランザクションで作る。アイコンは⑤と同じ扱いで、⑰へ送る
- 裏側のジョブ：登録の完了後、その学生の似た学生リストを作る（本書7-5）【強み】
- 段階タグ：【コア】

**⑦ GET /api/options（選択肢とマスタ）**

- 画面・操作：選択肢や表示名を使うすべての画面（16-2）
- 使える人：誰でも（ログイン前の登録画面でも使うため）
- ページ分けしない。並び順は、マスタの position（表示順）のとおり

| まとまり | 中身 |
| --- | --- |
| enums | 画面に出す選択肢すべて：grade、activity_status、employee_size、skill_level、job_posting_status、work_style、purpose、hiring_possibility、candidacy_reason、candidacy_status、technology_category、work_process_stage、last_active_range |
| work_conditions | 稼働条件の数値の選択肢（週の日数、1日の時間、継続期間。本書5-6） |
| culture_axes | 性格・カルチャーの5軸の名前と、両端の説明（本書5-5） |
| masters | 職種（大分類の中に中分類）、工程（主に使う大分類つき）、技術、業界、都道府県、大学、学部（中に学科） |

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
      { "id": 1, "name": "企画・要件定義", "stage": "upstream", "planning": true, "job_major_category_ids": [1, 4] }
    ],
    "technologies": [{ "id": 1, "name": "Ruby", "category": "language" }],
    "industries": [{ "id": 1, "name": "Webサービス" }],
    "prefectures": [{ "id": 13, "name": "東京都" }],
    "universities": [{ "id": 1, "name": "〇〇大学" }],
    "faculties": [
      { "id": 1, "name": "工学部", "departments": [{ "id": 1, "name": "情報工学科" }] }
    ]
  }
}
```

- 大学を全件入れても数十KB程度。大学が多くて選びにくい場合は、画面側で文字を入れて絞り込む（全件を持っているので画面側だけでできる）
- 段階タグ：【コア】

#### 16-3-4. まとまり2：企業のプロフィールと募集

**⑧ GET /api/company/profile（自社のプロフィール）**

- 画面・操作：C1 の表示。C3 の会社名と、空欄のときの既定値
- 使える人：企業

```json
{
  "name": "株式会社サンプル",
  "industry_ids": [1, 3],
  "employee_size": "size_10_49",
  "business_description": "受託開発と自社サービスの運営",
  "about": "エンジニアが半数を占める、30人ほどの会社です",
  "icon_url": null
}
```

- 段階タグ：【コア】

**⑨ PATCH /api/company/profile（自社のプロフィールの保存）**

- 画面・操作：C1 の保存
- 送るもの：⑧と同じ項目（icon_url は除く）。フォームの全項目を送る。industry_ids は、送った内容でまるごと置き換える
- 必須：name、employee_size、business_description、about（本書5-9。industry_ids は任意）
- 返すもの：200、⑧と同じ形
- 主なエラー：422
- 裏側のジョブ：自社の、一度でも掲載した募集それぞれについて、似た募集リストを作り直す（本書7-5）【強み】
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
| updated_at | 最終更新日 |
| pending_application_count | 未対応の応募の件数。発生元が応募で、状態が未マッチのやりとりを数える（C4 の「未対応応募」タグと同じ数え方） |

- 理由
  - 行に出す情報は、企業が一覧で判断したいこと（どの募集が公開中か、どこに対応待ちがあるか）に絞った
  - 件数を「未対応の応募」1つにしたのは、「次に何をすべきか」に直結するため。総応募数や返信率などは、後付けの企業ダッシュボード（本書4-4）で扱う
  - 1社の募集は多くても数十件で、C4・C5・C6 でも全件の名前が必要なため、ページ分けしない
- 段階タグ：【コア】（件数などの行の情報は【仕上げ】）

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
  "main_job_middle_category_ids": [2],
  "related_job_middle_category_ids": [3],
  "main_work_process_ids": [5],
  "involved_work_process_ids": [1, 2],
  "technology_ids": [1, 7],
  "updated_at": "2026-09-21T18:00:00.000+09:00"
}
```

- 職種と工程は、「主な／関連する」「メインで担当する／関われる」で配列を分けて返す（フォームの入力欄とそのまま対応させるため）
- about・business_description が空欄なら、null のまま返す。画面側は、⑧の企業プロフィールの値を薄く表示する
- 段階タグ：【コア】

**⑬ POST /api/company/job_postings（募集の新規作成）**

- 画面・操作：C3 の保存（新規）
- 送るもの：⑫と同じ項目（id、published_at、updated_at は除く）
- 新規作成のときは、非公開か掲載中を選ぶ（本書17-2-2）
- 返すもの：201、⑫と同じ形
- 処理：job_postings と中間テーブル3つ（職種・工程・使用技術）を、1つのトランザクションで作る。状態が掲載中なら published_at を記録する
- 主なエラー：422（必須の項目（本書5-9）、選択肢の範囲、主と関連に同じ中分類がある、状態の誤り、など）
- 裏側のジョブ：一度でも掲載した募集を保存したら（初めて掲載したときを含む）、その募集の似た募集リストを作る（本書7-5）【強み】
- 段階タグ：【コア】

**⑭ PATCH /api/company/job_postings/:id（募集の保存・状態の変更）**

- 画面・操作：C3 の保存（編集・状態の変更）
- 送るもの：⑬と同じ。フォームの全項目を送り、配列は送った内容でまるごと置き換える
- 状態は、この窓口で他の項目と一緒に保存する（16-1-4 の例外）。3つの状態は自由に行き来できる（本書17-2-2）。初めて掲載したときだけ、最初に掲載した日を記録する
- 返すもの：200、⑫と同じ形
- 処理：初めて掲載中にしたときだけ published_at を記録する
- 主なエラー：422（⑬と同じもの、状態の移り変わりの誤り）
- 裏側のジョブ：⑬と同じ
- 募集を消す窓口は作らない（募集は消さず、状態で管理する。本書8-6）
- 段階タグ：【コア】（工程・カルチャーは【強み】、目的・求める人材は【仕上げ】。本書6-5 C3）

#### 16-3-5. まとまり3：学生のプロフィールと募集検索

**⑮ GET /api/student/profile（自分のプロフィール）**

- 画面・操作：S1 の表示。S2 で、おすすめ順のときに稼働条件のボタンを自動で選ぶために使う
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
- 処理：student_profiles と付属テーブル7つを、1つのトランザクションで保存する
- 裏側のジョブ：その学生の似た学生リストを作り直す（本書7-5）【強み】
- 段階タグ：【コア】（性格5軸は【強み】、外部リンク・資格・興味のある業界・就活希望エリアは【仕上げ】。本書6-6 S1）

**⑰ POST /api/student/profile/icon（学生のアイコン）**

- 画面・操作：S1 のアイコンの登録・差し替え（保存のとき、⑯の成功後に続けて送る）。S9 の登録の直後
- 中身は⑩と同じ（multipart/form-data の `icon`、PNG・JPEG・WebP で 2MB まで、返すものは `{ "icon_url": "..." }`）
- 段階タグ：タグ未付与（S1 のアイコンと同じ）

**⑱ GET /api/student/job_postings（募集検索）**

- 画面・操作：S2 の表示、条件・並び順の変更、ページ送り
- 使える人：学生

| 送るもの | 型 | 画面の条件 | 絞り込みの決まり |
| --- | --- | --- | --- |
| q | 文字列 | ① フリーワード | 次のどこかに、部分一致で含まれる募集：タイトル、インターンですること、必須要件、歓迎要件、使用技術の補足、会社名、使用技術の名前。空白で区切ると「すべてを含む」 |
| prefecture_ids[] | 数値の配列 | ② 勤務地 | 勤務地がどれかに当てはまる募集。フルリモートの募集は、勤務地に関係なく含める |
| work_days_per_week | 数値 | ③ 週の日数 | 募集の「週○日以上」が、この値以下 |
| work_hours_per_day | 数値 | ③ 1日の時間 | 募集の「1日○時間以上」が、この値以下 |
| duration_months | 数値 | ③ 継続期間 | 募集の「最低○ヶ月以上」が、この値以下 |
| available_from | 日付 | ③ 開始時期 | 募集が随時（空欄）か、募集の開始月がこの日以降 |
| work_styles[] | 選択肢の名前の配列 | ③ 勤務形態 | 募集の勤務形態が、この中に含まれる |
| weekend_ok | 真偽値 | ③ 土日OK | true なら、土日OK の募集だけ |
| industry_ids[] | 数値の配列 | ④ 業界 | 企業の業種のどれか1つが一致 |
| job_major_category_ids[] | 数値の配列 | ④ 職種（大分類だけ選んだとき） | その大分類に属する中分類を、主・関連のどちらかに持つ募集 |
| job_middle_category_ids[] | 数値の配列 | ④ 職種（中分類） | 主・関連のどれか1つが一致。フロントエンド・バックエンドを選んだときは、フルスタックの募集も含める |
| planning | 真偽値 | ④ 企画・設計から関われる | true なら、工程（メイン・関われる）に「企画・設計から関われる」の対象の工程を持つ募集だけ |
| sort | `recommended`／`newest` | 並び順 | 省略時は recommended |
| page | 数値 | ページ | 省略時は1 |

- 出すのは、掲載中の募集だけ
- 条件を指定した項目が未入力の募集は、結果に出さない（本書5-10）。ただし、開始時期の空欄は「随時」として常に一致させる
- 並び順
  - recommended（おすすめ順）：f(募集, 学生) の高い順（本書7章）。点数が同じなら新着順。プロフィールがほとんど空の学生でも分岐せず、そのままおすすめ順で出す
  - newest（新着順）：最初に掲載した日時の新しい順
  - おすすめ順は並び順だけを変え、絞り込みは送られた条件だけで行う（見えない絞り込みはかけない。本書7-3）
- 画面側の動き（S2 の稼働条件のボタン）
  - おすすめ順のとき：⑮の稼働条件（入力済みの項目だけ）に合わせて、週の日数、1日の時間、継続期間、開始時期、勤務形態、勤務地（出社できる都道府県）のボタンを自動で選ぶ。手動で選び直せる
  - 新着順に切り替えたとき：稼働条件のボタンをすべてオフにする。おすすめ順に戻したら、もう一度自動で選ぶ
  - ボタンの選択肢は、稼働条件の共通形式（本書5-6）と同じ
- 返すもの：200。items は形B、pagination あり
- 段階タグ：【コア】（おすすめ順とボタンの自動選択、「企画・設計から関われる」は【強み】。稼働条件の手動の選択、土日OK、業界、フルスタックのルールは【仕上げ】）

**⑲ GET /api/student/job_postings/:id（募集詳細）**

- 画面・操作：S6 の表示
- 使える人：学生。見られる範囲は、掲載中の募集と、自分とやりとりがある募集（非公開・終了なら is_open が false）。一度も掲載していない募集と、関係のない非公開・終了の募集は 404（16-1-10）

```json
{
  "id": 12,
  "title": "自社サービスのバックエンド開発インターン",
  "is_open": true,
  "company": { "id": 3, "name": "株式会社サンプル", "icon_url": null, "industry_ids": [1] },
  "about": "エンジニアが半数を占める、30人ほどの会社です",
  "business_description": "受託開発と自社サービスの運営",
  "internship_details": "…",
  "growth": null,
  "culture_comparison": [
    { "axis": "pace", "job_posting_value": -1, "my_value": 1, "result": "mismatch" },
    { "axis": "novelty", "job_posting_value": 2, "my_value": 0, "result": "not_judged" }
  ],
  "my_status": "scouted",
  "my_candidacy_id": 34
}
```

- 上の例のほかに、⑫と同じ名前で次の項目も返す：稼働条件（min_work_days_per_week、min_work_hours_per_day、min_duration_months、start_month、work_style、work_style_note、prefecture_id、work_location_note、weekend_ok、work_note）、hourly_wage、culture_ の5つ、requirements、preferred_requirements、technology_note、職種・工程・使用技術の配列、published_at
- 返さない項目：status（代わりに is_open）、purpose、hiring_possibility、target_grade、target_graduation_year、target_other（学生に見せない項目）
- about・business_description：募集側が空欄なら、企業プロフィールの値を入れて返す（学生の画面では区別が要らないため）
- culture_comparison：result は Rails が本書5-5 のルールで判定する。`match`（一致）、`mismatch`（ずれ）、`not_judged`（どちらかが中央なので判定しない）のどれか。㉓の比較と同じ部品を使う
- my_status・my_candidacy_id：形E
- 段階タグ：【コア】（culture_comparison は【強み】）

**⑳ GET /api/student/companies/:id（企業詳細）**

- 画面・操作：S7 の表示
- 使える人：学生（すべての企業を見られる）

```json
{
  "id": 3,
  "name": "株式会社サンプル",
  "industry_ids": [1],
  "employee_size": "size_10_49",
  "business_description": "受託開発と自社サービスの運営",
  "about": "エンジニアが半数を占める、30人ほどの会社です",
  "icon_url": null,
  "job_postings": []
}
```

- job_postings：その企業の掲載中の募集。形B で、ページ分けしない
- 段階タグ：【コア】

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
      "created_at": "2026-09-21T09:00:00.000+09:00",
      "matched_at": null
    }
  ],
  "pagination": { "page": 1, "per_page": 20, "total_count": 8, "total_pages": 1 }
}
```

- tag（Rails が計算する）
  - `pending_application`（未対応応募）：応募で、未マッチ
  - `scouted`（スカウト済み）：スカウトで、未マッチ
  - `unreplied`（未返信）：マッチ以降で、スレッドの最後の送信者が学生
  - それ以外は null
- 理由：行には「誰が、どの段階か」が分かる最低限を載せる。並び順は単純で予想しやすい形にし、「対応が必要なものを上に並べる」は、タグで見分けられるので作らない
- 段階タグ：【コア】（show_all は【強み】、unreplied のタグと行の学生情報・並び順は【仕上げ】）

**㉒ GET /api/company/students（学生検索）**

- 画面・操作：C5 の表示、条件・並び順の変更、ページ送り

| 送るもの | 画面の条件 | 絞り込みの決まり |
| --- | --- | --- |
| job_posting_id | 募集の選択 | 選ぶと、画面がその募集の稼働条件（入力済みの項目）で条件のボタンを自動で選ぶ（推薦検索。⑫で取る）。タグの基準と、おすすめ順にも使う |
| q | フリーワード | 自己PR（3つの問い）、資格名、プログラミング歴の「その他」の名前に、部分一致で含まれる。空白で区切ると「すべてを含む」。名前と大学名は対象にしない |
| work_days_per_week | 週の日数 | 学生の「週○日まで」が、この値以上 |
| work_hours_per_day | 1日の時間 | 学生の「1日○時間まで」が、この値以上 |
| duration_months | 継続期間 | 学生の「○ヶ月以上続けられる」が、この値以上 |
| start_month | 開始時期 | 学生の開始可能月が、この月以前 |
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
  - 最終活動日から30日以上たった学生は出さない（本書5-4）。活動状況が「今は探していない」の学生は外さない
  - 条件を指定した項目が未入力の学生は、結果に出さない（本書5-10）
  - おすすめ順は並び順だけを変え、絞り込みは送られた条件だけで行う（本書7-3）。自動で選ばれたボタンは、手動で外せる
  - 性格は、絞り込みに使わない（本書2-4）
  - おすすめ順以外の並び順を「最終活動が新しい順」にするのは、最近使っている学生ほど返信が来やすいため（本書2-3 の V3）
- 返すもの：200。items は形C に次の2つを加えたもの、pagination あり
  - candidacy：募集を選んだときの、その募集とのやりとり（`{ "id", "origin", "status" }`。なければ null）。募集を選ばないときは常に null
  - candidacy_count：自社の募集とのやりとりの件数（募集を選ばないときのタグ用）
- タグ（画面の表示）
  - 募集を選んだとき：candidacy の状態に応じて、未対応応募、スカウト済み、マッチ、見送り、合格、不合格のタグを出す
  - 募集を選ばないとき：candidacy_count が1以上なら「やりとりあり」のタグを出す
  - 応募済みの学生も含めるのは、同じ募集にすでに応募している学生にスカウトしようとすると、エラー（1つの募集×学生でやりとりは1件だけ）になるため
- 段階タグ：【コア】（推薦検索・おすすめ順は【強み】、タグと最終活動の目安は【仕上げ】）

**㉓ GET /api/company/students/:id（学生詳細）**

- 画面・操作：C6 の表示
- 使える人：企業（すべての学生を見られる。30日以上活動のない学生も、C4 や通知から開けるように、ここでは外さない）

```json
{
  "student": { "…⑮と同じ項目…": "…", "icon_url": null, "last_active_range": "within_7_days" },
  "job_postings": [
    {
      "id": 12, "title": "自社サービスのバックエンド開発インターン", "status": "published",
      "candidacy": {
        "id": 34, "origin": "application", "status": "unmatched",
        "reasons": ["business", "culture"], "matched_at": null
      },
      "available_actions": ["match", "decline"],
      "comparison": {
        "work_conditions": [
          { "item": "work_days_per_week", "student_value": 3, "job_posting_value": 2, "result": "match" }
        ],
        "job_middle_category_ids": { "matched": [2] },
        "technology_ids": { "matched": [1] },
        "industry_ids": { "matched": [1] },
        "culture": [
          { "axis": "pace", "student_value": -1, "job_posting_value": -2, "distance": 1, "close": true }
        ]
      }
    }
  ]
}
```

- student：学生のプロフィールの全項目（マッチ前でもすべて見せる）
- job_postings：自社の全募集（掲載中以外も含む）。各要素は形D に comparison を加えたもの。並び順は⑪と同じ。最初に選ぶタブは画面側が決める（遷移元の job_posting_id、なければ先頭）
- comparison（Rails が計算する。⑲と同じ部品）
  - work_conditions：稼働条件の項目ごとに `match`（一致）、`mismatch`（不一致）、`not_judged`（どちらかが未入力）。照合のルールは本書5-6
  - job_middle_category_ids・technology_ids・industry_ids：一致した id の一覧。どちらかが未入力なら null（画面は「未入力」と出す）
  - culture：軸ごとの値と距離。close は、距離が1以下で、どちらも中央でないときに true（画面は背景を薄いオレンジにする）
- 段階タグ：【コア】（comparison と reasons は【強み】、last_active_range は【仕上げ】）

**状態を変える操作（㉔・㉖〜㉜）の共通の決まり**

- 返すもの
  - 企業側の操作：200（スカウトは 201）。形D（その募集の分）を返す。画面を読み直さずにボタンを出し直せる
  - 学生側の操作：200（応募は 201）。形E を返す
- 今の状態ではできない操作は 409（例：企業がスカウトに「マッチする」を押した、掲載中でない募集に応募した）
- 裏側のジョブは、トランザクションが確定したあとに動かす（本書7-5）
- 「できる状態」は、本書6-5 C6・6-6 S6 の「状態ごとの操作」を書き直したもの（案）。正式な表は本書17-2 で作る

| 窓口 | 送るもの | できる状態（案） | 1つのトランザクションで行うこと | 裏側のジョブ |
| --- | --- | --- | --- | --- |
| ㉔ POST /api/company/scouts（スカウト） | job_posting_id、student_profile_id、body（スカウト文） | 募集が掲載中で、その募集×学生のやりとりがまだない | やりとり（スカウト・未マッチ）、スレッド（なければ）、メッセージ、スカウトメッセージを作る。スレッドの last_message_at を更新 | なし |
| ㉖ POST /api/company/candidacies/:id/match（マッチ） | なし | 発生元が応募で、状態が未マッチか見送り。募集が掲載中 | 状態をマッチにし、matched_at を記録。スレッドを作る（なければ） | なし |
| ㉗ POST /api/company/candidacies/:id/decline（見送り） | なし | 状態が未マッチ（発生元は問わない） | 状態を見送りにする | 似た募集を持つ他社への通知を作る（本書7-5） |
| ㉘ POST /api/company/candidacies/:id/undo_decline（見送りの取り消し） | なし | 発生元がスカウトで、状態が見送り | 状態を未マッチに戻す | なし |
| ㉙ POST /api/company/candidacies/:id/pass（合格） | なし | 状態がマッチか不合格 | 状態を合格にする | なし |
| ㉚ POST /api/company/candidacies/:id/fail（不合格） | なし | 状態がマッチか合格 | 状態を不合格にする | なし |
| ㉛ POST /api/student/candidacies（応募） | job_posting_id、reasons（配列、最低1つ） | 募集が掲載中で、その募集とのやりとりがまだない | やりとり（応募・未マッチ）、応募理由、reason_mask を作る | 推薦の更新（本書7-5 の応募・マッチ時の手順） |
| ㉜ POST /api/student/candidacies/:id/match（マッチ） | reasons（配列、最低1つ） | 発生元がスカウトで、状態が未マッチか見送り。募集が掲載中 | 状態をマッチにし、matched_at、応募理由、reason_mask を保存 | 推薦の更新（同上） |

- reasons の値：business、industry、job_category、work_process、internship_details、culture、hourly_wage、work_conditions、technologies（本書8-5 candidacy_reasons）
- 主なエラー：404（他社・他人のやりとり、見てよい範囲の外の募集）、409（上の「できる状態」でない）、422（スカウト文が空、応募理由が0個、など。長さの上限は本書17-3-2）
- ㉔ の student_profile_id は、すべての学生を指定できる
- 段階タグ：㉔・㉖・㉛・㉜は【コア】、㉗〜㉚は【強み】

**㉕ GET /api/company/students/:id/similar_students（この学生に似た学生）**

- 画面・操作：C6 のスカウト送信後のポップアップ
- 送るもの：job_posting_id（必須。スカウトに使った募集）
- 返すもの：200。最大5人の形C（items で包む。ページ分けしない）
- 選び方（本書7-3・7-5）：その学生の似た学生リストを score の高い順に見て、次に当てはまる学生を除いた上位5人。5人に満たなければ、ある分だけ
  - その募集の稼働条件（入力済みの項目）に合わない学生（未入力の項目がある学生も、本書5-10 のとおり外す）
  - 30日以上活動のない学生
  - その募集とやりとりがある学生
- 段階タグ：【強み】

**㉝ GET /api/student/job_postings/:id/similar_job_postings（この募集に似た募集）**

- 画面・操作：S6 の応募完了のポップアップ
- 返すもの：200。最大5件の形B（items で包む。ページ分けしない）
- 選び方：その募集の似た募集リストを score の高い順に見て、次に当てはまる募集を除いた上位5件。5件に満たなければ、ある分だけ
  - 学生の入力済みの稼働条件に合わない募集
  - 自分とやりとりがある募集
  - 掲載中以外の募集
- 段階タグ：【強み】

**㉞ GET /api/student/candidacies（募集管理）**

- 画面・操作：S3 の表示、タグでの絞り込み、ページ送り
- 出すもの（本書8-7）：発生元が応募のもの（状態は問わない）と、発生元がスカウトで状態がマッチ・合格・不合格のもの
- 送るもの：status（`applied` か `matched`。省略するとすべて）、page
- 返すもの：200。items は形B に candidacy_id と my_status（`applied`／`matched`）を加えたもの、pagination あり
- 並び順：やりとりが始まった日の新しい順
- 段階タグ：【コア】（status での絞り込みは【仕上げ】）

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

- partner：相手（企業から見れば学生、学生から見れば企業）
- 並び順：最後のメッセージの新しい順（last_message_at）
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
  ]
}
```

- messages：古い順に全件返す。1組の会話は短い想定なので、ページ分けしない（Phase 8 の重さの点検で見直す）
- is_mine：自分が送ったメッセージなら true（画面で左右に分けて出すため）
- scout：スカウト文のときだけ、どの募集のスカウトかを入れる（ふつうのメッセージなら null）
- can_send：今送れるか。Rails が本書5-2 のルール（その企業×学生のやりとりに、マッチ・合格・不合格が1つでもあるか）で判定する。画面は、false なら入力欄を使えなくする
- matched_job_postings：その相手とマッチしている募集（マッチ・合格・不合格のもの）。学生側にも同じ形で返し、合格・不合格の区別は見せない
- 主なエラー：404（相手が存在しない、または、まだスレッドがない）
- 段階タグ：【コア】（matched_job_postings は【仕上げ】）

**㊳ POST /api/company/students/:id/message_thread/messages・㊶ POST /api/student/companies/:id/message_thread/messages（送信）**

- 画面・操作：C7・S5 の送信
- 送るもの：body（本文、必須。長さの上限は本書17-3-2）
- 返すもの：201。作ったメッセージ1件を、㊲の messages の1要素と同じ形で返す
- 処理：メッセージを作り、スレッドの last_message_at を更新する（1つのトランザクション）
- 主なエラー：404（スレッドがない）、409（can_send が false）、422（本文が空）
- 段階タグ：【コア】

#### 16-3-8. まとまり6：通知

- ヘッダーの未読件数は、③の unread_notifications_count を使う。通知用の窓口は増やさない
- 通知を作るのは、見送り（㉗）のあとの裏側のジョブ（本書7-5）。通知を作る窓口はない

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

- 自社宛ての通知だけを、新しい順に返す
- read_at が null なら未読（画面は背景色と未読マークで区別する）
- link_path が `/` で始まるときだけリンクにする確認は、画面側で行う（本書6-5 C10）
- 段階タグ：【強み】

**㊸ POST /api/company/notifications/:id/read・㊹ POST /api/company/notifications/read_all（既読にする）**

- 画面・操作：C10 の通知を押したとき（㊸）、「すべて既読にする」（㊹）
- 送るもの：なし
- 返すもの：204。すでに既読でも 204（何度押しても同じ結果）
- 画面側の動き：㊸が終わったら link_path へ移る。移った先の画面で③が呼ばれるので、ヘッダーの未読件数もそこで新しくなる
- 段階タグ：【強み】
