local mod = RegisterMod('Minesweeper Shenanigans', 1)
local sfx = SFXManager()
local game = Game()

if REPENTOGON then
  mod.rngShiftIdx = 35
  mod.faceNormal = '\u{f5b3}'
  mod.faceHappy = '\u{f59a}'
  mod.faceSad = '\u{f5c8}'
  mod.circle = '\u{f111}'
  mod.square = '\u{f45c}'
  mod.flagSolid = '\u{f024}'
  mod.flagCheckered = '\u{f11e}'
  mod.bomb = '\u{f1e2}' -- e51b
  mod.bombTemplate = mod.bomb .. ' %03d'
  mod.timerTemplate = '\u{f2f2} %03d' -- f017
  
  mod.globalData = {}
  mod.customWidth = 4
  mod.customHeight = 4
  mod.customBombCount = 4
  
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
  mod.prizeStatus = 0 -- 0 (off), 1 (pickups), 2 (pickups or item)
  mod.squareSize = 50 -- 40, 50, 60
  mod.colorPreset = 'dark' -- off, dark, light
  mod.firstClickIsZero = true
  mod.numbersEnabled = true
  mod.chordsEnabled = true
  
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
    ImGui.AddTab('shenanigansTabBarMinesweeper', 'shenanigansTabMinesweeperCustom', 'Custom')
    ImGui.AddTab('shenanigansTabBarMinesweeper', 'shenanigansTabMinesweeperSettings', 'Settings')
    
    mod:setupBoard('MinesweeperBeginner', 9, 9, 10) -- 8x8 in older versions of minesweeper
    mod:setupBoard('MinesweeperIntermediate', 16, 16, 40)
    mod:setupBoard('MinesweeperExpert', 30, 16, 99)
    mod:setupBoard('MinesweeperCustom', mod.customWidth, mod.customHeight, mod.customBombCount)
    
    ImGui.AddElement('shenanigansTabMinesweeperSettings', '', ImGuiElement.SeparatorText, 'Settings')
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingFirstClick', 'First click', function(i)
      mod.firstClickIsZero = i == 1
    end, { 'Safe', 'Safe + empty' }, mod.firstClickIsZero and 1 or 0, true)
    ImGui.SetHelpmarker('shenanigansCmbMinesweeperSettingFirstClick', 'This will fallback to "safe" if there\'s not enough room for "safe + empty"')
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingChords', 'Chords', function(i)
      mod.chordsEnabled = i == 1
    end, { 'Disabled', 'Enabled' }, mod.chordsEnabled and 1 or 0, true)
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingNumbers', 'Numbers', nil, { 'Disabled', 'Enabled' }, mod.numbersEnabled and 1 or 0, true)
    ImGui.AddCallback('shenanigansCmbMinesweeperSettingNumbers', ImGuiCallback.DeactivatedAfterEdit, function(i)
      mod.numbersEnabled = i == 1
      for _, v in ipairs({
                          { s = 'MinesweeperBeginner'    , w = 9 , h = 9 },
                          { s = 'MinesweeperIntermediate', w = 16, h = 16 },
                          { s = 'MinesweeperExpert'      , w = 30, h = 16 },
                          { s = 'MinesweeperCustom' },
                        })
      do
        local w = v.s == 'MinesweeperCustom' and mod.customWidth or v.w
        local h = v.s == 'MinesweeperCustom' and mod.customHeight or v.h
        for i = 1, w * h do
          if mod.globalData[v.s][i] and mod.globalData[v.s][i].uncovered and mod.globalData[v.s][i].num >= 1 and mod.globalData[v.s][i].num <= 8 then
            local txt = mod.numbersEnabled and mod.globalData[v.s][i].num or mod.circle
            ImGui.UpdateText('shenanigansBtn' .. v.s .. i, txt)
          end
        end
      end
    end)
    ImGui.SetHelpmarker('shenanigansCmbMinesweeperSettingNumbers', 'Make sure to enable colors if you disable numbers')
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingColors', 'Colors', nil, { 'Off', 'Dark', 'Light' }, 1, true)
    ImGui.AddCallback('shenanigansCmbMinesweeperSettingColors', ImGuiCallback.DeactivatedAfterEdit, function(_, s)
      mod.colorPreset = string.lower(s)
      for _, v in ipairs({
                          { s = 'MinesweeperBeginner'    , w = 9 , h = 9 },
                          { s = 'MinesweeperIntermediate', w = 16, h = 16 },
                          { s = 'MinesweeperExpert'      , w = 30, h = 16 },
                          { s = 'MinesweeperCustom' },
                        })
      do
        local w = v.s == 'MinesweeperCustom' and mod.customWidth or v.w
        local h = v.s == 'MinesweeperCustom' and mod.customHeight or v.h
        mod:updateColors(mod.globalData[v.s], v.s, w, h)
      end
    end)
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingSize', 'Size', nil, { 40, 50, 60 }, 1, true)
    ImGui.AddCallback('shenanigansCmbMinesweeperSettingSize', ImGuiCallback.DeactivatedAfterEdit, function(_, s)
      mod.squareSize = tonumber(s)
      for _, v in ipairs({
                          { s = 'MinesweeperBeginner'    , w = 9 , h = 9 },
                          { s = 'MinesweeperIntermediate', w = 16, h = 16 },
                          { s = 'MinesweeperExpert'      , w = 30, h = 16 },
                          { s = 'MinesweeperCustom' },
                        })
      do
        local w = v.s == 'MinesweeperCustom' and mod.customWidth or v.w
        local h = v.s == 'MinesweeperCustom' and mod.customHeight or v.h
        for i = 1, w * h do
          ImGui.SetSize('shenanigansBtn' .. v.s .. i, mod.squareSize, mod.squareSize)
        end
      end
    end)
    ImGui.AddCombobox('shenanigansTabMinesweeperSettings', 'shenanigansCmbMinesweeperSettingPrizes', 'Prizes', function(i)
      mod.prizeStatus = i
    end, { 'Off', 'Pickups', 'Pickups or item' }, mod.prizeStatus, true)
    ImGui.SetHelpmarker('shenanigansCmbMinesweeperSettingPrizes', 'You must be in a run and can\'t use the hint system to be eligible for a prize!\n\nPrizes include: hearts, coins, keys, bombs, batteries, pills, cards, trinkets, or grab bags. You can also enable a chance for a treasure room item which will replace the pickups if successful (only for intermediate or expert).\n\nBeginner: 2 pickups\nIntermediate: 3 pickups or 1 item\nExpert: 4 pickups or 1 item\nCustom: 0 pickups')
    ImGui.AddElement('shenanigansTabMinesweeperSettings', '', ImGuiElement.SeparatorText, 'Custom')
    local customBoard = { width = mod.customWidth, height = mod.customHeight, bombCount = mod.customBombCount }
    for _, v in ipairs({
                        { field = 'width'    , suffix = 'Width'    , text = 'Width'     , min = 1, max = 30 },
                        { field = 'height'   , suffix = 'Height'   , text = 'Height'    , min = 1, max = 16 },
                        { field = 'bombCount', suffix = 'BombCount', text = 'Bomb count', min = 0, max = (customBoard.width * customBoard.height) - 1 },
                      })
    do
      ImGui.AddSliderInteger('shenanigansTabMinesweeperSettings', 'shenanigansIntMinesweeperCustom' .. v.suffix, v.text, nil, customBoard[v.field], v.min, v.max)
      ImGui.AddCallback('shenanigansIntMinesweeperCustom' .. v.suffix, ImGuiCallback.DeactivatedAfterEdit, function(i)
        customBoard[v.field] = i
        local maxBombCount = (customBoard.width * customBoard.height) - 1
        ImGui.UpdateData('shenanigansIntMinesweeperCustomBombCount', ImGuiData.Max, maxBombCount)
        if customBoard.bombCount > maxBombCount then
          customBoard.bombCount = maxBombCount
          ImGui.UpdateData('shenanigansIntMinesweeperCustomBombCount', ImGuiData.Value, customBoard.bombCount)
        end
      end)
    end
    ImGui.AddButton('shenanigansTabMinesweeperSettings', 'shenanigansBtnMinesweeperCustomGenerate', 'Generate custom board', function()
      mod:removeBoard('MinesweeperCustom', mod.customWidth, mod.customHeight)
      mod.customWidth = customBoard.width
      mod.customHeight = customBoard.height
      mod.customBombCount = customBoard.bombCount
      mod:setupBoard('MinesweeperCustom', mod.customWidth, mod.customHeight, mod.customBombCount)
    end, false)
  end
  
  function mod:removeBoard(s, w, h)
    for _, v in ipairs({
                        'shenanigansBtn' .. s .. 'Restart',
                        'shenanigansBtn' .. s .. 'View',
                        'shenanigansBtn' .. s .. 'Hint',
                        'shenanigansRad' .. s .. 'Flag',
                        'shenanigansTxt' .. s .. 'Bombs',
                        'shenanigansTxt' .. s .. 'Timer',
                        'shenanigansSl' .. s .. 'Top1',
                        'shenanigansSl' .. s .. 'Top2',
                        'shenanigansSl' .. s .. 'Top3',
                        'shenanigansSl' .. s .. 'Top4',
                        'shenanigansSl' .. s .. 'Top5',
                        'shenanigansSep' .. s,
                      })
    do
      ImGui.RemoveElement(v)
    end
    
    local i = 0
    for iH = 1, h do
      for iW = 1, w do
        i = i + 1
        ImGui.RemoveElement('shenanigansBtn' .. s .. i)
        if iW ~= w then
          ImGui.RemoveElement('shenanigansSl' .. s .. iH .. '-' .. iW)
        end
      end
    end
  end
  
  function mod:setupBoard(s, w, h, bombCount)
    local tab = 'shenanigansTab' .. s
    local timer = { enabled = false, startTime = 0, seconds = 0 }
    local hintUsed = false
    
    local data = {}
    mod.globalData[s] = data
    
    local btnRestartId = 'shenanigansBtn' .. s .. 'Restart'
    local btnViewId = 'shenanigansBtn' .. s .. 'View'
    local btnHintId = 'shenanigansBtn' .. s .. 'Hint'
    local radFlagId = 'shenanigansRad' .. s .. 'Flag'
    local txtBombsId = 'shenanigansTxt' .. s .. 'Bombs'
    local txtTimerid = 'shenanigansTxt' .. s .. 'Timer'
    
    ImGui.AddButton(tab, btnRestartId, mod.faceNormal, function()
      mod:clearData(data)
      for i = 1, w * h do
        ImGui.UpdateText('shenanigansBtn' .. s .. i, mod.square)
      end
      ImGui.UpdateText(btnRestartId, mod.faceNormal)
      mod:updateBombCount(data, s, w, h, bombCount)
      mod:updateColors(data, s, w, h)
      timer.enabled = false
      timer.seconds = 0
      hintUsed = false
    end, false)
    ImGui.AddElement(tab, 'shenanigansSl' .. s .. 'Top1', ImGuiElement.SameLine, '')
    ImGui.AddButton(tab, btnViewId, '\u{f06e}', function()
      if #data == 0 then
        local rand = Random()
        local rng = RNG(rand <= 0 and 1 or rand, mod.rngShiftIdx)
        mod:generateData(data, bombCount, rng:RandomInt(w * h) + 1, w, h)
      end
      for i = 1, w * h do
        local txt = mod.numbersEnabled and data[i].num or mod.circle
        if data[i].num == 0 then
          txt = ''
        elseif data[i].num == 100 then
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
    ImGui.AddElement(tab, 'shenanigansSl' .. s .. 'Top2', ImGuiElement.SameLine, '')
    ImGui.AddButton(tab, btnHintId, '\u{f059}', function()
      if mod:isFailure(data) or mod:isSuccess(data) then
        return
      end
      local idxs = {}
      local idxsAboveZero = {}
      for i = 1, w * h do
        if data[i] and not data[i].uncovered and not data[i].flagged and data[i].num < 100 then
          table.insert(idxs, i)
          if data[i].num > 0 then
            table.insert(idxsAboveZero, i)
          end
        end
      end
      if #idxsAboveZero > 1 then -- force the user to make the winning click
        local rand = Random()
        local rng = RNG(rand <= 0 and 1 or rand, mod.rngShiftIdx)
        hintUsed = true
        mod:uncoverSquares(data, 0, idxs[rng:RandomInt(#idxs) + 1], s, w, h, timer, hintUsed)
        mod:updateBombCount(data, s, w, h, bombCount)
        mod:updateColors(data, s, w, h)
      end
    end, false)
    ImGui.AddElement(tab, 'shenanigansSl' .. s .. 'Top3', ImGuiElement.SameLine, '')
    
    ImGui.AddRadioButtons(tab, radFlagId, function(i)
      mod.flagStatus = i
      for _, v in ipairs({ 'MinesweeperBeginner', 'MinesweeperIntermediate', 'MinesweeperExpert', 'MinesweeperCustom' }) do
        ImGui.UpdateData('shenanigansRad' .. v .. 'Flag', ImGuiData.Value, i) -- keep setting in-sync between tabs
      end
    end, { '\u{f8cc}', mod.flagSolid, mod.flagCheckered }, mod.flagStatus, true)
    ImGui.SetHelpmarker(radFlagId, 'Mouse: uncover square\nFlag: add or remove flag\nCheckered flag: add flag or uncover flagged square\n\nController: hold left or right trigger when clicking to temporarily use flag mode')
    ImGui.AddElement(tab, 'shenanigansSl' .. s .. 'Top4', ImGuiElement.SameLine, '')
    ImGui.AddText(tab, string.format(mod.bombTemplate, bombCount), false, txtBombsId)
    ImGui.AddElement(tab, 'shenanigansSl' .. s .. 'Top5', ImGuiElement.SameLine, '')
    ImGui.AddText(tab, string.format(mod.timerTemplate, 0), false, txtTimerid)
    ImGui.AddCallback(txtTimerid, ImGuiCallback.Visible, function()
      if timer.enabled then
        timer.seconds = os.difftime(os.time(), timer.startTime)
      end
      ImGui.UpdateText(txtTimerid, string.format(mod.timerTemplate, timer.seconds))
    end)
    ImGui.AddElement(tab, 'shenanigansSep' .. s, ImGuiElement.Separator, '')
    
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
            mod:uncoverSquares(data, 0, iLocal, s, w, h, timer, hintUsed)
          else
            local flagStatus = (mod.flagStatus ~= 1 and mod:isControllerTriggerPressed()) and 1 or mod.flagStatus
            mod:uncoverSquares(data, flagStatus, iLocal, s, w, h, timer, hintUsed)
          end
          mod:updateBombCount(data, s, w, h, bombCount)
          mod:updateColors(data, s, w, h)
        end, false)
        ImGui.SetSize(btnId, mod.squareSize, mod.squareSize)
        if iW ~= w then
          ImGui.AddElement(tab, 'shenanigansSl' .. s .. iH .. '-' .. iW, ImGuiElement.SameLine, '')
        end
      end
    end
  end
  
  function mod:uncoverSquares(data, flagStatus, i, s, w, h, timer, hintUsed, iter)
    iter = iter or 0
    
    if iter == 0 and (mod:isFailure(data) or mod:isSuccess(data)) then
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
    
    if mod.chordsEnabled and iter == 0 and data[i].uncovered and data[i].num >= 1 and data[i].num <= 8 then
      local flagCount = 0
      local coveredSquares = {}
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
        if v.cond then
          if data[v.idx].flagged then
            flagCount = flagCount + 1
          elseif not data[v.idx].uncovered then
            table.insert(coveredSquares, v.idx)
          end
        end
      end
      if flagCount == data[i].num and #coveredSquares > 0 then
        for _, v in ipairs(coveredSquares) do
          mod:uncoverSquares(data, 0, v, s, w, h, timer, hintUsed, iter + 1)
        end
        mod:doSuccessOrFailure(data, s, w, h, timer, hintUsed)
      end
      
      return
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
      if not data[i].uncovered and not data[i].flagged then
        local txt = mod.numbersEnabled and data[i].num or mod.circle
        if data[i].num == 0 then
          txt = ''
        elseif data[i].num == 100 then
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
            if v.cond and not data[v.idx].uncovered and not data[v.idx].flagged and data[v.idx].num < 100 then
              mod:uncoverSquares(data, 0, v.idx, s, w, h, timer, hintUsed, iter + 1)
            end
          end
        end
        
        if iter == 0 then
          mod:doSuccessOrFailure(data, s, w, h, timer, hintUsed)
        end
      end
    end
  end
  
  function mod:doSuccessOrFailure(data, s, w, h, timer, hintUsed)
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
      local prizes = mod:spawnPrizes(s, hintUsed)
      if prizes then
        ImGui.PushNotification('Prize(s): ' .. table.concat(prizes, ', '), ImGuiNotificationType.SUCCESS, 10000)
      end
      sfx:Play(SoundEffect.SOUND_MOM_VOX_DEATH) -- SOUND_MOM_VOX_FILTERED_DEATH_1, SOUND_PRETTY_FLY
      timer.enabled = false
    end
  end
  
  -- todo: time-based prizes?
  function mod:spawnPrizes(s, hintUsed)
    if mod.prizeStatus == 0 or not Isaac.IsInGame() or hintUsed or s == 'MinesweeperCustom' then
      return
    end
    
    local possiblePrizes = { 'heart', 'coin', 'key', 'bomb', 'battery', 'pill', 'card', 'trinket', 'grab bag' }
    if mod.prizeStatus == 2 and s ~= 'MinesweeperBeginner' then
      table.insert(possiblePrizes, 'item')
    end
    
    local itemPool = game:GetItemPool()
    local rand = Random()
    local rng = RNG(rand <= 0 and 1 or rand, mod.rngShiftIdx)
    local numPrizes = 2 -- MinesweeperBeginner
    if s == 'MinesweeperIntermediate' then
      numPrizes = 3
    elseif s == 'MinesweeperExpert' then
      numPrizes = 4
    end
    
    local prizes = {}
    for i = 1, numPrizes do
      local prize = table.remove(possiblePrizes, rng:RandomInt(#possiblePrizes) + 1)
      if prize == 'item' then
        prizes = { prize }
        break
      else
        table.insert(prizes, prize)
      end
    end
    
    for _, v in ipairs(prizes) do
      if v == 'heart' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'coin' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'key' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'bomb' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'battery' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_LIL_BATTERY, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'pill' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_PILL, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'card' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'trinket' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'grab bag' then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_GRAB_BAG, 0, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      elseif v == 'item' then
        -- don't spawn extra devil/angel room items
        local collectible = itemPool:GetCollectible(ItemPoolType.POOL_TREASURE, true, nil, CollectibleType.COLLECTIBLE_NULL)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, collectible, Isaac.GetFreeNearPosition(Isaac.GetRandomPosition(), 3), Vector.Zero, nil)
      end
    end
    
    return prizes
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
    
    local firstClickIsZero = mod.firstClickIsZero
    if totalCount - 9 < bombCount then
      firstClickIsZero = false
    end
    
    -- create bombs
    local possibleBombIdxs = {}
    local hasSquareLeft = mod:hasSquareLeft(i, w, h)
    local hasSquareRight = mod:hasSquareRight(i, w, h)
    local hasSquareUp = mod:hasSquareUp(i, w, h)
    local hasSquareDown = mod:hasSquareDown(i, w, h)
    for j = 1, totalCount do
      -- first click is always safe
      if i ~= j then
        if not firstClickIsZero or
           (
             not (hasSquareUp and hasSquareLeft and i - w - 1 == j) and
             not (hasSquareUp and i - w == j) and
             not (hasSquareUp and hasSquareRight and i - w + 1 == j) and
             not (hasSquareLeft and i - 1 == j) and
             not (hasSquareRight and i + 1 == j) and
             not (hasSquareDown and hasSquareLeft and i + w - 1 == j) and
             not (hasSquareDown and i + w == j) and
             not (hasSquareDown and hasSquareRight and i + w + 1 == j)
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