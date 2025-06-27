# Project configuration
TOP = pong_game_top
DEVICE = up5k
PACKAGE = sg48

# Verilog source files
VERILOG_SOURCES = \
    src/module_domain_constant_handshake.sv \
    src/module_game_clock_generator.sv \
    src/module_button_debouncer_single_state.sv \
    src/module_game_controller.sv \
    src/module_graphics_driver.sv \
    src/module_paddle.sv \
    src/pong_game_top.sv

# Constraint file
PCF_FILE = constraints.pcf

# Output build directory and files
BUILD_DIR = build
JSON_FILE = $(BUILD_DIR)/$(TOP).json
ASC_FILE  = $(BUILD_DIR)/$(TOP).asc
BIN_FILE  = $(BUILD_DIR)/$(TOP).bin

# Toolchain
YOSYS = yosys
NEXTPNR = nextpnr-ice40
ICEPACK = icepack
ICEPROG = iceprog

# Default target
all: $(BIN_FILE)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Synthesis
$(JSON_FILE): $(VERILOG_SOURCES) | $(BUILD_DIR)
	$(YOSYS) -p "synth_ice40 -top $(TOP) -json $(JSON_FILE)" $(VERILOG_SOURCES)

# Place & route
$(ASC_FILE): $(JSON_FILE) $(PCF_FILE)
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --pcf $(PCF_FILE) --json $(JSON_FILE) --asc $(ASC_FILE) --seed 1796611893

# Bitstream generation
$(BIN_FILE): $(ASC_FILE)
	$(ICEPACK) $(ASC_FILE) $(BIN_FILE)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
