def check_for_fun_metrics
  edited = git.modified_files + git.added_files

  additions = github.pr_json[:additions] || 0
  deletions = github.pr_json[:deletions] || 0
  
  if deletions > additions && (deletions - additions) > 50
    markdown(<<~MARKDOWN)
      ### 🗑️ **Tossing out clutter**
      **#{deletions - additions}** line(s) removed. Fewer lines, fewer bugs 🐛!
    MARKDOWN
  end

  # Either comment for the small number of files changed or small number of lines changed, otherwise it gets crowded.
  files_changed = github.pr_json[:changed_files] || 0
  total_lines = deletions + additions
  
  if files_changed > 0 && files_changed <= 5
    markdown(<<~MARKDOWN)
      ### 🧹 **Tidy commit**
      Just **#{files_changed}** file(s) touched. Thanks for keeping it clean and review-friendly!
    MARKDOWN
  elsif total_lines > 0 && total_lines < 50
    markdown(<<~MARKDOWN)
      ### 🌱 **Tiny but mighty**
      Only **#{total_lines}** line(s) changed. Fast to review, faster to land! 🚀
    MARKDOWN
  end

  weekday = Time.now.wday # 5 = Friday (0=Sunday, 1=Monday, ...)
  if weekday == 5
    markdown(<<~MARKDOWN)
      ### 🙌 **Friday high-five**
      Thanks for pushing us across the finish line this week! 🙌
    MARKDOWN
  end
end
check_for_fun_metrics
