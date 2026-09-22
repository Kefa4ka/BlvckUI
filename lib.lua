--[[
    BlvckUI
    https://github.com/Kefa4ka/BlvckUI

    local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kefa4ka/BlvckUI/refs/heads/main/lib.lua"))()

    local Window  = UI:CreateWindow({ Title = "LumeVisuals" })
    local Tab     = Window:AddTab("Main")
    local Section = Tab:AddSection("Combat")

    Section:AddButton({ Text = "Click me", Callback = function() print("click") end })
    UI:Notify({ Title = "Готово", Text = "Збережено", Type = "Success" })
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
    Accent       = Color3.fromRGB(158, 142, 247),
    Text         = Color3.fromRGB(238, 238, 242),
    SubText      = Color3.fromRGB(138, 139, 148),
    Success      = Color3.fromRGB(102, 214, 150),
    Error        = Color3.fromRGB(235, 100, 110),
    Warning      = Color3.fromRGB(240, 190, 100),
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

local function padding(px)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
        PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
    })
end

local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- невеликий cleanup-хелпер: збирає конекти й інстанси, звільняє все одним викликом
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

local function clampToViewport(pos, absSize, viewportSize)
    local x = math.clamp(pos.X.Offset, 0, math.max(0, viewportSize.X - absSize.X))
    local y = math.clamp(pos.Y.Offset, 0, math.max(0, viewportSize.Y - absSize.Y))
    return UDim2.new(0, x, 0, y)
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

local TOAST_ICON = { Success = "✓", Error = "✕", Warning = "!", Info = "i" }

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

    new("TextLabel", {
        BackgroundColor3 = accentColor, BackgroundTransparency = 0.85,
        Size = UDim2.new(0, 26, 0, 26),
        Text = TOAST_ICON[kind] or "i", TextColor3 = accentColor,
        Font = Theme.FontBold, TextSize = 14, Parent = inner,
    }, { corner(UDim.new(0, 6)) })

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
    local size = options.Size or UDim2.new(0, 480, 0, 520)

    local self = setmetatable({}, Window)
    self._tabs = {}
    self._size = size
    self._janitor = newJanitor()

    self.Main = self._janitor:add(new("Frame", {
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(size.X.Scale, 0, size.Y.Scale, 0),
        Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        ClipsDescendants = true,
        Parent = BlvckUI.ScreenGui,
    }, { corner(UDim.new(0, 12)), stroke() }))

    tween(self.Main, EASE_OPEN, { Size = size })

    local TopBar = new("Frame", { BackgroundColor3 = Theme.Surface, Size = UDim2.new(1, 0, 0, 44), Parent = self.Main },
        { corner(UDim.new(0, 12)) })
    new("Frame", { -- маска для нижніх кутів TopBar (щоб не було закруглення знизу)
        BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, 0, 1, -12),
        Size = UDim2.new(1, 0, 0, 12), BorderSizePixel = 0, Parent = TopBar,
    })

    self.TitleLabel = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -104, 1, 0),
        Text = options.Title or "BlvckUI", Font = Theme.FontBold, TextSize = 15,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = TopBar,
    })

    local function topBarButton(text, order)
        local b = new("TextButton", {
            BackgroundColor3 = Theme.SurfaceLight,
            Position = UDim2.new(1, -32 - (order * 32), 0.5, -12),
            Size = UDim2.new(0, 24, 0, 24), Text = text, Font = Theme.FontBold, TextSize = 16,
            TextColor3 = Theme.SubText, AutoButtonColor = false, Parent = TopBar,
        }, { corner(UDim.new(0, 6)) })
        self._janitor:add(b.MouseEnter:Connect(function() tween(b, EASE, { BackgroundColor3 = Theme.SurfaceHover }) end))
        self._janitor:add(b.MouseLeave:Connect(function() tween(b, EASE, { BackgroundColor3 = Theme.SurfaceLight }) end))
        return b
    end

    local closeBtn = topBarButton("×", 0)
    local minimizeBtn = topBarButton("—", 1)
    self._janitor:add(closeBtn.MouseButton1Click:Connect(function() self:Destroy() end))
    self._janitor:add(minimizeBtn.MouseButton1Click:Connect(function() self:Minimize() end))

    self._tabBar = new("Frame", {
        BackgroundColor3 = Theme.Surface, Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(0, 128, 1, -44),
        Parent = self.Main,
    }, {
        new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
        padding(10),
    })

    self.PageHolder = new("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 128, 0, 44), Size = UDim2.new(1, -128, 1, -44),
        Parent = self.Main,
    })

    -- перетягування з кламп по межах екрану; лише один InputChanged на все вікно (не плодиться щоклаку)
    local dragging = false
    local dragStart, startPos

    self._janitor:add(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
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
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        local rawPos = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        self.Main.Position = clampToViewport(rawPos, self.Main.AbsoluteSize, workspace.CurrentCamera.ViewportSize)
    end))

    return self
end

-- дозволяє елементам реєструвати свої конекти для очищення разом з вікном
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

--============================================================
-- ТАБ
--============================================================

local Tab = {}
Tab.__index = Tab

function Window:AddTab(name)
    local tab = setmetatable({}, Tab)
    tab._window = self

    local isFirstTab = (#self._tabs == 0)

    local button = new("TextButton", {
        BackgroundColor3 = isFirstTab and Theme.Accent or Theme.SurfaceLight,
        Size = UDim2.new(1, 0, 0, 32), Text = name, Font = Theme.Font, TextSize = 13,
        TextColor3 = isFirstTab and Color3.new(1, 1, 1) or Theme.SubText,
        AutoButtonColor = false, Parent = self._tabBar,
    }, { corner(UDim.new(0, 6)) })

    local page = new("ScrollingFrame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, BorderSizePixel = 0,
        Visible = isFirstTab, Parent = self.PageHolder,
    }, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }), padding(14) })

    tab.Page = page
    tab.Button = button

    self:_track(button.MouseButton1Click:Connect(function()
        for _, t in ipairs(self._tabs) do
            t.Page.Visible = false
            tween(t.Button, EASE, { BackgroundColor3 = Theme.SurfaceLight, TextColor3 = Theme.SubText })
        end
        page.Visible = true
        tween(button, EASE, { BackgroundColor3 = Theme.Accent, TextColor3 = Color3.new(1, 1, 1) })
    end))

    table.insert(self._tabs, tab)
    return tab
end

--============================================================
-- СЕКЦІЯ
--============================================================

local Section = {}
Section.__index = Section

function Tab:AddSection(title)
    local section = setmetatable({}, Section)
    section._window = self._window

    section.Frame = new("Frame", {
        BackgroundColor3 = Theme.Surface, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Page,
    }, { corner(), stroke(), padding(14) })

    if title then
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Text = title,
            Font = Theme.FontBold, TextSize = 14, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -1, Parent = section.Frame,
        })
    end

    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = section.Frame

    return section
end

--============================================================
-- ЕЛЕМЕНТИ
--============================================================

function Section:AddButton(options)
    options = options or {}
    local btn = new("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 36),
        Text = options.Text or "Button", Font = Theme.Font, TextSize = 13,
        TextColor3 = Theme.Text, AutoButtonColor = false, Parent = self.Frame,
    }, { corner(UDim.new(0, 6)), stroke() })

    self._window:_track(btn.MouseEnter:Connect(function()
        tween(btn, EASE, { BackgroundColor3 = Theme.Accent, TextColor3 = Color3.new(1, 1, 1) })
    end))
    self._window:_track(btn.MouseLeave:Connect(function()
        tween(btn, EASE, { BackgroundColor3 = Theme.SurfaceLight, TextColor3 = Theme.Text })
    end))
    self._window:_track(btn.MouseButton1Click:Connect(function()
        if options.Callback then task.spawn(options.Callback) end
    end))

    return btn
end

function Section:AddLabel(text)
    return new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = text or "",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = self.Frame,
    })
end

function Section:AddToggle(options)
    options = options or {}
    local state = options.Default or false

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = self.Frame })

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0), Text = options.Text or "Toggle",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })

    local switchBg = new("TextButton", {
        Text = "", BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight,
        Position = UDim2.new(1, -40, 0.5, -10), Size = UDim2.new(0, 40, 0, 20),
        AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(1, 0)), stroke() })

    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16), Parent = switchBg,
    }, { corner(UDim.new(1, 0)) })

    local function apply(value, fireCallback)
        state = value
        tween(switchBg, EASE, { BackgroundColor3 = state and Theme.Accent or Theme.SurfaceLight })
        tween(knob, EASE, { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) })
        if fireCallback and options.Callback then task.spawn(options.Callback, state) end
    end

    self._window:_track(switchBg.MouseButton1Click:Connect(function() apply(not state, true) end))

    return {
        Set = function(_, value) apply(value, false) end,
        Get = function() return state end,
    }
end

function Section:AddSlider(options)
    options = options or {}
    local min, max = options.Min or 0, options.Max or 100
    local value = math.clamp(options.Default or min, min, max)

    local function label(v) return string.format("%s: %d", options.Text or "Slider", v) end

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = self.Frame })
    local labelText = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Text = label(value),
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })

    local track = new("Frame", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 6), Parent = holder,
    }, { corner(UDim.new(1, 0)) })

    local fill = new("Frame", {
        BackgroundColor3 = Theme.Accent, Size = UDim2.new((value - min) / (max - min), 0, 1, 0), Parent = track,
    }, { corner(UDim.new(1, 0)) })

    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12), ZIndex = 2, Parent = track,
    }, { corner(UDim.new(1, 0)) })

    local function setFromRelative(relative, fireCallback)
        relative = math.clamp(relative, 0, 1)
        value = math.floor(min + (max - min) * relative + 0.5)
        local snapRelative = (value - min) / (max - min)
        tween(fill, TweenInfo.new(0.08), { Size = UDim2.new(snapRelative, 0, 1, 0) })
        tween(knob, TweenInfo.new(0.08), { Position = UDim2.new(snapRelative, 0, 0.5, 0) })
        labelText.Text = label(value)
        if fireCallback and options.Callback then task.spawn(options.Callback, value) end
    end

    local dragging = false
    self._window:_track(track.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        setFromRelative((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)
    end))
    self._window:_track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    self._window:_track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        setFromRelative((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)
    end))

    return {
        Set = function(_, v) setFromRelative((math.clamp(v, min, max) - min) / (max - min), false) end,
        Get = function() return value end,
    }
end

function Section:AddTextBox(options)
    options = options or {}
    local box = new("TextBox", {
        BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 34),
        Text = options.Default or "", PlaceholderText = options.Placeholder or "Enter text...",
        PlaceholderColor3 = Theme.SubText, Font = Theme.Font, TextSize = 13,
        TextColor3 = Theme.Text, ClearTextOnFocus = false, Parent = self.Frame,
    }, { corner(UDim.new(0, 6)), stroke(), padding(8) })

    self._window:_track(box.FocusLost:Connect(function(enterPressed)
        if options.Callback then task.spawn(options.Callback, box.Text, enterPressed) end
    end))

    return box
end

function Section:AddDropdown(options)
    options = options or {}
    local items = options.Items or {}
    local selected = options.Default or items[1]

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = self.Frame })

    local main = new("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 34),
        Text = "", AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(0, 6)), stroke() })

    local prefix = options.Text and (options.Text .. ": ") or ""
    local valueLabel = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -30, 1, 0),
        Text = prefix .. tostring(selected or "—"), Font = Theme.Font, TextSize = 13,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = main,
    })

    local arrow = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.new(0, 20, 1, 0),
        Text = "▾", Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.SubText, Parent = main,
    })

    local list = new("Frame", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(0, 0, 1, 6),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 5, Parent = main,
    }, {
        corner(UDim.new(0, 6)), stroke(), padding(4),
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
    })

    local open = false
    local function toggleList()
        open = not open
        list.Visible = open
        tween(arrow, EASE, { Rotation = open and 180 or 0 })
    end

    for _, item in ipairs(items) do
        local opt = new("TextButton", {
            BackgroundColor3 = Theme.SurfaceLight, Size = UDim2.new(1, 0, 0, 28),
            Text = tostring(item), Font = Theme.Font, TextSize = 13,
            TextColor3 = Theme.Text, AutoButtonColor = false, ZIndex = 5, Parent = list,
        }, { corner(UDim.new(0, 4)) })

        self._window:_track(opt.MouseEnter:Connect(function() tween(opt, EASE, { BackgroundColor3 = Theme.Accent }) end))
        self._window:_track(opt.MouseLeave:Connect(function() tween(opt, EASE, { BackgroundColor3 = Theme.SurfaceLight }) end))
        self._window:_track(opt.MouseButton1Click:Connect(function()
            selected = item
            valueLabel.Text = prefix .. tostring(item)
            toggleList()
            if options.Callback then task.spawn(options.Callback, item) end
        end))
    end

    self._window:_track(main.MouseButton1Click:Connect(toggleList))

    return { Get = function() return selected end }
end

function Section:AddKeybind(options)
    options = options or {}
    local currentKey = options.Default or Enum.KeyCode.Unknown
    local listening = false

    local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Parent = self.Frame })

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Text = options.Text or "Keybind",
        Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })

    local keyBtn = new("TextButton", {
        BackgroundColor3 = Theme.SurfaceLight, Position = UDim2.new(1, -80, 0.5, -14),
        Size = UDim2.new(0, 80, 0, 28), Text = currentKey.Name, Font = Theme.Font, TextSize = 12,
        TextColor3 = Theme.SubText, AutoButtonColor = false, Parent = holder,
    }, { corner(UDim.new(0, 6)), stroke() })

    self._window:_track(keyBtn.MouseButton1Click:Connect(function()
        listening = true
        keyBtn.Text = "..."
        tween(keyBtn, EASE, { BackgroundColor3 = Theme.Accent })
    end))

    self._window:_track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if listening then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            currentKey = input.KeyCode
            keyBtn.Text = currentKey.Name
            listening = false
            tween(keyBtn, EASE, { BackgroundColor3 = Theme.SurfaceLight })
            if options.Callback then task.spawn(options.Callback, currentKey) end
        elseif not gameProcessed and input.KeyCode == currentKey and options.OnPress then
            task.spawn(options.OnPress)
        end
    end))

    return { Get = function() return currentKey end }
end

return BlvckUI
