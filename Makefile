SCRIPT_NAME=mpv_sort_script
CONCAT_FILE=concat.json
CONCAT_TOOL=./libs/concat_tool.py

SRC=$(wildcard libs/*.lua) $(wildcard src/*.lua)

.PHONY: release watch clean

$(SCRIPT_NAME).lua: $(CONCAT_FILE) $(SRC)
	$(CONCAT_TOOL) -r "$<" -o "$@"

$(SCRIPT_NAME).conf: $(SCRIPT_NAME).lua
	mpv av://lavfi:anullsrc --end 0 --msg-level cplayer=fatal --quiet --no-config --script "$<" --script-opts $(SCRIPT_NAME)-example-config="$@"

release: $(SCRIPT_NAME).lua $(SCRIPT_NAME).conf

watch: $(CONCAT_FILE)
	-$(CONCAT_TOOL) -w $<

clean:
	-rm $(SCRIPT_NAME).lua $(SCRIPT_NAME).conf
