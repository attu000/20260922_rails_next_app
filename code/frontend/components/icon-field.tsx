"use client";

// アイコン欄。企業プロフィール編集（C1）とマイページ（S1）で使い回す（design/designs/API設計.md の 16-3 ⑩⑰、技術構成.md の 9-3）。
// 選んだファイルは、保存を押すまで Rails に送らず、ブラウザの中だけでプレビューを出す。
// 保存では、本体を保存したあとに uploadIcon で続けて送る（本体の成功後に送る決まり）

import { useEffect, useState, type ChangeEvent } from "react";
import { ProfileIcon } from "@/components/profile-icon";
import { toFieldErrorItems } from "@/components/form-fields";
import { Field, FieldDescription, FieldError, FieldLabel } from "@/components/ui/field";
import { apiFetch } from "@/lib/api";

// 受け付ける形式と大きさ。Rails と同じ値を使う（app/models/concerns/icon_attachment.rb）
const ICON_CONTENT_TYPES = ["image/png", "image/jpeg", "image/webp"];
const ICON_MAX_BYTES = 2 * 1024 * 1024;

// 選んだファイルとプレビューを持つ。保存のときに親のフォームが file を使い、送れたら clear を呼ぶ
export function useIconPicker() {
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  // ファイルを選ぶ欄の番号。数を変えると、React が欄を捨てて作り直すので、選んだファイル名の表示も空に戻る（PR206）。
  // 欄を直接つかむ ref を使わないのは、描画の途中で ref を読まない決まり（ESLint の react-hooks/refs）に合わせるため
  const [inputKey, setInputKey] = useState(0);

  // プレビューの URL は、使い終わったら（別のファイルを選んだ、画面を離れた）ブラウザに返す
  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    const selected = event.target.files?.[0] ?? null;
    setFile(selected);
    setPreviewUrl(selected ? URL.createObjectURL(selected) : null);
  }

  // 送り終えたら、選んだファイルとプレビューを消し、欄を作り直して空にする
  function clear() {
    setFile(null);
    setPreviewUrl(null);
    setInputKey((key) => key + 1);
  }

  return { file, previewUrl, inputKey, handleChange, clear };
}

export type IconPicker = ReturnType<typeof useIconPicker>;

// その場での確認（形式・2MB）。文言は Rails と同じ。問題がなければ undefined
export function validateIconFile(file: File | null): string[] | undefined {
  if (!file) return undefined;
  const errors: string[] = [];
  if (!ICON_CONTENT_TYPES.includes(file.type)) {
    errors.push("アイコンはPNG・JPEG・WebPのいずれかにしてください");
  }
  if (file.size > ICON_MAX_BYTES) {
    errors.push("アイコンは2MB以下にしてください");
  }
  return errors.length > 0 ? errors : undefined;
}

// アイコンを送り、新しい icon_url を返す。ファイルは multipart/form-data で送る（apiFetch が FormData を見て切り替える）
export async function uploadIcon(path: string, file: File): Promise<string | null> {
  const formData = new FormData();
  formData.append("icon", file);
  const result = await apiFetch<{ icon_url: string | null }>(path, { method: "POST", body: formData });
  return result.icon_url;
}

type IconFieldProps = {
  picker: IconPicker;
  // 保存済みのアイコンの URL。未登録なら null
  currentUrl: string | null;
  // 会社名・氏名。アイコンがないときの頭文字に使う
  name: string;
  errors: string[] | undefined;
  // ファイルを選んだとき、親のフォームでも何かしたい場合（「保存しました」を消すなど）
  onFileChange?: () => void;
};

// 丸いアイコン（プレビューがあればそれ）＋ファイルを選ぶ欄＋説明＋エラー
export function IconField({ picker, currentUrl, name, errors, onFileChange }: IconFieldProps) {
  return (
    <Field data-invalid={errors ? true : undefined}>
      <FieldLabel htmlFor="icon">アイコン</FieldLabel>
      <div className="flex items-center gap-4">
        <ProfileIcon src={picker.previewUrl ?? currentUrl} name={name} size="lg" />
        <input
          key={picker.inputKey}
          id="icon"
          type="file"
          accept={ICON_CONTENT_TYPES.join(",")}
          onChange={(event) => {
            picker.handleChange(event);
            onFileChange?.();
          }}
          aria-invalid={errors ? true : undefined}
          className="text-sm"
        />
      </div>
      <FieldDescription>PNG・JPEG・WebP、2MBまで。保存を押すと登録されます</FieldDescription>
      <FieldError errors={toFieldErrorItems(errors)} />
    </Field>
  );
}
