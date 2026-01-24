local mod = RegisterMod('Minesweeper Shenanigans', 1)
local sfx = SFXManager()
local game = Game()

if REPENTOGON then
  mod.rngShiftIdx = 35
  mod.faceNormal = '\u{f5b3}'
  mod.faceHappy = '\u{f59a}'
  mod.faceSad = '\u{f5c8}'
  mod.square = '\u{f45c}'
  mod.flagSolid = '\u{f024}'
  mod.flagCheckered = '\u{f11e}'
  mod.bomb = '\u{f1e2}' -- e51b
  mod.bombTemplate = mod.bomb .. ' %03d'
  mod.timerTemplate = '\u{f2f2} %03d' -- f017
  
  -- no custom boards for now, but we'll allow custom bomb counts
  mod.bombCounts = {}
  mod.globalData = {}
  
  mod.colorPresets = {
    -- colors borrowed from minesweeper.online
    dark = {
      [1] = { 124, 199, 255 },
      [2] = { 102, 194, 102 },
      [3] = { 255, 119, 136 },
      [4] = { 238, 136, 255 },
      [5] = { 221, 170, 34 },
      [6] = { 102, 204, 204 },
      [7] = { 153, 153, 153 },
      [8] = { 208, 216, 224 },
    },
    light = {
      [1] = { 0, 0, 247 },
      [2] = { 0, 119, 0 },
      [3] = { 236, 0, 0 },
      [4] = { 0, 0, 128 },
      [5] = { 128, 0, 0 },
      [6] = { 0, 128, 128 },
      [7] = { 0, 0, 1 },
      [8] = { 112, 112, 112 },
    },
  }
  
  mod.flagStatus = 0 -- 0 (mouse), 1 (flag), 2 (special)
  mod.colorPreset = 'dark' -- off, dark, light
  mod.firstClickIsZero = true
  
  function mod:onModsLoaded()
    mod:setupImGui()
  end
  
  function mod:setupImGuiMenu()
    if not ImGui.ElementExists('shenanigansMenu') then
      ImGui.CreateMenu('shenanigansMenu', '\u{f6d1} Shenanigans')
    end
  end
  
  function mod:setupImGui()
    ImGui.AddElement('shenanigansMenu', 'shenanigansMenuItemMinesweeper', ImGuiElement.MenuItem, mod.bomb .. ' Minesweeper Shenanigans')
    ImGui.CreateWindow('shenanigansWindowMinesweeper', 'Minesweeper Shenanigans')
    ImGui.LinkWindowToElement('shenanigansWindowMinesweeper', 'shenanigansMenuItemMinesweeper')
    
    ImGui.AddTabBar('shenanigansWindowMinesweeper', 'shenanigansTabBarMinesweeper')
    ImGui.AddTab('shenanigansTabBarMinesweeper', 'shenanigansTabMinesweeperBeginner', 'Beginner')
    ImGui.AddTab('shenanigansTabBarMinesweeper', 'shenanigansTabMinesweeperIntermediate', 'Intermediate')
    ImGui.AddTab('shenanigansTabBarMinesweeper', 'shenanigansTabMinesweeperExpert', 'Expert')
    ImGui.AddTab('shenanigansTabBarMinesweeper', 'shenanigansTabMinesweeperSettings', 'Settings')
    
    mod:setupBoard('MinesweeperBeginner', 9, 9, 10) -- 8x8 in older versions of minesweeper
    mod:setupBoard('MinesweeperIntermediate', 16, 16, 40)
    mod:setupBoard('MinesweeperExpert', 30, 16, 99)
    
    ImGui.AddElement('shenanigansTabMinesweeperSettings', '', ImGuiElement.SeparatorText, 'Settings')
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingFirstClick', 'First click', function(i)
      mod.firstClickIsZero = i == 1
    end, { 'Safe', 'Safe + empty' }, mod.firstClickIsZero and 1 or 0, true)
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingColors', 'Colors', function(_, s)
      mod.colorPreset = string.lower(s)
      for _, v in ipairs({
                          { s = 'MinesweeperBeginner'    , w = 9 , h = 9 },
                          { s = 'MinesweeperIntermediate', w = 16, h = 16 },
                          { s = 'MinesweeperExpert'      , w = 30, h = 16 },
                        })
      do
        mod:updateColors(mod.globalData[v.s], v.s, v.w, v.h)
      end
    end, { 'Off', 'Dark', 'Light' }, 1, true)
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingSize', 'Size', function(_, s)
      local n = tonumber(s)
      for _, v in ipairs({
                          { s = 'MinesweeperBeginner'    , w = 9 , h = 9 },
                          { s = 'MinesweeperIntermediate', w = 16, h = 16 },
                          { s = 'MinesweeperExpert'      , w = 30, h = 16 },
                        })
      do
        for i = 1, v.w * v.h do
          ImGui.SetSize('shenanigansBtn' .. v.s .. i, n, n)
        end
      end
    end, { 40, 50, 60 }, 1, true)
    ImGui.AddElement('shenanigansTabMinesweeperSettings', '', ImGuiElement.SeparatorText, 'Bomb Count')
    for _, v in ipairs({
                        { s = 'MinesweeperBeginner'    , text = 'Beginner'    , max = 60 },
                        { s = 'MinesweeperIntermediate', text = 'Intermediate', max = 192 },
                        { s = 'MinesweeperExpert'      , text = 'Expert'      , max = 360 }, -- 75% max density (30 * 16 = 480 * .75 = 360)
                      })
    do
      ImGui.AddSliderInteger('shenanigansTabMinesweeperSettings', 'shenanigansInt' .. v.s .. 'SettingBombCount', v.text, function(i)
        mod.bombCounts[v.s] = i
      end, mod.bombCounts[v.s], 1, v.max)
      ImGui.SetHelpmarker('shenanigansInt' .. v.s .. 'SettingBombCount', 'Default: ' .. mod.bombCounts[v.s] .. '\n\nClick the restart button after changing the bomb count')
    end
  end
  
  function mod:setupBoard(s, w, h, bombCount)
    local tab = 'shenanigansTab' .. s
    local timer = { enabled = false, startTime = 0, seconds = 0 }
    
    local data = {}
    mod.globalData[s] = data
    mod.bombCounts[s] = bombCount
    
    local btnRestartId = 'shenanigansBtn' .. s .. 'Restart'
    local btnViewId = 'shenanigansBtn' .. s .. 'View'
    local radFlagId = 'shenanigansRad' .. s .. 'Flag'
    local txtBombsId = 'shenanigansTxt' .. s .. 'Bombs'
    local txtTimerid = 'shenanigansTxt' .. s .. 'Timer'
    
    ImGui.AddButton(tab, btnRestartId, mod.faceNormal, function()
      mod:clearData(data)
      for j = 1, w * h do
        ImGui.UpdateText('shenanigansBtn' .. s .. j, mod.square)
      end
      ImGui.UpdateText(btnRestartId, mod.faceNormal)
      bombCount = mod.bombCounts[s]
      mod:updateBombCount(data, s, w, h, bombCount)
      mod:updateColors(data, s, w, h)
      timer.enabled = false
      timer.seconds = 0
    end, false)
    ImGui.AddElement(tab, '', ImGuiElement.SameLine, '')
    ImGui.AddButton(tab, btnViewId, '\u{f06e}', function()
      if #data == 0 then
        local rand = Random()
        local rng = RNG(rand <= 0 and 1 or rand, mod.rngShiftIdx)
        mod:generateData(data, bombCount, rng:RandomInt(w * h) + 1, w, h)
      end
      for i = 1, w * h do
        local txt = data[i].num
        if txt == 0 then
          txt = ''
        elseif txt == 100 then
          txt = mod.bomb
        end
        ImGui.UpdateText('shenanigansBtn' .. s .. i, txt)
        data[i].uncovered = true
        data[i].flagged = false
      end
      mod:updateBombCount(data, s, w, h, bombCount)
      mod:updateColors(data, s, w, h)
      timer.enabled = false
    end, false)
    ImGui.AddElement(tab, '', ImGuiElement.SameLine, '')
    
    ImGui.AddRadioButtons(tab, radFlagId, function(i)
      mod.flagStatus = i
      for _, v in ipairs({ 'MinesweeperBeginner', 'MinesweeperIntermediate', 'MinesweeperExpert' }) do
        ImGui.UpdateData('shenanigansRad' .. v .. 'Flag', ImGuiData.Value, i) -- keep setting in-sync between tabs
      end
    end, { '\u{f8cc}', mod.flagSolid, mod.flagCheckered }, mod.flagStatus, true)
    ImGui.SetHelpmarker(radFlagId, 'Mouse: uncover square\nFlag: add or remove flag\nCheckered flag: add flag or uncover flagged square\n\nController: hold left or right trigger when clicking to temporarily use flag mode')
    ImGui.AddElement(tab, '', ImGuiElement.SameLine, '')
    ImGui.AddText(tab, string.format(mod.bombTemplate, bombCount), false, txtBombsId)
    ImGui.AddElement(tab, '', ImGuiElement.SameLine, '')
    ImGui.AddText(tab, string.format(mod.timerTemplate, 0), false, txtTimerid)
    ImGui.AddCallback(txtTimerid, ImGuiCallback.Visible, function()
      if timer.enabled then
        timer.seconds = os.difftime(os.time(), timer.startTime)
      end
      ImGui.UpdateText(txtTimerid, string.format(mod.timerTemplate, timer.seconds))
    end)
    ImGui.AddElement(tab, '', ImGuiElement.Separator, '')
    
    local i = 0
    for iH = 1, h do
      for iW = 1, w do
        i = i + 1
        local iLocal = i
        local btnId = 'shenanigansBtn' .. s .. iLocal
        ImGui.AddButton(tab, btnId, mod.square, function()
          if #data == 0 then
            timer.enabled = true
            timer.startTime = os.time()
            mod:generateData(data, bombCount, iLocal, w, h)
            mod:uncoverSquares(data, 0, iLocal, s, w, h, timer)
            mod:updateBombCount(data, s, w, h, bombCount)
            mod:updateColors(data, s, w, h)
          elseif not data[iLocal].uncovered then
            local flagStatus = (mod.flagStatus ~= 1 and mod:isControllerTriggerPressed()) and 1 or mod.flagStatus
            mod:uncoverSquares(data, flagStatus, iLocal, s, w, h, timer)
            mod:updateBombCount(data, s, w, h, bombCount)
            mod:updateColors(data, s, w, h)
          end
        end, false)
        ImGui.SetSize(btnId, 50, 50)
        if iW ~= w then
          ImGui.AddElement(tab, '', ImGuiElement.SameLine, '')
        end
      end
    end
  end
  
  function mod:uncoverSquares(data, flagStatus, i, s, w, h, timer, iter)
    iter = iter or 0
    
    if mod:isFailure(data) or mod:isSuccess(data) then
      return
    end
    
    local flag = flagStatus == 1
    if flagStatus == 2 then
      if not data[i].uncovered then
        if data[i].flagged then
          data[i].flagged = false
        else
          flag = true
        end
      end
    end
    
    if flag then
      if not data[i].uncovered then
        if data[i].flagged then
          ImGui.UpdateText('shenanigansBtn' .. s .. i, mod.square)
          data[i].flagged = false
        else
          ImGui.UpdateText('shenanigansBtn' .. s .. i, mod.flagSolid)
          data[i].flagged = true
        end
      end
    else
      if not data[i].flagged then
        local txt = data[i].num
        if txt == 0 then
          txt = ''
        elseif txt == 100 then
          txt = mod.bomb
        end
        ImGui.UpdateText('shenanigansBtn' .. s .. i, txt)
        data[i].uncovered = true
        
        if data[i].num == 0 then
          local hasSquareLeft = mod:hasSquareLeft(i, w, h)
          local hasSquareRight = mod:hasSquareRight(i, w, h)
          local hasSquareUp = mod:hasSquareUp(i, w, h)
          local hasSquareDown = mod:hasSquareDown(i, w, h)
          for _, v in ipairs({
                              { cond = hasSquareUp and hasSquareLeft   , idx = i - w - 1 },
                              { cond = hasSquareUp                     , idx = i - w },
                              { cond = hasSquareUp and hasSquareRight  , idx = i - w + 1 },
                              { cond = hasSquareLeft                   , idx = i - 1 },
                              { cond = hasSquareRight                  , idx = i + 1 },
                              { cond = hasSquareDown and hasSquareLeft , idx = i + w - 1 },
                              { cond = hasSquareDown                   , idx = i + w },
                              { cond = hasSquareDown and hasSquareRight, idx = i + w + 1 },
                            })
          do
            if v.cond and not data[v.idx].uncovered and data[v.idx].num < 100 then
              mod:uncoverSquares(data, 0, v.idx, s, w, h, timer, iter + 1)
            end
          end
        end
        
        if iter == 0 then
          if mod:isFailure(data) then
            -- setAllBombs? you can just click the view button
            ImGui.UpdateText('shenanigansBtn' .. s .. 'Restart', mod.faceSad)
            ImGui.PushNotification('You lose!' .. mod.faceSad, ImGuiNotificationType.ERROR, 10000)
            sfx:Play(SoundEffect.SOUND_MOM_VOX_EVILLAUGH) -- SOUND_MOM_VOX_FILTERED_EVILLAUGH
            timer.enabled = false
          elseif mod:isSuccess(data) then
            mod:setAllFlags(data, s, w, h)
            ImGui.UpdateText('shenanigansBtn' .. s .. 'Restart', mod.faceHappy)
            ImGui.PushNotification('You win!' .. mod.faceHappy, ImGuiNotificationType.SUCCESS, 10000)
            sfx:Play(SoundEffect.SOUND_MOM_VOX_DEATH) -- SOUND_MOM_VOX_FILTERED_DEATH_1, SOUND_PRETTY_FLY
            timer.enabled = false
          end
        end
      end
    end
  end
  
  function mod:setAllFlags(data, s, w, h)
    for i = 1, w * h do
      if data[i] and data[i].num == 100 then
        ImGui.UpdateText('shenanigansBtn' .. s .. i, mod.flagSolid)
        data[i].uncovered = false
        data[i].flagged = true
      end
    end
  end
  
  function mod:updateBombCount(data, s, w, h, bombCount)
    local flagCount = 0
    for i = 1, w * h do
      if data[i] and data[i].flagged then
        flagCount = flagCount + 1
      end
    end
    ImGui.UpdateText('shenanigansTxt' .. s .. 'Bombs', string.format(mod.bombTemplate, bombCount - flagCount))
  end
  
  function mod:updateColors(data, s, w, h)
    for i = 1, w * h do
      if mod.colorPreset ~= 'off' and data[i] and data[i].uncovered and data[i].num >= 1 and data[i].num <= 8 then
        local rgb = mod.colorPresets[mod.colorPreset][data[i].num]
        ImGui.SetTextColor('shenanigansBtn' .. s .. i, rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1)
      else
        ImGui.RemoveColor('shenanigansBtn' .. s .. i, ImGuiColor.Text)
      end
    end
  end
  
  function mod:generateData(data, bombCount, i, w, h)
    local rand = Random()
    local rng = RNG(rand <= 0 and 1 or rand, mod.rngShiftIdx)
    local totalCount = w * h
    
    -- create bombs
    local possibleBombIdxs = {}
    for j = 1, totalCount do
      -- first click is always safe
      -- we could check for hasSquareLeft|Right|Up|Down but it's not strictly necessary here
      if i ~= j then
        if not mod.firstClickIsZero or
           (
             i - w - 1 ~= j and
             i - w ~= j and
             i - w + 1 ~= j and
             i - 1 ~= j and
             i + 1 ~= j and
             i + w - 1 ~= j and
             i + w ~= j and
             i + w + 1 ~= j
           )
        then
          table.insert(possibleBombIdxs, j)
        end
      end
    end
    for j = 1, bombCount do
      data[table.remove(possibleBombIdxs, rng:RandomInt(#possibleBombIdxs) + 1)] = { uncovered = false, flagged = false, num = 100 }
    end
    
    -- generate numbers next to bombs (0-8)
    for j = 1, totalCount do
      if not data[j] then
        local num = 0
        local hasSquareLeft = mod:hasSquareLeft(j, w, h)
        local hasSquareRight = mod:hasSquareRight(j, w, h)
        local hasSquareUp = mod:hasSquareUp(j, w, h)
        local hasSquareDown = mod:hasSquareDown(j, w, h)
        for _, v in ipairs({
                            { cond = hasSquareUp and hasSquareLeft   , idx = j - w - 1 },
                            { cond = hasSquareUp                     , idx = j - w },
                            { cond = hasSquareUp and hasSquareRight  , idx = j - w + 1 },
                            { cond = hasSquareLeft                   , idx = j - 1 },
                            { cond = hasSquareRight                  , idx = j + 1 },
                            { cond = hasSquareDown and hasSquareLeft , idx = j + w - 1 },
                            { cond = hasSquareDown                   , idx = j + w },
                            { cond = hasSquareDown and hasSquareRight, idx = j + w + 1 },
                          })
        do
          if v.cond and data[v.idx] and data[v.idx].num == 100 then
            num = num + 1
          end
        end
        data[j] = { uncovered = false, flagged = false, num = num }
      end
    end
  end
  
  function mod:clearData(data)
    for k, _ in pairs(data) do
      data[k] = nil
    end
  end
  
  function mod:isSuccess(data)
    for _, v in pairs(data) do
      if v.num < 100 and not v.uncovered then
        return false
      end
    end
    return true
  end
  
  function mod:isFailure(data)
    for _, v in pairs(data) do
      if v.num == 100 and v.uncovered then
        return true
      end
    end
    return false
  end
  
  function mod:hasSquareLeft(i, w, h)
    return (i - 1) % w ~= 0
  end
  
  function mod:hasSquareRight(i, w, h)
    return i % w ~= 0
  end
  
  function mod:hasSquareUp(i, w, h)
    return i - w > 0
  end
  
  function mod:hasSquareDown(i, w, h)
    return i + w <= w * h
  end
  
  -- don't seem to be able to check keyboard or mouse keys here
  function mod:isControllerTriggerPressed()
    local triggerLeft = 9
    local triggerRight = 12
    for i = 1, 1000 do -- 0 is keyboard
      if Input.IsButtonPressed(triggerLeft, i) or Input.IsButtonPressed(triggerRight, i) then
        return true
      end
    end
    return false
  end
  
  mod:setupImGuiMenu()
  mod:AddCallback(ModCallbacks.MC_POST_MODS_LOADED, mod.onModsLoaded)
end