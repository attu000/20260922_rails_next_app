// Rails の API を呼ぶ共通の関数と、エラーの形。
// すべての画面は、Rails を呼ぶときに必ず apiFetch を使う（合言葉やエラーの扱いを1か所にまとめるため）。
// 詳しくは design/designs/API設計.md の 16-1-7（CSRF 対策）、16-1-10（エラーの形）

// エラーの形。Rails の {"message": "…", "errors": {…}} をそのまま持つ
export class ApiError extends Error {
  // 401・403・404・409・422・429・500 など
  readonly status: number;
  // 422 のときだけ、項目ごとの理由。それ以外は null
  readonly errors: Record<string, string[]> | null;

  constructor(status: number, message: string, errors: Record<string, string[]> | null) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.errors = errors;
  }
}

// Rails が合言葉を入れてくる Cookie の名前（Rails の CsrfProtection::COOKIE_NAME と同じ）
const CSRF_COOKIE_NAME = "CSRF-TOKEN";

// Rails に届かなかった場合など、message がないときに出す一言（16-1-10 の 500 と同じ文言）
const FALLBACK_ERROR_MESSAGE = "エラーが起きました";

// 合言葉を Cookie から読む。Cookie の値は符号化されているので、元に戻して返す
function readCsrfToken(): string | null {
  const prefix = `${CSRF_COOKIE_NAME}=`;
  const found = document.cookie.split("; ").find((cookie) => cookie.startsWith(prefix));
  return found ? decodeURIComponent(found.slice(prefix.length)) : null;
}

type ApiFetchOptions = {
  method?: "GET" | "POST" | "PATCH" | "DELETE";
  // 送る中身。JSON に直して送る
  body?: unknown;
};

type ErrorBody = {
  message?: string;
  errors?: Record<string, string[]>;
};

// API を呼ぶ。成功したら中身を返し、失敗したら ApiError を投げる。
// 204（中身なし）のときは null を返すので、呼ぶ側は apiFetch<null>(…) と書く。
// 401 のときにログイン画面へ移すかどうかは、ここでは決めない。
// ログイン後の画面では移し、ログイン前の画面では移さない、と場所によって違うため（16-1-6）
export async function apiFetch<T>(path: string, options: ApiFetchOptions = {}): Promise<T> {
  const { method = "GET", body } = options;

  const headers: Record<string, string> = {};
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  // GET 以外を送るときは、合言葉をヘッダーに入れる（16-1-7）
  if (method !== "GET") {
    const token = readCsrfToken();
    if (token) {
      headers["X-CSRF-Token"] = token;
    }
  }

  const response = await fetch(path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    // 同じ住所（Next.js の rewrites を通した Rails）への通信に Cookie を付ける。
    // fetch の標準の値と同じだが、技術構成.md の 3-1 A-2 の注意点3 をはっきりさせるために書く
    credentials: "same-origin",
  });

  if (response.status === 204) {
    return null as T;
  }

  // 中身を JSON として読む。読めなければ（Rails に届かなかった場合など）空として扱う
  const data: unknown = await response.json().catch(() => null);

  if (!response.ok) {
    const errorBody = (data ?? {}) as ErrorBody;
    throw new ApiError(
      response.status,
      errorBody.message ?? FALLBACK_ERROR_MESSAGE,
      errorBody.errors ?? null,
    );
  }

  return data as T;
}
