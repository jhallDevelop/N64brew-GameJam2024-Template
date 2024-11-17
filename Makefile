ROMNAME = gamejam2024
ROMTITLE = "N64BREW GAMEJAM 2024"

# Directories
BUILD_DIR = build
ASSETS_DIR = assets
FILESYSTEM_DIR = filesystem
MINIGAME_DIR = code
MINIGAMEDSO_DIR = $(FILESYSTEM_DIR)/minigames
AF_LIB_DIR = $(N64_INST)/AF_Lib/include
AF_MATH_DIR = $(N64_INST)/AF_Math/include
LIBDRAGON_DIR = $(N64_INST)/libdragon/include
UNFLOADER_DIR = $(N64_INST)/UNFLoader
T3D_DIR = $(N64_INST)/t3d

# External Libraries
CFLAGS += -I$(LIBDRAGON_DIR)
CFLAGS += -I$(AF_LIB_DIR)
CFLAGS += -I$(AF_MATH_DIR)
CFLAGS += -I$(UNFLOADER_DIR)
CFLAGS += -I$(T3D_DIR)

# Debug Files
DEBUGFILES = $(UNFLOADER_DIR)/debug.c $(UNFLOADER_DIR)/usb.c
SRC = main.c core.c minigame.c menu.c $(DEBUGFILES:.c=.o)

# Font Files
$(FILESYSTEM_DIR)/squarewave.font64: MKFONT_FLAGS += --outline 1 --range all

# Include files
include $(N64_INST)/include/n64.mk
include $(T3D_DIR)/t3d.mk

# Minigame files
MINIGAMES_LIST = $(notdir $(wildcard $(MINIGAME_DIR)/*))
DSO_LIST = $(addprefix $(MINIGAMEDSO_DIR)/, $(addsuffix .dso, $(MINIGAMES_LIST)))

IMAGE_LIST = $(wildcard $(ASSETS_DIR)/*.png) $(wildcard $(ASSETS_DIR)/core/*.png)
FONT_LIST  = $(wildcard $(ASSETS_DIR)/*.ttf)
MODEL_LIST  = $(wildcard $(ASSETS_DIR)/*.glb)
SOUND_LIST  = $(wildcard $(ASSETS_DIR)/*.wav) $(wildcard $(ASSETS_DIR)/core/*.wav)
MUSIC_LIST  = $(wildcard $(ASSETS_DIR)/*.xm)
ASSETS_LIST += $(subst $(ASSETS_DIR),$(FILESYSTEM_DIR),$(IMAGE_LIST:%.png=%.sprite))
ASSETS_LIST += $(subst $(ASSETS_DIR),$(FILESYSTEM_DIR),$(FONT_LIST:%.ttf=%.font64))
ASSETS_LIST += $(subst $(ASSETS_DIR),$(FILESYSTEM_DIR),$(MODEL_LIST:%.glb=%.t3dm))
ASSETS_LIST += $(subst $(ASSETS_DIR),$(FILESYSTEM_DIR),$(SOUND_LIST:%.wav=%.wav64))
ASSETS_LIST += $(subst $(ASSETS_DIR),$(FILESYSTEM_DIR),$(MUSIC_LIST:%.xm=%.xm64))

ifeq ($(DEBUG), 1)
	N64_CFLAGS += -g -O0
	N64_LDFLAGS += -g
	N64_CFLAGS += -Wno-unused-variables -Wno-unsued-function
else
	N64_CFLAGS += -O2
endif

all: $(ROMNAME).z64

$(FILESYSTEM_DIR)/%.sprite: $(ASSETS_DIR)/%.png
	@mkdir -p $(dir $@)
	@echo "    [SPRITE] $@"
	$(N64_MKSPRITE) $(MKSPRITE_FLAGS) -o $(dir $@) "$<"

$(FILESYSTEM_DIR)/%.font64: $(ASSETS_DIR)/%.ttf
	@mkdir -p $(dir $@)
	@echo "    [FONT] $@"
	$(N64_MKFONT) $(MKFONT_FLAGS) -o $(dir $@) "$<"

$(FILESYSTEM_DIR)/%.t3dm: $(ASSETS_DIR)/%.glb
	@mkdir -p $(dir $@)
	@echo "    [T3D-MODEL] $@"
	$(T3D_GLTF_TO_3D) $(T3DM_FLAGS) "$<" $@
	$(N64_BINDIR)/mkasset -c 2 -o $(dir $@) $@

$(FILESYSTEM_DIR)/%.wav64: $(ASSETS_DIR)/%.wav
	@mkdir -p $(dir $@)
	@echo "    [SFX] $@"
	$(N64_AUDIOCONV) $(AUDIOCONV_FLAGS) -o $(dir $@) "$<"

$(FILESYSTEM_DIR)/%.xm64: $(ASSETS_DIR)/%.xm
	@mkdir -p $(dir $@)
	@echo "    [XM] $@"
	$(N64_AUDIOCONV) $(AUDIOCONV_FLAGS) -o $(dir $@) "$<"


define MINIGAME_template
SRC_$(1) = \
	$$(wildcard $$(MINIGAME_DIR)/$(1)/*.c) \
	$$(wildcard $$(MINIGAME_DIR)/$(1)/**/*.c) \
	$$(wildcard $$(MINIGAME_DIR)/$(1)/*.cpp) \
	$$(wildcard $$(MINIGAME_DIR)/$(1)/**/*.cpp)
$$(MINIGAMEDSO_DIR)/$(1).dso: $$(SRC_$(1):%.cpp=$$(BUILD_DIR)/%.o)
$$(MINIGAMEDSO_DIR)/$(1).dso: $$(SRC_$(1):%.c=$$(BUILD_DIR)/%.o)

-include $$(MINIGAME_DIR)/$(1)/$(1).mk


endef

$(foreach minigame, $(MINIGAMES_LIST), $(eval $(call MINIGAME_template,$(minigame))))

MAIN_ELF_EXTERNS := $(BUILD_DIR)/$(ROMNAME).externs
$(MAIN_ELF_EXTERNS): $(DSO_LIST)
$(BUILD_DIR)/$(ROMNAME).dfs: $(ASSETS_LIST) $(DSO_LIST)
$(BUILD_DIR)/$(ROMNAME).elf: $(SRC:%.c=$(BUILD_DIR)/%.o) $(MAIN_ELF_EXTERNS)
$(ROMNAME).z64: N64_ROM_TITLE=$(ROMTITLE)
$(ROMNAME).z64: $(BUILD_DIR)/$(ROMNAME).dfs $(BUILD_DIR)/$(ROMNAME).msym

$(BUILD_DIR)/$(ROMNAME).msym: $(BUILD_DIR)/$(ROMNAME).elf

clean:
	rm -rf $(BUILD_DIR) $(FILESYSTEM_DIR) $(DSO_LIST) $(ROMNAME).z64

-include $(wildcard $(BUILD_DIR)/*.d)


.PHONY: all clean
