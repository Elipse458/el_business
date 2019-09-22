ESX = nil
local dataCache,namecache = {},{}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function reloadServerData()
    print("esx_business: Syncing businesses from database")
    dataCahe = {}
    local res = MySQL.Sync.fetchAll('SELECT * FROM businesses')
    for key,val in ipairs(res) do
        if val.owner~=nil and not namecache[val.owner] then namecache[val.owner]=MySQL.Sync.fetchAll("SELECT name,firstname,lastname FROM users WHERE identifier = @identifier",{["@identifier"]=val.owner})[1] end
        dataCache[val.id] = {
            id = val.id,
            name = val.name,
            address = val.address,
            description = val.description,
            blipname = (val.blipname~=nil and val.blipname~="") and val.blipname or Config.blip.name,
            owner = val.owner,
            owner_name = val.owner~=nil and namecache[val.owner].name or "None",
            owner_rp_name = val.owner~=nil and namecache[val.owner].firstname.." "..namecache[val.owner].lastname or "None",
            price = val.price,
            earnings = val.earnings,
            position = json.decode(val.position),
            stock_price = val.stock_price,
            employees = val.employees~=nil and json.decode(val.employees) or {},
            taxrate = val.taxrate~=nil and val.taxrate or Config.default_tax_rate
        }
    end
    print("esx_business: Synced "..tostring(#res).." business(es) from database")
end

function addMoney(identifier,money,business)
    if not identifier then return end
    local source = getSourceFromId(identifier) -- couldnt use ESX.GetPlayerFromIdentifier, the xPlayer.source was always 1, if you know why, please tell me
    local money = math.floor(tonumber(money))
    if source ~= nil then
        local xPlayer = ESX.GetPlayerFromId(source)
        print("esx_business: Adding money to "..GetPlayerName(source).." - "..identifier.." ("..tostring(money).."$)")
        TriggerClientEvent('esx:showNotification', source, 'You received ~g~'..tostring(money)..'$~s~ from ~b~'..business)
        xPlayer.addBank(math.floor(money))
    else
        print("esx_business: An error occured while adding money to "..identifier.." ("..tostring(money).."$). The player is offline. Forcing adding money")
        MySQL.Sync.execute('UPDATE `users` SET `bank` = `bank` + @bank WHERE `identifier` = @identifier',{['@bank'] = money, ['@identifier'] = identifier})
    end
end

function noStock(identifier,business)
    if not identifier or identifier==nil then return end
    print("esx_business: Player "..identifier.." has no stock at "..business)
    local source = getSourceFromId(identifier) -- xPlayer.source is bugges, it's always 1 
    if source ~= nil then
        TriggerClientEvent('esx:showNotification', source, '~r~'..business..'~s~ is out of stock!')
    end
end

function getStock(business)
    return MySQL.Sync.fetchAll('SELECT stock FROM businesses WHERE id='..tonumber(business))[1].stock
end

function getSourceFromId(identifier)
    for k,v in ipairs(ESX.GetPlayers()) do
        for kk,vv in ipairs(GetPlayerIdentifiers(v)) do
            if vv==identifier then return v end
        end
    end
    return nil
end

function runMoneyCoroutines(d,h,m)
    Citizen.CreateThread(function()
        print("esx_business: Running money coroutines "..h..":"..m)
        local businesses = MySQL.Async.fetchAll('SELECT * FROM businesses',{},function(data)
            for _,business in ipairs(data) do
                if business["owner"]~=nil then
                    if business["stock"]>0 then
                        MySQL.Async.execute('UPDATE businesses SET stock = stock - 1 WHERE id = @business', {["@business"] = tonumber(business["id"])}, nil)
                        local taxed_earnings = business["earnings"]*(1.0-(business["taxrate"]~=nil and business["taxrate"] or Config.default_tax_rate))
                        if business["employees"]~=nil and business["employees"]~="" and business["employees"]~="{}" and business["employees"]~="[]" then
                            local employees = json.decode(business["employees"])
                            local per_employee_earning = Config.employee_payout_formula(taxed_earnings,#employees)
                            for k,v in ipairs(employees) do
                                addMoney(v,per_employee_earning,business["name"])
                            end
                            addMoney(business["owner"],taxed_earnings-(per_employee_earning*#employees),business["name"])
                        else
                            addMoney(business["owner"],taxed_earnings,business["name"])
                        end
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

TriggerEvent('es:addGroupCommand', 'business', "superadmin", function(source, args, user)
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
        -- elseif args[1]=="runcoros" then -- debug
        --     runMoneyCoroutines(0,0,0)
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^4Business', 'Wrong parameters, possible parameters are: ^2reload^7, ^2list^7, ^2create^7' } })
    end
end, function(source, args, user)
    TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Insufficient permissions' } })
end, {})

function isBusinessEmployee(employeelist,identifier)
    for k,v in ipairs(employeelist) do
        if v==identifier then return true end
    end
    return false
end

ESX.RegisterServerCallback("esx_business:getNewEmployeeList",function(source,cb,business)
    local players = {}
    for k,v in ipairs(ESX.GetPlayers()) do
        local xTarget = ESX.GetPlayerFromId(v)
        if v~=source and GetPlayerName(v)~=nil and not isBusinessEmployee(dataCache[business]["employees"],xTarget.identifier) then table.insert(players,{name=GetPlayerName(v),sid=v}) end
    end
    if #players<1 then TriggerClientEvent('esx:showNotification', source, '~r~No people on the server'); return end
    cb(players)
end)

ESX.RegisterServerCallback("esx_business:getEmployeeList",function(source,cb,business)
    local idssql,idvals = {},{}
    for k,v in ipairs(dataCache[business]["employees"]) do
        table.insert(idssql,"@identifier"..k)
        idvals["@identifier"..k]=v
    end
    if #idssql<1 then TriggerClientEvent('esx:showNotification', source, '~r~Your employee list is empty'); return end
    MySQL.Async.fetchAll("SELECT name,identifier FROM users WHERE identifier IN ("..table.concat(idssql,",")..")",idvals,function(data)
        local employees = {}
        for k,v in ipairs(data) do
            table.insert(employees,{name=v.name,identifier=v.identifier})
        end
        cb(employees)
    end)
end)

ESX.RegisterServerCallback("esx_business:hireEmployee",function(source,cb,newempid,business)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(newempid)
    local identifier = xPlayer.identifier
    if dataCache[business]["owner"]==identifier and xTarget then
        table.insert(dataCache[business]["employees"],xTarget.identifier)
        MySQL.Async.execute("UPDATE businesses SET employees=@employees WHERE id=@business",{["@employees"]=json.encode(dataCache[business]["employees"]),["@business"]=business},function(rc)
            cb(rc>0)
            Citizen.CreateThread(function() reloadServerData(); reloadPlayersData() end)
        end)
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback("esx_business:fireEmployee",function(source,cb,fireid,business)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    if dataCache[business]["owner"]==identifier then
        for k,v in ipairs(dataCache[business]["employees"]) do
            if v==fireid then table.remove(dataCache[business]["employees"],k); break end
        end
        MySQL.Async.execute("UPDATE businesses SET employees=@employees WHERE id=@business",{["@employees"]=json.encode(dataCache[business]["employees"]),["@business"]=business},function(rc)
            cb(rc>0)
            Citizen.CreateThread(function() reloadServerData(); reloadPlayersData() end)
        end)
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback("esx_business:getStock", function(source,cb,business)
    local identifier = ESX.GetPlayerFromId(source).getIdentifier()
    if dataCache[business]["owner"]~=nil and dataCache[business]["owner"]==identifier or isBusinessEmployee(dataCache[business]["employees"],identifier) then cb(getStock(tonumber(business))) else cb(0) end
end)

ESX.RegisterServerCallback("esx_business:buyStock", function(source,cb,business,amt)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    if dataCache[business]["owner"]==identifier or isBusinessEmployee(dataCache[business]["employees"],identifier) then
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
        MySQL.Sync.execute('UPDATE businesses SET owner = NULL, employees = "{}" WHERE id = @business', {["@business"] = tonumber(business)}, nil)
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
        MySQL.Async.execute("INSERT INTO businesses(id,name,address,description,blipname,price,earnings,position,stock_price,taxrate,employees) VALUES (NULL,@name,@address,@description,@blipname,@price,@earnings,@position,@stock_price,@taxrate,'{}')", {
            ["@name"] = business["name"],
            ["@address"] = business["address"],
            ["@description"] = business["description"],
            ["@blipname"] = business["blipname"],
            ["@price"] = business["price"],
            ["@earnings"] = business["earnings"],
            ["@position"] = json.encode({buy = {x = bx, y = by, z = bz}, actions = {x = ax, y = ay, z = az}}),
            ["@stock_price"] = business["stock_price"],
            ["@taxrate"] = business["taxrate"]
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