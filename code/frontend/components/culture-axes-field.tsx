// 性格・カルチャーの5軸を、5本のスライダーで入力する欄（design/designs/その他決め事.md の 5-5）。
// 学生の働き方の好み（マイページ・新規登録。PR233）と、募集のカルチャーグラフ（募集詳細編集）で使い回す。
// 軸の名前と両端の説明は、⑦ GET /api/options の culture_axes をそのまま出す（画面側に軸ごとの文言を書かない。API設計.md の 16-1-9）。
// 値は「軸の名前 → 数（−2〜2）」の形で受け取るので、学生の personality_pace にも募集の culture_pace にもつなげられる。
// 募集詳細（学生）・学生詳細（企業）の見るだけのカルチャーグラフ（CultureAxesView）も、同じ見た目の部品でここに置く。
//
// スライダーは shadcn/ui の部品ではなく、その中身の Base UI のスライダーをここで組み立てる（PR244）。
// 棒の中に、5つの目盛りと「真ん中から今の位置までの線」を入れるため。
// Django でいえば、既製のウィジェットを使わず、同じライブラリの部品で専用のウィジェットを作るのにあたる

import { Slider } from "@base-ui/react/slider";
import { toFieldErrorItems, type FieldErrors } from "@/components/form-fields";
import { Field, FieldError, FieldLegend, FieldSet, FieldTitle } from "@/components/ui/field";
import type { CultureAxis } from "@/lib/options";

// 値の範囲（負＝左、正＝右、0＝真ん中）。Rails の app/models/concerns/culture_axes.rb と同じ
const MIN = -2;
const MAX = 2;
// 目盛りの5つの値（−2, −1, 0, 1, 2）
const STEPS = Array.from({ length: MAX - MIN + 1 }, (_, index) => MIN + index);

// 値（−2〜2）を、棒の左端からの位置（0〜100%）に直す
function percentOf(value: number): number {
  return ((value - MIN) / (MAX - MIN)) * 100;
}

// 読み上げ（スクリーンリーダー）に読ませる言葉。数字（−1 など）だけでは意味が伝わらないため。
// 例：−2「スピード」、−1「ややスピード」、0「こだわらない」、1「やや緻密さ」、2「緻密さ」。
// 左右の短い名前は Rails から受け取ったものを使う（真ん中の「こだわらない」は、その他決め事.md の 5-5 の中央の意味）
function valueText(axis: CultureAxis, value: number): string {
  if (value === 0) return "こだわらない";
  const side = value < 0 ? axis.left_label : axis.right_label;
  return Math.abs(value) === 1 ? `やや${side}` : side;
}

// 棒の見た目。入力のスライダーと、見るだけのグラフで同じにする
const TRACK_CLASS = "relative h-1 w-full rounded-full bg-muted";

// 棒の中に入れるもの：from から to までの線（薄いオレンジ。PR245）と、5つの目盛り。
// 入力のスライダーと、見るだけのグラフで使い回す。線は左右どちらに寄せても同じ色（どちらが良いとは見せない）。
// from を渡さなければ真ん中から。2つの点を比べるグラフでは、2点の間に引く（PR259）
function AxisMarks({ from = 0, to }: { from?: number; to: number }) {
  const lineStart = Math.min(percentOf(from), percentOf(to));
  const lineWidth = Math.abs(percentOf(to) - percentOf(from));
  return (
    <>
      <div
        aria-hidden="true"
        className="absolute inset-y-0 rounded-full bg-highlight"
        style={{ left: `${lineStart}%`, width: `${lineWidth}%` }}
      />
      {STEPS.map((step) => (
        <span
          key={step}
          aria-hidden="true"
          className="absolute top-1/2 size-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full border border-muted-foreground/40 bg-background"
          style={{ left: `${percentOf(step)}%` }}
        />
      ))}
    </>
  );
}

// 左右の短い名前（「スピード」「緻密さ」）。入力のスライダーだけで使う
function AxisLabels({ axis }: { axis: CultureAxis }) {
  return (
    <div className="flex justify-between gap-4 text-sm">
      <span>{axis.left_label}</span>
      <span className="text-right">{axis.right_label}</span>
    </div>
  );
}

// 左右の長い説明。入力のスライダーと、見るだけのグラフの両方で使う
function AxisDescriptions({ axis }: { axis: CultureAxis }) {
  return (
    <div className="grid grid-cols-2 gap-4 text-xs text-muted-foreground">
      <p>{axis.left_description}</p>
      <p className="text-right">{axis.right_description}</p>
    </div>
  );
}

type CultureAxesFieldProps = {
  // 欄全体の名前。画面には出さず、読み上げにだけ残す（まとまりの見出しやステップの見出しに、同じ名前がすでに出ているため）
  legend: string;
  axes: CultureAxis[];
  // 軸ごとの値（例：{ pace: -1, novelty: 0, … }）
  values: Record<string, number>;
  onChange: (axisKey: string, value: number) => void;
  // 軸ごとのエラー（例：{ pace: ["働き方の好み（進め方）は2以下の値にしてください"] }）。Rails から返ったときだけ
  errors: FieldErrors;
};

export function CultureAxesField({ legend, axes, values, onChange, errors }: CultureAxesFieldProps) {
  return (
    <FieldSet>
      <FieldLegend className="sr-only">{legend}</FieldLegend>
      {axes.map((axis) => {
        const value = values[axis.key] ?? 0;
        return (
          <Field key={axis.key} data-invalid={errors[axis.key] ? true : undefined}>
            <FieldTitle>{axis.name}</FieldTitle>
            <AxisLabels axis={axis} />
            {/*
              thumbAlignment="center"：つまみの中心を、値の位置（0%・25%…100%）にぴったり置く。目盛りの丸と重ねるため。
              両端のつまみが半分はみ出すので、左右に余白（px-2.5）を取る
            */}
            <Slider.Root
              min={MIN}
              max={MAX}
              step={1}
              // 値は1つだけの配列で渡す（数を1つだけ渡すと、つまみ2つで範囲を選ぶ形と見なされることがあるため）
              value={[value]}
              // 1つだけの配列で渡しているので、配列で返ってくる。念のため数で返ってきた場合も受け取る
              onValueChange={(next) => onChange(axis.key, typeof next === "number" ? next : next[0])}
              thumbAlignment="center"
              className="px-2.5"
            >
              {/* 押せる範囲。上下に広げて（h-8）、スマホでも押しやすくする。棒や目盛りのどこを押しても、いちばん近い段に動く */}
              <Slider.Control className="relative flex h-8 w-full touch-none items-center select-none">
                <Slider.Track className={TRACK_CLASS}>
                  {/* 目盛りを押すと、その段に動く（棒を押したのと同じ扱い） */}
                  <AxisMarks to={value} />
                </Slider.Track>
                {/* つまみ。目盛りより一回り大きい丸。キーボードの左右の矢印でも動かせる */}
                <Slider.Thumb
                  getAriaLabel={() => axis.name}
                  getAriaValueText={(_formattedValue, thumbValue) => valueText(axis, thumbValue)}
                  className="block size-5 rounded-full border-2 border-primary bg-background shadow-sm outline-none has-[:focus-visible]:ring-3 has-[:focus-visible]:ring-ring/50"
                />
              </Slider.Control>
            </Slider.Root>
            <AxisDescriptions axis={axis} />
            <FieldError errors={toFieldErrorItems(errors[axis.key])} />
          </Field>
        );
      })}
    </FieldSet>
  );
}

// 2つの点を比べるときの丸（PR256）。白丸（募集）は大きめの枠線だけ、黒丸（学生）は小さめの塗りつぶし。
// 大きさを変えておくと、同じ位置に来たときに「白丸の中に黒丸」の形になり、どちらの点も隠れない
const RING_CLASS = "rounded-full border-2 border-primary bg-background size-5";
const DOT_CLASS = "rounded-full bg-primary size-2.5";

// 比べる相手（黒丸）。値は「軸の名前 → 数」。label は黒丸の名前（「あなた」「学生」）、
// baseLabel は白丸（values の側）の名前（「この募集」「募集」）
type CultureCompare = {
  values: Record<string, number>;
  label: string;
  baseLabel: string;
};

type CultureAxesViewProps = {
  axes: CultureAxis[];
  // グラフの本体の値（募集のカルチャー）
  values: Record<string, number>;
  // 渡すと、2つの点を重ねて比べる形になる（順10。PR256・PR258）
  compare?: CultureCompare;
};

// 見るだけのカルチャーグラフ（募集詳細・学生詳細。ページ設計.md の 6-6 S6、6-5 C6、PR250）。
// 入力のスライダーと同じ目盛り・線で、値の位置に点を置く。
// 並びは「軸の名前 → 両端の長い説明 → 線と点」。短い名前（「スピード」など）は出さない。軸の名前・短い名前・長い説明が並ぶとくどいため。
// 入力のスライダーは、選ぶときの目印として短い名前も出したまま。読み上げの言葉（valueText）では短い名前を使う
// - compare なし：値の位置に濃い点1つと、真ん中からの線
// - compare あり：本体の値に白丸、相手の値に黒丸を置き、2点の間に線を引く。
//   「近い・遠い」や「一致・ずれ」の判定はしない（PR258・PR259）。凡例を上に1行だけ出す
export function CultureAxesView({ axes, values, compare }: CultureAxesViewProps) {
  return (
    <div className="space-y-5">
      {compare && (
        // 凡例。読み上げには軸ごとの1文で名前を伝えるので、ここは読ませない
        <div aria-hidden="true" className="flex flex-wrap items-center gap-4 text-sm text-muted-foreground">
          <span className="inline-flex items-center gap-1.5">
            <span className={`inline-block ${DOT_CLASS}`} />
            {compare.label}
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className={`inline-block ${RING_CLASS}`} />
            {compare.baseLabel}
          </span>
        </div>
      )}
      {axes.map((axis) => {
        const value = values[axis.key] ?? 0;
        const compareValue = compare ? (compare.values[axis.key] ?? 0) : null;
        return (
          <div key={axis.key} className="space-y-2">
            <p className="text-sm font-medium">{axis.name}</p>
            {/* 読み上げには、1軸を1文で伝える（例：「ややスピード」「この募集：ややスピード、あなた：緻密さ」）。絵の部分は読ませない */}
            <p className="sr-only">
              {compare && compareValue !== null
                ? `${compare.baseLabel}：${valueText(axis, value)}、${compare.label}：${valueText(axis, compareValue)}`
                : valueText(axis, value)}
            </p>
            {/* 両端の長い説明は、軸の名前のすぐ下、線より上に置く（説明を読んでから点の位置を見る順にする） */}
            <AxisDescriptions axis={axis} />
            <div aria-hidden="true" className="space-y-2">
              {/* 入力のスライダーと同じく、左右に余白を取り、点の中心を目盛りに重ねる */}
              <div className="flex h-6 items-center px-2.5">
                <div className={TRACK_CLASS}>
                  {compareValue === null ? (
                    <>
                      <AxisMarks to={value} />
                      <span
                        className="absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-primary bg-primary"
                        style={{ left: `${percentOf(value)}%` }}
                      />
                    </>
                  ) : (
                    <>
                      <AxisMarks from={value} to={compareValue} />
                      {/* 白丸を先に置き、黒丸をその上に重ねる */}
                      <span
                        className={`absolute top-1/2 -translate-x-1/2 -translate-y-1/2 ${RING_CLASS}`}
                        style={{ left: `${percentOf(value)}%` }}
                      />
                      <span
                        className={`absolute top-1/2 -translate-x-1/2 -translate-y-1/2 ${DOT_CLASS}`}
                        style={{ left: `${percentOf(compareValue)}%` }}
                      />
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
