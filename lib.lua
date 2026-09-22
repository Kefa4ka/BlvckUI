--[[
    ============================================================
     UILibrary — мінімалістична чорна GUI бібліотека для Roblox
    ============================================================

    Розповсюджується через loadstring, інші скрипти підключають
    її одним рядком і пишуть легкий код поверху:

        local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/UILibrary.lua"))()

        local Window = UI:CreateWindow({ Title = "LumeVisuals" })
        local Tab = Window:AddTab("Main")
        local Section = Tab:AddSection("Combat")

        Section:AddButton({ Text = "Click me", Callback = function() print("click") end })
        Section:AddToggle({ Text = "ESP", Callback = function(v) print(v) end })

        UI:Notify({ Title = "Готово", Text = "Налаштування збережено", Type = "Success" })

    Структура:
        UILibrary               -- кореневий модуль (:CreateWindow, :Notify, :SetAccent)
          Window                -- :AddTab, :Destroy, :Minimize, :SetTitle
            Tab                 -- :AddSection
              Section           -- :AddButton/:AddToggle/:AddSlider/:AddDropdown/
                                    :AddTextBox/:AddKeybind/:AddLabel
    ============================================================
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- ТЕМА
----------------------------------------------------------------

local Theme = {
    Background      = Color3.fromRGB(13, 14, 17),    -- #0D0E11
    Surface         = Color3.fromRGB(19, 20, 24),
    SurfaceLight    = Color3.fromRGB(27, 28, 33),
    SurfaceHover    = Color3.fromRGB(34, 35, 41),
    Stroke          = Color3.fromRGB(38, 39, 46),
    Accent          = Color3.fromRGB(158, 142, 247), -- #9E8EF7
    AccentDark      = Color3.fromRGB(112, 98, 190),
    Text            = Color3.fromRGB(238, 238, 242),
    SubText         = Color3.fromRGB(138, 139, 148),
    Success         = Color3.fromRGB(102, 214, 150),
    Error           = Color3.fromRGB(235, 100, 110),
    Warning         = Color3.fromRGB(240, 190, 100),
    Info            = Color3.fromRGB(120, 170, 240),
    Font            = Enum.Font.GothamMedium,
    FontBold        = Enum.Font.GothamBold,
    Corner          = UDim.new(0, 8),
    ToastCorner     = UDim.new(0, 10),
}

local EASE      = TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_OPEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

----------------------------------------------------------------
-- УТИЛІТИ
----------------------------------------------------------------

local function create(class, props, children)
    local inst = Instance.new(class)
    for prop, value in pairs(props or {}) do
        inst[prop] = value
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function corner(radius) return create("UICorner", { CornerRadius = radius or Theme.Corner }) end
local function stroke(color, thickness, transparency)
    return create("UIStroke", { Color = color or Theme.Stroke, Thickness = thickness or 1, Transparency = transparency or 0 })
end
local function pad(all, extra)
    extra = extra or {}
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, extra.Left or all),
        PaddingRight = UDim.new(0, extra.Right or all),
        PaddingTop = UDim.new(0, extra.Top or all),
        PaddingBottom = UDim.new(0, extra.Bottom or all),
    })
end
local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

----------------------------------------------------------------
-- КОРІНЬ БІБЛІОТЕКИ
----------------------------------------------------------------

local UILibrary = {}
UILibrary.Theme = Theme
UILibrary._windows = {}

UILibrary.ScreenGui = create("ScreenGui", {
    Name = "UILibrary_" .. tostring(math.random(1, 999999)),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    Parent = PlayerGui,
})

function UILibrary:SetAccent(color3)
    Theme.Accent = color3
end

----------------------------------------------------------------
-- TOAST / НОТИФІКАЦІЇ
----------------------------------------------------------------

local ToastHolder = create("Frame", {
    Name = "ToastHolder",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 300, 1, -32),
    Parent = UILibrary.ScreenGui,
}, {
    create("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

local TOAST_ICON = { Success = "✓", Error = "✕", Warning = "!", Info = "i" }

function UILibrary:Notify(options)
    options = options or {}
    local title = options.Title or "Notification"
    local text = options.Text or ""
    local kind = options.Type or "Info"
    local duration = options.Duration or 4
    local accentColor = Theme[kind] or Theme.Info

    local toast = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        BackgroundTransparency = 1,
        Parent = ToastHolder,
    }, { corner(Theme.ToastCorner), stroke(Theme.Stroke, 1) })

    local inner = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = toast,
    }, { pad(12) })

    create("Frame", {
        BackgroundColor3 = accentColor,
        Size = UDim2.new(0, 3, 1, 0),
        Parent = toast,
    }, { corner(UDim.new(0, 2)) })

    create("TextLabel", {
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.85,
        Size = UDim2.new(0, 26, 0, 26),
        Text = TOAST_ICON[kind] or "i",
        TextColor3 = accentColor,
        Font = Theme.FontBold,
        TextSize = 14,
        Parent = inner,
    }, { corner(UDim.new(0, 6)) })

    local textHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 36, 0, 0),
        Size = UDim2.new(1, -36, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = inner,
    }, { create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Text = title,
        TextColor3 = Theme.Text,
        Font = Theme.FontBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = textHolder,
    })

    if text ~= "" then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = text,
            TextColor3 = Theme.SubText,
            Font = Theme.Font,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = textHolder,
        })
    end

    -- прогрес-бар часу життя тоста
    local progressTrack = create("Frame", {
        BackgroundColor3 = Theme.SurfaceLight,
        Size = UDim2.new(1, 0, 0, 3),
        Parent = toast,
    }, { corner(UDim.new(1, 0)) })
    local progressFill = create("Frame", {
        BackgroundColor3 = accentColor,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = progressTrack,
    }, { corner(UDim.new(1, 0)) })

    toast.Position = UDim2.new(1, 60, 0, 0)
    tween(toast, EASE_SLOW, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
    tween(progressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })

    local function dismiss()
        if not toast or not toast.Parent then return end
        local out = tween(toast, EASE, { BackgroundTransparency = 1, Position = UDim2.new(1, 60, 0, 0) })
        out.Completed:Connect(function() toast:Destroy() end)
    end

    task.delay(duration, dismiss)

    return toast
end

----------------------------------------------------------------
-- ВІКНО (Window)
----------------------------------------------------------------

local Window = {}
Window.__index = Window

function UILibrary:CreateWindow(options)
    options = options or {}
    local title = options.Title or "UILibrary"
    local size = options.Size or UDim2.new(0, 480, 0, 520)

    local self = setmetatable({}, Window)
    self._tabs = {}

    self.Main = create("Frame", {
        Name = "Window",
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(size.X.Scale, 0, size.Y.Scale, 0),
        Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        ClipsDescendants = true,
        Parent = UILibrary.ScreenGui,
    }, { corner(UDim.new(0, 12)), stroke(Theme.Stroke, 1) })

    -- анімація появи вікна
    tween(self.Main, EASE_OPEN, { Size = size })

    ---------------------------------------------------------------- TopBar
    local TopBar = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 44),
        Parent = self.Main,
    }, { corner(UDim.new(0, 12)) })

    create("Frame", { -- прибираємо закруглення знизу topbar
        BackgroundColor3 = Theme.Surface,
        Position = UDim2.new(0, 0, 1, -12),
        Size = UDim2.new(1, 0, 0, 12),
        BorderSizePixel = 0,
        Parent = TopBar,
    })

    self.TitleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -104, 1, 0),
        Text = title,
        Font = Theme.FontBold,
        TextSize = 15,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local function topBarButton(text, order)
        local b = create("TextButton", {
            BackgroundColor3 = Theme.SurfaceLight,
            Position = UDim2.new(1, -32 - (order * 32), 0.5, -12),
            Size = UDim2.new(0, 24, 0, 24),
            Text = text,
            Font = Theme.FontBold,
            TextSize = 16,
            TextColor3 = Theme.SubText,
            AutoButtonColor = false,
            Parent = TopBar,
        }, { corner(UDim.new(0, 6)) })
        b.MouseEnter:Connect(function() tween(b, EASE, { BackgroundColor3 = Theme.SurfaceHover }) end)
        b.MouseLeave:Connect(function() tween(b, EASE, { BackgroundColor3 = Theme.SurfaceLight }) end)
        return b
    end

    local CloseBtn = topBarButton("×", 0)
    local MinimizeBtn = topBarButton("—", 1)

    CloseBtn.MouseButton1Click:Connect(function() self:Destroy() end)
    MinimizeBtn.MouseButton1Click:Connect(function() self:Minimize() end)

    ---------------------------------------------------------------- Tab bar (ліворуч, вертикально)
    local TabBar = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        Position = UDim2.new(0, 0, 0, 44),
        Size = UDim2.new(0, 128, 1, -44),
        Parent = self.Main,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
        pad(10),
    })

    ---------------------------------------------------------------- Page holder (праворуч)
    self.PageHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 128, 0, 44),
        Size = UDim2.new(1, -128, 1, -44),
        Parent = self.Main,
    })

    self._tabBar = TabBar
    self._size = size
    self._minimized = false

    ---------------------------------------------------------------- Перетягування
    local dragging, dragStart, startPos = false, nil, nil
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    table.insert(UILibrary._windows, self)
    return self
end

function Window:Destroy()
    tween(self.Main, EASE, { Size = UDim2.new(self._size.X.Scale, 0, self._size.Y.Scale, 0), BackgroundTransparency = 1 })
    task.wait(0.2)
    self.Main:Destroy()
end

function Window:Minimize()
    self._minimized = not self._minimized
    if self._minimized then
        self._expandedSize = self.Main.Size
        tween(self.Main, EASE, { Size = UDim2.new(self._expandedSize.X.Scale, self._expandedSize.X.Offset, 0, 44) })
    else
        tween(self.Main, EASE, { Size = self._expandedSize })
    end
end

function Window:SetTitle(text)
    self.TitleLabel.Text = text
end

----------------------------------------------------------------
-- ТАБ (Tab)
----------------------------------------------------------------

local Tab = {}
Tab.__index = Tab

function Window:AddTab(name)
    local tabObj = setmetatable({}, Tab)

    local tabButton = create("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight,
        Size = UDim2.new(1, 0, 0, 32),
        Text = name,
        Font = Theme.Font,
        TextSize = 13,
        TextColor3 = Theme.SubText,
        AutoButtonColor = false,
        Parent = self._tabBar,
    }, { corner(UDim.new(0, 6)) })

    local page = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = (#self._tabs == 0),
        Parent = self.PageHolder,
    }, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }), pad(14) })

    tabObj.Page = page
    tabObj._window = self

    if #self._tabs == 0 then
        tabButton.BackgroundColor3 = Theme.Accent
        tabButton.TextColor3 = Color3.new(1, 1, 1)
    end

    tabButton.MouseButton1Click:Connect(function()
        for _, t in ipairs(self._tabs) do
            t.Page.Visible = false
            tween(t.Button, EASE, { BackgroundColor3 = Theme.SurfaceLight, TextColor3 = Theme.SubText })
        end
        page.Visible = true
        tween(tabButton, EASE, { BackgroundColor3 = Theme.Accent, TextColor3 = Color3.new(1, 1, 1) })
    end)

    tabObj.Button = tabButton
    table.insert(self._tabs, tabObj)
    return tabObj
end

----------------------------------------------------------------
-- СЕКЦІЯ (Section)
----------------------------------------------------------------

local Section = {}
Section.__index = Section

function Tab:AddSection(title)
    local self = setmetatable({}, Section)

    self.Frame = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self.Page,
    }, { corner(), stroke(Theme.Stroke, 1), pad(14) })

    if title then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Text = title,
            Font = Theme.FontBold,
            TextSize = 14,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = -1,
            Parent = self.Frame,
        })
    end

    create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = self.Frame

    return self
end

----------------------------------------------------------------
-- ЕЛЕМЕНТИ
----------------------------------------------------------------

function Section:AddButton(options)
    options = options or {}
    local btn = create("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight,
        Size = UDim2.new(1, 0, 0, 36),
        Text = options.Text or "Button",
        Font = Theme.Font,
        TextSize = 13,
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
        Parent = self.Frame,
    }, { corner(UDim.new(0, 6)), stroke(Theme.Stroke, 1) })

    btn.MouseEnter:Connect(function() tween(btn, EASE, { BackgroundColor3 = Theme.Accent, TextColor3 = Color3.new(1, 1, 1) }) end)
    btn.MouseLeave:Connect(function() tween(btn, EASE, { BackgroundColor3 = Theme.SurfaceLight, TextColor3 = Theme.Text }) end)
    btn.MouseButton1Click:Connect(function()
        tween(btn, TweenInfo.new(0.08), { Size = UDim2.new(1, -4, 0, 34) })
        task.delay(0.08, function() tween(btn, EASE, { Size = UDim2.new(1, 0, 0, 36) }) end)
        if options.Callback then task.spawn(options.Callback) end
    end)

    return btn
end

function Section:AddLabel(text)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Text = text or "",
        Font = Theme.Font,
        TextSize = 13,
        TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.Frame,
    })
end

function Section:AddToggle(options)
    options = options or {}
    local state = options.Default or false

    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = self.Frame })

    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -50, 1, 0),
        Text = options.Text or "Toggle",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder,
    })

    local switchBg = create("TextButton", {
        Text = "", BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight,
        Position = UDim2.new(1, -40, 0.5, -10), Size = UDim2.new(0, 40, 0, 20),
        AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(1, 0)), stroke(Theme.Stroke, 1) })

    local knob = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16), Parent = switchBg,
    }, { corner(UDim.new(1, 0)) })

    local function apply(v, fire)
        state = v
        tween(switchBg, EASE, { BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight })
        tween(knob, EASE, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
        if fire and options.Callback then task.spawn(options.Callback, state) end
    end

    switchBg.MouseButton1Click:Connect(function() apply(not state, true) end)
    if state and options.Callback then task.spawn(options.Callback, state) end

    return { Set = function(_, v) apply(v, false) end, Get = function() return state end }
end

function Section:AddSlider(options)
    options = options or {}
    local min, max = options.Min or 0, options.Max or 100
    local value = options.Default or min

    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = self.Frame })
    local label = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        Text = string.format("%s: %d", options.Text or "Slider", value),
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })

    local track = create("Frame", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 6), Parent = holder,
    }, { corner(UDim.new(1, 0)) })

    local fill = create("Frame", {
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0), Parent = track,
    }, { corner(UDim.new(1, 0)) })

    local knob = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), ZIndex = 2, Parent = track,
    }, { corner(UDim.new(1, 0)) })

    local dragging = false
    local function setFromInput(inputPos)
        local relative = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * relative + 0.5)
        tween(fill, TweenInfo.new(0.08), { Size = UDim2.new(relative, 0, 1, 0) })
        tween(knob, TweenInfo.new(0.08), { Position = UDim2.new(relative, 0, 0.5, 0) })
        label.Text = string.format("%s: %d", options.Text or "Slider", value)
        if options.Callback then task.spawn(options.Callback, value) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInput(input.Position)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromInput(input.Position)
        end
    end)

    return { Set = function(_, v)
        value = math.clamp(v, min, max)
        local relative = (value - min) / (max - min)
        tween(fill, EASE, { Size = UDim2.new(relative, 0, 1, 0) })
        tween(knob, EASE, { Position = UDim2.new(relative, 0, 0.5, 0) })
        label.Text = string.format("%s: %d", options.Text or "Slider", value)
    end, Get = function() return value end }
end

function Section:AddTextBox(options)
    options = options or {}
    local box = create("TextBox", {
        BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 34),
        Text = options.Default or "", PlaceholderText = options.Placeholder or "Enter text...",
        PlaceholderColor3 = Theme.SubText, Font = Theme.Font, TextSize = 13,
        TextColor3 = Theme.Text, ClearTextOnFocus = false, Parent = self.Frame,
    }, { corner(UDim.new(0, 6)), stroke(Theme.Stroke, 1), pad(8) })

    box.FocusLost:Connect(function(enterPressed)
        if options.Callback then task.spawn(options.Callback, box.Text, enterPressed) end
    end)
    return box
end

function Section:AddDropdown(options)
    options = options or {}
    local items = options.Items or {}
    local selected = options.Default or items[1]

    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = self.Frame })

    local main = create("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 34),
        Text = "", AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(0, 6)), stroke(Theme.Stroke, 1) })

    create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -30, 1, 0),
        Text = (options.Text and (options.Text .. ": ") or "") .. tostring(selected or "—"),
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = main,
    })
    local valueLabel = main:FindFirstChildOfClass("TextLabel")

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.new(0, 20, 1, 0),
        Text = "▾", Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.SubText, Parent = main,
    })

    local list = create("Frame", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(0, 0, 1, 6),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 5, Parent = main,
    }, { corner(UDim.new(0, 6)), stroke(Theme.Stroke, 1), pad(4),
         create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

    local open = false
    local function toggleList()
        open = not open
        list.Visible = open
        tween(arrow, EASE, { Rotation = open and 180 or 0 })
    end

    for _, item in ipairs(items) do
        local opt = create("TextButton", {
            BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 28),
            Text = tostring(item), Font = Theme.Font, TextSize = 13,
            TextColor3 = Theme.Text, AutoButtonColor = false, ZIndex = 5, Parent = list,
        }, { corner(UDim.new(0, 4)) })
        opt.MouseEnter:Connect(function() tween(opt, EASE, { BackgroundColor3 = Theme.Accent }) end)
        opt.MouseLeave:Connect(function() tween(opt, EASE, { BackgroundColor3 = Theme.SurfaceLight }) end)
        opt.MouseButton1Click:Connect(function()
            selected = item
            valueLabel.Text = (options.Text and (options.Text .. ": ") or "") .. tostring(item)
            toggleList()
            if options.Callback then task.spawn(options.Callback, item) end
        end)
    end

    main.MouseButton1Click:Connect(toggleList)

    return { Get = function() return selected end }
end

function Section:AddKeybind(options)
    options = options or {}
    local currentKey = options.Default or Enum.KeyCode.Unknown
    local listening = false

    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = self.Frame })

    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0),
        Text = options.Text or "Keybind", Font = Theme.Font, TextSize = 13,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })

    local keyBtn = create("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(1, -80, 0.5, -14),
        Size = UDim2.new(0, 80, 0, 28), Text = currentKey.Name,
        Font = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText,
        AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(0, 6)), stroke(Theme.Stroke, 1) })

    keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
        tween(keyBtn, EASE, { BackgroundColor3 = Theme.Accent })
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            currentKey = input.KeyCode
            keyBtn.Text = currentKey.Name
            listening = false
            tween(keyBtn, EASE, { BackgroundColor3 = Theme.SurfaceLight })
            if options.Callback then task.spawn(options.Callback, currentKey) end
        elseif not listening and not gpe and input.KeyCode == currentKey then
            if options.OnPress then task.spawn(options.OnPress) end
        end
    end)

    return { Get = function() return currentKey end }
end

return UILibrary
