-- Interface functions
--
--    gmatch(str, regex): search for patterns globally, to replace string.gmatch. PCRE style regex.
--
--    add_action_handler(regex, func): add action hanlders. PCRE style regex.
--    add_message_handler(regex, func, synopsis, description): add message handlers. PCRE style regex.
--    print_case(number): print a case's detail to chat
--    say(str): print string to chat
--    set(str, value): set a persistent variable
--    set(str, value, ttl): set a variable with an expiration in seconds
--    get(str): get a variable

-- Message handlers
--
--    whenever a message matches a pattern defined, a predefined action will be triggered
--
add_message_handler("how are you", "greet")
add_message_handler("case\\s+(\\d)+", "handle_cases")
add_message_handler("\\w+\\+\\+", "karma_incr")
add_message_handler("\\w+\\-\\-", "karma_decr")

-- Action handlers
--
--    When a bot is directly addressed, an action handler will be triggered. Regex matching will
--    start from the beginning of the sentence after removing bot name prefix.
--
add_action_handler("who are you", "self",       "who are you", "Some greetings")
add_action_handler("ack",         "handle_ack", "ack [CASE]",  "Acknowledge a case")
add_action_handler("top",         "karma_top",  "top",         "Karma top list")

function greet(msg)
  say("How do you do?")
end

function karma_incr(msg)
  local matches = gmatch(msg, "(\\w+)\\+\\+")
  local karma = get("karma") or {}
  for _,v in ipairs(matches) do
    k = karma[v[1]]
    if k then 
      karma[v[1]] = k + 1
    else
      karma[v[1]] = 1
    end
    say(v[1] .. " has " .. karma[v[1]] .. " points of karma.")
  end
  set("karma", karma)
end

function karma_decr(msg)
  local matches = gmatch(msg, "(\\w+)\\-\\-")
  local karma = get("karma") or {}
  for _,v in ipairs(matches) do
    k = karma[v[1]]
    if k then 
      karma[v[1]] = k - 1
    else
      karma[v[1]] = -1
    end
    say(v[1] .. " has " .. karma[v[1]] .. " points of karma.")
  end
  set("karma", karma)
end

function karma_top(msg)
  local karma = get("karma") or {}
  local keys = {}
  for k in pairs(karma) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b) return karma[a] > karma[b] end)
  for i,k in ipairs(keys) do
    if i <= 10 then
      say(k .. " has " .. karma[k] .. " points of karma.")
    end
  end
end

function self(msg)
  say("I am a bot")
end

function handle_cases(msg)
  local matches = gmatch(msg, "[Cc]ase\\s+(\\d+)")
  for i,v in ipairs(matches) do
    print_case(v[1])
  end
end

function handle_ack(msg)
  local case = string.match(msg, "%d+")
  if case then say("Case " .. case .. " acked") else say("Most recent case acked") end
end
