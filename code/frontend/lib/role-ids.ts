// 「メインの番号の一覧」と「サブの番号の一覧」を、1つのチェックの一覧として扱うための関数。
// 募集詳細編集の職種（主な／関連する。PR234）と工程（メインで担当する／関われる。PR235）で使う。
// Rails とは今までどおり2つの一覧でやりとりし、画面の中では「チェックを入れた番号それぞれに、メインかサブが付く」形で見せる。
// 同じ番号がメインとサブの両方に入ることは、この関数の作りの上で起きない（Rails の「主な職種と同じものが含まれています」を画面から出さないため）

// メインかサブか。工程では「サブ」を「関われる」と表示する（PR236）
export type Role = "main" | "sub";

export type RoleIds = { main: number[]; sub: number[] };

// チェックが入っている番号すべて（メイン → サブの順）
export function selectedIdsOf({ main, sub }: RoleIds): number[] {
  return [...main, ...sub];
}

// チェックの一覧が変わったときの、新しい値。
// 新しくチェックした番号はメインに足す（チェックを入れた時点ではメイン。PR234）。チェックを外した番号は、メインからもサブからも消す
export function withSelectedIds(roleIds: RoleIds, ids: number[]): RoleIds {
  const current = new Set(selectedIdsOf(roleIds));
  const next = new Set(ids);
  return {
    main: [...roleIds.main.filter((id) => next.has(id)), ...ids.filter((id) => !current.has(id))],
    sub: roleIds.sub.filter((id) => next.has(id)),
  };
}

// その番号がメインかサブか
export function roleOf(roleIds: RoleIds, id: number): Role {
  return roleIds.sub.includes(id) ? "sub" : "main";
}

// その番号を、メインかサブに移す
export function withRole(roleIds: RoleIds, id: number, role: Role): RoleIds {
  const main = roleIds.main.filter((mainId) => mainId !== id);
  const sub = roleIds.sub.filter((subId) => subId !== id);
  return role === "main" ? { main: [...main, id], sub } : { main, sub: [...sub, id] };
}
