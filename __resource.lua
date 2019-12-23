resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

client_scripts {
    "config.lua",
    "client.lua",
    "locale/en.lua"
}
server_scripts {
    "@mysql-async/lib/MySQL.lua",
	"config.lua",
    "server.lua",
    "locale/en.lua"
}

dependencies {
    "es_extended",
    "cron"
}