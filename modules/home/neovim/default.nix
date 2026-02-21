{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.neovim;
in
{
  options.${namespace}.neovim = {
    enable = mkEnableOption "Neovim";
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      extraPackages = with pkgs; [
        # Nix
        nil
        nixfmt-rfc-style

        # Lua
        lua-language-server

        # General tools
        ripgrep
        fd
        tree-sitter
      ];

      plugins = with pkgs.vimPlugins; [
        # Theme
        tokyonight-nvim

        # Syntax highlighting
        nvim-treesitter.withAllGrammars

        # File navigation
        telescope-nvim
        plenary-nvim

        # LSP
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path

        # Quality of life
        comment-nvim
        gitsigns-nvim
        lualine-nvim
        nvim-web-devicons
        which-key-nvim
        indent-blankline-nvim
      ];

      extraConfig = ''
        lua << EOF
        -- Leader key
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

        -- Options
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.mouse = "a"
        vim.opt.showmode = false
        vim.opt.clipboard = "unnamedplus"
        vim.opt.breakindent = true
        vim.opt.undofile = true
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        vim.opt.signcolumn = "yes"
        vim.opt.updatetime = 250
        vim.opt.timeoutlen = 300
        vim.opt.splitright = true
        vim.opt.splitbelow = true
        vim.opt.list = true
        vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
        vim.opt.inccommand = "split"
        vim.opt.cursorline = true
        vim.opt.scrolloff = 10
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.expandtab = true
        vim.opt.termguicolors = true

        -- Theme
        vim.cmd.colorscheme("tokyonight-night")

        -- Keymaps
        vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
        vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

        -- Telescope
        local telescope = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", telescope.find_files, { desc = "Find files" })
        vim.keymap.set("n", "<leader>fg", telescope.live_grep, { desc = "Live grep" })
        vim.keymap.set("n", "<leader>fb", telescope.buffers, { desc = "Buffers" })
        vim.keymap.set("n", "<leader>fh", telescope.help_tags, { desc = "Help tags" })
        vim.keymap.set("n", "<leader>/", telescope.current_buffer_fuzzy_find, { desc = "Search in buffer" })

        -- LSP
        local lspconfig = require("lspconfig")
        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        lspconfig.nil_ls.setup({ capabilities = capabilities })
        lspconfig.lua_ls.setup({
          capabilities = capabilities,
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
            },
          },
        })

        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(event)
            local map = function(keys, func, desc)
              vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
            end
            map("gd", telescope.lsp_definitions, "Go to definition")
            map("gr", telescope.lsp_references, "References")
            map("gI", telescope.lsp_implementations, "Implementations")
            map("<leader>D", telescope.lsp_type_definitions, "Type definition")
            map("<leader>ds", telescope.lsp_document_symbols, "Document symbols")
            map("<leader>rn", vim.lsp.buf.rename, "Rename")
            map("<leader>ca", vim.lsp.buf.code_action, "Code action")
            map("K", vim.lsp.buf.hover, "Hover")
          end,
        })

        -- Completion
        local cmp = require("cmp")
        cmp.setup({
          sources = {
            { name = "nvim_lsp" },
            { name = "buffer" },
            { name = "path" },
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-n>"] = cmp.mapping.select_next_item(),
            ["<C-p>"] = cmp.mapping.select_prev_item(),
            ["<C-y>"] = cmp.mapping.confirm({ select = true }),
            ["<C-Space>"] = cmp.mapping.complete(),
          }),
        })

        -- Plugins setup
        require("Comment").setup()
        require("gitsigns").setup()
        require("lualine").setup({ options = { theme = "tokyonight" } })
        require("ibl").setup()
        require("which-key").setup()
        EOF
      '';
    };
  };
}
