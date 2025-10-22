def check_for_fun_metrics
  edited = danger.git.modified_files + danger.git.created_files

  # --- Проверка на изменённые тестовые файлы
  test_files = edited.select { |path| path.downcase.include?("tests/") }
  unless test_files.empty?
    markdown <<~MD
      ### 💪 **Quality guardian**
      **#{test_files.count}** test file(s) modified. You're a champion of test coverage! 🚀
    MD
  end

  additions = danger.github.pr_additions || 0
  deletions = danger.github.pr_deletions || 0

  # --- Проверка на «чистку» (удалено больше, чем добавлено)
  if deletions > additions && (deletions - additions) > 50
    markdown <<~MD
      ### 🗑️ **Tossing out clutter**
      **#{deletions - additions}** line(s) removed. Fewer lines, fewer bugs 🐛!
    MD
  end

  files_changed = danger.github.pr_changed_files || 0
  total_lines = additions + deletions

  # --- Маленькие PR
  if files_changed > 0 && files_changed <= 5
    markdown <<~MD
      ### 🧹 **Tidy commit**
      Just **#{files_changed}** file(s) touched. Thanks for keeping it clean and review-friendly!
    MD
  elsif total_lines > 0 && total_lines < 50
    markdown <<~MD
      ### 🌱 **Tiny but mighty**
      Only **#{total_lines}** line(s) changed. Fast to review, faster to land! 🚀
    MD
  else
    check_big_pull_request
  end

  # --- Пятничное поощрение
  weekday = Time.now.wday # 5 = Friday (Ruby: Sunday=0)
  if weekday == 5
    markdown <<~MD
      ### 🙌 **Friday high-five**
      Thanks for pushing us across the finish line this week! 🙌
    MD
  end

  # --- Если тронуты .md файлы
  if edited.any? { |path| path.include?(".md") }
    markdown <<~MD
      ### 🌟 **Documentation star**
      Great documentation touches. Future you says thank you! 📚
    MD
  end

  check_description_section
end


# --- Проверка размеров PR
def check_big_pull_request
  medium_threshold = 400
  big_threshold = 800
  monster_threshold = 2000

  additions = danger.github.pr_additions || 0
  deletions = danger.github.pr_deletions || 0
  total = additions + deletions

  case total
  when (monster_threshold + 1)..Float::INFINITY
    markdown <<~MD
      ### 🧟‍♂️ **Monster PR**
      Wow, this PR is **huge** with #{total} lines changed!
      Thanks for powering through such a big task 🙌.
      Reviewers: feel free to ask for extra context, screenshots, or a breakdown to make reviewing smoother.
    MD
  when (big_threshold + 1)..monster_threshold
    markdown <<~MD
      ### 🏔️ **Summit Climber**
      This PR is a **big climb** with #{total} lines changed!
      Thanks for taking on the heavy lifting 💪.
      Reviewers: a quick overview or walkthrough will make the ascent smoother.
    MD
  when (medium_threshold + 1)..big_threshold
    markdown <<~MD
      ### 🧩 **Neat Piece**
      This PR changes #{total} lines. It's a substantial update,
      but still review-friendly if there’s a clear description. Thanks for keeping things moving! 🚀
    MD
  else
    markdown <<~MD
      ### 🥇 **Perfect PR size**
      Smaller PRs are easier to review. Thanks for making life easy for reviewers! ✨
    MD
  end
end


# --- Проверка секции Description в теле PR
def check_description_section
  body = danger.github.pr_body
  return unless body

  regexes = [
    /## :bulb: Description\s*(.*?)## :movie_camera: Demos/m,
    /## :bulb: Description\s*(.*?)## :pencil: Checklist/m
  ]

  regexes.each do |regex|
    if body.match(regex)
      desc = body.match(regex)[1]
      # Удаляем HTML-комментарии
      desc = desc.gsub(/<!--.*?-->/m, "")
      comment_description_section(desc.strip)
      break
    end
  end
end


def comment_description_section(desc)
  count = desc.strip.length

  if count == 0
    fail <<~MD
      Details needed! Your description section is empty. Adding a bit more context will make reviews smoother.
    MD
  elsif count < 10
    warn <<~MD
      Extra details help! Your description section is a bit short (#{count} characters). Adding a bit more context will make reviews smoother.
    MD
  elsif count >= 300
    markdown <<~MD
      ### 💬 **Description craftsman**
      Great PR description! Reviewers salute you 🫡
    MD
  end
end

check_for_fun_metrics

