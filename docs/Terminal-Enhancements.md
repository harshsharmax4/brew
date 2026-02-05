# Terminal Enhancements with Homebrew

Homebrew can help you install tools that make working in the shell more efficient and pleasant. Below are examples of popular formulas you can use to improve tab completion, file navigation and general usability.

## Enable Homebrew Completions

Run `brew completions link` after installing Homebrew to set up completion files for all installed formulas. Reload your shell or restart your terminal to activate the completions.

## Fuzzy Finding and History Search

- **`fzf`** – General-purpose command-line fuzzy finder. After installation, run `"$(brew --prefix)/opt/fzf/install"` to enable key bindings and shell integration.

```sh
brew install fzf
"$(brew --prefix)/opt/fzf/install"
```

## Shell Suggestions and Syntax Highlighting

- **`zsh-autosuggestions`** – Suggests commands as you type based on history.
- **`zsh-syntax-highlighting`** – Colors commands while you type for visibility.
- **`zsh-autocomplete`** – Offers completion suggestions without delay.
- **`zsh-autopair`** – Automatically inserts matching delimiters.

```sh
brew install zsh-autosuggestions zsh-syntax-highlighting zsh-autocomplete zsh-autopair
```

Add the following lines to your `~/.zshrc` (ensure `eval "$(brew shellenv)"` runs first):

```sh
source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$(brew --prefix)/share/zsh-autopair/autopair.zsh"
source "$(brew --prefix)/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
```

## Mistyped Command Correction

- **`thefuck`** – Corrects previous mistyped commands.

```sh
brew install thefuck
```

Add to `~/.zshrc`:

```sh
eval "$(thefuck --alias)"
```

## File System Navigation

- **`zoxide`** – Smart directory jumper that tracks your most used paths.
- **`nnn`** – Terminal file browser with seamless `cd` integration.

```sh
brew install zoxide nnn
```

Add to `~/.zshrc`:

```sh
source "$(brew --prefix)/share/zoxide/zoxide.zsh"
```

To enable `nnn`'s `cd` function:

```sh
export NNN_PLUG='c:cd -'
```

## Shell Command Explanations

- **`tldr`** – Simplified and community-maintained man pages.
- **`navi`** – Interactive cheat sheet for command examples.

```sh
brew install tldr navi
```

## Python Utilities without Virtual Environments

Use `pipx` to install and isolate individual Python applications such as `shell-gpt`:

```sh
brew install pipx
pipx ensurepath
pipx install shell-gpt
```

This keeps global Python packages manageable without using a full virtual environment.

## Visual Improvements

- **`bat`** – A `cat` clone with syntax highlighting and Git integration.
- **`lsd`** – `ls` with colorized output and icons.

```sh
brew install bat lsd
```

After installing these tools, reload your shell or start a new session to take advantage of the enhancements.

