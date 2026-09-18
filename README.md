<div align="center">

# 🚀 Ansuel Custom GUI for Technicolor Gateways

[![Donate Ko-fi](https://img.shields.io/badge/Donate-Ko--fi-ff5e5b.svg)](https://ko-fi.com/nobodysan)
[![License](https://img.shields.io/github/license/NobodySan97/tch-nginx-gui.svg?style=flat)](https://github.com/NobodySan97/tch-nginx-gui/blob/master/LICENSE)
[![Build Status](https://github.com/NobodySan97/tch-nginx-gui/actions/workflows/autobuild.yml/badge.svg)](https://github.com/NobodySan97/tch-nginx-gui/actions)
[![Release](https://img.shields.io/github/v/release/NobodySan97/tch-nginx-gui?label=Release)](https://github.com/NobodySan97/tch-nginx-gui/releases)
[![Downloads](https://img.shields.io/github/downloads/NobodySan97/tch-nginx-gui/total.svg)](https://github.com/NobodySan97/tch-nginx-gui/releases)

<p align="center">
  <b>A highly modified, universal, and modern web interface for Technicolor Homeware / OpenWrt gateways.</b>
</p>

</div>

---

> [!NOTE]
> ### 🤖 AI-Assisted Development & Maintenance / Sviluppo Assistito da IA
> 
> **EN:** This repository and its ongoing maintenance, modern refactoring, bug fixes, automated build pipelines, and performance enhancements are actively developed with the assistance of advanced **AI coding agents** (pair programming), coupled with strict code auditing and live testing on physical Technicolor hardware.
> 
> **IT:** Questo repository e la sua continua manutenzione, i refactoring del codice, la correzione dei bug, le pipeline di build automatizzate e le ottimizzazioni delle prestazioni sono sviluppati attivamente con l'ausilio di **agenti di Intelligenza Artificiale avanzata (AI pair programming)**, affiancati da revisione del codice e test diretti su modem/router fisici Technicolor.

---

> [!CAUTION]
> ### ⚠️ Disclaimer / Limitazione di Responsabilità
> 
> **EN:** This software and modification package is provided **"AS IS"**, without any express or implied warranty of any kind. Modifying your router firmware and installing custom web interfaces involves inherent risks. **The author(s) and maintainer(s) assume NO responsibility or liability** for any hardware brick, bootloop, malfunction, data loss, loss of network connectivity, voided ISP warranties, or any other direct/indirect damage resulting from the installation, execution, or misuse of this project. **Proceed entirely at your own risk.**
> 
> **IT:** Questo software e pacchetto di modifica viene fornito **"COSÌ COM'È"**, senza alcuna garanzia espressa o implicita. La modifica del firmware del modem/router e l'installazione di interfacce personalizzate comporta rischi tecnici intrinseci. **L'autore e i manutentori non si assumono ALCUNA responsabilità** per eventuali brick permanenti, bootloop, malfunzionamenti hardware, perdita di dati, interruzioni di servizio, decadimento della garanzia dell'operatore o qualsiasi altro danno diretto o indiretto derivante dall'uso, installazione o configurazione di questo progetto. **Procedi esclusivamente a tuo rischio e pericolo.**

---

## 📡 Supported Devices

This GUI is designed and tested for all Technicolor Homeware-based gateways, including but not limited to:

* **DGA4132** (TIM HUB / VBNT-S)
* **DGA4131** (Fastweb FastGate / VBNT-O)
* **DGA4130** (Smart Modem Plus / VBNT-K)
* **TG589vac** (VANT-E)
* **TG788vn v2** (VDNT-W)
* **TG789vac v2 HP** (VBNT-L)
* **TG789vac v2** (VANT-6)
* **TG789vac v1** (VANT-D)
* **TG789vac XTREAM 35B** (VBNT-F)
* **TG799vac** (VANT-F)
* **TG799vac XTREAM** (VBNT-H)
* **TG800vac** (VANT-Y)

---

## ✨ Features & Enhancements

* 📊 **Quick Glance Statistics Dashboard**: Real-time traffic, DSL sync, Wi-Fi clients, and CPU/RAM load.
* ⚡ **High-Performance Architecture**: Zero-Fork native `/proc` calculation for CPU and memory usage.
* ⏸️ **Smart Background Polling**: Automatic pause of AJAX polling via HTML5 Page Visibility API when the browser tab is in background.
* 🔑 **VoIP & SIP Password Viewer**: View VoIP credentials and SIP parameters directly from the web interface.
* 🔄 **Firmware & GUI Manager**: Upgrade, downgrade, or switch update channels (Stable / Preview / Dev) directly from the GUI.
* 💾 **Backup & Restore**: Export and restore full modem configuration and bank switching.
* 🌿 **ECO Energy Modes**: Control CPU scaling, Wi-Fi radio power, and schedule LED night shutdown.
* 🌉 **Bridge & Voice Mode**: 1-Click setup for Bridge Mode, IP Passthrough, or ATA Voice Mode with safe revert.
* 📈 **Interactive Traffic Charts**: Real-time per-device bandwidth tracking powered by Flot / Chart.js.
* 🛡️ **DoS & Fast Cache Protections**: Built-in firewall rules, SYN flood mitigation, and DNS caching options.
* 📶 **Advanced xDSL Diagnostics**: Detailed SNR margin graphs, bit loading, error counters (FEC/CRC), and driver selector.
* 🎨 **Multiple Themes & Skins**: TIM, Vodafone, Fritz!Box, Fastweb, Dark Mode, and Custom styles.
* 🧩 **Integrated App Store**: One-click install for LuCI, Transmission, Aria2, Amule, AdBlock DNS sinkhole, and more.

---

## 📦 Installation Guide

### 1. Root Access
Before installing the GUI, your modem must be unlocked with **root access** (SSH / Telnet).  
Dedicated step-by-step guides and unlock procedures for each model:

* **DGA4130 TIM**: [IlPuntoTecnico Topic #77325](https://www.ilpuntotecnico.com/forum/index.php/topic,77325.html)
* **DGA4132 TIM**: [IlPuntoTecnico Topic #78162](https://www.ilpuntotecnico.com/forum/index.php/topic,78162.html)
* **TG789vac v2 TIM**: [IlPuntoTecnico Topic #77981](https://www.ilpuntotecnico.com/forum/index.php/topic,77981.0.html)
* **TG789vac v2 Tiscali**: [IlPuntoTecnico Topic #77988](https://www.ilpuntotecnico.com/forum/index.php/topic,77988.html)
* **TG789vac v1/2/3, TG799vac, TG800vac & TG797n v3 (Any ISP)**: [Hack Technicolor Documentation](https://hack-technicolor.rtfd.io)
* **Official Community GUI Thread**: [IlPuntoTecnico Topic #81461](https://www.ilpuntotecnico.com/forum/index.php/topic,81461.0.html) *(Note: To post on the forum, please introduce yourself in the presentation section after registering).*

---

### 2. Fast Online Installation (via SSH)

Connect via SSH to your gateway (`root@192.168.1.1` or your configured IP) and run:

```sh
curl -k https://raw.githubusercontent.com/NobodySan97/gui-dev-build-auto/master/GUI.tar.bz2 --output /tmp/GUI.tar.bz2
bzcat /tmp/GUI.tar.bz2 | tar -C / -xvf -
/etc/init.d/rootdevice force
```

> [!TIP]
> **Offline Installation**: If your gateway doesn't have an active internet connection, download `GUI.tar.bz2` from the [gui-dev-build-auto repository](https://github.com/NobodySan97/gui-dev-build-auto), transfer it to `/tmp/` on the router via SCP/SFTP, and run:
> ```sh
> bzcat /tmp/GUI.tar.bz2 | tar -C / -xvf -
> /etc/init.d/rootdevice force
> ```

---

## 📸 Screenshots

<div align="center">
  <h3>System Statistics</h3>
  <img src="https://i.ibb.co/XjhF629/modemstats.jpg" alt="Modem Stats" width="85%">
  <br><br>
  <h3>Cards Overview</h3>
  <img src="https://i.ibb.co/5BDrRnx/odemcards.jpg" alt="Modem Cards" width="85%">
</div>

---

## 🐛 Bug Reporting & Feedback

If you encounter an issue or have suggestions:
1. Open an issue on GitHub with details, screenshots, and logs (`logread`).
2. Redact sensitive information (Public IP, MAC addresses, WiFi passwords) before sharing logs.
3. Join the community discussions on [IlPuntoTecnico Forum](https://www.ilpuntotecnico.com/forum).

---

## 💖 Support & Donations

If you appreciate the work on this project and want to support its ongoing development and maintenance:

<div align="center">

[![Support on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/nobodysan)

</div>
