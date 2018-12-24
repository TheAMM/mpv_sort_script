local SCRIPT_NAME = "mpv_sort_script"

--------------------
-- Script options --
--------------------

local script_options = OptionParser(SCRIPT_NAME, 'sort')
local option_values = script_options.values

local BASE_EXTENSIONS = {
  'mkv', 'avi', 'mp4', 'ogv', 'webm', 'rmvb', 'flv', 'wmv', 'mpeg', 'mpg', 'm4v', '3gp', 'mov', 'ts',
  'mp3', 'wav', 'ogm', 'flac', 'm4a', 'wma', 'ogg', 'opus',
  'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'
}

local SORT_KEY_NAMES = {
  "name", "date", "size", "random"
}
local PRECEDENCE_KEY_NAMES = {
  "files", "dirs", "mix"
}

local SORT_KEYS = Set(SORT_KEY_NAMES)
local PRECEDENCE_KEYS = Set(PRECEDENCE_KEY_NAMES)

script_options:add_options({
  {nil, nil, "mpv_sort_script.lua options and default values"},

  {"always_sort", false,
    "Whether to sort directory entries even without being explicitly told to. Not recommended unless you're sure about what you're doing", true},

  {"recursive_sort", false,
    "Whether to recurse into subdirectories and sort all found files and directories in one go, instead of sorting each directory when we come across it.\nNote: only applies to always_sort, since sort: and rsort: control the recursion in explicit sorting", true},
  {"max_recurse_depth", 10,
    "Maximum recurse depth for subdirectories. 0 means no recursion."},

  {"default_sort", "date",
    "Default sorting method, used if one is not explicitly provided. Must be one of: " .. table.concat(SORT_KEY_NAMES, ", "), true},
  {"default_precedence", "files",
    "Default file/directory precedence (which to sort first), used if one is not explicitly provided. Must be one of: " .. table.concat(PRECEDENCE_KEY_NAMES, ", ")},
  {"default_descending", false,
    "Descending sort by default"},

  {"alphanumeric_sort", true,
    "Use alphanumeric sort instead of naive character sort. Ie., sort names by taking the numerical values into account.", true},
  {"stable_random_sort", true,
    "Generate a random seeed from the given path, file and directory count, to randomly sort entries in a reproducible manner. This enables random sort to work with watch-later resuming."},
  {"random_seed", "seed",
    "Extra random seed to use with stable_random_sort, if you want to change the stable order."},

  {"extensions", table.concat(BASE_EXTENSIONS, ","),
    "A comma-separated list of extensions to be consired as playable files.", true},

  {"exclude", "",
    "A Lua match pattern (more or less) to exclude file and directory paths with. '*' will be automatically replaced with '.-'."},
})

-- Read user-given options, if any
script_options:load_options()

if not SORT_KEYS[option_values.default_sort] then
  msg.warn(("Resetting bad default_sort '%s' to default"):format(option_values.default_sort))
  option_values.default_sort = script_options.defaults.default_sort
end

if not PRECEDENCE_KEYS[option_values.default_precedence] then
  msg.warn(("Resetting bad default_precedence '%s' to default"):format(option_values.default_precedence))
  option_values.default_precedence = script_options.defaults.default_precedence
end

local EXTENSIONS = {}
for k in option_values.extensions:lower():gmatch('[^, ]+') do
  EXTENSIONS[k] = true
end

local EXCLUDE_PATTERN = option_values.exclude:len() > 0 and option_values.exclude:gsub('%*', '.-') or nil
