# プチ職業体験の講座を、db/job_trials/ の YAML からデータベースに読み込む（design/designs/データベース.md の 8-5 I。PR376・PR392）。
# db/seeds.rb が、マスタ（中分類・工程）を入れたあとに呼ぶ。Django でいえば、自分で書いた YAML を管理コマンドでモデルに流し込むのにあたる。
#
# - データベースが正で、YAML は下書き。講座は code、ハードルは「講座×code」で探して、あれば更新、なければ作る。
#   何度読み込んでも同じ結果になり、文面を直して読み込み直すと同じ行が更新される（自己分析が指すハードルは壊れない）
# - YAML から消した講座・ハードルは、消さずにそのまま残す（PR383）
# - 工程のタグは中間テーブルなので、YAML の内容で置き換える
# - 全体を1つのトランザクションで行い、途中で誤りがあれば何も変えずに止める
# - 企業向けの説明（guide）は、データベースに入れずに読み飛ばす。Rails がその都度ファイルから読む（app/models/job_trial_guide.rb。PR407）
class JobTrialLoader
  DIRECTORY = Rails.root.join("db/job_trials")

  class Error < StandardError; end

  # 読み込んだ講座の数を返す
  def self.load!
    paths = Dir.glob(DIRECTORY.join("*.yml")).sort
    ActiveRecord::Base.transaction do
      paths.each { |path| new(path).load! }
    end
    paths.size
  end

  def initialize(path)
    @path = path
    @file_name = File.basename(path)
  end

  def load!
    # 安全な読み方（Python の yaml.safe_load にあたる）。文字・数・真偽・配列・対応表だけを読む
    data = YAML.safe_load_file(@path)
    job_trial = save_job_trial!(data)
    save_work_processes!(job_trial, data.fetch("work_processes"))
    data.fetch("hurdles").each.with_index(1) do |row, position|
      save_hurdle!(job_trial, row, position)
    end
  rescue KeyError => e
    raise Error, "#{@file_name}：#{e.key} がありません"
  end

  private

  def save_job_trial!(data)
    code = data.fetch("job_middle_category_code")
    job_middle_category = JobMiddleCategory.find_by(code: code) or
      raise Error, "#{@file_name}：中分類 #{code} が見つかりません"

    job_trial = JobTrial.find_or_initialize_by(code: data.fetch("code"))
    job_trial.assign_attributes(
      title: data.fetch("title"),
      position: data.fetch("position"),
      job_middle_category: job_middle_category,
      intro: data.fetch("intro")
    )
    check!(job_trial.save, job_trial, "講座")
    job_trial
  end

  # 工程は名前で指す。送った内容で中間テーブルを置き換える（Rails が、外した分を消して足りない分を作る）
  def save_work_processes!(job_trial, names)
    work_processes = names.map do |name|
      WorkProcess.find_by(name: name) or raise Error, "#{@file_name}：工程「#{name}」が見つかりません"
    end
    raise Error, "#{@file_name}：工程を1つ以上書いてください" if work_processes.empty?

    job_trial.work_processes = work_processes
  end

  def save_hurdle!(job_trial, row, position)
    hurdle = JobTrialHurdle.find_or_initialize_by(job_trial: job_trial, code: row.fetch("code"))
    hurdle.assign_attributes(
      position: position,
      name: row.fetch("name"),
      overview: row.fetch("overview"),
      difficulty: row.fetch("difficulty"),
      tips: row.fetch("tips"),
      example: row.fetch("example"),
      goal: row.fetch("goal"),
      question: row.fetch("question"),
      choices: row.fetch("choices")
    )
    check!(hurdle.save, hurdle, "ハードル #{hurdle.code}")
  end

  # 保存できなければ、どのファイルの何が誤りかを添えて止める
  def check!(saved, record, label)
    return if saved

    raise Error, "#{@file_name}：#{label}を保存できません（#{record.errors.full_messages.join('、')}）"
  end
end
