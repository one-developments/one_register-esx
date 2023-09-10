local playerIdentity = {}
local alreadyRegistered = {}
local multichar = ESX.GetConfig().Multichar

local function saveIdentityToDatabase(identifier, identity)
    MySQL.update.await(
        "UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ? WHERE identifier = ?",
        {
            identity.firstName,
            identity.lastName,
            identity.dateOfBirth,
            identity.sex,
            identity.height,
            identifier,
        }
    )
end

local function deleteIdentityFromDatabase(xPlayer)
    MySQL.query.await(
        "UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ?, skin = ? WHERE identifier = ?",
        { nil, nil, nil, nil, nil, nil, xPlayer.identifier }
    )

    if Config.FullCharDelete then
        MySQL.update.await(
            "UPDATE addon_account_data SET money = 0 WHERE account_name IN (?) AND owner = ?",
            { { "bank_savings", "caution" }, xPlayer.identifier }
        )

        MySQL.prepare.await(
            "UPDATE datastore_data SET data = ? WHERE name IN (?) AND owner = ?",
            { "'{}'", { "user_ears", "user_glasses", "user_helmet", "user_mask" }, xPlayer.identifier }
        )
    end
end

local function deleteIdentity(xPlayer)
    if alreadyRegistered[xPlayer.identifier] then
        xPlayer.setName(("%s %s"):format(nil, nil))
        xPlayer.set("firstName", nil)
        xPlayer.set("lastName", nil)
        xPlayer.set("dateofbirth", nil)
        xPlayer.set("sex", nil)
        xPlayer.set("height", nil)
        xPlayer.set("story", nil)
        deleteIdentityFromDatabase(xPlayer)
    end
end




local function convertToLowerCase(str)
    return string.lower(str)
end

local function convertFirstLetterToUpper(str)
    return str:gsub("^%l", string.upper)
end

local function formatName(name)
    local loweredName = convertToLowerCase(name)
    local formattedName = convertFirstLetterToUpper(loweredName)
    return formattedName
end

local function setIdentity(xPlayer)
    if alreadyRegistered[xPlayer.identifier] then
        local currentIdentity = playerIdentity[xPlayer.identifier]
        xPlayer.setName(("%s %s"):format(currentIdentity.firstName, currentIdentity.lastName))
        xPlayer.set("firstName", currentIdentity.firstName)
        xPlayer.set("lastName", currentIdentity.lastName)
        xPlayer.set("dateofbirth", currentIdentity.dateOfBirth)
        xPlayer.set("sex", currentIdentity.sex)
        xPlayer.set("height", currentIdentity.height)
        xPlayer.set("story", currentIdentity.story)
        TriggerClientEvent("esx_identity:setPlayerData", xPlayer.source, currentIdentity)
        if currentIdentity.saveToDatabase then
            saveIdentityToDatabase(xPlayer.identifier, currentIdentity)
        end
        playerIdentity[xPlayer.identifier] = nil
    end
end

local function checkIdentity(xPlayer)
    MySQL.single(
        "SELECT firstname, lastname, dateofbirth, sex, height, story FROM users WHERE identifier = ?",
        { xPlayer.identifier },
        function(result)
            if result then
                if result.firstname then
                    playerIdentity[xPlayer.identifier] = {
                        firstName = result.firstname,
                        lastName = result.lastname,
                        dateOfBirth = result.dateofbirth,
                        sex = result.sex,
                        height = result.height,
                        story = result.story,
                    }

                    alreadyRegistered[xPlayer.identifier] = true
                    setIdentity(xPlayer)
                else
                    playerIdentity[xPlayer.identifier] = nil
                    alreadyRegistered[xPlayer.identifier] = false
                    TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.source)
                end
            else
                TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.source)
            end
        end
    )
end

if not multichar then
    AddEventHandler("playerConnecting", function(playerName, setKickReason, deferrals)
        deferrals.defer()
        local playerId, identifier = source, ESX.GetIdentifier(source)
        Wait(40)

        if identifier then
            MySQL.single(
                "SELECT firstname, lastname, dateofbirth, sex, height, story FROM users WHERE identifier = ?",
                { identifier },
                function(result)
                    if result then
                        if result.firstname then
                            playerIdentity[identifier] = {
                                firstName = result.firstname,
                                lastName = result.lastname,
                                dateOfBirth = result.dateofbirth,
                                sex = result.sex,
                                height = result.height,
                                story = result.story,
                            }

                            alreadyRegistered[identifier] = true

                            deferrals.done()
                        else
                            playerIdentity[identifier] = nil
                            alreadyRegistered[identifier] = false
                            deferrals.done()
                        end
                    else
                        playerIdentity[identifier] = nil
                        alreadyRegistered[identifier] = false
                        deferrals.done()
                    end
                end
            )
        else
            deferrals.done(Locale["no_identifier"])
        end
    end)

    AddEventHandler("onResourceStart", function(resource)
        if resource == GetCurrentResourceName() then
            Wait(300)

            while not ESX do
                Wait(0)
            end

            local xPlayers = ESX.GetExtendedPlayers()

            for i = 1, #xPlayers do
                if xPlayers[i] then
                    checkIdentity(xPlayers[i])
                end
            end
        end
    end)

    RegisterNetEvent("esx:playerLoaded", function(playerId, xPlayer)
        local currentIdentity = playerIdentity[xPlayer.identifier]

        if currentIdentity and alreadyRegistered[xPlayer.identifier] == true then
            xPlayer.setName(("%s %s"):format(currentIdentity.firstName, currentIdentity.lastName))
            xPlayer.set("firstName", currentIdentity.firstName)
            xPlayer.set("lastName", currentIdentity.lastName)
            xPlayer.set("dateofbirth", currentIdentity.dateOfBirth)
            xPlayer.set("sex", currentIdentity.sex)
            xPlayer.set("height", currentIdentity.height)
            xPlayer.set("story", currentIdentity.story)
            TriggerClientEvent("esx_identity:setPlayerData", xPlayer.source, currentIdentity)
            if currentIdentity.saveToDatabase then
                saveIdentityToDatabase(xPlayer.identifier, currentIdentity)
            end

            Wait(0)

            TriggerClientEvent("esx_identity:alreadyRegistered", xPlayer.source)

            playerIdentity[xPlayer.identifier] = nil
        else
            TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.source)
        end
    end)
end

ESX.RegisterServerCallback("bcs_identity:registerIdentity", function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        if not alreadyRegistered[xPlayer.identifier] then
            local formattedFirstName = formatName(data.firstname)
            local formattedLastName = formatName(data.lastname)

            playerIdentity[xPlayer.identifier] = {
                firstName = formattedFirstName,
                lastName = formattedLastName,
                dateOfBirth = data.dateofbirth,
                sex = data.sex,
                height = data.height,
                story = data.description,
            }
            local currentIdentity = playerIdentity[xPlayer.identifier]
            xPlayer.setName(("%s %s"):format(currentIdentity.firstName, currentIdentity.lastName))
            xPlayer.set("firstName", currentIdentity.firstName)
            xPlayer.set("lastName", currentIdentity.lastName)
            xPlayer.set("dateofbirth", currentIdentity.dateOfBirth)
            xPlayer.set("sex", currentIdentity.sex)
            xPlayer.set("height", currentIdentity.height)
            TriggerClientEvent("esx_identity:setPlayerData", xPlayer.source, currentIdentity)
            saveIdentityToDatabase(xPlayer.identifier, currentIdentity)
            alreadyRegistered[xPlayer.identifier] = true
            playerIdentity[xPlayer.identifier] = nil
            cb(true)
        else
            xPlayer.showNotification(Locale["already_registered"], "error")
            cb(false)
        end
    else
        if multichar then
            local formattedFirstName = formatName(data.firstname)
            local formattedLastName = formatName(data.lastname)
            data.firstname = formattedFirstName
            data.lastname = formattedLastName
            data.dateofbirth = formattedDate
            local Identity = {
                firstName = formattedFirstName,
                lastName = formattedLastName,
                dateOfBirth = formattedDate,
                sex = data.sex,
                height = data.height,
            }
            TriggerEvent("esx_identity:completedRegistration", source, data)
            TriggerClientEvent("esx_identity:setPlayerData", source, Identity)
            cb(true)
        else
            TriggerClientEvent("esx:showNotification", source, Locale["data_incorrect"], "error")
            cb(false)
        end
    end
end)

if Config.EnableCommands then
    ESX.RegisterCommand("char", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.getName() then
            xPlayer.showNotification(string.format(Locale["active_character"], xPlayer.getName()))
        else
            xPlayer.showNotification(Locale["error_active_character"])
        end
    end, false, { help = Locale["show_active_character"] })

    ESX.RegisterCommand("chardel", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.getName() then
            if Config.UseDeferrals then
                xPlayer.kick(Locale["deleted_identity"])
                Wait(1500)
                deleteIdentity(xPlayer)
                xPlayer.showNotification(Locale["deleted_character"])
                playerIdentity[xPlayer.identifier] = nil
                alreadyRegistered[xPlayer.identifier] = false
            else
                deleteIdentity(xPlayer)
                xPlayer.showNotification(Locale["deleted_character"])
                playerIdentity[xPlayer.identifier] = nil
                alreadyRegistered[xPlayer.identifier] = false
                TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.source)
            end
        else
            xPlayer.showNotification(Locale["error_delete_character"])
        end
    end, false, { help = Locale["delete_character"] })
end

if Config.EnableDebugging then
    ESX.RegisterCommand("xPlayerGetFirstName", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.get("firstName") then
            xPlayer.showNotification(
                string.format(Locale["return_debug_xPlayer_get_first_name"], xPlayer.get("firstName"))
            )
        else
            xPlayer.showNotification(Locale["error_debug_xPlayer_get_first_name"])
        end
    end, false, { help = Locale["debug_xPlayer_get_first_name"] })

    ESX.RegisterCommand("xPlayerGetLastName", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.get("lastName") then
            xPlayer.showNotification(
                string.format(Locale["return_debug_xPlayer_get_last_name"], xPlayer.get("lastName"))
            )
        else
            xPlayer.showNotification(Locale["error_debug_xPlayer_get_last_name"])
        end
    end, false, { help = Locale["debug_xPlayer_get_last_name"] })

    ESX.RegisterCommand("xPlayerGetFullName", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.getName() then
            xPlayer.showNotification(string.format(Locale["return_debug_xPlayer_get_full_name"], xPlayer.getName()))
        else
            xPlayer.showNotification(Locale["error_debug_xPlayer_get_full_name"])
        end
    end, false, { help = Locale["debug_xPlayer_get_full_name"] })

    ESX.RegisterCommand("xPlayerGetSex", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.get("sex") then
            xPlayer.showNotification(string.format(Locale["return_debug_xPlayer_get_sex"], xPlayer.get("sex")))
        else
            xPlayer.showNotification(Locale["error_debug_xPlayer_get_sex"])
        end
    end, false, { help = Locale["debug_xPlayer_get_sex"] })

    ESX.RegisterCommand("xPlayerGetDOB", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.get("dateofbirth") then
            xPlayer.showNotification(string.format(Locale["return_debug_xPlayer_get_dob"], xPlayer.get("dateofbirth")))
        else
            xPlayer.showNotification(Locale["error_debug_xPlayer_get_dob"])
        end
    end, false, { help = Locale["debug_xPlayer_get_dob"] })

    ESX.RegisterCommand("xPlayerGetHeight", "user", function(xPlayer, args, showError)
        if xPlayer and xPlayer.get("height") then
            xPlayer.showNotification(string.format(Locale["return_debug_xPlayer_get_height"], xPlayer.get("height")))
        else
            xPlayer.showNotification(Locale["error_debug_xPlayer_get_height"])
        end
    end, false, { help = Locale["debug_xPlayer_get_height"] })
end
Citizen.CreateThread(function()
    if not Config.ESX_1_9_0 then
        ESX = nil
        TriggerEvent(Config.GetSharedObject, function(obj) ESX = obj end)
    else
        ESX = exports["es_extended"]:getSharedObject()
    end
end)
