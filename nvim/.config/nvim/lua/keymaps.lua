local map = vim.keymap.set

-- Leader key
vim.g.mapleader = " "

-- Exit insert mode
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Save (space w) and quit (space q)
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

-- Window navigation (Ctrl + h/j/k/l)
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })

-- Split vertical (space sv) and horizontal (space sh)
map("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>sh", "<cmd>split<CR>", { desc = "Split horizontal" })

-- Stay in indent mode
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Format file manually (not <leader>f: that's the start of ff/fg/fb/fr)
map("n", "<leader>cf", function()
	require("conform").format()
end, { desc = "Format file" })

-- Toggle whitespace visibility
map("n", "<leader>tw", "<cmd>set list!<CR>", { desc = "Toggle whitespace" })

-- Toggle file explorer
map("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "Toggle file explorer" })

-- Normalize spacing around = , and : in the selected lines. They leave
-- compound operators (== <= += != := =>), ::, URLs, 12:30 and anything at the
-- end of a line (no trailing space) alone.
map("v", "<leader>=", [[:s/\v\s*([-+*/%<>!=:&|^~.])@<!\=(\=|\>)@!\s*(\S)@=/ = /ge<CR>]], { desc = "Normalize = spacing" })
map("v", "<leader>:", [[:s/\v\s*(:|\d)@<!:(:|\=|\/)@!\s*(\S)@=/: /ge<CR>]], { desc = "Normalize : spacing" })
map("v", "<leader>,", [[:s/\v\s*,\s*(\S)@=/, /ge<CR>]], { desc = "Normalize , spacing" })

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Recent files" })

-- Show keymaps
map("n", "<leader>?", "<cmd>WhichKey<CR>", { desc = "Show keymaps" })

-- Close current buffer without closing window
map("n", "<leader>x", "<cmd>bp|bd #<CR>", { desc = "Close buffer" })

-- LSP. Neovim already maps grr (references), grn (rename), gra (code action),
-- gri (implementation), grt (type definition), K (hover), [d / ]d
-- (diagnostics) and insert-mode <C-s> (signature help).
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic" })

-- Signature help in normal mode too: what arguments does this function take?
map("n", "<C-s>", vim.lsp.buf.signature_help, { desc = "Signature help" })

-- Completion: silence the as-you-type menu in this buffer (<C-Space> still works)
map("n", "<leader>ta", function()
	local cmp = require("cmp")
	local on = vim.b.cmp_autocomplete ~= false
	cmp.setup.buffer({
		completion = {
			autocomplete = (not on) and { cmp.TriggerEvent.TextChanged } or false,
		},
	})
	vim.b.cmp_autocomplete = not on
	print("autocomplete " .. (on and "off" or "on") .. " (buffer)")
end, { desc = "Toggle autocomplete in buffer" })

-- Move end of line comments above for selected lines
map("v", "<leader>cl", function()
	local start_row = vim.fn.getpos("v")[2]
	local end_row = vim.fn.getpos(".")[2]

	if start_row > end_row then
		start_row, end_row = end_row, start_row
	end

	local patterns = {
		"^(.-)%s*%-%-(.*)$",
		"^(.-)%s*#(.*)$",
		"^(.-)%s*//(.*)$",
	}

	local new_lines = {}
	for row = start_row, end_row do
		local result = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
		local line = result[1]
		if line then
			local indent = line:match("^(%s*)")
			local matched = false
			for _, pattern in ipairs(patterns) do
				local code, comment = line:match(pattern)
				if code and comment and code ~= "" then
					table.insert(new_lines, indent .. vim.bo.commentstring:format(comment))
					table.insert(new_lines, code)
					matched = true
					break
				end
			end
			if not matched then
				table.insert(new_lines, line)
			end
		end
	end

	vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, new_lines)
end, { desc = "Move comments above lines" })

-- Markdown
map("n", "<leader>mp", "<cmd>PeekOpen<CR>", { desc = "Open markdown preview" })

-- Toggle 80 column ruler
map("n", "<leader>tc", function()
	if vim.o.colorcolumn == "" then
		vim.o.colorcolumn = "80"
	else
		vim.o.colorcolumn = ""
	end
end, { desc = "Toggle column ruler" })

-- Run the current file in a terminal split (<leader>rr below, <leader>rv beside)
local runners = {
	python = "python3 %s",
	sh = "bash %s",
	bash = "bash %s",
	javascript = "node %s",
	go = "go run %s",
	rust = "cargo run",
}

local function run_file(split)
	local runner = runners[vim.bo.filetype]
	if not runner then
		print("No runner configured for " .. vim.bo.filetype)
		return
	end
	local cmd = runner:format(vim.fn.shellescape(vim.fn.expand("%")))
	vim.cmd(split .. " | terminal " .. cmd)
end

map("n", "<leader>rr", function()
	run_file("split")
end, { desc = "Run current file (horizontal)" })
map("n", "<leader>rv", function()
	run_file("vsplit")
end, { desc = "Run current file (vertical)" })

-- Remove trailing whitespace
map("n", "<leader>cw", "<cmd>%s/\\s\\+$//e<CR>", { desc = "Remove trailing whitespace" })
