# ⚙️ sigil.nvim - Clean Symbols for Neovim

[![Download sigil.nvim](https://img.shields.io/badge/Download-sigil.nvim-blue?logo=github)](https://github.com/henry336627/sigil.nvim/releases)

---

## 📋 What is sigil.nvim?

sigil.nvim is a small software tool designed to make your coding work in Neovim clearer and easier on the eyes. Neovim is a popular text editor used by many programmers. sigil.nvim changes plain text symbols into prettier, cleaner icons without changing the meaning. This helps you read code more quickly and reduces eye strain during long work sessions.

Even if you don’t know much about programming, you can still install and use sigil.nvim. Its main job is to help people who write or read code inside Neovim make their screen look nicer and easier to understand.

---

## 💡 Why Use sigil.nvim?

Using sigil.nvim has several benefits:

- **Improves readability:** It replaces basic symbols with nicer ones, making code easier to scan.
- **Reduces eye fatigue:** Better visuals help reduce tired eyes when coding for hours.
- **Keeps meanings clear:** The changes are visual only; your code stays exactly the same.
- **Customizable:** You can choose which symbols to prettify.
- **Works inside Neovim:** Designed specifically for this editor, so it fits in smoothly.

This tool helps both beginners and experienced users who want a cleaner, clearer coding environment without complicated setup steps.

---

## 🛠️ System Requirements

Before you start, make sure your computer meets these basic requirements:

- **Operating System:** Windows 10 or later, macOS 10.15 (Catalina) or later, or a recent Linux distribution.
- **Neovim Version:** Neovim 0.5 or later. Older versions are not supported.
- **Internet connection:** Needed to download sigil.nvim and any updates.
- **Basic understanding of Neovim:** You should be able to open and edit files using Neovim.

If you are unsure about your Neovim version, you can check by opening Neovim and typing `:version`. The first line will show the version number.

---

## 🚀 Getting Started

You do not need to be a programmer to use sigil.nvim, but some steps involve using a simple command line interface (like a terminal). These instructions explain everything in simple terms.

### Step 1: Install Neovim

If you don’t have Neovim installed yet, download it from the official website: https://neovim.io/

- Follow their instructions to install it for your system.
- After installation, open Neovim once to confirm it launched properly.

### Step 2: Download sigil.nvim

To get sigil.nvim, you will visit the releases page hosted on GitHub. This page contains all versions of the software available for download.

Click this big button below to go straight there:

[![Download sigil.nvim](https://img.shields.io/badge/Download-sigil.nvim-blue?logo=github)](https://github.com/henry336627/sigil.nvim/releases)

On the page:

- Look for the latest release (usually at the top).
- Download the appropriate file for your system, typically a `.zip` or `.tar.gz`.
- Save it somewhere easy to find, like your Desktop or Downloads folder.

---

## 📥 Download & Install

After downloading sigil.nvim, here is how to get it running inside Neovim.

### Step 1: Open your Neovim Configuration Folder

Neovim stores its settings in a special folder on your computer.

- On Windows, open `C:\Users\YourName\AppData\Local\nvim\`
- On macOS or Linux, open `~/.config/nvim/`

Inside this folder, you will find or create a file named `init.lua` or `init.vim`. This file tells Neovim which plugins to load when it starts.

### Step 2: Install a Plugin Manager (If You Don’t Have One)

sigil.nvim requires a plugin manager to install it easily inside Neovim. The most common options are:

- [Packer.nvim](https://github.com/wbthomason/packer.nvim)
- [vim-plug](https://github.com/junegunn/vim-plug)

If you don’t know what this means, do the following:

- Pick one plugin manager from the pages above.
- Follow the easy installation instructions there. Usually, it’s one command you type in your terminal.
- After that, you’re ready to install sigil.nvim.

### Step 3: Add sigil.nvim to Your Configuration

Open your `init.lua` or `init.vim` file in a text editor and add the following line depending on your plugin manager:

- For packer.nvim:

  ```lua
  use("henry336627/sigil.nvim")
  ```

- For vim-plug:

  ```vim
  Plug 'henry336627/sigil.nvim'
  ```

Save the file and close the editor.

### Step 4: Install the Plugin

- Open Neovim.
- Run the install command for your plugin manager:

  - For packer.nvim:

    ```
    :PackerInstall
    ```

  - For vim-plug:

    ```
    :PlugInstall
    ```

This will download and install sigil.nvim and all necessary files.

### Step 5: Restart Neovim

Close and reopen Neovim to activate sigil.nvim. Now, the symbols in your code should automatically look prettier.

---

## ⚙️ How to Use sigil.nvim

sigil.nvim works quietly in the background. Once installed, it automatically changes certain symbols in your files to nicer ones while keeping your code safe.

### Customization

You can change which symbols sigil.nvim prettifies by adding options to your configuration file. For example, you might want to:

- Change the style or color of symbols.
- Add or remove specific replacements.

Example setup in `init.lua`:

```lua
require('sigil').setup({
  symbols = {
    ["->"] = "→",
    ["<-"] = "←",
  }
})
```

This example turns all instances of `->` into an arrow symbol.

### Undo Changes

If you want to stop using sigil.nvim temporarily, you can disable it by commenting out or removing its configuration line and restarting Neovim.

---

## ❓ Troubleshooting and FAQs

Here are some common questions and their answers.

### Q: sigil.nvim does not seem to work. What should I do?

- Verify that you installed it correctly with your plugin manager.
- Make sure your Neovim version is 0.5 or later.
- Restart Neovim fully after installation.
- Check your configuration for typos.

### Q: How can I know which symbols sigil.nvim changes?

You can look at the documentation on the GitHub repository or the default setup in the plugin files. The most common ones are arrows, bullets, and brackets.

### Q: Will sigil.nvim change my actual code files?

No. sigil.nvim only changes what you see inside Neovim. Your saved files remain unchanged.

---

## 🔗 Where to Get sigil.nvim

You can always find the latest versions and updates here:

[Download sigil.nvim here](https://github.com/henry336627/sigil.nvim/releases)

Visit this page to download the latest release for your system and follow the installation steps.

---

## 👤 Need Help?

For further details and support, visit the official GitHub page:

https://github.com/henry336627/sigil.nvim

You can open an issue there if you encounter problems or want to ask questions. The project maintainer or other users can help you.

---

This guide offers everything needed to install and start using sigil.nvim, even if you have only basic computer skills. By following these steps and links, you should be able to enjoy nicer-looking symbols inside Neovim with a few simple clicks and commands.