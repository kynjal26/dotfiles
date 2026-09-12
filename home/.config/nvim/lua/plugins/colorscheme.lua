return {
  {
    'loctvl842/monokai-pro.nvim',
    lazy = false,
    priority = 1000,
    name = 'monokai-pro',
    config = function()
      require('monokai-pro').setup({
        filter = 'pro', -- classic | octagon | pro | machine | ristretto | spectrum
        transparent_background = vim.uv.os_uname().sysname == 'Darwin'
          or string.find(vim.uv.os_uname().sysname, 'Windows') ~= nil
          or string.find(vim.uv.os_uname().release, 'WSL') ~= nil,
        styles = {
          comment = { italic = false },
          keyword = { italic = false },
          type = { italic = false },
          storageclass = { italic = false },
          structure = { italic = false },
          parameter = { italic = false },
          annotation = { italic = false },
          tag_attribute = { italic = false },
        },
      })

      vim.cmd('colorscheme monokai-pro')

      -- Make the dimmed directory path in the Snacks picker readable
      vim.api.nvim_set_hl(0, 'SnacksPickerDir', { fg = '#939293' })
    end,
  },
}
