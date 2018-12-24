# `mpv_sort_script.lua`

## What is it?

`mpv_sort_script.lua` is a script for sorting directory entries by name, age, size or randomly. An entire directory tree can be sorted at once, as well.  
The script hooks file loading to check if the given path is a directory, enumerates the entries and sorts them.  
(The script does *not* allow sorting the playlist during playback, yet!)

## How do I install it?

Grab a release from the [releases page](https://github.com/TheAMM/mpv_sort_script/releases), an automatic build [from here](https://raw.githubusercontent.com/TheAMM/mpv_sort_script/build/mpv_sort_script.lua) or [see below](#development) how to "build" (concatenate) the script yourself.  
Place the `mpv_sort_script.lua` to your mpv's `scripts` directory.

For example:
  * Linux/Unix/Mac: `~/.config/mpv/scripts/mpv_sort_script.lua`
  * Windows: `%APPDATA%\Roaming\mpv\scripts\mpv_sort_script.lua`

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more info.

## How do I use it?

Prepend a directory path with `sort:` (or `rsort:` for recursive sorting), for example:

```shell
$ mpv sort:~/Videos
$ mpv sort:/tmp/files
$ mpv sort:.
$ mpv rsort:~/Videos # recurse into all subdirectories and sort
```
This will sort using the default sort options, see [Configuration](#configuration) below.

Recursive sorting with `rsort:` means the script will find all files in the directory tree (up until `max_recurse_depth`) and sort them all in one go. Otherwise the script will sort each folder separately, when it comes across them.

You may specify the sorting method and order as well:
```shell
$ mpv sort-name:.   # sort by name, using default order (depends on config)
$ mpv sort-size-:.  # sort by size, descending (biggest to smallest)
$ mpv sort-date+:.  # sort by date, ascending (oldest to newest)
$ mpv sort-random:. # sort files randomly
```

## Configuration

Create a file called `mpv_sort_script.conf` inside your mpv's `lua-settings` directory.

For example:
  * Linux/Unix/Mac: `~/.config/mpv/lua-settings/mpv_sort_script.conf`
  * Windows: `%APPDATA%\Roaming\mpv\lua-settings\mpv_sort_script.conf`

See the [Files section](https://mpv.io/manual/master/#files) in mpv's manual for more info.

You can grab an example config [from here](https://raw.githubusercontent.com/TheAMM/mpv_sort_script/build/mpv_sort_script.conf) or use mpv to save an example config:
```shell
$ mpv --idle --script-opts sort-example-config=example.conf
```
The example configuration documents itself, so read that for all the options.

## Development

This project uses git submodules. After cloning (or fetching updates), run `git submodule update --init` to update the `libs` submodule, which contains parts most of my scripts share and use.

Included in the libs directory is `concat_tool.py` I use for automatically concatenating files upon their change, and also mapping changes to the output file back to the source files. It's really handy on stack traces when mpv gives you a line and column on the output file - no need to hunt down the right place in the source files!

The script requires Python 3, so install that. Nothing more, though. Call it with `libs/concat_tool.py concat.json`.

You may also, of course, just `cat` the files together yourself. See the [`concat.json`](concat.json) for the order.

### Donation

If you *really* get a kick out of this (weirdo), you can [paypal me](https://www.paypal.me/TheAMM) or send bitcoins to `1K9FH7J3YuC9EnQjjDZJtM4EFUudHQr52d`. Just having the option there, is all.
