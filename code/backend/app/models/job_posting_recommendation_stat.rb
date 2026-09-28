# 募集ごとの推薦の集計（design/designs/データベース.md の 8-5 F）。1募集1行。
# 件数と self_weight は応募・マッチのあとのジョブで（refresh_interests!。concerns/interest_stats.rb）、
# 項目数は募集の保存と同じトランザクションで（refresh_item_counts!）数え直す（処理設計_類似度.md の 7-5）
class JobPostingRecommendationStat < ApplicationRecord
  include InterestStats

  # 項目数の列。refresh_item_counts! が書き換えるのはこの列だけ
  ITEM_COUNT_COLUMNS = %i[
    job_middle_category_count job_major_category_count work_process_count technology_count industry_count
  ].freeze

  belongs_to :job_posting

  # 件数と self_weight は、やりとりを募集の列でまとめて数える
  interest_stats_columns own: :job_posting_id, other: :student_profile_id

  # 渡された募集の項目数を、募集の中間テーブルから数え直して上書きする。
  # 行がなければ作り（件数と self_weight は既定値0のまま）、あれば項目数の列だけを書き換える
  def self.refresh_item_counts!(job_posting_ids)
    ids = Array(job_posting_ids).map(&:to_i).uniq
    return if ids.empty?

    # どれも { 募集の番号 => 数 }。中間テーブルは UNIQUE なので、行の数がそのまま項目の数になる。
    # 職種は主・関連、工程はメイン・関われるを、区別せずに数える（今は同じ扱い。処理設計_類似度.md の 7-2）
    job_categories = JobPostingJobCategory.where(job_posting_id: ids)
    job_middle_counts = job_categories.group(:job_posting_id).count
    # 大分類は、中分類の表を通して数える。2つの中分類が同じ大分類なら1つに数える（COUNT(DISTINCT ...)）
    job_major_counts = job_categories.joins(:job_middle_category)
                                     .group(:job_posting_id)
                                     .distinct
                                     .count("job_middle_categories.job_major_category_id")
    work_process_counts = JobPostingWorkProcess.where(job_posting_id: ids).group(:job_posting_id).count
    technology_counts = JobPostingTechnology.where(job_posting_id: ids).group(:job_posting_id).count
    industry_counts = JobPostingIndustry.where(job_posting_id: ids).group(:job_posting_id).count

    rows = ids.map do |id|
      {
        job_posting_id: id,
        job_middle_category_count: job_middle_counts.fetch(id, 0),
        job_major_category_count: job_major_counts.fetch(id, 0),
        work_process_count: work_process_counts.fetch(id, 0),
        technology_count: technology_counts.fetch(id, 0),
        industry_count: industry_counts.fetch(id, 0)
      }
    end
    upsert_all(rows, unique_by: :job_posting_id, update_only: ITEM_COUNT_COLUMNS)
  end
end
