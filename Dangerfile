require 'json'
require 'octokit'

$client = Octokit::Client.new(access_token: ENV['GIST_TOKEN'])
$gist_id = ENV['DANGER_STATE_GIST_ID']

def load_state
  begin
    gist = $client.gist($gist_id)
    content = gist.files["state.json"].content
    JSON.parse(content)
  rescue => e
    puts "WARN: Не удалось загрузить состояние из Gist: #{e.message}"
    { "pushers" => [] }
  end
end

def save_state(state)
  content = JSON.pretty_generate(state)
  begin
    $client.edit_gist($gist_id, files: { "state.json" => { content: content } })
    puts "DEBUG: Состояние успешно сохранено в Gist."
  rescue => e
    puts "ERROR: Ошибка при сохранении состояния в Gist: #{e.message}"
  end
end

def increment_pr_count(user_login)
  state = load_state
  pushers = state["pushers"]

  user = pushers.find { |u| u["name"] == user_login }

  if user
    user["pr_count"] += 1
  else
    user = { "name" => user_login, "pr_count" => 1 }
    pushers << user
  end

  save_state(state)
  user["pr_count"]
end

def get_cur_pr_count(user_login)
  state = load_state
  pushers = state["pushers"]
  user = pushers.find { |u| u["name"] == user_login }

  user ? user["pr_count"] + 1 : 1
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
  cur_pusher_pr_count = get_cur_pr_count(pr_pusher)

  message(<<~MARKDOWN)
    ### `#{pr_pusher}` — Вы замечательны 😎!  
    ![#{pr_pusher}](#{pr_pusher_avatar}&s=64)
    Это ваш **#{cur_pusher_pr_count}-й PR**. Благодарим за вклад в проект 🤝
  MARKDOWN

  if files_changed > 0 && files_changed <= 5
    message("### 🧹 **Tidy commit**\nЗатронуто только **#{files_changed}** файлов. Отличная работа!")
  elsif total_lines > 0 && total_lines < 50
    message("### 🌱 **Tiny but mighty**\nИзменено всего **#{total_lines}** строк.")
  elsif total_lines > 1000
    fail("### ⛔️ **Слишком большой PR**\nДопускается не более 1000 строк за один PR.")
  end

  if files_changed > 20
    fail("### ⛔️ **Слишком много файлов**\nДопускается не более 20 файлов за один PR.")
  end

  if commits > 0 && commits <= 5
    message("### 🧹 **Малое количество коммитов**\nТолько **#{commits}** коммит(ов). Отлично!")
  elsif commits > 15
    message("### ⚠️ **Много коммитов**\nЦелых **#{commits}**! Впечатляет.")
  end

  if deletions > 500
    fail("### ⛔️ **Удалено слишком много строк**\nДопускается не более 500 строк за раз.")
  end

  if edited.any? { |f| f.start_with?('.github/workflows/') && f.match?(/\.ya?ml$/) }
    warn("### ⚙️ **Изменения в workflow**\nПожалуйста, убедитесь, что они безопасны.")
  end

  if edited.any? { |f| f.start_with?('OrbitTests/') }
    message("### 🧪 **Изменены тесты**\nСпасибо, что поддерживаете тесты в актуальном состоянии!")
  end

  weekday = Time.now.wday
  if weekday == 5
    message("### 🙌 **Пятничный привет!**\nСпасибо за вашу работу на этой неделе 🙌")
  elsif [6, 0].include?(weekday)
    warn("### ⚠️ **Отдых важен**\nСегодня выходной — не забудьте немного отдохнуть 😊")
  end
end

check_for_fun_metrics

if github.pr_json[:merged]
  pr_pusher = github.pr_json[:user][:login]
  increment_pr_count(pr_pusher)
  puts "✅ Счётчик PR успешно обновлён."
else
  puts "ℹ️ PR не вмержен — счётчик не обновляется."
end
