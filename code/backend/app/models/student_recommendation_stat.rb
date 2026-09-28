# 学生ごとの推薦の集計（design/designs/データベース.md の 8-5 F）。1人1行。
# 件数と self_weight は応募・マッチのあとのジョブで（refresh_interests!。concerns/interest_stats.rb）、
# 項目数は新規登録・プロフィールの保存と同じトランザクションで（refresh_item_counts!）数え直す（処理設計_類似度.md の 7-5）
class StudentRecommendationStat < ApplicationRecord
  include InterestStats

  # 項目数の列。refresh_item_counts! が書き換えるのはこの列だけ
  ITEM_COUNT_COLUMNS = %i[job_middle_category_count job_major_category_count technology_count industry_count].freeze

  belongs_to :student_profile

  # 件数と self_weight は、やりとりを学生の列でまとめて数える
  interest_stats_columns own: :student_profile_id, other: :job_posting_id

  # 渡された学生の項目数を、プロフィールの付属テーブルから数え直して上書きする。
  # 行がなければ作り（件数と self_weight は既定値0のまま）、あれば項目数の列だけを書き換える
  def self.refresh_item_counts!(student_profile_ids)
    ids = Array(student_profile_ids).map(&:to_i).uniq
    return if ids.empty?

    # どれも { 学生の番号 => 数 }。中間テーブルは UNIQUE なので、行の数がそのまま項目の数になる
    interested_job_categories = StudentInterestedJobCategory.where(student_profile_id: ids)
    job_middle_counts = interested_job_categories.group(:student_profile_id).count
    # 大分類は、中分類の表を通して数える。2つの中分類が同じ大分類なら1つに数える（COUNT(DISTINCT ...)）
    job_major_counts = interested_job_categories.joins(:job_middle_category)
                                                .group(:student_profile_id)
                                                .distinct
                                                .count("job_middle_categories.job_major_category_id")
    # プログラミング歴は、マスタから選んだ技術だけを数える（「その他」の行は技術が空。処理設計_類似度.md の 7-2）
    technology_counts = StudentSkill.where(student_profile_id: ids).where.not(technology_id: nil).group(:student_profile_id).count
    industry_counts = StudentInterestedIndustry.where(student_profile_id: ids).group(:student_profile_id).count

    rows = ids.map do |id|
      {
        student_profile_id: id,
        job_middle_category_count: job_middle_counts.fetch(id, 0),
        job_major_category_count: job_major_counts.fetch(id, 0),
        technology_count: technology_counts.fetch(id, 0),
        industry_count: industry_counts.fetch(id, 0)
      }
    end
    upsert_all(rows, unique_by: :student_profile_id, update_only: ITEM_COUNT_COLUMNS)
  end
end
