-- Spinners adapted from: https://github.com/sindresorhus/cli-spinners
--
-- Some designs' names are made more descriptive; differences noted in comments.
-- Other designs are omitted for brevity.
--
-- You may want to adjust spinner_rate according to the number of frames of your
-- chosen spinner.

-- MIT License
--
-- Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
local M = {}

M.check = {
  "✔"
}

M.dots = {
  "⠋",
  "⠙",
  "⠹",
  "⠸",
  "⠼",
  "⠴",
  "⠦",
  "⠧",
  "⠇",
  "⠏",
}

-- Originally called dots2
M.dots_negative = {
  "⣾",
  "⣽",
  "⣻",
  "⢿",
  "⡿",
  "⣟",
  "⣯",
  "⣷",
}

-- Originally called dots3
M.dots_snake = {
  "⠋",
  "⠙",
  "⠚",
  "⠒",
  "⠂",
  "⠂",
  "⠒",
  "⠲",
  "⠴",
  "⠦",
  "⠖",
  "⠒",
  "⠐",
  "⠐",
  "⠒",
  "⠓",
  "⠋",
}

-- Originally called dots10
M.dots_footsteps = {
  "⢄",
  "⢂",
  "⢁",
  "⡁",
  "⡈",
  "⡐",
  "⡠",
}

-- Originally called dots11
M.dots_hop = {
  "⠁",
  "⠂",
  "⠄",
  "⡀",
  "⢀",
  "⠠",
  "⠐",
  "⠈",
}

M.line = {
  "-",
  "\\",
  "|",
  "/",
}

M.pipe = {
  "┤",
  "┘",
  "┴",
  "└",
  "├",
  "┌",
  "┬",
  "┐",
}

-- Originally called simpleDots
M.dots_ellipsis = {
  ".  ",
  ".. ",
  "...",
  "   ",
}

-- Originally called simpleDotsScrolling
M.dots_scrolling = {
  ".  ",
  ".. ",
  "...",
  " ..",
  "  .",
  "   ",
}

M.star = {
  "✶",
  "✸",
  "✹",
  "✺",
  "✹",
  "✷",
}

M.flip = {
  "_",
  "_",
  "_",
  "-",
  "`",
  "`",
  "'",
  "´",
  "-",
  "_",
  "_",
  "_",
}

M.hamburger = {
  "☱",
  "☲",
  "☴",
}

-- Originally called growVertical
M.grow_vertical = {
  "▁",
  "▃",
  "▄",
  "▅",
  "▆",
  "▇",
  "▆",
  "▅",
  "▄",
  "▃",
}

-- Originally called growHorizontal
M.grow_horizontal = {
  "▏",
  "▎",
  "▍",
  "▌",
  "▋",
  "▊",
  "▉",
  "▊",
  "▋",
  "▌",
  "▍",
  "▎",
}

M.noise = {
  "▓",
  "▒",
  "░",
}

-- Originally called bounce
M.dots_bounce = {
  "⠁",
  "⠂",
  "⠄",
  "⠂",
}

M.triangle = {
  "◢",
  "◣",
  "◤",
  "◥",
}

M.arc = {
  "◜",
  "◠",
  "◝",
  "◞",
  "◡",
  "◟",
}

M.circle = {
  "◡",
  "⊙",
  "◠",
}

-- Originally called squareCorners
M.square_corners = {
  "◰",
  "◳",
  "◲",
  "◱",
}

-- Originally called circleQuarters
M.circle_quarters = {
  "◴",
  "◷",
  "◶",
  "◵",
}

-- Originally called circleHalves
M.circle_halves = {
  "◐",
  "◓",
  "◑",
  "◒",
}

-- Originally called toggle
M.dots_toggle = {
  "⊶",
  "⊷",
}

-- Originally called toggle2
M.box_toggle = {
  "▫",
  "▪",
}

M.arrow = {
  "←",
  "↖",
  "↑",
  "↗",
  "→",
  "↘",
  "↓",
  "↙",
}

-- Originally called arrow3
M.zip = {
  "▹▹▹▹▹",
  "▸▹▹▹▹",
  "▹▸▹▹▹",
  "▹▹▸▹▹",
  "▹▹▹▸▹",
  "▹▹▹▹▸",
}

-- Originally called bouncingBar
M.bouncing_bar = {
  "[    ]",
  "[=   ]",
  "[==  ]",
  "[=== ]",
  "[ ===]",
  "[  ==]",
  "[   =]",
  "[    ]",
  "[   =]",
  "[  ==]",
  "[ ===]",
  "[====]",
  "[=== ]",
  "[==  ]",
  "[=   ]",
}

-- Originally called bouncingBall
M.bouncing_ball = {
  "( ●    )",
  "(  ●   )",
  "(   ●  )",
  "(    ● )",
  "(     ●)",
  "(    ● )",
  "(   ●  )",
  "(  ●   )",
  "( ●    )",
  "(●     )",
}

M.clock = {
  "🕛 ",
  "🕐 ",
  "🕑 ",
  "🕒 ",
  "🕓 ",
  "🕔 ",
  "🕕 ",
  "🕖 ",
  "🕗 ",
  "🕘 ",
  "🕙 ",
  "🕚 ",
}

M.earth = {
  "🌍 ",
  "🌎 ",
  "🌏 ",
}

M.moon = {
  "🌑 ",
  "🌒 ",
  "🌓 ",
  "🌔 ",
  "🌕 ",
  "🌖 ",
  "🌗 ",
  "🌘 ",
}

-- Originally called point
M.dots_pulse = {
  "∙∙∙",
  "●∙∙",
  "∙●∙",
  "∙∙●",
  "∙∙∙",
}

-- Originally called aesthetic
M.meter = {
  "▰▱▱▱▱▱▱",
  "▰▰▱▱▱▱▱",
  "▰▰▰▱▱▱▱",
  "▰▰▰▰▱▱▱",
  "▰▰▰▰▰▱▱",
  "▰▰▰▰▰▰▱",
  "▰▰▰▰▰▰▰",
  "▰▱▱▱▱▱▱",
}
return M
