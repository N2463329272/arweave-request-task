-- 初始化全局变量
local CurrentGameState = CurrentGameState or {}
local ActionInProgress = ActionInProgress or false
local Logs = Logs or {}
local Me = nil

-- 定义颜色用于控制台输出
local colors = {
  red = "\27[31m", green = "\27[32m", blue = "\27[34m",
  yellow = "\27[33m", purple = "\27[35m", reset = "\27[0m"
}

-- 添加日志函数
function addLog(msg, text)
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

-- 收到游戏状态信息后更新游戏状态
Handlers.add("UpdateGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    CurrentGameState = json.decode(msg.Data)
    Me = CurrentGameState.Players[ao.id]
    ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    print("游戏状态已更新。查看 'CurrentGameState' 以获得详细信息。")
  end)

-- 检查两点是否在一定范围内
function inRange(weakestOpponent)
  return math.abs(Me.x - weakestOpponent.x) <= 3 and math.abs(Me.y - weakestOpponent.y) <= 3
end

-- 查找生命值最低的对手
function findWeakestOpponent()
  local weakestOpponent, lowestHealth = nil, math.huge
  if CurrentGameState and CurrentGameState.Players then
    for target, state in pairs(CurrentGameState.Players) do
      if target ~= ao.id and state.health < lowestHealth then
        weakestOpponent, lowestHealth = state, state.health
      end
    end
    return weakestOpponent
  end
  return nil
end

-- 攻击生命值最低的对手
function attackWeakestOpponent()
  local weakestOpponent = findWeakestOpponent()
  local json = require("json")
  if weakestOpponent ~= nil then
    print("对手信息：" .. json.decode(weakestOpponent))
  end
  if weakestOpponent and inRange(weakestOpponent) then
    local useEnrygy = Me.energy
    print("我的能量：" .. useEnrygy)
    if Me.energy > weakestOpponent.health then
      useEnrygy =  weakestOpponent.health
    end
    print(colors.red .. "攻击生命值最低的对手，能量: " .. useEnrygy .. colors.reset)
    ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(useEnrygy) })
    ActionInProgress = false
    return true
  end
  return false
end

-- 随机移动
function moveRandomly()
  local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
  local randomIndex = math.random(#directionMap)
  print(colors.blue .. "随机移动方向: " .. directionMap[randomIndex] .. colors.reset)
  ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex]})
end


-- 根据状态决定下一步行动
function decideNextAction()
  if not attackWeakestOpponent() then
    moveRandomly()
  end
end

-- 处理游戏公告并触发状态更新
Handlers.add("PrintAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({ Target = ao.id, Action = "AutoPay" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not ActionInProgress then
      ActionInProgress = true
      ao.send({ Target = Game, Action = "GetGameState" })
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end)

Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)

-- 触发游戏状态更新
Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not ActionInProgress then
      ActionInProgress = true
      print(colors.yellow .. "获取游戏状态..." .. colors.reset)
      ao.send({ Target = Game, Action = "GetGameState" })
    end
  end)


-- 决定下一个最佳操作
Handlers.add("DecideNextAction", Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"), function()
    if CurrentGameState.GameMode ~= "Playing" then
      ActionInProgress = false
      return
    end
    decideNextAction()
    ao.send({ Target = ao.id, Action = "Tick" })
  end)

-- 自动攻击被击中时
Handlers.add("ReturnAttack", Handlers.utils.hasMatchingTag("Action", "Hit"), function(msg)
    if not ActionInProgress then
      ActionInProgress = true
      local playerEnergy = Me.energy
      if playerEnergy and playerEnergy > 0 then
        print(colors.red .. "反击." .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
      end
      ActionInProgress = false
      ao.send({ Target = ao.id, Action = "Tick" })
    end
  end)
