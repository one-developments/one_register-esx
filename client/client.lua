local ready = false
local loadingScreenFinished = false

Citizen.CreateThread(function()
  if not Config.ESX_1_9_0 then
    ESX = nil
    while ESX == nil do
      TriggerEvent(Config.GetSharedObject, function(obj) ESX = obj end)
      Citizen.Wait(200)
    end
  else
    ESX = exports["es_extended"]:getSharedObject()
  end
end)

AddEventHandler('esx:loadingScreenOff', function()
  loadingScreenFinished = true
end)

local function toggleNuiFrame(shouldShow)
  while not ready do
    Wait(250)
  end
  SetNuiFocus(shouldShow, shouldShow)
  SendReactMessage('setVisible', shouldShow)
end

RegisterCommand('test', function()
  toggleNuiFrame(true)
end)




RegisterNetEvent('esx_identity:setPlayerData', function(data)
  SetTimeout(1, function()
    ESX.SetPlayerData("name", ('%s %s'):format(data.firstName, data.lastName))
    ESX.SetPlayerData('firstName', data.firstName)
    ESX.SetPlayerData('lastName', data.lastName)
    ESX.SetPlayerData('dateofbirth', data.dateOfBirth)
    ESX.SetPlayerData('sex', data.sex)
    ESX.SetPlayerData('height', data.height)
  end)
end)

RegisterNetEvent("esx_identity:alreadyRegistered", function()
  while not loadingScreenFinished do Wait(100) end
  TriggerEvent("esx_skin:playerRegistered")
end)

RegisterNetEvent("esx_identity:showRegisterIdentity", function()
  TriggerEvent("esx_skin:resetFirstSpawn")
  while not ready do
    Wait(500)
  end
  if not ESX.PlayerData.dead then
    StartRegistry()
  end
end)

RegisterNUICallback("ready", function(data, cb)
  ready = true
  SendReactMessage('setConfig', { UIConfig = UIConfig })
  cb(true)
end)


RegisterNUICallback("register", function(data, cb)
  data.sex = data.sex == "male" and "m" or "f"
  local Promise = promise.new()
  ESX.TriggerServerCallback("bcs_identity:registerIdentity", function(callback)
    if callback then
      ESX.ShowNotification("Thank you for registering")
      DoScreenFadeOut(500)
      while not IsScreenFadedOut() do
        Wait(100)
      end
      FreezeEntityPosition(PlayerPedId(), true)
      while not HasCollisionLoadedAroundEntity(PlayerPedId()) do
        Wait(200)
      end
      FreezeEntityPosition(PlayerPedId(), false)
      DoScreenFadeIn(500)
      if not ESX.GetConfig().Multichar then
        TriggerEvent("esx_skin:openSaveableMenu")
        TriggerEvent("esx_skin:playerRegistered")
      end
    end
    local retData <const> = { success = callback }
    Promise:resolve(retData)
  end, data)
  toggleNuiFrame(false)
  cb(Citizen.Await(Promise))
end)

function StartRegistry()
  toggleNuiFrame(true)
  debugPrint("Show NUI frame")
end
