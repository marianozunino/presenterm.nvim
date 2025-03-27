.PHONY: test

test:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory test/ { minimal_init = './scripts/minimal_init.vim' }"
