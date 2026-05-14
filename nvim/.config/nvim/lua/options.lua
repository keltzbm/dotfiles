local opt = vim.opt

-- Line numbers
opt.number = true

-- Tabs
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true

-- Indentation
opt.autoindent = true
opt.smartindent = true

-- Clipboard
opt.clipboard = "unnamedplus"

-- Colors
opt.termguicolors = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true

-- Feel
opt.scrolloff = 8
opt.wrap = false
opt.cursorline = true
opt.signcolumn = "yes"

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Files
opt.swapfile = false
opt.undofile = true

-- Whitespace characters
opt.listchars = {
	tab = "→ ",
	trail = "·",
	extends = "›",
	precedes = "‹",
	space = "·",
}
