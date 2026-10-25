local component = require("component")
local gpu = component.gpu

local event = require("event")
--Шрифт Брайлля
local br = require("braille")

--Пустой символ
local emptyChar = ' '

--Таблица координат для нажатия
local touchCoordsTable = {}

--Матрица ячеек
local cellsMatrix
--Активная ячейка
local activeCell

local isPerfrom = true

--Активная кнопка
local activeKey

local start

--SideBar
local sideBar ={
    {
        value = "1",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    },
    {
        value = "2",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    }
    ,
    {
        value = "3",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    },
    {
        value = "4",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    },
    {
        value = "5",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    }
}
--SideBar
local sideBarSecond ={
    {
        value = "6",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    },
    {
        value = "7",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    }
    ,
    {
        value = "8",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    },
    {
        value = "9",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    },
    
    {
        value = "0",
        isActive = false,
        size = {
            width = 12,
            widthDefault = 12,
            height = 6,
            heightDefault = 6
        },
        borderSize = {
            x = 2,
            y = 1
        },
        colorForeground = 0x7B68EE,
        colorBackground = 0xE6E6FA,
        colorActiveForeground = 0x7B68EE,
        colorActiveBackground = 0x00FFFF,
        func = setActiveKey
    }
}

--Конфигурация
-------------------------------
local sizeCell = {x = 8, y = 4} --Размер ячейки2
local sizeCellBorder = {x = 2, y = 1} -- Толщина границы
local sizeSquareBorder = {x = 4, y = 2} -- Толщина границы

local cellExample = { --Параметры ячейки (Ширина границы - 2)
    size = sizeCell,
    answer = null,
    coords = {x = nil, y = nil},
    bordersType = { --Тип линий (0, отсутствие,1 - тонкая, 2 - жирная). По час. стрелке
        borderTop = 0,
        borderRight = 0,
        borderBottom = 0,
        borderLeft = 0
    } 
}

local normalBorderColor = 0xC0C0C0
local boldBorderColor = 0x696969
local activeCellColorBackground = 0xDCDCDC
local activeCellColorForeground = 0xFF0000	
local defaultCellColorBackground = 0x000
local defaultCellColorForeground = 0x808000
local hintCellColor = 0xFFFFFF
local sameNumberColor = 0x00FF00
local notEditableColor = 0x006400
local wrongAnswerColor = 0xB22222

--Базовая сетка судоку
local baseGrid = {
    {1, 2, 3, 4, 5, 6, 7, 8, 9},
    {4, 5, 6, 7, 8, 9, 1, 2 ,3},
    {7, 8, 9, 1, 2, 3, 4, 5, 6},
    {2, 3, 4, 5, 6, 7, 8, 9, 1},
    {5, 6, 7, 8, 9, 1, 2, 3, 4},
    {8, 9, 1, 2, 3, 4, 5, 6, 7},
    {3, 4, 5, 6, 7, 8, 9, 1, 2},
    {6, 7, 8, 9, 1, 2, 3, 4, 5},
    {9, 1, 2, 3, 4, 5, 6, 7, 8}
}

--Другие сетки
local generatedFullGrid, generatedNeFullGrid, userGrid

local font = {}

local zero = br.matrix(10,14)
    br.line(zero, 4,4, 4, 13)
    br.line(zero, 5,3, 5, 14)

    br.line(zero, 6,2,6,4)
    br.line(zero, 6,13,6,15)

    br.line(zero, 7,2,10,2)
    br.line(zero, 7,3,10,3)



    br.line(zero, 7,15,10,15)
    br.line(zero, 7,14,10,14)

    br.line(zero, 11,2,11,4)
    br.line(zero, 11,13,11,15)

    br.line(zero, 13,4, 13, 13)
    br.line(zero, 12,3, 12, 14)

    font.zero = zero

local one = br.matrix(10,16)
    br.line(one, 5, 2, 6, 2)
    br.line(one, 4, 3, 6, 3)
    br.line(one, 3, 4, 6, 4)
    br.line(one, 2, 5, 6, 5)
    br.line(one, 2, 6, 3, 6)
    br.line(one, 5, 6, 5, 13)
    br.line(one, 6, 6, 6, 13)
    br.line(one, 1, 14, 10, 14)
    br.line(one, 1, 15, 10, 15)

    font.one = one

local two = br.matrix(10,16)
    br.line(two, 3, 2, 8, 2)
    br.line(two, 2, 3, 9, 3)
    br.line(two, 1, 4, 3, 4)
    br.line(two, 7, 4, 10, 4)
    br.line(two, 1, 5, 2, 5)
    br.line(two, 8, 5, 10, 5)
    br.line(two, 8, 6, 10, 6)
    br.line(two, 7, 7, 10, 7)
    br.line(two, 3, 8, 9, 8)
    br.line(two, 2, 9, 8, 9)
    br.line(two, 1, 10, 3, 10)
    br.line(two, 1, 11, 1, 13)
    br.line(two, 2, 11, 2, 13)
    br.line(two, 1, 14, 10, 14)
    br.line(two, 1, 15, 10, 15)
    
    font.two = two

local three = br.matrix(10,16)
    br.line(three, 1, 2, 10, 2)
    br.line(three, 1, 3, 10, 3)

    br.line(three, 8, 4, 10, 4)
    br.line(three, 7, 5, 9, 5)
    br.line(three, 6, 6, 8, 6)

    br.line(three, 5, 7, 7, 7)
    br.line(three, 4, 8, 8, 8)
    br.line(three, 4, 9, 9, 9)

    br.line(three, 8, 10, 10, 10)

    br.line(three, 9, 11, 10, 11)
    br.line(three, 9, 12, 10, 12)

    br.line(three, 8, 13, 10, 13)

    br.line(three, 2, 14, 9, 14)
    br.line(three, 3, 15, 8, 15)

    br.line(three, 1, 13, 3, 13)
    br.line(three, 1, 12, 2, 12)

    font.three = three

local four = br.matrix(10,16)
    br.line(four, 7, 2, 7, 15)
    br.line(four, 8, 2, 8, 15)

    br.line(four, 1, 10, 10, 10)
    br.line(four, 1, 11, 10, 11)

    br.line(four, 1, 9, 2, 9)

    br.line(four, 1, 8, 3, 8)
    br.line(four, 2, 7, 4, 7)
    br.line(four, 3, 6, 5, 6)
    br.line(four, 4, 5, 6, 5)
    br.line(four, 5, 4, 7, 4)
    br.line(four, 6, 3, 7, 3)

    font.four = four

local five = br.matrix(10, 16)

    br.line(five, 1, 2, 10 ,2)
    br.line(five, 1, 3, 10 ,3)

    
    br.line(five, 1, 4, 1 ,6)
    br.line(five, 2, 4, 2 ,6)

    br.line(five, 1, 7, 8 ,7)
    br.line(five, 1, 8, 9 ,8)

    br.line(five, 8, 9, 10 ,9)

    br.line(five, 9, 10, 9 ,12)
    br.line(five, 10, 10, 10 ,12)

    br.line(five, 8, 13, 10 ,13)

    br.line(five, 1, 12, 2 ,12)
    br.line(five, 1, 13, 3 ,13)

    br.line(five, 2, 14, 9 ,14)
    br.line(five, 3, 15, 8 ,15)

    font.five = five

local six = br.matrix(10, 16)
    br.line(six, 3, 2, 8, 2)
    br.line(six, 2, 3, 9, 3)

    br.line(six, 1, 4, 3, 4)
    br.line(six, 8, 4, 10, 4)

    br.line(six, 1, 5, 1, 13)
    br.line(six, 2, 5, 2, 14)

    br.line(six, 3, 13, 3 ,15)

    br.line(six, 4, 14, 9, 14)
    br.line(six, 4, 15, 8, 15)

    br.line(six, 8, 13, 10 ,13)

    br.line(six, 9, 10, 9 ,12)
    br.line(six, 10, 10, 10 ,12)

    br.line(six, 8, 9, 10 ,9)
    br.line(six, 1, 8, 10 ,8)
    br.line(six, 4, 7, 8 ,7)

    br.set(six, 3, 9, 1)
    br.set(six, 10, 8, 0)

    br.line(six, 9, 5, 10 ,5)

    font.six = six

local seven = br.matrix(10, 16)
    br.line(seven, 1, 2, 10 ,2)
    br.line(seven, 1, 3, 10 ,3)

    br.line(seven, 8, 4, 9 ,4)
    br.line(seven, 8, 5, 9 ,5)

    br.line(seven, 7, 6, 8 ,6)
    br.line(seven, 7, 7, 8 ,7)

    br.line(seven, 6, 8, 7 ,8)
    br.line(seven, 6, 9, 7 ,9)

    br.line(seven, 5, 10, 6 ,10)
    br.line(seven, 5, 11, 6 ,11)
    
    br.line(seven, 4, 12, 5 ,12)
    br.line(seven, 4, 13, 5 ,13)

    br.line(seven, 3, 14, 4 ,14)
    br.line(seven, 3, 15, 4 ,15)

    font.seven = seven

local eight = br. matrix(10, 16)
    br.line(eight, 3, 2, 8, 2)
    br.line(eight, 2, 3, 9, 3)

    br.line(eight, 1, 4, 3, 4)
    br.line(eight, 8, 4, 10, 4)

    br.line(eight, 1, 5, 2, 5)
    br.line(eight, 1, 6, 2, 6)

    br.line(eight, 9, 5, 10, 5)
    br.line(eight, 9, 6, 10, 6)

    br.line(eight, 1, 7, 3, 7)
    br.line(eight, 8, 7, 10, 7)

    br.line(eight, 2, 8, 9, 8)
    br.line(eight, 2, 9, 9, 9)

    br.line(eight, 1, 10, 3, 10)
    br.line(eight, 8, 10, 10, 10)

    br.line(eight, 1, 11, 2, 11)
    br.line(eight, 1, 12, 2, 12)

    br.line(eight, 9, 11, 10, 11)
    br.line(eight, 9, 12, 10, 12)

    br.line(eight, 1, 13, 3, 13)
    br.line(eight, 8, 13, 10, 13)

    br.line(eight, 2, 14, 9, 14)
    br.line(eight, 3, 15, 8, 15)

    font.eight = eight

local nine = br.matrix(10,16)

    br.line(nine, 3, 2, 8, 2)
    br.line(nine, 2, 3, 9, 3)

    br.line(nine, 1, 4, 3, 4)
    br.line(nine, 8, 4, 10, 4)

    br.line(nine, 1, 5, 1, 7)
    br.line(nine, 2, 5, 2, 7)
    br.line(nine, 1, 8, 3, 8)

    br.line(nine, 9, 5, 9, 14)
    br.line(nine, 10, 5, 10, 13)

    br.line(nine, 8, 13, 8, 15)

    br.line(nine, 2, 9, 8, 9)
    br.line(nine, 3, 10, 7, 10)

    br.set(nine, 8, 8, 1)

    br.line(nine, 2, 14, 9, 14)
    br.line(nine, 3, 15, 8, 15)

    br.line(nine, 1, 12, 2, 12)
    br.line(nine, 1, 13, 3, 13)

    font.nine = nine

    font = {one, two, three, four, five, six, seven, eight, nine}
local function transposingMatrix(matrix)
    local tMatrix = {}
    for i = 1, #matrix do
        table.insert(tMatrix, {})
        for j = 1, #matrix[i] do
            table.insert(tMatrix[i], matrix[j][i])
        end
    end

    return tMatrix
end

local function swapRowsInSquare(matrix)
    local squareNumber = math.random(1, 3)
    local firstRow = math.random(1, 3) + squareNumber * 3 - 3
    local secondRow = math.random(1, 3) + squareNumber * 3 - 3

    while firstRow == secondRow do
        secondRow = math.random(1, 3) + squareNumber * 3 - 3
    end

    local tmpRow = {}

    for j = 1, #matrix[firstRow] do
        table.insert(tmpRow, matrix[firstRow][j])
        matrix[firstRow][j] = matrix[secondRow][j]
    end

    matrix[secondRow] = tmpRow

    return matrix
end

local function swapColumnsInSquare(matrix)
    local squareNumber = math.random(1, 3)
    local firstColumn = math.random(1, 3) + squareNumber * 3 - 3
    local secondColumn = math.random(1, 3) + squareNumber * 3 - 3

    while firstColumn == secondColumn do
        secondColumn = math.random(1, 3) + squareNumber * 3 - 3
    end
    
    local tmpColumn = {}

    for i = 1, #matrix do
        table.insert(tmpColumn, matrix[i][firstColumn])
        matrix[i][firstColumn] = matrix[i][secondColumn]
        matrix[i][secondColumn] = tmpColumn[i]
    end

    return matrix
end

local function swapRows(matrix)
    local firstSquareNumber = math.random(1, 3)
    local secondSquareNumber = math.random(1, 3)

    while firstSquareNumber == secondSquareNumber do
        secondSquareNumber = math.random(1, 3)
    end

    local tmpRow = {}
    local count = 1
    for i = firstSquareNumber * 3 - 2, firstSquareNumber * 3 do
        table.insert(tmpRow, {})
        for j = 1, 9 do
            table.insert(tmpRow[count], matrix[i][j])
            matrix[i][j] = matrix[secondSquareNumber * 3 - 3 + count][j]
            matrix[secondSquareNumber * 3 - 3 + count][j] = tmpRow[count][j]
        end

        count = count + 1
    end
    return matrix
end

local function spawColumns(matrix)
    local firstSquareNumber = math.random(1, 3)
    local secondSquareNumber = math.random(1, 3)

    while firstSquareNumber == secondSquareNumber do
        secondSquareNumber = math.random(1, 3)
    end

    local tmpColumn = {}
    local count = 1
    for i = 1, 9 do
        
        for j = firstSquareNumber * 3 - 2, firstSquareNumber * 3 do
            local tmpCell = matrix[i][j]
            matrix[i][j] = matrix[i][secondSquareNumber * 3 - 3 + count]
            matrix[i][secondSquareNumber * 3 - 3 + count] = tmpCell
            
            count = count + 1
        end
        count = 1
    end

    return matrix

end

--Генерация судоку
local function generateSudoku()
    local generatedFullGrid, generatedNeFullGrid 
    generatedFullGrid = baseGrid

    local countIteration = math.random(30, 40)

    for i = 1, countIteration do
        local operation = math.random(1, 5)

        if (operation == 1) then
            generatedFullGrid = transposingMatrix(generatedFullGrid)
        elseif(operation == 2) then
            generatedFullGrid = swapRowsInSquare(generatedFullGrid)
        elseif(operation == 3) then
            generatedFullGrid = swapColumnsInSquare(generatedFullGrid)
        elseif(operation == 4) then
            generatedFullGrid = swapRows(generatedFullGrid)
        elseif(operation == 5) then
            generatedFullGrid = spawColumns(generatedFullGrid)
        end
    end

    generatedNeFullGrid = {}
    
    for i = 1, #generatedFullGrid do
        table.insert(generatedNeFullGrid, {})

        for j = 1, #generatedFullGrid[i] do
            generatedNeFullGrid[i][j] = generatedFullGrid[i][j]
        end
    end



    for i = 1, 3 do
        for j = 1, 3 do
            local rand = math.random(2, 6)
            local cellIndex = {i * 3 - 3 + 1}
            local cellsIndex = {
                {i * 3 - 3 + 1, j * 3 - 3 + 1}, {i * 3 - 3 + 1, j * 3 - 3 + 2}, {i * 3 - 3 + 1, j * 3 - 3 + 3},
                {i * 3 - 3 + 2, j * 3 - 3 + 1}, {i * 3 - 3 + 2, j * 3 - 3 + 2}, {i * 3 - 3 + 2, j * 3 - 3 + 3},
                {i * 3 - 3 + 3, j * 3 - 3 + 1}, {i * 3 - 3 + 3, j * 3 - 3 + 2}, {i * 3 - 3 + 3, j * 3 - 3 + 3},
            }

            for k = 1, rand do
                local rand2 = math.random(1, 9 - k + 1)
                generatedNeFullGrid[cellsIndex[rand2][1]][cellsIndex[rand2][2]] = emptyChar
                table.remove(cellsIndex, rand2)
            end
        end
    end

    return generatedFullGrid, generatedNeFullGrid
end

--Установливает основной цвет
local function setForegroundColor(color)
    if gpu.getForeground() == color then
        return
    else
        gpu.setForeground(color)
    end
end

--Установливает цвет фона
local function setBackgoundColor(color)
    if gpu.getBackground() == color then
        return
    else
        gpu.setBackground(color)
    end
end

local function clearScreen()
    local width, height = gpu.getResolution()

    setBackgoundColor(0x000)
    gpu.fill(1, 1, width, height, emptyChar)

    setForegroundColor(0xA9A9A9)
    setBackgoundColor(0x000000)
    gpu.set(1, 50, "All right reserved GovnoCodeGroup | 2023 - 2023")
    gpu.set(149, 50, "by Antonesku")
end

local function getCell(pos)
    for i = 1, #cellsMatrix do
        for j = 1, #cellsMatrix[i] do
            if cellsMatrix[i][j].params[1] == pos[1] and   cellsMatrix[i][j].params[2] == pos[2] then
                return cellsMatrix[i][j]
            end
        end
    end
end

local function getCellsByNumber(number)
    local posList = {}
    for i = 1, #userGrid do
        for j = 1, #userGrid do
            if userGrid[i][j] == number then
                table.insert(posList, {i, j})
            end
        end
    end

    return posList
end



local function drawBackgroundCell(cell, colorBackground)
    setBackgoundColor(colorBackground)
    gpu.fill(cell.x1, cell.y1, cell.x2 - cell.x1, cell.y2 - cell.y1, emptyChar)
end

local function drawForegroundCell(cell, colorForeground)
    setForegroundColor(colorForeground)
    local number = userGrid[cell.params[1]][cell.params[2]]
    
    if number ~= emptyChar then
        br.render(font[number], cell.x1 + 2, cell.y1)
    end
    
end

local function drawContentCell(cell, type)
    local pos = cell.params
    local numberRow, numberColumn = pos[1], pos[2]

    --Задний фон
    if type == "active" then
        drawBackgroundCell(cell, activeCellColorBackground)
    elseif type == "hint" then
        drawBackgroundCell(cell, hintCellColor)
    else
        drawBackgroundCell(cell, defaultCellColorBackground)
    end

    --Цвет шрифта
    

    --Неизменяемая ячейка
    if generatedNeFullGrid[numberRow][numberColumn] ~= emptyChar then
        drawForegroundCell(cell, notEditableColor)
    end

    if userGrid[numberRow][numberColumn] == generatedFullGrid[numberRow][numberColumn]
        and userGrid[numberRow][numberColumn] ~= generatedNeFullGrid[numberRow][numberColumn] then  
        --Правильная ячейка
        drawForegroundCell(cell, defaultCellColorForeground)
    end

    if type == "hintFore" or type == "active" then 
        drawForegroundCell(cell, sameNumberColor)
    end

    if userGrid[numberRow][numberColumn] ~= generatedFullGrid[numberRow][numberColumn] then  
        --Неправильная ячейка
        drawForegroundCell(cell, wrongAnswerColor)
    end



    
end

local function drawHint(pos, isDraw) 
    local currentCell
    
    local sameNumberList = getCellsByNumber(userGrid[pos[1]][pos[2]])
    local currentPos 
    for i = 1, #sameNumberList do
        currentPos = sameNumberList[i]
        currentCell = getCell({currentPos[1], currentPos[2]})
        if isDraw then
            drawContentCell(currentCell, "hintFore")
        else
            drawContentCell(currentCell)
        end
    end

    if isDraw then
        sameNumberList = getCellsByNumber(getCell(pos).prevValue)

        for i = 1, #sameNumberList do
            currentPos = sameNumberList[i]
            currentCell = getCell({currentPos[1], currentPos[2]})

            drawContentCell(currentCell)
        end
    end

    


    for i = 1, 9 do
        currentCell = getCell({i, pos[2]})

        if isDraw then
            drawContentCell(currentCell, "hint")
        else
            drawContentCell(currentCell)
        end
    
    end

    for j = 1, 9 do
        currentCell = getCell({pos[1], j})

        if isDraw then
            drawContentCell(currentCell, "hint")
        else
            drawContentCell(currentCell)
        end
    end
    
end


local function setActiveCell(pos)
    if activeCell ~= nil then
        drawContentCell(getCell(pos))

        local isDraw = false
        drawHint(activeCell.params, isDraw)
    end

    local isDraw = true
    drawHint(pos, isDraw)

    local cell = getCell(pos)
    activeCell = cell

    drawContentCell(cell, "active")
end

local function drawCell(x, y, numberRow, numberColumn)
    local width = sizeCell.x + sizeCellBorder.x * 2
    local height = sizeCell.y + sizeCellBorder.y * 2

    local verticalBorder = br.matrix(sizeCellBorder.x * 2, height * 4)
    local horizontalBorder = br.matrix(width * 2, sizeCellBorder.y * 4)

    for i = 1, sizeCellBorder.x * 2 do
        br.line(verticalBorder, i, 1, i, height * 4)
    end

    for i = 1, sizeCellBorder.y * 4 do
        br.line(horizontalBorder, 1, i, width * 2, i)
    end

    setForegroundColor(normalBorderColor)
    --topBorder
    br.render(horizontalBorder, x, y)
    --bottomBorder
    br.render(horizontalBorder, x, y + sizeCellBorder.y + sizeCell.y)
    --leftBorder
    br.render(verticalBorder, x, y)
    --rightBorder
    br.render(verticalBorder, x + sizeCellBorder.x + sizeCell.x, y)

    return {x1 = x + sizeCellBorder.x, 
            y1 = y + sizeCellBorder.y, 
            x2 = x + width - sizeCellBorder.x, 
            y2 = y + height - sizeCellBorder.y,
            func = setActiveCell,
            params = {numberRow, numberColumn}}
end

local function drawSquare(x, y, numberRow, numberColumn)
    local sizeSquare = 3
    local square = {}

    local currentX, currentY = x, y
    for i = 1, sizeSquare do
        table.insert(square, {})
        for j = 1, sizeSquare do
            table.insert(square[i],drawCell(currentX, currentY, numberRow * sizeSquare - sizeSquare + i, numberColumn * sizeSquare - sizeSquare + j))

            currentX = currentX + sizeCell.x + sizeCellBorder.x
        end
        currentY = currentY + sizeCell.y + sizeCellBorder.y
        currentX = x
    end

    return square
end

--Отрисовка сетки
local function drawGrid(x, y)
    local sizeGrid = 3
    local grid = {}

    local width = 3 * (sizeCell.x + sizeCellBorder.x) + sizeCellBorder.x
    local height = 3 * (sizeCell.y + sizeCellBorder.y) + sizeCellBorder.y

    local verticalBorder = br.matrix(sizeSquareBorder.x * 2, height * 4)
    local horizontalBorder = br.matrix(width * 2, sizeSquareBorder.y * 4)

    for i = 1, sizeSquareBorder.x * 2 do
        br.line(verticalBorder, i, 1, i, height * 4)
    end

    for i = 1, sizeSquareBorder.y * 4 do
        br.line(horizontalBorder, 1, i, width * 2, i)
    end

    local currentX, currentY = x, y
    for i = 1, sizeGrid do
        table.insert(grid, {})
        for j = 1, sizeGrid do
            table.insert(grid[i], drawSquare(currentX, currentY, i, j))
            currentX = currentX + 3 * (sizeCell.x + sizeCellBorder.x) + sizeCellBorder.x
        end
        
        currentY = currentY + 3 * (sizeCell.y + sizeCellBorder.y) + sizeCellBorder.y
        currentX = x
    end

    currentX, currentY = x, y

    for i = 1, sizeGrid do
        for j = 1, sizeGrid do
            if j < sizeGrid then
                setForegroundColor(boldBorderColor)
                br.render(verticalBorder, currentX + width - sizeCellBorder.x, currentY)
            end

            if i < sizeGrid then
                setForegroundColor(boldBorderColor)
                br.render(horizontalBorder,currentX , currentY + height - sizeCellBorder.y)
            end

            currentX = currentX + 3 * (sizeCell.x + sizeCellBorder.x) + sizeCellBorder.x
        end
        
        currentY = currentY + 3 * (sizeCell.y + sizeCellBorder.y) + sizeCellBorder.y
        currentX = x
    end

    return grid
end

local function getCellsMatrix(grid)
    local tmpMatrix = {}
    for i = 1, 9 do
        table.insert(tmpMatrix, {})
    end

    for i = 1, #grid do
        for j = 1, #grid[i] do
            local square = grid[i][j]

            for k = 1, #square do
                for v = 1, #square[k] do
                    local cell = square[k][v]
                    table.insert(tmpMatrix[cell.params[1]],cell.params[2], cell)
                end
            end
        end
    end

    return tmpMatrix
end
local function addInTouch(tableIn)
    table.insert(touchCoordsTable, tableIn)
end

local function addInTouchTable(tableIn)
    for i = 1, #tableIn do
        table.insert(touchCoordsTable, tableIn[i])
    end
end

local function addCellsEvent(cells)
    for i = 1, #cells do
        addInTouchTable(cells[i])
    end
end

local function drawBorderKey(key)
    local x, y = key.x1, key.y1
    local borderSizeX, borderSizeY = key.borderSize.x, key.borderSize.y
    local border = br.matrix(key.size.width * 2, key.size.height * 4)

    if key.isActive then
        setForegroundColor(key.colorActiveForeground)
    else
        setForegroundColor(key.colorForeground)
    end

    for i = 1, borderSizeY * 4 do
        --Top
        br.line(border, 1, i, key.size.width * 2, i)

        --Bottom
        br.line(border, 1, key.size.height * 4 - i + 1, key.size.width * 2, key.size.height * 4 - i + 1)

        br.render(border, x, y)
    end

    for i = 1, borderSizeX * 2 do
         --Left
         br.line(border, i, 1, i, key.size.height * 4)

         --Right
         br.line(border, key.size.width * 2 - i + 1, 1, key.size.width * 2 - i + 1, key.size.height * 4)
         
         br.render(border, x, y)
    end
end

local function drawBackgroundKey(key)
    local x, y, borderSizeX, borderSizeY = key.x1, key.y1, key.borderSize.x, key.borderSize.y

    if key.isActive then
        --setBackgoundColor(key.colorActiveBackground)
        setBackgoundColor(key.colorBackground)
    else
        setBackgoundColor(key.colorBackground)
    end
    
    gpu.fill(x + borderSizeX, y + borderSizeY, key.size.width - borderSizeX * 2, key.size.height - borderSizeY * 2, emptyChar)
end

local function drawContentKey(key)
    local x, y, borderSizeX, borderSizeY = key.x1, key.y1, key.borderSize.x, key.borderSize.y

    if key.isActive then
        setForegroundColor(key.colorActiveForeground)
    else
        setForegroundColor(key.colorForeground)
    end

    if key.value ~= "0" then
        br.render(font[tonumber(key.value)], x + math.ceil((key.size.width - borderSizeX * 2) / 2) - 1, y + math.ceil((key.size.height - borderSizeY * 2) / 2) - borderSizeY)
    end
end

local function drawKey(key)
    drawBorderKey(key)
    drawBackgroundKey(key)
    drawContentKey(key)
end

local function isEditableCell()
    local isEditable = false
    local posCurrentCell = activeCell.params
    local numberRow, numberColumn = posCurrentCell[1], posCurrentCell[2]

    if generatedNeFullGrid[numberRow][numberColumn] == emptyChar then
        isEditable = true
    end

    return isEditable
end

--Та ну на..
local function isCorrectAnswer(key)
    local isCorrect = false
    local posCurrentCell = activeCell.params
    local numberRow, numberColumn = posCurrentCell[1], posCurrentCell[2]

    if generatedFullGrid[numberRow][numberColumn] == key.value then
        isCorrect = true
    end

    return isCorrect
end

local function checkCorrect()
    local isCorrect = true

    for i = 1, #generatedFullGrid do
        if isCorrect == false then
            break
        end

        for j = 1, #generatedFullGrid[i] do
            if generatedFullGrid[i][j] ~= userGrid[i][j] then
                isCorrect = false
                break
            end
        end
    end

    return isCorrect
end

local function cleanTable()
    for i = 1, #touchCoordsTable do
        touchCoordsTable[i] = nil
    end
end

local function deleteTouch(touchName)
    for i = 1, #touchCoordsTable do
        local item = touchCoordsTable[i]

        if item.name == touchName then
            touchCoordsTable[i] = nil
            break
        end
    end
end

local function win()
    setBackgoundColor(0x000)
    clearScreen()

    setForegroundColor(0xffffff)
    gpu.set(62, 20, "Судоку решена. Хотите начать заново?")

    

    setBackgoundColor(0x2F4F4F)
    local x, y = 75, 23
    local textBtn = "  Начать  "
    gpu.set(x, y, textBtn)

    local touchTable = {
        x1 = x,
        y1 = y,
        x2 = x + #textBtn,
        y2 = y,
        func = start,
        params = {},
        name = "newGameBtn"
    }

    cleanTable()
    addInTouch(touchTable)

end

--Установка активной кнопки
local function setActiveKey(key)
    if activeKey ~= nil then
        activeKey.isActive = false
        drawKey(activeKey)
    end
    if activeCell ~= nil then
        if isEditableCell() then
            local posCurrentCell = activeCell.params
            local numberRow, numberColumn = posCurrentCell[1], posCurrentCell[2]
            activeCell.prevValue = userGrid[numberRow][numberColumn]
            
            if key.value == "0" then
                userGrid[numberRow][numberColumn] = emptyChar
            else
                userGrid[numberRow][numberColumn] = tonumber(key.value)
            end
            
    
            setActiveCell(posCurrentCell)
        end
    end

    if checkCorrect() then
        win()
    end
    

    key.isActive = true

    activeKey = key
    --drawKey(key)
end

--Отрисовка sideBar
local function drawSideBar(x, y, sideBar)
    local keysTable = {}
    local currentX, currentY = x, y
    for i = 1, #sideBar do
        local key = sideBar[i]
        local tmpkey
        key.size.width = key.size.widthDefault + key.borderSize.x * 2
        key.size.height = key.size.heightDefault + key.borderSize.y * 2
        key.x1 = currentX
        key.y1 = currentY
        key.x2 = currentX + key.size.width
        key.y2 = currentY + key.size.height
        
        drawKey(key)

        tmpkey = {
            x1 = key.x1,
            x2 = key.x2,
            y1 = key.y1,
            y2 = key.y2,
            func = setActiveKey,
            params = key
        }

        table.insert(keysTable, tmpkey)

        currentY = currentY + key.size.height
    end

    return keysTable
end

local function startGame()
    deleteTouch("newGameBtn")
    clearScreen()
    local grid = drawGrid(4,2)
    
    local cells = getCellsMatrix(grid)
    cellsMatrix = cells

    addCellsEvent(cellsMatrix)

    generatedFullGrid, generatedNeFullGrid = generateSudoku()

    userGrid = {}
    for i = 1, #generatedNeFullGrid do
        table.insert(userGrid, {})
        for j = 1, #generatedNeFullGrid[i] do
            userGrid[i][j] = generatedNeFullGrid[i][j]
        end
    end

    for i = 1, #cellsMatrix do
        for j = 1, #cellsMatrix[i] do
            local cell = cellsMatrix[i][j]
            
            drawContentCell(cell)
        end
    end


    local sideBarElements = drawSideBar(110, 2, sideBar)
    addInTouchTable(sideBarElements)
    
    sideBarElements = drawSideBar(130, 2, sideBarSecond)
    addInTouchTable(sideBarElements)
    
end


--Обработка нажатий
local function performTouch()
    while isPerfrom do 
        local _, _, x, y, _, nick = event.pull("touch", _, _, _, _, _)
        
        local currentArea
        for i = 1, #touchCoordsTable do
            currentArea = touchCoordsTable[i]

            if currentArea ~= nil then
                if (x >= currentArea.x1 and x <= currentArea.x2) and
                    (y >= currentArea.y1 and y <= currentArea.y2) then
                        currentArea.func(currentArea.params)
                end
            else

            end
        end
    end
end


function main()
    startGame()
    start = startGame
    --win()
    
    performTouch()

end

main()

