// 外部リンクの入力欄。行を足す・消す形で、1行に「URL・表示名」を持つ（プログラミング歴の部品と同じ作り）。
// 詳しくは design/designs/ページ設計.md の 6-6 S1、API設計.md の 16-3 ⑥⑯。順17。
// 行の値の変換（Rails の形 ⇔ フォームの形）と、その場での確認もここに置く

import { SHORT_TEXT_MAX_LENGTH, toFieldErrorItems, type FieldErrors } from "@/components/form-fields";
import { Button } from "@/components/ui/button";
import { FieldError, FieldLegend, FieldSet } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import type { StudentLink } from "@/lib/student-profile";

// 行数と URL の長さの上限。Rails と同じ値を使う（権限_バリデーション.md の 17-3-4）
export const LINKS_MAX = 20;
const URL_MAX_LENGTH = 500;
// http:// か https:// で始まり、その後ろに空白でない文字が続く（Rails の StudentLink::URL_FORMAT と同じ。PR338）
export const HTTP_URL_FORMAT = /^https?:\/\/\S+$/i;

// フォームが持つ1行の値。入力欄にそのまま入れるため、文字で持つ（表示名の空欄は ""）
export type LinkRow = {
  // React が行を見分ける印。消したときに、ほかの行の入力が入れ替わらないようにするため
  key: string;
  url: string;
  title: string;
};

// 行の印の通し番号（画面を開いている間だけ使う）
let nextRowKey = 0;

function newRowKey(): string {
  nextRowKey += 1;
  return `link-${nextRowKey}`;
}

// Rails の返事 → フォームの行
export function toLinkRows(links: StudentLink[]): LinkRow[] {
  return links.map((link) => ({ key: newRowKey(), url: link.url, title: link.title ?? "" }));
}

// フォームの行 → Rails に送る形。URL の前後の空白は落とす（貼り付けたときに付きやすいため）。
// 表示名の空欄は "" のまま送る（Rails が null にそろえる）
export function toLinkRequest(rows: LinkRow[]) {
  return rows.map((row) => ({ url: row.url.trim(), title: row.title }));
}

// その場での確認（権限_バリデーション.md の 17-3-2）。Rails と同じ文言・同じ名前（links[0].url など）で返す。
// Rails も同じ確認をするので、ここをすり抜けても守られる
export function validateLinkRows(rows: LinkRow[]): FieldErrors {
  const errors: FieldErrors = {};
  rows.forEach((row, index) => {
    const url = row.url.trim();
    if (url === "") {
      errors[`links[${index}].url`] = ["URLを入力してください"];
    } else if (url.length > URL_MAX_LENGTH) {
      errors[`links[${index}].url`] = [`URLは${URL_MAX_LENGTH}文字以内で入力してください`];
    } else if (!HTTP_URL_FORMAT.test(url)) {
      errors[`links[${index}].url`] = ["URLはhttp://かhttps://で始まる形で入力してください"];
    }
    if (row.title.length > SHORT_TEXT_MAX_LENGTH) {
      errors[`links[${index}].title`] = [`表示名は${SHORT_TEXT_MAX_LENGTH}文字以内で入力してください`];
    }
  });
  return errors;
}

type LinkRowsFieldProps = {
  rows: LinkRow[];
  // フォーム全体のエラー。links[0].url などの行のエラーと、links（欄全体）のエラーを拾って出す
  errors: FieldErrors;
  onChange: (rows: LinkRow[]) => void;
};

// 部品は、フォームの中ではなくファイルの一番上の段に置く（打っている途中でカーソルが外れないように）
export function LinkRowsField({ rows, errors, onChange }: LinkRowsFieldProps) {
  function updateRow(index: number, changes: Partial<LinkRow>) {
    onChange(rows.map((row, rowIndex) => (rowIndex === index ? { ...row, ...changes } : row)));
  }

  return (
    <FieldSet>
      <FieldLegend variant="label">外部リンク</FieldLegend>

      {rows.length > 0 && (
        <ul className="space-y-2">
          {rows.map((row, index) => {
            const urlErrors = errors[`links[${index}].url`];
            const titleErrors = errors[`links[${index}].title`];
            const allMessages = [...(urlErrors ?? []), ...(titleErrors ?? [])];
            return (
              <li key={row.key} className="rounded-lg border p-3">
                <div className="flex flex-wrap items-center gap-2">
                  <Input
                    aria-label={`${index + 1}行目のURL`}
                    type="url"
                    placeholder="https://github.com/…"
                    value={row.url}
                    onChange={(event) => updateRow(index, { url: event.target.value })}
                    aria-invalid={urlErrors ? true : undefined}
                    className="w-72 max-w-full"
                  />
                  <Input
                    aria-label={`${index + 1}行目の表示名`}
                    placeholder="表示名（例：GitHub）"
                    value={row.title}
                    onChange={(event) => updateRow(index, { title: event.target.value })}
                    aria-invalid={titleErrors ? true : undefined}
                    className="w-48"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => onChange(rows.filter((_, rowIndex) => rowIndex !== index))}
                  >
                    削除
                  </Button>
                </div>
                {/* この行のエラーは、この行の下にまとめて出す */}
                <FieldError errors={toFieldErrorItems(allMessages.length > 0 ? allMessages : undefined)} />
              </li>
            );
          })}
        </ul>
      )}

      {/* 20行になったら、足すボタンを出さない */}
      {rows.length < LINKS_MAX && (
        <div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onChange([...rows, { key: newRowKey(), url: "", title: "" }])}
          >
            ＋ リンクを足す
          </Button>
        </div>
      )}

      {/* 欄全体のエラー（21件以上など） */}
      <FieldError errors={toFieldErrorItems(errors.links)} />
    </FieldSet>
  );
}
