include("shared.lua")
local imgui = include("libs/imgui.lua")
local TRANSFER_NONE = nil
local TRANSFER_WITHDRAW = 0
local TRANSFER_DEPOSIT = 1
local FRONT_PAGE = 0
local MAIN_PAGE = 1
local ACCOUNT_PAGE = 2
local TRANSFER_PAGE = 3
local HISTORY_PAGE = 4
local ATM_UI_WIDTH = 400
local ATM_UI_HEIGHT = 230
local ATM_UI_PADDING_Y = 15
local ATM_UI_PADDING_X = 50
local ATM_LINE_PADDING = 5
local ATM_BUTTON_PADDING = 5
local ATM_ARROW_BUTTON_WIDTH = 35
local ATM_ARROW_BUTTON_HEIGHT = 35
local ATM_MENU_BUTTON_HEIGHT = 35
local ATM_TRANSFER_BUTTON_HEIGHT = 35

local WHITE = Color(255, 255, 255, 255)
local TRANSPARENT_WHITE = Color(255, 255, 255, 0)
local GREEN = Color(100, 200, 125, 255)
local GREEN_DARK = Color(50, 150, 75, 255)
local RED = Color(200,100,100)
local DARK_GREY = Color(25, 25, 25, 255)
local ATM_BACKDROP_COLOR = Color(50, 50, 50, 255)
local TRANSPARENT_ATM_BACKDROP_COLOR = Color(50, 50, 50, 0)
local ATM_GREY_BUTTON_COLOR = Color(35, 35, 35, 255)
local ATM_GREY_BUTTON_COLOR_DARK = Color(30, 30, 30, 255)

local MainFontData = {font = "Arial",size = 36,weight = 1000,}
local SmallMainFontData = {font = "Arial",size = 18,weight = 1500,}
surface.CreateFont("OscarMoney:MainFont", MainFontData)
surface.CreateFont("OscarMoney:MainFontSmall", SmallMainFontData)

local FONT_HEIGHT = draw.GetFontHeight("OscarMoney:MainFont")
local FONT_HEIGHT_SMALL = draw.GetFontHeight("OscarMoney:MainFontSmall")
local CLICK_SOUND = Sound("ui/bubble_click.wav")
local DISTANCE_LIMIT = 100
local timeDifference = 0

local timeFormats = {
    [1] = { suffix = "s", denom = 1 },
    [2] = { suffix = "m", denom = 60 },
    [3] = { suffix = "h", denom = 3600 },
    [4] = { suffix = "d", denom = 86400 },
    [5] = { suffix = "m", denom = 2592000 },
    [6] = { suffix = "y", denom = 31536000 },
}

function CubicEase(n)
    return n^2 * (3 - 2*n)
end

function FormatTime(timestamp)
    local timePassed = os.difftime( os.time(), timestamp - timeDifference )
    local result = tostring(timePassed) .. "s"
    for _, format in ipairs(timeFormats) do
        local units = math.floor(timePassed / format.denom)
        if units == 0 then break end
        result = tostring(units) .. format.suffix
    end
    return result .. " ago"
end

function ENT:OpenTransferSelectionMenu()
    local entity = self
    local popupWidth, popupHeight = 225, 55

    local frame = vgui.Create( "DFrame" )
    frame:SetPos( ScrW() / 2 - popupWidth / 2, ScrH() / 2 - popupHeight / 2 ) 
    frame:SetSize( popupWidth, popupHeight ) 
    frame:SetTitle( "Select Transfer Target" ) 
    frame:SetVisible( true ) 
    frame:SetDraggable( false ) 
    frame:ShowCloseButton( true ) 
    frame:MakePopup()

    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:Dock(TOP)
    textEntry:SetPlaceholderText("SteamID (x64)")
    textEntry:SetNumeric(true)
    textEntry:RequestFocus()

    function textEntry:OnEnter( value )
        entity.transferTarget = value
        frame:Close()
    end
end

function ENT:OpenTransferConfirmMenu()
    local entity = self

    local popupWidth, popupHeight = 400, 100

    local frame = vgui.Create( "DFrame" )
    frame:SetPos( ScrW() / 2 - popupWidth / 2, ScrH() / 2 - popupHeight / 2 ) 
    frame:SetSize( popupWidth, popupHeight ) 
    frame:SetTitle( "Transfer Confirmation" ) 
    frame:SetVisible( true ) 
    frame:SetDraggable( false ) 
    frame:ShowCloseButton( true ) 
    frame:MakePopup()

    local label = vgui.Create( "DLabel", frame )
    label:Dock( TOP )
    label:SetSize( 400, 45 )
    label:SetFont( "OscarMoney:MainFontSmall" )
    label:SetText( string.format( "Are you sure you want to transfer $%d\nTo account: %d?", self.increment, self.transferTarget ) )
    label:SetTextColor( DARK_GREY )

    local confirmButton = vgui.Create( "DButton", frame )
    confirmButton:Dock(LEFT)
    confirmButton:SetText( "Confirm" )

    local cancelButton = vgui.Create( "DButton", frame )
    cancelButton:Dock(LEFT)
    cancelButton:SetText( "Cancel" )

    function cancelButton:DoClick()
        frame:Close()
    end

    function confirmButton:DoClick()
        net.Start("OscarMoney:PlayerTransferMoney")
            net.WriteUInt64(entity.transferTarget)
            net.WriteUInt(entity.increment,32)
        net.SendToServer()
        frame:Close()
    end
end

function ENT:Initialize()
    self.increment = 10
    self.page = FRONT_PAGE
    self.transferTarget = "" -- steamid of the player that we need to send money to
    self.active = false -- has the atm been interacted with yet?

    self.buttons = {}

    self.startupAnimation = {
        active = false,
        duration = 1,
        startTime = 0,
    }

    self.pageFadeAnimation = {
        active = false,
        duration = 1,
        startTime = 0,
        fadeTo = FRONT_PAGE,
    }

    self.historyData = {}
    self.historyPage = 1
end

function ENT:AddButton(x, y, w, h, callback)
    if self.startupAnimation.active then return end
    if self.pageFadeAnimation.active then return end
    table.insert(self.buttons, {x = x, y = y, w = w, h = h, callback = callback})
end

function ENT:IncrementKey(amount, key, lower, upper)
    local increment = input.IsShiftDown() and 10 * amount or amount
    self[key] = math.Clamp(self[key] + increment, lower, upper)
end

function ENT:DoTransfer(transferType)
    net.Start("OscarMoney:TransferMoney")
        net.WriteUInt(transferType,1)
        net.WriteUInt(self.increment,32)
    net.SendToServer()
end

function ENT:FadeToPage(page)
    self.pageFadeAnimation.active = true 
    self.pageFadeAnimation.startTime = CurTime()
    self.pageFadeAnimation.fadeTo = page
end

function ENT:DrawIncrementElement(x, y, width, height, textFormat, largeFont, key, lower, upper, callback)
    local isHoveringLeftArrow = imgui.IsHovering(x, y, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
    local isHoveringRightArrow = imgui.IsHovering(x + width - ATM_ARROW_BUTTON_WIDTH, y, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

    -- drawing left and right buttons for adjusting money to withdraw or deposit
    surface.SetDrawColor(isHoveringLeftArrow and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(x, y, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

    surface.SetDrawColor(isHoveringRightArrow and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(x + width - ATM_ARROW_BUTTON_WIDTH, y, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

    -- drawing arrows in the buttons above
    draw.DrawText("<", "OscarMoney:MainFont", x + ATM_ARROW_BUTTON_WIDTH / 2, y + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)
    draw.DrawText(">", "OscarMoney:MainFont", x + width - ATM_ARROW_BUTTON_WIDTH + ATM_ARROW_BUTTON_WIDTH / 2, y + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(DARK_GREY)
    surface.DrawRect(x + ATM_ARROW_BUTTON_WIDTH, y, width - ATM_ARROW_BUTTON_WIDTH * 2, ATM_ARROW_BUTTON_HEIGHT)

    draw.DrawText(string.format(textFormat,self[key]),largeFont and "OscarMoney:MainFont" or "OscarMoney:MainFontSmall", x + width / 2, y + (ATM_ARROW_BUTTON_HEIGHT - (largeFont and FONT_HEIGHT or FONT_HEIGHT_SMALL)) / 2, WHITE, TEXT_ALIGN_CENTER)

    self:AddButton(x, y, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT, function()
        self:IncrementKey(-1, key, lower, upper)
        if callback then callback() end
    end)

    self:AddButton(x + width - ATM_ARROW_BUTTON_WIDTH, y, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT, function()
        self:IncrementKey(1, key, lower, upper)
        if callback then callback() end
    end)
end

function ENT:DrawFrontPage()
    local client = LocalPlayer()

    local labelPositionY = ATM_UI_HEIGHT / 2 - FONT_HEIGHT
    local subtextColor = WHITE

    if self.startupAnimation.active then
        local timePassed = CurTime() - self.startupAnimation.startTime
        local timeFraction = math.min(timePassed / self.startupAnimation.duration, 1)
        local timeEased = CubicEase(timeFraction)

        subtextColor = WHITE:Lerp(TRANSPARENT_WHITE, timeEased)
        labelPositionY = math.max(labelPositionY - (labelPositionY - ATM_UI_PADDING_Y) * timeEased, ATM_UI_PADDING_Y)

        local animationEnded = timeFraction == 1
        if animationEnded then
            self.startupAnimation.active = false
            self.active = true

            self:FadeToPage( MAIN_PAGE )
        end
    end

    if not self.active then
        draw.DrawText("ATM - MoneyBank™", "OscarMoney:MainFont", ATM_UI_WIDTH / 2, labelPositionY, WHITE, TEXT_ALIGN_CENTER)
        draw.DrawText("Touch to Begin", "OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, labelPositionY + FONT_HEIGHT, subtextColor, TEXT_ALIGN_CENTER)

        self:AddButton(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT, function()
            self.startupAnimation.active = true 
            self.startupAnimation.startTime = CurTime()
        end)
    end
end

function ENT:DrawMainPage()
    local client = LocalPlayer()

    local accountPageButtonX = ATM_UI_PADDING_X
    local transferPageButtonX = ATM_UI_PADDING_X
    local historyPageButtonX = ATM_UI_PADDING_X

    local accountPageButtonY = ATM_UI_PADDING_Y + FONT_HEIGHT + ATM_LINE_PADDING
    local transferPageButtonY = accountPageButtonY + ATM_MENU_BUTTON_HEIGHT + ATM_LINE_PADDING
    local historyPageButtonY = transferPageButtonY + ATM_MENU_BUTTON_HEIGHT + ATM_LINE_PADDING

    local isHoveringAccountButton = imgui.IsHovering(accountPageButtonX, accountPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
    local isHoveringTransferButton = imgui.IsHovering(transferPageButtonX, transferPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
    local isHoveringHistoryButton = imgui.IsHovering(historyPageButtonX, historyPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)

    draw.DrawText("ATM - MoneyBank™", "OscarMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)

    -- draw the account page button here
    surface.SetDrawColor(isHoveringAccountButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(accountPageButtonX, accountPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
    draw.DrawText("Account", "OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, accountPageButtonY + (ATM_MENU_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(isHoveringTransferButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(transferPageButtonX, transferPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
    draw.DrawText("Transfer", "OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, transferPageButtonY + (ATM_MENU_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(isHoveringHistoryButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(historyPageButtonX, historyPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
    draw.DrawText("History", "OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, historyPageButtonY + (ATM_MENU_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    self:AddButton(accountPageButtonX, accountPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT, function()
        self:FadeToPage( ACCOUNT_PAGE )
    end)

    self:AddButton(transferPageButtonX, transferPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT, function()
        self:FadeToPage( TRANSFER_PAGE )
    end)

    self:AddButton(historyPageButtonX, historyPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT, function()
        self:FadeToPage( HISTORY_PAGE )
        self:UpdateHistory() -- requests updated transfer history data
    end)
end

function ENT:DrawAccountPage()
    local client = LocalPlayer()

    local arrowPositionX = ATM_UI_PADDING_X
    local arrowPositionY = ATM_UI_PADDING_Y + FONT_HEIGHT * 2 + ATM_LINE_PADDING * 5

    local depositButtonPositionX = ATM_UI_PADDING_X
    local withdrawButtonPositionX = ATM_UI_WIDTH / 2 + ATM_BUTTON_PADDING / 2
    local transferButtonPositionY = arrowPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING
    local transferButtonWidth = ATM_UI_WIDTH / 2 - ATM_UI_PADDING_X - ATM_BUTTON_PADDING / 2

    local isHoveringDeposit = imgui.IsHovering(depositButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)
    local isHoveringWithdraw = imgui.IsHovering(withdrawButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

    // ATM title and current balance (title is draw here as well because of the fade out animation when stepping away from the ATM requiring it)
    draw.DrawText("ATM - MoneyBank™", "OscarMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)
    draw.DrawText("Current Balance:", "OscarMoney:MainFontSmall", ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT + FONT_HEIGHT_SMALL / 2, WHITE, TEXT_ALIGN_LEFT)
    draw.DrawText(string.format("$%.2f",client:GetNWInt("bankBalance")), "OscarMoney:MainFont",ATM_UI_WIDTH - ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT, GREEN,TEXT_ALIGN_RIGHT)

    // This draws the UI element for selecting how much to deposit/withdraw
    self:DrawIncrementElement( arrowPositionX, arrowPositionY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_ARROW_BUTTON_HEIGHT, "$%.2f", true, "increment", 1, 2^32 )

    // This draws the deposit and withdraw buttons
    surface.SetDrawColor(isHoveringDeposit and GREEN_DARK or GREEN)
    surface.DrawRect(depositButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

    surface.SetDrawColor(isHoveringWithdraw and GREEN_DARK or GREEN)
    surface.DrawRect(withdrawButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

    // This draws the text for the deposit and withdraw buttons
    draw.DrawText("Deposit","OscarMoney:MainFontSmall",depositButtonPositionX + transferButtonWidth / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)
    draw.DrawText("Withdraw","OscarMoney:MainFontSmall",withdrawButtonPositionX + transferButtonWidth / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    self:AddButton(depositButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT, function()
        self:DoTransfer(TRANSFER_DEPOSIT)
    end)

    self:AddButton(withdrawButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT, function()
        self:DoTransfer(TRANSFER_WITHDRAW)
    end)
end

function ENT:DrawTransferPage()
    local client = LocalPlayer()

    local arrowPositionX = ATM_UI_PADDING_X
    local arrowPositionY = ATM_UI_PADDING_Y + FONT_HEIGHT * 2 + ATM_LINE_PADDING

    local targetEntryPositionX = ATM_UI_PADDING_X
    local targetEntryPositionY = arrowPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING

    local targetEditButtonPositionX = ATM_UI_WIDTH - ATM_UI_PADDING_X - ATM_ARROW_BUTTON_WIDTH

    local transferButtonPositionX = ATM_UI_PADDING_X
    local transferButtonPositionY = targetEntryPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING
    local transferButtonWidth = ATM_UI_WIDTH - ATM_UI_PADDING_X * 2

    local isHoveringTargetEdit = imgui.IsHovering(targetEditButtonPositionX, targetEntryPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
    local isHoveringTransfer = imgui.IsHovering(transferButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

    draw.DrawText("ATM - MoneyBank™", "OscarMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)
    draw.DrawText("Current Balance:", "OscarMoney:MainFontSmall", ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT + FONT_HEIGHT_SMALL / 2, WHITE, TEXT_ALIGN_LEFT)
    draw.DrawText(string.format("$%.2f",client:GetNWInt("bankBalance")), "OscarMoney:MainFont",ATM_UI_WIDTH - ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT, GREEN,TEXT_ALIGN_RIGHT)

    self:DrawIncrementElement( arrowPositionX, arrowPositionY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_ARROW_BUTTON_HEIGHT, "$%.2f", true, "increment", 1, 2^32 )

    surface.SetDrawColor(DARK_GREY)
    surface.DrawRect(targetEntryPositionX, targetEntryPositionY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2 - ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

    draw.DrawText(self.transferTarget, "OscarMoney:MainFontSmall", targetEntryPositionX + (ATM_UI_WIDTH - ATM_UI_PADDING_X * 2 - ATM_ARROW_BUTTON_WIDTH) / 2, targetEntryPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(isHoveringTargetEdit and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(targetEditButtonPositionX, targetEntryPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

    draw.DrawText("...","OscarMoney:MainFontSmall", targetEditButtonPositionX + ATM_ARROW_BUTTON_WIDTH / 2, targetEntryPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(isHoveringTransfer and GREEN_DARK or GREEN)
    surface.DrawRect(transferButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

    draw.DrawText("Transfer","OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    self:AddButton(targetEditButtonPositionX, targetEntryPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT, function()
        self:OpenTransferSelectionMenu()
    end)

    self:AddButton(transferButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT, function()
        if self.transferTarget == "" then
            -- we don't use the darkrp method here
            notification.AddLegacy( "No Transfer recipient selected!", NOTIFY_ERROR, 5 )
            return
        end

        self:OpenTransferConfirmMenu()
    end)
end

function ENT:DrawHistoryPage()
    local client = LocalPlayer()

    -- title is drawn here aswell because of the fade out animation when stepping away from the ATM requiring it
    draw.DrawText("ATM - MoneyBank™", "OscarMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)

    draw.DrawText("Amount      -      Account      -      Time", "OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y + FONT_HEIGHT, WHITE, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(WHITE)
    surface.DrawRect(ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT + FONT_HEIGHT_SMALL, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, 1)

    for row, data in pairs(self.historyData) do
        local isNegative = tonumber(data.amount) < 0
        local amount = (isNegative and "-" or "+") .. string.format("$%d",math.abs(data.amount))
        draw.DrawText(amount, "OscarMoney:MainFontSmall", ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT + (FONT_HEIGHT_SMALL + ATM_LINE_PADDING) * row, isNegative and RED or GREEN, TEXT_ALIGN_LEFT)
        draw.DrawText(data.toFrom, "OscarMoney:MainFontSmall", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y + FONT_HEIGHT + (FONT_HEIGHT_SMALL + ATM_LINE_PADDING) * row, WHITE, TEXT_ALIGN_CENTER)
        draw.DrawText(FormatTime(data.timestamp), "OscarMoney:MainFontSmall", ATM_UI_WIDTH - ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT + (FONT_HEIGHT_SMALL + ATM_LINE_PADDING) * row, WHITE, TEXT_ALIGN_RIGHT)
    end

    local arrowPositionX = ATM_UI_PADDING_X
    local arrowPositionY = ATM_UI_PADDING_Y + FONT_HEIGHT + (FONT_HEIGHT_SMALL + ATM_LINE_PADDING) * (#self.historyData + 1)

    self:DrawIncrementElement( arrowPositionX, arrowPositionY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_ARROW_BUTTON_HEIGHT, "Page %d", false, "historyPage", 1, 2^32, function()
        self:UpdateHistory()
    end)
end

function ENT:DrawBackArrow()
    local backButtonX = 5
    local backButtonY = 5
    local backButtonWidth = 25
    local backButtonHeight = 25

    local isHoveringBackButton = imgui.IsHovering(backButtonX, backButtonY, backButtonWidth, backButtonHeight)

    surface.SetDrawColor(isHoveringBackButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
    surface.DrawRect(backButtonX, backButtonY, backButtonWidth, backButtonHeight)
    draw.DrawText("<", "OscarMoney:MainFontSmall", backButtonX + backButtonWidth / 2, backButtonY + (backButtonHeight - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

    self:AddButton(backButtonX, backButtonY, backButtonWidth, backButtonHeight, function()
        self:FadeToPage( MAIN_PAGE )
    end)
end

function ENT:DrawFadeAnimation()
    local timePassed = CurTime() - self.pageFadeAnimation.startTime
    local timeFraction = math.min(timePassed / self.pageFadeAnimation.duration, 1)

    local fadeColor = nil
    if timeFraction <= 0.5 then -- fading out
        local timeEased = CubicEase(timeFraction*2)
        fadeColor = TRANSPARENT_ATM_BACKDROP_COLOR:Lerp(ATM_BACKDROP_COLOR, timeEased)
    else -- fading in
        self.page = self.pageFadeAnimation.fadeTo

        local timeEased = CubicEase((timeFraction-0.5)*2)
        fadeColor = ATM_BACKDROP_COLOR:Lerp(TRANSPARENT_ATM_BACKDROP_COLOR, timeEased)

        local animationEnded = timeFraction == 1
        if animationEnded then
            self.pageFadeAnimation.active = false
        end
    end
    
    surface.SetDrawColor(fadeColor)
    surface.DrawRect(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT)
end

function ENT:DrawTranslucent()
    local client = LocalPlayer()
    local distance = client:GetPos():Distance(self:GetPos())

    if imgui.Entity3D2D(self, Vector(1, -20.15, 23.75), Angle(0, 90, 85), 0.1) then
        self.buttons = {}

        -- backdrop
        surface.SetDrawColor(ATM_BACKDROP_COLOR)
        surface.DrawRect(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT)
        if self.page == FRONT_PAGE then
            self:DrawFrontPage()
        elseif self.page == MAIN_PAGE then
            self:DrawMainPage()
        elseif self.page == ACCOUNT_PAGE then
            self:DrawAccountPage()
        elseif self.page == TRANSFER_PAGE then
            self:DrawTransferPage()
        elseif self.page == HISTORY_PAGE then
            self:DrawHistoryPage()
        end

        -- draw back arrow on selected pages
        if self.page == ACCOUNT_PAGE or self.page == TRANSFER_PAGE or self.page == HISTORY_PAGE then
            self:DrawBackArrow()
        end

        if self.pageFadeAnimation.active then
            self:DrawFadeAnimation()
        end

        -- draw the title here so that the fade animation doesn't affect it during the startup animation
        if self.active then
            draw.DrawText("ATM - MoneyBank™", "OscarMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)
        end

        if imgui.IsPressed() and imgui.IsHovering(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT) and distance <= DISTANCE_LIMIT then
            for _, button in pairs(self.buttons) do
                if imgui.IsHovering(button.x, button.y, button.w, button.h) then
                    self:EmitSound(CLICK_SOUND)
                    button.callback()
                end
            end
        end

        if distance > DISTANCE_LIMIT * 2 then -- moved away
            if not self.pageFadeAnimation.active and self.active then
                self:FadeToPage(FRONT_PAGE)
                self.active = false
            end
        end
        imgui.End3D2D()
    end
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:UpdateHistory()
    net.Start("OscarMoney:RequestTransfers")
        net.WriteEntity(self)
        net.WriteUInt(self.historyPage - 1, 32)
        net.WriteInt(os.time(), 32)
    net.SendToServer()
end

net.Receive("OscarMoney:RequestTransfers", function(length)
    local entity = net.ReadEntity()
    if not entity then return end
    entity.historyData = net.ReadTable(true)
    timeDifference = net.ReadInt(32)
end)
