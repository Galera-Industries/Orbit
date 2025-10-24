def check_for_fun_metrics
  edited = git.modified_files + git.added_files

  additions = github.pr_json[:additions] || 0
  deletions = github.pr_json[:deletions] || 0
  
  files_changed = github.pr_json[:changed_files] || 0
  total_lines = deletions + additions
  
  if files_changed > 0 && files_changed <= 5
    message(<<~MARKDOWN)
      ### 🧹 **Tidy commit**
      Just **#{files_changed}** file(s) touched. Thanks for keeping it clean and review-friendly!
    MARKDOWN
  elsif total_lines > 0 && total_lines < 50
    message(<<~MARKDOWN)
      ### 🌱 **Tiny but mighty**
      Only **#{total_lines}** line(s) changed. Fast to review, faster to land! 🚀
    MARKDOWN
  end

  if edited.any? { |file| file.start_with?('.github/workflows/') && file.match?(/\.ya?ml$/) }
    message(<<~MARKDOWN)
      ### ⚙️ **Changes in workflow**
      Detected changes in GitHub Actions. 
      Please, make sure, that changes is safety and had been tested.
    MARKDOWN
  end


  if edited.any? { |file| file.start_with?('OrbitTests/') }
    message(<<~MARKDOWN)
      ### 🧪 **Tests modified**
      Thank you for keeping the tests up-to-date!
    MARKDOWN
  end

  weekday = Time.now.wday # 5 = Friday (0=Sunday, 1=Monday, ...)
  if weekday == 5
    message(<<~MARKDOWN)
      ### 🙌 **Friday high-five**
      Thanks for pushing us across the finish line this week! 🙌
    MARKDOWN
  end
end
check_for_fun_metrics
