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

-- Format file manually
map("n", "<leader>f", function()
	require("conform").format()
end, { desc = "Format file" })

-- Toggle whitespace visibility
map("n", "<leader>tw", "<cmd>set list!<CR>", { desc = "Toggle whitespace" })

-- Toggle file explorer
map("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "Toggle file explorer" })

-- Normalize spacing around = signs
map("v", "<leader>=", [[:s/\v\s*\=\s*/\ \=\ /g<CR>]], { desc = "Normalize = spacing" })
