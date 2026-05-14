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

-- Telescope
map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Recent files" })

-- Show keymaps
map("n", "<leader>?", "<cmd>WhichKey<CR>", { desc = "Show keymaps" })

-- Close current buffer without closing window
map("n", "<leader>x", "<cmd>bp|bd #<CR>", { desc = "Close buffer" })

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
map("n", "gr", vim.lsp.buf.references, { desc = "Go to references" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show diagnostic" })
