// 性格・カルチャーの5軸を、5本のスライダーで入力する欄（design/designs/その他決め事.md の 5-5）。
// 学生の働き方の好み（マイページ・新規登録。PR233）と、募集のカルチャーグラフ（募集詳細編集）で使い回す。
// 軸の名前と両端の説明は、⑦ GET /api/options の culture_axes をそのまま出す（画面側に軸ごとの文言を書かない。API設計.md の 16-1-9）。
// 値は「軸の名前 → 数（−2〜2）」の形で受け取るので、学生の personality_pace にも募集の culture_pace にもつなげられる。
// 募集詳細（学生）の見るだけのカルチャーグラフ（CultureAxesView）も、同じ見た目の部品でここに置く。
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

// 棒の中に入れるもの：真ん中から値の位置までの線（薄いオレンジ。PR245）と、5つの目盛り。
// 入力のスライダーと、見るだけのグラフで使い回す。線は左右どちらに寄せても同じ色（どちらが良いとは見せない）
function AxisMarks({ value }: { value: number }) {
  const lineStart = Math.min(percentOf(0), percentOf(value));
  const lineWidth = Math.abs(percentOf(value) - percentOf(0));
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

// 左右の短い名前（「スピード」「緻密さ」）と、左右の長い説明。入力と見るだけのグラフで同じ並べ方にする
function AxisLabels({ axis }: { axis: CultureAxis }) {
  return (
    <div className="flex justify-between gap-4 text-sm">
      <span>{axis.left_label}</span>
      <span className="text-right">{axis.right_label}</span>
    </div>
  );
}

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
                  <AxisMarks value={value} />
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

// 見るだけのカルチャーグラフ（募集詳細。ページ設計.md の 6-6 S6、PR250）。
// 入力のスライダーと同じ見た目（目盛り・真ん中からの線・両端の短い名前と長い説明）で、値の位置に濃い点を置く。
// 順10 で、ここに学生自身の点を重ねて「一致・ずれ」を出す予定
export function CultureAxesView({ axes, values }: { axes: CultureAxis[]; values: Record<string, number> }) {
  return (
    <div className="space-y-5">
      {axes.map((axis) => {
        const value = values[axis.key] ?? 0;
        return (
          <div key={axis.key} className="space-y-2">
            <p className="text-sm font-medium">{axis.name}</p>
            {/* 読み上げには、1軸を1文で伝える（例：「ややスピード」）。絵の部分は読ませない */}
            <p className="sr-only">{valueText(axis, value)}</p>
            <div aria-hidden="true" className="space-y-2">
              <AxisLabels axis={axis} />
              {/* 入力のスライダーと同じく、左右に余白を取り、点の中心を目盛りに重ねる */}
              <div className="flex h-6 items-center px-2.5">
                <div className={TRACK_CLASS}>
                  <AxisMarks value={value} />
                  <span
                    className="absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-primary bg-primary"
                    style={{ left: `${percentOf(value)}%` }}
                  />
                </div>
              </div>
            </div>
            <AxisDescriptions axis={axis} />
          </div>
        );
      })}
    </div>
  );
}
