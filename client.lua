local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

print("[Gov.xp - Client] Iniciando script client...")

local vSERVER = Tunnel.getInterface("govxp")

-- ============================================================
-- REGISTRO NO LB-PHONE
-- ============================================================
Citizen.CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do
        Citizen.Wait(500)
    end

    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = "govxp",
        name = "Gov.xp",
        description = "Serviços Digitais do Cidadão",
        developer = "Governo",
        defaultApp = true,
        size = 15000,
        price = 0,
        ui = GetCurrentResourceName() .. "/web/index.html",
        icon = "https://cfx-nui-" .. GetCurrentResourceName() .. "/icon.png"
    })

    if added then 
        print("[Gov.xp - Client] App registrado no lb-phone com sucesso!") 
    else
        print("[Gov.xp - Client] Erro ao registrar app: " .. tostring(errorMessage))
    end
end)

-- ============================================================
-- CALLBACKS GERAIS E DE SESSÃO
-- ============================================================
RegisterNUICallback("nuiLoaded", function(data, cb)
    local info = vSERVER.getUserInfo()
    
    exports["lb-phone"]:SendCustomAppMessage("govxp", {
        action = "setupData",
        passport = info.passport,
        name = info.name,
        status = info.status,
        anac = info.anac
    })
    
    cb("ok")
end)

RegisterNUICallback("login", function(data, cb) 
    local response = vSERVER.login(data.pass)
    cb(response) 
end)

RegisterNUICallback("register", function(data, cb) 
    local success = vSERVER.register(data.pass)
    cb({ success = success }) 
end)

-- ============================================================
-- CALLBACKS DE BUSCA E LISTAGEM
-- ============================================================
RegisterNUICallback("getVehicles", function(data, cb) 
    local vehicles = vSERVER.getVehicles()
    cb(vehicles) 
end)

RegisterNUICallback("getProperties", function(data, cb) 
    local properties = vSERVER.getProperties()
    cb(properties) 
end)

-- ============================================================
-- CALLBACKS DO BOLETIM DE OCORRÊNCIA (ROUBO)
-- ============================================================
RegisterNUICallback("reportStolen", function(data, cb)
    local success = vSERVER.reportStolen(data.plate, data.model)
    cb({ success = success })
end)

RegisterNUICallback("removeStolen", function(data, cb)
    local success = vSERVER.removeStolen(data.plate)
    cb({ success = success })
end)