OUTDIR = out/
APP = $(OUTDIR)/Akaza.app
INSTALL_DIR = $(HOME)/Library/Input Methods

.PHONY: all build install clean

all: build

build:
	swift build -c release

install: build
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	rm -rf "$(INSTALL_DIR)/Akaza.app"
	cp Info.plist $(APP)/Contents/
	cp .build/release/AkazaIME $(APP)/Contents/MacOS/
	cp -r resources/* $(APP)/Contents/Resources/
	cp -a $(APP) "$(INSTALL_DIR)/"

clean:
	rm -rf .build/ $(OUTDIR)/
