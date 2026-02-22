# BetterDente

BetterDente is a powerful and intelligent battery management utility for macOS, designed to prolong your MacBook's battery lifespan by giving you granular control over charging behavior.

> [!WARNING]
> **BETA SOFTWARE**: BetterDente is currently in Beta.
> **USE AT YOUR OWN RISK**: The developer is not responsible for any damage to your hardware, data loss, or "bricking" of your device. By installing and using this software, you acknowledge and accept all risks associated with modifying system-level power management behavior.

## Core Features

### ⚡ Smart Charge Limiting
Set a custom charge limit (e.g., 80%) to prevent your battery from staying at high voltage levels for extended periods. This is the most effective way to slow down chemical aging of Lithium-ion batteries.

### ⛵ Sailing Mode
Avoid "micro-charging" cycles. Sailing Mode allows the battery to naturally discharge by a set percentage (e.g., 5%) before the charger kicks back in, keeping the battery in a healthy state of activity.

### 🌡️ Heat Protection
Heat is the enemy of battery health. BetterDente monitors your battery temperature in real-time and will automatically pause charging if it exceeds your defined threshold (e.g., 35°C), allowing it to cool down safely.

### 📊 Power Insights Dashboard
Get deep visibility into your Mac's power system:
- **Live Charts**: Real-time tracking of battery level, temperature, and wattage.
- **Power Flow**: See exactly how much power is going to the battery vs. the system.
- **Battery Specs**: View raw capacity, voltage, amperage, and cycle counts.
- **App Energy Usage**: Identify which apps are currently draining the most power.

### 🔄 Automated Calibration
Batteries need occasional "exercise" to keep the internal sensor accurate. The automated calibration tool handles the full cycle (Charge to 100% -> Discharge to 15% -> Recharge to 100%) for you.

### 🚀 Smart App Exceptions
Working on a heavy project in Xcode or Final Cut Pro? Add them to the exception list. BetterDente will automatically disable the limit and top up your battery to 100% whenever these apps are active for maximum performance.

### 😴 Sleep Management
Prevent your Mac from bypassing the charge limit while asleep. BetterDente can automatically stop charging right before sleep and prevent the system from idling until your target charge is reached.

### 🛠️ Advanced Tools
- **Hardware-Level Accuracy**: Toggle between macOS's rounded percentage and the raw hardware capacity.
- **Menu Bar Customization**: Choose what to display in your menu bar (Wattage, Temp, Percentage, or just the Icon).
- **Manual SMC Control**: Direct buttons to enable/disable charging if needed for debugging.

## Installation

1. Download the latest `.dmg` from the Releases page.
2. Drag `BetterDente.app` to your Applications folder.
3. Launch the app and follow the prompts to install the required Helper Tool (Safe to run, requires Root permissions for SMC access).

---

© 2026 Kathan Desai. Built with care for MacBook longevity.
