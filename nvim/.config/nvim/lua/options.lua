local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

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

-- Restore cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
			vim.api.nvim_win_set_cursor(0, mark)
		end
	end,
})
