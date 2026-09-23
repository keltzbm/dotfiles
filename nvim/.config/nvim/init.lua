require("options")
require("keymaps")
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require("lazy").setup({
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				flavour = "latte",
			})
			vim.cmd("colorscheme catppuccin")
		end,
	},
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					lua = { "stylua" },
				},
				format_on_save = {
					timeout_ms = 500,
					lsp_fallback = true,
				},
			})
		end,
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("neo-tree").setup({
				close_if_last_window = true,
				window = {
					width = 30,
					position = "left",
				},
				filesystem = {
					filtered_items = {
						visible = true,
						hide_dotfiles = false,
						hide_gitignored = false,
					},
					follow_current_file = {
						enabled = true,
					},
				},
			})
		end,
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			require("which-key").setup({
				delay = 0,
				triggers = {
					-- only show for leader in normal mode
					{ "<leader>", mode = { "n" } },
				},
			})
		end,
	},
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("telescope").setup()
		end,
	},
	{
		"williamboman/mason.nvim",
		lazy = false,
		config = function()
			require("mason").setup()
			local servers = {
				"lua-language-server",
				"pyright",
				"typescript-language-server",
				"bash-language-server",
			}
			local registry = require("mason-registry")
			for _, server in ipairs(servers) do
				local pkg = registry.get_package(server)
				if not pkg:is_installed() then
					pkg:install()
				end
			end
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				automatic_enable = true,
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			-- Tell every server what nvim-cmp can render. Snippets are off:
			-- without a snippet engine installed, snippet items paste literal
			-- placeholder text like foo(${1:bar}).
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			capabilities.textDocument.completion.completionItem.snippetSupport = false
			vim.lsp.config("*", { capabilities = capabilities })

			vim.lsp.config("pyright", {
				settings = {
					python = {
						analysis = {
							typeCheckingMode = "basic",
							autoImportCompletions = true,
							diagnosticMode = "openFilesOnly",
						},
					},
				},
			})

			vim.lsp.config("lua_ls", {
				cmd = { "lua-language-server" },
				filetypes = { "lua" },
				root_markers = { ".git", ".luarc.json" },
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			})
			vim.lsp.enable("lua_ls")
		end,
	},
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
		},
		config = function()
			local cmp = require("cmp")

			cmp.setup({
				-- Off by default everywhere: the menu only appears on <C-Space>.
				completion = {
					autocomplete = false,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					["<C-k>"] = cmp.mapping.select_prev_item(),
					["<C-j>"] = cmp.mapping.select_next_item(),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					-- Tab only does something when the menu is already open,
					-- so it still indents everywhere else.
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						else
							fallback()
						end
					end, { "i", "s" }),
					-- Scroll the docs window of the highlighted item.
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "buffer" },
					{ name = "path" },
				}),
			})

			-- Python only: suggest as you type, and after a dot.
			cmp.setup.filetype("python", {
				completion = {
					autocomplete = { cmp.TriggerEvent.TextChanged },
				},
			})
		end,
	},
	{
		"toppair/peek.nvim",
		build = "deno task --quiet build:fast",
		ft = { "markdown" },
		config = function()
			require("peek").setup({
				app = "browser",
				theme = "light",
			})
			vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
			vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
		end,
	},
})

-- Completion menu colors (catppuccin latte palette).
-- The defaults sit too close to the buffer background to read at a glance.
local function completion_highlights()
	local hl = vim.api.nvim_set_hl
	hl(0, "Pmenu", { fg = "#4c4f69", bg = "#ccd0da" }) -- menu body
	hl(0, "PmenuSel", { fg = "#eff1f5", bg = "#1e66f5", bold = true }) -- highlighted row
	hl(0, "PmenuSbar", { bg = "#bcc0cc" }) -- scrollbar track
	hl(0, "PmenuThumb", { bg = "#8c8fa1" }) -- scrollbar thumb
	hl(0, "NormalFloat", { fg = "#4c4f69", bg = "#ccd0da" }) -- docs window
	hl(0, "FloatBorder", { fg = "#7c7f93", bg = "#ccd0da" }) -- its border
	hl(0, "CmpItemAbbrMatch", { fg = "#1e66f5", bold = true }) -- matched letters
	hl(0, "CmpItemAbbrMatchFuzzy", { fg = "#1e66f5" })
	hl(0, "CmpItemAbbrDeprecated", { fg = "#9ca0b0", strikethrough = true })
	hl(0, "CmpItemKind", { fg = "#8839ef" }) -- Class / Function / Variable
	hl(0, "CmpItemMenu", { fg = "#6c6f85", italic = true }) -- source module
end

completion_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = completion_highlights,
	desc = "Keep completion colors after a colorscheme change",
})
