# プチ職業体験の講座の、企業向けの説明（講座の説明と、ハードルごとの力。PR402・PR407）。
# 文面はまだ変わりそうなので、データベースには入れず、講座の YAML（db/job_trials/*.yml）の guide から、その都度読む。
# ファイルは小さいので覚えておかず、毎回読む。文面を直せば、db:seed なしで次の読み込みから反映される。
# データベースの表ではないので、ActiveRecord ではない普通のクラスにしている（Django でいう、モデルではない読み込み用のクラス）。
#
# 使い方：guides = JobTrialGuide.all（講座の code => 説明）。1回の返事の中では1回だけ呼ぶ
class JobTrialGuide
  DIRECTORY = Rails.root.join("db/job_trials")
  # ハードルごとに持つ項目
  HURDLE_KEYS = %w[skill skill_description skill_point].freeze

  attr_reader :summary

  # すべての講座のファイルを読み、講座の code => 説明 の対応表を返す。guide のない講座は入らない
  def self.all
    Dir.glob(DIRECTORY.join("*.yml")).each_with_object({}) do |path, guides|
      data = YAML.safe_load_file(path)
      guides[data["code"]] = new(data["guide"]) if data.is_a?(Hash) && data["guide"].is_a?(Hash)
    end
  end

  def initialize(data)
    @summary = data["summary"]
    @hurdles = data["hurdles"].is_a?(Hash) ? data["hurdles"] : {}
  end

  # ハードルの code から、そのハードルの力（skill、skill_description、skill_point）を返す。書いていなければ空の対応表
  def hurdle(code)
    row = @hurdles[code]
    row.is_a?(Hash) ? row.slice(*HURDLE_KEYS) : {}
  end
end
