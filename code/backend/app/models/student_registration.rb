# 学生の新規登録（⑥ POST /api/student_registrations。design/designs/API設計.md の 16-3 ⑥）。
# 処理は親の Registration にある。ここでは種別とプロフィールの種類だけを決める。
# プロフィールの項目は、マイページの保存と同じ（性格の5つは順9、外部リンク・資格・興味のある業界・就活希望エリアは【仕上げ】で足す）。
# 【強み】の順12 で、登録の完了後に「その学生の似た学生リストを作る」ジョブを呼ぶ（API設計.md の 16-3 ⑥、処理設計_類似度.md の 7-5）
class StudentRegistration < Registration
  ROLE = :student
  PROFILE_CLASS = StudentProfile
end
