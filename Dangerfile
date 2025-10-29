require 'json'

state_file = ".danger_state.json"

def load_state_file
  if File.exists?(state_file)
    JSON.parse(File.read(state_file))
  else 
    { "pushers" => [] }
  end
end

def save_state_file(state)
  File.write(state_file, JSON.pretty_generate(state))
end

def increment_pr_count(cur_pr_pusher)
  state = load_state_file
  pushers = state["pushers"]
  user = pushers.find {|u| u["name"] == cur_pr_pusher}
  if user
    user["pr_count"] += 1
  else
    user = { "name" => username, "pr_count" => 1 }
    pushers << user
  end

  save_state_file(state)

  return user["pr_count"]
end

def check_for_fun_metrics
  edited = git.modified_files + git.added_files

  additions = github.pr_json[:additions] || 0
  deletions = github.pr_json[:deletions] || 0
  commits = github.pr_json[:commits] || 0
  
  files_changed = github.pr_json[:changed_files] || 0
  total_lines = deletions + additions

  pr_pusher = github.pr_json[:user][:login]
  pr_pusher_avatar = github.pr_json[:user][:avatar_url]

  cur_pusher_pr_count = increment_pr_count(pr_pusher)

  message(<<~MARKDOWN)
    ### **#{pr_pusher}** you are so cooool 😎! 
    ![#{pr_pusher}](#{pr_pusher_avatar}&s=64)
    It's your **#{cur_pusher_pr_count}** PR!
    Thanks for contributing in our project🤝
  MARKDOWN
  
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
  elsif total_lines > 1000
    fail (<<~MARKDOWN)
      ### ⛔️ **To many lines added**
      You have to add at most 1000 lines in 1 pr
    MARKDOWN
  end

  if files_changed > 20
    fail (<<~MARKDOWN)
      ### ⛔️ **To many files changed**
      You have to change at most 20 files in 1 pr
    MARKDOWN
  end

  if commits > 0 && commits <= 5
    message(<<~MARKDOWN)
      ### 🧹 **Tidy commit**
      Only **#{commits}** commits. Thanks for keeping it clean and review-friendly!
    MARKDOWN
  elsif commits > 15 
    message(<<~MARKDOWN)
      ### ⚠️ **Monster commit**
      IT IS **#{commits}** commits. Amazing dude!
    MARKDOWN
  end

  if deletions > 500
    fail (<<~MARKDOWN)
      ### ⛔️ **To many lines removed**
      Do you want to delete our project😔? You can remove at most 500 lines!
    MARKDOWN
  end

  if edited.any? { |file| file.start_with?('.github/workflows/') && file.match?(/\.ya?ml$/) }
    warn(<<~MARKDOWN)
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
  elsif weekday == 6 || weekday == 7
    warn(<<~MARKDOWN)
      ### ⚠️ **Try to relax during weekend**
      It is so important to relax sometimes 😊
    MARKDOWN
  end
end
check_for_fun_metrics
