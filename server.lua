ESX = nil
local dataCache = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function reloadServerData()
    print("esx_business: Syncing businesses from database")
    dataCahe = {}
    for key,val in ipairs(MySQL.Sync.fetchAll('SELECT * FROM businesses;')) do
        dataCache[val["id"]] = {
            id = val["id"],
            name = val["name"],
            address = val["address"],
            description = val["description"],
            owner = val["owner"],
            owner_name = val["owner"]~=nil and MySQL.Sync.fetchAll("SELECT name FROM users WHERE identifier = @identifier",{["@identifier"]=val["owner"]})[1]["name"] or "None",
            price = val["price"],
            earnings = val["earnings"],
            position = json.decode(val["position"]),
            stock_price = val["stock_price"]
        }
    end
    print("esx_business: Synced "..tostring(#dataCache).." business(es) from database")
end

function addMoney(identifier,money,business)
    if not identifier or identifier==nil then return end
    local xPlayer = ESX.GetPlayerFromIdentifier(tostring(identifier))
    if xPlayer ~= nil then
        print("esx_business: Adding money to "..xPlayer.getName().." - "..identifier.." ("..tostring(money).."$)")
        TriggerClientEvent('esx:showNotification', xPlayer.source, 'You received ~g~'..tostring(money)..'$~s~ from ~b~'..business)
        xPlayer.addBank(tonumber(money))
    else
        print("esx_business: An error occured while adding money to "..identifier.." ("..tostring(money).."$). Forcing adding money")
        MySQL.Sync.execute('UPDATE `users` SET `bank` = `bank` + @bank WHERE `identifier` = @identifier',{['@bank'] = tonumber(money), ['@identifier'] = identifier})
    end
end

function noStock(identifier,business)
    if not identifier or identifier==nil then return end
    print("esx_business: Player "..identifier.." has no stock at "..business)
    local xPlayer = ESX.GetPlayerFromIdentifier(tostring(identifier))
    if xPlayer ~= nil then
        TriggerClientEvent('esx:showNotification', xPlayer.source, '~r~'..business..'~s~ is out of stock!')
    end
end

function getStock(business)
    return MySQL.Sync.fetchAll('SELECT stock FROM businesses WHERE id='..tonumber(business))[1].stock
end

function runMoneyCoroutines(d,h,m)
    Citizen.CreateThread(function()
        print("esx_business: Running money coroutines "..h..":"..m)
        local businesses = MySQL.Async.fetchAll('SELECT * FROM businesses',{},function(data)
            for _,business in ipairs(data) do
                if tostring(business["owner"])~=nil then
                    local xPlayer = ESX.GetPlayerFromIdentifier(business["owner"])
                    if business["stock"]>0 then
                        MySQL.Async.execute('UPDATE businesses SET stock = stock - 1 WHERE id = @business', {["@business"] = tonumber(business["id"])}, nil)
                        addMoney(business["owner"],business["earnings"],business["name"])
                    else
                        noStock(business["owner"],business["name"])
                    end
                end
            end
        end)
    end)
end

MySQL.ready(function()
    reloadServerData()
    Citizen.CreateThread(function()
        Citizen.Wait(2000) -- just wait for clients to load their shit
        reloadPlayersData()
    end)
end)

function reloadPlayersData()
    local xPlayers = ESX.GetPlayers()
    if #xPlayers<1 then return end
    for _,id in ipairs(xPlayers) do
        TriggerClientEvent("esx_business:syncServer",id,dataCache)
    end
end

AddEventHandler('es:playerLoaded', function(source, user)
    local _source = source
    TriggerClientEvent("esx_business:syncServer",_source,dataCache)
end)

TriggerEvent('es:addAdminCommand', 'business', 10, function(source, args, user)
    if args[1]=="business" then table.remove(args,1) end
    if #args>0 then
        if args[1]=="reload" then
            reloadServerData()
            reloadPlayersData()
            TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Data loaded from database and synced' } })
        elseif args[1]=="list" then
            TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Business list will appear in F8 console' } })
            TriggerClientEvent("esx_business:businessList", source)
        elseif args[1]=="create" then
            TriggerClientEvent("esx_business:businessCreate", source)
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Wrong parameters, possible parameters are: ^2reload^7, ^2list^7, ^2create^7' } })
    end
end, function(source, args, user)
    TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions' } })
end, {})

ESX.RegisterServerCallback("esx_business:getStock", function(source,cb,business)
    local identifier = ESX.GetPlayerFromId(source).getIdentifier()
    if dataCache[business]["owner"]~=nil and dataCache[business]["owner"]==identifier then cb(getStock(tonumber(business))) else cb(0) end
end)

ESX.RegisterServerCallback("esx_business:buyStock", function(source,cb,business,amt)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    if dataCache[business]["owner"]==identifier then
        if xPlayer.getMoney()>=dataCache[business]["stock_price"]*amt then
            xPlayer.removeMoney(dataCache[business]["stock_price"]*amt)
            local time = math.random(300,900)
            Citizen.CreateThread(function()
                print("esx_business: Player "..identifier.." bought stock, delivering in: "..time.."s")
                Citizen.Wait(time*1000)
                MySQL.Async.execute('UPDATE businesses SET stock = stock + @amt WHERE id = @business', {["@amt"] = tonumber(amt), ["@business"] = tonumber(business)}, nil)
                TriggerClientEvent('esx:showNotification', source, 'Your stock for ~b~'..dataCache[business]["name"]..'~s~ has been delivered!')
            end)
            cb(true,time)
        else
            cb(false,0)
        end
    else
        cb(false,0)
    end
end)

ESX.RegisterServerCallback("esx_business:buyBusiness", function(source,cb,business)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    if dataCache[business]["owner"]==nil then
        if xPlayer.getMoney()>=dataCache[business]["price"] then
            dataCache[business]["owner"]=identifier -- counteract the loading time from db (player can accidentally buy twice)
            xPlayer.removeMoney(dataCache[business]["price"])
            MySQL.Sync.execute('UPDATE businesses SET owner = @identifier WHERE id = @business', {["@identifier"] = identifier, ["@business"] = tonumber(business)}, nil)
            Citizen.CreateThread(function() reloadServerData();reloadPlayersData() end)
            cb(0)
        else
            cb(2)
        end
    else
        cb(1)
    end
end)

ESX.RegisterServerCallback("esx_business:sellBusiness", function(source,cb,business)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    if dataCache[business]["owner"]==identifier then
        xPlayer.addMoney(math.floor(dataCache[business]["price"]*Config.sell_percentage))
        dataCache[business]["owner"]=nil -- counteract the loading time from db (dupe bug)
        MySQL.Sync.execute('UPDATE businesses SET owner = NULL WHERE id = @business', {["@business"] = tonumber(business)}, nil)
        Citizen.CreateThread(function() reloadServerData();reloadPlayersData() end)
        cb(true)
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback("esx_business:createBusiness", function(source,cb,business)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getPermissions()>=10 then
        if not business then cb(false) end
        local bx,by,bz = table.unpack(business["buy_position"])
        local ax,ay,az = table.unpack(business["actions_position"])
        local id = MySQL.Sync.fetchAll("SELECT MAX(id) FROM businesses")[1]["MAX(id)"]+1
        MySQL.Async.execute("INSERT INTO businesses(id,name,address,description,price,earnings,position,stock_price) VALUES (@id,@name,@address,@description,@price,@earnings,@position,@stock_price)", {
            ["@id"] = id,
            ["@name"] = business["name"],
            ["@address"] = business["address"],
            ["@description"] = business["description"],
            ["@price"] = business["price"],
            ["@earnings"] = business["earnings"],
            ["@position"] = json.encode({buy = {x = bx, y = by, z = bz}, actions = {x = ax, y = ay, z = az}}),
            ["@stock_price"] = business["stock_price"]
        }, function(rowsChanged)
            if rowsChanged>0 then cb(true);reloadServerData();reloadPlayersData() else cb(false) end
        end)
    else
        cb(false)
    end
end)

Citizen.CreateThread(function()
    print("esx_business: Started!")
    print("********************")
    print("WARNING: PLEASE DON\'T RESTART THIS SCRIPT, USE THE BUILTIN COMMAND /business reload TO RELOAD DATA FROM DATABASE")
    print("********************")
    for i=0,23 do
        TriggerEvent("cron:runAt",i,0,runMoneyCoroutines)
    end
end)