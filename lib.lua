--[[
    BlvckUI
    https://github.com/Kefa4ka/BlvckUI

    local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kefa4ka/BlvckUI/refs/heads/main/lib.lua"))()

    -- Optional but recommended: real Lucide icons (https://lucide.dev) instead of text glyphs.
    -- Uses latte-soft/lucide-roblox (MIT), a free/open icon set wrapped for Roblox.
    UI:AutoLoadLucide() -- pcall'd internally; falls back to text glyphs if it fails/no internet

    local Window = UI:CreateWindow({
        Title = "Kinetix", Badge = "Beta",
        User = { Name = "AhekiUA", Role = "Owner" },
    })

    local World = Window:AddCategory({ Name = "World", Icon = "globe" })
    local Module = World:AddModule({
        Title = "Chunk Animator",
        Description = "Makes newly loaded chunks smoothly pop up or slide.",
        Default = false,
        DetailTitle = "Chunk Animation",
    })
    Module:AddCheckbox({ Text = "Invert Direction", Callback = function(v) end })
    Module:AddSlider({ Text = "Animation Speed", Min = 100, Max = 2000, Default = 500, Suffix = "ms" })
    Module:AddSelectList({ Text = "Animation Mode", Items = { "Slide In", "Pop Up", "Fade In" }, Default = "Fade In" })
    Module:AddCheckList({ Text = "World", Items = { "Overworld", "Nether", "End" }, Default = { "Overworld", "Nether" } })
    Module:AddColorPicker({ Text = "Grid Color", Default = Color3.fromHex("84E395") })

    UI:Notify({ Title = "Saved", Text = "Settings updated", Type = "Success" })
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

--============================================================
-- ТЕМА
--============================================================

local Theme = {
    Background   = Color3.fromRGB(13, 14, 17),
    Surface      = Color3.fromRGB(19, 20, 24),
    SurfaceLight = Color3.fromRGB(27, 28, 33),
    SurfaceHover = Color3.fromRGB(34, 35, 41),
    Stroke       = Color3.fromRGB(38, 39, 46),
    Accent       = Color3.fromRGB(132, 227, 149), -- #84E395-ish grass green
    Text         = Color3.fromRGB(238, 238, 242),
    SubText      = Color3.fromRGB(138, 139, 148),
    Success      = Color3.fromRGB(102, 214, 150),
    Error        = Color3.fromRGB(235, 100, 110),
    Warning      = Color3.fromRGB(235, 140, 90),
    Info         = Color3.fromRGB(120, 170, 240),
    Font         = Enum.Font.GothamMedium,
    FontBold     = Enum.Font.GothamBold,
    Corner       = UDim.new(0, 8),
}

local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_OPEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--============================================================
-- УТИЛІТИ
--============================================================

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function corner(radius)
    return new("UICorner", { CornerRadius = radius or Theme.Corner })
end

local function stroke(color, thickness)
    return new("UIStroke", { Color = color or Theme.Stroke, Thickness = thickness or 1 })
end

local function padding(px, extra)
    extra = extra or {}
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, extra.Left or px),
        PaddingRight = UDim.new(0, extra.Right or px),
        PaddingTop = UDim.new(0, extra.Top or px),
        PaddingBottom = UDim.new(0, extra.Bottom or px),
    })
end

local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- cleanup-хелпер: збирає конекти й інстанси, звільняє все одним викликом
local function newJanitor()
    local self = { _items = {} }

    function self:add(item)
        table.insert(self._items, item)
        return item
    end

    function self:cleanup()
        for _, item in ipairs(self._items) do
            if typeof(item) == "RBXScriptConnection" then
                item:Disconnect()
            elseif typeof(item) == "Instance" then
                item:Destroy()
            end
        end
        table.clear(self._items)
    end

    return self
end

-- Icons from makeIcon() can be either an ImageLabel (Lucide) or a TextLabel
-- (text-glyph fallback) — this recolors whichever one it actually is.
local function setIconColor(icon, color)
    if icon:IsA("TextLabel") then
        icon.TextColor3 = color
    else
        icon.ImageColor3 = color
    end
end

local function clampToViewport(pos, absSize, viewportSize)
    local x = math.clamp(pos.X.Offset, 0, math.max(0, viewportSize.X - absSize.X))
    local y = math.clamp(pos.Y.Offset, 0, math.max(0, viewportSize.Y - absSize.Y))
    return UDim2.new(0, x, 0, y)
end

--============================================================
-- ІКОНКИ (Lucide, з текстовим фолбеком)
--============================================================
-- BlvckUI:AutoLoadLucide() підвантажує https://github.com/latte-soft/lucide-roblox
-- (MIT, реально безкоштовний набір іконок lucide.dev). Якщо це не вдалось (немає
-- інтернету/заблоковано), усі іконки тихо деградують до текстових гліфів нижче,
-- інтерфейс і далі повністю робочий.

local FALLBACK_GLYPHS = {
    ["settings"] = "⚙", ["globe"] = "◍", ["user"] = "☺", ["sparkles"] = "✦",
    ["palette"] = "◐", ["check"] = "✓", ["circle-check"] = "✓", ["circle-x"] = "✕",
    ["circle-alert"] = "!", ["chevron-down"] = "▾", ["x"] = "×", ["gamepad-2"] = "◫",
}

local lucideRef -- shared upvalue: the loaded Lucide module, if any (set via AutoLoadLucide/SetIconProvider)

local function makeIcon(name, size, color)
    size = size or 16
    color = color or Theme.Text

    if lucideRef then
        local ok, obj = pcall(lucideRef.ImageLabel, name, size, {
            ImageColor3 = color,
            BackgroundTransparency = 1,
        })
        if ok and obj then
            return obj
        end
    end

    return new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, size, 0, size),
        Text = FALLBACK_GLYPHS[name] or "•",
        Font = Theme.FontBold,
        TextSize = math.floor(size * 0.85),
        TextColor3 = color,
    })
end

--============================================================
-- КОРІНЬ БІБЛІОТЕКИ
--============================================================

local BlvckUI = {}
BlvckUI.Theme = Theme

BlvckUI.ScreenGui = new("ScreenGui", {
    Name = "BlvckUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    Parent = PlayerGui,
})

function BlvckUI:SetAccent(color3)
    Theme.Accent = color3
end

function BlvckUI:SetIconProvider(lucideModule)
    lucideRef = lucideModule
end

-- Пробує підвантажити latte-soft/lucide-roblox (MIT) як єдиний .luau бандл через
-- loadstring+HttpGet. Обгорнуто в pcall: якщо немає інтернету/HttpGet заблоковано/
-- лоадер недоступний — просто повертає nil і бібліотека далі working з текстовими
-- гліфами, нічого не ламається.
function BlvckUI:AutoLoadLucide()
    if lucideRef then
        return lucideRef
    end

    local url = "https://github.com/latte-soft/lucide-roblox/releases/download/0.1.3/lucide-roblox.luau"
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if ok and result then
        lucideRef = result
        return result
    end

    warn("[BlvckUI] Не вдалось підвантажити Lucide, використовую текстові гліфи: " .. tostring(result))
    return nil
end

--============================================================
-- НОТИФІКАЦІЇ (Toast)
--============================================================

local ToastHolder = new("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 300, 1, -32),
    Parent = BlvckUI.ScreenGui,
}, {
    new("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local TOAST_ICON = { Success = "circle-check", Error = "circle-x", Warning = "circle-alert", Info = "circle-alert" }

function BlvckUI:Notify(options)
    options = options or {}
    local kind = options.Type or "Info"
    local duration = options.Duration or 4
    local accentColor = Theme[kind] or Theme.Info

    local toast = new("Frame", {
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        BackgroundTransparency = 1,
        Parent = ToastHolder,
    }, { corner(UDim.new(0, 10)), stroke() })

    local inner = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = toast,
    }, { padding(12) })

    new("Frame", { BackgroundColor3 = accentColor, Size = UDim2.new(0, 3, 1, 0), Parent = toast },
        { corner(UDim.new(0, 2)) })

    local iconBadge = new("Frame", {
        BackgroundColor3 = accentColor, Size = UDim2.new(0, 26, 0, 26), Parent = inner,
    }, { corner(UDim.new(0, 6)) })
    local icon = makeIcon(TOAST_ICON[kind] or "circle-alert", 16, Color3.new(1, 1, 1))
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.Parent = iconBadge

    local textHolder = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 36, 0, 0),
        Size = UDim2.new(1, -36, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = inner,
    }, { new("UIListLayout", { Padding = UDim.new(0, 2) }) })

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Text = options.Title or "Notification", TextColor3 = Theme.Text,
        Font = Theme.FontBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = textHolder,
    })

    if options.Text and options.Text ~= "" then
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, Text = options.Text,
            TextColor3 = Theme.SubText, Font = Theme.Font, TextSize = 13,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            Parent = textHolder,
        })
    end

    local progressTrack = new("Frame", { BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 3), Parent = toast },
        { corner(UDim.new(1, 0)) })
    new("Frame", { BackgroundColor3 = accentColor, Size = UDim2.new(1, 0, 1, 0), Name = "Fill", Parent = progressTrack },
        { corner(UDim.new(1, 0)) })
    local progressFill = progressTrack.Fill

    toast.Position = UDim2.new(1, 60, 0, 0)
    tween(toast, EASE, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
    tween(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })

    task.delay(duration, function()
        if not toast.Parent then return end
        local out = tween(toast, EASE, { BackgroundTransparency = 1, Position = UDim2.new(1, 60, 0, 0) })
        out.Completed:Once(function() toast:Destroy() end)
    end)

    return toast
end

--============================================================
-- ВІКНО
--============================================================

local Window = {}
Window.__index = Window

function BlvckUI:CreateWindow(options)
    options = options or {}
    local size = options.Size or UDim2.new(0, 1040, 0, 620)
    local listWidth = 660

    local self = setmetatable({}, Window)
    self._categories = {}
    self._size = size
    self.ListWidth = listWidth
    self._janitor = newJanitor()

    self.Main = self._janitor:add(new("Frame", {
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(size.X.Scale, 0, size.Y.Scale, 0),
        Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        ClipsDescendants = true,
        Parent = BlvckUI.ScreenGui,
    }, { corner(UDim.new(0, 12)), stroke() }))

    tween(self.Main, EASE_OPEN, { Size = size })

    ------------------------------------------------ Header
    local Header = new("Frame", { BackgroundColor3 = Theme.Surface, Size = UDim2.new(1, 0, 0, 64), Parent = self.Main },
        { corner(UDim.new(0, 12)) })
    new("Frame", { -- маска нижніх кутів (тільки верх заокруглений)
        BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, 0, 1, -12),
        Size = UDim2.new(1, 0, 0, 12), BorderSizePixel = 0, Parent = Header,
    })

    local iconBox = new("Frame", {
        BackgroundColor3 = Theme.Accent, Position = UDim2.new(0, 16, 0.5, -18), Size = UDim2.new(0, 36, 0, 36),
        Parent = Header,
    }, { corner(UDim.new(0, 10)) })
    local headerIcon = makeIcon(options.Icon or "sparkles", 18, Color3.new(1, 1, 1))
    headerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    headerIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    headerIcon.Parent = iconBox

    local titleHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 64, 0, 10), Size = UDim2.new(0, 240, 0, 44), Parent = Header })
    self.TitleLabel = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = options.Title or "BlvckUI",
        Font = Theme.FontBold, TextSize = 16, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = titleHolder,
    })
    if options.Badge then
        new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 16),
            Text = "◆ " .. options.Badge, Font = Theme.Font, TextSize = 11, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = titleHolder,
        })
    end

    local user = options.User or {}
    local userHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(1, -190, 0, 10), Size = UDim2.new(0, 130, 0, 44), Parent = Header })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = user.Name or "Guest",
        Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = userHolder,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 16),
        Text = user.Role or "", Font = Theme.Font, TextSize = 11, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = userHolder,
    })

    local avatar = new("Frame", { BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(1, -46, 0.5, -18), Size = UDim2.new(0, 36, 0, 36), Parent = Header },
        { corner(UDim.new(1, 0)), stroke() })
    local avatarIcon = makeIcon("user", 16, Theme.SubText)
    avatarIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    avatarIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    avatarIcon.Parent = avatar

    ------------------------------------------------ Breadcrumbs
    local CrumbBar = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 0, 28), Parent = self.Main })
    self.LeftCrumb = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0, listWidth - 16, 1, 0),
        Text = "", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = CrumbBar,
    })
    self.RightCrumb = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, listWidth + 16, 0, 0), Size = UDim2.new(1, -listWidth - 32, 1, 0),
        Text = "Settings \\ —", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = CrumbBar,
    })

    ------------------------------------------------ Content (list | detail)
    self.Content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 1, -92 - 56), Parent = self.Main })
    new("Frame", { BackgroundColor3 = Theme.Stroke, Position = UDim2.new(0, listWidth, 0, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0, Parent = self.Content })

    ------------------------------------------------ Footer nav
    self.Footer = new("Frame", { BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(1, 0, 0, 56), Parent = self.Main },
        { corner(UDim.new(0, 12)) })
    new("Frame", { -- маска верхніх кутів (тільки низ заокруглений)
        BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 12),
        BorderSizePixel = 0, Parent = self.Footer,
    })
    self.FooterList = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = self.Footer,
    }, {
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 24), SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    ------------------------------------------------ Floating toggle button (persists even if Main hidden)
    local toggleBtn = self._janitor:add(new("TextButton", {
        BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 16, 0, 16), Size = UDim2.new(0, 32, 0, 32),
        Text = "", AutoButtonColor = false, ZIndex = 50, Parent = BlvckUI.ScreenGui,
    }, { corner(UDim.new(0, 8)) }))
    local toggleIcon = makeIcon("x", 16, Theme.Background)
    toggleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    toggleIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    toggleIcon.Parent = toggleBtn
    self._janitor:add(toggleBtn.MouseButton1Click:Connect(function()
        self.Main.Visible = not self.Main.Visible
    end))

    ------------------------------------------------ Drag (кламп по viewport, без витоку конектів)
    local dragging, dragStart, startPos = false, nil, nil
    self._janitor:add(Header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragStart = input.Position
        startPos = self.Main.Position
    end))
    self._janitor:add(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    self._janitor:add(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        local rawPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        self.Main.Position = clampToViewport(rawPos, self.Main.AbsoluteSize, workspace.CurrentCamera.ViewportSize)
    end))

    return self
end

function Window:_track(conn)
    self._janitor:add(conn)
    return conn
end

function Window:Destroy()
    tween(self.Main, EASE, { Size = UDim2.new(self._size.X.Scale, 0, self._size.Y.Scale, 0), BackgroundTransparency = 1 })
    task.delay(0.18, function()
        self._janitor:cleanup()
    end)
end

function Window:SetTitle(text)
    self.TitleLabel.Text = text
end

function Window:_selectCategory(category)
    if self._activeCategory == category then return end
    if self._activeCategory then self._activeCategory.ListFrame.Visible = false end
    self._activeCategory = category
    category.ListFrame.Visible = true
    self.LeftCrumb.Text = category.Name .. " \\ Modules"

    for _, cat in ipairs(self._categories) do
        local isActive = (cat == category)
        cat.Button.TextColor3 = isActive and Theme.Text or Theme.SubText
        if cat.Icon then setIconColor(cat.Icon, isActive and Theme.Text or Theme.SubText) end
    end

    if #category._modules > 0 then
        self:_selectModule(category._modules[1])
    else
        self.RightCrumb.Text = "Settings \\ —"
    end
end

function Window:_selectModule(module)
    if self._activeModule then self._activeModule.SettingsFrame.Visible = false end
    self._activeModule = module
    module.SettingsFrame.Visible = true
    self.RightCrumb.Text = "Settings \\ " .. (module.DetailTitle or module.Title)
end

--============================================================
-- КАТЕГОРІЯ (нижня навігація)
--============================================================

local Category = {}
Category.__index = Category

function Window:AddCategory(options)
    options = options or {}
    local category = setmetatable({}, Category)
    category._window = self
    category.Name = options.Name or "Category"
    category._modules = {}

    local isFirst = (#self._categories == 0)

    local button = new("TextButton", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 32),
        Text = "", AutoButtonColor = false, Parent = self.FooterList,
    }, {
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }),
        padding(0, { Left = 4, Right = 4 }),
    })

    if options.Icon then
        local icon = makeIcon(options.Icon, 16, isFirst and Theme.Text or Theme.SubText)
        icon.LayoutOrder = 1
        icon.Parent = button
        category.Icon = icon
    end

    new("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        Text = category.Name, Font = isFirst and Theme.FontBold or Theme.Font, TextSize = 13,
        TextColor3 = isFirst and Theme.Text or Theme.SubText, LayoutOrder = 2, Parent = button,
    })

    category.ListFrame = new("ScrollingFrame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, self.ListWidth, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, BorderSizePixel = 0,
        Visible = false, Parent = self.Content,
    }, { padding(16), new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

    category.Button = button

    self:_track(button.MouseButton1Click:Connect(function() self:_selectCategory(category) end))

    table.insert(self._categories, category)
    if isFirst then self:_selectCategory(category) end

    return category
end

--============================================================
-- МОДУЛЬ (рядок у списку + панель налаштувань)
--============================================================

local Module = {}
Module.__index = Module

function Category:AddModule(options)
    options = options or {}
    local module = setmetatable({}, Module)
    module._window = self._window
    module.Title = options.Title or "Module"
    module.DetailTitle = options.DetailTitle or module.Title

    local row = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Text = "", AutoButtonColor = false, Parent = self.ListFrame,
    })
    local glow = new("Frame", { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, Parent = row },
        { corner(UDim.new(0, 10)) })
    new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.82) }), Parent = glow })

    local textHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -100, 1, -16), Parent = row })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = module.Title, Font = Theme.FontBold,
        TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = textHolder,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 16),
        Text = options.Description or "", Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = textHolder,
    })

    local gear = new("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -72, 0.5, -12), Size = UDim2.new(0, 24, 0, 24),
        Text = "", AutoButtonColor = false, ZIndex = 2, Parent = row,
    })
    local gearIcon = makeIcon("settings", 16, Theme.SubText)
    gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    gearIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    gearIcon.Parent = gear

    local toggleState = options.Default or false
    local switchBg = new("TextButton", {
        Text = "", BackgroundColor3 = toggleState and Theme.Accent or Theme.SurfaceLight,
        Position = UDim2.new(1, -40, 0.5, -10), Size = UDim2.new(0, 40, 0, 20), AutoButtonColor = false, ZIndex = 2, Parent = row,
    }, { corner(UDim.new(1, 0)), stroke() })
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = toggleState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16), ZIndex = 3, Parent = switchBg,
    }, { corner(UDim.new(1, 0)) })

    local function applyToggle(state, fireCallback)
        toggleState = state
        tween(switchBg, EASE, { BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight })
        tween(knob, EASE, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
        tween(glow, EASE, { BackgroundTransparency = state and 0 or 1 })
        if fireCallback and options.Callback then task.spawn(options.Callback, state) end
    end
    applyToggle(toggleState, false)

    self._window:_track(switchBg.MouseButton1Click:Connect(function() applyToggle(not toggleState, true) end))

    module.SettingsFrame = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, self._window.ListWidth + 1, 0, 0),
        Size = UDim2.new(1, -(self._window.ListWidth + 1), 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, BorderSizePixel = 0,
        Visible = false, Parent = self._window.Content,
    }, { padding(16), new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }) })

    local function selectThis() self._window:_selectModule(module) end
    self._window:_track(row.MouseButton1Click:Connect(selectThis))
    self._window:_track(gear.MouseButton1Click:Connect(selectThis))

    module.Toggle = { Get = function() return toggleState end, Set = function(_, v) applyToggle(v, false) end }

    table.insert(self._modules, module)
    if #self._modules == 1 and self._window._activeCategory == self then
        self._window:_selectModule(module)
    end

    return module
end

--============================================================
-- ЕЛЕМЕНТИ ПАНЕЛІ НАЛАШТУВАНЬ
--============================================================

function Module:AddCheckbox(options)
    options = options or {}
    local state = options.Default or false

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = self.SettingsFrame })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -30, 1, 0), Text = options.Text or "Option",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })

    local strokeInst = stroke(state and Theme.Accent or Theme.Stroke)
    local box = new("TextButton", {
        BackgroundColor3 = state and Theme.Accent or Theme.Surface,
        Position = UDim2.new(1, -20, 0.5, -10), Size = UDim2.new(0, 20, 0, 20),
        Text = "", AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(0, 5)), strokeInst })
    local checkIcon = makeIcon("check", 12, Color3.new(1, 1, 1))
    checkIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    checkIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    checkIcon.Visible = state
    checkIcon.Parent = box

    local function apply(v, fireCallback)
        state = v
        checkIcon.Visible = state
        strokeInst.Color = state and Theme.Accent or Theme.Stroke
        tween(box, EASE, { BackgroundColor3 = state and Theme.Accent or Theme.Surface })
        if fireCallback and options.Callback then task.spawn(options.Callback, state) end
    end

    self._window:_track(box.MouseButton1Click:Connect(function() apply(not state, true) end))

    return { Get = function() return state end, Set = function(_, v) apply(v, false) end }
end

function Module:AddSlider(options)
    options = options or {}
    local min, max = options.Min or 0, options.Max or 100
    local value = math.clamp(options.Default or min, min, max)
    local suffix = options.Suffix or ""

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = self.SettingsFrame })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 18), Text = options.Text or "Slider",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -60, 0, 0), Size = UDim2.new(0, 60, 0, 18),
        Text = tostring(value) .. suffix, Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
    })

    local track = new("Frame", { BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 6), Parent = holder },
        { corner(UDim.new(1, 0)) })
    local fill = new("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.new((value - min) / (max - min), 0, 1, 0), Parent = track },
        { corner(UDim.new(1, 0)) })
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0), Size = UDim2.new(0, 12, 0, 12), ZIndex = 2, Parent = track,
    }, { corner(UDim.new(1, 0)) })

    local function setFromRelative(relative, fireCallback)
        relative = math.clamp(relative, 0, 1)
        value = math.floor(min + (max - min) * relative + 0.5)
        local snap = (value - min) / (max - min)
        tween(fill, TweenInfo.new(0.08), { Size = UDim2.new(snap, 0, 1, 0) })
        tween(knob, TweenInfo.new(0.08), { Position = UDim2.new(snap, 0, 0.5, 0) })
        valueLabel.Text = tostring(value) .. suffix
        if fireCallback and options.Callback then task.spawn(options.Callback, value) end
    end

    local dragging = false
    self._window:_track(track.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        setFromRelative((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)
    end))
    self._window:_track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    self._window:_track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        setFromRelative((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)
    end))

    return {
        Get = function() return value end,
        Set = function(_, v) setFromRelative((math.clamp(v, min, max) - min) / (max - min), false) end,
    }
end

function Module:AddSelectList(options)
    options = options or {}
    local items = options.Items or {}
    local selected = options.Default or items[1]

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.SettingsFrame })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = options.Text or "Select",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    local list = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = holder,
    }, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

    local rows = {}
    local function refreshVisual()
        for _, r in ipairs(rows) do
            local isSel = (r.item == selected)
            r.label.TextColor3 = isSel and Theme.Text or Theme.SubText
            r.check.Visible = isSel
        end
    end

    for _, item in ipairs(items) do
        local row = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Text = "", AutoButtonColor = false, Parent = list })
        local label = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0), Text = tostring(item),
            Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
        local check = makeIcon("check", 14, Theme.Accent)
        check.Position = UDim2.new(1, -18, 0.5, -7)
        check.Visible = false
        check.Parent = row

        self._window:_track(row.MouseButton1Click:Connect(function()
            selected = item
            refreshVisual()
            if options.Callback then task.spawn(options.Callback, item) end
        end))

        table.insert(rows, { item = item, label = label, check = check })
    end

    refreshVisual()
    return { Get = function() return selected end }
end

function Module:AddCheckList(options)
    options = options or {}
    local items = options.Items or {}
    local checked = {}
    for _, item in ipairs(options.Default or {}) do checked[item] = true end

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.SettingsFrame })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = options.Text or "List",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    local list = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = holder,
    }, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

    for _, item in ipairs(items) do
        local row = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Text = "", AutoButtonColor = false, Parent = list })
        local isChecked = checked[item] == true
        local label = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0), Text = tostring(item),
            Font = Theme.Font, TextSize = 13, TextColor3 = isChecked and Theme.Text or Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
        local check = makeIcon("check", 14, Theme.Accent)
        check.Position = UDim2.new(1, -18, 0.5, -7)
        check.Visible = isChecked
        check.Parent = row

        self._window:_track(row.MouseButton1Click:Connect(function()
            local newState = not (checked[item] == true)
            checked[item] = newState
            label.TextColor3 = newState and Theme.Text or Theme.SubText
            check.Visible = newState
            if options.Callback then task.spawn(options.Callback, item, newState) end
        end))
    end

    return {
        IsChecked = function(_, item) return checked[item] == true end,
        GetChecked = function()
            local out = {}
            for _, item in ipairs(items) do if checked[item] then table.insert(out, item) end end
            return out
        end,
    }
end

--============================================================
-- COLOR PICKER (HSV + alpha)
--============================================================

local openColorPicker -- forward declaration (used by Module:AddColorPicker below)

function Module:AddColorPicker(options)
    options = options or {}
    local color = options.Default or Color3.fromRGB(255, 255, 255)
    local alpha = options.DefaultAlpha or 1

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = self.SettingsFrame })
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Text = options.Text or "Color",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    local hexLabel = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -90, 0, 0), Size = UDim2.new(0, 60, 1, 0),
        Text = "#" .. color:ToHex():upper(), Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
    })
    local swatch = new("TextButton", {
        BackgroundColor3 = color, Position = UDim2.new(1, -20, 0.5, -10), Size = UDim2.new(0, 20, 0, 20),
        Text = "", AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(1, 0)), stroke() })

    self._window:_track(swatch.MouseButton1Click:Connect(function()
        openColorPicker(self._window, swatch, color, alpha, function(newColor, newAlpha)
            color, alpha = newColor, newAlpha
            swatch.BackgroundColor3 = color
            hexLabel.Text = "#" .. color:ToHex():upper()
            if options.Callback then task.spawn(options.Callback, color, alpha) end
        end)
    end))

    return {
        Get = function() return color, alpha end,
        Set = function(_, c, a)
            color = c
            if a then alpha = a end
            swatch.BackgroundColor3 = color
            hexLabel.Text = "#" .. color:ToHex():upper()
        end,
    }
end

openColorPicker = function(window, anchor, initialColor, initialAlpha, callback)
    local h, s, v = initialColor:ToHSV()
    local alpha = initialAlpha or 1

    if window._colorPicker then
        window._colorPicker.Destroy()
        window._colorPicker = nil
    end

    local janitor = newJanitor()

    local panelSize = Vector2.new(210, 270)
    local anchorPos, anchorSize = anchor.AbsolutePosition, anchor.AbsoluteSize
    local viewport = workspace.CurrentCamera.ViewportSize
    local posX = math.clamp(anchorPos.X - panelSize.X + anchorSize.X, 0, math.max(0, viewport.X - panelSize.X))
    local posY = math.clamp(anchorPos.Y + anchorSize.Y + 8, 0, math.max(0, viewport.Y - panelSize.Y))

    local panel = janitor:add(new("Frame", {
        BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, posX, 0, posY),
        Size = UDim2.new(0, panelSize.X, 0, panelSize.Y), ZIndex = 20, Parent = BlvckUI.ScreenGui,
    }, { corner(UDim.new(0, 10)), stroke() }))
    window._janitor:add(panel) -- бекап-очищення, якщо вікно закриють поки пікер відкритий

    local titleBar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = panel })
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -40, 1, 0),
        Text = "Color", Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar,
    })
    local closeBtn = new("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(1, -26, 0.5, -10), Size = UDim2.new(0, 20, 0, 20),
        Text = "", AutoButtonColor = false, ZIndex = 21, Parent = titleBar,
    }, { corner(UDim.new(0, 5)) })
    local closeIcon = makeIcon("x", 12, Theme.SubText)
    closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    closeIcon.Parent = closeBtn
    janitor:add(closeBtn.MouseButton1Click:Connect(function()
        janitor:cleanup()
        window._colorPicker = nil
    end))

    local svSize = Vector2.new(180, 130)
    local svBox = new("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), Position = UDim2.new(0, 10, 0, 34),
        Size = UDim2.new(0, svSize.X, 0, svSize.Y), ClipsDescendants = true, ZIndex = 20, Parent = panel,
    }, { corner(UDim.new(0, 6)) })

    local whiteOverlay = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 20, Parent = svBox })
    new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = whiteOverlay })
    local blackOverlay = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 20, Parent = svBox })
    new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = blackOverlay })

    local svHandle = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(s, 0, 1 - v, 0), Size = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = svBox,
    }, { corner(UDim.new(1, 0)), stroke(Color3.new(0, 0, 0), 2) })

    local hueBar = new("Frame", {
        Position = UDim2.new(0, 10 + svSize.X + 10, 0, 34), Size = UDim2.new(0, 16, 0, svSize.Y), ZIndex = 20, Parent = panel,
    }, { corner(UDim.new(0, 4)) })
    local hueColors = {}
    for i = 0, 6 do table.insert(hueColors, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1))) end
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueColors), Parent = hueBar })
    local hueHandle = new("Frame", {
        Position = UDim2.new(0.5, 0, h, 0), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 4),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = hueBar,
    }, { corner(UDim.new(0, 2)), stroke(Color3.new(0, 0, 0), 1) })

    local alphaBar = new("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, s, v), Position = UDim2.new(0, 10, 0, 34 + svSize.Y + 14),
        Size = UDim2.new(0, svSize.X, 0, 14), ZIndex = 20, Parent = panel,
    }, { corner(UDim.new(0, 4)) })
    new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = alphaBar })
    local alphaHandle = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(alpha, 0, 0.5, 0), Size = UDim2.new(0, 4, 1, 4),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22, Parent = alphaBar,
    }, { corner(UDim.new(0, 2)), stroke(Color3.new(0, 0, 0), 1) })

    local hexLabel = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 34 + svSize.Y + 14 + 20), Size = UDim2.new(1, -20, 0, 18),
        Text = "#" .. initialColor:ToHex():upper(), Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
    })

    local function currentColor() return Color3.fromHSV(h, s, v) end
    local function refresh(fireCallback)
        svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        alphaBar.BackgroundColor3 = currentColor()
        hexLabel.Text = "#" .. currentColor():ToHex():upper()
        if fireCallback and callback then task.spawn(callback, currentColor(), alpha) end
    end

    local function bindDrag(control, onDrag)
        local active = false
        local function process(input) onDrag(Vector2.new(input.Position.X, input.Position.Y)) end
        janitor:add(control.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            active = true
            process(input)
        end))
        janitor:add(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then active = false end
        end))
        janitor:add(UserInputService.InputChanged:Connect(function(input)
            if not active then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            process(input)
        end))
    end

    bindDrag(svBox, function(pos)
        local rel = pos - svBox.AbsolutePosition
        s = math.clamp(rel.X / svBox.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp(rel.Y / svBox.AbsoluteSize.Y, 0, 1)
        svHandle.Position = UDim2.new(s, 0, 1 - v, 0)
        refresh(true)
    end)
    bindDrag(hueBar, function(pos)
        local rel = pos - hueBar.AbsolutePosition
        h = math.clamp(rel.Y / hueBar.AbsoluteSize.Y, 0, 1)
        hueHandle.Position = UDim2.new(0.5, 0, h, 0)
        refresh(true)
    end)
    bindDrag(alphaBar, function(pos)
        local rel = pos - alphaBar.AbsolutePosition
        alpha = math.clamp(rel.X / alphaBar.AbsoluteSize.X, 0, 1)
        alphaHandle.Position = UDim2.new(alpha, 0, 0.5, 0)
        refresh(true)
    end)

    window._colorPicker = { Destroy = function() janitor:cleanup() end }
end

return BlvckUI
