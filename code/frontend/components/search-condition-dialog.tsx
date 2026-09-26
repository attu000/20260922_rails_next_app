// 検索の条件のボタンと、押すと開くポップアップ（shadcn/ui の Dialog）。
// 募集一覧（学生のホーム）の勤務地・職種・技術で使い回す。条件の欄を増やすとき（稼働条件、企業の学生検索など）も使える。
//
// ポップアップの中で選んだものは、その場で使う側の下書きに入る（「決定」を押し忘れても消えない。PR201）。
// 検索は、ポップアップを閉じても走らない。横の「検索する」を押したときだけ（PR192）

import type { ReactNode } from "react";
import { cn } from "cn";
import { Button, buttonVariants } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

type SearchConditionDialogProps = {
  // ボタンとポップアップの題名（例："勤務地"）
  label: string;
  // 選んでいる数。0 より大きければ、ボタンに（2）のように出し、見た目を変える
  count: number;
  // 「この条件をクリア」を押したとき
  onClear: () => void;
  // 題名の下に出す一言（任意）
  description?: string;
  // ポップアップの幅など（任意。例：都道府県を多くの列で並べるときに広げる）
  contentClassName?: string;
  // ポップアップの中身（選ぶ部品）
  children: ReactNode;
};

export function SearchConditionDialog({
  label,
  count,
  onClear,
  description,
  contentClassName,
  children,
}: SearchConditionDialogProps) {
  return (
    <Dialog>
      {/* 条件欄は form の中にあるので、押しても検索が走らないよう type="button" を付ける */}
      <DialogTrigger type="button" className={buttonVariants({ variant: count > 0 ? "secondary" : "outline" })}>
        {label}
        {count > 0 && `（${count}）`}
      </DialogTrigger>
      {/* 中身が長ければ、題名と下のボタンは動かさず、中身だけを縦に動かせるようにする */}
      <DialogContent className={cn("max-h-[85vh] grid-rows-[auto_minmax(0,1fr)_auto] sm:max-w-2xl", contentClassName)}>
        <DialogHeader>
          <DialogTitle>{label}</DialogTitle>
          {description && <DialogDescription>{description}</DialogDescription>}
        </DialogHeader>
        <div className="-mx-1 overflow-y-auto px-1">{children}</div>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClear}>
            この条件をクリア
          </Button>
          <DialogClose render={<Button type="button" />}>閉じる</DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
