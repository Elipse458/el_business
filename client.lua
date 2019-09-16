ESX = nil
local PlayerData = nil
local businessData = {}
local boss,buy,currentmenu = false,false,nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
    end
    if PlayerData==nil then PlayerData = ESX.GetPlayerData() end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

function disp_time(time)
    local minutes = math.floor((time%3600)/60)
    local seconds = math.floor((time%60))
    return string.format("~b~%02d~s~m ~b~%02d~s~s",minutes,seconds)
end

function DrawText3D(x,y,z, text, scl) 
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
    local scale = (1/dist)*scl
    local fov = (1/GetGameplayCamFov())*100
    local scale = scale*fov
    if onScreen then
        SetTextScale(0.0*scale, 1.1*scale)
        SetTextFont(0)
        SetTextProportional(1)
        -- SetTextScale(0.0, 0.55)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x,_y)
    end
end

function OpenBusinessMenu(business)
    if boss then ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_boss") end
    boss = true
    ESX.TriggerServerCallback("esx_business:getStock", function(stock)
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_boss',
        {
            title = business["name"],
            align = 'bottom-right',
            elements = {
                {label = "Stock: "..tostring(stock), value = ''},
                {label = 'Buy Stock - <span style="color:green;">$'..tostring(business["stock_price"])..'</span>', label_real = 'buystock', value = 1, type = 'slider', min = 1, max = 100},
                {label = 'Sell business - <span style="color:red;">$'..tostring(math.floor(business["price"]*Config.sell_percentage))..'</span>', value = 'sellbusiness'},
                {label = "Exit menu", value = 'exitmenu'},
            }
        }, function(data, menu)
            if data.current.label_real == 'buystock' then
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_confirm_stock', {
                    title    = ("Are you sure you want to buy %s stock for %s?"):format(data.current.value,business["stock_price"]*data.current.value),
                    align    = 'bottom-right',
                    elements = {
                        {label = 'No',  value = 'no'},
                        {label = 'Yes', value = 'yes'},
                    }
                }, function(data2, menu2)
                    if data2.current.value == 'yes' then
                        ESX.TriggerServerCallback("esx_business:buyStock", function(success,time)
                            if success then
                                ESX.ShowNotification("Successfuly bought stock! It will arrive in "..disp_time(time))
                            else ESX.ShowNotification("~r~You don't have enough money") end
                        end,business["id"],data.current.value)
                    end
                    menu2.close()
                end, function(data2, menu2) menu2.close() end)
            elseif data.current.value == 'sellbusiness' then
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_confirm_sellbusiness', {
                    title    = ("Are you sure you want to sell %s for %s?"):format(business["name"],math.floor(business["price"]*0.8)),
                    align    = 'bottom-right',
                    elements = {
                        {label = 'No',  value = 'no'},
                        {label = 'Yes', value = 'yes'},
                    }
                }, function(data2, menu2)
                    if data2.current.value == 'yes' then
                        ESX.TriggerServerCallback("esx_business:sellBusiness", function(success)
                            if success then
                                ESX.ShowNotification("You have sold your business for ~g~$"..math.floor(business["price"]*0.8))
                            else ESX.ShowNotification("~r~An error occured") end
                        end,business["id"])
                    end
                    menu2.close()
                end, function(data2, menu2) menu2.close() end)
                menu.close(); boss=false
            else
                menu.close(); boss=false
            end
        end, function(data, menu)
            menu.close(); boss=false
        end)
    end, business["id"])
end

function OpenBuyBusinessMenu(business)
    if buy then ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_buy") end
    buy = true
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_buy',
    {
        title = "Buy "..business["name"].." for $"..business["price"].."?",
        align = 'bottom-right',
        elements = {
            {label = 'Yes', value = 'yes'},
            {label = 'No', value = 'no'}
        }
    }, function(data,menu)
        if data.current.value == 'yes' then
            ESX.TriggerServerCallback("esx_business:buyBusiness",function(status)
                if status==0 then
                    ESX.ShowNotification("You successfuly bought ~b~"..business["name"].."~s~!")
                elseif status==1 then
                    ESX.ShowNotification("~r~"..business["name"].."~s~ already has an owner!")
                else
                    ESX.ShowNotification("You don't have enough money to buy ~b~"..business["name"].."~s~!")
                end
            end,business["id"])
        end
        menu.close(); buy = false
    end, function(data,menu)
        menu.close(); buy = false
    end)
end

function OpenParameterDialog(length)
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP", "", "", "", "", "", length)
    while UpdateOnscreenKeyboard()==0 do
        DisableAllControlActions(0)
        Wait(0)
    end
    if GetOnscreenKeyboardResult() then return GetOnscreenKeyboardResult() end
end

function editElements(elements,label,value)
    for _,v in ipairs(elements) do
        if v.label==label then v.value=value; break end
    end
    return elements
end

RegisterCommand("testing", function(a,b,c)
    print(OpenParameterDialog(255))
end, false)

function OpenCreateBusinessMenu()
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_create',
    {
        title = "Create business",
        align = 'bottom-right',
        elements = {
            {label = '<span style="color:red;">Your current position will be used</span>', action = ''},
            {label = 'Name: ', action = 'name', value = '', key = 2},
            {label = 'Description: ', action = 'desc', value = '', key = 3},
            {label = 'Address: ', action = 'address', value = '', key = 4},
            {label = 'Price: ', action = 'price', value = '', key = 5},
            {label = 'Earnings: ', action = 'earnings', value = '', key = 6},
            {label = 'Stock price: ', action = 'stock_price', value = '', key = 7},
            {label = 'Create business', action = 'create'},
            {label = 'Discard business', action = 'discard'}
        }
    }, function(data,menu)
        if data.current.action == 'name' then
            data.current.value = OpenParameterDialog(255)
            data.current.label = 'Name: '..data.current.value
        elseif data.current.action == 'desc' then
            data.current.value = OpenParameterDialog(75)
            data.current.label = 'Description: '..data.current.value
        elseif data.current.action == 'address' then
            data.current.value = OpenParameterDialog(255)
            data.current.label = 'Address: '..data.current.value
        elseif data.current.action == 'price' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Price: '..tostring(data.current.value)
        elseif data.current.action == 'earnings' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Earnings: '..tostring(data.current.value)
        elseif data.current.action == 'stock_price' then
            data.current.value = tonumber(OpenParameterDialog(11))
            data.current.label = 'Stock price: '..tostring(data.current.value)
        elseif data.current.action == 'create' then
            local error = false
            for _,v in ipairs(menu.data.elements) do if v.key~=nil and (v.value==nil or v.value=='') then error = true end end
            if not error then
                local buypos = GetEntityCoords(GetPlayerPed(-1))
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'business_create_actionpos', {title="Please select the boss action location",align="bottom-right",elements={{label='<span style="color:red;">Your current position will be used</span>',action=''},{label="Set position",action="setpos"},{label="Cancel",action="cancel"}}},function(data1,menu1) if data1.current.action=="setpos" then 
                    local business = {
                        name = menu.data.elements[2].value,
                        address = menu.data.elements[4].value,
                        description = menu.data.elements[3].value,
                        price = menu.data.elements[5].value,
                        earnings = menu.data.elements[6].value,
                        buy_position = buypos,
                        actions_position = GetEntityCoords(GetPlayerPed(-1)),
                        stock_price = menu.data.elements[7].value
                    }
                    ESX.ShowNotification("~b~Creating business...")
                    menu1.close()
                    ESX.TriggerServerCallback("esx_business:createBusiness", function(diditwork)
                        if diditwork then ESX.ShowNotification("~g~Business created!") else ESX.ShowNotification("~r~There was an error creating the business") end
                    end,business)
                elseif data1.current.action=="cancel" then menu1.close() end end,function(data1,menu1) menu1.close() end)
                menu.close()
            else
                ESX.ShowNotification("~r~Data error, check your values.")
            end
        elseif data.current.action == 'discard' then
            menu.close()
        end
        if data.current.key~=nil then menu.setElement(data.current.key, "label", data.current.label); menu.setElement(data.current.key, "value", data.current.value); menu.refresh() end
    end, function(data,menu)
        menu.close()
    end)
end

function replaceVariablesInString(str,business)
    for k,v in pairs(business) do
        str = str:gsub("{"..k.."}",k=="price" and ESX.Math.GroupDigits(v) or tostring(v))
    end
    return str
end

RegisterNetEvent("esx_business:syncServer")
AddEventHandler("esx_business:syncServer",function(data)
    for k,v in ipairs(data) do
        data[k]["display"] = {}
        for kk,vv in ipairs(Config.display) do
            table.insert(data[k].display,replaceVariablesInString(vv.text,v))
        end
    end
    businessData = data
    -- Citizen.Trace("Received business data from server")
end)

RegisterNetEvent("esx_business:businessCreate")
AddEventHandler("esx_business:businessCreate",function()
    OpenCreateBusinessMenu()
end)

RegisterNetEvent("esx_business:businessList")
AddEventHandler("esx_business:businessList",function()
    if #businessData<1 then Citizen.Trace("No business info on client, if there is some on server, you should try running the `/business reload` command to sync server info") else
        Citizen.Trace("esx_business: Started business dump")
        for k,v in ipairs(businessData) do
            Citizen.Trace("-"..tostring(v["id"]))
            Citizen.Trace("|-> Name: "..v["name"])
            Citizen.Trace("|-> Address: "..v["address"])
            Citizen.Trace("|-> Description: "..v["description"])
            Citizen.Trace("|-> Owner: "..(v["owner_name"]~=nil and v["owner_name"] or "N/A").." ("..(v["owner"]~=nil and v["owner"] or "N/A")..")")
            Citizen.Trace("|-> Price: "..v["price"].."$")
            Citizen.Trace("|-> Stock price: "..v["stock_price"].."$")
            Citizen.Trace("L-> Earnings: "..v["earnings"].."$/h")
        end
        Citizen.Trace("esx_business: Finished business dump")
        Citizen.Trace("esx_business: Dumped "..tostring(#businessData).." business(es) to console")
    end
end)

Citizen.CreateThread(function()
    while true do
        local ped = GetPlayerPed(-1)
        local ppos = GetEntityCoords(ped)
        Citizen.Wait(10) -- change this to 0 if you're experiencing flickering
        for id,business in ipairs(businessData) do
            local x,y,z = business.position.buy.x,business.position.buy.y,business.position.buy.z
            if GetDistanceBetweenCoords(ppos,x,y,z,false)<Config.draw_distance then
                if business.owner==nil then
                    if GetDistanceBetweenCoords(ppos,x,y,z,false)<2.0 and not buy then
                        ESX.ShowHelpNotification('Hit ~INPUT_CONTEXT~ to buy business')
                        if IsControlJustPressed(0, 51) then OpenBuyBusinessMenu(business); currentmenu=id end
                    elseif GetDistanceBetweenCoords(ppos,x,y,z,false)>2.0 and buy and currentmenu==id then
                        ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_buy")
                        buy = false; currentmenu = nil
                    end
                elseif business.owner==PlayerData.identifier then
                    local xx,yy,zz = business.position.actions.x,business.position.actions.y,business.position.actions.z
                    if GetDistanceBetweenCoords(vector3(xx,yy,zz),GetEntityCoords(ped),false)<1.0 and not boss then
                        ESX.ShowHelpNotification('Hit ~INPUT_CONTEXT~ to open business menu')
                        if IsControlJustPressed(0, 51) then OpenBusinessMenu(business); currentmenu=id end
                    elseif GetDistanceBetweenCoords(vector3(xx,yy,zz),GetEntityCoords(ped),false)>1.0 and boss and currentmenu==id then
                        ESX.UI.Menu.Close("default",GetCurrentResourceName(),"business_boss")
                        boss = false; currentmenu = nil
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function() -- draw thread
    while true do
        Citizen.Wait(5)
        local ppos = GetEntityCoords(GetPlayerPed(-1))
        for _,business in ipairs(businessData) do
            local x,y,z = business.position.buy.x,business.position.buy.y,business.position.buy.z
            if GetDistanceBetweenCoords(ppos,x,y,z,false)<Config.draw_distance then
                for k,v in ipairs(Config.display) do
                    DrawText3D(x,y,z+0.5+v.offset,business.display[k],v.scale)
                end
                if business.owner==nil then
                    DrawMarker(29, x, y, z-0.7, 0, 0, 0, 0, 0, 0, 1.0001, 1.0001, 1.2001, 0, 255, 0, 200, 0, 0, 0, true)
                elseif business.owner==PlayerData.identifier then
                    local xx,yy,zz = business.position.actions.x,business.position.actions.y,business.position.actions.z
                    DrawMarker(1, xx, yy, zz-1.0, 0, 0, 0, 0, 0, 0, 1.0001, 1.0001, 0.25, 0, 0, 255, 100, 0, 0, 0, false)
                end
            end
        end
    end
end)