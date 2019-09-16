Config = {}

Config.draw_distance = 25.0

Config.display = {
    {offset = 0.23, text = "~y~ {name}", scale = 1.5},
    {offset = 0.0, text = "{address}; {description}", scale = 0.7},
    {offset = -0.1, text = "~b~Owner: ~r~{owner_name} ~b~Price: ~g~${price}", scale = 1},
    {offset = -0.21, text = "~b~Earnings: ~g~${earnings}/hr", scale = 1}
}

Config.sell_percentage = 0.8 -- % from original price the player gets after selling business (1 = 100%, 0.5 = 50%)