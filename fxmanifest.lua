fx_version "cerulean"

description "Free Version Register Menu [YOU CAN BUY PREMIUM VERSION WITH MORE FEATURE FROM https://one.tebex.io]"
author "One Store"
version '1.0'

shared_script '@es_extended/imports.lua'

lua54 'yes'

games {
  "gta5"
}

ui_page 'web/build/index.html'

shared_script 'config.lua'

client_scripts {
  "client/**/*",
}

server_scripts {
  '@mysql-async/lib/MySQL.lua',
  "server/**/*",
}


files {
  'web/build/index.html',
  'web/build/**/*',
}
