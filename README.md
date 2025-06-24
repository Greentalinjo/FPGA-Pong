# 🎮 FPGA Pong

This project implements the classic game of Pong that I wrote to learn RTL design and SystemVerilog.

Main features:
* 🖥️ VGA output controller.
* 🕹️ Button debouncer.
* 🏓 Paddle and ball logic.
* 💥 Collision detection.
* ⏰ Multiple clock domains.
* 🌉 Safe clock domain crossing logic.

## ⚙️ Logic architecture

The following diagram illustrates the core architecture of the system:

![Logic Architecture](./images/PongGame.jpg)

### ⏰ Clock generator module

The clock generator module provides two clock outputs required by the game control and display drivers.  
It uses the FPGA’s internal high-frequency oscillator to generate a 48 MHz clock, which is then refined through a Phase-Locked Loop (PLL) to produce the 25.125 MHz clock required to run the VGA display.  
Simultaneously, it uses the internal low-frequency oscillator to generate a 10 kHz clock required to run the game control module.

### 🕹️ Button debouncer

The button debouncer module filters out mechanical bounce from a noisy button input.  
It uses a parameterized debounce interval (in clock cycles) and a simple state machine that toggles state only after the input has been stable for the specified time. The output (debounced_button) reflects a clean, stable button press signal, eliminating false triggers caused by contact bounce.

### 🏓 Paddle module

The paddle module manages up/down button inputs to generate position changes.  
It uses two instances of the **button debouncer** to filter noisy button signals, then accumulates the debounced inputs over a configurable interval. After this interval, it outputs a position change signal (-1, 0, or 1) based on the net button presses, providing rate-limited paddle movement.

### 🎲 Game control module

The game controller module implements the core game logic.  
It manages two paddles and a ball on a 2D playing field, updating their positions based on debounced button inputs and game physics. The paddles move up or down using the **paddle** modules, while the ball moves autonomously, bouncing off the top and bottom edges and reflecting when hitting paddles. The module also handles scoring by resetting the ball position if it passes a paddle. All movements and timing are controlled via configurable parameters to adjust responsiveness and screen dimensions.
