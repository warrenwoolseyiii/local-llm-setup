# 🚀 Installing CodeGraph CLI

CodeGraph provides command-line tools to analyze codebases. Follow the instructions below based on your operating system to get started.

## 🛠️ Installation Guide

### **💻 macOS / Linux (Bash/Zsh)**
Open your terminal and run the following command to download and execute the official installer script:

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
```

### **💻 Windows (PowerShell)**
Open PowerShell (recommended) and run the following command to download and execute the installer script:

```powershell
irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex
```

---

## 🌐 Adding CodeGraph to Your System PATH

After installation, you may need to explicitly add the directory where `codegraph` was installed to your system's `$PATH` variable so that the shell can find the command globally.

### **🐧 Linux / macOS**

For Unix-like systems, editing the shell profile file is necessary for a permanent update. The installer might handle this automatically, but if the `codegraph` command isn't recognized, follow these steps:

1.  **Identify Shell:** Determine if you use Zsh (`~/.zshrc`) or Bash (`~/.bash_profile`).
2.  **Edit Profile File:** Open your respective configuration file using a text editor (like `nano`).
    *   For **Zsh**: `nano ~/.zshrc`
    *   For **Bash**: `nano ~/.bash_profile`
3.  **Add Export Command:** Add the following line to the end of the file, ensuring you use the correct directory path where CodeGraph was installed:

    ```bash
    export PATH="$HOME/.local/bin:$PATH"
    ```
4.  **Apply Changes:** Save and close the file, then run `source ~/.zshrc` (or `source ~/.bash_profile`) to make the change active immediately.

### **🪟 Windows (PowerShell)**

For a permanent update on Windows, you should add the directory path to your System Environment Variables.

1.  **Search:** Type "Environment Variables" in the Windows Start Menu search bar and select **"Edit the system environment variables."**
2.  **Open Variables:** Click the **"Environment Variables..."** button.
3.  **Edit Path:** Under either User variables or System variables, find the `Path` variable and click **"Edit."**
4.  **Add New Entry:** Click "New" and paste the directory path where CodeGraph was installed (e.g., `C:\Users\YourUser\AppData\Local\codegraph\current\bin`).
5.  **Confirm:** Click OK on all open windows to save the changes. You may need to restart your terminal or PowerShell window for the change to take effect.