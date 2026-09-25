// 画面の見出し（h1）。全画面の見出しの大きさを、ここ1か所で決める

import type { ReactNode } from "react";

export function PageTitle({ children }: { children: ReactNode }) {
  return <h1 className="text-xl font-bold">{children}</h1>;
}
