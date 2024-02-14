local jsonTableViewer = {}

local function addTabs(str, tab)
  if tab > 0 then
    for _=1, tab do
      str = '\t' .. str
    end
  end
  return str
end
local function min(arr)
  if #arr == 0 then
    return nil
  end
  table.sort(arr)
  return arr[1]
end

local function jsonLine2Table(intiStr, startInd, tab, resStr)
  if not intiStr then return '' end
  if not startInd then startInd = 1 end
  if not tab then tab = 0 end
  if not resStr then resStr = '' end
  local compArray = {}
  local nextSqBrOp = string.find(intiStr, '%[', startInd)
  if nextSqBrOp then table.insert(compArray, nextSqBrOp) end
  local nextSqBrCl = string.find(intiStr, '%]', startInd)
  if nextSqBrCl then table.insert(compArray, nextSqBrCl) end
  local nextCuBrCl = string.find(intiStr, '}', startInd)
  if nextCuBrCl then table.insert(compArray, nextCuBrCl) end
  local nextCuBrOp = string.find(intiStr, '{', startInd)
  if nextCuBrOp then table.insert(compArray, nextCuBrOp) end
  local nextComma = string.find(intiStr, ',', startInd)
  if nextComma then table.insert(compArray, nextComma) end
  local minVal = min(compArray)
  if minVal then
    local currentSymbol = string.sub(intiStr, minVal, minVal)
    local content = ''
    if startInd < minVal then
      content = string.sub(intiStr, startInd, minVal-1)
    end
    if minVal == nextCuBrOp or minVal == nextSqBrOp then
      resStr = resStr .. addTabs(content .. currentSymbol .. '\n', tab)
      tab = tab + 1
      
    elseif minVal == nextCuBrCl or minVal == nextSqBrCl then
      resStr = resStr .. addTabs(content, tab) .. '\n' 
      tab = tab - 1
      resStr = resStr .. addTabs(currentSymbol, tab)
    elseif nextComma and minVal == nextComma then
      if content == '' then
        resStr = resStr.. currentSymbol .. '\n'
      else
        resStr = resStr .. addTabs(content .. currentSymbol .. '\n', tab)
      end
    end
    resStr = jsonLine2Table(intiStr, minVal+1, tab, resStr)
  end
  return resStr
end
jsonTableViewer.jsonLine2Table = jsonLine2Table

return jsonTableViewer